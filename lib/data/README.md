# `data/` — shared telemetry data access (SPEC.md §9.1, §9.2)

Built in Phase 1. Repositories are **shared, not per-feature** (§9.1) because most features
query the same session/lap/telemetry tables, and duplicating query logic per feature would
drift.

## Layout

- `duckdb/` — connection lifecycle and SQL.
  - `telemetry_database.dart` — the one place that knows about platforms. Both desktop and
    web `ATTACH` the file `READ_ONLY` into an in-memory database, differing only in whether
    they attach a path or a registered byte buffer, so every query downstream is
    byte-identical across targets. Also defines `TelemetryQueryExecutor`, the narrow seam
    repositories depend on.
  - `sql.dart` — identifier/literal quoting. Channel names contain spaces and come from a
    file the app doesn't control, so quoting escapes rather than trusts.
  - `time_axis.dart` — the §5.2 derivation. Integer stride where the master-grid identity
    holds, row-count ratio for the two channels where it doesn't.
  - `channel_queries.dart` — min/max decimation, degenerate-channel detection, `ASOF LEFT
    JOIN` event alignment.
  - `lap_queries.dart` / `session_queries.dart` — lap boundaries and sector splits;
    metadata, catalog discovery, clock-gap scan.
- `models/` — `freezed` models plus the pure derivations over them (`SectorTimes`,
  `LapPaceStatistics`), which live here rather than in the repositories so a plain
  `flutter test` can reach them without importing the DuckDB layer.
- `repositories/` — `SessionRepository`, `LapRepository`, `TelemetryRepository`.

## Why the SQL builders are pure functions

`dart_duckdb`'s native library links into a compiled app, not into the `flutter test`
process, so anything holding a real connection runs only under `integration_test` — on CI,
that means "not without a device". Keeping SQL construction and every derivation pure puts
the highest-risk logic in the test surface CI can always run (`test/data/`, 77 cases), and
leaves `integration_test/data_layer_test.dart` (24 cases) to check that the SQL actually
executes and agrees with the file's own ground truth.

## Two spec corrections came out of building this

Both were stated as confirmed fact in SPEC v0.6 and refuted by real data — see §8.3.1 and
§5.2:

- **Sector splits are cumulative.** `s3 = lap - s1 - s2` double-subtracts S1 and yields
  *negative* sector-3 times. Correct: `s2 = s2cum - s1`, `s3 = lap - s2cum`.
- **The master-row mapping is an integer stride**, not `round(i * n_gpstime / rows)`, which
  compresses the axis by up to 0.5 s on a 1 Hz channel.

`integration_test/duckdb_spike_test.dart` still pins the §5 invariants this layer honours.
