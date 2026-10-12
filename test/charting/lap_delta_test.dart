// The time delta between two laps (SPEC.md §8.3, §8.4).
//
// Synthetic laps pin down the arithmetic; the two real Sebring laps pin it
// against the one number the file can confirm independently — the difference
// between the laps' own `Lap Time`s.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/widgets/charting/decimation.dart';
import 'package:pace_reader/widgets/charting/lap_delta.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

/// A 10 Hz `Lap Dist` read for a lap starting at [start], covering [metres]
/// in [seconds] at constant speed, first sampled [firstSampleAfter] seconds
/// after the line.
DistanceAxis _lap({
  required double start,
  required double seconds,
  double metres = 3000,
  double firstSampleAfter = 0,
  List<double>? distances,
}) {
  final n = (seconds * 10).floor() + 1;
  final times = [for (var i = 0; i < n; i++) start + firstSampleAfter + i / 10];
  final values = distances ??
      [for (final t in times) metres * (t - start) / seconds];
  return DistanceAxis.fromSeries(TraceSeries(
    channelName: 'Lap Dist',
    unit: 'm',
    frequencyHz: 10,
    valueColumn: 'value',
    times: Float64List.fromList(times),
    lows: Float64List.fromList(values),
    highs: Float64List.fromList(values),
  ));
}

