/// Lap and sector queries (SPEC.md §5.2, §8.2, §8.3).
///
/// Lap boundaries come from the `Lap` event table, whose values are **0-based**
/// and whose row count is *not* the lap count: row 0 marks the recording start
/// with the car in the garage, and the final row opens a lap the file has no
/// closing boundary for.
library;

import 'sql.dart';

/// Event table names this module reads. Named as constants because the
/// relationships between them are the non-obvious part, not the strings.
const lapEventTable = 'Lap';
const lapTimeEventTable = 'Lap Time';
const lastSector1EventTable = 'Last Sector1';
const lastSector2EventTable = 'Last Sector2';
const bestLapTimeEventTable = 'Best LapTime';
const currentSectorEventTable = 'Current Sector';

/// Tables [lapTableSql] depends on, for the catalog check that fails clearly
/// rather than crashing when a future LMU version renames one (§10).
const requiredLapTables = [
  lapEventTable,
  lapTimeEventTable,
  lastSector1EventTable,
  lastSector2EventTable,
];

/// One row per lap: `(lap_index, start_ts, end_ts, lap_time, sector1,
/// sector2_cumulative)`.
///
/// ## Why a lap's time is read at its *end* boundary
///
/// `Lap Time` is emitted at the moment a lap completes — which is the same
/// timestamp as the *next* lap's `Lap` event. So the time of the lap starting
/// at `ts` is the `Lap Time` row at `lead(ts)`, not at `ts`. Same for
/// `Last Sector1`/`Last Sector2`, which report the just-finished lap.
///
/// ## Why an exact `=` join, and not `ASOF`
///
/// Every `Lap Time`/`Last Sector*`/`Best LapTime` timestamp is *exactly* equal
/// to some `Lap` timestamp — verified as 0 orphans across all three samples,
/// so float identity holds and equality is safe. It's also the only *correct*
/// join: laps legitimately have no `Lap Time` row at all (an untimed out-lap —
/// the Practice and Qualify samples both start with one), and `ASOF` would
/// resolve those to the *previous* lap's time instead of to nothing, silently
/// attributing one lap's pace to another. Equality yields null, which is the
/// truth.
///
/// ## Why `lap_time` is never `end_ts - start_ts`
///
/// On the Race sample's lap 0 those disagree by 101 s: the wall-clock span
/// covers garage and grid time while the game times only from the start. The
/// span is returned too, but strictly as a diagnostic.
String lapTableSql() {
  final lap = quoteIdent(lapEventTable);
  final value = quoteIdent('value');
  return 'WITH _b AS ('
      'SELECT $value AS lap_index, ts AS start_ts, '
      'lead(ts) OVER (ORDER BY ts) AS end_ts FROM $lap) '
      'SELECT _b.lap_index, _b.start_ts, _b.end_ts, '
      'lt.$value AS lap_time, s1.$value AS sector1, s2.$value AS sector2_cum '
      'FROM _b '
      'LEFT JOIN ${quoteIdent(lapTimeEventTable)} lt ON lt.ts = _b.end_ts '
      'LEFT JOIN ${quoteIdent(lastSector1EventTable)} s1 ON s1.ts = _b.end_ts '
      'LEFT JOIN ${quoteIdent(lastSector2EventTable)} s2 ON s2.ts = _b.end_ts '
      'ORDER BY _b.lap_index';
}

/// The game's own running best lap time — its final value is the session best.
///
/// Read as a cross-check against the best computed from [lapTableSql], not as
/// the primary source: a best derived from the lap table is guaranteed to
/// match the lap the UI highlights, whereas this table's value could in
/// principle come from a lap the file didn't fully record.
String bestLapTimeSql() =>
    'SELECT ${quoteIdent('value')} FROM ${quoteIdent(bestLapTimeEventTable)} '
    'ORDER BY ts DESC LIMIT 1';

/// Sector-boundary crossings, as `(ts, sector_code)`.
///
/// `Current Sector` cycles `1 → 2 → 0`, so **code 0 is sector 3**, not a
/// missing value — confirmed by measuring durations between transitions
/// against the reported splits. This is what gives sector boundaries a
/// *position* on the track map (§8.5), which the sector *times* alone can't.
String sectorTransitionsSql() =>
    'SELECT ts, ${quoteIdent('value')} AS sector_code '
    'FROM ${quoteIdent(currentSectorEventTable)} ORDER BY ts';

/// Sector code as it appears in `Current Sector`, mapped to a 1-based sector
/// number.
int sectorNumberFromCode(int code) => code == 0 ? 3 : code;
