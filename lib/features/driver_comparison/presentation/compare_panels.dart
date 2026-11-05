/// Compare's panels, shared by its stage and by the plain layout a lap
/// without a map gets: the trace stack with the Line panel's notes, the
/// chips, and the Why · Sectors · Tyres card (comparison proposal §3, §6).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../telemetry_trace/presentation/lap_view_panes.dart';
import '../application/comparison_chart.dart';
import '../application/lap_conditions.dart';
import '../application/segment_tables.dart';
import '../domain/lines.dart';
import 'comparability_strip.dart';
import 'compare_stage.dart' show TimeReadoutBar;
import 'gap_split_card.dart';
import 'sector_table.dart';
import 'tyres_this_lap.dart';
import 'why_card.dart';

/// Base's and the Target's traces, one panel per channel, the Line panel
/// with its note, and on the Time axis the readout pinned under them: it
/// answers for wherever the cursor is, so it never scrolls away.
class ComparePanelStack extends StatelessWidget {
  const ComparePanelStack({super.key, required this.view, this.footer = true});

  final ComparisonView view;

  /// The stack's own axis footer; off where the stage draws one.
  final bool footer;

  /// The least height that holds the readout and a panel above it.
  static const _readoutRoom = 140.0;

  @override
  Widget build(BuildContext context) {
    final chart = view.chart!;
    if (chart.panels.isEmpty) {
      return const Center(child: Text('No traceable channels in this lap.'));
    }
    final stack = LapPanelStack(
      chart: chart,
      footer: footer,
      below: (panel) => switch (panel.role) {
        ChannelRole.line => const LineToggle(),
        ChannelRole.steering =>
          view.line?.withheld == null
              ? null
              : LineWithheld(reason: view.line!.withheld!),
        _ => null,
      },
    );
    final map = view.map;
    if (map == null || chart.axis != TraceAxis.time) return stack;
    // Where a phone-width sheet leaves the stack almost no height, the
    // readout gives way: the HUD's chips still read at the cursor.
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: stack),
          if (constraints.maxHeight >= _readoutRoom) ...[
            const Divider(height: 1),
            TimeReadoutBar(map: map),
          ],
        ],
      ),
    );
  }
}

/// Under the Line panel: what it shows, and the switch to each lap's own
/// `Path Lateral` (comparison proposal §6).
class LineToggle extends ConsumerWidget {
  const LineToggle({super.key});

  static const _besideWidth = 520.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw = ref.watch(linePanelRawProvider);
    final words = Text(
      raw
          ? "Each lap's Path Lateral: metres from the centre path, + = right."
          : 'Target against Base, + = Target further right. The band is the '
                '${lineFloor.toStringAsFixed(1)} m floor: differences inside '
                'it are not stated.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final button = TextButton(
      onPressed: () => ref.read(linePanelRawProvider.notifier).toggle(),
      child: Text(raw ? 'Show the difference' : 'Show raw Path Lateral'),
    );
    // In the stage's dock the words take the width and the button goes
    // under them; beside them it would squeeze them to a word a line.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < _besideWidth
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [words, button],
              )
            : Row(
                children: [
                  Expanded(child: words),
                  button,
                ],
              ),
      ),
    );
  }
}

/// Where the Line panel would be, when it is not shown: why.
class LineWithheld extends StatelessWidget {
  const LineWithheld({super.key, required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No Line panel: $reason.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The chart's chips, then each lap's conditions and setup once they are
/// read (§7): they are not needed to draw either lap, so they never hold the
/// chart up.
class CompareStrip extends ConsumerWidget {
  const CompareStrip({super.key, required this.view, this.oneLine = false});

  final ComparisonView view;

  /// See [ComparabilityStrip.oneLine].
  final bool oneLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = view.chart?.comparison == null
        ? null
        : ref.watch(comparisonConditionsProvider(view.set)).value;
    return ComparabilityStrip(
      chips: [...view.chips, ...?conditions],
      oneLine: oneLine,
    );
  }
}

/// Why, Sectors and Tyres (§3): in the stage's drawer, or under the map.
class CompareDetailTabs extends StatelessWidget {
  const CompareDetailTabs({
    super.key,
    required this.view,
    required this.segments,
  });

  final ComparisonView view;
  final ComparisonSegments? segments;

  @override
  Widget build(BuildContext context) {
    final chart = view.chart!;
    final segments = this.segments;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Why'),
              Tab(text: 'Sectors'),
              Tab(text: 'Tyres'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: segments == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GapSplitCard(set: view.set),
                            const SizedBox(height: 16),
                            WhyCard(
                              set: view.set,
                              segments: segments,
                              view: view,
                            ),
                          ],
                        ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: SectorTable(
                    base: chart.lap,
                    target: chart.comparison!.reference,
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: TyresThisLap(set: view.set),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
