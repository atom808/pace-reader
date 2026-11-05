/// Where the lap's gap goes, by what the Target is doing at each point of
/// the lap (GO reference proposal P3; PACE-FACTORS §10).
///
/// The lap is cut every [gapSplitStep] metres. Each cut's loss is Base's time
/// across it less the Target's, from the same clocks the segments use, so the
/// phases sum to the lap's delta exactly as the segments do. The cut goes to
/// one phase by the Target's pedals, and its battery, at the cut's middle.
///
/// What it tells apart: a gap lost at full throttle is mostly what the car
/// carries (fuel, battery, drag); one lost under braking and mid-corner is
/// mostly the driving. Against GO's 499P at Bahrain, 1.36 of 2.36 s went at
/// full throttle and 0.08 s mid-corner; against its Genesis at Daytona, 1.54
/// of 3.12 s went under braking. It states where, never why.
///
/// Full throttle is split once more, on each straight (proposal P8): where
/// Base's speed gap to the Target closes from the straight's start to its
/// end, the loss there was carried from the corner before; where it grows,
/// it was made on the straight. Against GO's ORECA at Spa, 1.74 of the 2.14 s
/// lost on straights was carried; against its Genesis at Daytona, none was
/// (PACE-FACTORS §10.6).
library;

import 'segment_findings.dart';
import 'segment_losses.dart';

/// The length of one cut (m).
const gapSplitStep = 5.0;

/// The Target is braking above this pedal (%), as the braking share of a
/// lap counts it (PACE-FACTORS §9).
const gapBrakeOn = 2.0;

/// The Target is at full throttle from this pedal (%).
const gapFullThrottle = 98.0;

/// The Target is deploying below this `Regen Rate` (W): a kilowatt, under the
/// smallest map step measured (19.6 kW on the 499P).
const gapDeploying = -1000.0;

/// The least length of full throttle that counts as a straight (m): a
/// shorter run is a squeeze between corners, with no speed gap to follow.
const gapStraightMin = 100.0;

/// How far back from a straight the map lights its corner exit (m): the
/// Target's part-throttle run before it, at most this much.
const gapExitReach = 150.0;

/// What the Target is doing over a cut.
enum GapPhase {
  deploying,
  fullThrottle,
  braking,
  midCorner;

  /// Whether the Target is at full throttle, deploying or not.
  bool get isFullThrottle => this == deploying || this == fullThrottle;

  /// The row's label; [hybrid] when the Target deploys anywhere on the lap,
  /// so full throttle comes in two rows.
  String label({required bool hybrid}) => switch (this) {
    deploying => 'Full throttle, Target deploying',
    fullThrottle => hybrid ? 'Full throttle, no deployment' : 'Full throttle',
    braking => 'Target braking',
    midCorner => 'Mid-corner',
  };
}

/// A run of consecutive cuts in one phase, in `Lap Dist`.
typedef GapStretch = ({double from, double to});

/// Full throttle's loss on the straights, by whether it came out of the
/// corner before or was made on the straight itself.
class GapStraights {
  const GapStraights({
    required this.carried,
    required this.made,
    required this.carriedStretches,
  });

  /// The loss on straights where Base's speed gap to the Target is no
  /// larger at the end than at the start: set by the corner before.
  final double carried;

  /// The loss on straights where the gap grows.
  final double made;

  /// The carried straights, each from the corner exit before it, for the map.
  final List<GapStretch> carriedStretches;

  /// Whether either part clears the segments' noise floor; otherwise the
  /// card says nothing about the straights.
  bool get stated =>
      carried.abs() >= segmentNoiseFloor || made.abs() >= segmentNoiseFloor;
}

/// The lap's gap, phase by phase.
class GapSplit {
  const GapSplit({
    required this.seconds,
    required this.stretches,
    required this.hybrid,
    this.straights,
  });

  /// Base's time less the Target's in each phase: positive where Base lost.
  /// Every phase the lap visits has an entry.
  final Map<GapPhase, double> seconds;

  /// Where on the lap each phase is.
  final Map<GapPhase, List<GapStretch>> stretches;

  /// Whether the Target deploys anywhere at full throttle. Without it
  /// [GapPhase.deploying] is absent and full throttle is one row.
  final bool hybrid;

  /// Full throttle on the straights, carried or made; null where the lap has
  /// no full-throttle run of [gapStraightMin].
  final GapStraights? straights;

  /// The lap's delta, as the phases sum to it.
  double get total => seconds.values.fold(0.0, (a, b) => a + b);

  /// The phases in the order the card lists them: the car's first, then the
  /// driving.
  List<GapPhase> get phases => [
    for (final p in GapPhase.values)
      if (seconds.containsKey(p)) p,
  ];

