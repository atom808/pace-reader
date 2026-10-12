/// Where a lap's clock starts, and whether two laps' delta agrees with the
/// game's own splits (comparison proposal §4, decision D1).
///
/// ## Why not simply the `Lap` event
///
/// The game writes its `Lap` event on a 0.02 s grid, so a lap timed from it
/// starts anywhere in a 20 ms window around the real line crossing, and a
/// pair of laps carries the difference of two such errors: a triangular
/// ±20 ms on every number read off the delta (pair residual at S1 p95
/// 15.8 ms, max 38.2 ms over 528,113 cross-file pairs of the user's
/// library).
///
/// The game also writes three times it measured precisely — S1, S1+S2 and
/// the lap — and the trace says when the lap reached each of those lines.
/// Their disagreement is the anchor error, the same at all three lines, so
/// a lap that recorded all three is **re-anchored**: its start moves by the
/// mean of (trace − game) at the three lines. On the library that leaves
/// each lap within 12.15 ms of the game at every line (2,452 laps) and a
/// pair within 17.9 ms (pair p95 1.7–3.0 ms by layout). Laps that did not
/// record all three keep their `Lap` event.
///
/// The same starts drive Trace's same-file delta, so one pair of laps reads
/// the same on every screen (D1).
library;

import '../../data/models/models.dart';
import 'decimation.dart';

/// The game's three timing lines, in lap order.
enum TimingLine {
  sector1('S1'),
  sector2('S1+S2'),
  finish('line');

  const TimingLine(this.label);

  final String label;
}

/// One lap's start, and how its trace met the game's splits.
class LapAnchor {
  const LapAnchor._({
    required this.eventSeconds,
    required this.startSeconds,
    required this.traceMinusGame,
  });

  /// A lap kept on its `Lap` event, with nothing measured: no distance axis,
  /// no course facts, or nothing the game timed.
  const LapAnchor.event(this.eventSeconds)
    : startSeconds = eventSeconds,
      traceMinusGame = const {};

  /// Measures [lap] against the game's splits and re-anchors it when it
  /// recorded all three.
  ///
  /// [axis] is the lap's own `Lap Dist` against time, and [course] the facts
  /// of its file: the sector-line stations and the timing line. A
  /// [recordingStart] lap is never re-anchored. Its `Lap` event is not a
  /// lap boundary — over 407 recordings the first span exceeds the game's
  /// lap time by a median 124.7 s — so its splits describe a start the
  /// trace never saw.
  factory LapAnchor.measure({
    required Lap lap,
    required DistanceAxis? axis,
    required CourseFacts? course,
    bool recordingStart = false,
  }) {
    final event = lap.startSeconds;
    if (axis == null || !axis.isUsable || course == null || recordingStart) {
      return LapAnchor.event(event);
    }
    final s1 = lap.sectors.sector1Seconds;
    final s2 = lap.sectors.sector2Seconds;
    final game = <TimingLine, (double?, double?)>{
      TimingLine.sector1: (course.sector1Station, s1),
      TimingLine.sector2: (
        course.sector2Station,
        s1 == null || s2 == null ? null : s1 + s2,
      ),
      TimingLine.finish: (course.timingLineStation, lap.lapTimeSeconds),
    };
    final measured = <TimingLine, double>{};
    for (final MapEntry(key: line, value: (station, split)) in game.entries) {
      if (station == null || split == null) continue;
      final reached = reachTime(axis, station);
      if (reached == null) continue;
      measured[line] = (reached - event) - split;
    }
    final reanchor = measured.length == TimingLine.values.length;
    final offset = reanchor
        ? measured.values.reduce((a, b) => a + b) / measured.length
        : 0.0;
    return LapAnchor._(
      eventSeconds: event,
      startSeconds: event + offset,
      traceMinusGame: measured,
    );
  }

  /// The lap's `Lap` event, in session seconds.
  final double eventSeconds;

  /// Where the lap's clock starts: [eventSeconds] moved by the anchor error
  /// when re-anchored, [eventSeconds] itself otherwise.
  final double startSeconds;

