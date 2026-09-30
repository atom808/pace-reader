#!/usr/bin/env python3
"""Generate a Dart fixture holding the real `Time Behind Next` readings.

SPEC.md §8.9's race-pace view is fed by one 2 Hz channel, and everything the
app derives from it — the gap at either end, the laps it gained and lost, the
moments the car ahead changed — has to be tested against what the game actually
wrote, inside a plain `flutter test` where `dart_duckdb` is not linked and no
`.duckdb` file can be opened. So the readings arrive as Dart source, generated
here from the three real samples.

Checked in for the same reason `make_fixture.py` and `make_lap_fixture.py` are:
a fixture nobody can regenerate is an artifact described only in prose.

Emits, for the Sebring Race sample:

* every reading (2,682 of them) — the full-resolution series the app analyses;
* the same channel min/max-bucketed to 1,000 buckets, exactly as
  `decimateSql` returns it for the session window — the series the app draws;
* the per-lap aggregates `lapStatsSql` returns (first, last, min, max, mean,
  samples), reproduced here by the query's own rule: a lap opens at the first
  channel row whose master-clock time is at or after the `Lap` event.

and, for the Practice and Qualify samples, their full-resolution series only —
the evidence for why §8.9 is race-only, kept in the suite so a change to the
detector that would start calling a qualifying session's gaps "passes" is
caught by a test rather than by a reader.

Reads `samples/` (git-ignored), so it needs the real recordings:

    python3 tool/make_gap_fixture.py samples test/fixtures/gap_samples.dart

Needs `pip install duckdb`.
"""

from __future__ import annotations

import math
import struct
import sys
from pathlib import Path

try:
    import duckdb
except ImportError:  # pragma: no cover - a setup problem, not a logic one
    sys.exit("needs `pip install duckdb`")

CHANNEL = "Time Behind Next"
CHANNEL_HZ = 2
MASTER_HZ = 100
STRIDE = MASTER_HZ // CHANNEL_HZ
BUCKETS = 1000

FILES = {
    "race": "Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb",
    "qualify": "Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb",
    "practice": "Autódromo José Carlos Pace_P_2026-07-22T02_43_34Z.duckdb",
}


def column(con, table: str) -> list[float]:
    return [
        float(r[0])
        for r in con.execute(
            f'SELECT value FROM "{table}" ORDER BY (row_number() OVER ())'
        ).fetchall()
    ]


def readings(con):
    """`(origin, values)` — and proof that the channel sits on a 0.5 s grid."""
    master = column(con, "GPS Time")
    values = column(con, CHANNEL)
    expected = math.ceil(len(master) * CHANNEL_HZ / MASTER_HZ)
    if len(values) != expected:
        raise SystemExit(f"{CHANNEL}: {len(values)} rows, master grid says {expected}")
    origin = master[0]
    worst = max(abs(master[i * STRIDE] - (origin + i / CHANNEL_HZ)) for i in range(len(values)))
    # Practice and Qualify each hold one recording discontinuity (§5.2), after
    # the last lap boundary; the Race sample holds none, and it is the only one
    # whose times this fixture reconstructs as origin + i / 2.
    return master, origin, values, worst


def num(x: float) -> str:
    """The shortest decimal that reads back as the same FLOAT (32-bit) value.

    Rounding to a fixed number of decimals merges neighbouring readings, which
    matters here: the held stretches (SPEC.md §8.9) are *runs of identical
    readings*, and at four decimals the Race sample's opening run of 86 grows
    to 88 as two readings that differ in the sixth digit collapse into it.
    """
    packed = struct.pack("f", x)
    for precision in range(1, 10):
        text = f"{x:.{precision}g}"
        if struct.pack("f", float(text)) == packed:
            break
    else:
        text = repr(x)
    if "e" not in text and "." not in text:
        text += ".0"
    return "0.0" if text in ("-0.0", "0.0") else text


def mean(x: float) -> str:
    return repr(round(x, 6))


def dart_list(name: str, values: list[float], per_line: int = 10) -> str:
    lines = []
    for i in range(0, len(values), per_line):
        lines.append("  " + ", ".join(num(v) for v in values[i : i + per_line]) + ",")
    return f"const {name} = <double>[\n" + "\n".join(lines) + "\n];\n"


def dart_ints(name: str, values: list[int], per_line: int = 12) -> str:
    lines = []
    for i in range(0, len(values), per_line):
        lines.append("  " + ", ".join(str(v) for v in values[i : i + per_line]) + ",")
    return f"const {name} = <int>[\n" + "\n".join(lines) + "\n];\n"


def envelope(values: list[float]):
    """`decimateSql` over the whole channel: bucket = floor(i * B / n)."""
    n = len(values)
    firsts: dict[int, int] = {}
    lows: dict[int, float] = {}
    highs: dict[int, float] = {}
    for i, v in enumerate(values):
        b = math.floor(i * BUCKETS / n)
        firsts.setdefault(b, i)
        lows[b] = min(lows.get(b, v), v)
        highs[b] = max(highs.get(b, v), v)
    keys = sorted(firsts)
    return [firsts[b] for b in keys], [lows[b] for b in keys], [highs[b] for b in keys]


