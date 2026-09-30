import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../application/lap_incidents.dart';
import '../application/lap_trend.dart';
import 'incident_marks.dart';
import 'lap_trend_card.dart';

/// Lap Time Analysis (SPEC.md §8.3).
///
/// Reads top to bottom as a question narrowing: how fast and how consistent
/// (the tiles), how the laps trended and which were slow (the chart), and the
/// exact numbers and causes behind each lap (the table).
///
/// The table shows **every** lap, including the ones that aren't comparable —
/// the garage lap, invalidated laps, laps missing a sector, and the open final
/// lap. Hiding them would make the lap numbering jump for no visible reason,
/// and "why is lap 6 missing?" is a worse question than "why is lap 6 greyed
/// out?". Each is marked instead, and excluded from the statistics rather than
/// from the view.
///
/// **Choosing a lap here chooses it everywhere.** A row or a bar loads that lap
/// into the Trace view and the Track map — the same `SelectedLapIndex` their
/// own lap picker writes — and the lap they are showing is highlighted here,
/// which is the best lap until somebody picks another (§8.4). That is a
/// second cross-feature dependency, and like the first (track map on trace) it
/// is the application-level provider only and runs one way.
class LapAnalysisScreen extends ConsumerWidget {
  const LapAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) return const NoSessionScreen(title: 'Laps');

    return Scaffold(
      appBar: AppBar(title: const Text('Laps')),
      body: AsyncValueView<List<Lap>>(
        value: ref.watch(lapsProvider(source)),
        data: (context, laps) => laps.isEmpty
            ? const _NoLaps()
            : _LapAnalysis(source: source, laps: laps),
      ),
    );
  }
}

class _LapAnalysis extends HookConsumerWidget {
  const _LapAnalysis({required this.source, required this.laps});

  final TelemetrySource source;
  final List<Lap> laps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = useMemoized(() => LapTrend.derive(laps), [laps]);

    // Which lap the pointer is over, in either view. Ephemeral and shared by
    // exactly two siblings, so widget state rather than a provider (§9.3).
    final hovered = useState<int?>(null);

    // The events are a second, slower read behind the lap table. The table and
    // the chart do not wait for them: they draw at once and the marks arrive.
    final incidentsAsync = ref.watch(sessionIncidentsProvider(source));
    final incidents = incidentsAsync.value;

    final displayed = ref.watch(displayedLapProvider(source)).value;

    void select(int lapIndex) =>
        ref.read(selectedLapIndexProvider(source).notifier).select(lapIndex);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Summary(trend: trend, incidents: incidentsAsync),
        const SizedBox(height: 20),
        LapTrendCard(
          trend: trend,
          incidents: incidents,
          selectedLapIndex: displayed?.index,
          hoveredLapIndex: hovered.value,
          onSelect: select,
          onHover: (index) => hovered.value = index,
          onOpenInTrace: displayed == null
              // Without a router — a widget test — there is nowhere to go.
              ? null
              : () => GoRouter.maybeOf(context)?.go('/trace'),
        ),
        const SizedBox(height: 20),
        _LapTable(
          trend: trend,
          incidents: incidents,
          selectedLapIndex: displayed?.index,
          hoveredLapIndex: hovered.value,
          onSelect: select,
          onHover: (index) => hovered.value = index,
        ),
        const SizedBox(height: 16),
        _Footnotes(incidents: incidentsAsync),
      ],
    );
  }
}

/// The headline figures: pace, spread and what went wrong.
class _Summary extends StatelessWidget {
  const _Summary({required this.trend, required this.incidents});

  final LapTrend trend;
  final AsyncValue<SessionIncidents> incidents;

  @override
  Widget build(BuildContext context) {
    final best = trend.fastest;
    final median = trend.medianLapTimeSeconds;
    final medianDelta = trend.medianDeltaSeconds;
    final stdDev = trend.stdDevSeconds;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        StatTile(
          label: 'Fastest lap',
          value: best == null ? '—' : formatLapTime(best.lapTimeSeconds!),
          caption: best == null
              ? 'no lap was timed'
              : 'lap ${best.displayNumber}',
          emphasised: true,
        ),
        StatTile(
          label: 'Median lap',
          value: median == null ? '—' : formatLapTime(median),
          caption: switch (medianDelta) {
            null => 'no lap was timed',
            0 => 'as fast as the fastest',
            final delta => '${formatDelta(delta)} s behind the fastest',
          },
        ),
        StatTile(
          label: 'Consistency',
          value: stdDev == null ? '—' : '±${stdDev.toStringAsFixed(3)} s',
          caption: stdDev == null
              ? 'needs two timed laps'
              : 'std. deviation of ${trend.timedCount} laps',
        ),
        _IncidentsTile(incidents: incidents),
      ],
    );
  }
}

