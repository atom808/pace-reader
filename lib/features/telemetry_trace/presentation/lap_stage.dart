/// The lap stage (map stage proposal §2, §9): Trace and Track map as one
/// screen, in the shared [StageFrame]. What is Trace's own lives here: the
/// line's colouring by the open tab, the HUD, the tabs and their detail
/// links.
library;

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_surface.dart';
import '../../lap_focus/lap_focus.dart';
import '../../lap_focus/lap_focus_link.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/corner_chart.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
import '../application/trace_focus.dart';
import 'channel_tabs.dart';
import 'corner_tabs.dart';
import 'lap_view_controls.dart';
import 'lap_view_panes.dart';
import 'stage_frame.dart';

class LapStage extends ConsumerWidget {
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

  /// Ctrl+Enter: the open tab's detail screen, at the playhead.
  void _openDetail(BuildContext context, WidgetRef ref) {
    final tab = shownTraceTab(chart, ref.read(traceTabProvider)).shown;
    final target = traceTabDetails[tab.id];
    if (target == null) return;
    openFocus(context, ref, target, stageFocusFor(ref, source, chart, tab));
  }

  /// The line as the open tab's Colour by has it (§3.3). A corner quantity
  /// draws the pedals until the tab's channels are read, and where the lap
  /// lacks that channel.
  LapLineStyle _lineStyle(BuildContext context, WidgetRef ref) {
    final tab = shownTraceTab(chart, ref.watch(traceTabProvider)).shown;
    final choice = colourByOf(ref.watch(colourByProvider), tab.id);
    if (cornerQuantityOf(choice) case final quantity?) {
      final corners = ref
          .watch(lapCornerChartProvider(cornerChartKey(source, chart)))
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
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _lineStyle(context, ref);
    final (:tabs, shown: selected) = shownTraceTab(
      chart,
      ref.watch(traceTabProvider),
    );
    final detail = traceTabDetails[selected.id];
    void openDetail() => _openDetail(context, ref);
    // The tabs laid out by corner light the one they follow on the car, in
    // the colour of what they read (P9c).
    final channels = ChannelColors.resolve(context);
    final wheelColour = switch (selected) {
      tyresTab => channels.tyre,
      brakesTab => channels.brake,
      suspensionTab => Theme.of(context).colorScheme.primary,
      _ => null,
    };
    final surfaces = _Surfaces.of(context, ref, source, chart);
    return StageFrame(
      chart: chart,
      source: source,
      dockCollapsed: dockCollapsed,
      map: StageMapSpec(
        colouring: style.colouring,
        alignment: chart.comparison == null ? null : chart.alignment,
        litWheel: wheelColour == null ? null : ref.watch(cornerFocusProvider),
        wheelColour: wheelColour,
        underlays: [?surfaces?.layer],
        pulse: ref.watch(stageArrivalProvider),
        onPulsed: ref.read(stageArrivalProvider.notifier).settle,
      ),
      hud: _Hud(chart: chart, legend: style.legend, surfaces: surfaces?.legend),
      keys: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            openDetail,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): openDetail,
      },
      dock: (side) => StageDockSpec(
        tabs: tabs,
        selected: selected,
        onSelect: ref.read(traceTabProvider.notifier).select,
        body: (tab) => switch ((tab.id, channelSetOf(tab.id))) {
          ('tyres', _) => TyresTab(source: source, chart: chart),
          ('brakes', _) => BrakesTab(source: source, chart: chart),
          (_, final set?) => ChannelTab(source: source, chart: chart, set: set),
          _ => LapPanelStack(chart: chart, footer: false),
        },
        trailing: (width) => [
          if (detail != null)
            LapFocusLink.lazy(
              target: detail,
              label: detail.label,
              // The link gives up its words before the tabs do: their names
              // are what says where the user is.
              compact: width < tabs.length * DockTabs.labelledWidth + 6 + 300,
              tooltip:
                  'This lap in ${detail.label}, at the playhead (Ctrl+Enter)',
              at: () => stageFocusFor(ref, source, chart, selected),
            ),
        ],
      ),
    );
  }
}

/// The lap, the comparison, live readings and the colouring.
/// Where the lap ran over kerbs and off the track (map stage P9d): cased
/// under its line, and keyed in the HUD.
class _Surfaces {
  const _Surfaces._(this.layer, this.legend);

  /// Null for a lap that stayed on the asphalt, a file without
  /// `SurfaceTypes`, or while it is read.
  static _Surfaces? of(
    BuildContext context,
    WidgetRef ref,
    TelemetrySource source,
    LapChart chart,
  ) {
    final path = chart.trackPath;
    final stretches = ref
        .watch(lapSurfaceProvider((source, chart.lap.index)))
        .value;
    if (path == null || stretches == null || stretches.isEmpty) return null;
    List<(double, double)> on(TrackSurface surface) => [
      for (final s in stretches)
        if (s.surface == surface)
          if ((chart.domainOf(s.startSeconds), chart.domainOf(s.endSeconds))
              case (final start?, final end?))
            (start, end),
    ];
    final kerbs = on(TrackSurface.kerb);
    final offTrack = on(TrackSurface.offTrack);
    final kerbColour = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.8);
    final offTrackColour = AppColors.trackOffTrack.withValues(alpha: 0.8);
    return _Surfaces._(
      SurfaceLayer(
        path: path,
        kerbs: kerbs,
        offTrack: offTrack,
        kerbColour: kerbColour,
        offTrackColour: offTrackColour,
        width: StageFrame.lineWidth,
      ),
      SurfaceLegend(
        kerbColour: kerbColour,
        offTrackColour: offTrackColour,
        kerbs: kerbs.length,
        offTrack: offTrack.length,
      ),
    );
  }

  final SurfaceLayer layer;
  final Widget legend;
}

class _Hud extends StatelessWidget {
  const _Hud({required this.chart, required this.legend, this.surfaces});

  final LapChart chart;
  final Widget? legend;

  /// The key to the kerbs and off-track under the line.
  final Widget? surfaces;

  /// Narrower than this, a phone's, the HUD is a compact lap card (map stage
  /// P9e): the lap's time and the colouring on one row, the live readings
  /// without their names on the next, and the keys left to the menu's
  /// words. The map keeps the rest of the screen.
  static const compactBelow = 380.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < compactBelow
        ? _compact(context)
        : _full(context),
  );

  Widget _compact(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: LapSummaryBar(chart: chart, compact: true)),
          const SizedBox(width: 8),
          _ColourByMenu(chart: chart),
        ],
      ),
      const SizedBox(height: 8),
      StageLiveChips(chart: chart, compact: true),
      if (chart.comparison?.note case final note?) ...[
        const SizedBox(height: 8),
        ComparisonNote(note: note),
      ],
    ],
  );

  Widget _full(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LapSummaryBar(chart: chart),
        const SizedBox(height: 10),
        StageLiveChips(chart: chart),
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
        if (legend case final legend?) ...[const SizedBox(height: 8), legend],
        if (surfaces case final surfaces?) ...[
          const SizedBox(height: 8),
          surfaces,
        ],
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
