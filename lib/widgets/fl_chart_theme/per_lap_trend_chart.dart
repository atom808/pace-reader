/// A per-lap trend of a quantity not anchored at zero, themed like
/// [PerLapBarChart] (SPEC.md §9.5, §9.7).
///
/// ## Why not bars
///
/// A bar's length is its value, which is only true when the bar starts at
/// zero. Tyre pressure sits at 170–177 kPa for a whole stint and a carcass
/// at 80–95 °C: bars from zero would be 95% identical stubs with the story in
/// the last few pixels, and bars from a truncated floor would make a 2% rise
/// look like a doubling. So the lap's **mean is a point**, joined lap to lap
/// by a line, and the lap's **lowest-to-highest reading is a faint band**
/// around it — position rather than length, on a scale fitted to the data.
///
/// The rest is [PerLapBarChart]'s rulebook, so the two read as one family:
/// one slot per lap on the same 48 px value axis, ticks only on round values,
/// text in ink rather than the series colour, and laps left out of a headline
/// drawn grey rather than dropped — a grey dot with a grey min–max whisker,
/// not joined to the line, since the line is the representative trend.
///
/// `fl_chart` 1.2.0 still imports `package:flutter/material.dart` rather than
/// `material_ui`; everything it would take from a theme is passed in
/// explicitly (README.md, Toolchain).
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../charting/viewport.dart';
import '../design_system/design_system.dart';

/// One lap's point.
class PerLapTrendPoint {
  const PerLapTrendPoint({
    required this.lapNumber,
    required this.value,
    this.low,
    this.high,
    this.muted = false,
    this.note,
  });

  /// The 1-based number a driver counts laps by.
  final int lapNumber;

  /// The lap's summary value — its mean. Null keeps the lap's slot empty.
  final double? value;

  /// The lap's lowest and highest reading, drawn as the band. Either null
  /// draws the point without one.
  final double? low;
  final double? high;

  /// Drawn in the de-emphasis grey and left off the line.
  final bool muted;

  /// Why the lap is muted or empty, for the tooltip.
  final String? note;

  bool get hasRange => low != null && high != null;
}

/// A tick to the decimals its step needs — the same rule as the bar chart's
/// axis, so the two agree when stacked.
String _tick(double value, double step) {
  final decimals = step >= 1
      ? 0
      : step >= 0.1
          ? 1
          : 2;
  return value.toStringAsFixed(decimals);
}

/// A line of per-lap means over faint per-lap min–max bands.
class PerLapTrendChart extends StatelessWidget {
  const PerLapTrendChart({
    super.key,
    required this.points,
    required this.color,
    required this.formatValue,
    this.minY,
    this.maxY,
    this.highlightLap,
    this.height = 180,
  });

  final List<PerLapTrendPoint> points;

  /// The series' identity colour, for its line, dots and band only.
  final Color color;

  /// Formats a value for the tooltip. The axis formats its own ticks.
  final String Function(double) formatValue;

  /// The data range to fit, for small multiples that must share one scale —
  /// four corners compared on four different scales compare nothing. Null
  /// fits this chart's own points.
  final double? minY;
  final double? maxY;

  /// A lap to mark with a faint vertical rule — the lap another view on the
  /// same screen is showing, so the two can be read against each other.
  final int? highlightLap;

  final double height;

  static const _valueAxisWidth = 48.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mutedColor = scheme.onSurfaceVariant.withValues(alpha: 0.45);
    final grid = scheme.outlineVariant.withValues(alpha: 0.45);
    final labelStyle = AppTextStyles.numeral.copyWith(
      fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
      color: scheme.onSurfaceVariant,
    );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final own = ValueRange.ofAll([
      for (final p in points) ...[?p.value, ?p.low, ?p.high],
    ]);
    final data = switch ((minY, maxY)) {
      (final lo?, final hi?) => ValueRange(lo, hi),
      _ => own ?? const ValueRange(0, 1),
    };
    // Headroom so a band never touches the frame, and an absolute pad for a
    // flat series, whose zero span would otherwise make no scale at all.
    final range = data.padded(fraction: 0.1, minimumPad: 1);
    final ticks = range.ticks(target: 4);
    final step = ticks.length > 1 ? ticks[1] - ticks[0] : range.span;

    final bars = <LineChartBarData>[];
    final between = <BetweenBarsData>[];