class _IncidentsTile extends StatelessWidget {
  const _IncidentsTile({required this.incidents});

  final AsyncValue<SessionIncidents> incidents;

  @override
  Widget build(BuildContext context) {
    const label = 'Incidents';
    return incidents.when(
      loading: () => const StatTile(
        label: label,
        value: '…',
        caption: 'reading the recording’s events',
      ),
      error: (error, _) => const StatTile(
        label: label,
        value: '—',
        caption: 'the events could not be read',
      ),
      data: (data) {
        if (data.hasNoEvents) {
          return const StatTile(
            label: label,
            value: '—',
            caption: 'this recording has no incident events',
          );
        }
        if (data.isEmpty) {
          return const StatTile(
            label: label,
            value: 'None',
            caption: 'no impact, yellow flag or lost wheel',
          );
        }
        String laps(int n) => '$n ${n == 1 ? 'lap' : 'laps'}';
        return StatTile(
          label: label,
          value: laps(data.byLap.length),
          caption: [
            if (data.impactCount > 0)
              '${data.impactCount} ${data.impactCount == 1 ? 'impact' : 'impacts'}',
            if (data.lapsUnderYellow > 0)
              'yellow on ${laps(data.lapsUnderYellow)}',
            if (data.lapsWithDetachedWheel > 0)
              'wheel off on ${laps(data.lapsWithDetachedWheel)}',
          ].join(', '),
        );
      },
    );
  }
}

class _LapTable extends StatelessWidget {
  const _LapTable({
    required this.trend,
    required this.incidents,
    required this.selectedLapIndex,
    required this.hoveredLapIndex,
    required this.onSelect,
    required this.onHover,
  });

  final LapTrend trend;
  final SessionIncidents? incidents;
  final int? selectedLapIndex;
  final int? hoveredLapIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int?> onHover;

