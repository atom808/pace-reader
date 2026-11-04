/// The map stage (map stage proposal §3–§5): the track map as a camera over
/// the lap, following the car at the playhead.
///
/// What it does with the shared [ChartSync]:
/// - the **playhead** places the car, and the camera follows it;
/// - the **probe** — the pointer over a trace or over the line — draws a
///   ring and moves nothing;
/// - hovering the line sets the probe, clicking it sets the playhead.
///
/// The camera is local: Follow (the default), Free after any drag, Fit on a
/// double-click or the Fit button. A wheel changes Follow's zoom, or zooms
/// about the pointer in the other two.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design_system/design_system.dart';
import '../lap_alignment.dart';
import '../playback.dart';
import '../painters/chart_painting.dart';
import '../sync/chart_sync.dart';
import '../sync/sync_owner.dart';
import '../track_path.dart';
import '../viewport.dart';
import 'camera.dart';
import 'camera_rig.dart';
import 'minimap.dart';
import 'path_hit_test.dart';
import 'path_kinematics.dart';
import 'stage_contracts.dart';
import 'stage_layers.dart';

class MapStage extends ConsumerStatefulWidget {
  const MapStage({
    super.key,
    required this.path,
    required this.colouring,
    this.markers = const [],
    this.alignment,
    this.strokeWidth = 4,
    this.obscured = EdgeInsets.zero,
    this.followMetres = 320,
    this.entrance = false,
    this.controller,
    this.minimap = false,
    this.speedZoom = true,
    this.onSpeedZoom,
  });

  /// Commands from outside — the screen's keys — to the camera.
  final MapStageController? controller;

  /// Shows the minimap and the camera's controls in a card at the bottom
  /// right of the clear map, where there is room; the bare Follow and Fit
  /// buttons otherwise.
  final bool minimap;

  /// Whether Follow breathes with speed (§4); off under reduced motion
  /// whatever this says.
  final bool speedZoom;

  /// Turns [speedZoom] on or off from the minimap's menu; no menu when null.
  final ValueChanged<bool>? onSpeedZoom;

  final TrackPath path;
  final LineColouring colouring;

  /// `(point index, label)`: start/finish and the sector boundaries.
  final List<(int, String)> markers;

  /// Where a comparison's car is, for its ghost; null for no ghost.
  final LapAlignment? alignment;

  final double strokeWidth;

  /// What of the stage lies under the panels, which the camera centres
  /// beside rather than behind.
  final EdgeInsets obscured;

  /// How much of the lap Follow shows across the view's short side, before
  /// any wheel.
  final double followMetres;

  /// Whether the line draws itself from the start/finish line when the stage
  /// first appears (map stage proposal §8). Never under reduced motion or
  /// Performance mode.
  final bool entrance;

  @override
  ConsumerState<MapStage> createState() => _MapStageState();
}

/// Commands to a [MapStage]'s camera from outside it: the screen's keys,
/// which reach the screen rather than the map (map stage proposal §5.1).
/// Inert until a stage is built with it.
class MapStageController {
  _MapStageState? _stage;

  /// Esc: back to Follow.
  void follow() => _stage?._command(CameraMode.follow);

  /// F: the trace window, or the whole lap.
  void fit() => _stage?._command(CameraMode.fit);

  /// +/−: closer (above 1) or further (below 1), about the visible centre.
  void zoomBy(double factor) => _stage?._zoomBy(factor);
}

