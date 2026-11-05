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

/// What the Target is doing over a cut.
enum GapPhase {
  deploying,
  fullThrottle,
  braking,
  midCorner;

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

/// The lap's gap, phase by phase.
class GapSplit {
  const GapSplit({
    required this.seconds,
    required this.stretches,
    required this.hybrid,
  });

  /// Base's time less the Target's in each phase: positive where Base lost.
  /// Every phase the lap visits has an entry.
  final Map<GapPhase, double> seconds;

  /// Where on the lap each phase is.
  final Map<GapPhase, List<GapStretch>> stretches;

  /// Whether the Target deploys anywhere at full throttle. Without it
  /// [GapPhase.deploying] is absent and full throttle is one row.
  final bool hybrid;

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
      seconds[phase] = (seconds[phase] ?? 0) + loss;
      final runs = stretches.putIfAbsent(phase, () => []);
      if (phase == last && runs.isNotEmpty && runs.last.to == from) {
        runs[runs.length - 1] = (from: runs.last.from, to: to);
      } else {
        runs.add((from: from, to: to));
      }
      last = phase;
    }
    return GapSplit(seconds: seconds, stretches: stretches, hybrid: hybrid);
  }
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
