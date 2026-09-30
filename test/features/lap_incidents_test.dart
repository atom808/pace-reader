// Per-lap incidents (SPEC.md §8.3): impacts, a yellow-flag state, a detached
// wheel.
//
// What the recordings on hand can and cannot exercise is the first thing to
// know about this file. Across all three samples — 37.6 minutes — the only
// incident ever written is two impacts, both in the Race. `Yellow Flag State`
// and `WheelsDetached` are a single all-zero row each, in every sample. So:
//
// * the impact tests run on the **real** Race events and laps, and the real
//   Practice and Qualify events prove a quiet session stays quiet;
// * the yellow-flag and wheel tests run on **constructed** series, because no
//   real one exists — and say so, so that nobody reads them as measured.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';

import '../fixtures/lap_incidents.dart';
import '../fixtures/sebring_race_per_lap.dart';

/// A closed lap `[start, end)` — timing is irrelevant to incident derivation.
Lap _lap(int index, double start, double? end) => Lap(
  index: index,
  startSeconds: start,
  endSeconds: end,
  lapTimeSeconds: null,
  sectors: const SectorTimes(),
);

StepSeries _series(List<(double, Object?)> rows, {String name = 'event'}) =>
    StepSeries.fromRows(rows, eventName: name);

/// Four `WheelsDetached` columns from `(ts, fl, fr, rl, rr)` rows.
List<StepSeries> _wheels(List<(double, int, int, int, int)> rows) => [
  for (var corner = 0; corner < 4; corner++)
    _series([
      for (final r in rows) (r.$1, [r.$2, r.$3, r.$4, r.$5][corner]),
    ], name: 'WheelsDetached'),
];

