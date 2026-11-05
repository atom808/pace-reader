/// The stage's frame (map stage proposal §2, §9): the map full bleed, and
/// over it on glass a HUD, a dock of traces and a play bar — one layout for
/// every screen that is a stage, Trace and Compare alike.
///
/// The camera centres the car in the part of the map the panels leave
/// visible, and glides when they move. Below 1080 px the dock becomes a sheet
/// over the lower part of the map. A host says what goes in each place
/// ([StageMapSpec], [hud], [StageDockSpec], [drawer]); the frame owns where
/// it goes, the play bar, the keys every stage shares, and the offer of
/// Performance mode.
library;

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../core/formatting.dart';
import '../../settings/application/app_settings.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../track_outline/application/road_outlines.dart';
import '../../track_outline/domain/road_band.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
import 'lap_view_controls.dart';
import 'lap_view_panes.dart';

/// What a host draws on the map: how the line is coloured, and what it adds
/// to it.
class StageMapSpec {
  const StageMapSpec({
    required this.colouring,
    this.alignment,
    this.reference,
    this.underlays = const [],
    this.overlays = const [],
    this.extent,
    this.frameWindow,
    this.litWheel,
    this.wheelColour,
    this.pulse = false,
    this.onPulsed,
  });

  /// Pulse the car once where a link has landed (map stage P9e); [onPulsed]
  /// says it has.
  final bool pulse;
  final VoidCallback? onPulsed;

  final LineColouring colouring;

  /// The corner the dock follows, lit on the car (map stage P9c); null on a
  /// tab that reads no corner.
  final Corner? litWheel;
  final Color? wheelColour;

  /// Where the reference lap's car is, for its ghost; null for no ghost.
  final LapAlignment? alignment;

  /// The reference lap's own line, dotted, which its ghost rides.
  final TrackPath? reference;
  final List<StageLayer> underlays;
  final List<StageLayer> overlays;

  /// The whole-lap frame, when more than the lap's own line.
  final Rect? extent;
  final Rect? Function(ChartViewport window)? frameWindow;
}

/// What a host puts in the dock: its tabs, the open one's panels, and what
/// sits in the header beside the tabs.
class StageDockSpec {
  const StageDockSpec({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.body,
    this.trailing = _none,
  });

  static List<Widget> _none(double headerWidth) => const [];

  final List<TraceTab> tabs;
  final TraceTab selected;
  final ValueChanged<TraceTab> onSelect;
  final Widget Function(TraceTab tab) body;

  /// After the tabs, before the zoom reset and the fold, for a header
  /// [headerWidth] wide: a detail link, a drawer's toggle.
  final List<Widget> Function(double headerWidth) trailing;
}

class StageFrame extends ConsumerStatefulWidget {
  /// The width of the lap's line on the stage, which what is drawn under it
  /// is cased around.
  static const lineWidth = 5.0;

  const StageFrame({
    super.key,
    required this.chart,
    required this.source,
    required this.map,
    required this.hud,
    required this.dock,
    this.keys = const {},
    this.drawer,
    this.footer,
    this.dockCollapsed = false,
  });

  /// A card across the foot of the clear map, on glass: Compare's segment
  /// navigator. The camera, the minimap and the scale bar keep above it. On
  /// a sheet it is the sheet's first row instead, unless the sheet is folded.
  final Widget? footer;

  final LapChart chart;
  final StageMapSpec map;

  /// The HUD's content, top left; the frame puts it on glass, no wider than
  /// the window allows.
  final Widget hud;

  /// The dock for a side (true) or sheet (false) layout: a host may offer a
  /// tab on a narrow window that a wide one shows in its [drawer].
  final StageDockSpec Function(bool side) dock;

  /// The host's own keys. They are asked first, so a host may give a shared
  /// key its own meaning (Compare's ← and → step through segments).
  final Map<ShortcutActivator, VoidCallback> keys;

  /// A column at the right edge on a wide window, pushing the dock left of
  /// it: Compare's Why. Null when closed or for none; never on a sheet.
  final Widget? drawer;

