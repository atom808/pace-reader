# Fixtures

`sebring_race_lap1.duckdb` — lap 0 plus the lap-1 boundary, trimmed from the real Sebring
Race sample (`samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb`), per
SPEC.md §12's "small fixture `.duckdb` files... checked into the repo" testing strategy.

`samples/` is git-ignored, so **this fixture is the only telemetry CI ever sees**. Whatever
a fixture gets wrong, CI cannot catch — which makes the trim rule part of the test surface,
not a packaging detail.

## Regenerating

```bash
python3 tool/make_fixture.py \
  "samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
  test/fixtures/sebring_race_lap1.duckdb --through-lap 0
```

Needs `pip install duckdb`. The script copies `metadata`, `channelsList` and `eventsList`
unchanged, trims each channel table against the **master grid**, trims each event table by
`ts <= cutoff`, then re-opens the result and asserts the invariants before you can check it
in.

## Why the trim rule matters

Channels have no timestamp column (SPEC.md §5.2), so trimming is row-count based rather
than a `WHERE` filter — and the row count is exactly what carries the timing information.
Every channel is a decimation of one shared 100 Hz master grid (§5.1):

```
rows == ceil(rows_of_GPS_Time * frequency / 100)
```

The original hand-trim cut each channel by `elapsed * its own frequency` instead. That
over-kept 4–5 rows on every sub-100 Hz channel and left **36 of 56 channels inconsistent
with the fixture's own `GPS Time` row count**, manufacturing timing errors up to +3.74 s
that do not exist in the source file — in the exact dimension the fixture exists to
validate. `tool/make_fixture.py` trims against the master grid so the fixture stays
faithful.

Two channels — `Engine Oil Temp` and `Engine Water Temp` — legitimately break that identity
in the source: they declare 7 Hz but sample at ~7.0171 Hz (§5.2). The script trims those
proportionally so the fixture **reproduces the anomaly rather than hiding it**;
`integration_test/duckdb_spike_test.dart` asserts on both groups, so a third off-grid
channel appearing in a future LMU version fails the suite instead of slipping through.

## Size

The trimmed file is ~21 MB against a ~25 MB source (vs. the ~13% of rows actually kept) —
DuckDB's single-file format has meaningful per-table overhead once a file holds ~100 tables,
so trimming rows doesn't shrink the file proportionally. Not itself a concern for this
fixture, but worth knowing before assuming row-count reductions predict file-size
reductions elsewhere (SPEC.md §5.5/§9.5's extrapolations are row-count based for exactly
this reason).
