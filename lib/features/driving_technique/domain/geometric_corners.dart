/// Corners from the road's geometry (SPEC.md §8.13.5): what the road does,
/// where Compare's segments say where the time goes.
///
/// Pure: plain arrays in, plain numbers out, so the detector runs in a plain
/// `flutter test` on constructed paths.
///
/// ## Why geometry, and why a median
///
/// A segment is a speed minimum, so a chicane is one segment and a kink taken
/// flat is none. Curvature sees both. It comes from the GPS path over a ±20 m
/// window, which matches lateral G ÷ v² at r 0.995–0.999 (slope 0.97–1.00) on
/// 18 sessions — and unlike lateral G it is not fooled by banking (0.86–0.88 ×
/// the GPS value on Daytona's). Per-lap detection is not stable (the corner
/// count holds on 8 of 40 laps at Spa), so the detector runs once, on the
/// median over the layout's clean laps, and the result is frozen like
/// Compare's segment table.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// One lap's position channels, read at their own 10 Hz.
class LapPathRead {
  const LapPathRead({
    required this.lap,
    required this.distances,
    required this.latitudes,
    required this.longitudes,
  });

  final int lap;

  /// `Lap Dist`, metres.
  final Float64List distances;
  final Float64List latitudes;
  final Float64List longitudes;

  int get length => distances.length;
}

/// The median curvature of several laps on a uniform `Lap Dist` grid.
class CurvatureProfile {
  const CurvatureProfile({
    required this.spacing,
    required this.curvature,
    required this.laps,
  });

  /// Metres between grid points; point k sits at k × spacing.
  final double spacing;

  /// 1/m, + left. NaN where under half the laps had a value.
  final Float64List curvature;

  /// How many laps the median is over.
  final int laps;

  int get length => curvature.length;
}

/// Metres per degree of latitude, as `projection.dart` uses.
const _metresPerDegree = 111320.0;

/// The grid every lap is resampled onto (m). Fine enough that a 43 m radius
/// hairpin spans dozens of points.
const cornerGridSpacing = 2.0;

/// Curvature's chord half-width (m): heading from a ±20 m chord, then the
/// heading change over ±20 m divided by the path length between.
const curvatureHalfWidth = 20.0;

/// A lap whose `Lap Dist` steps back by more than this (m) is not used.
const _backwardsTolerance = 0.5;

/// The median curvature over [laps], each projected north-up about one shared
/// origin, resampled onto a [spacing] grid and differentiated over
/// ±[halfWidth] metres.
CurvatureProfile medianCurvature(
  List<LapPathRead> laps, {
  double spacing = cornerGridSpacing,
  double halfWidth = curvatureHalfWidth,
}) {
  final usable = [
    for (final lap in laps)
      if (lap.length >= 10 && _forward(lap.distances)) lap,
  ];
  if (usable.isEmpty) {
    return CurvatureProfile(
      spacing: spacing,
      curvature: Float64List(0),
      laps: 0,
    );
  }
  // One origin for every lap, so their headings share a frame.
  final first = usable.first;
  var latSum = 0.0;
  var lonSum = 0.0;
  for (var i = 0; i < first.length; i++) {
    latSum += first.latitudes[i];
    lonSum += first.longitudes[i];
  }
  final lat0 = latSum / first.length;
  final lon0 = lonSum / first.length;
  final lonScale = _metresPerDegree * math.cos(lat0 * math.pi / 180);

  final perLap = <(int, Float64List)>[];
  var gridEnd = 0;
  for (final lap in usable) {
    final k0 = (lap.distances.first / spacing).ceil();
    final k1 = (lap.distances.last / spacing).floor();
    final n = k1 - k0 + 1;
    if (n < 10) continue;
    final x = Float64List(n);
    final y = Float64List(n);
    var j = 0;
    for (var i = 0; i < n; i++) {
      final s = (k0 + i) * spacing;
      while (j < lap.length - 2 && lap.distances[j + 1] < s) {
        j++;
      }
      final a = lap.distances[j];
      final b = lap.distances[j + 1];
      final f = b > a ? ((s - a) / (b - a)).clamp(0.0, 1.0) : 0.0;
      double lerp(Float64List q) => q[j] + f * (q[j + 1] - q[j]);
      x[i] = (lerp(lap.longitudes) - lon0) * lonScale;
      y[i] = (lerp(lap.latitudes) - lat0) * _metresPerDegree;
    }
    perLap.add((k0, _curvature(x, y, (halfWidth / spacing).round())));
    gridEnd = math.max(gridEnd, k0 + n);
  }

  final out = Float64List(gridEnd)..fillRange(0, gridEnd, double.nan);
  final values = <double>[];
  for (var k = 0; k < gridEnd; k++) {
    values.clear();
    for (final (k0, curvature) in perLap) {
      final i = k - k0;
      if (i < 0 || i >= curvature.length) continue;
      final v = curvature[i];
      if (!v.isNaN) values.add(v);
    }
    if (values.isEmpty || values.length * 2 < perLap.length) continue;
    values.sort();
    final mid = values.length ~/ 2;
    out[k] = values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }
  return CurvatureProfile(
    spacing: spacing,
    curvature: out,
    laps: perLap.length,
  );
}

bool _forward(Float64List d) {
  for (var i = 1; i < d.length; i++) {
    if (d[i] < d[i - 1] - _backwardsTolerance) return false;
  }
  return true;
}

