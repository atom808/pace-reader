/// A per-lap aggregate chart, themed to match the custom chart core
/// (SPEC.md §9.5, §9.7).
///
/// `fl_chart` rather than `../charting/`, by §9.5's rule: one bar per lap is a
/// small dataset with no decimation and no shared cursor, so it never joins the
/// synced system the custom core exists for. What this file adds is the part
/// that keeps it from looking bolted on — the same numeral face on the axes,
/// the same recessive grid, the same surface under the tooltip — and the mark
/// rules a standalone chart is easiest to get wrong:
///
/// - **Bars at most 24 px thick**, their tops rounded 4 px and their feet
///   square on one baseline, and never filling their slot: the air between
///   bars is what separates them, not a stroke drawn around each one.
/// - **Text in ink, never in the series colour.** The bar carries identity;
///   the axis, the tooltip and the title stay legible on the surface whatever
///   the hue.
/// - **A lap left out of the headline is still drawn**, in the de-emphasis
///   grey rather than dropped: an out lap missing from a per-lap chart makes
///   the lap numbering jump, and the lap table already established that a
///   greyed row beats a missing one.
///
/// `fl_chart` 1.2.0 still imports `package:flutter/material.dart` rather than
/// `material_ui`, which is harmless here only because everything it would
/// otherwise take from a theme is passed in explicitly (README.md, Toolchain).
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../charting/viewport.dart';
import '../design_system/design_system.dart';

/// One lap's bar.
class PerLapBar {
  const PerLapBar({
    required this.lapNumber,
    required this.value,
    this.from,
    this.muted = false,
    this.note,
  });

  /// The 1-based number a driver counts laps by.
  final int lapNumber;

  /// Where the bar starts, for a *range* rather than an amount — a lap's
  /// state-of-charge window runs from its lowest reading to its highest.
  /// Null grows the bar from zero, the baseline every amount shares.
  final double? from;

  /// Null draws no bar and keeps the lap's slot — a lap the value is unknown
  /// for is still a lap, and closing the gap would renumber every lap after
  /// it.
  final double? value;

  /// Drawn in the de-emphasis grey: a lap the headline figure leaves out.
  final bool muted;

  /// Why the lap is muted or empty, for the tooltip.
  final String? note;
}

/// A tick value to the decimals its step needs: a step of 0.5 needs one, a
/// step of 20 none, and a step of 2.5 — one of the 1/2/2.5/5 × 10ⁿ steps
/// `ValueRange.ticks` picks — needs one too, which a rule based on the step's
/// size alone rounds away (a gridline at 7.5 labelled `8`).
String _tick(double value, double step) {
  var decimals = 3;
  var scale = 1.0;
  for (var d = 0; d < 3; d++) {
    final scaled = step.abs() * scale;
    if ((scaled - scaled.roundToDouble()).abs() < 1e-6) {
      decimals = d;
      break;
    }
    scale *= 10;
  }
  // `fl_chart` computes its own tick positions, and on a signed axis the one at
  // zero can arrive as -1e-17 — which would print as "-0.0".
  final folded = value.abs() < step * 1e-6 ? 0.0 : value;
  return folded.toStringAsFixed(decimals);
}

/// A column per lap on one value axis, with an optional reference line.
class PerLapBarChart extends StatelessWidget {
  const PerLapBarChart({
    super.key,
    required this.bars,
    required this.color,
    required this.formatValue,
    this.reference,
    this.referenceLabel,
    this.height = 200,
    this.signed = false,
  });

  final List<PerLapBar> bars;

  /// The series' identity colour, for its bars only.
  final Color color;

  /// Formats a bar's value for its tooltip. The axis formats its own ticks,
  /// to no more decimals than its step needs — `1`, `2`, not `1.00`, `2.00`.
  final String Function(double) formatValue;

  /// A value drawn across the chart — the average a headline tile states, so
  /// the tile and the bars it summarises can be read against each other.
  final double? reference;
  final String? referenceLabel;

  final double height;

  /// Bars may fall below zero — seconds gained and lost against a car ahead
  /// (§8.9), where the sign *is* the message.
  ///
  /// The value axis then spans the data and zero rather than starting at zero,
  /// zero is drawn as a solid line of its own (a gridline that is also the
  /// baseline every bar grows from), and a negative bar is rounded at the end
  /// that is free, its foot square on the zero line like a positive one. Off by
  /// default: an amount below zero is a bug for every other user of this chart,
  /// and the floor at zero is what stops a 5% difference reading as a factor of
  /// two.
  final bool signed;

