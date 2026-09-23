/// Time gained or lost against a reference lap, around the lap (SPEC.md §8.3,
/// §8.4).
///
/// ## What is compared, and why
///
/// Two laps are compared **at the same point of the circuit**, not at the same
/// moment: the delta at distance `d` is how much longer this lap took to reach
/// `d` than the reference did. Comparing at equal times would line up a corner
/// entry on one lap with a straight on the other the moment either lap gains a
/// tenth, and every value after that would describe two different places.
///
/// Each lap's time is measured **from its own `Lap` event**, the game's own
/// line-crossing timestamp, rather than from the first `Lap Dist` sample. That
/// sample lands up to one 10 Hz period after the line — 0 to 4.4 m into the
/// lap on the Sebring Race sample — so anchoring on it would add up to a tenth
/// of noise to the one number a user reads off the end of the trace.
///
/// ## Checked against the file's own ground truth
///
/// A delta trace has one value the recording can confirm independently: at the
/// finish it must equal the difference between the two laps' `Lap Time`s.
/// Measured on every pair of the real samples' timed flying laps against each
/// session's best (15 pairs at Sebring, one at Interlagos), the end of the
/// trace lands within **0.0154 s** of that difference — a sixth of one 10 Hz
/// sample period — and the trace starts within 0.02 s of zero.
///
/// Anchoring on the first shared distance sample instead measured worse at the
/// finish (0.020 s) while forcing an exact zero at the start, so the start
/// anchor is the lap event: the line crossing is a fact the game recorded, and
/// the first `Lap Dist` sample is only the first time anyone looked.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'decimation.dart';
import 'viewport.dart';

/// The delta of one lap against a reference, sampled at the lap's own
/// `Lap Dist` points.
class LapDelta {
  LapDelta._(this.times, this.distances, this.deltas);

  /// Compares [lap] against [reference], or returns null when no comparison by
  /// position is possible.
  ///
  /// Null when either axis is unusable — the garage lap, where `Lap Dist` runs
  /// backwards while the car manoeuvres in the pits (see
  /// [DistanceAxis.isMonotonic]) — because a distance that occurs twice on a
  /// lap has no single time to compare. Also null when the two laps share no
  /// stretch of track at all.
  ///
  /// Only the stretch both laps recorded is compared: a sample of [lap] past
  /// the last distance [reference] reached has nothing to be compared with,
  /// and extrapolating the reference to it would invent the part of the delta
  /// a user reads first.
  static LapDelta? between({
    required DistanceAxis lap,
    required double lapStartSeconds,
    required DistanceAxis reference,
    required double referenceStartSeconds,
  }) {
    if (!lap.isUsable || !reference.isUsable) return null;
    final from = math.max(lap.distances.first, reference.distances.first);
    final to = math.min(lap.distances.last, reference.distances.last);
    if (to <= from) return null;

    final times = <double>[];
    final distances = <double>[];
    final deltas = <double>[];
    for (var i = 0; i < lap.times.length; i++) {
      final distance = lap.distances[i];
      if (distance < from || distance > to) continue;
      final elapsed = lap.times[i] - lapStartSeconds;
      final referenceElapsed =
          reference.timeAt(distance) - referenceStartSeconds;
      times.add(lap.times[i]);
      distances.add(distance);
      deltas.add(elapsed - referenceElapsed);
    }
    if (times.length < 2) return null;
    return LapDelta._(
      Float64List.fromList(times),
      Float64List.fromList(distances),
      Float64List.fromList(deltas),
    );
  }

  /// The lap's own clock at each sample, in session seconds.
  final Float64List times;

  /// Lap distance at each sample, in metres.
  final Float64List distances;

  /// Seconds behind the reference at each sample: positive means slower so
  /// far, negative means ahead.
  final Float64List deltas;

  int get length => times.length;

  /// The delta where the comparison ends — within 0.0154 s of the lap-time
  /// difference on every pair measured (see the library comment).
  double get finalDelta => deltas.last;

  /// The delta as a plot on [axis]: against the lap's own distance, or its own
  /// clock. Either way the x values are the lap's, so the trace shares the
  /// panels' domain and cursor.
  ///
  /// Its value range always includes zero, because zero is the line the whole
  /// panel is read against — a range fitted to a lap that only ever lost time
  /// would push "level with the reference" off the bottom of the panel.
  TracePlot toPlot(TraceAxis axis, {String label = 'Delta'}) {
    final range = ValueRange.ofAll(deltas) ?? const ValueRange(0, 0);
    return TracePlot(
      label: label,
      unit: 's',
      xs: axis == TraceAxis.distance ? distances : times,
      lows: deltas,
      highs: deltas,
      valueRange: range.union(const ValueRange(0, 0)),
    );
  }
}
