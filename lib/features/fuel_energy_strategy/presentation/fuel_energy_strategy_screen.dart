import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/fl_chart_theme/per_lap_bar_chart.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/fuel_energy.dart';

/// Fuel & Energy Strategy (SPEC.md §8.7).
///
/// Leads with numbers rather than charts, because the question a driver
/// brings here is a number — how much a lap costs, and how many laps are
/// left — and a number that is the whole message is a tile, not a bar.
/// The per-lap charts below it are the evidence for those figures, and the
/// table under them holds every value the charts draw, so nothing on this
/// screen is readable only by hovering.
class FuelEnergyStrategyScreen extends ConsumerWidget {
  const FuelEnergyStrategyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Fuel & energy',
        subject: 'fuel and energy use',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fuel & energy')),
      body: AsyncValueView<FuelEnergyReport>(
        value: ref.watch(fuelEnergyReportProvider(source)),
        data: (context, report) => _Report(source: source, report: report),
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.source, required this.report});

  final TelemetrySource source;
  final FuelEnergyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ChannelColors.resolve(context);
    final origin = ref.watch(telemetryCatalogProvider(source)).value?.origin;
    final fuel = report.fuel;
    final energy = report.energy;
    final charge = report.stateOfCharge;

    final charts = [
      if (fuel != null)
        _UsageChart(
          title: 'Fuel used per lap',
          usage: fuel,
          color: channels.fuel,
        ),
      if (energy != null)
        _UsageChart(
          title: 'Virtual energy used per lap',
          usage: energy,
          color: channels.energy,
        ),
      if (charge != null)
        _ChargeChart(
          laps: (fuel ?? energy)?.laps.map((u) => u.lap).toList() ?? const [],
          stats: charge,
          color: channels.charge,
        ),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (fuel == null && energy == null)
          const _NoResources()
        else
          _Headline(report: report),
        const SizedBox(height: 20),
        // Two charts to a row where the window allows: they share a lap axis,
        // and reading one lap's fuel against its energy is the comparison
        // this screen exists for. Never one chart with two value axes — the
        // units differ, and a second scale would invent a correlation.
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 1000 ? 2 : 1;
            final width = (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final chart in charts)
                  SizedBox(width: width, child: chart),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        _PitLane(visits: report.pitVisits, origin: origin),
        if (fuel != null || energy != null) ...[
          const SizedBox(height: 20),
          _UsageTable(fuel: fuel, energy: energy),
        ],
      ],
    );
  }
}

/// `1.83 L`, `2.20 %` — two decimals, because a lap costs about 2 of either
/// and a tenth of that is exactly the difference between two stints' plans.
String _amount(double value, String unit) => unit.isEmpty
    ? value.toStringAsFixed(2)
    : '${value.toStringAsFixed(2)} $unit';

class _Headline extends StatelessWidget {
  const _Headline({required this.report});

  final FuelEnergyReport report;

  @override
  Widget build(BuildContext context) {
    final limiting = report.limiting;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final resource in [report.fuel, report.energy])
          if (resource != null) ...[
            StatTile(
              label: '${resource.name} per lap',
              value: switch (resource.averagePerLap) {
                final average? => _amount(average, resource.unit),
                null => '—',
              },
              caption: switch (resource.representative.length) {
                0 => 'no racing lap to average',
                1 => 'from 1 racing lap',
                final n => 'average of $n racing laps',
              },
            ),
            StatTile(
              label: '${resource.name} left',
              value: switch (resource.remaining) {
                final left? => _amount(left, resource.unit),
                null => '—',
              },
              caption: switch (resource.lapsRemaining) {
                final laps? => '≈ ${laps.toStringAsFixed(1)} laps at that rate',
                null => 'at the end of the recording',
              },
            ),
          ],
        if (limiting != null)
          StatTile(
            label: 'Runs out first',
            value: '${limiting.lapsRemaining!.toStringAsFixed(1)} laps',
            // Named in the caption rather than the value: the value is the
            // number to plan a stint around, and the resource is why.
            caption: '${limiting.name.toLowerCase()}, at '
                '${_amount(limiting.averagePerLap!, limiting.unit)} a lap',
            emphasised: true,
          ),
      ],
    );
  }
}

class _UsageChart extends StatelessWidget {
  const _UsageChart({
    required this.title,
    required this.usage,
    required this.color,
  });

  final String title;
  final ResourceUsage usage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final average = usage.averagePerLap;
    return _ChartCard(
      title: title,
      unit: usage.unit,
      caption: 'Grey laps are left out of the average — hover one to see why.',
      child: PerLapBarChart(
        color: color,
        formatValue: (value) => value.toStringAsFixed(2),
        reference: average,
        referenceLabel: average == null
            ? null
            : 'avg ${_amount(average, usage.unit)}',
        bars: [
          for (final lap in usage.laps)
            PerLapBar(
              lapNumber: lap.lap.displayNumber,
              // A refill is shown as its lap slot with no bar: its "usage" is
              // a large negative number that would flatten every real bar.
              value: lap.exclusion == UsageExclusion.refilled ? null : lap.used,
              muted: !lap.representative,
              note: lap.exclusion?.label,
            ),
        ],
      ),
    );
  }
}