  static const _maxBarWidth = 24.0;
  static const _valueAxisWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.35);
    final grid = scheme.outlineVariant.withValues(alpha: 0.45);
    final labelStyle = AppTextStyles.numeral.copyWith(
      fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
      color: scheme.onSurfaceVariant,
    );

    final values = [
      for (final bar in bars) ?bar.value,
      ?reference,
    ];
    // Ticks on round values, chosen the same way the trace panels choose
    // theirs, so a bar reads against a gridline without arithmetic. The floor
    // stays at zero: these are amounts, and a truncated baseline would make a
    // 5% difference between two laps look like a factor of two. (A signed chart
    // spans the data *and* zero instead: both are on the axis, so neither can
    // be truncated.)
    final top = values.isEmpty ? 1.0 : values.reduce(math.max);
    final bottom = signed && values.isNotEmpty
        ? math.min(0.0, values.reduce(math.min))
        : 0.0;
    final high = signed ? math.max(0.0, top) : top;
    final ticks = ValueRange(
      bottom,
      high <= bottom ? bottom + 1 : high,
    ).ticks(target: 4);
    final step = ticks.length > 1 ? ticks[1] - ticks[0] : top;
    final maxY = ticks.isEmpty ? top : math.max(ticks.last, high) + step * 0.15;
    final minY = bottom < 0 && ticks.isNotEmpty
        ? math.min(ticks.first, bottom) - step * 0.15
        : 0.0;

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = bars.isEmpty
              ? _maxBarWidth
              : (constraints.maxWidth - _valueAxisWidth) / bars.length;
          final barWidth = math.min(_maxBarWidth, math.max(2.0, slot * 0.6));
          // A label per lap until they would collide, then every n-th — a
          // 150-lap stint cannot label every column, and a skipped label is
          // cheaper than an unreadable axis.
          final labelEvery = math.max(1, (28 / math.max(slot, 1)).ceil());

          return BarChart(
            // Bars grow to a new value rather than jumping; not under
            // reduced motion (§9.7.4), where they land on it.
            duration: AppMotion.duration(context, AppDurations.medium),
            curve: AppCurves.standard,
            BarChartData(
              minY: minY,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: grid, strokeWidth: 1),
              ),
              extraLinesData: reference == null && !signed
                  ? null
                  : ExtraLinesData(horizontalLines: [
                      if (signed)
                        // Solid and brighter than the grid: the baseline every
                        // bar grows from, and the line that says which side of
                        // it is which.
                        HorizontalLine(
                          y: 0,
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      if (reference != null)
                        // Dashed because it is a threshold to read bars
                        // against, not a gridline — the one line on the chart
                        // that is.
                        HorizontalLine(
                          y: reference!,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          strokeWidth: 1,
                          dashArray: const [4, 4],
                          label: referenceLabel == null
                              ? null
                              : HorizontalLineLabel(
                                  show: true,
                                  // A signed chart's line is usually below
                                  // zero, and above it sits the baseline and
                                  // the feet of every bar; the label goes on
                                  // the far side, where nothing grows.
                                  alignment: signed && reference! < 0
                                      ? Alignment.bottomRight
                                      : Alignment.topRight,
                                  style: labelStyle,
                                  labelResolver: (_) => referenceLabel!,
                                ),
                        ),
                    ]),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _valueAxisWidth,
                    interval: step,
                    // Ticks only on the round values the grid is drawn at.
                    // `fl_chart` otherwise adds one at the axis maximum — a
                    // number like 2.45 on no gridline, which reads as data.
                    // A signed axis is padded below its lowest tick for the
                    // same reason, so it drops the minimum's label too.
                    maxIncluded: false,
                    minIncluded: !signed,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(_tick(value, step), style: labelStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      final number = bars[index].lapNumber;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          number % labelEvery == 0 || labelEvery == 1
                              ? '$number'
                              : '',
                          style: labelStyle,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  tooltipBorder: BorderSide(color: scheme.outlineVariant),
                  tooltipBorderRadius: BorderRadius.circular(AppRadii.sm),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final bar = bars[group.x];
                    return BarTooltipItem(
                      'Lap ${bar.lapNumber}\n',
                      theme.textTheme.labelSmall!
                          .copyWith(color: scheme.onSurfaceVariant),
                      children: [
                        TextSpan(
                          text: switch ((bar.from, bar.value)) {
                            (_, null) => '—',
                            (null, final value?) => formatValue(value),
                            (final from?, final value?) =>
                              '${formatValue(from)} – ${formatValue(value)}',
                          },
                          style: AppTextStyles.numeral.copyWith(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (bar.note != null)
                          TextSpan(
                            text: '\n${bar.note}',
                            style: theme.textTheme.labelSmall!
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < bars.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        fromY: bars[i].from,
                        toY: bars[i].value ?? 0,
                        width: barWidth,
                        color: bars[i].value == null
                            ? Colors.transparent
                            : bars[i].muted
                                ? muted
                                : color,
                        // The free end is the rounded one: the foot stays
                        // square on the baseline whichever way the bar grows.
                        borderRadius: (bars[i].value ?? 0) < 0
                            ? const BorderRadius.vertical(
                                bottom: Radius.circular(4),
                              )
                            : const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
