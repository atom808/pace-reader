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
/// - **Marks live in the axis, not on the bars.** A lap's incidents, and the
///   one lap a chart is about, get a small glyph in the row between the plot
///   and the lap number. Each is a real widget with its own tooltip, so the
///   reason is reachable on a lap that has no bar at all — a value of zero, or
///   none — which `fl_chart` cannot be hovered on.
/// - **A bar can be interactive.** Hover and tap report the lap under the
///   pointer, and the whole column is the target rather than just the bar, so
///   the shortest bar on a chart is as easy to hit as the tallest.
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
    this.highlight,
    this.marks = const [],
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

  /// Draws this bar in another colour: the one lap the chart is answering a
  /// question about (the fastest), against the series colour of the rest.
  /// A bar whose value is exactly zero has no height to colour, so it is drawn
  /// as a short cap on the baseline instead of vanishing.
  final Color? highlight;

  /// Glyphs shown under the plot, in this lap's slot. See [PerLapMark].
  final List<PerLapMark> marks;
}

/// A small glyph under one lap's column, with a tooltip saying what it means.
class PerLapMark {
  const PerLapMark({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;

  /// Also the accessible label: the glyph alone says nothing to a screen
  /// reader, and little to anyone who has not met it before.
  final String tooltip;
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
class PerLapBarChart extends StatefulWidget {
  const PerLapBarChart({
    super.key,
    required this.bars,
    required this.color,
    required this.formatValue,
    this.reference,
    this.referenceLabel,
    this.height = 200,
    this.signed = false,
    this.selectedIndex,
    this.hoveredIndex,
    this.onBarTap,
    this.onBarHover,
    this.animateIn = false,
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

  /// The index into [bars] of the lap the rest of the app is showing: drawn
  /// with an outline and a faint column behind it, and its number set bold.
  final int? selectedIndex;

  /// The index under the pointer somewhere *else* — a table row the user is
  /// hovering — mirrored here so the two views point at one lap.
  final int? hoveredIndex;

  /// A bar's column, or its lap number, was tapped. Giving this or
  /// [onBarHover] makes the whole column a target and adds the hover band.
  final ValueChanged<int>? onBarTap;

  /// The pointer entered a lap's column (its index) or left every column
  /// (null).
  final ValueChanged<int?>? onBarHover;

  /// Grows the bars from the baseline on first build, where by default they
  /// are simply there. Off by default: a chart that re-appears every time it
  /// is rebuilt with the same data should not replay its entrance.
  final bool animateIn;

  static const _maxBarWidth = 24.0;
  static const _valueAxisWidth = 48.0;

  /// Height of the row of [PerLapMark]s between the plot and the lap numbers.
  static const _markLaneHeight = 18.0;
  static const _labelHeight = 22.0;

  /// The most a glyph is drawn at.
  static const _maxMarkSize = 16.0;

  @override
  State<PerLapBarChart> createState() => _PerLapBarChartState();
}

class _PerLapBarChartState extends State<PerLapBarChart> {
  /// Whether the bars have been let up to their values. False for exactly one
  /// frame when [PerLapBarChart.animateIn] is set: `fl_chart` animates a
  /// *change* of data, never a first build, so the entrance is a change from
  /// zero-height bars to the real ones on the frame after.
  late bool _revealed = !widget.animateIn;

  @override
  void initState() {
    super.initState();
    if (!_revealed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  bool get _interactive => widget.onBarTap != null || widget.onBarHover != null;

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
    final bars = widget.bars;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final revealed = _revealed || reduceMotion;
    final hasMarks = bars.any((bar) => bar.marks.isNotEmpty);

    final values = [for (final bar in bars) ?bar.value, ?widget.reference];
    // Ticks on round values, chosen the same way the trace panels choose
    // theirs, so a bar reads against a gridline without arithmetic. The floor
    // stays at zero: these are amounts, and a truncated baseline would make a
    // 5% difference between two laps look like a factor of two. (A signed chart
    // spans the data *and* zero instead: both are on the axis, so neither can
    // be truncated.)
    final top = values.isEmpty ? 1.0 : values.reduce(math.max);
    final bottom = widget.signed && values.isNotEmpty
        ? math.min(0.0, values.reduce(math.min))
        : 0.0;
    final high = widget.signed ? math.max(0.0, top) : top;
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
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = bars.isEmpty
              ? PerLapBarChart._maxBarWidth
              : (constraints.maxWidth - PerLapBarChart._valueAxisWidth) /
                    bars.length;
          final barWidth = math.min(
            PerLapBarChart._maxBarWidth,
            math.max(2.0, slot * 0.6),
          );
          // A label per lap until they would collide, then every n-th — a
          // 150-lap stint cannot label every column, and a skipped label is
          // cheaper than an unreadable axis.
          final labelEvery = math.max(1, (28 / math.max(slot, 1)).ceil());

          BarChartGroupData group(int i) {
            final bar = bars[i];
            final hovered = i == widget.hoveredIndex;
            final selected = i == widget.selectedIndex;

            final base = bar.value == null
                ? Colors.transparent
                : bar.muted
                ? muted
                : bar.highlight ?? widget.color;
            // Lightened toward the ink rather than the hue shifted: the bar
            // keeps its identity and only its emphasis changes.
            final fill = hovered && bar.value != null
                ? Color.lerp(base, scheme.onSurface, 0.3)!
                : base;
            // Zero is a value, not an absence: a lap exactly as fast as the
            // reference has no height, and would otherwise be the one lap on
            // the chart with nothing to look at. `fl_chart` paints no rod at
            // all when its two ends are equal, and gives every other rod at
            // least its corner radius of height — so the smallest mark that
            // is honest about a zero is the smallest value that draws, which
            // is the 4 px cap the rod shape already means by "almost none".
            final flat = bar.value != null && bar.value == (bar.from ?? 0);

            // Selection is an outline round the bar — except on that cap,
            // where 1.5 px of ink on every side would repaint a 4 px mark
            // white and take the highlight colour with it. The column band and
            // the bold lap number carry the selection there.
            final border = selected && !flat
                ? BorderSide(
                    color: scheme.onSurface.withValues(alpha: 0.9),
                    width: 1.5,
                  )
                : BorderSide.none;

            final target = flat ? (bar.from ?? 0) + 1e-9 : (bar.value ?? 0);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  fromY: bar.from,
                  toY: revealed ? target : (bar.from ?? 0),
                  width: barWidth,
                  color: fill,
                  borderSide: border,
                  // The free end is the rounded one: the foot stays square on
                  // the baseline whichever way a signed bar grows.
                  borderRadius: (bar.value ?? 0) < (bar.from ?? 0)
                      ? const BorderRadius.vertical(bottom: Radius.circular(4))
                      : const BorderRadius.vertical(top: Radius.circular(4)),
                  // A full-height, invisible column behind the bar: what
                  // `fl_chart` hit-tests instead of the bar alone, and the
                  // band that lights up under the pointer.
                  backDrawRodData: _interactive
                      ? BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: scheme.onSurface.withValues(
                            alpha: hovered
                                ? 0.10
                                : selected
                                ? 0.06
                                : 0,
                          ),
                        )
                      : null,
                ),
              ],
            );
          }

          Widget markRow(PerLapBar bar) {
            final marks = bar.marks;
            // As many as fit: a mark shrinks toward a dot before it is
            // dropped, and only the first survives a column too narrow for
            // two — marks are ordered most important first.
            var size = math.min(
              PerLapBarChart._maxMarkSize,
              slot / math.max(marks.length, 1),
            );
            var shown = marks;
            if (size < 6) {
              size = 6;
              shown = marks.take(1).toList();
            }
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mark in shown)
                  Tooltip(
                    message: mark.tooltip,
                    child: Icon(mark.icon, size: size, color: mark.color),
                  ),
              ],
            );
          }

