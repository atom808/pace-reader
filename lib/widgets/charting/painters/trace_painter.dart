/// Line-trace painters for the chart core (SPEC.md §9.5, §9.7.1).
library;

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

    paintValueLabels(canvas, scaled, palette,
        ticks: valueTicks, format: formatValue);
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
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );

    paintDomainGrid(canvas, scaled, palette, ticks: domainTicks);
    paintValueGrid(canvas, scaled, palette, ticks: valueTicks);

    if (plot.isNotEmpty) {
      canvas.drawPath(
        Path()..addPolygon(_stepPoints(plot, scaled, size), false),
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

    paintValueLabels(canvas, scaled, palette,
        ticks: valueTicks, format: formatValue);
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

    final zero = scaled.y(0);
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

    paintValueLabels(canvas, scaled, palette,
        ticks: valueTicks, format: formatValue);
  }

  @override
  bool shouldRepaint(DeltaTracePainter old) =>
      !identical(old.plot, plot) ||
      old.geometry != geometry ||
      old.palette.series != palette.series ||
      !TracePainter._sameTicks(old.valueTicks, valueTicks) ||
      !TracePainter._sameTicks(old.domainTicks, domainTicks);
}