  /// The trace's time to each line, from the `Lap` event, minus the game's —
  /// only for the lines the game timed and the trace reached.
  final Map<TimingLine, double> traceMinusGame;

  bool get reanchored => traceMinusGame.length == TimingLine.values.length;

  /// How far the start moved.
  double get offset => startSeconds - eventSeconds;

  /// What is left at each line once the start has moved: the lap's own
  /// disagreement with the game, which re-anchoring cannot remove.
  Map<TimingLine, double> get residuals => {
    for (final MapEntry(:key, :value) in traceMinusGame.entries)
      key: value - offset,
  };
}

/// When the lap first reached [station] on [axis] — extrapolated past its
/// last sample at its own last-interval speed, since a lap's last `Lap Dist`
/// sample lands 1.1–11.5 m short of the timing line. Null when the station
/// lies before the lap's first sample, or further past its last than a
/// sample interval or two could honestly carry it.
double? reachTime(DistanceAxis axis, double station) {
  final d = axis.distances;
  final t = axis.times;
  final n = d.length;
  if (n < 2) return null;
  if (station <= d[n - 1]) return axis.firstReachTime(station);
  final step = d[n - 1] - d[n - 2];
  final interval = t[n - 1] - t[n - 2];
  if (step <= 0 || interval <= 0) return null;
  final beyond = station - d[n - 1];
  if (beyond > maxExtrapolation) return null;
  return t[n - 1] + beyond * interval / step;
}

/// How far past a lap's last sample [reachTime] will extrapolate: a 5 Hz
/// sample at 220 km/h is 12 m.
const maxExtrapolation = 25.0;

/// Whether a pair's delta agrees with the game at its three lines
/// (comparison proposal §4, "Delta self-check").
enum DeltaCheckStatus {
  /// Within bounds at every line both laps were timed at.
  passed,

  /// Outside them somewhere: a number on screen would be wrong.
  failed,

  /// No line where both laps carry the game's figure.
  unchecked,
}

class DeltaCheck {
  DeltaCheck._(this.base, this.target, this.pair);

  /// Checks [base] against [target]: each re-anchored lap against the game,
  /// and the pair's delta at each line against the game's difference.
  factory DeltaCheck.of(LapAnchor base, LapAnchor target) {
    final b = base.residuals;
    final t = target.residuals;
    return DeltaCheck._(base, target, {
      for (final line in TimingLine.values)
        if (b[line] != null && t[line] != null) line: b[line]! - t[line]!,
    });
  }

  /// A re-anchored lap's own residual: 12.15 ms at worst on the library.
  static const perLapLimit = 0.015;

  /// A pair of re-anchored laps: 17.9 ms at worst on the library.
  static const pairLimit = 0.020;

  /// A pair where a lap kept its `Lap` event, and so its ±20 ms grid error.
  static const unanchoredPairLimit = 0.030;

  final LapAnchor base;
  final LapAnchor target;

  /// The delta at each line minus the game's difference there.
  final Map<TimingLine, double> pair;

  bool get bothReanchored => base.reanchored && target.reanchored;

  double get pairBound => bothReanchored ? pairLimit : unanchoredPairLimit;

  /// The largest pair residual, by size, or null when none was measured.
  double? get worstPair => _worst(pair.values);

  /// The largest residual of a re-anchored lap, by size.
  double? get worstLap => _worst([
    if (base.reanchored) ...base.residuals.values,
    if (target.reanchored) ...target.residuals.values,
  ]);

  DeltaCheckStatus get status {
    if (pair.isEmpty) return DeltaCheckStatus.unchecked;
    final lap = worstLap;
    if (lap != null && lap.abs() > perLapLimit) return DeltaCheckStatus.failed;
    return worstPair!.abs() > pairBound
        ? DeltaCheckStatus.failed
        : DeltaCheckStatus.passed;
  }

  static double? _worst(Iterable<double> values) {
    double? worst;
    for (final v in values) {
      if (worst == null || v.abs() > worst.abs()) worst = v;
    }
    return worst;
  }
}