  /// Opens with the traces folded to a rail: how the Track map entry
  /// arrives, the map on its own.
  final bool dockCollapsed;

  /// The file whose layout the road under the line is drawn for (§3.4):
  /// the lap's own, or Compare's Base.
  final TelemetrySource source;

  /// Below this width the dock is a sheet under the map rather than a
  /// column beside it.
  static const sideDockBreakpoint = 1080.0;

  /// The [drawer]'s width.
  static const drawerWidth = 380.0;

  @override
  ConsumerState<StageFrame> createState() => _StageFrameState();
}

class _StageFrameState extends ConsumerState<StageFrame> {
  static const _margin = 12.0;
  static const _transportHeight = 56.0;
  static const _rail = 44.0;

  /// The HUD's widest.
  static const _hudWidth = 460.0;

  /// Narrower than this the sheet gives the map more of the height: on a
  /// phone the map is what the stage is for (map stage P9e).
  static const _phoneWidth = 520.0;

  /// The narrowest strip beside the HUD worth centring the car in.
  static const _minStrip = 280.0;

  /// The height the map's scale bar takes at the foot of the clear map.
  static const _scaleBarClearance = 36.0;

  /// One press of + or −: what a notch of the wheel does.
  static const _zoomStep = 1.25;

  /// The HUD's height as last laid out: what a narrow window's map sits
  /// under.
  double _hudHeight = 240;

  /// The footer card's height as last laid out.
  double _footerHeight = 120;

  late bool _collapsed = widget.dockCollapsed;
  bool _resizing = false;
  bool _side = true;
  final _camera = MapStageController();

  /// The road along the lap's line, kept while neither the line nor the
  /// outlines change: it is a pass over every point, and a survey's fit runs
  /// off the UI isolate (P9f), so it lands a frame or two after the stage.
  RoadBand? _road;

  /// The line [_road] was chosen along.
  TrackPath? _roadPath;
  (TrackPath, RoadOutlines)? _roadFrom;

  RoadBand? _roadFor(RoadOutlines? outlines) {
    final path = widget.chart.trackPath;
    final lateral = widget.chart.telemetry.pathLateral;
    if (outlines == null || path == null || lateral == null) return null;
    final from = (path, outlines);
    if (from == _roadFrom) return _road;
    _roadFrom = from;
    // The band the library grew from stays up until the next one lands;
    // another lap's never does.
    if (!identical(_roadPath, path)) _road = null;
    chooseRoadAsync(
      path: path,
      lateral: lateralAlong(path, lateral),
      library: outlines.library.outline,
      recordings: outlines.library.recordings,
      survey: outlines.survey,
      envelope: outlines.envelope,
    ).then((road) {
      if (!mounted || _roadFrom != from) return;
      setState(() {
        _road = road;
        _roadPath = path;
      });
    });
    return _road;
  }

  @override
  void didUpdateWidget(StageFrame old) {
    super.didUpdateWidget(old);
    if (old.dockCollapsed != widget.dockCollapsed) {
      _collapsed = widget.dockCollapsed;
    }
  }

  void _toggleDock() => setState(() => _collapsed = !_collapsed);

  /// What the traces show: the zoomed window, else the whole lap.
  ChartViewport get _window =>
      ref.read(chartSyncProvider).viewport ?? widget.chart.bounds;

  /// Moves the playhead to [to] and holds playback: a key is a choice of
  /// where to look, which a running clock would carry away.
  void _seek(double to) {
    ref.read(playbackProvider.notifier).pause();
    ref.read(chartSyncProvider.notifier).setPlayhead(to);
  }

  /// ←/→: 1 % of the window either way (map stage proposal §5.1).
  void _nudge(int direction) => _seek(
    nudgePlayhead(
      playhead: ref.read(chartSyncProvider).playhead,
      window: _window,
      fraction: 0.01 * direction,
    ),
  );

  /// Shift+←/→: the next timing line either way.
  void _jump(int direction) => _seek(
    jumpToMark(
      playhead: ref.read(chartSyncProvider).playhead,
      window: _window,
      marks: [for (final (at, _) in widget.chart.traceMarkers) at],
      direction: direction,
    ),
  );

