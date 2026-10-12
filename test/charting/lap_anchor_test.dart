// Where a lap's clock starts, and the delta's check against the game's
// splits (comparison proposal §4 "Delta self-check", D1).
//
// Fed by the two real Sebring fixture laps at 5 Hz. The native-rate probe
// (0a) measured this pair's residuals at S1 +0.004, S1+S2 −0.002 and the
// line −0.002 s; the 5 Hz laps must land inside the same bounds, and do.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../features/compare_harness.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

LapAnchor _anchor(
  LapTelemetry t, {
  Lap? lap,
  CourseFacts course = sebringCourse,
  bool recordingStart = false,
}) => LapAnchor.measure(
  lap: lap ?? t.lap,
  axis: DistanceAxis.fromSeries(t.lapDistance!),
  course: course,
  recordingStart: recordingStart,
);

void main() {
  group('LapAnchor', () {
    test('a lap with all three splits is re-anchored on them', () {
      final anchor = _anchor(sebringLapTelemetry());
      expect(anchor.reanchored, isTrue);
      expect(anchor.eventSeconds, sebringLapStartSeconds);
      // The Lap event sits 3.8 ms after the line: inside its 20 ms grid.
      expect(anchor.offset, closeTo(-0.0038, 0.0002));
      expect(
        anchor.startSeconds,
        closeTo(sebringLapStartSeconds - 0.0038, 2e-4),
      );
      for (final residual in anchor.residuals.values) {
        expect(residual.abs(), lessThan(DeltaCheck.perLapLimit));
      }
    });

    test("the residuals are what the start's move cannot remove", () {
      final anchor = _anchor(sebringLapTelemetry());
      final raw = anchor.traceMinusGame;
      final mean =
          raw.values.reduce((a, b) => a + b) / TimingLine.values.length;
      expect(anchor.offset, closeTo(mean, 1e-12));
      for (final line in TimingLine.values) {
        expect(anchor.residuals[line], closeTo(raw[line]! - mean, 1e-12));
      }
    });

    test("a recording's first lap keeps its Lap event", () {
      final anchor = _anchor(sebringLapTelemetry(), recordingStart: true);
      expect(anchor.reanchored, isFalse);
      expect(anchor.offset, 0);
      expect(anchor.traceMinusGame, isEmpty);
    });

    test('a lap missing a split keeps its Lap event, measured at the rest', () {
      final file = CompareFile('/f.duckdb', withoutSplits: true);
      final anchor = _anchor(file.telemetry(sebringLapIndex));
      expect(anchor.reanchored, isFalse);
      expect(anchor.offset, 0);
      expect(anchor.traceMinusGame.keys, [TimingLine.finish]);
    });

    test('no course facts, no measuring', () {
      final t = sebringLapTelemetry();
      final anchor = LapAnchor.measure(
        lap: t.lap,
        axis: DistanceAxis.fromSeries(t.lapDistance!),
        course: null,
      );
      expect(anchor.startSeconds, t.lap.startSeconds);
      expect(anchor.traceMinusGame, isEmpty);
    });

    test('a later recording of the same lap moves by the same amount', () {
      final shifted = CompareFile('/later.duckdb', timeShift: 1234.5);
      final original = _anchor(sebringLapTelemetry());
      final later = _anchor(shifted.telemetry(sebringLapIndex));
      expect(later.offset, closeTo(original.offset, 1e-9));
      expect(later.startSeconds - 1234.5, closeTo(original.startSeconds, 1e-9));
    });
  });

  group('reachTime', () {
    final axis = DistanceAxis.fromSeries(
      TraceSeries(
        channelName: 'Lap Dist',
        unit: 'm',
        frequencyHz: 5,
        valueColumn: 'value',
        times: Float64List.fromList([10, 10.2, 10.4]),
        lows: Float64List.fromList([3050, 3062, 3074]),
        highs: Float64List.fromList([3050, 3062, 3074]),
      ),
    );

    test('interpolates inside the lap', () {
      expect(reachTime(axis, 3056), closeTo(10.1, 1e-9));
    });

    test('extrapolates past the last sample at its own speed', () {
      // 12 m per 0.2 s: the timing line 7.5 m on is 0.125 s later.
      expect(reachTime(axis, 3081.5), closeTo(10.525, 1e-9));
    });

    test('but not further than a couple of samples could carry it', () {
      expect(reachTime(axis, 3074 + maxExtrapolation + 1), isNull);
    });

    test('nor before the first sample', () {
      expect(reachTime(axis, 3000), isNull);
    });
  });

  group('DeltaCheck', () {
    test('the fixture pair agrees with the game at all three lines', () {
      final check = DeltaCheck.of(
        _anchor(sebringLapTelemetry()),
        _anchor(sebringLap3Telemetry()),
      );
      expect(check.bothReanchored, isTrue);
      // The native probe's values, to its own rounding.
      expect(check.pair[TimingLine.sector1], closeTo(0.004, 0.001));
      expect(check.pair[TimingLine.sector2], closeTo(-0.002, 0.001));
      expect(check.pair[TimingLine.finish], closeTo(-0.002, 0.001));
      expect(check.worstLap!.abs(), lessThan(DeltaCheck.perLapLimit));
      expect(check.worstPair!.abs(), lessThan(DeltaCheck.pairLimit));
      expect(check.pairBound, DeltaCheck.pairLimit);
      expect(check.status, DeltaCheckStatus.passed);
    });

    test('a lap that kept its Lap event is checked at 30 ms', () {
      final file = CompareFile('/f.duckdb', withoutSplits: true);
      final check = DeltaCheck.of(
        _anchor(file.telemetry(sebringLapIndex)),
        _anchor(sebringLap3Telemetry()),
      );
      expect(check.bothReanchored, isFalse);
      expect(check.pairBound, DeltaCheck.unanchoredPairLimit);
      // Only the line, where both laps carry the game's figure.
      expect(check.pair.keys, [TimingLine.finish]);
      expect(check.status, DeltaCheckStatus.passed);
    });

    test('a split the trace contradicts fails the check', () {
      // S1 written 50 ms long: no start explains all three lines at once.
      final lap = sebringLap().copyWith(
        sectors: SectorTimes.fromCumulative(
          sector1: sebringLapSector1 + 0.05,
          sector2Cumulative: sebringLapSector2Cumulative,
          lapTimeSeconds: sebringLapTimeSeconds,
        ),
      );
      final check = DeltaCheck.of(
        _anchor(sebringLapTelemetry(), lap: lap),
        _anchor(sebringLap3Telemetry()),
      );
      expect(check.worstLap!.abs(), greaterThan(DeltaCheck.perLapLimit));
      expect(check.status, DeltaCheckStatus.failed);
    });

    test('with no line both laps were timed at, it is unchecked', () {
      final check = DeltaCheck.of(
        LapAnchor.event(sebringLapStartSeconds),
        _anchor(sebringLap3Telemetry()),
      );
      expect(check.pair, isEmpty);
      expect(check.status, DeltaCheckStatus.unchecked);
    });
  });
}