  @override
  Widget build(BuildContext context) {
    final laps = [for (final t in trend.laps) t.lap];
    final best = trend.fastest;
    final bestSectors = _bestSectors(laps);

    return SquircleCard(
      // Horizontal scroll on the table only, so a narrow window never makes
      // the whole page scroll sideways. The table stretches to whatever
      // width it's given rather than subtracting the shell's nav rail: a
      // screen that hardcodes its own chrome's dimensions breaks the moment
      // that chrome changes, and LayoutBuilder already knows the answer.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: Theme.of(context).textTheme.bodySmall,
              // A row is tapped to be chosen, not ticked: the checkbox column
              // a selectable table adds would be a second way to say the same
              // thing.
              showCheckboxColumn: false,
              // Tighter than the default 56: with two chip columns the table
              // otherwise scrolls sideways at the narrow end of the range,
              // hiding the very note column that says why a lap is greyed.
              columnSpacing: 28,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('Lap')),
                DataColumn(label: Text('Time'), numeric: true),
                DataColumn(label: Text('Δ best'), numeric: true),
                DataColumn(label: Text('S1'), numeric: true),
                DataColumn(label: Text('S2'), numeric: true),
                DataColumn(label: Text('S3'), numeric: true),
                DataColumn(label: Text('Incidents')),
                DataColumn(label: Text('Note')),
              ],
              rows: [
                for (final lap in laps)
                  _lapRow(context, lap, best: best, bestSectors: bestSectors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static List<double?> _bestSectors(List<Lap> laps) {
    final bests = List<double?>.filled(3, null);
    for (final lap in laps.timed) {
      final sectors = lap.sectors.all;
      for (var i = 0; i < 3; i++) {
        final value = sectors[i];
        if (value != null && (bests[i] == null || value < bests[i]!)) {
          bests[i] = value;
        }
      }
    }
    return bests;
  }

  DataRow _lapRow(
    BuildContext context,
    Lap lap, {
    required Lap? best,
    required List<double?> bestSectors,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isBest = best != null && identical(lap, best);
    final muted = !lap.isTimed;
    final isSelected = lap.index == selectedLapIndex;
    final isHovered = lap.index == hoveredLapIndex;

    final delta = (lap.lapTimeSeconds != null && best?.lapTimeSeconds != null)
        ? lap.lapTimeSeconds! - best!.lapTimeSeconds!
        : null;

    Widget numeral(String text, {Color? color, bool bold = false}) => Text(
      text,
      style: AppTextStyles.numeral.copyWith(
        color: color ?? (muted ? scheme.onSurfaceVariant : null),
        fontWeight: bold ? FontWeight.w600 : null,
      ),
    );

    Widget sector(double? value, int index) {
      final isBestSector =
          value != null &&
          bestSectors[index] != null &&
          value == bestSectors[index];
      return numeral(
        formatOptionalSectorTime(value),
        color: isBestSector ? scheme.tertiary : null,
        bold: isBestSector,
      );
    }

    final marks = incidents == null
        ? const <IncidentMark>[]
        : incidentMarks(scheme, lap, incidents!.of(lap));

    return DataRow(
      selected: isSelected,
      onSelectChanged: (_) => onSelect(lap.index),
      // Mirrors the pointer to the chart, and takes the chart's pointer back.
      onHover: (hovering) {
        if (hovering) {
          onHover(lap.index);
        } else if (hoveredLapIndex == lap.index) {
          onHover(null);
        }
      },
      // The lap the Trace is showing outranks the best lap's tint, which is
      // otherwise the same row on entry (the default lap *is* the best one)
      // and would make the two indistinguishable the moment another is chosen.
      color: WidgetStateProperty.resolveWith((states) {
        if (isSelected) return scheme.primary.withValues(alpha: 0.16);
        if (isHovered || states.contains(WidgetState.hovered)) {
          return scheme.onSurface.withValues(alpha: 0.06);
        }
        if (isBest) return scheme.primaryContainer.withValues(alpha: 0.3);
        return null;
      }),
      cells: [
        // +1, or every lap would read one lower than the driver's own count.
        DataCell(numeral('${lap.displayNumber}', bold: isSelected)),
        DataCell(
          numeral(
            formatOptionalLapTime(lap.lapTimeSeconds),
            color: isBest ? scheme.primary : null,
            bold: isBest,
          ),
        ),
        DataCell(
          numeral(delta == null ? '—' : (isBest ? '—' : formatDelta(delta))),
        ),
        DataCell(sector(lap.sectors.sector1Seconds, 0)),
        DataCell(sector(lap.sectors.sector2Seconds, 1)),
        DataCell(sector(lap.sectors.sector3Seconds, 2)),
        DataCell(_IncidentBadges(marks: marks)),
        DataCell(_LapNote(lap: lap)),
      ],
    );
  }
}

/// What went wrong on a lap: an icon and a word per incident, with the full
/// story in the tooltip.
///
/// A word beside every icon rather than an icon alone, so the table reads
/// without hovering (§9.5) and the cell is findable by its text.
class _IncidentBadges extends StatelessWidget {
  const _IncidentBadges({required this.marks});

  final List<IncidentMark> marks;

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox.shrink();

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // The events arrive after the table has drawn, so a badge appears on a
    // row that was quiet a moment ago. A short fade and lift, once, tells the
    // eye something arrived rather than that the layout jumped.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppDurations.slow,
      curve: AppCurves.entrance,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 4),
          child: child,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final mark in marks)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: mark.tooltip,
                child: Chip(
                  avatar: Icon(mark.icon, size: 16, color: mark.color),
                  label: Text(
                    mark.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: mark.color.withValues(alpha: 0.10),
                  side: BorderSide(color: mark.color.withValues(alpha: 0.45)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Says *why* a lap isn't comparable, rather than leaving a blank row.
class _LapNote extends StatelessWidget {
  const _LapNote({required this.lap});

  final Lap lap;

  @override
  Widget build(BuildContext context) {
    final (label, tooltip) = _describe(lap);
    if (label == null) return const SizedBox.shrink();

    return Tooltip(
      message: tooltip!,
      child: Chip(
        label: Text(label, style: Theme.of(context).textTheme.bodySmall),
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  static (String?, String?) _describe(Lap lap) {
    final exclusion = LapExclusion.of(lap);
    if (exclusion != null) return (exclusion.label, exclusion.explanation);
    if (!lap.sectors.isComplete) {
      return (
        'partial sectors',
        'The lap time is valid, but the recording is missing at least one '
            'sector split for it.',
      );
    }
    return (null, null);
  }
}

/// The small print under the table, including what the incident events
/// cannot say.
class _Footnotes extends StatelessWidget {
  const _Footnotes({required this.incidents});

  final AsyncValue<SessionIncidents> incidents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    final lines = <String>[
      'Sector 2 and 3 are derived: the recording stores sector 2 as a '
          'cumulative split, and carries no sector 3 value at all.',
      'The highlighted lap is the one the Trace and Track map are showing; '
          'click any lap to load it there.',
      ...incidents.when(
        loading: () => const <String>[],
        error: (error, _) => ['Incidents could not be read: $error'],
        data: (data) => [
          if (data.unavailable.isNotEmpty && !data.hasNoEvents)
            'This recording has no ${data.unavailable.join(' or ')} event, so '
                'that kind of incident cannot be shown.',
          if (!data.unavailable.contains(impactEventName))
            'Impacts are counted from changes in the game’s '
                'LastImpactMagnitude flag. It records that contact happened, '
                'not how hard, so a tap and a crash look alike — and it can '
                'only count impacts that changed the flag.',
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: style),
          ),
      ],
    );
  }
}

class _NoLaps extends StatelessWidget {
  const _NoLaps();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This session recorded no laps.',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
