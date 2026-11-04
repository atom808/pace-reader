/// Where a second lap is at one moment of the first (map stage proposal
/// §3.3.1; comparison proposal §6 "Ghost").
///
/// Lifted out of Compare's map so the Trace stage and Compare place a
/// reference car the same way. Plain Dart: no Flutter, no providers.
///
/// Both laps are read through their own `Lap Dist` against their own clock
/// (a [DistanceAxis] each); the map's metres never enter into it, and neither
/// does Δ × speed, which is 2.6% out at the median and 25% at worst
/// (comparison proposal §6).
library;

import 'decimation.dart';

class LapAlignment {
  const LapAlignment({this.base, this.reference, this.timeShift = 0});

  /// The first lap's `Lap Dist` against its clock.
  final DistanceAxis? base;

  /// The second lap's, on its own clock.
  final DistanceAxis? reference;

  /// Seconds that put the reference on the base lap's clock: the reference
  /// at its own time `s` is shown at the base's `s + timeShift`.
  final double timeShift;

  /// `Lap Dist` on [axis] at [seconds] of its own clock; null outside its
  /// recorded span or when it has no usable distance.
  static double? stationAt(DistanceAxis? axis, double seconds) {
    if (axis == null || !axis.isUsable) return null;
    if (seconds < axis.times.first || seconds > axis.times.last) return null;
    return axis.distanceAt(seconds);
  }

  /// The base lap's `Lap Dist` at its [seconds]; null off its lap.
  double? baseStationAt(double seconds) => stationAt(base, seconds);

  /// The reference's `Lap Dist` at the same moment as the base's [seconds];
  /// null off its lap.
  double? referenceStationAt(double seconds) =>
      stationAt(reference, seconds - timeShift);

  /// Where the reference is, as a `Lap Dist`, when the playhead is at
  /// [playhead] on [axis].
  ///
  /// - **Distance:** at the same point of the lap. That is what the
  ///   Distance axis means, so the two cars sit together.
  /// - **Time:** where it was at the same moment, so the gap between the cars
  ///   *is* the time difference, laid out on the track.
  double? referenceStationFor(TraceAxis axis, double playhead) =>
      switch (axis) {
        TraceAxis.distance => playhead,
        TraceAxis.time => referenceStationAt(playhead),
      };

  /// The reference's `Lap Dist` less the base's at the base's [seconds]:
  /// + when the reference is ahead. Null when either is off its lap.
  double? gapAt(double seconds) {
    final b = baseStationAt(seconds);
    final r = referenceStationAt(seconds);
    return b == null || r == null ? null : r - b;
  }
}
