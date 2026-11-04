/// The lap stage (map stage proposal §2, §9): Trace and Track map as one
/// screen. The map fills it; the HUD, the dock of traces and the play bar
/// float over it on glass.
///
/// The camera centres the car in the part of the map the dock leaves
/// visible, and glides when the dock moves. Below 1080 px the dock becomes
/// a sheet over the lower part of the map.
library;

import 'package:flutter/rendering.dart' show RenderProxyBox;
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../lap_focus/lap_focus.dart';
import '../../lap_focus/lap_focus_link.dart';
import '../../settings/application/app_settings.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/corner_chart.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
import '../application/trace_focus.dart';
import 'corner_tabs.dart';
import 'lap_view_controls.dart';
import 'lap_view_panes.dart';

class LapStage extends ConsumerStatefulWidget {
  const LapStage({
    super.key,
    required this.source,
    required this.chart,
    this.dockCollapsed = false,
  });

  /// The session [chart]'s lap is from: what a link to another screen names.
  final TelemetrySource source;
  final LapChart chart;

  /// Opens with the traces folded to a rail: how the Track map entry
  /// arrives, the map on its own.
  final bool dockCollapsed;

  /// Below this width the dock is a sheet under the map rather than a
  /// column beside it.
  static const sideDockBreakpoint = 1080.0;

  @override
  ConsumerState<LapStage> createState() => _LapStageState();
}

class _LapStageState extends ConsumerState<LapStage> {
  static const _margin = 12.0;
  static const _transportHeight = 56.0;
  static const _rail = 44.0;

  /// The HUD's widest.
  static const _hudWidth = 460.0;

  /// The narrowest strip beside the HUD worth centring the car in.
  static const _minStrip = 280.0;

  /// The height the map's scale bar takes at the foot of the clear map.
  static const _scaleBarClearance = 36.0;

  /// The HUD's height as last laid out: what a narrow window's map sits
  /// under.
  double _hudHeight = 240;

  late bool _collapsed = widget.dockCollapsed;
  bool _resizing = false;
  final _camera = MapStageController();

  @override
  void didUpdateWidget(LapStage old) {
    super.didUpdateWidget(old);
    if (old.dockCollapsed != widget.dockCollapsed) {
      _collapsed = widget.dockCollapsed;
    }
  }

  void _toggleDock() => setState(() => _collapsed = !_collapsed);

  /// Ctrl+Enter: the open tab's detail screen, at the playhead.
  void _openDetail() {
    final tab = shownTraceTab(widget.chart, ref.read(traceTabProvider)).shown;
    final target = traceTabDetails[tab.id];
    if (target == null) return;
    openFocus(
      context,
      ref,
      target,
      stageFocusFor(ref, widget.source, widget.chart, tab),
    );
  }

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

  /// 1, 2, 3: the tab at [index] among those the lap admits.
  void _selectTab(int index) {
    final tabs = shownTraceTab(widget.chart, ref.read(traceTabProvider)).tabs;
    if (index < tabs.length) {
      ref.read(traceTabProvider.notifier).select(tabs[index]);
    }
  }

  /// Ctrl+Tab and Ctrl+Shift+Tab: the next tab either way, round.
  void _cycleTab(int direction) {
    final (:tabs, :shown) = shownTraceTab(
      widget.chart,
      ref.read(traceTabProvider),
    );
    final i = tabs.indexOf(shown);
    ref
        .read(traceTabProvider.notifier)
        .select(tabs[(i + direction) % tabs.length]);
  }

