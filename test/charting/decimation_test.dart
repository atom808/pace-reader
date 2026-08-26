// Distance-axis remapping and plot building (SPEC.md §8.4, §9.5).
//
// The values here are the real Sebring Race numbers wherever one exists, so a
// regression fails against the file rather than against a made-up curve.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/decimation.dart';
import 'package:pace_reader/widgets/charting/viewport.dart';

TraceSeries _series({
  required List<double> times,
  required List<double> lows,
  List<double>? highs,
  String name = 'Lap Dist',
  String unit = 'm',
  int hz = 10,
}) =>
    TraceSeries(
      channelName: name,
      unit: unit,
      frequencyHz: hz,
      valueColumn: 'value',
      times: Float64List.fromList(times),
      lows: Float64List.fromList(lows),
      highs: Float64List.fromList(highs ?? lows),
    );

/// A 10 Hz lap-distance ramp: 0 → [metres] over [seconds], from [start].
TraceSeries _lapDistance({
  double start = 100,
  double seconds = 60,
  double metres = 3000,
}) {
  final n = (seconds * 10).round() + 1;
  return _series(
    times: [for (var i = 0; i < n; i++) start + i / 10],
    lows: [for (var i = 0; i < n; i++) metres * (i / (n - 1))],
  );
}

void main() {
  group('TraceWindow.forLap', () {
    test('asks for one bucket per master-grid sample', () {
      // The claim the single-fetch design rests on: at 100 buckets per second
      // the fastest channel in the file arrives one sample per bucket, so
      // zooming inside a lap has nothing finer left to fetch.
      final window = TraceWindow.forLap(startSeconds: 10, endSeconds: 50);
      expect(window.buckets, 4000);
      expect(window.durationSeconds, closeTo(40, 1e-9));
    });

    test('clamps the real Sebring lap to the ceiling', () {
      // 64.5 s of lap 1 wants 6450 buckets and gets the 6000 cap — still
      // finer than one sample per 1.1 master rows.
      final window =
          TraceWindow.forLap(startSeconds: 195.82, endSeconds: 260.32);
      expect(window.buckets, 6000);
      expect(window.durationSeconds, closeTo(64.5, 1e-9));
    });

    test('caps a long lap rather than fetching without limit', () {
      // A 6-minute Le Mans lap would otherwise ask for 36,000 buckets.
      final window = TraceWindow.forLap(startSeconds: 0, endSeconds: 360);
      expect(window.buckets, 6000);
    });

    test('a very short window still gets enough buckets to draw', () {
      final window = TraceWindow.forLap(startSeconds: 0, endSeconds: 0.5);
      expect(window.buckets, greaterThanOrEqualTo(240));
    });
  });

  group('DistanceAxis', () {
    test('interpolates between the 10 Hz samples a 100 Hz trace falls between',
        () {
      final axis = DistanceAxis.fromSeries(_lapDistance());
      // Halfway between two distance samples in time is halfway in distance
      // on a linear ramp.
      final a = axis.distanceAt(130.0);
      final b = axis.distanceAt(130.1);
      expect(axis.distanceAt(130.05), closeTo((a + b) / 2, 1e-6));
    });

    test('clamps outside the window instead of dropping the ends', () {
      // A 100 Hz channel legitimately has up to a tenth of a second of samples
      // before the first 10 Hz distance sample; returning null there would
      // trim the ends off every trace.
      final axis = DistanceAxis.fromSeries(_lapDistance());
      expect(axis.distanceAt(0), 0);
      expect(axis.distanceAt(1e9), closeTo(3000, 1e-9));
    });

    test('round-trips through its own inverse', () {
      final axis = DistanceAxis.fromSeries(_lapDistance());
      for (final seconds in [100.0, 117.37, 141.9, 159.99]) {
        expect(axis.timeAt(axis.distanceAt(seconds)), closeTo(seconds, 1e-6));
      }
    });

    test('flags a lap whose distance runs backwards', () {
      // Measured on the checked-in fixture: lap 0 — the garage lap — has one
      // backwards step while laps 1-3 have none, because the car is
      // manoeuvring in the pits rather than driving the circuit. A distance
      // axis there would fold the chart back over itself.
      final good = DistanceAxis.fromSeries(_lapDistance());
      expect(good.isMonotonic, isTrue);
      expect(good.isUsable, isTrue);

      final garage = DistanceAxis.fromSeries(_series(
        times: [10, 10.1, 10.2, 10.3],
        lows: [0, 12, 4, 18],
      ));
      expect(garage.isMonotonic, isFalse);
      expect(garage.isUsable, isFalse);
    });

    test('a stationary car repeating a distance is not a violation', () {
      final axis = DistanceAxis.fromSeries(_series(
        times: [10, 10.1, 10.2, 10.3],
        lows: [40, 40, 40, 41],
      ));
      expect(axis.isMonotonic, isTrue);
    });
  });

  group('TracePlot', () {
    final speed = _series(
      name: 'Ground Speed',
      unit: 'km/h',
      hz: 100,
      times: [100.0, 100.5, 101.0, 101.5],
      lows: [40, 80, 120, 60],
      highs: [45, 90, 130, 70],
    );

    test('keeps time as the domain on the time axis', () {
      final plot = TracePlot.fromSeries(speed, axis: TraceAxis.time);
      expect(plot.xs.first, 100.0);
      expect(plot.xs.last, 101.5);
      expect(plot.valueRange, const ValueRange(40, 130));
    });

    test('projects onto lap distance when asked', () {
      final axis = DistanceAxis.fromSeries(_lapDistance());
      final plot = TracePlot.fromSeries(speed,
          axis: TraceAxis.distance, distanceAxis: axis);
      expect(plot.xs.first, closeTo(axis.distanceAt(100.0), 1e-9));
      expect(plot.xs.last, closeTo(axis.distanceAt(101.5), 1e-9));
      // Strictly increasing, or the trace would fold over itself.
      for (var i = 1; i < plot.length; i++) {
        expect(plot.xs[i], greaterThan(plot.xs[i - 1]));
      }
    });

    test('falls back to time when the lap has no usable distance axis', () {
      // Whether a lap has one is a property of the recording, not a
      // programming error, so this must not throw.
      final plot = TracePlot.fromSeries(speed, axis: TraceAxis.distance);
      expect(plot.xs.first, 100.0);
    });

    test('the cursor reads the nearest bucket, not the preceding one', () {
      // A cursor a pixel past a peak should report the peak.
      final plot = TracePlot.fromSeries(speed, axis: TraceAxis.time);
      expect(plot.nearestIndex(100.99), 2);
      expect(plot.nearestIndex(100.76), 2);
      expect(plot.nearestIndex(100.74), 1);
      // The readout is the envelope midpoint: a bucket is a range the signal
      // covered, so a single number for it cannot be a measured extreme.
      expect(plot.valueAt(101.0), closeTo(125, 1e-9));
    });

    test('clamps a cursor outside the plot to its ends', () {
      final plot = TracePlot.fromSeries(speed, axis: TraceAxis.time);
      expect(plot.nearestIndex(-5), 0);
      expect(plot.nearestIndex(1e9), plot.length - 1);
    });
  });

  group('StepPlot', () {
    // The real shape of a gear read: the first row is the value in force when
    // the window opened and sits *before* it (see eventWindowSql).
    final gear = StepSeries.fromRows(
      const [(190.0, 4), (196.5, 3), (200.0, 4), (205.0, 5)],
      eventName: 'Gear',
    );

    test('pulls the preceding change forward to the window edge', () {
      // Extending the axis backwards instead would place a change from the
      // previous lap on this one.
      final plot = StepPlot.fromSeries(gear,
          axis: TraceAxis.time, window: const ChartViewport(195.82, 260.32));
      expect(plot.xs.first, 195.82);
      expect(plot.values.first, 4);
    });

    test('holds a value between changes rather than interpolating', () {
      // Interpolating would draw the car passing through gears it never used.
      final plot = StepPlot.fromSeries(gear,
          axis: TraceAxis.time, window: const ChartViewport(195.82, 260.32));
      expect(plot.valueAt(198), 3);
      expect(plot.valueAt(199.99), 3);
      expect(plot.valueAt(200.01), 4);
      expect(plot.valueAt(1e9), 5);
    });

    test('drops changes after the window', () {
      final plot = StepPlot.fromSeries(gear,
          axis: TraceAxis.time, window: const ChartViewport(195.82, 199.0));
      expect(plot.length, 2);
      expect(plot.values.last, 3);
    });

    test('collapses changes that clamp onto the same position', () {
      // Several shifts before the window opened all clamp to its edge; the
      // last is the one in force from there on.
      final busy = StepSeries.fromRows(
        const [(100.0, 2), (150.0, 3), (190.0, 6)],
        eventName: 'Gear',
      );
      final plot = StepPlot.fromSeries(busy,
          axis: TraceAxis.time, window: const ChartViewport(195.0, 260.0));
      expect(plot.length, 1);
      expect(plot.values.single, 6);
    });
  });
}
