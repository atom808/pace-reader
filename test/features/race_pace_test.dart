// Race pace and gaps (SPEC.md §8.9): the derivations, against the real Sebring
// Race readings — and, for one group, against the Practice and Qualify samples
// that are the reason the view is race-only.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart'
    show PitVisit;
import 'package:pace_reader/features/race_pace/application/race_pace.dart';

import '../fixtures/gap_samples.dart';
import '../fixtures/sebring_race_per_lap.dart';

GapSession _race({List<PitVisit> pitVisits = const []}) => GapSession.derive(
      readings: sebringRaceGapSeries(),
      envelope: sebringRaceGapEnvelope(),
      laps: sebringRaceLaps(),
      stats: sebringRaceGapStats(),
      originSeconds: sebringRaceGapOrigin,
      endSeconds: 1364.18,
      pitVisits: pitVisits,
    );

/// Seconds into the recording, for reading a time off the session clock.
double _at(double seconds) => sebringRaceGapOrigin + seconds;

TraceSeries _series(List<double> values, {double interval = 0.5}) {
  final data = Float64List.fromList(values);
  return TraceSeries(
    channelName: timeBehindNextChannelName,
    unit: 's',
    frequencyHz: 2,
    valueColumn: 'value',
    times: Float64List.fromList(
      [for (var i = 0; i < values.length; i++) i * interval],
    ),
    lows: data,
    highs: data,
  );
}

