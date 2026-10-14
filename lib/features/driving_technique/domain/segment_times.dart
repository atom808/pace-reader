/// Each lap's time per segment (SPEC.md §8.13.5, §8.13.9).
library;

import 'dart:typed_data';

/// When a lap crossed [station], interpolated between the `Lap Dist`
/// samples either side; null when it never did.
///
/// A step backwards, or one over 50 m in a 10 Hz sample, is the wrap at the
/// line or a teleport, never a crossing.
double? crossingTime(Float64List times, Float64List distances, double station) {
  for (var k = 1; k < distances.length; k++) {
    final d0 = distances[k - 1];
    final d1 = distances[k];
    if (d0 < station && d1 >= station && d1 > d0 && d1 - d0 < 50) {
      return times[k - 1] +
          (station - d0) / (d1 - d0) * (times[k] - times[k - 1]);
    }
  }
  return null;
}

/// One lap's segment times: from its start to the first boundary, between
/// boundaries, and from the last boundary to the start plus its `Lap Time`
/// — Compare's `LapClock`, so they add up to the lap exactly. Null when the
/// lap missed a boundary or crossed them out of order.
///
/// Measured with crossings either end on 16 Sebring laps, the same segments
/// summed to `Lap Time` within 14 ms (median 5 ms): the lap's own span and
/// its time differ by that much, no more.
List<double>? segmentTimes({
  required Float64List times,
  required Float64List distances,
  required List<double> boundaries,
  required double lapStart,
  required double lapTime,
}) {
  final edges = <double>[lapStart];
  for (final b in boundaries) {
    final t = crossingTime(times, distances, b);
    if (t == null || t <= edges.last) return null;
    edges.add(t);
  }
  final end = lapStart + lapTime;
  if (end <= edges.last) return null;
  edges.add(end);
  return [for (var k = 1; k < edges.length; k++) edges[k] - edges[k - 1]];
}
