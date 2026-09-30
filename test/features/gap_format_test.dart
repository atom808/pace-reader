// The numerals and the chart's pure helpers for race pace (SPEC.md §8.9).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/race_pace/application/race_pace.dart';
import 'package:pace_reader/features/race_pace/presentation/gap_format.dart';
import 'package:pace_reader/features/race_pace/presentation/gap_session_chart.dart';

import '../fixtures/gap_samples.dart';
import '../fixtures/sebring_race_per_lap.dart';

GapSession _race() => GapSession.derive(
      readings: sebringRaceGapSeries(),
      envelope: sebringRaceGapEnvelope(),
      laps: sebringRaceLaps(),
      stats: sebringRaceGapStats(),
      originSeconds: sebringRaceGapOrigin,
      endSeconds: 1364.18,
    );

void main() {
  group('formatGap', () {
    test('is always signed, so a column of them lines up', () {
      expect(formatGap(-6.9584), '-6.96 s');
      expect(formatGap(0.42), '+0.42 s');
      expect(formatGap(0), '+0.000 s');
    });

    test('takes a third decimal below a tenth of a second', () {
      // The closest approach in the Race sample is 1 ms from level; two
      // decimals would print it as +0.00.
      expect(formatGap(0.00086688995), '+0.001 s');
      expect(formatGap(-0.0229), '-0.023 s');
      expect(formatGap(-0.0999), '-0.100 s');
      expect(formatGap(0.1132), '+0.11 s');
    });

    test('a value that rounds to nothing takes the sign of nothing', () {
      expect(formatGap(-0.0004), '+0.000 s');
      expect(formatGap(0.0004), '+0.000 s');
    });

    test('drops the unit for a table cell, and says nothing for nothing', () {
      expect(formatGap(-3.47, unit: false), '-3.47');
      expect(formatGap(null), '—');
      expect(formatGap(double.nan), '—');
      expect(formatGap(double.infinity), '—');
    });
  });

  group('formatGapTick', () {
    test('uses as many decimals as the step needs', () {
      expect(formatGapTick(-6, 2), '-6');
      expect(formatGapTick(-0.5, 0.5), '-0.5');
      expect(formatGapTick(0.25, 0.05), '0.25');
    });

    test('a step of 2.5 keeps its decimal', () {
      // `ValueRange.ticks` steps in 1/2/2.5/5 x 10^n. The Race axis runs 0 to
      // -8.4 on a 2.5 step; labelled to a whole number its gridlines read
      // -3, -5, -8 when they sit at -2.5, -5, -7.5.
      expect(formatGapTick(-2.5, 2.5), '-2.5');
      expect(formatGapTick(-7.5, 2.5), '-7.5');
      expect(formatGapTick(-5, 2.5), '-5.0');
      expect(formatGapTick(-0.25, 0.25), '-0.25');
      expect(formatGapTick(-25, 25), '-25');
    });

    test('never prints a negative zero', () {
      expect(formatGapTick(-1e-17, 2), '0');
      expect(formatGapTick(-1e-17, 0.5), '0.0');
    });
  });

  group('the session clock', () {
    test('reads minutes and tenths from the recording\'s start', () {
      const origin = 23.5975;
      expect(formatSessionClock(origin, origin: origin), '0:00.0');
      expect(formatSessionClock(origin + 122.5, origin: origin), '2:02.5');
      expect(formatSessionClock(origin + 165.0, origin: origin), '2:45.0');
      expect(formatSessionClock(origin + 3600, origin: origin), '60:00.0');
    });

    test('a held stretch is named to a tenth', () {
      expect(formatHeldDuration(42.5), '42.5\u00A0s');
      expect(formatHeldDuration(10.5), '10.5\u00A0s');
    });
  });

  group('clockTicks', () {
    test('step in round minutes, not round decimal seconds', () {
      // 1,340 s is 22:20: a step of 240 s gives 0:00, 4:00, ... rather than a
      // tick at 250 s, which is 4:10.
      final ticks = clockTicks(1340);
      expect(ticks.first, 0);
      expect(ticks.length - 1, lessThanOrEqualTo(6));
      expect(ticks[1], anyOf(240, 300));
      for (final t in ticks) {
        expect(t % 60, 0, reason: '$t s is not a whole minute');
      }
    });

    test('a short span still gets ticks, and an empty one gets the origin', () {
      expect(clockTicks(8), [0, 2, 4, 6, 8]);
      expect(clockTicks(0), [0]);
      expect(clockTicks(-5), [0]);
    });

    test('a long one does not run past its last step', () {
      final ticks = clockTicks(86400 * 3, target: 6);
      expect(ticks.length, lessThan(10));
    });
  });

  group('the chart frame', () {
    test('the value axis keeps zero in view and pads the data', () {
      final range = gapValueRange(sebringRaceGapEnvelope());
      expect(range.min, lessThan(-8.3), reason: 'the whole race is behind');
      expect(range.max, greaterThan(0.11), reason: 'lap 1 touches level');
    });

    test('a race spent entirely behind still shows zero', () {
      final series = _flat(-3);
      final range = gapValueRange(series);
      expect(range.max, greaterThan(0));
      expect(range.min, lessThan(-3));
    });

    test('the domain runs from the recording\'s start to its last reading',
        () {
      final viewport = gapViewport(_race());
      expect(viewport.start, sebringRaceGapOrigin);
      expect(viewport.end, closeTo(1364.18, 1e-9));
    });
  });

  group('gapReadout', () {
    final race = _race();

    test('names the lap, the clock and the gap', () {
      final at = sebringRaceGapOrigin + 300.0;
      final near = race.readingNear(at)!;
      final lap = sebringRaceLaps()
          .lastWhere((l) => l.startSeconds <= near.seconds)
          .displayNumber;
      final text = gapReadout(race, at);
      expect(text, startsWith('Lap $lap · 5:00.0 · '));
      expect(text, endsWith(formatGap(near.gap)));
      expect(text, isNot(contains('unchanged')));
    });

    test('says so inside the stretch before the start, where nothing moved',
        () {
      final text = gapReadout(race, sebringRaceGapOrigin + 10);
      expect(text, 'Lap 1 · 0:10.0 · -0.19 s · unchanged');
    });

    test('says so after the flag too', () {
      final text = gapReadout(race, sebringRaceGapOrigin + 1340);
      expect(text, contains('-6.96 s'));
      expect(text, endsWith('unchanged'));
    });

    test('an exact zero is "no car timed", not a gap of nothing', () {
      final session = GapSession.derive(
        readings: _flat(0),
        envelope: _flat(0),
        laps: const [
          Lap(
              index: 0,
              startSeconds: 0,
              endSeconds: null,
              sectors: SectorTimes()),
        ],
        stats: const [],
        originSeconds: 0,
        endSeconds: 5,
      );
      expect(gapReadout(session, 2), 'Lap 1 · 0:02.0 · no car timed');
    });
  });
}

TraceSeries _flat(double value, {int count = 12}) {
  final data = Float64List.fromList([for (var i = 0; i < count; i++) value]);
  return TraceSeries(
    channelName: timeBehindNextChannelName,
    unit: 's',
    frequencyHz: 2,
    valueColumn: 'value',
    times: Float64List.fromList([for (var i = 0; i < count; i++) i * 0.5]),
    lows: data,
    highs: data,
  );
}