def lap_stats(con, master, values):
    """`lapStatsSql`, reproduced: first/last/min/max/mean/count per lap."""
    laps = con.execute('SELECT value, ts FROM "Lap" ORDER BY ts').fetchall()
    starts = []
    for index, ts in laps:
        m0 = next(mi for mi, t in enumerate(master) if t >= ts)
        starts.append((int(index), math.ceil(m0 / STRIDE)))
    out = []
    for k, (index, c0) in enumerate(starts):
        c1 = starts[k + 1][1] if k + 1 < len(starts) else len(values)
        chunk = values[c0:c1]
        if not chunk:
            continue
        out.append((index, chunk[0], chunk[-1], min(chunk), max(chunk), sum(chunk) / len(chunk), len(chunk)))
    return out


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    samples, out = Path(sys.argv[1]), Path(sys.argv[2])

    race = duckdb.connect(str(samples / FILES["race"]), read_only=True)
    master, origin, values, worst = readings(race)
    if worst > 1e-9:
        raise SystemExit(f"Race sample is not on a 0.5 s grid (worst {worst})")
    firsts, lows, highs = envelope(values)
    stats = lap_stats(race, master, values)

    parts = [
        f"""// Real `Time Behind Next` readings (SPEC.md §8.9), generated by
// `tool/make_gap_fixture.py` from the three samples in `samples/`.
//
// The Race sample is here in full — its 2,682 readings, the 1,000-bucket
// envelope `decimateSql` returns for the whole session, and the per-lap
// aggregates `lapStatsSql` returns — so a plain `flutter test` can run the
// derivations and the screen against numbers the game wrote. The Practice and
// Qualify series are here for one purpose: to pin *why* the view is race-only.
//
// Do not edit by hand; regenerate. Readings are the shortest decimal that
// round-trips the file's 32-bit FLOAT, so equality between readings is exact.
library;

import 'dart:typed_data';

import 'package:pace_reader/data/models/models.dart';

/// The Race sample's `GPS Time` at its first row — the recording's t=0 on the
/// file's own clock (SPEC.md §5.2).
const sebringRaceGapOrigin = {num(origin)};

/// The Race sample has no recording discontinuity, so reading `i` sits at
/// exactly `origin + i * 0.5` s — checked by the generator to 7e-15.
const gapReadingInterval = 0.5;

""",
        dart_list("_raceReadings", values),
        f"""
TraceSeries _series(List<double> readings, double origin) {{
  final times = Float64List(readings.length);
  for (var i = 0; i < readings.length; i++) {{
    times[i] = origin + i * gapReadingInterval;
  }}
  final values = Float64List.fromList(readings);
  return TraceSeries(
    channelName: 'Time Behind Next',
    unit: 's',
    frequencyHz: 2,
    valueColumn: 'value',
    times: times,
    lows: values,
    highs: values,
  );
}}

/// Every reading of the Race sample, as `readFullResolution` returns it.
TraceSeries sebringRaceGapSeries() =>
    _series(_raceReadings, sebringRaceGapOrigin);
""",
        "\n/// Row index of each envelope bucket's first reading.\n",
        dart_ints("_envelopeFirsts", firsts),
        dart_list("_envelopeLows", lows),
        dart_list("_envelopeHighs", highs),
        f"""
/// The Race sample min/max-bucketed to {BUCKETS} buckets over the whole session,
/// as `readTrace` returns it for the window the view asks for.
TraceSeries sebringRaceGapEnvelope() {{
  final times = Float64List(_envelopeFirsts.length);
  for (var i = 0; i < times.length; i++) {{
    times[i] = sebringRaceGapOrigin + _envelopeFirsts[i] * gapReadingInterval;
  }}
  return TraceSeries(
    channelName: 'Time Behind Next',
    unit: 's',
    frequencyHz: 2,
    valueColumn: 'value',
    times: times,
    lows: Float64List.fromList(_envelopeLows),
    highs: Float64List.fromList(_envelopeHighs),
  );
}}

/// `readLapStats('Time Behind Next')` on the Race sample, lap by lap.
List<LapChannelStats> sebringRaceGapStats() => const [
""",
    ]
    for index, first, last, lo, hi, avg, count in stats:
        parts.append(
            f"      LapChannelStats(lapIndex: {index}, first: {num(first)}, last: {num(last)}, "
            f"min: {num(lo)}, max: {num(hi)}, mean: {mean(avg)}, samples: {count}),\n"
        )
    parts.append("    ];\n")

    for key, name in (("practice", "practice"), ("qualify", "qualify")):
        con = duckdb.connect(str(samples / FILES[key]), read_only=True)
        m, o, v, _ = readings(con)
        # Times of a recording with a discontinuity are read off `GPS Time`,
        # not rebuilt from the grid: emit them.
        times = [m[i * STRIDE] for i in range(len(v))]
        parts.append(f"\n/// The {key.capitalize()} sample's `GPS Time` at its first row.\n")
        parts.append(f"const {name}GapOrigin = {num(o)};\n")
        parts.append(dart_list(f"_{name}Readings", v))
        parts.append(dart_list(f"_{name}Times", times, 8))
        parts.append(
            f"""
/// Every reading of the {key.capitalize()} sample.
TraceSeries {name}GapSeries() => TraceSeries(
      channelName: 'Time Behind Next',
      unit: 's',
      frequencyHz: 2,
      valueColumn: 'value',
      times: Float64List.fromList(_{name}Times),
      lows: Float64List.fromList(_{name}Readings),
      highs: Float64List.fromList(_{name}Readings),
    );
"""
        )

    out.write_text("".join(parts))
    print(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