  /// Cuts [base] and [target]'s clocks every [step] metres and sorts each
  /// cut by the Target's [throttle], [brake] and [regen], placed on its own
  /// `Lap Dist`. Null without the pedals.
  static GapSplit? measure({
    required LapClock base,
    required LapClock target,
    required PlacedSeries? throttle,
    required PlacedSeries? brake,
    PlacedSeries? regen,
    double step = gapSplitStep,
  }) {
    if (throttle == null || brake == null) return null;
    final length = target.wrapLength;
    final seconds = <GapPhase, double>{};
    final stretches = <GapPhase, List<GapStretch>>{};
    final cuts = <_Cut>[];
    var hybrid = false;
    GapPhase? last;
    for (var i = 0; i * step < length; i++) {
      final from = i * step;
      final to = (i + 1) * step < length ? (i + 1) * step : length;
      final middle = (from + to) / 2;
      final phase = _phaseAt(middle, throttle, brake, regen) ?? last;
      if (phase == null) continue;
      if (phase == GapPhase.deploying) hybrid = true;
      final loss =
          (base.at(to) - base.at(from)) - (target.at(to) - target.at(from));
      cuts.add((from: from, to: to, phase: phase, loss: loss));
      seconds[phase] = (seconds[phase] ?? 0) + loss;
      final runs = stretches.putIfAbsent(phase, () => []);
      if (phase == last && runs.isNotEmpty && runs.last.to == from) {
        runs[runs.length - 1] = (from: runs.last.from, to: to);
      } else {
        runs.add((from: from, to: to));
      }
      last = phase;
    }
    return GapSplit(
      seconds: seconds,
      stretches: stretches,
      hybrid: hybrid,
      straights: _straights(cuts, base, target),
    );
  }
}

typedef _Cut = ({double from, double to, GapPhase phase, double loss});

/// Each full-throttle run of [gapStraightMin] or more, sorted by whether
/// Base's speed gap to the Target closed along it. A straight across the
/// line counts as two, one each side: the lap's own ends are not joined.
GapStraights? _straights(List<_Cut> cuts, LapClock base, LapClock target) {
  var carried = 0.0;
  var made = 0.0;
  var any = false;
  final lit = <GapStretch>[];
  var i = 0;
  while (i < cuts.length) {
    if (!cuts[i].phase.isFullThrottle) {
      i++;
      continue;
    }
    var j = i;
    while (j + 1 < cuts.length &&
        cuts[j + 1].phase.isFullThrottle &&
        cuts[j + 1].from == cuts[j].to) {
      j++;
    }
    final first = cuts[i];
    final end = cuts[j];
    final gapIn = _speedGap(base, target, first);
    final gapOut = _speedGap(base, target, end);
    if (end.to - first.from >= gapStraightMin &&
        gapIn != null &&
        gapOut != null) {
      any = true;
      var loss = 0.0;
      for (var k = i; k <= j; k++) {
        loss += cuts[k].loss;
      }
      if (gapOut.abs() <= gapIn.abs()) {
        carried += loss;
        lit.add((from: _exitStart(cuts, i), to: end.to));
      } else {
        made += loss;
      }
    }
    i = j + 1;
  }
  return any
      ? GapStraights(carried: carried, made: made, carriedStretches: lit)
      : null;
}

/// The Target's speed less Base's across [cut] (m/s); null where either
/// clock stands still there.
double? _speedGap(LapClock base, LapClock target, _Cut cut) {
  double? speed(LapClock clock) {
    final dt = clock.at(cut.to) - clock.at(cut.from);
    return dt > 0 ? (cut.to - cut.from) / dt : null;
  }

  final b = speed(base);
  final t = speed(target);
  return b == null || t == null ? null : t - b;
}

/// Where the corner exit before the straight at [cuts]\[[straight]\] begins:
/// back through the Target's part-throttle cuts, at most [gapExitReach].
double _exitStart(List<_Cut> cuts, int straight) {
  final start = cuts[straight].from;
  var from = start;
  for (var k = straight - 1; k >= 0; k--) {
    final cut = cuts[k];
    if (cut.phase != GapPhase.midCorner ||
        cut.to != from ||
        start - cut.from > gapExitReach) {
      break;
    }
    from = cut.from;
  }
  return from;
}

/// The phase at [station]; null off the pedals' samples.
GapPhase? _phaseAt(
  double station,
  PlacedSeries throttle,
  PlacedSeries brake,
  PlacedSeries? regen,
) {
  final b = brake.valueAtStation(station);
  final t = throttle.valueAtStation(station);
  if (b == null || t == null) return null;
  if (b > gapBrakeOn) return GapPhase.braking;
  if (t < gapFullThrottle) return GapPhase.midCorner;
  final r = regen?.valueAtStation(station);
  return r != null && r < gapDeploying
      ? GapPhase.deploying
      : GapPhase.fullThrottle;
}
