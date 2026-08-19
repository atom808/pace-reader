#!/usr/bin/env python3
"""Regenerate a trimmed test fixture from a real LMU telemetry file.

SPEC.md §12 calls for "small fixture `.duckdb` files (trimmed versions of the 3 real
samples, e.g. first N laps only)". `samples/` is git-ignored, so these fixtures are the
only telemetry CI ever sees — which makes the trim rule load-bearing rather than
incidental, and worth having as a checked-in script instead of prose.

The rule that matters: **preserve the master-grid identity from SPEC.md §5.1**, i.e.
`rows == ceil(n_gpstime * frequency / 100)` for every channel that satisfies it in the
source. Trimming each channel by `elapsed * its own frequency` instead — the original
hand-trim — over-keeps 4-5 rows on every sub-100 Hz channel, leaving 36 of 56 channels
inconsistent with the fixture's own `GPS Time` row count and manufacturing timing errors
up to +3.74 s that don't exist in the source. That is precisely the dimension the fixture
exists to test, so getting it wrong makes the fixture worse than useless.

The two channels that *legitimately* break the identity in the source (`Engine Oil Temp`
and `Engine Water Temp`, declared 7 Hz but sampling at ~7.0171 Hz — SPEC.md §5.2) are
trimmed proportionally instead, so the fixture reproduces the anomaly rather than hiding
it: the integration test asserts on both the 54 conforming channels and these 2.

Usage:
    python3 tool/make_fixture.py \\
        "samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \\
        test/fixtures/sebring_race_lap1.duckdb --through-lap 1
"""

import argparse
import math
import os
import sys

import duckdb

MASTER_CHANNEL = "GPS Time"  # the 100 Hz elapsed-seconds master clock (SPEC.md §5.2)
MASTER_HZ = 100


def build(source: str, dest: str, through_lap: int) -> None:
    if os.path.exists(dest):
        os.remove(dest)

    con = duckdb.connect(dest)
    con.execute("SET threads = 1")  # deterministic, insertion-order scans
    con.execute(f"ATTACH '{source}' AS src (READ_ONLY)")

    channels = con.execute(
        "SELECT channelName, frequency FROM src.channelsList ORDER BY channelName"
    ).fetchall()
    events = [r[0] for r in con.execute(
        "SELECT eventName FROM src.eventsList ORDER BY eventName"
    ).fetchall()]

    # Cut at the start of the lap *after* the last one we keep, so the kept span covers
    # whole laps. `Lap` values are 0-based (SPEC.md §5.2).
    cutoff = con.execute(
        'SELECT MIN(ts) FROM src."Lap" WHERE value = ?', [through_lap + 1]
    ).fetchone()[0]
    if cutoff is None:
        sys.exit(f"source has no lap {through_lap + 1} to cut at")

    src_master_rows = con.execute(f'SELECT COUNT(*) FROM src."{MASTER_CHANNEL}"').fetchone()[0]
    kept_master_rows = con.execute(
        f'SELECT COUNT(*) FROM src."{MASTER_CHANNEL}" WHERE value <= ?', [cutoff]
    ).fetchone()[0]

    print(f"source     : {os.path.basename(source)}")
    print(f"cutoff     : lap {through_lap + 1} starts at ts={cutoff}")
    print(f"master rows: {src_master_rows} -> {kept_master_rows}")

    for table in ("metadata", "channelsList", "eventsList"):
        con.execute(f'CREATE TABLE "{table}" AS SELECT * FROM src."{table}"')

    anomalous = []
    for name, hz in channels:
        src_rows = con.execute(f'SELECT COUNT(*) FROM src."{name}"').fetchone()[0]
        on_grid = src_rows == math.ceil(src_master_rows * hz / MASTER_HZ)
        if on_grid:
            keep = math.ceil(kept_master_rows * hz / MASTER_HZ)
        else:
            # Off-grid channel: preserve its real (mis-declared) rate proportionally.
            keep = round(src_rows * kept_master_rows / src_master_rows)
            anomalous.append((name, hz, src_rows, keep))
        con.execute(
            f'CREATE TABLE "{name}" AS '
            f'SELECT * EXCLUDE (_rn) FROM ('
            f'  SELECT *, row_number() OVER () AS _rn FROM src."{name}"'
            f') WHERE _rn <= {keep}'
        )

    for name in events:
        con.execute(
            f'CREATE TABLE "{name}" AS SELECT * FROM src."{name}" WHERE ts <= {cutoff!r}'
        )

    con.execute("DETACH src")
    con.execute("CHECKPOINT")
    con.close()

    print(f"off-grid channels preserved as-is: {[a[0] for a in anomalous] or 'none'}")
    print(f"wrote      : {dest} ({os.path.getsize(dest) / 1e6:.1f} MB)")
    verify(dest)


def verify(dest: str) -> None:
    """Re-open the fixture and assert the invariants the integration test relies on."""
    con = duckdb.connect(dest, read_only=True)
    master_rows = con.execute(f'SELECT COUNT(*) FROM "{MASTER_CHANNEL}"').fetchone()[0]
    origin = con.execute(f'SELECT value FROM "{MASTER_CHANNEL}" LIMIT 1').fetchone()[0]

    off_grid = []
    for name, hz in con.execute("SELECT channelName, frequency FROM channelsList").fetchall():
        rows = con.execute(f'SELECT COUNT(*) FROM "{name}"').fetchone()[0]
        if rows != math.ceil(master_rows * hz / MASTER_HZ):
            off_grid.append((name, hz, rows, math.ceil(master_rows * hz / MASTER_HZ)))

    empty_events = [
        n for n, in con.execute("SELECT eventName FROM eventsList").fetchall()
        if con.execute(f'SELECT COUNT(*) FROM "{n}"').fetchone()[0] == 0
    ]
    bad_origin = [
        n for n, in con.execute("SELECT eventName FROM eventsList").fetchall()
        if con.execute(f'SELECT MIN(ts) FROM "{n}"').fetchone()[0] != origin
    ]
    steps = con.execute(f'''
        WITH g AS (SELECT value AS v, row_number() OVER () AS i FROM "{MASTER_CHANNEL}"),
             d AS (SELECT v - lag(v) OVER (ORDER BY i) AS dt FROM g)
        SELECT COUNT(*) FROM d WHERE dt IS NOT NULL AND abs(dt - 0.01) > 1e-9
    ''').fetchone()[0]
    con.close()

    print("\nverification")
    print(f"  master rows              : {master_rows} (origin {origin})")
    print(f"  channels off master grid : {len(off_grid)} {[o[0] for o in off_grid]}")
    print(f"  empty event tables       : {len(empty_events)} {empty_events}")
    print(f"  events not starting at origin: {len(bad_origin)} {bad_origin}")
    print(f"  master-clock steps != 10ms   : {steps}")
    ok = len(off_grid) <= 2 and not empty_events and not bad_origin and steps == 0
    print("  RESULT: " + ("ok" if ok else "PROBLEM — do not check this fixture in"))
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("source")
    ap.add_argument("dest")
    ap.add_argument("--through-lap", type=int, default=1,
                    help="keep laps 0..N inclusive (default 1)")
    args = ap.parse_args()
    build(args.source, args.dest, args.through_lap)
