// The battery chips and the gap split (GO reference proposal P2, P3).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/channels.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/gap_split.dart';
import 'package:pace_reader/features/driver_comparison/domain/lap_conditions.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_findings.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_losses.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

StepSeries _steps(List<(double, double)> rows) => StepSeries(
  eventName: Events.fuelMixtureMap,
  unit: '',
  times: Float64List.fromList([for (final (t, _) in rows) t]),
  values: Float64List.fromList([for (final (_, v) in rows) v]),
);

TraceSeries _trace(String name, List<double> times, List<double> values) {
  final v = Float64List.fromList(values);
  return TraceSeries(
    channelName: name,
    unit: '',
    frequencyHz: 100,
    valueColumn: 'value',
    times: Float64List.fromList(times),
    lows: v,
    highs: v,
  );
}

List<String> _labels(List<ComparabilityChip> chips) => [
  for (final c in chips) c.label,
];

void main() {
  group('the deployment map over a lap', () {
    test("GO's 499P lap at Bahrain: 1–10, four switches of single steps", () {
      // Stepped one event at a time, as the file writes it (PACE-FACTORS
      // §5.5): 3 → 10 before the lap, then 10 → 1, 1 → 10, 10 → 3, 3 → 10.
      final rows = <(double, double)>[
        for (var v = 3; v <= 10; v++) (-6.0 + (v - 3) * 0.2, v.toDouble()),
        for (var v = 9; v >= 1; v--) (19.5 + (9 - v) * 0.2, v.toDouble()),
        for (var v = 2; v <= 10; v++) (57.5 + (v - 2) * 0.15, v.toDouble()),
        for (var v = 9; v >= 3; v--) (63.4 + (9 - v) * 0.12, v.toDouble()),
        for (var v = 4; v <= 10; v++) (84.5 + (v - 4) * 0.07, v.toDouble()),
      ];
      final use = mapUse(_steps(rows), 0, 104.9)!;
      expect(use.min, 1);
      expect(use.max, 10);
      expect(use.switches, 4);
    });

    test('a map held all lap is its value, with no switches', () {
      final use = mapUse(_steps([(-30, 5)]), 0, 95)!;
      expect((use.min, use.max, use.switches), (5.0, 5.0, 0));
      expect(mapUse(_steps([(200, 5)]), 0, 95), isNull);
    });
  });

  group('the battery chip', () {
    // GO's 499P lap and the user's at Bahrain (PACE-FACTORS §10.1).
    const go = LapConditions(
      battery: LapBattery(
        socStart: 77.5,
        socEnd: 38.4,
        deployed: 5.63,
        harvested: 3.52,
      ),
      map: MapUse(min: 1, max: 10, switches: 4),
    );
    const user = LapConditions(
      battery: LapBattery(
        socStart: 33.3,
        socEnd: 24.7,
        deployed: 3.98,
        harvested: 3.52,
      ),
      map: MapUse(min: 3, max: 6, switches: 2),
    );

    test('a qualifying lap against a level one: "≠ battery", every figure '
        'in its popover', () {
      final chips = conditionChips(base: user, target: go, sameCar: true);
      expect(_labels(chips), ['≠ battery 33 → 25 % / 78 → 38 %', 'conditions']);
      expect(chips.first.detail, [
        'State of charge over each lap: Base 33 → 25 % (9 points used), '
            'Target 78 → 38 % (39 points used).',
        'Deployed: Base 4.0 MJ, Target 5.6 MJ. Harvested: Base 3.5 MJ, '
            'Target 3.5 MJ.',
        'Deployment map: Base 3–6, 2 switches, Target 1–10, 4 switches.',
        startsWith('A qualifying lap can spend'),
      ]);
      expect(
        chips.last.detail,
        containsAll([
          startsWith('Battery over the lap'),
          'Deployed: 4.0 MJ / 5.6 MJ',
          'Harvested: 3.5 MJ / 3.5 MJ',
          'Deployment map over the lap: 3–6, 2 switches / 1–10, 4 switches',
        ]),
      );
    });

    test('within the library\'s lap-to-lap spread: in the popover only', () {
      // GO's Genesis at Daytona against the user's: 21.7 against 31.7 points.
      const a = LapConditions(
        battery: LapBattery(socStart: 68.6, socEnd: 46.9),
      );
      const b = LapConditions(
        battery: LapBattery(socStart: 65.7, socEnd: 34.0),
      );
      final chips = conditionChips(base: b, target: a, sameCar: true);
      expect(_labels(chips), ['conditions']);
      expect(
        chips.single.detail,
        contains(
          'Battery over the lap: 66 → 34 % / 69 → 47 % (a "≠" chip '
          'from 21 points spent)',
        ),
      );
    });

    test('a car without a hybrid says nothing about a battery', () {
      final chips = conditionChips(
        base: const LapConditions(fuel: 40),
        target: const LapConditions(fuel: 40),
        sameCar: true,
      );
      expect(chips.single.detail.where((l) => l.contains('Battery')), isEmpty);
    });

    test("a lap's charge and flow come from its own rows", () {
      final conditions = SessionConditions(
        soc: {
          3: const LapChannelStats(
            lapIndex: 3,
            first: 77.5,
            last: 38.4,
            min: 38.4,
            max: 77.5,
            mean: 55,
            samples: 2098,
          ),
        },
        regen: {
          3: const LapChannelFlow(
            lapIndex: 3,
            below: -5.63e6,
            above: 3.52e6,
            samples: 10490,
          ),
        },
      );
      const lap = Lap(
        index: 3,
        startSeconds: 100,
        endSeconds: 204.9,
        sectors: SectorTimes(),
      );
      final battery = conditions.of(lap).battery!;
      expect(battery.spent, closeTo(39.1, 1e-9));
      expect(battery.deployed, closeTo(5.63, 1e-9));
      expect(battery.harvested, closeTo(3.52, 1e-9));
      expect(
        conditions
            .of(const Lap(index: 4, startSeconds: 205, sectors: SectorTimes()))
            .battery,
        isNull,
      );
    });
  });

  group('the gap split', () {
    // A 1000 m lap. The Target runs 50 m/s throughout: deploying at full
    // throttle to 200 m, full throttle without to 400 m, braking to 500 m,
    // part throttle to 700 m, then full throttle to the line.
    const length = 1000.0;
    DistanceAxis axis(double Function(double s) secondsAt) {
      final times = <double>[];
      final stations = <double>[];
      for (var s = 0.0; s <= length; s += 0.5) {
        stations.add(s);
        times.add(secondsAt(s));
      }
      return DistanceAxis.fromSeries(_trace('Lap Dist', times, stations));
    }

    double targetAt(double s) => s / 50;
    // Base is the Target but for 40 m/s through the braking zone: 0.5 s.
    double baseAt(double s) => s <= 400
        ? s / 50
        : (s <= 500 ? 8 + (s - 400) / 40 : 10.5 + (s - 500) / 50);

    final targetAxis = axis(targetAt);
    final baseAxis = axis(baseAt);
    LapClock clock(DistanceAxis a, double end) =>
        LapClock(axis: a, startSeconds: 0, endSeconds: end, wrapLength: length);

    PlacedSeries pedal(String name, double Function(double s) value) {
      final times = <double>[];
      final values = <double>[];
      for (var s = 0.0; s <= length; s += 1) {
        times.add(targetAt(s));
        values.add(value(s));
      }
      return PlacedSeries.of(_trace(name, times, values), targetAxis);
    }

    final throttle = pedal(
      'Throttle',
      (s) => s < 400 || s >= 700 ? 100 : (s < 500 ? 0 : 50),
    );
    final brake = pedal('Brake', (s) => s >= 400 && s < 500 ? 80 : 0);
    final regen = pedal('Regen', (s) => s < 200 ? -120000 : 0);

    test('the loss lands in the phase it was lost in, and the phases sum to '
        'the lap', () {
      final split = GapSplit.measure(
        base: clock(baseAxis, 20.5),
        target: clock(targetAxis, 20),
        throttle: throttle,
        brake: brake,
        regen: regen,
      )!;
      expect(split.hybrid, isTrue);
      expect(split.phases, GapPhase.values);
      expect(split.seconds[GapPhase.braking], closeTo(0.5, 1e-6));
      for (final p in [
        GapPhase.deploying,
        GapPhase.fullThrottle,
        GapPhase.midCorner,
      ]) {
        expect(split.seconds[p], closeTo(0, 1e-6), reason: p.name);
      }
      expect(split.total, closeTo(0.5, 1e-6));
      // Runs of one phase join; full throttle is two stretches.
      expect(split.stretches[GapPhase.deploying], [(from: 0.0, to: 200.0)]);
      expect(split.stretches[GapPhase.braking], [(from: 400.0, to: 500.0)]);
      expect(split.stretches[GapPhase.fullThrottle], [
        (from: 200.0, to: 400.0),
        (from: 700.0, to: 1000.0),
      ]);
    });

    test('a Target that never deploys has one full-throttle row', () {
      final split = GapSplit.measure(
        base: clock(baseAxis, 20.5),
        target: clock(targetAxis, 20),
        throttle: throttle,
        brake: brake,
      )!;
      expect(split.hybrid, isFalse);
      expect(split.phases, [
        GapPhase.fullThrottle,
        GapPhase.braking,
        GapPhase.midCorner,
      ]);
      expect(GapPhase.fullThrottle.label(hybrid: false), 'Full throttle');
      expect(
        GapPhase.fullThrottle.label(hybrid: true),
        'Full throttle, no deployment',
      );
    });

    test('without the pedals there is no split', () {
      expect(
        GapSplit.measure(
          base: clock(baseAxis, 20.5),
          target: clock(targetAxis, 20),
          throttle: null,
          brake: brake,
        ),
        isNull,
      );
    });
  });
}