void main() {
  group('the real Sebring Race', () {
    final laps = sebringRaceLaps();
    final events = sebringRaceIncidents();
    final incidents = SessionIncidents.derive(
      laps,
      impact: events.impact,
      yellowFlag: events.yellowFlag,
      wheelsDetached: events.wheelsDetached,
    );

    test('finds exactly the two impacts the file wrote, on laps 2 and 6', () {
      // Lap indices 1 and 5. `LastImpactMagnitude` holds rows at 213.8 s
      // (`true`) and 508.1 s (`false`); the laps start at 195.82 s and
      // 452.96 s.
      expect(incidents.byLap.keys.toList()..sort(), [1, 5]);
      expect(incidents.impactCount, 2);
      expect(incidents.lapsWithImpact, 2);
      expect(incidents.byLap[1]!.impactSeconds, [213.8]);
      expect(incidents.byLap[5]!.impactSeconds, [508.1]);
    });

    test('counts changes, never the state: laps 3-5 are not "impacted"', () {
      // The flag reads `true` from 213.8 s to 508.1 s — laps at indices 1
      // through 5. Reading the state would blame indices 2, 3 and 4 for a
      // shove on index 1, which is the bug this pins.
      for (final index in [2, 3, 4]) {
        expect(
          incidents.byLap.containsKey(index),
          isFalse,
          reason: 'lap $index',
        );
      }
    });

    test('a change *to false* is an impact too', () {
      // 508.1 s writes `false`, and is the harder shove of the two (Ground
      // Speed +7.9 km/h in 0.06 s against +3.5) — polarity carries nothing.
      expect(events.impact.valueAt(508.1), 0);
      expect(incidents.byLap[5]!.hasImpact, isTrue);
    });

    test('the first row is the state at the start, not an impact', () {
      // It sits at the session origin, exactly on lap 0's start.
      expect(events.impact.times.first, laps.first.startSeconds);
      expect(incidents.of(laps.first).hasImpact, isFalse);
    });

    test('no yellow flag and no detached wheel — the file has none', () {
      expect(incidents.lapsUnderYellow, 0);
      expect(incidents.lapsWithDetachedWheel, 0);
    });

    test('every other lap is quiet', () {
      for (final lap in laps.where((l) => l.index != 1 && l.index != 5)) {
        expect(incidents.of(lap).isEmpty, isTrue, reason: 'lap ${lap.index}');
      }
    });
  });

  group('the other two real sessions stay quiet', () {
    test('Practice', () {
      final events = interlagosPracticeIncidents();
      final incidents = SessionIncidents.derive(
        interlagosPracticeLaps(),
        impact: events.impact,
        yellowFlag: events.yellowFlag,
        wheelsDetached: events.wheelsDetached,
      );
      expect(incidents.isEmpty, isTrue);
    });

    test(
      'Qualify — including a lap where the car stops, which is not an impact',
      () {
        // Lap index 3 of the Spa sample is invalidated, and the car comes to a
        // standstill in it (Ground Speed 0.1 km/h at 495.7 s, rear-right wear
        // 95.4 -> 85.7 % within the lap) — yet none of the three events ever
        // leaves its first row. A spin without contact leaves no trace in them,
        // and the screen must not pretend otherwise.
        final events = spaQualifyIncidents();
        final incidents = SessionIncidents.derive(
          spaQualifyLaps(),
          impact: events.impact,
          yellowFlag: events.yellowFlag,
          wheelsDetached: events.wheelsDetached,
        );
        expect(events.impact.length, 1);
        expect(incidents.isEmpty, isTrue);
      },
    );
  });

  group('lap boundaries', () {
    // Laps [0,100), [100,200), and an open one from 200.
    final laps = [_lap(0, 0, 100), _lap(1, 100, 200), _lap(2, 200, null)];

    test('a change exactly at a boundary belongs to the lap that starts', () {
      final impact = _series([(0, false), (100, true)]);
      final incidents = SessionIncidents.derive(laps, impact: impact);
      expect(incidents.byLap.keys, [1]);
    });

    test('a change in the open final lap is counted', () {
      // The recording ended inside it; the impact still happened.
      final impact = _series([(0, false), (250, true)]);
      final incidents = SessionIncidents.derive(laps, impact: impact);
      expect(incidents.byLap.keys, [2]);
    });

    test('several changes in one lap are all counted, in order', () {
      final impact = _series([
        (0, false),
        (110, true),
        (140, false),
        (170, true),
      ]);
      final incidents = SessionIncidents.derive(laps, impact: impact);
      expect(incidents.byLap[1]!.impactSeconds, [110, 140, 170]);
      expect(incidents.byLap[1]!.impactCount, 3);
    });
  });

  group('yellow flag — constructed, no recording has ever raised one', () {
    final laps = [
      _lap(0, 0, 100),
      _lap(1, 100, 200),
      _lap(2, 200, 300),
      _lap(3, 300, null),
    ];

    test('a state raised and cleared inside a lap marks that lap only', () {
      final yellow = _series([(0, 0), (120, 1), (160, 0)]);
      final incidents = SessionIncidents.derive(laps, yellowFlag: yellow);
      expect(incidents.byLap.keys, [1]);
      expect(incidents.byLap[1]!.yellowFlagCodes, {1});
    });

    test('a state that spans a boundary marks both laps, and not a third', () {
      final yellow = _series([(0, 0), (150, 1), (250, 0)]);
      final incidents = SessionIncidents.derive(laps, yellowFlag: yellow);
      expect(incidents.byLap.keys.toList()..sort(), [1, 2]);
    });

    test('a state already in force when a lap begins still marks it', () {
      // Raised at 50, never cleared before 200: lap 1 has *no row of its own*
      // and is yellow throughout — the reason the read reaches back before a
      // window (`eventWindowSql`).
      final yellow = _series([(0, 0), (50, 1), (210, 0)]);
      final incidents = SessionIncidents.derive(laps, yellowFlag: yellow);
      expect(incidents.byLap.keys.toList()..sort(), [0, 1, 2]);
    });

    test('a state cleared exactly at a lap start does not mark that lap', () {
      final yellow = _series([(0, 0), (150, 1), (200, 0)]);
      final incidents = SessionIncidents.derive(laps, yellowFlag: yellow);
      expect(incidents.byLap.keys, [1]);
    });

    test('quotes every non-zero code seen, and interprets none', () {
      final yellow = _series([(0, 0), (110, 1), (130, 4), (150, 0)]);
      final incidents = SessionIncidents.derive(laps, yellowFlag: yellow);
      expect(incidents.byLap[1]!.yellowFlagCodes, {1, 4});
    });

    test('an all-zero series marks nothing — what every real file holds', () {
      final incidents = SessionIncidents.derive(
        laps,
        yellowFlag: _series([(0, 0)]),
      );
      expect(incidents.isEmpty, isTrue);
    });
  });

  group('wheels detached — constructed, no recording has ever lost one', () {
    final laps = [
      _lap(0, 0, 100),
      _lap(1, 100, 200),
      _lap(2, 200, 300),
      _lap(3, 300, null),
    ];

    test('value1..4 are FL, FR, RL, RR', () {
      // One corner per lap, each in a different column, so a wrong mapping
      // cannot pass by coincidence.
      final wheels = _wheels([
        (0, 0, 0, 0, 0),
        (110, 1, 0, 0, 0),
        (150, 0, 0, 0, 0),
        (210, 0, 1, 0, 0),
        (250, 0, 0, 0, 0),
        (310, 0, 0, 1, 0),
        (350, 0, 0, 0, 0),
      ]);
      final incidents = SessionIncidents.derive(laps, wheelsDetached: wheels);
      expect(incidents.byLap[1]!.detachedWheels, {WheelCorner.frontLeft});
      expect(incidents.byLap[2]!.detachedWheels, {WheelCorner.frontRight});
      expect(incidents.byLap[3]!.detachedWheels, {WheelCorner.rearLeft});
    });

    test(
      'a wheel that stays off keeps marking the laps after it, as carried',
      () {
        // Off at 250 and never restored: lap 2 is where it came off, laps 3 on
        // are still driven without it.
        final wheels = _wheels([(0, 0, 0, 0, 0), (250, 0, 0, 0, 1)]);
        final incidents = SessionIncidents.derive(laps, wheelsDetached: wheels);
        expect(incidents.byLap[2]!.detachedWheels, {WheelCorner.rearRight});
        expect(incidents.byLap[2]!.alreadyDetached, isEmpty);
        expect(incidents.byLap[3]!.detachedWheels, {WheelCorner.rearRight});
        expect(incidents.byLap[3]!.alreadyDetached, {WheelCorner.rearRight});
        expect(incidents.lapsWithDetachedWheel, 2);
      },
    );

    test('two corners at once are both named', () {
      final wheels = _wheels([(0, 0, 0, 0, 0), (110, 1, 0, 0, 1)]);
      final incidents = SessionIncidents.derive(laps, wheelsDetached: wheels);
      expect(incidents.byLap[1]!.detachedWheels, {
        WheelCorner.frontLeft,
        WheelCorner.rearRight,
      });
    });

    test('all-zero columns mark nothing — what every real file holds', () {
      final events = sebringRaceIncidents();
      final incidents = SessionIncidents.derive(
        sebringRaceLaps(),
        wheelsDetached: events.wheelsDetached,
      );
      expect(incidents.isEmpty, isTrue);
    });

    test(
      'a table that is not four columns is ignored rather than guessed at',
      () {
        final three = _wheels([(0, 1, 1, 1, 1)]).take(3).toList();
        final incidents = SessionIncidents.derive(laps, wheelsDetached: three);
        expect(incidents.isEmpty, isTrue);
      },
    );
  });

  group('the session summary', () {
    test('sums impacts across laps and counts laps per kind', () {
      final laps = [_lap(0, 0, 100), _lap(1, 100, 200), _lap(2, 200, 300)];
      final incidents = SessionIncidents.derive(
        laps,
        impact: _series([(0, false), (110, true), (120, false), (250, true)]),
        yellowFlag: _series([(0, 0), (260, 1)]),
      );
      expect(incidents.impactCount, 3);
      expect(incidents.lapsWithImpact, 2);
      expect(incidents.lapsUnderYellow, 1);
      expect(incidents.lapsWithDetachedWheel, 0);
    });

    test('says which tables the recording lacked', () {
      final incidents = SessionIncidents.derive(
        [_lap(0, 0, null)],
        unavailable: const [impactEventName],
      );
      expect(incidents.unavailable, [impactEventName]);
      expect(incidents.hasNoEvents, isFalse);

      final none = SessionIncidents.derive([
        _lap(0, 0, null),
      ], unavailable: SessionIncidents.eventNames);
      expect(none.hasNoEvents, isTrue);
    });
  });
}
