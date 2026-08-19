/// Lap and sector reads (SPEC.md §8.2, §8.3).
library;

import '../duckdb/lap_queries.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';

/// Lap boundaries, times and sector splits.
///
/// Every feature from §8.3 through §8.9 needs "the laps in this session" and
/// "the time window of lap N", so both live here once rather than being
/// re-derived per feature (§9.1: repositories are shared, not per-feature).
class LapRepository {
  LapRepository(this._exec);

  final TelemetryQueryExecutor _exec;

  /// All laps, in order, including the garage lap and the final open one.
  ///
  /// Nothing is filtered out here: which laps count depends on the question
  /// being asked (a lap table shows all of them and marks the odd ones; a pace
  /// statistic uses only [Lap.isTimed]), so the filtering decision belongs to
  /// the caller and the flags to the model.
  Future<List<Lap>> readLaps() async {
    final rows = await _exec.rows(lapTableSql());
    return [
      for (final row in rows)
        Lap(
          index: (row[0] as num).toInt(),
          startSeconds: (row[1] as num).toDouble(),
          endSeconds: (row[2] as num?)?.toDouble(),
          // 0.0 means "not recorded", not a zero-second lap: the game writes
          // it for invalidated laps (2 of 19 in the Race sample), and taking
          // it at face value would show a fastest lap of 0.000.
          lapTimeSeconds: _presence(row[3]),
          sectors: SectorTimes.fromCumulative(
            sector1: _presence(row[4]),
            sector2Cumulative: _presence(row[5]),
            lapTimeSeconds: _presence(row[3]),
          ),
        ),
    ];
  }

  /// The game's own running best, as a cross-check on the best computed from
  /// [readLaps]. Null when the session recorded no timed lap.
  Future<double?> readGameReportedBest() async =>
      _presence(await _exec.scalar(bestLapTimeSql()));

  /// Sector-boundary crossings as `(seconds, sector 1..3)`.
  ///
  /// Gives sector boundaries a *position*, which the sector times alone can't —
  /// what §8.5's segment navigation needs to draw them on the track map.
  Future<List<(double, int)>> readSectorTransitions() async => [
        for (final row in await _exec.rows(sectorTransitionsSql()))
          ((row[0] as num).toDouble(),
              sectorNumberFromCode((row[1] as num).toInt())),
      ];

  static double? _presence(Object? raw) {
    if (raw == null) return null;
    final value = (raw as num).toDouble();
    return value == 0.0 ? null : value;
  }
}
