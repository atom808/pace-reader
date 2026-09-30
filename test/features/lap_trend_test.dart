// The lap-time trend (SPEC.md §8.3), derived from the real laps of all three
// samples. Every expected number here was computed straight from the
// `.duckdb` files with `statistics` — not from this code, and not from the
// fixtures — so the tests check the derivation against an independent
// calculation rather than against itself.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_trend.dart';

import '../fixtures/lap_incidents.dart';
import '../fixtures/sebring_race_per_lap.dart';

/// The shared per-lap fixture holds laps 8-18 to within 0.55 ms of the file
/// (measured against the sample: worst 0.549 ms, at lap index 9), so figures
/// taken from the file are matched to a millisecond rather than to the bit.
const _fixtureMs = 1e-3;

void main() {
  group('Sebring Race — 16 timed laps of 20', () {
    final trend = LapTrend.derive(sebringRaceLaps());

    test('finds the fastest lap, and only one', () {
      // Lap 11 on the driver's count (index 10): 1:03.941.
      expect(trend.fastest?.index, 10);
      expect(
        trend.fastest?.lapTimeSeconds,
        closeTo(63.94091796875, _fixtureMs),
      );
      expect(trend.laps.where((t) => t.isFastest).map((t) => t.lap.index), [
        10,
      ]);
    });

    test('expresses every timed lap as its delta to the fastest', () {
      double delta(int index) =>
          trend.laps.firstWhere((t) => t.lap.index == index).deltaSeconds!;

      expect(
        delta(10),
        0,
        reason: 'the fastest lap sits exactly on the baseline',
      );
      expect(delta(1), closeTo(0.5565, _fixtureMs));
      expect(delta(3), closeTo(0.0887, _fixtureMs));
      expect(delta(15), closeTo(0.7598, _fixtureMs));
    });

    test('the median lap is the reference, not the mean', () {
      // Median 64.2076 s, +0.2667 s off the fastest. The mean is dragged by
      // the slowest laps and describes no lap that was driven.
      expect(
        trend.medianLapTimeSeconds,
        closeTo(64.20758056640625, _fixtureMs),
      );
      expect(trend.medianDeltaSeconds, closeTo(0.26666259765625, _fixtureMs));
    });

    test('reports consistency as the standard deviation of timed laps', () {
      expect(trend.stdDevSeconds, closeTo(0.2352423315147933, _fixtureMs));
      expect(trend.timedCount, 16);
    });

    test('knows the slowest lap and the spread the chart has to span', () {
      // 0.76 s from best to worst: the whole story is under 1.2 % of a lap
      // time, which is why the chart plots deltas and not lap times.
      expect(trend.slowest?.index, 15);
      expect(trend.spreadSeconds, closeTo(0.759765625, _fixtureMs));
    });

    test('keeps every lap in its slot, with a reason where it is left out', () {
      expect(trend.laps, hasLength(20));
      TrendLap lap(int index) => trend.laps[index];

      // The garage lap *has* a time (71.241 s), and is excluded anyway —
      // charted, it would be 7.3 s tall against 0.76 s for everything else.
      expect(lap(0).lap.lapTimeSeconds, isNotNull);
      expect(lap(0).exclusion, LapExclusion.outLap);
      expect(lap(0).deltaSeconds, isNull);

      // The two invalidated laps the game wrote 0.0 for.
      for (final index in [5, 13]) {
        expect(lap(index).exclusion, LapExclusion.noTime);
        expect(lap(index).deltaSeconds, isNull);
      }

      // The final lap the recording ended inside.
      expect(lap(19).exclusion, LapExclusion.incomplete);
      expect(lap(19).deltaSeconds, isNull);

      // A lap with a valid time and a missing sector is still compared.
      expect(lap(2).exclusion, isNull, reason: 'S2 missing, lap time valid');
      expect(lap(2).deltaSeconds, isNotNull);
    });
  });

  group('the other two samples', () {
    test('Practice: two timed laps, so a spread exists', () {
      final trend = LapTrend.derive(interlagosPracticeLaps());
      expect(trend.timedCount, 2);
      expect(trend.fastest?.index, 2);
      // The median of two is their mean: 98.2242 s, 0.9239 s off the fastest.
      expect(trend.medianLapTimeSeconds, closeTo(98.22418212890625, 1e-9));
      expect(trend.medianDeltaSeconds, closeTo(0.92388916015625, 1e-9));
      expect(trend.stdDevSeconds, closeTo(1.3065765804224572, 1e-9));
      expect(trend.spreadSeconds, closeTo(1.8477783203125, 1e-9));
    });

    test('Qualify: one timed lap, so consistency is undefined, not zero', () {
      final trend = LapTrend.derive(spaQualifyLaps());
      expect(trend.timedCount, 1);
      expect(trend.fastest?.index, 2);
      expect(trend.stdDevSeconds, isNull);
      // The invalidated lap 4 (index 3) keeps its slot and says why.
      expect(trend.laps[3].exclusion, LapExclusion.noTime);
    });
  });

  group('no timed lap at all', () {
    // Qualify's laps with the one timed lap made untimed: a session that never
    // set a time. Everything is absent — not zero.
    final laps = [
      for (final lap in spaQualifyLaps()) lap.copyWith(lapTimeSeconds: null),
    ];
    final trend = LapTrend.derive(laps);

    test('has no fastest lap and nothing to compare against', () {
      expect(trend.fastest, isNull);
      expect(trend.medianLapTimeSeconds, isNull);
      expect(trend.medianDeltaSeconds, isNull);
      expect(trend.stdDevSeconds, isNull);
      expect(trend.spreadSeconds, isNull);
      expect(trend.timedCount, 0);
    });

    test('still lists every lap, none with a delta', () {
      expect(trend.laps, hasLength(5));
      expect(trend.laps.every((t) => t.deltaSeconds == null), isTrue);
    });
  });

  group('ties', () {
    test('two laps at the fastest time: only the first is "the" fastest', () {
      Lap lap(int index, double time) => Lap(
        index: index,
        startSeconds: index * 100.0,
        endSeconds: index * 100.0 + 90,
        lapTimeSeconds: time,
        sectors: const SectorTimes(),
      );
      final trend = LapTrend.derive([
        lap(0, 70),
        lap(1, 64.5),
        lap(2, 64.5),
        lap(3, 65),
      ]);
      expect(trend.laps.where((t) => t.isFastest).map((t) => t.lap.index), [1]);
      // The other still sits at exactly zero: it is as fast, just not first.
      expect(trend.laps[2].deltaSeconds, 0);
    });
  });

  group('LapExclusion.of', () {
    test('agrees with Lap.isTimed on every real lap', () {
      // The exclusion and the timed flag are two views of one fact, and the
      // trend's slots are built from one while its statistics use the other.
      for (final laps in [
        sebringRaceLaps(),
        interlagosPracticeLaps(),
        spaQualifyLaps(),
      ]) {
        for (final lap in laps) {
          expect(LapExclusion.of(lap) == null, lap.isTimed, reason: '$lap');
        }
      }
    });
  });
}