  /// 1, 2, 3: the tab at [index]; Ctrl+Tab and Ctrl+Shift+Tab: the next
  /// either way, round.
  void _selectTab(int index) {
    final dock = widget.dock(_side);
    if (index < dock.tabs.length) dock.onSelect(dock.tabs[index]);
  }

  void _cycleTab(int direction) {
    final dock = widget.dock(_side);
    final i = dock.tabs.indexOf(dock.selected);
    dock.onSelect(dock.tabs[(i + direction) % dock.tabs.length]);
  }

  Map<ShortcutActivator, VoidCallback> get _keys {
    void rate(int d) => ref.read(playbackProvider.notifier).stepRate(d);
    return {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          ref.read(playbackProvider.notifier).toggle(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _nudge(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _nudge(1),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
          _jump(-1),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
          _jump(1),
      const SingleActivator(LogicalKeyboardKey.home): () =>
          _seek(_window.start),
      const SingleActivator(LogicalKeyboardKey.end): () => _seek(_window.end),
      const SingleActivator(LogicalKeyboardKey.bracketLeft): () => rate(-1),
      const SingleActivator(LogicalKeyboardKey.bracketRight): () => rate(1),
      for (final (i, key) in const [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
      ].indexed)
        SingleActivator(key): () => _selectTab(i),
      const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
          _cycleTab(1),
      const SingleActivator(
        LogicalKeyboardKey.tab,
        control: true,
        shift: true,
      ): () =>
          _cycleTab(-1),
      const SingleActivator(LogicalKeyboardKey.escape): _camera.follow,
      const SingleActivator(LogicalKeyboardKey.keyF): _camera.fit,
      // + is Shift+= on most layouts: matched by the character it types.
      const CharacterActivator('+'): () => _camera.zoomBy(_zoomStep),
      for (final key in const [
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.numpadAdd,
      ])
        SingleActivator(key): () => _camera.zoomBy(_zoomStep),
      for (final key in const [
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.numpadSubtract,
      ])
        SingleActivator(key): () => _camera.zoomBy(1 / _zoomStep),
    };
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final sideWidth = ref.watch(
      appSettingsProvider.select((s) => s.sidePaneWidth),
    );
    final watching =
        ref.watch(playbackProvider.select((p) => p.playing)) &&
        !ref.watch(appSettingsProvider.select((s) => s.performanceMode)) &&
        ref.watch(stutterOfferProvider) == StutterOffer.unmade;

    return PlaybackDriver(
      bounds: chart.bounds,
      distanceAxis: chart.distanceAxis,
      child: StutterWatch(
        active: watching,
        onStutter: ref.read(stutterOfferProvider.notifier).stuttered,
        // The shared keys outside the host's: a key event climbs from the
        // focus, so the host's are asked first.
        child: CallbackShortcuts(
          bindings: _keys,
          child: CallbackShortcuts(
            bindings: widget.keys,
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  final side = size.width >= StageFrame.sideDockBreakpoint;
                  _side = side;
                  final drawer = side ? widget.drawer : null;
                  final room = drawer == null
                      ? size.width
                      : size.width - StageFrame.drawerWidth - _margin;
                  final open = side
                      ? sideWidth.clamp(
                          (room * 0.34).clamp(320.0, double.infinity),
                          room * 0.62,
                        )
                      : (size.height - _transportHeight - _margin * 3) *
                            (size.width < _phoneWidth ? 0.45 : 0.55);
                  final extent = _collapsed ? _rail : open.toDouble();
                  final pushed = drawer == null
                      ? 0.0
                      : StageFrame.drawerWidth + _margin;
                  return TweenAnimationBuilder<(double, double)>(
                    tween: _PairTween(end: (extent, pushed)),
                    // Under the pointer while resizing: an eased dock would
                    // trail the hand that moves it.
                    duration: _resizing
                        ? Duration.zero
                        : AppMotion.duration(context, AppDurations.slow),
                    curve: AppCurves.standard,
                    builder: (context, at, _) => _layout(
                      size: size,
                      side: side,
                      extent: at.$1,
                      pushed: at.$2,
                      drawer: drawer,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _layout({
    required Size size,
    required bool side,
    required double extent,
    required double pushed,
    required Widget? drawer,
  }) {
    final chart = widget.chart;
    final map = widget.map;
    final scheme = Theme.of(context).colorScheme;
    final road = _roadFor(ref.watch(roadOutlinesProvider(widget.source)).value);
    final hudWidth = (size.width - _margin * 2).clamp(0.0, _hudWidth);
    // What the dock, the drawer and the play bar leave of the map.
    final panels = side
        ? EdgeInsets.only(
            right: extent + pushed + _margin * 2,
            bottom: _transportHeight + _margin * 2,
          )
        : EdgeInsets.only(bottom: extent + _transportHeight + _margin * 3);
    // On a sheet the footer is the sheet's first row, above the traces: the
    // short map over it has no room for a card. Folded, it floats again.
    final footer = side || _collapsed ? widget.footer : null;
    final lead = footer == null ? widget.footer : null;
    // The footer card takes the foot of what the panels leave clear.
    final clear = footer == null
        ? panels
        : panels.copyWith(bottom: panels.bottom + _footerHeight + _margin);
    // The HUD would cover the car: the camera centres in the strip beside
    // it, or, where that strip is too narrow, in the band under it.
    final strip = size.width - clear.horizontal - hudWidth - _margin * 2;
    final framing = strip >= _minStrip
        ? clear.copyWith(left: hudWidth + _margin * 2)
        : clear.copyWith(top: _hudHeight + _margin * 2);

    final dock = _StageDock(
      chart: chart,
      spec: widget.dock(side),
      // The rail while folded, and while the dock is still too small for its
      // panels on the way open or shut: never a squeezed stack.
      collapsed: _collapsed || extent < (side ? 240 : 120),
      folded: _collapsed,
      side: side,
      lead: lead,
      onToggle: _toggleDock,
      onResize: side && !_collapsed
          ? (dx, {required bool done}) {
              setState(() => _resizing = !done);
              ref
                  .read(appSettingsProvider.notifier)
                  .setSidePaneWidth(extent - dx, commit: done);
            }
          : null,
    );

    const stagger = Duration(milliseconds: 120);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scheme.surfaceContainerLowest),
        // The road fades in when its outline lands, which on a layout
        // the library is still reading is after the stage has opened.
        TweenAnimationBuilder<double>(
          tween: Tween(end: road == null ? 0 : 1),
          duration: AppMotion.duration(context, AppDurations.slow),
          curve: AppCurves.standard,
          builder: (context, fade, _) => MapStage(
            path: chart.trackPath!,
            ground: [
              if (road != null && fade > 0)
                TrackOutlineLayer(
                  left: road.left,
                  right: road.right,
                  colour: _roadColour(scheme, fade),
                ),
            ],
            colouring: map.colouring,
            markers: chart.trackMarkers,
            alignment: map.alignment,
            reference: map.reference,
            underlays: map.underlays,
            overlays: map.overlays,
            extent: map.extent,
            frameWindow: map.frameWindow,
            litWheel: map.litWheel,
            wheelColour: map.wheelColour,
            pulse: map.pulse,
            onPulsed: map.onPulsed,
            obscured: clear,
            framing: framing,
            strokeWidth: StageFrame.lineWidth,
            entrance: true,
            controller: _camera,
            minimap: true,
            speedZoom: ref.watch(
              appSettingsProvider.select((s) => s.speedZoom),
            ),
            onSpeedZoom: ref.read(appSettingsProvider.notifier).setSpeedZoom,
          ),
        ),
        // One group: every glass surface over the stage shares a single
        // read of what is behind it each frame (§7.2). None overlap.
        BackdropGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: _margin,
                top: _margin,
                child: StaggeredEntrance(
                  index: 0,
                  stagger: stagger,
                  child: _SizeReport(
                    onHeight: (h) {
                      if (h != _hudHeight) setState(() => _hudHeight = h);
                    },
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: hudWidth),
                      child: GlassSurface(
                        grouped: true,
                        radius: AppRadii.md,
                        tint: 0.45,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            widget.hud,
                            // Where the road under the line comes from, so
                            // a session's own envelope is never taken for
                            // the track. Only beside the map: a sheet's HUD
                            // is tight already.
                            AnimatedSize(
                              duration: AppMotion.duration(
                                context,
                                AppDurations.medium,
                              ),
                              curve: AppCurves.standard,
                              alignment: Alignment.topLeft,
                              child: road == null || !side
                                  ? const SizedBox.shrink()
                                  : _RoadNote(road.note),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (side)
                Positioned(
                  right: _margin + pushed,
                  top: _margin,
                  bottom: _transportHeight + _margin * 2,
                  width: extent,
                  child: StaggeredEntrance(
                    index: 1,
                    stagger: stagger,
                    child: dock,
                  ),
                )
              else
                Positioned(
                  left: _margin,
                  right: _margin,
                  bottom: _transportHeight + _margin * 2,
                  height: extent,
                  child: dock,
                ),
              if (side)
                Positioned(
                  right: _margin,
                  top: _margin,
                  bottom: _transportHeight + _margin * 2,
                  width: StageFrame.drawerWidth,
                  child: _DrawerSlot(drawer: drawer),
                ),
              Positioned(
                left: _margin,
                right: _margin,
                bottom: _margin,
                height: _transportHeight,
                child: StaggeredEntrance(
                  index: 2,
                  stagger: stagger,
                  child: StageTransport(chart: chart),
                ),
              ),
              if (footer != null)
                Positioned(
                  left: _margin,
                  right: panels.right + _margin,
                  bottom: panels.bottom + _margin,
                  child: StaggeredEntrance(
                    index: 3,
                    stagger: stagger,
                    child: _SizeReport(
                      onHeight: (h) {
                        if (h != _footerHeight) {
                          setState(() => _footerHeight = h);
                        }
                      },
                      child: GlassSurface(
                        grouped: true,
                        radius: AppRadii.md,
                        tint: 0.5,
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                        child: footer,
                      ),
                    ),
                  ),
                ),
              // Along the foot of the clear map, over the scale bar and short
              // of the minimap.
              Positioned(
                left: clear.left + _margin,
                right: clear.right + _margin * 2 + MapMinimap.width,
                bottom: clear.bottom + _margin + _scaleBarClearance,
                child: const Align(
                  alignment: Alignment.bottomCenter,
                  child: _StutterNotice(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two doubles eased together: the dock's extent and how far the drawer
/// pushes it.
class _PairTween extends Tween<(double, double)> {
  _PairTween({super.end});

  @override
  (double, double) lerp(double t) {
    final a = begin ?? end!;
    final b = end!;
    return (a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t);
  }
}

/// The drawer sliding in from the right edge, and out.
class _DrawerSlot extends StatelessWidget {
  const _DrawerSlot({required this.drawer});

  final Widget? drawer;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppDurations.slow),
    switchInCurve: AppCurves.standard,
    switchOutCurve: AppCurves.standard,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.25, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: drawer == null
        ? const SizedBox.shrink()
        : GlassSurface(
            key: const ValueKey('stage-drawer'),
            grouped: true,
            radius: AppRadii.lg,
            tint: 0.55,
            padding: EdgeInsets.zero,
            child: drawer!,
          ),
  );
}

/// The one-time offer of Performance mode when playback stutters (§7.4).
class _StutterNotice extends ConsumerWidget {
  const _StutterNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(stutterOfferProvider) == StutterOffer.shown;
    void settle() => ref.read(stutterOfferProvider.notifier).settle();
    return GlassNoticeSlot(
      notice: shown
          ? GlassNotice(
              icon: Icons.speed,
              message: 'Playback is stuttering. Turn on Performance mode?',
              action: 'Turn on',
              onAction: () {
                ref.read(appSettingsProvider.notifier).setPerformanceMode(true);
                settle();
              },
              onDismiss: settle,
            )
          : null,
    );
  }
}

/// Where the panels read: the probe while the pointer is over a trace or the
/// line, the playhead otherwise.
double? stageReading(ChartSyncState sync) => sync.probe ?? sync.playhead;

/// Speed, gear, throttle and brake where the panels read — GO Fast's driver
/// chips — each on a solid backing, so a number is never read against blur.
/// With a reference lap, its value sits under this lap's (§6.3).
class StageLiveChips extends ConsumerWidget {
  const StageLiveChips({super.key, required this.chart, this.compact = false});

  final LapChart chart;

  /// Each chip its swatch and value alone, the four in one row of a
  /// phone-width HUD (map stage P9e); the name moves to its tooltip.
  final bool compact;

  static const _roles = [
    ChannelRole.speed,
    ChannelRole.gear,
    ChannelRole.throttle,
    ChannelRole.brake,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final at = stageReading(sync);
    final channels = ChannelColors.resolve(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final compared = chart.comparison != null;
    return Wrap(
      spacing: compact ? 4 : 6,
      runSpacing: 6,
      children: [
        for (final role in _roles)
          if (chart.panels.where((p) => p.role == role).firstOrNull
              case final panel?)
            _ChipName(
              name: compact ? panel.title : null,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: 4,
                ),
                decoration: ShapeDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: AppRadii.squircle(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: channels.of(role),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 6),
                    if (!compact) ...[
                      Text(
                        panel.title,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: compact ? 26 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _value(panel, at, reference: false),
                            style: AppTextStyles.numeral.copyWith(fontSize: 12),
                          ),
                          if (compared)
                            Text(
                              _value(panel, at, reference: true),
                              key: ValueKey('chip-reference-${role.name}'),
                              style: AppTextStyles.numeral.copyWith(
                                fontSize: 10.5,
                                color: muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (panel.unit.isNotEmpty) ...[
                      const SizedBox(width: 3),
                      Text(
                        panel.unit,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  static String _value(
    TracePanelSpec panel,
    double? at, {
    required bool reference,
  }) {
    if (at == null) return '—';
    final value = reference
        ? panel.series.referenceValueAt(at)
        : panel.series.valueAt(at);
    return value == null ? '—' : valueFormatter(panel)(value);
  }
}

/// The traces, on glass: the tab bar, then the open tab's panels. Folds to
/// a rail; beside the map, its left edge resizes it.
class _StageDock extends ConsumerWidget {
  const _StageDock({
    required this.chart,
    required this.spec,
    required this.collapsed,
    required this.folded,
    required this.side,
    required this.onToggle,
    required this.onResize,
    this.lead,
  });

  final LapChart chart;
  final StageDockSpec spec;

  /// Between the tabs and the panels, whatever the tab: the stage's footer
  /// card, on a sheet.
  final Widget? lead;

  /// Shows the rail: folded, or still too small to hold the panels.
  final bool collapsed;

  /// Folded by the user: what the toggle offers to undo.
  final bool folded;
  final bool side;
  final VoidCallback onToggle;
  final void Function(double dx, {required bool done})? onResize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toggle = AppTooltip(
      message: folded ? 'Show the traces' : 'Fold the traces away',
      child: IconButton(
        onPressed: onToggle,
        icon: Icon(switch ((side, folded)) {
          (true, true) => Icons.keyboard_double_arrow_left,
          (true, false) => Icons.keyboard_double_arrow_right,
          (false, true) => Icons.keyboard_double_arrow_up,
          (false, false) => Icons.keyboard_double_arrow_down,
        }, size: 18),
      ),
    );

    final Widget body;
    if (collapsed) {
      body = Flex(
        direction: side ? Axis.vertical : Axis.horizontal,
        children: [
          toggle,
          for (final tab in spec.tabs)
            AppTooltip(
              message: tab.label,
              child: IconButton(
                onPressed: () {
                  spec.onSelect(tab);
                  onToggle();
                },
                icon: Icon(tab.icon, size: 18),
              ),
            ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
            child: LayoutBuilder(
              builder: (context, header) => Row(
                children: [
                  // All the free width, so the tabs keep their names wherever
                  // those fit.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DockTabs(
                        tabs: spec.tabs,
                        selected: spec.selected,
                        onSelected: spec.onSelect,
                      ),
                    ),
                  ),
                  ...spec.trailing(header.maxWidth),
                  const ZoomResetButton(),
                  toggle,
                ],
              ),
            ),
          ),
          if (lead case final lead?) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              child: lead,
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppDurations.medium),
              child: KeyedSubtree(
                key: ValueKey(spec.selected.id),
                child: spec.body(spec.selected),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
            child: LapAxisFooter(chart: chart),
          ),
        ],
      );
    }

    final surface = GlassSurface(
      grouped: true,
      radius: AppRadii.lg,
      tint: 0.55,
      padding: collapsed ? const EdgeInsets.all(2) : EdgeInsets.zero,
      child: body,
    );
    final resize = onResize;
    if (resize == null) return surface;
    return Stack(
      fit: StackFit.expand,
      children: [
        surface,
        Positioned(
          left: 0,
          top: 24,
          bottom: 24,
          width: 8,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (d) => resize(d.delta.dx, done: false),
              onHorizontalDragEnd: (_) => resize(0, done: true),
              onDoubleTap: ref
                  .read(appSettingsProvider.notifier)
                  .resetSidePaneWidth,
            ),
          ),
        ),
      ],
    );
  }
}

/// ▶, where the lap is, the gap at the playhead, and the axis.
class StageTransport extends ConsumerWidget {
  const StageTransport({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassSurface(
      grouped: true,
      radius: AppRadii.lg,
      tint: 0.45,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: TransportBar(
        bounds: chart.bounds,
        markers: chart.traceMarkers,
        formatDomain: (domain) => formatLapTime(lapSecondsAt(chart, domain)),
        trailing: [
          _DeltaReadout(chart: chart),
          const SizedBox(width: 12),
          AxisToggle(chart: chart),
        ],
        compactTrailing: [AxisToggle(chart: chart, compact: true)],
        tightTrailing: [AxisToggle(chart: chart, single: true)],
      ),
    );
  }
}

/// Seconds into the lap at [domain], whichever axis the chart is on.
double lapSecondsAt(LapChart chart, double domain) {
  final seconds = switch (chart.axis) {
    TraceAxis.time => domain,
    TraceAxis.distance => chart.distanceAxis?.timeAt(domain) ?? domain,
  };
  return seconds - chart.telemetry.startSeconds;
}

/// Δ where the panels read, when there is a reference to be ahead of.
class _DeltaReadout extends ConsumerWidget {
  const _DeltaReadout({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = chart.panels
        .where((p) => p.role == ChannelRole.delta)
        .firstOrNull;
    if (panel == null) return const SizedBox.shrink();
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final at = stageReading(sync);
    final value = at == null ? null : panel.series.valueAt(at);
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Δ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 64,
          child: Text(
            value == null ? '—' : formatDelta(value),
            style: AppTextStyles.numeral,
          ),
        ),
      ],
    );
  }
}

/// Reports [child]'s laid-out height after each layout that changes it.
class _SizeReport extends SingleChildRenderObjectWidget {
  const _SizeReport({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReport(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReport render) =>
      render.onHeight = onHeight;
}

class _RenderSizeReport extends RenderProxyBox {
  _RenderSizeReport(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // After the frame: a layout may not mark its ancestors dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (attached) onHeight(height);
    });
  }
}

/// The road's fill: ground, not ink, a neutral tone with no edge (§3.1).
/// The darkest container tones sit too close to the stage's own to read.
Color _roadColour(ColorScheme scheme, [double fade = 1]) =>
    scheme.surfaceContainerHighest.withValues(alpha: 0.9 * fade);

/// One muted line under the HUD: a swatch of the road's fill and where it
/// comes from.
class _RoadNote extends StatelessWidget {
  const _RoadNote(this.note);

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 8,
            decoration: BoxDecoration(
              color: _roadColour(scheme),
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live chip's channel name as its tooltip, where the chip has no room to
/// write it.
class _ChipName extends StatelessWidget {
  const _ChipName({required this.name, required this.child});

  final String? name;
  final Widget child;

  @override
  Widget build(BuildContext context) => switch (name) {
    final name? => AppTooltip(message: name, child: child),
    null => child,
  };
}
