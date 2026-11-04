/// The lap stage (map stage proposal §2, §9): Trace and Track map as one
/// screen. The map fills it; the HUD, the dock of traces and the play bar
/// float over it on glass.
///
/// The camera centres the car in the part of the map the dock leaves
/// visible, and glides when the dock moves. Below 1080 px the dock becomes
/// a sheet over the lower part of the map.
library;

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../settings/application/app_settings.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
import 'lap_view_controls.dart';
import 'lap_view_panes.dart';

class LapStage extends ConsumerStatefulWidget {
  const LapStage({super.key, required this.chart, this.dockCollapsed = false});

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

  late bool _collapsed = widget.dockCollapsed;
  bool _resizing = false;

  @override
  void didUpdateWidget(LapStage old) {
    super.didUpdateWidget(old);
    if (old.dockCollapsed != widget.dockCollapsed) {
      _collapsed = widget.dockCollapsed;
    }
  }

  void _toggleDock() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final chart = widget.chart;
    final sideWidth = ref.watch(
      appSettingsProvider.select((s) => s.sidePaneWidth),
    );
    final colourBy = ref.watch(colourByProvider);
    final style = LapLineStyle.of(
      context,
      chart,
      colour: colourBy == colourByInputs
          ? LapLineColour.pedals
          : LapLineColour.channel,
    );

    return PlaybackDriver(
      bounds: chart.bounds,
      distanceAxis: chart.distanceAxis,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.space): () =>
              ref.read(playbackProvider.notifier).toggle(),
        },
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
    );
  }

  Widget _layout({
    required Size size,
    required bool side,
    required double extent,
    required LapLineStyle style,
  }) {
    final chart = widget.chart;
    final obscured = side
        ? EdgeInsets.only(
            right: extent + _margin * 2,
            bottom: _transportHeight + _margin * 2,
          )
        // Under the sheet the map is short, and the HUD would cover the
        // car: the camera centres in the strip beside it instead.
        : EdgeInsets.only(
            left: _hudWidth + _margin * 2,
            bottom: extent + _transportHeight + _margin * 3,
          );

    final dock = _Dock(
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
                  child: _Hud(chart: chart, legend: style.legend),
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
            ],
          ),
        ),
      ],
    );
  }
}

/// Where the panels read: the probe while the pointer is over a trace or the
/// line, the playhead otherwise.
double? _reading(ChartSyncState sync) => sync.probe ?? sync.playhead;

/// The lap, the comparison, live readings and the colouring, top left.
class _Hud extends ConsumerWidget {
  const _Hud({required this.chart, required this.legend});

  final LapChart chart;
  final Widget? legend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _LapStageState._hudWidth),
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
                const _ColourByMenu(),
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

/// What the map's line is coloured by: the pedals, or one channel.
class _ColourByMenu extends ConsumerWidget {
  const _ColourByMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(colourByProvider);
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      key: const ValueKey('colour-by'),
      tooltip: 'What the line on the map is coloured by',
      initialValue: selected,
      onSelected: ref.read(colourByProvider.notifier).select,
      shape: AppRadii.squircle(AppRadii.sm),
      itemBuilder: (context) => [
        for (final choice in colourByChoices)
          CheckedPopupMenuItem(
            value: choice,
            checked: choice == selected,
            child: Text(colourByLabel(choice)),
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
            Text(colourByLabel(selected), style: theme.textTheme.labelMedium),
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
    required this.chart,
    required this.collapsed,
    required this.folded,
    required this.side,
    required this.onToggle,
    required this.onResize,
  });

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
    final tabs = admittedTabs(traceTabs, chart.telemetry.channels.keys.toSet());
    final selectedId = ref.watch(traceTabProvider);
    final selected = tabs.firstWhere(
      (t) => t.id == selectedId,
      orElse: () => tabs.first,
    );

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
            child: Row(
              children: [
                Flexible(
                  child: DockTabs(
                    tabs: tabs,
                    selected: selected,
                    onSelected: ref.read(traceTabProvider.notifier).select,
                  ),
                ),
                const Spacer(),
                const ZoomResetButton(),
                toggle,
              ],
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

  /// The open tab's panels. Inputs is today's stack; each later tab is a
  /// case here and a [TraceTab] in `stage_view.dart`.
  Widget _tabBody(TraceTab tab) => switch (tab.id) {
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
