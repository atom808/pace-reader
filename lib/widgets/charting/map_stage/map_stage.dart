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
import 'camera.dart';
import 'camera_rig.dart';
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
  });

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
    if (!identical(old.path, widget.path)) {
      _index(widget.path);
      _speed.reset();
    }
    // The dock moved: the visible map's middle moved with it, and the
    // camera glides after it rather than jumping.
    if (old.obscured != widget.obscured) _kick();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _entrance.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _index(TrackPath path) {
    _kinematics = PathKinematics.of(path);
    _hits = PathHitIndex(path.projection.points);
  }

  Rect get _visible => widget.obscured.deflateRect(Offset.zero & _size);

  MapCamera get _fitCamera =>
      MapCamera.fit(widget.path.projection.boundsMetres, _visible);

  double get _maxZoom => maxPixelsPerMetre(_visible.size);

  double _clampZoom(double ppm) {
    final min = math.min(_fitCamera.pixelsPerMetre, _maxZoom);
    return ppm.clamp(min, _maxZoom);
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
          _reduced ? chosen : chosen * speedZoomFactor(fraction),
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
      if (_mode == CameraMode.follow && _playheadIndex != null) {
        _followZoom = _clampZoom((_followZoom ?? 1) * factor);
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

    // Rebuilt per frame of the entrance only; otherwise once per build.
    List<StageLayer> layers() => [
      TrackLineLayer(
        path: path,
        colouring: widget.colouring,
        casing: palette.grid.withValues(alpha: 0.5),
        width: widget.strokeWidth,
        drawn: _entrance.value,
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
                          animation: _entrance,
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
            Positioned(
              top: widget.obscured.top + 8,
              right: widget.obscured.right + 8,
              child: _CameraButtons(
                mode: _mode,
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
