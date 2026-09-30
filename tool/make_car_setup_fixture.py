#!/usr/bin/env python3
"""Generate a Dart fixture holding the real `CarSetup` JSON of the samples, plus
the telemetry facts the setup is checked against.

The Setup Viewer (SPEC.md §8.10) is a parse-and-group over one JSON blob, and
its unit tests are only worth having if they run on the real blobs: the spec's
history is a record of plausible-looking readings of real fields being wrong.
They also have to run inside a plain `flutter test`, where `dart_duckdb`'s
native library is not linked and no `.duckdb` file can be opened — so the JSON
arrives as Dart source.

Alongside each blob go the numbers from the *same file's telemetry* that the
setup's strings were checked against (brake bias, TC/ABS level, the first
virtual-energy and fuel samples, brake-disc thickness, peak rpm, and the median
speed per 1000 rpm the car ran in each gear). They are what makes the tests
independent-ground-truth checks rather than the parser agreeing with itself,
and having the query here is what lets a reader see where each figure came from.

`samples/` is git-ignored, so the output is what CI sees: regenerate with

    python3 tool/make_car_setup_fixture.py \
        interlagos="samples/Autódromo José Carlos Pace_P_2026-07-22T02_43_34Z.duckdb" \
        spa="samples/Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb" \
        sebring="samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
        > test/fixtures/car_setup_samples.dart

Needs `pip install duckdb`. The JSON is re-emitted one top-level entry per line
(the game writes it on one 38 kB line) with every value untouched, so the file
diffs and reads; parsing the emitted text yields exactly the parsed original.
"""

from __future__ import annotations

import bisect
import json
import statistics
import sys

try:
    import duckdb
except ImportError:  # pragma: no cover - a setup problem, not a logic one
    sys.exit("needs `pip install duckdb`")

MIN_GEAR_ROWS = 200
MIN_SPEED_KPH = 30
MIN_RPM = 3000


def first(con, table: str, column: str = "value"):
    row = con.execute(f'select {column} from "{table}" limit 1').fetchone()
    return None if row is None else row[0]


def first_event(con, table: str):
    row = con.execute(f'select value from "{table}" order by ts limit 1').fetchone()
    return None if row is None else row[0]


def kph_per_krpm_by_gear(con) -> dict[int, float]:
    """Median `Ground Speed / (Engine RPM / 1000)` while in each gear.

    Rows are aligned by index: `Engine RPM`, `Ground Speed` and `GPS Time` are
    all 100 Hz decimations of the one master grid (§5.1, §5.2), and a gear
    applies from its event's `ts` until the next.
    """
    rpm = [r[0] for r in con.execute('select value from "Engine RPM"').fetchall()]
    speed = [r[0] for r in con.execute('select value from "Ground Speed"').fetchall()]
    clock = [r[0] for r in con.execute('select value from "GPS Time"').fetchall()]
    gears = con.execute('select ts, value from "Gear" order by ts').fetchall()
    ts = [g[0] for g in gears]
    values = [g[1] for g in gears]
    per_gear: dict[int, list[float]] = {}
    for i in range(min(len(rpm), len(speed), len(clock))):
        j = bisect.bisect_right(ts, clock[i]) - 1
        if j < 0:
            continue
        if speed[i] > MIN_SPEED_KPH and rpm[i] > MIN_RPM:
            per_gear.setdefault(values[j], []).append(speed[i] / (rpm[i] / 1000.0))
    return {
        g: statistics.median(xs)
        for g, xs in sorted(per_gear.items())
        if g >= 1 and len(xs) >= MIN_GEAR_ROWS
    }


def dart_string(text: str) -> str:
    if "'''" in text:
        sys.exit("CarSetup JSON contains ''' — pick another delimiter")
    return "r'''\n" + text + "\n'''"


def one_entry_per_line(setup: dict) -> str:
    lines = [
        f"{json.dumps(k, ensure_ascii=False)}:{json.dumps(v, ensure_ascii=False, separators=(',', ':'))}"
        for k, v in setup.items()
    ]
    return "{\n" + ",\n".join(lines) + "\n}"


def emit(name: str, path: str) -> str:
    con = duckdb.connect(path, read_only=True)
    metadata = dict(con.execute("select key, value from metadata").fetchall())
    setup = json.loads(metadata["CarSetup"], object_pairs_hook=dict)
    text = one_entry_per_line(setup)
    assert json.loads(text) == setup, "re-emitted JSON changed the data"

    thickness = con.execute('select value1, value2, value3, value4 from "Brake Thickness" limit 1').fetchone()
    peak_rpm = con.execute('select max(value) from "Engine RPM"').fetchone()[0]
    gear_speed = kph_per_krpm_by_gear(con)
    gear_map = ", ".join(f"{g}: {v!r}" for g, v in gear_speed.items())
    return f"""
/// {metadata.get('TrackName')} ({metadata.get('SessionType')}, {metadata.get('CarClass')}).
const {name}CarSetup = CarSetupSample(
  json: {dart_string(text)},
  brakeBiasRear: {first_event(con, 'Brake Bias Rear')!r},
  tcLevel: {first_event(con, 'TCLevel')!r},
  absLevel: {first_event(con, 'ABSLevel')!r},
  firstVirtualEnergy: {first(con, 'Virtual Energy')!r},
  firstFuelLevel: {first(con, 'Fuel Level')!r},
  brakeThicknessFirst: {list(thickness)!r},
  peakEngineRpm: {peak_rpm!r},
  kphPerKrpmByGear: {{{gear_map}}},
);
"""


def main(argv: list[str]) -> None:
    if not argv:
        sys.exit(__doc__)
    print(
        """// The real `CarSetup` JSON of the three samples, and the telemetry facts
// each is checked against (SPEC.md §5.1, §8.10).
//
// GENERATED by `tool/make_car_setup_fixture.py` from `samples/` (git-ignored) —
// see that script for how each figure is derived. Do not edit by hand.
library;

/// One sample's setup blob and what its own telemetry says about it.
class CarSetupSample {
  const CarSetupSample({
    required this.json,
    required this.brakeBiasRear,
    required this.tcLevel,
    required this.absLevel,
    required this.firstVirtualEnergy,
    required this.firstFuelLevel,
    required this.brakeThicknessFirst,
    required this.peakEngineRpm,
    required this.kphPerKrpmByGear,
  });

  /// `metadata.CarSetup`, one top-level entry per line, values untouched.
  final String json;

  /// First `Brake Bias Rear` event: the rear share of the braking, 0..1.
  final double brakeBiasRear;

  /// First `TCLevel` and `ABSLevel` events.
  final int tcLevel;
  final int absLevel;

  /// First samples of `Virtual Energy` (%) and `Fuel Level` (L).
  final double firstVirtualEnergy;
  final double firstFuelLevel;

  /// First `Brake Thickness` row, FL FR RL RR (labelled `%`, reads cm).
  final List<double> brakeThicknessFirst;

  /// Peak `Engine RPM` over the whole session.
  final double peakEngineRpm;

  /// Median `Ground Speed / (Engine RPM / 1000)` in each gear the car used
  /// for at least 200 samples at speed, keyed by gear.
  final Map<int, double> kphPerKrpmByGear;
}
"""
    )
    for arg in argv:
        name, _, path = arg.partition("=")
        print(emit(name, path))


if __name__ == "__main__":
    main(sys.argv[1:])