class _MapStageState extends ConsumerState<MapStage>
    with TickerProviderStateMixin {
  /// How near the pointer must be to the line, in pixels, to read it.
  static const _hitPixels = 24.0;

  /// Two stretches of the line closer than this, in pixels, are a tie, which
  /// the one nearer the playhead wins.
  static const _tiePixels = 6.0;

  late final Ticker _ticker = createTicker(_tick);
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
    value: widget.entrance ? 0 : 1,
  );
  bool _entranceDecided = false;

  /// The band under the trace window, faded in and out (§8).
  late final AnimationController _casing = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
  );

  /// The outgoing colouring while the line cross-fades to a new one (§3.3).
  late final AnimationController _fade =
      AnimationController(
        vsync: this,
        duration: AppDurations.medium,
        value: 1,
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _outgoing = null;
      });

  /// The colouring fading out under the new one; always of the current
  /// path, since a new path cuts rather than fades.
  LineColouring? _outgoing;

  /// The trace window the camera frames in Fit; null for the whole lap.
  ChartViewport? _window;

  /// The last window the band was drawn for, kept while it fades out.
  ChartViewport? _bandWindow;
  final _camera = ValueNotifier(
    const MapCamera(centre: Offset.zero, pixelsPerMetre: 1, focus: Offset.zero),
  );
  CameraRig? _rig;
  CameraMode _mode = CameraMode.follow;
  double? _followZoom;
  final _speed = LowPass();
  Duration? _lastTick;

  late PathKinematics _kinematics;
  late PathHitIndex _hits;

  Size _size = Size.zero;
  double? _playheadIndex;
  bool _reduced = false;
  bool _overLine = false;

  /// For telling a double-click from two clicks: frame timestamps stand
  /// still while nothing repaints, so they cannot.
  final _clock = Stopwatch()..start();
  ({Duration at, Offset where})? _lastTap;

  @override
  void initState() {
    super.initState();
    _index(widget.path);
    widget.controller?._stage = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceDecided) return;
    _entranceDecided = true;
    if (!widget.entrance) return;
    // Decided once, before anything listens: the pen stroke is decoration,
    // so reduced motion and Performance mode open on the finished map.
    if (AppMotion.reduced(context) || !EffectsQuality.blurs(context)) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void didUpdateWidget(MapStage old) {
    super.didUpdateWidget(old);
    final samePath = identical(old.path, widget.path);
    if (!samePath) {
      _index(widget.path);
      _speed.reset();
    }
    if (old.controller != widget.controller) {
      if (old.controller?._stage == this) old.controller!._stage = null;
      widget.controller?._stage = this;
    }
    // A new colouring cross-fades in rather than snapping, so the eye sees
    // the same line read another way (§3.3); a cut under reduced motion.
    // Another lap is another line, and its colours are another path's: that
    // cuts too, and drops any fade still running over the old one.
    if (!samePath) {
      _outgoing = null;
      _fade.value = 1;
    } else if (old.colouring != widget.colouring &&
        !AppMotion.reduced(context)) {
      _outgoing = old.colouring;
      _fade.forward(from: 0);
    }
    // The dock moved: the visible map's middle moved with it, and the
    // camera glides after it rather than jumping.
    if (old.obscured != widget.obscured) _kick();
    if (old.speedZoom != widget.speedZoom) _kick();
  }

  @override
  void dispose() {
    if (widget.controller?._stage == this) widget.controller!._stage = null;
    _ticker.dispose();
    _entrance.dispose();
    _casing.dispose();
    _fade.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _index(TrackPath path) {
    _kinematics = PathKinematics.of(path);
    _hits = PathHitIndex(path.projection.points);
  }

  Rect get _visible => widget.obscured.deflateRect(Offset.zero & _size);

  /// The minimap takes a corner of the clear map; below this it would cover
  /// the car, and the bare buttons stand in.
  bool get _roomForMinimap => _visible.width >= 520 && _visible.height >= 360;

  /// The whole lap: the furthest the camera goes.
  MapCamera get _lapCamera =>
      MapCamera.fit(widget.path.projection.boundsMetres, _visible);

  /// What Fit shows: the trace window's stretch when the traces are zoomed
  /// (§4, "Trace zoom frames the map"), else the whole lap.
  MapCamera get _fitCamera {
    final window = _window;
    final stretch = window == null
        ? null
        : stretchBoundsMetres(widget.path, window.start, window.end);
    if (stretch == null) return _lapCamera;
    final framed = MapCamera.fit(stretch, _visible, padding: 48);
    return framed.copyWith(pixelsPerMetre: _clampZoom(framed.pixelsPerMetre));
  }

  double get _maxZoom => maxPixelsPerMetre(_visible.size);

  double get _minZoom => math.min(_lapCamera.pixelsPerMetre, _maxZoom);

  double _clampZoom(double ppm) => ppm.clamp(_minZoom, _maxZoom);

  bool get _following => _mode == CameraMode.follow && _playheadIndex != null;

  /// What the camera is doing as the controls name it: Follow with no car
  /// yet to follow shows the whole lap, and says so.
  CameraMode get _shownMode => _mode == CameraMode.follow && !_following
      ? CameraMode.fit
      : _mode;

  /// The zoom the user chose: Follow's, which the speed term only breathes
  /// around, or where the camera is heading in Free and Fit.
  double get _chosenZoom => _following
      ? _clampZoom(_followZoom ?? _visible.shortestSide / widget.followMetres)
      : (_rig?.target.pixelsPerMetre ?? _camera.value.pixelsPerMetre);

  /// [_chosenZoom] between the whole lap (0) and the closest (1), on a log
  /// scale, as the minimap's slider shows it.
  double get _zoomFraction {
    final span = math.log(_maxZoom / _minZoom);
    if (span <= 0) return 0;
    return math.log(_chosenZoom / _minZoom) / span;
  }

  void _setZoomFraction(double t) =>
      _setZoom(_minZoom * math.exp(t * math.log(_maxZoom / _minZoom)));

  /// Zooms to [ppm] about the visible centre: Follow keeps it as its chosen
  /// zoom; Free and Fit go Free there.
  void _setZoom(double ppm) {
    final rig = _rig;
    if (rig == null) return;
    final clamped = _clampZoom(ppm);
    setState(() {
      if (_following) {
        _followZoom = clamped;
      } else {
        _mode = CameraMode.free;
        rig.target = rig.target.copyWith(pixelsPerMetre: clamped);
      }
    });
    _kick();
  }

  void _zoomBy(double factor) => _setZoom(_chosenZoom * factor);

  void _command(CameraMode mode) {
    if (mode == CameraMode.follow && _playheadIndex == null) return;
    _setMode(mode);
  }

  /// Centres the camera on [metres], going Free there: the minimap's click.
  void _centreOn(Offset metres) {
    final rig = _rig;
    if (rig == null) return;
    if (_mode != CameraMode.free) setState(() => _mode = CameraMode.free);
    rig.target = rig.target.copyWith(centre: metres);
    _kick();
  }

  /// Where the camera is heading, given the mode and the playhead.
  MapCamera _target() {
    final fit = _fitCamera;
    final i = _playheadIndex;
    switch (_mode) {
      case CameraMode.free:
        return _rig?.target ?? fit;
      case CameraMode.fit:
        return fit;
      case CameraMode.follow:
        if (i == null) return fit;
        final visible = _visible;
        final chosen = _clampZoom(
          _followZoom ??= visible.shortestSide / widget.followMetres,
        );
        final fraction =
            _speed.value ?? _kinematics.speedFraction(_kinematics.speedAt(i));
        // Reduced motion keeps the zoom still: the breathing is decoration.
        final ppm = _clampZoom(
          _reduced || !widget.speedZoom
              ? chosen
              : chosen * speedZoomFactor(fraction),
        );
        final ahead = lookAhead(
          heading: _kinematics.headingAt(i),
          metresPerSecond: _kinematics.speedAt(i),
          viewMetres: visible.shortestSide / ppm,
        );
        return MapCamera(
          centre: positionAtIndex(widget.path, i) + ahead,
          pixelsPerMetre: ppm,
          focus: visible.center,
        );
    }
  }

  /// Something the camera reads changed: glide there, or jump under reduced
  /// motion.
  void _kick() {
    final rig = _rig;
    if (rig == null) return;
    if (_reduced) {
      _speed.reset();
      rig.jumpTo(_target());
      _camera.value = rig.current;
      return;
    }
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) {
    final rig = _rig;
    if (rig == null) return;
    final last = _lastTick;
    final dt = last == null ? 1 / 60 : (elapsed - last).inMicroseconds / 1e6;
    _lastTick = elapsed;

    final i = _playheadIndex;
    var speedSettled = true;
    if (_mode == CameraMode.follow && i != null) {
      final raw = _kinematics.speedFraction(_kinematics.speedAt(i));
      final smoothed = _speed.add(raw, dt);
      speedSettled = (smoothed - raw).abs() < 0.01;
    }
    rig.target = _target();
    rig.step(dt);
    _camera.value = rig.current;
    if (rig.settled && speedSettled) {
      _ticker.stop();
      _lastTick = null;
    }
  }

  void _layout(Size size) {
    if (size == _size && _rig != null) return;
    _size = size;
    final rig = _rig;
    if (rig == null) {
      // The first frame lands where it should be: nothing to glide from.
      final start = _target();
      _rig = CameraRig(initial: start);
      _camera.value = start;
    } else {
      // A resize moves the focus; keep what is under it, then re-aim.
      rig.jumpTo(rig.current.copyWith(focus: _visible.center));
      _camera.value = rig.current;
      _kick();
    }
  }

  void _setMode(CameraMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    _kick();
  }

  PathHit? _hitAt(Offset local) {
    final camera = _camera.value;
    final ppm = camera.pixelsPerMetre;
    return _hits.nearest(
      camera.toMetres(local),
      radius: _hitPixels / ppm,
      near: _playheadIndex,
      tieMetres: _tiePixels / ppm,
    );
  }

  void _hover(Offset local, ChartSync sync) {
    final hit = _hitAt(local);
    sync.setProbe(hit == null ? null : domainAtIndex(widget.path, hit.index));
    if ((hit != null) != _overLine) setState(() => _overLine = hit != null);
  }

  void _exit(ChartSync sync) {
    sync.setProbe(null);
    if (_overLine) setState(() => _overLine = false);
  }

  void _tapUp(TapUpDetails details, ChartSync sync) {
    final now = _clock.elapsed;
    final last = _lastTap;
    _lastTap = (at: now, where: details.localPosition);
    final isDouble =
        last != null &&
        now - last.at < kDoubleTapTimeout &&
        (details.localPosition - last.where).distance < kDoubleTapSlop;
    if (isDouble) {
      _lastTap = null;
      sync.resetViewport();
      _setMode(CameraMode.fit);
      return;
    }
    final hit = _hitAt(details.localPosition);
    if (hit == null) return;
    sync.setPlayhead(domainAtIndex(widget.path, hit.index));
  }

  void _drag(DragUpdateDetails details) {
    final rig = _rig;
    if (rig == null) return;
    if (_mode != CameraMode.free) setState(() => _mode = CameraMode.free);
    rig.jumpTo(rig.current.pannedBy(details.delta));
    _camera.value = rig.current;
  }

  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      final rig = _rig;
      if (rig == null) return;
      // As the trace panels zoom: a proportional step per notch, clamped so
      // a trackpad fling cannot jump decades at once.
      final factor =
          1 / (1 + event.scrollDelta.dy * 0.0016).clamp(0.75, 1.35).toDouble();
      if (_following) {
        setState(() => _followZoom = _clampZoom(_chosenZoom * factor));
      } else {
        final next = rig.target.zoomedAbout(event.localPosition, factor);
        if (_mode != CameraMode.free) setState(() => _mode = CameraMode.free);
        rig.target = next.copyWith(
          pixelsPerMetre: _clampZoom(next.pixelsPerMetre),
        );
      }
      _kick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final (state: sync, :owns) = watchChartSync(ref, context);
    final controller = ref.read(chartSyncProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final palette = ChartPalette.of(context, series: scheme.onSurface);
    final path = widget.path;
    _reduced = AppMotion.reduced(context);
    // ▶ recentres: playing a lap is watching the car (§5.1).
    ref.listen(playbackProvider.select((s) => s.playing), (_, playing) {
      if (playing && _mode == CameraMode.free) _setMode(CameraMode.follow);
    });

    // The trace window: the traces zoomed to a stretch frame it on the map
    // (§4) — unless ▶ moved it, which is the window keeping up with the
    // car, not the user asking to look somewhere. A band fades in under it.
    final window = sync.viewport;
    if (window != _window) {
      final wasZoomed = _window != null;
      _window = window;
      if (window != null) {
        _bandWindow = window;
        _casing.forward();
        if (!ref.read(playbackProvider).playing && _mode != CameraMode.fit) {
          _mode = CameraMode.fit;
        }
      } else {
        _casing.reverse();
      }
      if (window != null || wasZoomed) _kick();
    }

    final playhead = sync.playhead;
    final playheadIndex = playhead == null
        ? null
        : indexAtDomain(path, playhead);
    if (playheadIndex != _playheadIndex) {
      _playheadIndex = playheadIndex;
      _kick();
    }
    final probe = sync.probe;
    final probeIndex = probe == null ? null : indexAtDomain(path, probe);

    final cars = <CarGlyph>[];
    final alignment = widget.alignment;
    if (alignment != null && playhead != null) {
      final station = alignment.referenceStationFor(sync.axis, playhead);
      final ghost = station == null ? null : indexAtStation(path, station);
      if (ghost != null) {
        cars.add(
          CarGlyph(
            at: positionAtIndex(path, ghost),
            heading: _kinematics.headingAt(ghost),
            colour: scheme.onSurface.withValues(alpha: 0.85),
            hollow: true,
          ),
        );
      }
    }
    if (playheadIndex != null) {
      cars.add(
        CarGlyph(
          at: positionAtIndex(path, playheadIndex),
          heading: _kinematics.headingAt(playheadIndex),
          colour: scheme.onSurface,
        ),
      );
    }

    // Rebuilt per frame of the entrance, the band's fade and the colouring's
    // cross-fade only; otherwise once per build.
    final band = _bandWindow;
    final outgoing = _outgoing;
    List<StageLayer> layers() => [
      if (band != null && _casing.value > 0)
        WindowCasingLayer(
          path: path,
          start: band.start,
          end: band.end,
          colour: scheme.primary.withValues(alpha: 0.22),
          width: widget.strokeWidth,
          opacity: _casing.value,
        ),
      TrackLineLayer(
        path: path,
        colouring: widget.colouring,
        casing: palette.grid.withValues(alpha: 0.5),
        width: widget.strokeWidth,
        drawn: _entrance.value,
      ),
      if (outgoing != null && _fade.value < 1)
        TrackLineLayer(
          path: path,
          colouring: outgoing,
          casing: palette.grid.withValues(alpha: 0.5),
          width: widget.strokeWidth,
          drawn: _entrance.value,
          opacity: 1 - _fade.value,
        ),
      TrackMarkerLayer(path: path, markers: widget.markers, palette: palette),
      ProbeLayer(
        at: probeIndex == null ? null : positionAtIndex(path, probeIndex),
        colour: palette.cursor,
        halo: palette.surface,
      ),
      // The car arrives once the pen stroke has reached the line.
      if (_entrance.value == 1) CarLayer(cars: cars, halo: palette.surface),
      ScaleBarLayer(
        palette: palette,
        inset: Offset(widget.obscured.left + 12, widget.obscured.bottom + 12),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        _layout(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              label: 'Track map',
              child: IgnorePointer(
                ignoring: !owns,
                child: MouseRegion(
                  cursor: _overLine
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.grab,
                  onHover: (e) => _hover(e.localPosition, controller),
                  onExit: (_) => _exit(controller),
                  child: Listener(
                    onPointerSignal: _wheel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) => _tapUp(d, controller),
                      onPanUpdate: _drag,
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _entrance,
                            _casing,
                            _fade,
                          ]),
                          builder: (context, _) => CustomPaint(
                            painter: StagePainter(
                              camera: _camera,
                              layers: layers(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.minimap && _roomForMinimap)
              Positioned(
                right: widget.obscured.right + 12,
                bottom: widget.obscured.bottom + 12,
                child: MapMinimap(
                  path: path,
                  camera: _camera,
                  visible: _visible,
                  cars: cars,
                  mode: _shownMode,
                  framingWindow: _window != null,
                  canFollow: playheadIndex != null,
                  zoom: _zoomFraction,
                  onZoom: _setZoomFraction,
                  onCentre: _centreOn,
                  onMode: _command,
                  speedZoom: widget.speedZoom,
                  onSpeedZoom: widget.onSpeedZoom,
                ),
              )
            else
              Positioned(
                top: widget.obscured.top + 8,
                right: widget.obscured.right + 8,
                child: _CameraButtons(
                  mode: _shownMode,
                  canFollow: playheadIndex != null,
                  onMode: _setMode,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Follow and Fit, top right. In Free neither is lit: pressing Follow is
/// the way back to the car.
class _CameraButtons extends StatelessWidget {
  const _CameraButtons({
    required this.mode,
    required this.canFollow,
    required this.onMode,
  });

  final CameraMode mode;
  final bool canFollow;
  final ValueChanged<CameraMode> onMode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(
      CameraMode target,
      IconData icon,
      String tip, {
      bool enabled = true,
    }) {
      final selected = mode == target;
      return AppTooltip(
        message: tip,
        child: IconButton(
          onPressed: enabled ? () => onMode(target) : null,
          isSelected: selected,
          icon: Icon(icon, size: 16),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor: selected
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            foregroundColor: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
            shape: AppRadii.squircle(AppRadii.sm),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          CameraMode.follow,
          Icons.my_location,
          mode == CameraMode.free ? 'Back to the car' : 'Follow the car',
          enabled: canFollow,
        ),
        const SizedBox(width: 4),
        button(CameraMode.fit, Icons.fit_screen_outlined, 'Whole lap'),
      ],
    );
  }
}