  Map<ShortcutActivator, VoidCallback> get _keys {
    void rate(int d) => ref.read(playbackProvider.notifier).stepRate(d);
    return {
      const SingleActivator(LogicalKeyboardKey.space): () =>
          ref.read(playbackProvider.notifier).toggle(),
      const SingleActivator(LogicalKeyboardKey.enter, control: true):
          _openDetail,
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): _openDetail,
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

  /// One press of + or -: what a notch of the wheel does.
  static const _zoomStep = 1.25;

  /// The line as the open tab's Colour by has it (§3.3). A corner quantity
  /// draws the pedals until the tab's channels are read, and where the lap
  /// lacks that channel.
  LapLineStyle _lineStyle(BuildContext context, LapChart chart) {
    final tab = shownTraceTab(chart, ref.watch(traceTabProvider)).shown;
    final choice = colourByOf(ref.watch(colourByProvider), tab.id);
    if (cornerQuantityOf(choice) case final quantity?) {
      final corners = ref
          .watch(lapCornerChartProvider(cornerChartKey(widget.source, chart)))
          .value;
      final path = corners?.colourPath(
        quantity,
        ref.watch(cornerFocusProvider),
      );
      if (path != null) {
        return LapLineStyle.ramp(
          context,
          path,
          role: quantity == CornerQuantity.brake
              ? ChannelRole.brake
              : ChannelRole.tyre,
        );
      }
    }
    return LapLineStyle.of(
      context,
      chart,
      colour: choice == colourByInputs || cornerQuantityOf(choice) != null
          ? LapLineColour.pedals
          : LapLineColour.channel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final sideWidth = ref.watch(
      appSettingsProvider.select((s) => s.sidePaneWidth),
    );
    final style = _lineStyle(context, chart);
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
        child: CallbackShortcuts(
          bindings: _keys,
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final side = size.width >= LapStage.sideDockBreakpoint;
                final open = side
                    ? sideWidth.clamp(
                        (size.width * 0.34).clamp(320.0, double.infinity),
                        size.width * 0.62,
                      )
                    : (size.height - _transportHeight - _margin * 3) * 0.55;
                final extent = _collapsed ? _rail : open.toDouble();
                return TweenAnimationBuilder<double>(
                  tween: Tween(end: extent),
                  // Under the pointer while resizing: an eased dock would
                  // trail the hand that moves it.
                  duration: _resizing
                      ? Duration.zero
                      : AppMotion.duration(context, AppDurations.slow),
                  curve: AppCurves.standard,
                  builder: (context, extent, _) => _layout(
                    size: size,
                    side: side,
                    extent: extent,
                    style: style,
                  ),
                );
              },
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
    required LapLineStyle style,
  }) {
    final chart = widget.chart;
    final hudWidth = (size.width - _margin * 2).clamp(0.0, _hudWidth);
    final obscured = side
        ? EdgeInsets.only(
            right: extent + _margin * 2,
            bottom: _transportHeight + _margin * 2,
          )
        // Under the sheet the map is short, and the HUD would cover the
        // car: the camera centres in the strip beside it instead, or, on a
        // window too narrow for a strip, in the band under it.
        : size.width - hudWidth - _margin * 2 >= _minStrip
        ? EdgeInsets.only(
            left: hudWidth + _margin * 2,
            bottom: extent + _transportHeight + _margin * 3,
          )
        : EdgeInsets.only(
            top: _hudHeight + _margin * 2,
            bottom: extent + _transportHeight + _margin * 3,
          );

    final dock = _Dock(
      source: widget.source,
      chart: chart,
      // The rail while folded, and while the dock is still too small for its
      // panels on the way open or shut: never a squeezed stack.
      collapsed: _collapsed || extent < (side ? 240 : 120),
      folded: _collapsed,
      side: side,
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

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerLowest),
        MapStage(
          path: chart.trackPath!,
          colouring: style.colouring,
          markers: chart.trackMarkers,
          alignment: chart.comparison == null ? null : chart.alignment,
          obscured: obscured,
          strokeWidth: 5,
          entrance: true,
          controller: _camera,
          minimap: true,
          speedZoom: ref.watch(appSettingsProvider.select((s) => s.speedZoom)),
          onSpeedZoom: ref.read(appSettingsProvider.notifier).setSpeedZoom,
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
                  stagger: const Duration(milliseconds: 120),
                  child: _SizeReport(
                    onHeight: (h) {
                      if (h != _hudHeight) setState(() => _hudHeight = h);
                    },
                    child: _Hud(
                      chart: chart,
                      legend: style.legend,
                      maxWidth: hudWidth,
                    ),
                  ),
                ),
              ),
              if (side)
                Positioned(
                  right: _margin,
                  top: _margin,
                  bottom: _transportHeight + _margin * 2,
                  width: extent,
                  child: StaggeredEntrance(
                    index: 1,
                    stagger: const Duration(milliseconds: 120),
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
              Positioned(
                left: _margin,
                right: _margin,
                bottom: _margin,
                height: _transportHeight,
                child: StaggeredEntrance(
                  index: 2,
                  stagger: const Duration(milliseconds: 120),
                  child: _Transport(chart: chart),
                ),
              ),
              // Along the foot of the clear map, over the scale bar and short
              // of the minimap.
              Positioned(
                left: obscured.left + _margin,
                right: obscured.right + _margin * 2 + MapMinimap.width,
                bottom: obscured.bottom + _margin + _scaleBarClearance,
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
double? _reading(ChartSyncState sync) => sync.probe ?? sync.playhead;

/// The lap, the comparison, live readings and the colouring, top left.
class _Hud extends ConsumerWidget {
  const _Hud({
    required this.chart,
    required this.legend,
    required this.maxWidth,
  });

  final LapChart chart;
  final Widget? legend;

  /// [_LapStageState._hudWidth], or less on a window narrower than that.
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
        grouped: true,
        radius: AppRadii.md,
        tint: 0.45,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LapSummaryBar(chart: chart),
            const SizedBox(height: 10),
            _LiveChips(chart: chart),
            if (chart.comparison?.note case final note?) ...[
              const SizedBox(height: 10),
              ComparisonNote(note: note),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Colour by',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                _ColourByMenu(chart: chart),
              ],
            ),
            if (legend case final legend?) ...[
              const SizedBox(height: 8),
              legend,
            ],
          ],
        ),
      ),
    );
  }
}

