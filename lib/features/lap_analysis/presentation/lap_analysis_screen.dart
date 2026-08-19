import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';

/// Lap Time Analysis (SPEC.md §8.3).
///
/// The table shows **every** lap, including the ones that aren't comparable —
/// the garage lap, invalidated laps, laps missing a sector, and the open final
/// lap. Hiding them would make the lap numbering jump for no visible reason,
/// and "why is lap 6 missing?" is a worse question than "why is lap 6 greyed
/// out?". Each is marked instead, and excluded from the statistics rather than
/// from the view.
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
        data: (context, laps) =>
            laps.isEmpty ? const _NoLaps() : _LapTable(laps: laps),
      ),
    );
  }
}

class _LapTable extends StatelessWidget {
  const _LapTable({required this.laps});

  final List<Lap> laps;

  @override
  Widget build(BuildContext context) {
    final best = laps.bestLap;
    final bestSectors = _bestSectors(laps);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Horizontal scroll on the table only, so a narrow window never makes
        // the whole page scroll sideways. The table stretches to whatever
        // width it's given rather than subtracting the shell's nav rail: a
        // screen that hardcodes its own chrome's dimensions breaks the moment
        // that chrome changes, and LayoutBuilder already knows the answer.
        LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingTextStyle: Theme.of(context).textTheme.bodySmall,
                columns: const [
                  DataColumn(label: Text('Lap')),
                  DataColumn(label: Text('Time'), numeric: true),
                  DataColumn(label: Text('Δ best'), numeric: true),
                  DataColumn(label: Text('S1'), numeric: true),
                  DataColumn(label: Text('S2'), numeric: true),
                  DataColumn(label: Text('S3'), numeric: true),
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
        const SizedBox(height: 16),
        Text(
          'Sector 2 and 3 are derived: the recording stores sector 2 as a '
          'cumulative split, and carries no sector 3 value at all.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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

    return DataRow(
      color: isBest
          ? WidgetStatePropertyAll(
              scheme.primaryContainer.withValues(alpha: 0.3),
            )
          : null,
      cells: [
        // +1, or every lap would read one lower than the driver's own count.
        DataCell(numeral('${lap.displayNumber}')),
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
        DataCell(_LapNote(lap: lap)),
      ],
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
    if (lap.isOutLap) {
      return (
        'out lap',
        'Starts in the garage rather than at the start/finish line, so its '
            'time is not comparable with a flying lap.',
      );
    }
    if (lap.isOpenEnded) {
      return (
        'incomplete',
        'The recording ended before this lap finished, so it has no time.',
      );
    }
    if (lap.lapTimeSeconds == null) {
      return (
        'no time',
        'The game recorded no time for this lap — usually an invalidated lap.',
      );
    }
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
