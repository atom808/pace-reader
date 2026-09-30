/// The stint view: one quantity, four corners, every lap (SPEC.md §8.6).
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/fl_chart_theme/per_lap_bar_chart.dart';
import '../../../widgets/fl_chart_theme/per_lap_trend_chart.dart';
import '../application/tire_brake_report.dart';
import 'tyre_format.dart';

/// Brake temperature is drawn in the brake identity colour, every tyre
/// quantity in the tyre one (§9.7.1: one colour per channel type).
Color metricColor(BuildContext context, TyreMetric metric) {
  final channels = ChannelColors.resolve(context);
  return metric == TyreMetric.brake ? channels.brake : channels.tyre;
}

/// What each metric's trend plots, said under the charts.
String metricCaption(TyreMetric metric) => switch (metric) {
      TyreMetric.pressure =>
        'Lap mean, with the lap’s lowest to highest reading as the band.',
      TyreMetric.tread =>
        'Mean of the inner, centre and outer zones; the band spans the '
            'coolest to the hottest zone reading of the lap.',
      TyreMetric.carcass =>
        'Lap mean, with the lap’s lowest to highest reading as the band.',
      TyreMetric.wear => 'Tread used per lap: the reading at the lap’s start '
          'minus the reading at the next lap’s start.',
      TyreMetric.brake =>
        'Lap mean, with the band from the coolest reading on a straight to '
            'the peak under braking.',
    };

/// Four small multiples in the car's own layout, on one shared scale.
class CornerTrends extends StatelessWidget {
  const CornerTrends({
    super.key,
    required this.report,
    required this.metric,
    required this.selectedLap,
  });

  final TireBrakeReport report;
  final TyreMetric metric;
  final Lap? selectedLap;

