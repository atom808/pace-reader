# Fixtures

`sebring_race_lap1.duckdb` — lap 1 only, trimmed from the real Sebring Race sample
(`samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb`), per SPEC.md
§12's "small fixture `.duckdb` files... checked into the repo" testing strategy.

Regenerated with a short Python script (`duckdb` + `pip install duckdb`):

1. `ATTACH` the source file read-only.
2. Copy `metadata`, `channelsList`, `eventsList` unchanged.
3. For each channel table, keep the first `(lap2_start_ts - origin) * frequency` rows
   (channels have no timestamp column — see SPEC.md §5.2 — so trimming is row-count
   based, not a `WHERE` filter).
4. For each event table, keep rows where `ts <= lap2_start_ts`.

`lap2_start_ts` and `origin` both come from the `Lap` event table (`MIN(ts)` for the
recording start, `MIN(ts) WHERE value = 1` for the start of lap 2).

Note: the trimmed file is ~21 MB against a ~25 MB source (vs. the ~13% of rows actually
kept) — DuckDB's single-file format has meaningful per-table overhead once a file holds
~100 tables, so trimming rows doesn't shrink the file proportionally. Not itself a
concern for this fixture, but worth knowing before assuming row-count reductions predict
file-size reductions elsewhere (SPEC.md §5.5/§9.5's extrapolations are row-count based
for exactly this reason).
