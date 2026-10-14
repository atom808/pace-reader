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

## The second recording

`sebring_race_b_laps0_2.duckdb` — laps 0 through 2 plus the lap-3 boundary of another
Race session on the same course, `Sebring International Raceway_R_2026-07-07T05_57_04Z`,
trimmed by the same rule. Compare needs a genuinely different recording of one course
(comparison proposal §4, §10 step 3): copies of one file under two paths fire every gate,
but only a second session shows that two files' `Lap Dist`, sector lines and timing agree.
`integration_test/compare_test.dart` compares the two.

| Lap | What it exercises |
|---|---|
| 0 | the recording's first lap (69.346 s timed, never a Compare lap) |
| 1 | the session's best, 1:04.128, with `Last Sector2` written as `0.0`: it keeps its `Lap` event and is checked at 30 ms |
| 2 | 1:04.201 with all three splits: re-anchored, the pair's residuals within 5 ms of the game |
| 3 | open final lap |

Against the first fixture: lap length 3083.31 m in both, S1 lines 0.42 m apart, S2 lines
0.22 m apart.

At 7.6 MB it is a third of the first fixture's size, because it keeps the game's own
16 KB DuckDB block size (see "Regenerating").

## TC as a channel

`sebring_race_tc_channel_laps0_3.duckdb` is the first fixture in a newer game build's
layout (SPEC.md §5.1, 2026-10-13). In that layout `TC` is a 100 Hz `BOOLEAN` channel and
`SurfaceTypes` a 5 Hz channel, where every one of the user's recordings has them as events.
Each channel row holds the event's value as of its master row, the way the app reads an
event at a sample. Both names move from `eventsList` to `channelsList`, and every other
table is copied unchanged. `integration_test/technique_test.dart` runs Driving Technique on
both fixtures and checks that per-lap TC time and TC episodes agree.
`test/data/technique_queries_test.dart` checks which read each layout gets, without a
database.

It is the same data in the other shape, not a second recording. Pulses shorter than one
10 ms tick fall between two rows: 1,189 `TC` event rows become 911 changes on the grid. None
of the lost pulses stood alone as an episode, so the episode counts still match lap for
lap. Generated from the first fixture by `tool/make_tc_channel_fixture.dart`, which writes
the game's 16 KB block size (8.3 MB) and checks the result's shape before you can check it
in:

```bash
dart --packages=.dart_tool/package_config.json tool/make_tc_channel_fixture.dart \
  --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
  test/fixtures/sebring_race_laps0_3.duckdb \
  test/fixtures/sebring_race_tc_channel_laps0_3.duckdb
```

## Course facts as Dart

`sebring_course.dart` holds what the first fixture says about its course — the lap length
(the median over its `Lap Dist` wraps) and the S1 and S2 line stations — as
`CourseRepository` reads them. With it, the two Dart lap fixtures below re-anchor on the
game's splits in a plain `flutter test` exactly as they do in the app;
`integration_test/compare_test.dart` asserts the constants against the file.

## The Dart lap fixtures

`sebring_lap1.dart` and `sebring_lap3.dart` are laps 1 and 3 of the trimmed fixture as Dart
source, resampled to 5 Hz, for the tests that cannot open a `.duckdb` file at all — every
plain `flutter test`, since `dart_duckdb`'s native library only links into a compiled app.
Two of them because a comparison needs two laps: lap 3 is the faster clean lap and makes
the natural reference for lap 1. Each is generated with its own `--prefix`, so both can be
imported into one test without their declarations colliding.

They come from `tool/make_lap_fixture.dart`, the Dart port of `tool/make_lap_fixture.py`:
the same sampling and the same output for every channel the Python script emits, plus three
it does not — `Throttle Pos Unfiltered` (the pedal, in the `channels` map), and
`Path Lateral` and `Track Edge` (Compare's Line panel and centre-line check). The Python
script would regenerate the files without those three. Like `tool/make_fixture.dart`, it
runs on the DuckDB library a desktop build bundles:

```bash
dart --packages=.dart_tool/package_config.json tool/make_lap_fixture.dart \
  --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
  test/fixtures/sebring_race_laps0_3.duckdb test/fixtures/sebring_lap1.dart --lap 1
dart --packages=.dart_tool/package_config.json tool/make_lap_fixture.dart \
  --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
  test/fixtures/sebring_race_laps0_3.duckdb test/fixtures/sebring_lap3.dart --lap 3 \
  --prefix sebringLap3
```

## The tyre and brake fixtures

`sebring_race_tyres.dart` and `spa_qualify_tyres.dart` hold the eight per-corner tyre and
brake channels of the **full** Race and Hypercar Qualify recordings, aggregated per lap
(first, last, min, max, mean, samples; four decimals), plus the setup keys and recorded
brake settings the tyres & brakes view reads. `tyre_reports.dart` assembles them into the
`TireBrakeReport` the provider would build. Four laps of a wear trend show nothing, so these
come from the whole session rather than the trimmed `.duckdb`;
`integration_test/tires_brakes_test.dart` checks the Dart query against the trimmed fixture
lap for lap. Generated by `tool/make_tyre_fixture.py`:

```bash
python3 tool/make_tyre_fixture.py \
  "samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
  test/fixtures/sebring_race_tyres.dart --prefix sebringRace
```

## Regenerating

```bash
python3 tool/make_fixture.py \
  "samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
  test/fixtures/sebring_race_laps0_3.duckdb --through-lap 3
```

Needs `pip install duckdb`. Where Python is not installed (the Windows development
machine), `tool/make_fixture.dart` is the same trim with the same invariants. It runs on
the DuckDB library a desktop build bundles and on the package's existing resolution, so
nothing re-resolves `pubspec.lock`:

```bash
dart --packages=.dart_tool/package_config.json tool/make_fixture.dart \
  --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
  "<LMU Telemetry folder>/Sebring International Raceway_R_2026-07-07T05_57_04Z.duckdb" \
  test/fixtures/sebring_race_b_laps0_2.duckdb --through-lap 2
```

It attaches the source `READ_ONLY` (it is the user's game data), refuses one with a
`.wal` beside it (the game may still be writing it), and writes the result with the
source's own block size: DuckDB's default for a new file is 256 KB against the game's
16 KB, and with ~100 small tables that default alone made a three-lap trim 23 MB.

Either script copies `metadata`, `channelsList` and `eventsList`
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