/// A Hypercar's state-of-charge window per lap (§8.7) — the range each lap
/// used, lowest reading to highest, rather than a net change: a lap can end
/// where it started having deployed and recovered half the battery.
class _ChargeChart extends StatelessWidget {
  const _ChargeChart({
    required this.laps,
    required this.stats,
    required this.color,
  });

  final List<Lap> laps;
  final List<LapChannelStats> stats;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final byLap = {for (final s in stats) s.lapIndex: s};
    return _ChartCard(
      title: 'State of charge per lap',
      unit: '%',
      caption: 'Each bar spans the lowest to the highest reading of the lap.',
      child: PerLapBarChart(
        color: color,
        formatValue: (value) => value.toStringAsFixed(0),
        bars: [
          for (final lap in laps)
            PerLapBar(
              lapNumber: lap.displayNumber,
              from: byLap[lap.index]?.min,
              value: byLap[lap.index]?.max,
              muted: lap.isOutLap || lap.isOpenEnded,
              note: lap.isOutLap
                  ? 'out lap'
                  : lap.isOpenEnded
                      ? 'incomplete'
                      : null,
            ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.unit,
    required this.caption,
    required this.child,
  });

  final String title;
  final String unit;
  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(unit,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 8),
          Text(caption,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _PitLane extends StatelessWidget {
  const _PitLane({required this.visits, required this.origin});

  final List<PitVisit> visits;

  /// The recording's own t=0, so a visit reads as time into the session
  /// rather than as the file's arbitrary clock (§5.2).
  final double? origin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    String at(double seconds) => origin == null
        ? formatLapTime(seconds)
        : formatSessionTime(seconds, origin: origin!);

    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pit lane', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          if (visits.isEmpty)
            // The normal case for a race stint — the Race sample never went
            // in — so it is stated, not left as an empty card.
            Text(
              'No pit-lane visit recorded: the car stayed on track for the '
              'whole recording.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else
            for (final visit in visits)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.garage_outlined, size: 16, color: muted),
                    const SizedBox(width: 10),
                    Text(
                      visit.fromRecordingStart
                          ? 'From the start of the recording'
                          : 'In at ${at(visit.enteredSeconds)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      switch (visit.durationSeconds) {
                        null => '· still there when it ended',
                        final stay => '· out at ${at(visit.exitedSeconds!)} '
                            '(${stay.toStringAsFixed(1)} s)',
                      },
                      style: AppTextStyles.numeral
                          .copyWith(fontSize: 13, color: muted),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Every value the charts draw, as a table — the view that needs no hover and
/// no colour to read.
class _UsageTable extends StatelessWidget {
  const _UsageTable({required this.fuel, required this.energy});

  final ResourceUsage? fuel;
  final ResourceUsage? energy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final laps = (fuel ?? energy)!.laps.map((u) => u.lap).toList();
    LapUsage? usageOf(ResourceUsage? resource, int i) =>
        resource == null ? null : resource.laps[i];

    Widget numeral(String text, {required bool muted}) => Text(
          text,
          style: AppTextStyles.numeral
              .copyWith(color: muted ? scheme.onSurfaceVariant : null),
        );
    String value(double? v, String unit) => v == null ? '—' : _amount(v, unit);

    return SquircleCard(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: theme.textTheme.bodySmall,
              columns: [
                const DataColumn(label: Text('Lap')),
                if (fuel != null) ...[
                  const DataColumn(label: Text('Fuel used'), numeric: true),
                  const DataColumn(label: Text('Fuel at start'), numeric: true),
                ],
                if (energy != null) ...[
                  const DataColumn(label: Text('Energy used'), numeric: true),
                  const DataColumn(
                      label: Text('Energy at start'), numeric: true),
                ],
                const DataColumn(label: Text('Note')),
              ],
              rows: [
                for (var i = 0; i < laps.length; i++)
                  _row(i, laps[i], usageOf(fuel, i), usageOf(energy, i),
                      numeral, value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow _row(
    int i,
    Lap lap,
    LapUsage? fuelLap,
    LapUsage? energyLap,
    Widget Function(String, {required bool muted}) numeral,
    String Function(double?, String) value,
  ) {
    final exclusion = fuelLap?.exclusion ?? energyLap?.exclusion;
    final muted = exclusion != null;
    return DataRow(
      cells: [
        DataCell(numeral('${lap.displayNumber}', muted: muted)),
        if (fuel != null) ...[
          DataCell(numeral(value(fuelLap?.used, fuel!.unit), muted: muted)),
          DataCell(
              numeral(value(fuelLap?.levelAtStart, fuel!.unit), muted: muted)),
        ],
        if (energy != null) ...[
          DataCell(numeral(value(energyLap?.used, energy!.unit), muted: muted)),
          DataCell(numeral(value(energyLap?.levelAtStart, energy!.unit),
              muted: muted)),
        ],
        DataCell(Text(exclusion?.label ?? '')),
      ],
    );
  }
}

class _NoResources extends StatelessWidget {
  const _NoResources();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'This recording carries no usable fuel or virtual-energy channel.',
      style: theme.textTheme.titleMedium,
    );
  }
}
