// The shared cursor/viewport controller (SPEC.md §9.5, §9.7.6).
//
// Worth its own tests because what it gets wrong is invisible rather than
// loud: a cursor that lands a corner early after an axis toggle still looks
// like a cursor.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/decimation.dart';
import 'package:pace_reader/widgets/charting/sync/chart_sync.dart';
import 'package:pace_reader/widgets/charting/viewport.dart';

/// A lap where the car covers distance at a deliberately uneven rate: 500 m
/// in the first half of the time and 2500 m in the second. Proportional
/// rescaling and a real conversion disagree here by hundreds of metres, which
/// is the point.
DistanceAxis _unevenAxis() {
  const n = 101;
  final times = Float64List(n);
  final distances = Float64List(n);
  for (var i = 0; i < n; i++) {
    final fraction = i / (n - 1);
    times[i] = 100 + fraction * 60;
    distances[i] =
        fraction <= 0.5 ? 1000 * fraction : 500 + 5000 * (fraction - 0.5);
  }
  return DistanceAxis.fromSeries(TraceSeries(
    channelName: 'Lap Dist',
    unit: 'm',
    frequencyHz: 10,
    valueColumn: 'value',
    times: times,
    lows: distances,
    highs: distances,
  ));
}

void main() {
  late ProviderContainer container;
  ChartSync sync() => container.read(chartSyncProvider.notifier);
  ChartSyncState state() => container.read(chartSyncProvider);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  const bounds = ChartViewport(100, 160);

  test('starts on the distance axis, unzoomed, with no cursor', () {
    // Distance by default: it is the axis that makes two laps comparable,
    // which is what a trace view is for (§8.4).
    expect(state().axis, TraceAxis.distance);
    expect(state().isZoomed, isFalse);
    expect(state().cursor, isNull);
    expect(state().visible(bounds), bounds);
  });

  test('a null viewport means the whole lap, whatever the lap is', () {
    // The extent lives with the data, not here, so nothing has to be pushed
    // into this controller when a lap finishes loading.
    expect(state().visible(const ChartViewport(0, 10)),
        const ChartViewport(0, 10));
    expect(state().visible(const ChartViewport(-5, 4000)),
        const ChartViewport(-5, 4000));
  });

  test('zooming back out to the full lap clears the stored window', () {
    sync().zoomAround(130, 0.4, bounds: bounds);
    expect(state().isZoomed, isTrue);
    sync().zoomAround(130, 100, bounds: bounds);
    expect(state().isZoomed, isFalse,
        reason: 'a viewport equal to its bounds is "not zoomed"');
  });

  test('panning does nothing while the whole lap is shown', () {
    sync().panBy(10, bounds: bounds);
    expect(state().isZoomed, isFalse);
  });

  test('resetting the viewport keeps the cursor', () {
    // Zooming out is a framing change, not a change of what is being
    // inspected.
    sync().setCursor(123.5);
    sync().zoomAround(123.5, 0.3, bounds: bounds);
    sync().resetViewport();
    expect(state().isZoomed, isFalse);
    expect(state().cursor, 123.5);
  });

  test('new data drops the cursor but keeps the axis choice', () {
    sync().setAxis(TraceAxis.time);
    sync().setCursor(140);
    sync().zoomAround(140, 0.5, bounds: bounds);
    sync().resetForNewData();
    expect(state().cursor, isNull);
    expect(state().isZoomed, isFalse);
    expect(state().axis, TraceAxis.time,
        reason: 'the user picked an axis; a new lap is not a reason to undo it');
  });

  group('axis toggle', () {
    test('carries the cursor to the same point of the lap', () {
      final axis = _unevenAxis();
      sync().setAxis(TraceAxis.time, distanceAxis: axis);
      sync().setCursor(130); // exactly half way through the lap in time
      sync().setAxis(TraceAxis.distance, distanceAxis: axis);

      // Half the time is 500 m into a 3000 m lap here, not 1500 m. A
      // proportional rescale would put the cursor a kilometre away, in
      // exactly the corners a user is looking at when they toggle.
      expect(state().cursor, closeTo(500, 1));
      expect(state().cursor, isNot(closeTo(1500, 100)));
    });

    test('round-trips the cursor back to where it started', () {
      final axis = _unevenAxis();
      sync().setAxis(TraceAxis.time, distanceAxis: axis);
      sync().setCursor(141.3);
      sync().setAxis(TraceAxis.distance, distanceAxis: axis);
      sync().setAxis(TraceAxis.time, distanceAxis: axis);
      expect(state().cursor, closeTo(141.3, 0.01));
    });

    test('carries a zoom window across too', () {
      final axis = _unevenAxis();
      sync().setAxis(TraceAxis.time, distanceAxis: axis);
      sync().zoomAround(145, 0.25, bounds: bounds);
      final before = state().viewport!;
      sync().setAxis(TraceAxis.distance, distanceAxis: axis);
      final after = state().viewport!;
      expect(after.start, closeTo(axis.distanceAt(before.start), 1));
      expect(after.end, closeTo(axis.distanceAt(before.end), 1));
    });

    test('resets cleanly when the lap has no usable distance axis', () {
      // The garage lap: there is no correct conversion to make, so pretending
      // to make one would be worse than re-framing.
      sync().setCursor(130);
      sync().zoomAround(130, 0.5, bounds: bounds);
      sync().setAxis(TraceAxis.time, distanceAxis: null);
      expect(state().axis, TraceAxis.time);
      expect(state().cursor, isNull);
      expect(state().isZoomed, isFalse);
    });

    test('toggling to the axis already shown changes nothing', () {
      sync().setCursor(130);
      sync().setAxis(TraceAxis.distance, distanceAxis: _unevenAxis());
      expect(state().cursor, 130);
    });
  });

  // Whose lap the cursor is on (comparison proposal §9): with Compare, Trace
  // and Compare can show different laps, and a window on one is meaningless
  // on the other's clock.
  group('owners', () {
    test('a new owner starts from the whole lap, keeping only the axis', () {
      sync().claim('lap A');
      sync().setAxis(TraceAxis.time);
      sync().setCursor(130);
      sync().zoomAround(130, 0.5, bounds: bounds);

      sync().claim('lap B');
      expect(state().owner, 'lap B');
      expect(state().axis, TraceAxis.time);
      expect(state().cursor, isNull);
      expect(state().isZoomed, isFalse);
    });

    test('a repeat claim by the owner changes nothing', () {
      // Trace and the track map claim the same lap, so moving between them
      // keeps the zoom and the cursor, as it always has.
      sync().claim('lap A');
      sync().setCursor(130);
      sync().zoomAround(130, 0.5, bounds: bounds);
      final before = state();
      sync().claim('lap A');
      expect(identical(state(), before), isTrue);
    });

    test('every operation keeps the owner', () {
      sync().claim('lap A');
      sync().setCursor(130);
      sync().zoomAround(130, 0.5, bounds: bounds);
      sync().panBy(5, bounds: bounds);
      sync().resetViewport();
      sync().showWindow(const ChartViewport(110, 120), bounds: bounds);
      sync().setAxis(TraceAxis.time, distanceAxis: _unevenAxis());
      sync().resetForNewData();
      expect(state().owner, 'lap A');
    });

    test('another owner\'s widgets see the axis alone', () {
      sync().claim('lap A');
      sync().setCursor(130);
      sync().zoomAround(130, 0.5, bounds: bounds);

      final mine = state().seenBy('lap A');
      expect(mine.cursor, 130);
      expect(mine.isZoomed, isTrue);
      // A widget outside any owner sees the state as it is.
      expect(identical(state().seenBy(null), state()), isTrue);

      final theirs = state().seenBy('lap B');
      expect(theirs.axis, state().axis);
      expect(theirs.cursor, isNull);
      expect(theirs.viewport, isNull);
    });
  });

  group('showWindow', () {
    test('shows the window it is given', () {
      sync().showWindow(const ChartViewport(110, 120), bounds: bounds);
      expect(state().viewport, const ChartViewport(110, 120));
    });

    test('slides a window that overhangs an edge back inside', () {
      sync().showWindow(const ChartViewport(150, 170), bounds: bounds);
      expect(state().viewport, const ChartViewport(140, 160));
      sync().showWindow(const ChartViewport(90, 95), bounds: bounds);
      expect(state().viewport, const ChartViewport(100, 105));
    });

    test('a window as wide as the lap is the whole lap', () {
      sync().showWindow(const ChartViewport(110, 120), bounds: bounds);
      sync().showWindow(const ChartViewport(80, 200), bounds: bounds);
      expect(state().isZoomed, isFalse);
    });

    test('keeps the cursor', () {
      sync().setCursor(130);
      sync().showWindow(const ChartViewport(110, 120), bounds: bounds);
      expect(state().cursor, 130);
    });
  });
}
