/// Caught slides: steering against the turn (SPEC.md §8.13.3).
library;

import 'technique_thresholds.dart';

/// One 10 Hz sample that meets the countersteer condition: |steer| ≥ 5 %
/// with the sign of lateral G (in a turn they are opposite), |lateral G| ≥
/// 0.5 G, above 60 km/h. The query returns only these.
class SteerSample {
  const SteerSample({
    required this.lap,
    required this.index,
    required this.seconds,
    required this.station,
    required this.steer,
    required this.lateralG,
    required this.speed,
  });

  final int lap;

  /// The 10 Hz row: consecutive samples have consecutive indices.
  final int index;
  final double seconds;

  /// `Lap Dist`, in metres.
  final double station;

  /// `Steering Pos` in %, + right.
  final double steer;

  /// `G Force Long` (the lateral channel, §5.4), + left.
  final double lateralG;

  /// Ground Speed, km/h.
  final double speed;
}

/// A slide the driver caught.
class CountersteerEpisode {
  const CountersteerEpisode({
    required this.lap,
    required this.startSeconds,
    required this.endSeconds,
    required this.station,
    required this.peakSteer,
    required this.speed,
    required this.samples,
  });

  final int lap;
  final double startSeconds;
  final double endSeconds;

  /// Where it began, in `Lap Dist` metres.
  final double station;

  /// The largest opposite lock, |%|.
  final double peakSteer;

  /// Ground Speed when it began.
  final double speed;
  final int samples;

  double get seconds => endSeconds - startSeconds + 0.1;
}

/// Groups [candidates] into episodes: runs of consecutive 10 Hz samples of
/// one lap, at least three long, whose largest |steer| reaches 20 %.
///
/// On the three original samples this finds exactly one episode, Spa
/// qualifying's lap 3: steering from +7 % to −81.5 % in 0.7 s through a
/// right-hander at 126 km/h. The clean lap of that file has none, and
/// Sebring's Race none in 17 laps.
List<CountersteerEpisode> countersteerEpisodes(List<SteerSample> candidates) {
  final sorted = [...candidates]..sort((a, b) => a.index.compareTo(b.index));
  final out = <CountersteerEpisode>[];
  var run = <SteerSample>[];

  void close() {
    if (run.length >= TechniqueThresholds.countersteerSamples) {
      final peak = run
          .map((s) => s.steer.abs())
          .reduce((a, b) => a > b ? a : b);
      if (peak >= TechniqueThresholds.countersteerPeak) {
        out.add(
          CountersteerEpisode(
            lap: run.first.lap,
            startSeconds: run.first.seconds,
            endSeconds: run.last.seconds,
            station: run.first.station,
            peakSteer: peak,
            speed: run.first.speed,
            samples: run.length,
          ),
        );
      }
    }
    run = <SteerSample>[];
  }

  for (final s in sorted) {
    final last = run.isEmpty ? null : run.last;
    if (last != null && (s.index != last.index + 1 || s.lap != last.lap)) {
      close();
    }
    run.add(s);
  }
  close();
  return out;
}
