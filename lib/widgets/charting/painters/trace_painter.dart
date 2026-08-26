/// Line-trace painters for the chart core (SPEC.md §9.5, §9.7.1).
library;

import 'package:flutter/material.dart';

import '../decimation.dart';
import 'chart_painting.dart';

/// Draws one decimated channel: its min/max envelope, an area fill under it,
/// and the gridlines behind both.
///
/// ## Why the envelope is drawn, not a mid-line
///
/// Each point is a bucket the signal *covered*, not a sample it hit, so the
/// honest mark is the vertical extent. Where the signal is smooth the
/// envelope collapses to something a line's width and reads as a line; where
/// it spikes inside one bucket the envelope thickens, which is the chart
/// admitting there is detail below its resolution rather than picking one
/// sample and implying there wasn't.
///
/// ## Why the area fill
///
/// §9.7.1 adopts both reference apps' convention of a solid filled trace for
/// the primary lap, against a dotted line for a reference lap. The fill is
/// also what makes five stacked panels scannable: the eye reads filled area
/// as magnitude at a glance, where five bare lines read as one tangle.
///
/// Cursor drawing is deliberately *not* here — see [CursorPainter]. The trace
/// costs thousands of points to draw and changes only when the data or the
/// viewport does, while the cursor changes on every pointer move; keeping
/// them in separate layers is what stops a scrub from redrawing the trace at
/// pointer rate.
class TracePainter extends CustomPainter {
  const TracePainter({
    required this.plot,
    required this.geometry,
    required this.palette,
    required this.valueTicks,
    required this.domainTicks,
    required this.formatValue,
  });

  final TracePlot plot;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    void labels() => paintValueLabels(canvas, scaled, palette,
        ticks: valueTicks, format: formatValue);

    if (plot.length < 2) return labels();

    final range = _visibleRange(scaled);
    if (range == null) return labels();
    final (first, last) = range;

    final upper = Path();
    final lower = Path();
    for (var i = first; i <= last; i++) {
      final x = scaled.x(plot.xs[i]);
      final hy = scaled.y(plot.highs[i]);
      final ly = scaled.y(plot.lows[i]);
      if (i == first) {
        upper.moveTo(x, hy);
        lower.moveTo(x, ly);
      } else {
        upper.lineTo(x, hy);
        lower.lineTo(x, ly);
      }
    }

    // Area under the trace: from the envelope's lower edge down to the
    // panel's floor, so the filled region is the part of the range the signal
    // definitely covered.
    final area = Path.from(lower)
      ..lineTo(scaled.x(plot.xs[last]), size.height)
      ..lineTo(scaled.x(plot.xs[first]), size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.series.withValues(alpha: 0.26),
            palette.series.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // The envelope itself, as a closed band between the two edges.
    final band = Path.from(upper);
    for (var i = last; i >= first; i--) {
      band.lineTo(scaled.x(plot.xs[i]), scaled.y(plot.lows[i]));
    }
    band.close();
    canvas.drawPath(band, Paint()..color = palette.series);

    // A stroke along the band keeps the trace visible where the envelope is
    // thinner than a pixel, which is most of a smooth signal.
    canvas.drawPath(
      upper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = palette.series,
    );

    labels();
  }

  /// First and last index touching the viewport, with one point of overscan
  /// each side so the trace enters and leaves the panel rather than starting
  /// at its edge.
  (int, int)? _visibleRange(ChartGeometry geometry) {
    final firstVisible = plot.nearestIndex(geometry.viewport.start);
    final lastVisible = plot.nearestIndex(geometry.viewport.end);
    final first = (firstVisible - 1).clamp(0, plot.length - 1);
    final last = (lastVisible + 1).clamp(0, plot.length - 1);
    return last > first ? (first, last) : null;
  }

  @override
  bool shouldRepaint(TracePainter old) =>
      !identical(old.plot, plot) ||
      old.geometry != geometry ||
      old.palette.series != palette.series ||
      !_sameTicks(old.valueTicks, valueTicks) ||
      !_sameTicks(old.domainTicks, domainTicks);

  static bool _sameTicks(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Draws an event signal as held steps (SPEC.md §5.1).
///
/// Square corners are the whole point: an event row is a *change*, so the
/// value between two rows is the earlier one held, and a sloped connector
/// would draw the car passing through gears it was never in.
class StepTracePainter extends CustomPainter {
  const StepTracePainter({
    required this.plot,
    required this.geometry,
    required this.palette,
    required this.valueTicks,
    required this.domainTicks,
    required this.formatValue,
  });

  final StepPlot plot;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    if (plot.isEmpty) {
      paintValueLabels(canvas, scaled, palette,
          ticks: valueTicks, format: formatValue);
      return;
    }

    final path = Path();
    var y = scaled.y(plot.values.first);
    path.moveTo(scaled.x(plot.xs.first), y);
    for (var i = 1; i < plot.length; i++) {
      final x = scaled.x(plot.xs[i]);
      path.lineTo(x, y);
      y = scaled.y(plot.values[i]);
      path.lineTo(x, y);
    }
    // Held to the right edge: the last change stays in force to the end of
    // the window, and stopping the line at it would read as data running out.
    path.lineTo(size.width, y);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.miter
        ..color = palette.series,
    );

    paintValueLabels(canvas, scaled, palette,
        ticks: valueTicks, format: formatValue);
  }

  @override
  bool shouldRepaint(StepTracePainter old) =>
      !identical(old.plot, plot) ||
      old.geometry != geometry ||
      old.palette.series != palette.series;
}