/// Speed, gear, throttle and brake where the panels read — GO Fast's driver
/// chips — each on a solid backing, so a number is never read against blur.
class _LiveChips extends ConsumerWidget {
  const _LiveChips({required this.chart});

  final LapChart chart;

  static const _roles = [
    ChannelRole.speed,
    ChannelRole.gear,
    ChannelRole.throttle,
    ChannelRole.brake,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final at = _reading(sync);
    final channels = ChannelColors.resolve(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final role in _roles)
          if (chart.panels.where((p) => p.role == role).firstOrNull
              case final panel?)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  const SizedBox(width: 6),
                  Text(
                    panel.title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 30),
                    child: Text(
                      switch (at == null ? null : panel.series.valueAt(at)) {
                        final value? => valueFormatter(panel)(value),
                        null => '—',
                      },
                      textAlign: TextAlign.right,
                      style: AppTextStyles.numeral.copyWith(fontSize: 12),
                    ),
                  ),
                  if (panel.unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      panel.unit,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

/// What the map's line is coloured by on the open tab: the pedals, or one
/// of the tab's channels.
class _ColourByMenu extends ConsumerWidget {
  const _ColourByMenu({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = shownTraceTab(chart, ref.watch(traceTabProvider)).shown;
    final selected = colourByOf(ref.watch(colourByProvider), tab.id);
    final corner = ref.watch(cornerFocusProvider);
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      key: const ValueKey('colour-by'),
      tooltip: 'What the line on the map is coloured by',
      initialValue: selected,
      onSelected: (choice) =>
          ref.read(colourByProvider.notifier).select(tab.id, choice),
      shape: AppRadii.squircle(AppRadii.sm),
      itemBuilder: (context) => [
        for (final choice in colourByChoicesFor(tab.id))
          CheckedPopupMenuItem(
            value: choice,
            checked: choice == selected,
            child: Text(colourByLabel(choice, corner: corner)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: ShapeDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: AppRadii.squircle(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              colourByLabel(selected, corner: corner),
              style: theme.textTheme.labelMedium,
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The traces, on glass: the tab bar, then the open tab's panels. Folds to
/// a rail; beside the map, its left edge resizes it.
class _Dock extends ConsumerWidget {
  const _Dock({
    required this.source,
    required this.chart,
    required this.collapsed,
    required this.folded,
    required this.side,
    required this.onToggle,
    required this.onResize,
  });

  final TelemetrySource source;
  final LapChart chart;

  /// Shows the rail: folded, or still too small to hold the panels.
  final bool collapsed;

  /// Folded by the user: what the toggle offers to undo.
  final bool folded;
  final bool side;
  final VoidCallback onToggle;
  final void Function(double dx, {required bool done})? onResize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:tabs, shown: selected) = shownTraceTab(
      chart,
      ref.watch(traceTabProvider),
    );
    final detail = traceTabDetails[selected.id];

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
          for (final tab in tabs)
            AppTooltip(
              message: tab.label,
              child: IconButton(
                onPressed: () {
                  ref.read(traceTabProvider.notifier).select(tab);
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
                  // All the free width, so the tabs keep their names
                  // wherever those fit.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: DockTabs(
                        tabs: tabs,
                        selected: selected,
                        onSelected: ref.read(traceTabProvider.notifier).select,
                      ),
                    ),
                  ),
                  if (detail != null)
                    LapFocusLink.lazy(
                      target: detail,
                      label: detail.label,
                      // The link gives up its words before the tabs do:
                      // their names are what says where the user is.
                      compact:
                          header.maxWidth <
                          tabs.length * DockTabs.labelledWidth + 6 + 300,
                      tooltip:
                          'This lap in ${detail.label}, at the playhead '
                          '(Ctrl+Enter)',
                      at: () => stageFocusFor(ref, source, chart, selected),
                    ),
                  const ZoomResetButton(),
                  toggle,
                ],
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppDurations.medium),
              child: KeyedSubtree(
                key: ValueKey(selected.id),
                child: _tabBody(selected),
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

  /// The open tab's panels. Each tab is a case here and a [TraceTab] in
  /// `stage_view.dart`.
  Widget _tabBody(TraceTab tab) => switch (tab.id) {
    'tyres' => TyresTab(source: source, chart: chart),
    'brakes' => BrakesTab(source: source, chart: chart),
    _ => LapPanelStack(chart: chart, footer: false),
  };
}

/// ▶, where the lap is, the gap at the playhead, and the axis.
class _Transport extends ConsumerWidget {
  const _Transport({required this.chart});

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
    final at = _reading(sync);
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
