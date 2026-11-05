/// The peaks worth pointing at on a trace (map stage P9b): the hottest
/// brake applications, the pressure's highs, a ride height's lowest points.
/// Marked on the panel; a click on one puts the playhead on it, and with it
/// the car on the map.
library;

import 'package:material_ui/material_ui.dart';

import 'decimation.dart';
import 'painters/chart_painting.dart';
import 'viewport.dart';

/// Which way a trace's peaks point.
enum PeakKind {
  /// Highs: a temperature, a pressure, a damper's travel.
  highs,

  /// Lows: a ride height, where the car came nearest the ground.
  lows,
}

/// One peak of a trace, in the panel's domain.
class TracePeak {
  const TracePeak(this.at, this.value);

  final double at;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is TracePeak && other.at == at && other.value == value;

  @override
  int get hashCode => Object.hash(at, value);

  @override
  String toString() => 'TracePeak($at, $value)';
}

/// The [count] most prominent peaks of [plot] pointing [kind], in domain
/// order.
///
/// A peak is the extreme of its neighbourhood, a fiftieth of the trace
/// either side, and its prominence is how far it stands out from the
/// trace's lowest (for highs) point within a tenth either side. Peaks
/// standing out by less than [minProminence] of the trace's span, or by less
/// than [minRise] in its own units, are not peaks, and of two peaks nearer than [minSeparation] of the domain only
/// the more prominent is kept, so a braking zone's ragged top is one peak.
List<TracePeak> findPeaks(
  TracePlot plot, {
  required PeakKind kind,
  int count = 5,
  double minProminence = 0.08,
  double minSeparation = 0.04,
  double minRise = 0,
}) {
  final n = plot.length;
  if (n < 5) return const [];
  final highs = kind == PeakKind.highs;
  double y(int i) => highs ? plot.highs[i] : -plot.lows[i];

  var top = y(0);
  var bottom = y(0);
  for (var i = 1; i < n; i++) {
    final v = y(i);
    if (v > top) top = v;
    if (v < bottom) bottom = v;
  }
  final span = top - bottom;
  if (span <= 0) return const [];

  final near = (n / 100).ceil().clamp(1, n);
  final wide = (n / 20).ceil().clamp(near, n);
  final candidates = <({int index, double prominence})>[];
  for (var i = 0; i < n; i++) {
    final v = y(i);
    var extreme = true;
    for (
      var j = (i - near).clamp(0, n - 1);
      j <= (i + near).clamp(0, n - 1);
      j++
    ) {
      // Ties go to the first sample, so a flat top is one peak.
      if (y(j) > v || (y(j) == v && j < i)) {
        extreme = false;
        break;
      }
    }
    if (!extreme) continue;
    var leftLow = v;
    for (var j = i - 1; j >= (i - wide).clamp(0, n - 1); j--) {
      if (y(j) < leftLow) leftLow = y(j);
    }
    var rightLow = v;
    for (var j = i + 1; j <= (i + wide).clamp(0, n - 1); j++) {
      if (y(j) < rightLow) rightLow = y(j);
    }
    // The higher of the two lows: a peak on a slope stands out only as far
    // as its shallower side.
    final prominence = v - (leftLow > rightLow ? leftLow : rightLow);
    if (prominence >= minProminence * span && prominence >= minRise) {
      candidates.add((index: i, prominence: prominence));
    }
  }
  candidates.sort((a, b) => b.prominence.compareTo(a.prominence));

  final domain = ChartViewport(plot.xs.first, plot.xs.last);
  final apart = domain.span * minSeparation;
  final kept = <int>[];
  for (final c in candidates) {
    if (kept.length == count) break;
    final x = plot.xs[c.index];
    if (kept.every((k) => (plot.xs[k] - x).abs() >= apart)) kept.add(c.index);
  }
  kept.sort();
  return [
    for (final i in kept)
      TracePeak(plot.xs[i], highs ? plot.highs[i] : plot.lows[i]),
  ];
}

/// How near a pointer must come to a peak's mark, in pixels, to take it.
const peakHitSlop = 12.0;

/// The peak of [peaks] whose mark on [geometry] lies within [slop] of
/// [local], the nearest if several do; null for none.
TracePeak? peakNear(
  List<TracePeak> peaks,
  ChartGeometry geometry,
  Offset local, {
  double slop = peakHitSlop,
}) {
  TracePeak? best;
  var bestDistance = slop;
  for (final p in peaks) {
    if (!geometry.viewport.contains(p.at)) continue;
    final d = (Offset(geometry.x(p.at), geometry.y(p.value)) - local).distance;
    if (d <= bestDistance) {
      best = p;
      bestDistance = d;
    }
  }
  return best;
}

/// [peaks] as small rings on the trace; the [hovered] one larger, with its
/// value beside it — above a mark in the panel's lower half, below one in
/// its upper half, so the number never leaves the panel. Values only on
/// hover, as in the reference apps: five numbers to a panel crowd out the
/// trace they are about.
class PeakPainter extends CustomPainter {
  const PeakPainter({
    required this.peaks,
    required this.geometry,
    required this.palette,
    required this.format,
    this.hovered,
  });

  final List<TracePeak> peaks;
  final TracePeak? hovered;
  final ChartGeometry geometry;
  final ChartPalette palette;
  final String Function(double) format;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    for (final p in peaks) {
      if (!scaled.viewport.contains(p.at)) continue;
      final at = Offset(scaled.x(p.at), scaled.y(p.value));
      final lit = p == hovered;
      // A ring rather than a dot: it reads as "a place you can go" and
      // leaves the trace's own value visible through it.
      canvas.drawCircle(at, lit ? 6 : 4, Paint()..color = palette.surface);
      canvas.drawCircle(
        at,
        lit ? 5 : 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lit ? 2 : 1.4
          ..color = palette.series,
      );
      if (!lit) continue;
      final text = TextPainter(
        text: TextSpan(
          text: format(p.value),
          style: palette.labelStyle.copyWith(
            color: palette.series,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: palette.surface, blurRadius: 3),
              Shadow(color: palette.surface, blurRadius: 3),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final y = at.dy > size.height / 2 ? at.dy - 9 - text.height : at.dy + 9;
      final x = (at.dx - text.width / 2).clamp(
        2.0,
        size.width - text.width - 2,
      );
      text.paint(canvas, Offset(x, y));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(PeakPainter old) =>
      !identical(old.peaks, peaks) ||
      old.hovered != hovered ||
      old.geometry != geometry ||
      old.palette.series != palette.series;
}
