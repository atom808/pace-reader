/// Pace statistics derived from a set of laps (SPEC.md §8.2, §8.3).
///
/// Lives in `models/` rather than in the repository because it is arithmetic
/// over already-fetched laps, not a query — which keeps it inside the test
/// surface a plain `flutter test` can reach, without importing the DuckDB
/// layer (and so `dart_duckdb`'s native library) at all.
library;

import 'dart:math' as math;

import 'lap.dart';

extension LapPaceStatistics on List<Lap> {
  /// Laps usable for pace analysis: timed, closed, and excluding the garage
  /// lap (§5.2 — lap 0 starts in the pits, so its time isn't comparable).
  List<Lap> get timed => where((lap) => lap.isTimed).toList();

  /// Completed laps. `COUNT(*)` on the `Lap` table counts lap *starts*, so it
  /// overstates this by one (§5.2/§8.2).
  int get completedCount => where((lap) => lap.endSeconds != null).length;

  Lap? get bestLap {
    Lap? best;
    for (final lap in timed) {
      if (best == null || lap.lapTimeSeconds! < best.lapTimeSeconds!) {
        best = lap;
      }
    }
    return best;
  }

  /// Sum of the best sector 1, 2 and 3 across all laps — the lap time the
  /// driver's own best sectors imply (§8.2). Null unless every sector has at
  /// least one recorded value.
  double? get theoreticalBestSeconds {
    final bests = List<double?>.filled(3, null);
    for (final lap in timed) {
      final sectors = lap.sectors.all;
      for (var i = 0; i < 3; i++) {
        final value = sectors[i];
        if (value != null && (bests[i] == null || value < bests[i]!)) {
          bests[i] = value;
        }
      }
    }
    if (bests.any((b) => b == null)) return null;
    return bests.fold<double>(0, (sum, b) => sum + b!);
  }

  /// Standard deviation of timed lap times — §8.3's consistency measure.
  /// Null with fewer than two timed laps, where spread is undefined rather
  /// than zero.
  double? get consistencyStdDevSeconds {
    final times = timed.map((l) => l.lapTimeSeconds!).toList();
    if (times.length < 2) return null;
    final mean = times.reduce((a, b) => a + b) / times.length;
    final variance = times
            .map((t) => (t - mean) * (t - mean))
            .reduce((a, b) => a + b) /
        (times.length - 1);
    return math.sqrt(variance);
  }
}