          Widget lapTitle(int index, TitleMeta meta) {
            final bar = bars[index];
            final selected = index == widget.selectedIndex;
            final number = bar.lapNumber;
            final showNumber = labelEvery == 1 || number % labelEvery == 0;
            final text = Text(
              showNumber ? '$number' : '',
              style: selected
                  ? labelStyle.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    )
                  : labelStyle,
            );
            // Bare when there is nothing to stack it with: the numeral face is
            // 14.5 px tall in an axis that leaves 14, which a bare `Text`
            // tolerates and a `Column` reports as an overflow.
            Widget cell = !hasMarks
                ? text
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: PerLapBarChart._markLaneHeight,
                        child: Center(child: markRow(bar)),
                      ),
                      text,
                    ],
                  );
            if (_interactive) {
              // The whole slot is the target, so a lap number is as good a
              // place to click as its bar.
              cell = MouseRegion(
                cursor: widget.onBarTap == null
                    ? MouseCursor.defer
                    : SystemMouseCursors.click,
                onEnter: (_) => widget.onBarHover?.call(index),
                onExit: (_) => widget.onBarHover?.call(null),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onBarTap == null
                      ? null
                      : () => widget.onBarTap!(index),
                  child: SizedBox(width: math.max(slot, 1), child: cell),
                ),
              );
            }
            return SideTitleWidget(
              meta: meta,
              space: hasMarks ? 4 : 8,
              child: cell,
            );
          }

          return BarChart(
            // Bars grow to a new value rather than jumping, and not at all under
            // reduced motion (§9.7.4), where they land on it. The entrance is a
            // slower, softer version of the change animation: it is the one
            // motion on the page the eye is asked to follow, so it gets the
            // entrance curve rather than the standard.
            duration: AppMotion.duration(
              context,
              widget.animateIn ? AppDurations.slow : AppDurations.medium,
            ),
            curve: widget.animateIn ? AppCurves.entrance : AppCurves.standard,
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
              extraLinesData: widget.reference == null && !widget.signed
                  ? null
                  : ExtraLinesData(
                      horizontalLines: [
                        if (widget.signed)
                          // Solid and brighter than the grid: the baseline every
                          // bar grows from, and the line that says which side of
                          // it is which.
                          HorizontalLine(
                            y: 0,
                            color: scheme.onSurface.withValues(alpha: 0.5),
                            strokeWidth: 1,
                          ),
                        if (widget.reference != null)
                          // Dashed because it is a threshold to read bars
                          // against, not a gridline — the one line on the chart
                          // that is.
                          HorizontalLine(
                            y: widget.reference!,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                            strokeWidth: 1,
                            dashArray: const [4, 4],
                            label: widget.referenceLabel == null
                                ? null
                                : HorizontalLineLabel(
                                    show: true,
                                    // A signed chart's line is usually below
                                    // zero, and above it sits the baseline and
                                    // the feet of every bar; the label goes on
                                    // the far side, where nothing grows.
                                    alignment:
                                        widget.signed && widget.reference! < 0
                                        ? Alignment.bottomRight
                                        : Alignment.topRight,
                                    style: labelStyle,
                                    labelResolver: (_) =>
                                        widget.referenceLabel!,
                                  ),
                          ),
                      ],
                    ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: PerLapBarChart._valueAxisWidth,
                    interval: step,
                    // Ticks only on the round values the grid is drawn at.
                    // `fl_chart` otherwise adds one at the axis maximum — a
                    // number like 2.45 on no gridline, which reads as data.
                    // A signed axis is padded below its lowest tick for the
                    // same reason, so it drops the minimum's label too.
                    maxIncluded: false,
                    minIncluded: !widget.signed,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(_tick(value, step), style: labelStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: hasMarks
                        ? PerLapBarChart._labelHeight +
                              PerLapBarChart._markLaneHeight
                        : PerLapBarChart._labelHeight,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= bars.length) {
                        return const SizedBox.shrink();
                      }
                      return lapTitle(index, meta);
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                allowTouchBarBackDraw: _interactive,
                mouseCursorResolver: widget.onBarTap == null
                    ? null
                    : (event, response) => response?.spot == null
                          ? MouseCursor.defer
                          : SystemMouseCursors.click,
                touchCallback: !_interactive
                    ? null
                    : (event, response) {
                        final index = response?.spot?.touchedBarGroupIndex;
                        if (event is FlPointerHoverEvent) {
                          widget.onBarHover?.call(index);
                        } else if (event is FlPointerExitEvent) {
                          widget.onBarHover?.call(null);
                        } else if (event is FlTapUpEvent && index != null) {
                          widget.onBarTap?.call(index);
                        }
                      },
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
                      theme.textTheme.labelSmall!.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: switch ((bar.from, bar.value)) {
                            (_, null) => '—',
                            (null, final value?) => widget.formatValue(value),
                            (final from?, final value?) =>
                              '${widget.formatValue(from)} – ${widget.formatValue(value)}',
                          },
                          style: AppTextStyles.numeral.copyWith(
                            fontSize: 13,
                            color: scheme.onSurface,
                          ),
                        ),
                        if (bar.note != null)
                          TextSpan(
                            text: '\n${bar.note}',
                            style: theme.textTheme.labelSmall!.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: [for (var i = 0; i < bars.length; i++) group(i)],
            ),
          );
        },
      ),
    );
  }
}
