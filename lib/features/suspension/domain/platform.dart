/// The platform as a whole: ride heights, packers, roll and the dampers
/// (suspension proposal §4.5, §5).
library;

import '../../../data/duckdb/suspension_queries.dart' show damperSpeedEdges;
import '../../../data/models/models.dart';
import 'suspension_thresholds.dart';

/// One racing lap's platform numbers.
class LapPlatform {
  const LapPlatform({
    required this.lap,
    this.samplesAtSpeed = 0,
    this.frontMedian,
    this.rearMedian,
    this.frontLowest,
    this.rearLowest,
    this.frontPackers,
    this.rearPackers,
    this.frontRoll,
    this.frontRollR,
    this.rearRoll,
    this.rearRollR,
    this.rollSamples = 0,
  });

  final int lap;

  /// Samples above [platformSpeedKph].
  final int samplesAtSpeed;

  /// The axle's median ride height above [platformSpeedKph], m.
  final double? frontMedian;
  final double? rearMedian;

  /// The axle's lowest corner, m.
  final double? frontLowest;
  final double? rearLowest;

  /// The share of time above [platformSpeedKph] the third element sat on its
  /// packers; null without a third element.
  final double? frontPackers;
  final double? rearPackers;

  /// Left minus right travel per G of lateral load, mm/G, and its r. Roll is
  /// millimetres of travel per G, not degrees.
  final double? frontRoll;
  final double? frontRollR;
  final double? rearRoll;
  final double? rearRollR;
  final int rollSamples;

  /// Front roll over rear: above 1 the front rolls more. A step in it is the
  /// balance changing, as an in-car bar change does (SPEC.md §5.4).
  double? get rollRatio {
    final f = frontRoll;
    final r = rearRoll;
    if (f == null || r == null || r.abs() < 1e-6) return null;
    return f / r;
  }
}

/// The session's third-element ceilings: where each third rests on its
/// packers, m.
class ThirdCeilings {
  const ThirdCeilings({this.front, this.rear});

  final double? front;
  final double? rear;
}

/// The laps where the roll balance stepped (§4.5): each lap whose front-to-
/// rear ratio moved more than [balanceStepShare] from the median of the
/// [balanceWindowLaps] laps before it. In-car bar changes are not logged,
/// so this is how they show.
List<int> balanceSteps(List<LapPlatform> laps) {
  final out = <int>[];
  final history = <double>[];
  for (final lap in laps) {
    final ratio = lap.rollRatio;
    if (ratio == null) continue;
    if (history.length >= balanceWindowLaps) {
      final recent = [...history.sublist(history.length - balanceWindowLaps)]
        ..sort();
      final median = recent[recent.length ~/ 2];
      if (median.abs() > 1e-6 &&
          ((ratio - median) / median).abs() > balanceStepShare) {
        out.add(lap.lap);
        // A new balance starts here: compare what follows with it.
        history.clear();
      }
    }
    history.add(ratio);
  }
  return out;
}

/// Damper-speed counts for one corner: bump bins 0…, rebound −1….
class DamperHistogram {
  const DamperHistogram(this.counts);

  static const empty = DamperHistogram({});

  final Map<int, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  /// The bins either side, slowest first.
  static int get binsPerSide => damperSpeedEdges.length;

  static double lowerEdge(int bin) =>
      damperSpeedEdges[bin >= 0 ? bin : -bin - 1];

  static double? upperEdge(int bin) {
    final k = (bin >= 0 ? bin : -bin - 1) + 1;
    return k < damperSpeedEdges.length ? damperSpeedEdges[k] : null;
  }

  int at(int bin) => counts[bin] ?? 0;

  DamperHistogram operator +(DamperHistogram other) {
    final out = Map.of(counts);
    other.counts.forEach((k, v) => out[k] = (out[k] ?? 0) + v);
    return DamperHistogram(out);
  }

  /// The share of samples faster than [knee] mm/s, either way.
  double fastShare(double knee) {
    final total = this.total;
    if (total == 0) return 0;
    var fast = 0;
    counts.forEach((bin, n) {
      if (lowerEdge(bin) >= knee) fast += n;
    });
    return fast / total;
  }
}

/// Where a car's dampers move from their slow to their fast circuit, mm/s.
class DamperKnee {
  const DamperKnee({
    required this.front,
    required this.rear,
    required this.measured,
    this.source,
  });

  final double front;
  final double rear;

  /// False for the default every untested car gets.
  final bool measured;
  final String? source;

  double of(Corner corner) => corner.isFront ? front : rear;

  /// Not in the recording and not in the setup: found by experiment, per car
  /// (D5). The Alpine A424's is from your two extreme damper runs, B and C,
  /// where the histograms diverged: front 80–100, rear 100–150 mm/s.
  static DamperKnee forCar(String carName) {
    final name = carName.toLowerCase();
    if (name.contains('a424') || name.contains('alpine')) {
      return const DamperKnee(
        front: 90,
        rear: 125,
        measured: true,
        source:
            'Measured on your Alpine A424 damper runs B and C at Le Mans: '
            'the two setups\' damper-speed histograms part at 80–100 mm/s '
            'front and 100–150 mm/s rear.',
      );
    }
    return const DamperKnee(front: 100, rear: 100, measured: false);
  }
}
