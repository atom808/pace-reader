import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/decimation.dart';
import 'package:pace_reader/widgets/charting/lap_alignment.dart';

/// A lap of [length] metres driven at a constant [speed] from [start] s.
DistanceAxis _lap({
  required double start,
  required double speed,
  double length = 3000,
}) {
  final n = (length / speed * 10).ceil() + 1;
  final times = Float64List(n);
  final distances = Float64List(n);
  for (var i = 0; i < n; i++) {
    times[i] = start + i / 10;
    distances[i] = (speed * i / 10).clamp(0, length).toDouble();
  }
  return DistanceAxis.fromSeries(
    TraceSeries(
      channelName: 'Lap Dist',
      unit: 'm',
      frequencyHz: 10,
      valueColumn: 'value',
      times: times,
      lows: distances,
      highs: distances,
    ),
  );
}

void main() {
  group('LapAlignment', () {
    // Base at 50 m/s from t = 100 s; the reference at 55 m/s from its own
    // t = 400 s, shifted onto Base's clock.
    final alignment = LapAlignment(
      base: _lap(start: 100, speed: 50),
      reference: _lap(start: 400, speed: 55),
      timeShift: -300,
    );

    test('Distance puts the reference at the same point of the lap', () {
      expect(alignment.referenceStationFor(TraceAxis.distance, 1234), 1234);
    });

    test('Time puts it where it was at the same moment', () {
      // 20 s in: Base at 1000 m, the reference at 1100 m.
      expect(alignment.baseStationAt(120), closeTo(1000, 1e-9));
      expect(
        alignment.referenceStationFor(TraceAxis.time, 120),
        closeTo(1100, 1e-9),
      );
      expect(alignment.gapAt(120), closeTo(100, 1e-9));
    });

    test('is null off either lap rather than clamped', () {
      expect(alignment.baseStationAt(99), isNull);
      expect(alignment.referenceStationAt(99), isNull);
      expect(alignment.gapAt(99), isNull);
    });

    test('a lap without a usable distance places nothing on Time', () {
      const none = LapAlignment();
      expect(none.referenceStationFor(TraceAxis.time, 120), isNull);
      expect(none.referenceStationFor(TraceAxis.distance, 50), 50);
    });
  });
}