void main() {
  group('LapDelta.between', () {
    test('a slower lap falls behind in proportion to the distance covered', () {
      // 3000 m in 60 s against 3000 m in 50 s: at every point the slower lap
      // has taken 6/5 of the reference's time, so it is 1/6 of its own
      // elapsed time behind.
      final delta = LapDelta.between(
        lap: _lap(start: 100, seconds: 60),
        lapStartSeconds: 100,
        reference: _lap(start: 500, seconds: 50),
        referenceStartSeconds: 500,
      )!;
      for (var i = 0; i < delta.length; i++) {
        final elapsed = delta.times[i] - 100;
        expect(delta.deltas[i], closeTo(elapsed / 6, 1e-9),
            reason: 'sample $i');
      }
      expect(delta.finalDelta, closeTo(10, 1e-9));
    });

    test('is negative where the lap is ahead of the reference', () {
      final delta = LapDelta.between(
        lap: _lap(start: 0, seconds: 50),
        lapStartSeconds: 0,
        reference: _lap(start: 80, seconds: 60),
        referenceStartSeconds: 80,
      )!;
      expect(delta.finalDelta, closeTo(-10, 1e-9));
      expect(delta.deltas.every((d) => d <= 1e-9), isTrue);
    });

    test('measures each lap from its own line crossing, not its first sample',
        () {
      // Identical pace, but the lap's first `Lap Dist` sample arrives 0.07 s
      // after the line — the real Sebring case. Anchoring on that sample would
      // report a gap of 0.07 s that no one drove; anchoring on the lap event
      // reports none.
      final delta = LapDelta.between(
        lap: _lap(start: 10, seconds: 60, firstSampleAfter: 0.07),
        lapStartSeconds: 10,
        reference: _lap(start: 200, seconds: 60),
        referenceStartSeconds: 200,
      )!;
      for (final d in delta.deltas) {
        expect(d, closeTo(0, 1e-9));
      }
    });

    test('compares only the stretch of track both laps recorded', () {
      // The reference stops 500 m short (a recording that ended mid-lap);
      // nothing past the last distance it reached has a counterpart.
      final reference = _lap(start: 0, seconds: 50, metres: 2500);
      final delta = LapDelta.between(
        lap: _lap(start: 0, seconds: 60),
        lapStartSeconds: 0,
        reference: reference,
        referenceStartSeconds: 0,
      )!;
      expect(delta.distances.last, lessThanOrEqualTo(2500));
      expect(delta.distances.first, greaterThanOrEqualTo(0));
    });

    test('is null when either lap has no usable distance axis', () {
      // The garage lap: `Lap Dist` runs backwards while the car manoeuvres in
      // the pits, so a distance occurs twice and has no single time.
      final garage = _lap(
        start: 0,
        seconds: 3,
        distances: [
          for (var i = 0; i <= 30; i++) i < 15 ? i * 10.0 : (30 - i) * 10.0,
        ],
      );
      final flying = _lap(start: 100, seconds: 60);
      expect(
        LapDelta.between(
          lap: garage,
          lapStartSeconds: 0,
          reference: flying,
          referenceStartSeconds: 100,
        ),
        isNull,
      );
      expect(
        LapDelta.between(
          lap: flying,
          lapStartSeconds: 100,
          reference: garage,
          referenceStartSeconds: 0,
        ),
        isNull,
      );
    });

    test('is null when the laps share no stretch of track', () {
      final early = _lap(
        start: 0,
        seconds: 10,
        distances: [for (var i = 0; i <= 100; i++) i * 1.0],
      );
      final late = _lap(
        start: 50,
        seconds: 10,
        distances: [for (var i = 0; i <= 100; i++) 500 + i * 1.0],
      );
      expect(
        LapDelta.between(
          lap: early,
          lapStartSeconds: 0,
          reference: late,
          referenceStartSeconds: 50,
        ),
        isNull,
      );
    });
  });

  group('LapDelta.toPlot', () {
    final delta = LapDelta.between(
      lap: _lap(start: 100, seconds: 60),
      lapStartSeconds: 100,
      reference: _lap(start: 500, seconds: 50),
      referenceStartSeconds: 500,
    )!;

    test('plots against the lap\'s own distance or its own clock', () {
      final byDistance = delta.toPlot(TraceAxis.distance);
      final byTime = delta.toPlot(TraceAxis.time);
      expect(byDistance.xs, delta.distances);
      expect(byTime.xs, delta.times);
      expect(byDistance.lows, delta.deltas);
    });

    test('keeps zero inside the value range', () {
      // A lap that only ever lost time still needs the "level with the
      // reference" line on the panel — it is what the panel is read against.
      final range = delta.toPlot(TraceAxis.distance).valueRange;
      expect(range.min, lessThanOrEqualTo(0));
      expect(range.max, closeTo(10, 1e-9));
    });
  });

  group('deltaAt', () {
    final delta = LapDelta.between(
      lap: _lap(start: 100, seconds: 60),
      lapStartSeconds: 100,
      reference: _lap(start: 500, seconds: 50),
      referenceStartSeconds: 500,
    )!;

    test('equals the trace at its samples', () {
      for (var i = 0; i < delta.length; i++) {
        expect(delta.deltaAt(delta.distances[i]), delta.deltas[i],
            reason: 'sample $i');
      }
    });

    test('is the straight line between two samples', () {
      for (var i = 1; i < delta.length; i++) {
        final d0 = delta.distances[i - 1], d1 = delta.distances[i];
        final quarter = d0 + (d1 - d0) / 4;
        expect(
          delta.deltaAt(quarter),
          closeTo(
            delta.deltas[i - 1] + (delta.deltas[i] - delta.deltas[i - 1]) / 4,
            1e-12,
          ),
          reason: 'between samples ${i - 1} and $i',
        );
      }
    });

    test('is null outside the stretch both laps recorded', () {
      expect(delta.deltaAt(delta.distances.first - 0.1), isNull);
      expect(delta.deltaAt(delta.distances.last + 0.1), isNull);
    });

    test('where the lap stood still, reads the moment it arrived', () {
      // Stopped at 1500 m for half a second: the delta grows while it sits,
      // and the point is first reached at the start of the stop.
      final stopped = _lap(
        start: 0,
        seconds: 60.5,
        distances: [
          for (var i = 0; i <= 605; i++)
            i <= 300 ? i * 5.0 : (i <= 305 ? 1500.0 : 1500 + (i - 305) * 5.0),
        ],
      );
      final d = LapDelta.between(
        lap: stopped,
        lapStartSeconds: 0,
        reference: _lap(start: 0, seconds: 60),
        referenceStartSeconds: 0,
      )!;
      final atStop = [
        for (var i = 0; i < d.length; i++)
          if (d.distances[i] == 1500) d.deltas[i],
      ];
      expect(atStop.length, greaterThan(1));
      expect(d.deltaAt(1500), atStop.first);
    });
  });

  group('DistanceAxis.firstReachTime', () {
    test('matches timeAt wherever the lap kept moving', () {
      final axis = _lap(start: 100, seconds: 60);
      for (final d in [0.0, 1.5, 999.9, 1500.0, 2999.5]) {
        expect(axis.firstReachTime(d), closeTo(axis.timeAt(d), 1e-9),
            reason: '$d m');
      }
    });

    test('a stop on a boundary is charged after it, not before', () {
      // At rest at 1500 m from 30.0 s to 30.5 s. timeAt lands on the last
      // sample at that distance; the first reach is the first one.
      final axis = _lap(
        start: 0,
        seconds: 60.5,
        distances: [
          for (var i = 0; i <= 605; i++)
            i <= 300 ? i * 5.0 : (i <= 305 ? 1500.0 : 1500 + (i - 305) * 5.0),
        ],
      );
      expect(axis.firstReachTime(1500), closeTo(30.0, 1e-9));
      expect(axis.timeAt(1500), closeTo(30.5, 1e-9));
    });

    test('is null where the lap was never seen', () {
      final axis = _lap(start: 0, seconds: 60, firstSampleAfter: 0.05);
      expect(axis.firstReachTime(axis.distances.first - 1), isNull);
      expect(axis.firstReachTime(axis.distances.last + 1), isNull);
      expect(axis.firstReachTime(axis.distances.first), axis.times.first);
    });
  });

  test('two real Sebring laps: the delta ends at the lap-time difference', () {
    // Lap 2 (index 1) against lap 4 (index 3) of the real Race sample, from
    // the 5 Hz fixtures. The game timed them 64.497 s and 64.030 s; a delta
    // trace that is right about the whole lap has to be right about its end.
    DistanceAxis axis(LapTelemetry t) =>
        DistanceAxis.fromSeries(t.lapDistance!);
    final slower = sebringLapTelemetry();
    final faster = sebringLap3Telemetry();
    final delta = LapDelta.between(
      lap: axis(slower),
      lapStartSeconds: slower.startSeconds,
      reference: axis(faster),
      referenceStartSeconds: faster.startSeconds,
    )!;

    const expected = sebringLapTimeSeconds - sebringLap3TimeSeconds;
    expect(expected, closeTo(0.4678, 1e-4));
    // Measured 0.4587: at 5 Hz a sample lands every ~9 m, so the comparison
    // stops short of the line (3062.8 m of ~3080) and 0.009 s short of the
    // difference. The tolerance is three times that, not a guess at it.
    expect(delta.finalDelta, closeTo(expected, 0.03));
    // And it starts level (measured -0.002 s), because both laps are timed
    // from their own line crossing.
    expect(delta.deltas.first, closeTo(0, 0.03));
  });
}
