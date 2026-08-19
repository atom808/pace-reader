# Fixtures

`sebring_race_laps0_3.duckdb` — laps 0 through 3 plus the lap-4 boundary, trimmed from the
real Sebring Race sample (`samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb`), per
SPEC.md §12's "small fixture `.duckdb` files... checked into the repo" testing strategy.

`samples/` is git-ignored, so **this fixture is the only telemetry CI ever sees**. Whatever
a fixture gets wrong, CI cannot catch — which makes the trim rule part of the test surface,
not a packaging detail.

## Why four laps and not one

The fixture originally stopped at lap 0. That kept it small, but lap 0 is the *garage* lap
(SPEC.md §5.2) — the one lap whose time isn't a real lap time — so a one-lap fixture
contains **no flying lap at all**, and CI could not check any per-lap derivation on the
case that actually occurs. That gap hid a real bug: the sector splits in `Last Sector2` are
*cumulative*, not durations, and the formula in SPEC v0.6 §8.3 (`s3 = lap - s1 - s2`)
produced negative sector-3 times. Nothing in a lap-0-only fixture could have caught it.

Through lap 3 the fixture covers every case the lap layer handles, at a cost of ~3 MB:

| Lap | What it exercises |
|---|---|
| 0 | garage lap — timed by the game (71.241 s) but a 172.2 s wall-clock span |
| 1 | clean flying lap — validates the corrected cumulative-sector derivation |
| 2 | valid lap time with `Last Sector2` written as `0.0` — the partial-row case |
| 3 | second clean flying lap — gives best-lap/consistency something to compare |
| 4 | open final lap — no closing boundary, so it cannot be timed |

## Regenerating

```bash
python3 tool/make_fixture.py \
  "samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
  test/fixtures/sebring_race_laps0_3.duckdb --through-lap 3
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
