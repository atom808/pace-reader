import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driver_comparison/presentation/open_in_compare_button.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/lap_chart.dart';
import '../application/lap_selection.dart';
import 'lap_view_controls.dart';
import 'lap_stage.dart';
import 'lap_view_panes.dart';

/// Trace (SPEC.md §8.4, §8.5): the lap stage — the track map filling the
/// screen, the car on it at the playhead, and the trace panels in a dock
/// beside it on the same playhead (map stage proposal §2). Track map is
/// this screen with the dock folded.
///
/// Stacked single-channel panels sharing one axis, one viewport and one
/// playhead with each other and with the map — the shape both reference
/// apps converge on (§7.1) and the reason §9.5 built a custom chart core
/// instead of reaching for a chart library.
///
/// One channel per panel, deliberately. Overlaying channels of different
/// units on one pair of axes is the single most common way a telemetry chart
/// misleads: two signals with unrelated scales share a baseline, and the
/// crossings a reader sees are artefacts of the scaling. Stacked panels
/// against a shared x-axis say the same thing without inventing any of it.
class TelemetryTraceScreen extends ConsumerWidget {
  const TelemetryTraceScreen({super.key, this.dockCollapsed = false});

  /// Opens on the map alone, the traces folded to a rail: the Track map
  /// entry, which is this screen (map stage proposal §9).
  final bool dockCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Telemetry trace',
        subject: 'the trace view',
      );
    }
    return _TraceScaffold(source: source, dockCollapsed: dockCollapsed);
  }
}

class _TraceScaffold extends ConsumerWidget {
  const _TraceScaffold({required this.source, required this.dockCollapsed});

  final TelemetrySource source;
  final bool dockCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lap = ref.watch(displayedLapProvider(source));
    final reference = ref.watch(referenceLapIndexProvider(source));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trace'),
        actions: [
          LapPicker(source: source, selected: lap.value),
          ReferencePicker(source: source, displayed: lap.value),
          const SizedBox(width: 4),
          OpenInCompareButton(source: source, displayed: lap.value),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<Lap?>(
        value: lap,
        data: (context, lap) => lap == null
            ? const _NoLaps()
            : _LapTrace(
                source: source,
                lapIndex: lap.index,
                referenceIndex: comparedReferenceIndex(reference, lap.index),
                dockCollapsed: dockCollapsed,
              ),
      ),
    );
  }
}

class _LapTrace extends ConsumerWidget {
  const _LapTrace({
    required this.source,
    required this.lapIndex,
    required this.referenceIndex,
    required this.dockCollapsed,
  });

  final TelemetrySource source;
  final int lapIndex;
  final int? referenceIndex;
  final bool dockCollapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The cursor and zoom are this lap's. A different lap or session is a
    // new owner, and the claim clears them for it; the track map claims the
    // same owner for the same lap, so moving between the two keeps them.
    return SyncOwner(
      owner: LapRef(source, lapIndex),
      child: AsyncValueView<LapChart>(
        value: ref.watch(lapChartProvider(source, lapIndex, referenceIndex)),
        data: (context, chart) => chart.panels.isEmpty
            ? const _NoChannels()
            : chart.hasTrackMap
            ? LapStage(chart: chart, dockCollapsed: dockCollapsed)
            : _TraceBody(chart: chart),
      ),
    );
  }
}

/// The traces alone: a lap with no position to put on a map.
class _TraceBody extends StatelessWidget {
  const _TraceBody({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Wrap rather than a Row: on a narrow window the summary and the
        // controls together exceed the width, and dropping the controls to
        // a second line beats clipping one off the edge.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              LapSummaryBar(chart: chart),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [AxisToggle(chart: chart), const ZoomResetButton()],
              ),
            ],
          ),
        ),
        if (chart.comparison?.note case final note?)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: ComparisonNote(note: note),
          ),
        const Divider(height: 1),
        Expanded(child: LapPanelStack(chart: chart)),
      ],
    );
  }
}

class _NoLaps extends StatelessWidget {
  const _NoLaps();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'This session recorded no laps to trace.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

class _NoChannels extends StatelessWidget {
  const _NoChannels();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No traceable channels in this lap',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The recording carries none of the channels this view plots, or '
              'none of them have samples inside this lap.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