/// Signed curvature (1/m, + left) along a resampled path, NaN within 2m
/// points of either end.
Float64List _curvature(Float64List x, Float64List y, int m) {
  final n = x.length;
  final heading = Float64List(n)..fillRange(0, n, double.nan);
  for (var i = m; i < n - m; i++) {
    heading[i] = math.atan2(y[i + m] - y[i - m], x[i + m] - x[i - m]);
  }
  final along = Float64List(n);
  for (var i = 1; i < n; i++) {
    final dx = x[i] - x[i - 1];
    final dy = y[i] - y[i - 1];
    along[i] = along[i - 1] + math.sqrt(dx * dx + dy * dy);
  }
  final out = Float64List(n)..fillRange(0, n, double.nan);
  for (var i = 2 * m; i < n - 2 * m; i++) {
    final length = along[i + m] - along[i - m];
    if (length > 0) out[i] = _wrap(heading[i + m] - heading[i - m]) / length;
  }
  return out;
}

double _wrap(double a) {
  var v = a;
  while (v > math.pi) {
    v -= 2 * math.pi;
  }
  while (v < -math.pi) {
    v += 2 * math.pi;
  }
  return v;
}

/// Which way a corner turns.
enum TurnDirection {
  left('L'),
  right('R');

  const TurnDirection(this.letter);

  final String letter;
}

/// A corner of the road.
class GeoCorner {
  const GeoCorner({
    required this.number,
    required this.start,
    required this.end,
    required this.apex,
    required this.direction,
    required this.radius,
    required this.turnDegrees,
  });

  /// 1..n in track order: never a turn number (§8.13.5).
  final int number;

  /// Where the curvature span starts and ends, `Lap Dist` metres.
  final double start;
  final double end;

  /// The tightest point: the peak of |curvature|.
  final double apex;
  final TurnDirection direction;

  /// 1 / peak curvature, metres.
  final double radius;

  /// How far the road turns over the span, degrees.
  final double turnDegrees;

  bool contains(double station) => station >= start && station <= end;

  GeoCorner renumbered(int n) => GeoCorner(
    number: n,
    start: start,
    end: end,
    apex: apex,
    direction: direction,
    radius: radius,
    turnDegrees: turnDegrees,
  );

  @override
  String toString() =>
      'GeoCorner($number ${direction.letter} '
      '${start.toStringAsFixed(0)}–${end.toStringAsFixed(0)} m, '
      'R ${radius.toStringAsFixed(0)} m, ${turnDegrees.toStringAsFixed(0)}°)';
}

/// The detector's thresholds.
abstract final class CornerDetector {
  /// Bumped whenever detection changes what it finds.
  static const version = 1;

  /// A corner starts where the radius falls to 500 m…
  static const enterCurvature = 1 / 500;

  /// …and ends where it opens past 1 km: hysteresis, so a radius wavering
  /// around one threshold is one corner, not several.
  static const leaveCurvature = 1 / 1000;

  /// A span is split at an interior valley of |curvature| below this share of
  /// the smaller peak either side of it: a chicane's two halves, or two
  /// apexes of one long corner.
  static const splitRatio = 0.5;
}

/// The corners of [profile], in track order.
List<GeoCorner> detectGeoCorners(CurvatureProfile profile) {
  final k = profile.curvature;
  final n = k.length;
  final ds = profile.spacing;
  final spans = <(int, int, int)>[];
  var i = 0;
  while (i < n) {
    if (k[i].isNaN || k[i].abs() < CornerDetector.enterCurvature) {
      i++;
      continue;
    }
    final sign = k[i] > 0 ? 1 : -1;
    var a = i;
    var b = i;
    while (a > 0 &&
        !k[a - 1].isNaN &&
        k[a - 1] * sign >= CornerDetector.leaveCurvature) {
      a--;
    }
    while (b < n - 1 &&
        !k[b + 1].isNaN &&
        k[b + 1] * sign >= CornerDetector.leaveCurvature) {
      b++;
    }
    spans.add((a, b, sign));
    i = b + 1;
  }

  final split = <(int, int, int)>[];
  void splitSpan((int, int, int) span) {
    final (a, b, sign) = span;
    if (b - a < 4) {
      split.add(span);
      return;
    }
    var bestAt = -1;
    var bestRatio = double.infinity;
    for (var j = a + 1; j < b; j++) {
      final here = k[j].abs();
      if (!(here <= k[j - 1].abs() && here <= k[j + 1].abs())) continue;
      var left = 0.0;
      var right = 0.0;
      for (var q = a; q < j; q++) {
        left = math.max(left, k[q].abs());
      }
      for (var q = j + 1; q <= b; q++) {
        right = math.max(right, k[q].abs());
      }
      // Each side must still hold a corner of its own.
      if (left < CornerDetector.enterCurvature ||
          right < CornerDetector.enterCurvature) {
        continue;
      }
      final ratio = here / math.min(left, right);
      if (ratio < bestRatio) {
        bestRatio = ratio;
        bestAt = j;
      }
    }
    if (bestAt < 0 || bestRatio >= CornerDetector.splitRatio) {
      split.add(span);
      return;
    }
    splitSpan((a, bestAt, sign));
    splitSpan((bestAt + 1, b, sign));
  }

  spans.forEach(splitSpan);

  return [
    for (final (index, (a, b, sign)) in split.indexed)
      () {
        var turn = 0.0;
        var peak = 0.0;
        var apex = a;
        for (var j = a; j <= b; j++) {
          turn += k[j] * ds;
          if (k[j].abs() > peak) {
            peak = k[j].abs();
            apex = j;
          }
        }
        return GeoCorner(
          number: index + 1,
          start: a * ds,
          end: b * ds,
          apex: apex * ds,
          direction: sign > 0 ? TurnDirection.left : TurnDirection.right,
          radius: 1 / peak,
          turnDegrees: turn.abs() * 180 / math.pi,
        );
      }(),
  ];
}