    // The representative line: every non-muted lap with a value, broken by a
    // null spot wherever a muted or empty lap sits, so the line never implies
    // a trend through a lap it does not describe.
    bars.add(LineChartBarData(
      spots: [
        for (var i = 0; i < points.length; i++)
          if (!points[i].muted && points[i].value != null)
            FlSpot(i.toDouble(), points[i].value!)
          else
            FlSpot.nullSpot,
      ],
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      isStrokeJoinRound: true,
      dotData: FlDotData(
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: color,
          strokeWidth: 1.5,
          strokeColor: AppColors.surfaceBase,
        ),
      ),
    ));
    final meanBars = {0};

    // Bands, one per run of consecutive representative laps: fill between an
    // invisible low line and an invisible high line. A run of one lap has no
    // width to fill, so it gets a whisker instead.
    var i = 0;
    while (i < points.length) {
      if (points[i].muted || !points[i].hasRange) {
        i++;
        continue;
      }
      final start = i;
      while (i < points.length && !points[i].muted && points[i].hasRange) {
        i++;
      }
      final run = [for (var k = start; k < i; k++) k];
      if (run.length == 1) {
        bars.add(_whisker(run.single, points[run.single],
            color.withValues(alpha: 0.35)));
        continue;
      }
      LineChartBarData edge(double Function(PerLapTrendPoint) y) =>
          LineChartBarData(
            spots: [for (final k in run) FlSpot(k.toDouble(), y(points[k]))],
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
          );
      bars.add(edge((p) => p.low!));
      bars.add(edge((p) => p.high!));
      between.add(BetweenBarsData(
        fromIndex: bars.length - 2,
        toIndex: bars.length - 1,
        color: color.withValues(alpha: 0.16),
      ));
    }

    // Muted laps: a grey whisker for the range and a grey dot for the mean,
    // each lap on its own so nothing joins it to its neighbours.
    for (var k = 0; k < points.length; k++) {
      final p = points[k];
      if (!p.muted || p.value == null) continue;
      if (p.hasRange) bars.add(_whisker(k, p, mutedColor));
      meanBars.add(bars.length);
      bars.add(LineChartBarData(
        spots: [FlSpot(k.toDouble(), p.value!)],
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 3,
            color: mutedColor,
            strokeWidth: 1.5,
            strokeColor: AppColors.surfaceBase,
          ),
        ),
      ));
    }

    final highlightIndex = highlightLap == null
        ? -1
        : points.indexWhere((p) => p.lapNumber == highlightLap);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = points.isEmpty
              ? 24.0
              : (constraints.maxWidth - _valueAxisWidth) / points.length;
          // A label per lap until they would collide, then every n-th — the
          // bar chart's rule, so a stacked pair labels the same laps.
          final labelEvery = math.max(1, (28 / math.max(slot, 1)).ceil());

          return LineChart(
            duration: reduceMotion ? Duration.zero : AppDurations.medium,
            curve: AppCurves.standard,
            LineChartData(
              minX: -0.5,
              maxX: points.length - 0.5,
              minY: range.min,
              maxY: range.max,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              lineBarsData: bars,
              betweenBarsData: between,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: grid, strokeWidth: 1),
              ),
              extraLinesData: highlightIndex < 0
                  ? null
                  : ExtraLinesData(verticalLines: [
                      VerticalLine(
                        x: highlightIndex.toDouble(),
                        color: scheme.onSurface.withValues(alpha: 0.22),
                        strokeWidth: 1,
                        dashArray: const [3, 3],
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
                    // Only the round values the grid is drawn at — never the
                    // padded range's ends, which are numbers on no gridline.
                    minIncluded: false,
                    maxIncluded: false,
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
                    interval: 1,
                    minIncluded: false,
                    maxIncluded: false,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final number = points[index].lapNumber;
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
              lineTouchData: LineTouchData(
                touchSpotThreshold: math.max(8, slot / 2),
                // Only the mean marks answer a touch: the band edges and
                // whiskers are the same lap, and answering for them would
                // stack three copies of one tooltip.
                getTouchedSpotIndicator: (bar, indexes) => [
                  for (final _ in indexes)
                    bar.dotData.show
                        ? TouchedSpotIndicatorData(
                            FlLine(
                              color: scheme.onSurface.withValues(alpha: 0.3),
                              strokeWidth: 1,
                              dashArray: const [3, 3],
                            ),
                            FlDotData(
                              getDotPainter: (spot, percent, bar, index) =>
                                  FlDotCirclePainter(
                                radius: 4.5,
                                color: bar.color == Colors.transparent
                                    ? mutedColor
                                    : color,
                                strokeWidth: 2,
                                strokeColor: scheme.onSurface,
                              ),
                            ),
                          )
                        : null,
                ],
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                  tooltipBorder: BorderSide(color: scheme.outlineVariant),
                  tooltipBorderRadius: BorderRadius.circular(AppRadii.sm),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    var answered = false;
                    return [
                      for (final spot in spots)
                        if (!answered && meanBars.contains(spot.barIndex))
                          (() {
                            answered = true;
                            return _tooltip(
                                points[spot.x.round()], theme, scheme);
                          })()
                        else
                          null,
                    ];
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  LineChartBarData _whisker(int index, PerLapTrendPoint point, Color color) =>
      LineChartBarData(
        spots: [
          FlSpot(index.toDouble(), point.low!),
          FlSpot(index.toDouble(), point.high!),
        ],
        color: color,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
      );

  LineTooltipItem _tooltip(
    PerLapTrendPoint point,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final small =
        theme.textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant);
    return LineTooltipItem(
      'Lap ${point.lapNumber}\n',
      small,
      textAlign: TextAlign.left,
      children: [
        TextSpan(
          text: point.value == null ? '—' : formatValue(point.value!),
          style: AppTextStyles.numeral
              .copyWith(fontSize: 13, color: scheme.onSurface),
        ),
        if (point.hasRange)
          TextSpan(
            text: '\n${formatValue(point.low!)} – ${formatValue(point.high!)}',
            style: AppTextStyles.numeral
                .copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        if (point.note != null) TextSpan(text: '\n${point.note}', style: small),
      ],
    );
  }
}