void main() {
  group('the real Race readings', () {
    final series = sebringRaceGapSeries();

    test('there are 2,682 of them, half a second apart', () {
      expect(series.length, 2682);
      expect(series.times.last - series.times.first, closeTo(1340.5, 1e-9));
    });

    test('every one is a live reading and all but five are behind', () {
      expect(series.lows.every(isLiveGap), isTrue);
      expect(series.lows.where((v) => v > 0), hasLength(5));
      expect(series.minValue, closeTo(-8.3624, 1e-4));
      expect(series.maxValue, closeTo(0.1132, 1e-4));
    });
  });

  group('carAheadChangesIn', () {
    final series = sebringRaceGapSeries();
    final changes = carAheadChangesIn(series);

    test('finds exactly the three passes of the first lap', () {
      expect(changes, hasLength(3));
      expect(
        [for (final c in changes) c.timeSeconds - sebringRaceGapOrigin],
        [122.5, 124.0, 165.0],
      );
    });

    test('reads each as the gap closing, then a car further up the road', () {
      final expected = [
        (0.1132, -0.4584),
        (-0.0593, -0.7119),
        (-0.0229, -2.0976),
      ];
      for (var i = 0; i < 3; i++) {
        expect(changes[i].before, closeTo(expected[i].$1, 1e-4));
        expect(changes[i].after, closeTo(expected[i].$2, 1e-4));
        expect(changes[i].step, lessThan(0));
        // Preceded by the gap closing to within 0.12 s — what a pass looks like.
        expect(changes[i].closedTo, lessThan(0.12));
        expect(changes[i].closedInFirst(), isTrue);
      }
    });

    test('the threshold sits between ordinary racing and a change', () {
      // The largest step that is not a change is 0.293 s (the scrap at 123 s);
      // the smallest change is 0.572 s. The threshold has to be between them,
      // with room each side, or it is fitted to three examples.
      final steps = [
        for (var i = 0; i + 1 < series.length; i++)
          (series.lows[i + 1] - series.lows[i]).abs(),
      ];
      final ordinary = steps.where((s) => s < carAheadChangeThreshold);
      final ordinaryMax = ordinary.reduce((a, b) => a > b ? a : b);
      final smallestChange =
          changes.map((c) => c.step.abs()).reduce((a, b) => a < b ? a : b);
      expect(ordinaryMax, closeTo(0.2935, 1e-3));
      expect(smallestChange, closeTo(0.5716, 1e-3));
      expect(carAheadChangeThreshold - ordinaryMax, greaterThan(0.1));
      expect(smallestChange - carAheadChangeThreshold, greaterThan(0.15));
    });

    test('a step onto or off an exactly-zero reading is not a change', () {
      // 0.0 is the game writing "no car timed"; a car appearing is not one
      // replacing another.
      expect(carAheadChangesIn(_series([-1.0, -1.02, 0.0, -5.0, -5.02])),
          isEmpty);
      expect(carAheadChangesIn(_series([-1.0, -1.02, -3.0, -3.02])),
          hasLength(1));
    });

    test('a slow drift, however far, is never a change', () {
      // 0.3 s a reading for 40 readings: 12 s of closing, no step over the bar.
      final drift = [for (var i = 0; i < 40; i++) -12.0 + i * 0.3];
      expect(carAheadChangesIn(_series(drift)), isEmpty);
    });
  });

  group('held stretches', () {
    final series = sebringRaceGapSeries();

    test('the grid start: 86 identical readings, 42.5 s', () {
      final held = heldReadingsAtStart(series)!;
      expect(held.count, 86);
      expect(held.durationSeconds, closeTo(42.5, 1e-9));
      expect(held.value, closeTo(-0.1879, 1e-4));
      expect(held.fromSeconds, sebringRaceGapOrigin);
    });

    test('the chequered flag: 22 identical readings, 10.5 s', () {
      final held = heldReadingsAtEnd(series)!;
      expect(held.count, 22);
      expect(held.durationSeconds, closeTo(10.5, 1e-9));
      expect(held.value, closeTo(-6.9584, 1e-4));
      // Half a second after `Finish Status` went to 1, at 1329.5 s.
      expect(held.fromSeconds - sebringRaceGapOrigin, closeTo(1330.0, 1e-9));
    });

    test('a live gap is not held: nothing else repeats more than twice', () {
      expect(heldReadingsAtStart(_series([-1.0, -1.1, -1.2])), isNull);
      expect(heldReadingsAtEnd(_series([-1.0, -1.1, -1.2])), isNull);
      expect(heldReadingsAtStart(_series(List.filled(9, -1.0))), isNull);
      expect(heldReadingsAtStart(_series(List.filled(10, -1.0))), isNotNull);
    });
  });

  group('per lap, on the real race', () {
    final session = _race();
    final laps = session.laps;

    test('one row per lap, the garage lap and the cut-off lap included', () {
      expect(laps, hasLength(20));
      expect(laps.first.exclusion, isNull, reason: 'lap 1 is real racing');
      expect(laps.last.exclusion, GapExclusion.incomplete);
      expect(session.countedLaps, hasLength(19));
    });

    test('a lap starts where the SQL says it does', () {
      // `lapStatsSql` opens a lap at the first channel row at or after the
      // boundary. The series-side rule must land on the same reading, for every
      // lap that has one, or the two reads describe different laps.
      final stats = sebringRaceGapStats();
      final byLap = {for (final s in stats) s.lapIndex: s};
      final series = sebringRaceGapSeries();
      for (final gap in laps) {
        final i = firstReadingAtOrAfter(series.times, gap.lap.startSeconds);
        expect(series.lows[i], byLap[gap.lap.index]!.first,
            reason: 'lap ${gap.lap.displayNumber}');
        expect(gap.start, byLap[gap.lap.index]!.first);
      }
    });

    test('gained is the movement of the gap, less the passes', () {
      // Independently derived from the file: (lap index, start, end, gained).
      const expected = [
        (0, -0.1879, -2.5186, 0.9682),
        (1, -2.5186, -3.2573, -0.7387),
        (10, -7.1475, -6.7437, 0.4038),
        (11, -6.7437, -6.3024, 0.4412),
        (15, -7.3089, -8.0017, -0.6928),
        (18, -7.9741, -6.9584, 1.0157),
      ];
      for (final (index, start, end, gained) in expected) {
        final lap = laps[index];
        expect(lap.start, closeTo(start, 1e-4), reason: 'lap $index start');
        expect(lap.end, closeTo(end, 1e-4), reason: 'lap $index end');
        expect(lap.gained, closeTo(gained, 2e-3), reason: 'lap $index');
      }
    });

    test('the first lap gains on the cars it passes, not loses to them', () {
      // Raw, the gap goes from -0.19 to -2.52: a 2.33 s "loss". The three
      // passes account for -3.30 s of that, so what the lap did to the gap to
      // whoever was ahead of it at the time is +0.97 s.
      final first = laps.first;
      expect(first.changes, hasLength(3));
      expect(first.end! - first.start!, closeTo(-2.3307, 1e-3));
      expect(first.gained, closeTo(0.9682, 2e-3));
      expect(first.gained, greaterThan(0));
    });

    test('closest is the smallest reading in the lap, sign kept', () {
      expect(laps[0].closest, closeTo(0.0009, 5e-4));
      expect(laps[1].closest, closeTo(-2.414, 1e-3));
      expect(laps[18].closest, closeTo(-6.9572, 1e-4));
    });

    test('carries the SQL mean', () {
      expect(laps[3].mean, closeTo(-4.0793, 1e-4));
    });

    test('the lap gains add up to the raw movement less the passes', () {
      // start → end is -6.77 s. -3.30 s of it is somebody else being ahead;
      // the other -3.47 s is what the driver did against the cars ahead.
      expect(session.startGap, closeTo(-0.1879, 1e-4));
      expect(session.endGap, closeTo(-6.9584, 1e-4));
      expect(session.changeSteps, closeTo(-3.2989, 2e-3));
      expect(session.netGained, closeTo(-3.4715, 2e-3));
      expect(
        session.endGap! - session.startGap!,
        closeTo(session.netGained + session.changeSteps, 2e-3),
        reason: 'nothing gained or lost is unaccounted for',
      );
    });

    test('closest approach: level with the car ahead 3 s before the first pass',
        () {
      final closest = session.closestApproach!;
      expect(closest.gap, closeTo(0.0009, 5e-4));
      expect(closest.atSeconds - sebringRaceGapOrigin, closeTo(119.0, 1e-9));
      expect(session.lapAt(closest.atSeconds)!.index, 0);
    });

    test('slower laps lose more: the sign is pinned by the driver\'s own pace',
        () {
      // The independent ground truth for what the channel means. Over laps on
      // which the car ahead does not change, the gap moves by your lap time
      // minus theirs, so gained must fall as the lap gets longer. Measured
      // -1.44 ± 0.38 s per second (r = -0.68) on the 18 closed racing laps;
      // the opposite sign convention, or a channel about the car behind, gives
      // +1.
      final pairs = [
        for (final gap in laps)
          if (gap.lap.index >= 1 && gap.counted && gap.changes.isEmpty)
            (gap.lap.wallClockSeconds!, gap.gained!),
      ];
      expect(pairs, hasLength(18));
      final n = pairs.length;
      final meanX = pairs.fold<double>(0, (s, p) => s + p.$1) / n;
      final meanY = pairs.fold<double>(0, (s, p) => s + p.$2) / n;
      var sxx = 0.0, sxy = 0.0, syy = 0.0;
      for (final (x, y) in pairs) {
        sxx += (x - meanX) * (x - meanX);
        sxy += (x - meanX) * (y - meanY);
        syy += (y - meanY) * (y - meanY);
      }
      final slope = sxy / sxx;
      final r = sxy / math.sqrt(sxx * syy);
      expect(slope, lessThan(-1.0));
      expect(slope, greaterThan(-2.0));
      expect(r, lessThan(-0.6));
    });

    test('a lap with time in the pit lane is left out', () {
      final lap8 = sebringRaceLaps()[7];
      final withStop = _race(pitVisits: [
        PitVisit(
          enteredSeconds: lap8.startSeconds + 30,
          exitedSeconds: lap8.startSeconds + 52.5,
        ),
      ]);
      expect(withStop.laps[7].exclusion, GapExclusion.pitLane);
      expect(withStop.countedLaps, hasLength(18));
      expect(
        withStop.netGained,
        closeTo(session.netGained - session.laps[7].gained!, 1e-9),
      );
    });

    test('a lap with no readings is absent from the sum, not zero', () {
      final trimmed = [
        for (final s in sebringRaceGapStats())
          if (s.lapIndex != 4) s,
      ];
      final gaps = lapGapsFrom(
        laps: sebringRaceLaps(),
        stats: trimmed,
        readings: sebringRaceGapSeries(),
        changes: carAheadChangesIn(sebringRaceGapSeries()),
      );
      expect(gaps[4].exclusion, GapExclusion.noData);
      expect(gaps[4].gained, isNull);
      expect(gaps[4].counted, isFalse);
    });

    test('a lap that opens on an exactly-zero reading has no car ahead', () {
      // Readings at 0, 0.5, ... s: lap 2 (seconds 2-4) holds only zeros.
      final flat = _series([
        -3.0, -3.1, -3.2, -3.3, //
        0.0, 0.0, 0.0, 0.0,
        -3.4, -3.5, -3.6, -3.7,
      ]);
      final gaps = lapGapsFrom(
        laps: [
          const Lap(
            index: 0,
            startSeconds: 0,
            endSeconds: 2,
            sectors: SectorTimes(),
          ),
          const Lap(
            index: 1,
            startSeconds: 2,
            endSeconds: 4,
            sectors: SectorTimes(),
          ),
          const Lap(
            index: 2,
            startSeconds: 4,
            endSeconds: null,
            sectors: SectorTimes(),
          ),
        ],
        stats: const [
          LapChannelStats(
              lapIndex: 0, first: -3.0, last: -3.3, min: -3.3, max: -3.0,
              mean: -3.15, samples: 4),
          LapChannelStats(
              lapIndex: 1, first: 0.0, last: 0.0, min: 0.0, max: 0.0,
              mean: 0.0, samples: 4),
          LapChannelStats(
              lapIndex: 2, first: -3.4, last: -3.7, min: -3.7, max: -3.4,
              mean: -3.55, samples: 4),
        ],
        readings: flat,
        changes: const [],
      );
      expect(gaps[1].exclusion, GapExclusion.noCarAhead);
      expect(gaps[1].closest, isNull, reason: 'nothing live to be closest');
    });
  });

  group('lookups', () {
    final session = _race();

    test('lapAt is the last lap that had started', () {
      expect(session.lapAt(_at(0))!.index, 0);
      expect(session.lapAt(_at(172.0))!.index, 0);
      expect(session.lapAt(_at(172.3))!.index, 1);
      expect(session.lapAt(_at(1340))!.index, 19);
    });

    test('readingNear snaps to the closest reading', () {
      final near = session.readingNear(_at(122.4))!;
      expect(near.seconds, _at(122.5));
      expect(near.gap, closeTo(-0.4584, 1e-4));
      expect(session.readingNear(_at(-50))!.seconds, _at(0));
      expect(session.readingNear(_at(5000))!.seconds, _at(1340.5));
    });

    test('firstReadingAtOrAfter is a lower bound', () {
      final times = Float64List.fromList([1, 2, 3]);
      expect(firstReadingAtOrAfter(times, 0), 0);
      expect(firstReadingAtOrAfter(times, 2), 1);
      expect(firstReadingAtOrAfter(times, 2.1), 2);
      expect(firstReadingAtOrAfter(times, 4), 3);
    });
  });

  group('why the view is race-only', () {
    // The same channel in the other two samples, run through the same detector
    // at a looser 0.3 s bar so the comparison is like for like with the notes
    // in the library comment.
    final race = sebringRaceGapSeries();
    final qualify = qualifyGapSeries();
    final practice = practiceGapSeries();

    int steps(TraceSeries s) => carAheadChangesIn(s, threshold: 0.3).length;

    test('three steps in a whole race, dozens in a qualifying lap', () {
      expect(steps(race), 3);
      expect(steps(qualify), 61);
      expect(steps(practice), 68);
    });

    test('the offset changes sign and is often positive', () {
      double positive(TraceSeries s) =>
          s.lows.where((v) => v > 0).length / s.length;
      expect(positive(race), lessThan(0.005));
      expect(positive(qualify), closeTo(0.081, 0.002));
      expect(positive(practice), closeTo(0.218, 0.002));
    });

    test('and reaches tens of seconds in either direction', () {
      expect(race.minValue, greaterThan(-9));
      expect(qualify.minValue, closeTo(-22.2639, 1e-3));
      expect(practice.minValue, closeTo(-41.8834, 1e-3));
      expect(practice.maxValue, closeTo(43.4016, 1e-3));
    });

    test('exact zeros belong to the other two files alone', () {
      expect(race.lows.where((v) => v == 0), isEmpty);
      expect(qualify.lows.where((v) => v == 0), hasLength(43));
      expect(practice.lows.where((v) => v == 0), hasLength(18));
    });

    test('the recorded gap in each is a single 20 s+ step', () {
      double biggest(TraceSeries s) {
        var m = 0.0;
        for (var i = 0; i + 1 < s.length; i++) {
          if (!isLiveGap(s.lows[i]) || !isLiveGap(s.lows[i + 1])) continue;
          final d = (s.lows[i + 1] - s.lows[i]).abs();
          if (d > m) m = d;
        }
        return m;
      }

      expect(biggest(race), closeTo(2.0747, 1e-3));
      expect(biggest(qualify), closeTo(23.9720, 5e-3));
      expect(biggest(practice), closeTo(80.6395, 5e-3));
    });
  });
}