  @override
  Widget build(BuildContext context) {
    final range = report.sharedRange(metric);
    final color = metricColor(context, metric);

    Widget chart(Corner corner) {
      final series = report.series(metric, corner);
      if (metric == TyreMetric.wear) {
        return PerLapBarChart(
          height: 150,
          color: color,
          maxValue: range?.max,
          formatValue: (v) => '${formatMetric(metric, v)} %',
          bars: [
            for (final point in series)
              PerLapBar(
                lapNumber: point.lap.displayNumber,
                value: point.value,
                muted: point.muted,
                note: point.exclusion == null
                    ? null
                    : exclusionLabel(point.exclusion!),
              ),
          ],
        );
      }
      return PerLapTrendChart(
        height: 150,
        color: color,
        minY: range?.min,
        maxY: range?.max,
        highlightLap: selectedLap?.displayNumber,
        formatValue: (v) => formatWithUnit(metric, v),
        points: [
          for (final point in series)
            PerLapTrendPoint(
              lapNumber: point.lap.displayNumber,
              value: point.value,
              low: point.low,
              high: point.high,
              muted: point.muted,
              note: point.exclusion == null
                  ? null
                  : exclusionLabel(point.exclusion!),
            ),
        ],
      );
    }

    Widget card(Corner corner) => _TrendCard(
          corner: corner,
          unit: metric.unit,
          child: chart(corner),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two to a row, nose up, like the cards above — the charts are the
        // same four corners over time, so they keep the same places.
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              for (final corner in Corner.values) ...[
                card(corner),
                const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final axle in [
              [Corner.frontLeft, Corner.frontRight],
              [Corner.rearLeft, Corner.rearRight],
            ]) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: card(axle[0])),
                  const SizedBox(width: 12),
                  Expanded(child: card(axle[1])),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.corner,
    required this.unit,
    required this.child,
  });

  final Corner corner;
  final String unit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(corner.short, style: theme.textTheme.titleSmall),
              const SizedBox(width: 6),
              Text(corner.label,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              const Spacer(),
              Text(unit,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Every value the charts draw, lap by lap — the view that needs no hover
/// and no colour to read (§9.5). Tapping a row shows that lap on the cards.
class MetricTable extends StatelessWidget {
  const MetricTable({
    super.key,
    required this.report,
    required this.metric,
    required this.selectedLap,
    required this.onSelectLap,
  });

  final TireBrakeReport report;
  final TyreMetric metric;
  final Lap? selectedLap;
  final ValueChanged<Lap> onSelectLap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final byCorner = {
      for (final corner in Corner.values) corner: report.series(metric, corner),
    };
    final laps = byCorner[Corner.frontLeft]!.map((p) => p.lap).toList();

    String? tread(Corner corner, Lap lap) {
      final t = report.tread?.at(corner, lap.index);
      if (t == null) return null;
      // The zones' order is the heading's, not letters in every cell: with
      // "I 94.2 · C 94.8 · O 85.0" four corners no longer fit a 1000 px
      // window without scrolling sideways, which is where the table's job —
      // being readable at a glance — stops.
      return '${t.inner.mean.toStringAsFixed(1)} · '
          '${t.centre.mean.toStringAsFixed(1)} · '
          '${t.outer.mean.toStringAsFixed(1)}';
    }

    (String, String?) cell(Corner corner, int i) {
      final point = byCorner[corner]![i];
      final value = point.value;
      if (metric == TyreMetric.wear) {
        final usage = report.wear?[corner]?.laps[i];
        final start = usage?.levelAtStart;
        final used = usage?.used;
        return (
          used == null ? '—' : formatMetric(metric, used),
          start == null || used == null
              ? null
              : '${start.toStringAsFixed(2)} → '
                  '${(start - used).toStringAsFixed(2)}',
        );
      }
      final range = point.low == null || point.high == null
          ? null
          : '${formatMetric(metric, point.low!)}–'
              '${formatMetric(metric, point.high!)}';
      if (metric == TyreMetric.tread) {
        return (
          tread(corner, point.lap) ?? '—',
          value == null ? null : 'mean ${formatMetric(metric, value)} · $range',
        );
      }
      return (value == null ? '—' : formatMetric(metric, value), range);
    }

    final heading = switch (metric) {
      TyreMetric.wear => 'Used this lap (%), then the level from lap start to '
          'lap end',
      TyreMetric.tread => 'Inner · centre · outer lap means (°C), then their '
          'mean and the lap’s coolest–hottest zone reading',
      _ => 'Lap mean (${metric.unit}), then the lap’s lowest–highest reading',
    };

    Widget numeral(String text, {required bool muted, double size = 13}) =>
        Text(
          text,
          style: AppTextStyles.numeral.copyWith(
            fontSize: size,
            color: muted ? scheme.onSurfaceVariant : null,
          ),
        );

    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${metric.label} by lap', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(heading,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  showCheckboxColumn: false,
                  headingTextStyle: theme.textTheme.bodySmall,
                  dataRowMinHeight: 46,
                  dataRowMaxHeight: 50,
                  columnSpacing: 20,
                  columns: [
                    const DataColumn(label: Text('Lap')),
                    for (final corner in Corner.values)
                      DataColumn(label: Text(corner.short), numeric: true),
                    const DataColumn(label: Text('Note')),
                  ],
                  rows: [
                    for (var i = 0; i < laps.length; i++)
                      _row(context, i, laps[i], cell, numeral),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(
    BuildContext context,
    int i,
    Lap lap,
    (String, String?) Function(Corner, int) cell,
    Widget Function(String, {required bool muted, double size}) numeral,
  ) {
    final points = [
      for (final corner in Corner.values) report.series(metric, corner)[i],
    ];
    final exclusion = points
        .map((p) => p.exclusion)
        .firstWhere((e) => e != null, orElse: () => null);
    final muted = exclusion != null;
    return DataRow(
      selected: selectedLap?.index == lap.index,
      onSelectChanged: (_) => onSelectLap(lap),
      cells: [
        DataCell(numeral('${lap.displayNumber}', muted: muted)),
        for (final corner in Corner.values)
          DataCell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                numeral(cell(corner, i).$1, muted: muted),
                if (cell(corner, i).$2 case final secondary?)
                  numeral(secondary, muted: true, size: 11),
              ],
            ),
          ),
        DataCell(Text(exclusion == null ? '' : exclusionLabel(exclusion),
            style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
