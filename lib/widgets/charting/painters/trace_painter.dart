/// Line-trace painters for the chart core (SPEC.md §9.5, §9.7.1).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

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
    this.reference,
  });

  final TracePlot plot;

  /// The same channel on a reference lap, drawn as a dotted line over [plot]
  /// (§8.4). Its midline rather than its envelope: the envelope is what makes
  /// the primary honest about detail below its resolution, and a second
  /// envelope on top of it would bury the one being inspected.
  final TracePlot? reference;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    // The samples just outside the window are drawn so the trace enters and
    // leaves the panel; clipped, so they never draw past its edges.
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    _paintPrimary(canvas, size, scaled);
    final reference = this.reference;
    if (reference != null) _paintReference(canvas, scaled, reference);

    paintValueLabels(
      canvas,
      scaled,
      palette,
      ticks: valueTicks,
      format: formatValue,
      atRight: true,
    );
  }

  void _paintPrimary(Canvas canvas, Size size, ChartGeometry scaled) {
    final range = _visibleRange(plot, scaled);
    if (range == null) return;
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
    paintAreaUnder(
      canvas,
      size,
      lower,
      from: scaled.x(plot.xs[first]),
      to: scaled.x(plot.xs[last]),
      color: palette.series,
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
  }

  void _paintReference(Canvas canvas, ChartGeometry scaled, TracePlot line) {
    final range = _visibleRange(line, scaled);
    if (range == null) return;
    final (first, last) = range;
    canvas.drawPath(
      dashedPolyline([
        for (var i = first; i <= last; i++)
          Offset(
            scaled.x(line.xs[i]),
            scaled.y((line.lows[i] + line.highs[i]) / 2),
          ),
      ]),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..color = palette.reference,
    );
  }

  @override
  bool shouldRepaint(TracePainter old) =>
      !identical(old.plot, plot) ||
      !identical(old.reference, reference) ||
      old.geometry != geometry ||
      old.palette.series != palette.series ||
      !_sameTicks(old.valueTicks, valueTicks) ||
      !_sameTicks(old.domainTicks, domainTicks);

  /// First and last index of [plot] touching the viewport, with one point of
  /// overscan each side so the trace enters and leaves the panel rather than
  /// starting at its edge.
  static (int, int)? _visibleRange(TracePlot plot, ChartGeometry geometry) {
    if (plot.length < 2) return null;
    final firstVisible = plot.nearestIndex(geometry.viewport.start);
    final lastVisible = plot.nearestIndex(geometry.viewport.end);
    final first = (firstVisible - 1).clamp(0, plot.length - 1);
    final last = (lastVisible + 1).clamp(0, plot.length - 1);
    return last > first ? (first, last) : null;
  }

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
    this.reference,
  });

  final StepPlot plot;

  /// The reference lap's steps, dotted — see [TracePainter.reference].
  final StepPlot? reference;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    // The samples just outside the window are drawn so the trace enters and
    // leaves the panel; clipped, so they never draw past its edges.
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    if (plot.isNotEmpty) {
      final points = _stepPoints(plot, scaled, size);
      final steps = Path()..addPolygon(points, false);
      // Filled like every other trace, so gear reads as a mass at a glance
      // rather than a wire.
      paintAreaUnder(
        canvas,
        size,
        steps,
        from: points.first.dx,
        to: points.last.dx,
        color: palette.series,
      );
      canvas.drawPath(
        steps,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeJoin = StrokeJoin.miter
          ..color = palette.series,
      );
    }
    final reference = this.reference;
    if (reference != null && reference.isNotEmpty) {
      canvas.drawPath(
        dashedPolyline(_stepPoints(reference, scaled, size)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = palette.reference,
      );
    }

    paintValueLabels(
      canvas,
      scaled,
      palette,
      ticks: valueTicks,
      format: formatValue,
      atRight: true,
    );
  }

  /// The corners of [steps] as held values: across to each change, then up
  /// or down to it.
  static List<Offset> _stepPoints(
    StepPlot steps,
    ChartGeometry scaled,
    Size size,
  ) {
    var y = scaled.y(steps.values.first);
    final points = [Offset(scaled.x(steps.xs.first), y)];
    for (var i = 1; i < steps.length; i++) {
      final x = scaled.x(steps.xs[i]);
      points.add(Offset(x, y));
      y = scaled.y(steps.values[i]);
      points.add(Offset(x, y));
    }
    // Held to the right edge: the last change stays in force to the end of
    // the window, and stopping the line at it would read as data running out.
    points.add(Offset(size.width, y));
    return points;
  }

  @override
  bool shouldRepaint(StepTracePainter old) =>
      !identical(old.plot, plot) ||
      !identical(old.reference, reference) ||
      old.geometry != geometry ||
      old.palette.series != palette.series;
}

/// Draws a lap's time delta against its reference (SPEC.md §8.4).
///
/// Different from [TracePainter] in the one respect that matters for a signed
/// quantity: its baseline is **zero**, not the panel floor. Filling down to
/// the floor would paint "0.2 s behind" and "0.2 s ahead" as two different
/// amounts of colour; filling toward zero makes the filled area *be* the time
/// gained or lost, on whichever side of level it falls.
///
/// One colour for both sides, deliberately. Green for gained and red for lost
/// would borrow throttle's and brake's identity colours (§9.7.1) for a meaning
/// that is neither, on a panel stacked directly above both of them.
class DeltaTracePainter extends CustomPainter {
  const DeltaTracePainter({
    required this.plot,
    this.floorBand,
    required this.geometry,
    required this.palette,
    required this.valueTicks,
    required this.domainTicks,
    required this.formatValue,
  });

