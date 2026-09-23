// Fuel and energy per lap (SPEC.md §8.7): the derivations, against the real
// Sebring Race numbers wherever the recording has them.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';

import '../fixtures/sebring_race_per_lap.dart';

StepSeries _inPits(List<(double, int)> rows) => StepSeries(
      eventName: inPitsEventName,
      unit: '',
      times: Float64List.fromList([for (final r in rows) r.$1]),
      values: Float64List.fromList([for (final r in rows) r.$2.toDouble()]),
    );

ResourceUsage _fuel({
  List<LapChannelStats>? stats,
  List<PitVisit> pitVisits = const [],
}) =>
    ResourceUsage.derive(
      name: 'Fuel',
      unit: 'L',
      laps: sebringRaceLaps(),
      stats: stats ?? sebringRaceFuelStats(),
      pitVisits: pitVisits,
    );

void main() {
  group('pitVisitsFrom', () {
    test('a session that never went in has no visits', () {
      // The Race sample: `In Pits` holds a single 0 row for the whole race.
      expect(pitVisitsFrom(_inPits([(23.5975, 0)])), isEmpty);
    });

    test('a recording that starts in the pit lane says so', () {
      // The Practice sample: in the pits at the first sample, out 21.39 s
      // later — the out lap leaving the garage.
      final visits = pitVisitsFrom(_inPits([(381.0875, 1), (402.48, 0)]));
      expect(visits, hasLength(1));
      expect(visits.single.fromRecordingStart, isTrue);
      expect(visits.single.durationSeconds, closeTo(402.48 - 381.0875, 1e-9));
    });

    test('a stop mid-session is an entry and an exit', () {
      final visits =
          pitVisitsFrom(_inPits([(10, 0), (100, 1), (130.5, 0), (200, 0)]));
      expect(visits, hasLength(1));
      expect(visits.single.fromRecordingStart, isFalse);
      expect(visits.single.enteredSeconds, 100);
      expect(visits.single.exitedSeconds, 130.5);
    });

    test('a recording that ends in the pit lane leaves the visit open', () {
      final visits = pitVisitsFrom(_inPits([(10, 0), (100, 1)]));
      expect(visits.single.exitedSeconds, isNull);
      expect(visits.single.durationSeconds, isNull);
    });
  });

  group('ResourceUsage.derive on the real race', () {
    final fuel = _fuel();

    test('a lap uses what it starts with minus what the next starts with', () {
      final lap2 = fuel.laps[1];
      expect(lap2.used, closeTo(38.5866 - 36.7852, 1e-9));
      expect(lap2.levelAtStart, 38.5866);
    });

    test('averages the 18 racing laps, invalidated ones included', () {
      // Lap 1 is the garage lap and lap 20 is cut off by the recording; the
      // two invalidated laps still burnt fuel driving them, so they count.
      expect(fuel.representative, hasLength(18));
      expect(fuel.laps[5].lap.lapTimeSeconds, isNull, reason: 'invalidated');
      expect(fuel.laps[5].representative, isTrue);
      // Consecutive differences telescope: the average is simply lap 2's
      // starting level minus lap 20's, over the 18 laps between.
      expect(fuel.averagePerLap, closeTo((38.5866 - 6.3194) / 18, 1e-9));
    });

    test('says why each lap left out is left out', () {
      expect(fuel.laps.first.exclusion, UsageExclusion.outLap);
      expect(fuel.laps.last.exclusion, UsageExclusion.incomplete);
    });

    test('estimates the laps the remaining fuel lasts', () {
      expect(fuel.remaining, 6.1324);
      const average = (38.5866 - 6.3194) / 18;
      expect(fuel.lapsRemaining, closeTo(6.1324 / average, 1e-9));
      expect(fuel.lapsRemaining, closeTo(3.42, 0.01));
    });

    test('virtual energy runs out before fuel does', () {
      // 5.59% at 2.14% a lap is 2.6 laps; 6.13 L at 1.79 L a lap is 3.4. On
      // this car and track the energy allocation, not the tank, ends a stint.
      final report = FuelEnergyReport(
        carClass: 'GT3',
        fuel: fuel,
        energy: ResourceUsage.derive(
          name: 'Virtual energy',
          unit: '%',
          laps: sebringRaceLaps(),
          stats: sebringRaceEnergyStats(),
        ),
        stateOfCharge: null,
        pitVisits: const [],
      );
      expect(report.limiting!.name, 'Virtual energy');
      expect(report.limiting!.lapsRemaining, closeTo(2.61, 0.01));
    });
  });

  group('ResourceUsage.derive exclusions', () {
    test('a lap with time in the pit lane is left out', () {
      final lap8 = sebringRaceLaps()[7];
      final fuel = _fuel(pitVisits: [
        PitVisit(
          enteredSeconds: lap8.startSeconds + 30,
          exitedSeconds: lap8.startSeconds + 50,
        ),
      ]);
      expect(fuel.laps[7].exclusion, UsageExclusion.pitLane);
      expect(fuel.representative, hasLength(17));
    });

    test('a rising level is a refill, not negative consumption', () {
      // 40 L added during lap 8 (index 7): every level from lap 9 on sits
      // 40 L higher, as it would after a real stop.
      final stats = [
        for (final s in sebringRaceFuelStats())
          s.lapIndex < 8
              ? s
              : LapChannelStats(
                  lapIndex: s.lapIndex,
                  first: s.first + 40,
                  last: s.last + 40,
                  min: s.min + 40,
                  max: s.max + 40,
                  mean: s.mean + 40,
                  samples: s.samples,
                ),
      ];
      final fuel = _fuel(stats: stats);
      expect(fuel.laps[7].exclusion, UsageExclusion.refilled);
      expect(fuel.laps[7].used, closeTo(27.8097 - (25.9916 + 40), 1e-9));
      // The laps either side of the stop are untouched by it: the average is
      // the 17 racing laps that did not refill, at their real figures.
      final untouched = _fuel().representative.where((l) => l.lap.index != 7);
      expect(
        fuel.averagePerLap,
        closeTo(
          untouched.fold<double>(0, (sum, l) => sum + l.used!) / 17,
          1e-9,
        ),
      );
    });

    test('a lap with no samples has no figure rather than a zero', () {
      final stats = sebringRaceFuelStats()..removeAt(4);
      final fuel = _fuel(stats: stats);
      expect(fuel.laps[4].used, isNull);
      expect(fuel.laps[4].exclusion, UsageExclusion.noData);
    });

    test('with no racing lap there is no average and no estimate', () {
      final fuel = ResourceUsage.derive(
        name: 'Fuel',
        unit: 'L',
        laps: sebringRaceLaps().take(1).toList(),
        stats: sebringRaceFuelStats().take(1).toList(),
      );
      expect(fuel.averagePerLap, isNull);
      expect(fuel.lapsRemaining, isNull);
    });
  });
}