  final TracePlot plot;

  /// See `DeltaSeriesPanel.floorBand`.
  final double? floorBand;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    // The samples just outside the window are drawn so the trace enters and
    // leaves the panel; clipped, so they never draw past its edges.
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    final zero = scaled.y(0);
    if (floorBand case final band?) {
      // Under the trace: the band is the floor the trace is read against,
      // not something drawn over it.
      canvas.drawRect(
        Rect.fromLTRB(0, scaled.y(band), size.width, scaled.y(-band)),
        Paint()..color = palette.axisText.withValues(alpha: 0.10),
      );
    }
    // "Level with the reference" is the line the whole panel is read
    // against, so it is drawn heavier than the gridlines around it.
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = palette.axisText.withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );

    final range = TracePainter._visibleRange(plot, scaled);
    if (range != null) {
      final (first, last) = range;
      final line = Path();
      for (var i = first; i <= last; i++) {
        final x = scaled.x(plot.xs[i]);
        final y = scaled.y(plot.lows[i]);
        if (i == first) {
          line.moveTo(x, y);
        } else {
          line.lineTo(x, y);
        }
      }
      canvas.drawPath(
        Path.from(line)
          ..lineTo(scaled.x(plot.xs[last]), zero)
          ..lineTo(scaled.x(plot.xs[first]), zero)
          ..close(),
        Paint()..color = palette.series.withValues(alpha: 0.22),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = palette.series,
      );
    }

    paintValueLabels(
      canvas,
      scaled,
      palette,
      ticks: valueTicks,
      format: formatValue,
      atRight: true,
    );
  }

  @override
  bool shouldRepaint(DeltaTracePainter old) =>
      !identical(old.plot, plot) ||
      old.floorBand != floorBand ||
      old.geometry != geometry ||
      old.palette.series != palette.series ||
      !TracePainter._sameTicks(old.valueTicks, valueTicks) ||
      !TracePainter._sameTicks(old.domainTicks, domainTicks);
}

/// Draws several lines of one panel: a tyre's tread zones (map stage P9c).
///
/// No fill under each, which would bury the lines beneath it. The band
/// between the highest and lowest line is filled instead: how far apart the
/// lines run is the reading, a camber or pressure story, and the band shows
/// it at a glance.
class MultiTracePainter extends CustomPainter {
  const MultiTracePainter({
    required this.lines,
    required this.colours,
    required this.geometry,
    required this.palette,
    required this.valueTicks,
    required this.domainTicks,
    required this.formatValue,
  });

  final List<TracePlot> lines;

  /// One per line, in [lines]' order.
  final List<Color> colours;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final List<double> domainTicks;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    _paintSpread(canvas, scaled);
    // The last line first, so the first, the brightest, sits on top.
    for (var k = lines.length - 1; k >= 0; k--) {
      final line = lines[k];
      final range = TracePainter._visibleRange(line, scaled);
      if (range == null) continue;
      final (first, last) = range;
      canvas.drawPath(
        _midline(line, scaled, first, last),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = k == 0 ? 1.8 : 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = colours[k],
      );
    }

    paintValueLabels(
      canvas,
      scaled,
      palette,
      ticks: valueTicks,
      format: formatValue,
      atRight: true,
    );
  }

  /// The band from the lowest line to the highest, where they share a clock.
  void _paintSpread(Canvas canvas, ChartGeometry scaled) {
    if (lines.length < 2) return;
    final n = lines.first.length;
    if (lines.any((l) => l.length != n)) return;
    final range = TracePainter._visibleRange(lines.first, scaled);
    if (range == null) return;
    final (first, last) = range;
    double mid(TracePlot l, int i) => (l.lows[i] + l.highs[i]) / 2;
    final band = Path();
    for (var i = first; i <= last; i++) {
      final top = lines.map((l) => mid(l, i)).reduce(math.max);
      final p = Offset(scaled.x(lines.first.xs[i]), scaled.y(top));
      i == first ? band.moveTo(p.dx, p.dy) : band.lineTo(p.dx, p.dy);
    }
    for (var i = last; i >= first; i--) {
      final bottom = lines.map((l) => mid(l, i)).reduce(math.min);
      band.lineTo(scaled.x(lines.first.xs[i]), scaled.y(bottom));
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()..color = colours.first.withValues(alpha: 0.16),
    );
  }

  static Path _midline(TracePlot line, ChartGeometry g, int first, int last) {
    final path = Path();
    for (var i = first; i <= last; i++) {
      final x = g.x(line.xs[i]);
      final y = g.y((line.lows[i] + line.highs[i]) / 2);
      i == first ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    return path;
  }

  @override
  bool shouldRepaint(MultiTracePainter old) =>
      !listEquals(old.lines, lines) ||
      !listEquals(old.colours, colours) ||
      old.geometry != geometry ||
      !TracePainter._sameTicks(old.valueTicks, valueTicks) ||
      !TracePainter._sameTicks(old.domainTicks, domainTicks);
}
