import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

/// A lap that covers its first 1000 m at 10 m/s and its last 1000 m at
/// 50 m/s, from t = 100 s: slow, then fast.
DistanceAxis _lap() {
  final times = <double>[];
  final metres = <double>[];
  for (var t = 0.0; t <= 120; t += 0.1) {
    times.add(100 + t);
    metres.add(t <= 100 ? t * 10 : 1000 + (t - 100) * 50);
  }
  return DistanceAxis.fromSeries(
    TraceSeries(
      channelName: 'Lap Dist',
      unit: 'm',
      frequencyHz: 10,
      valueColumn: 'value',
      times: Float64List.fromList(times),
      lows: Float64List.fromList(metres),
      highs: Float64List.fromList(metres),
    ),
  );
}

void main() {
  const lap = ChartViewport(0, 2000);

  group('advancePlayhead', () {
    test('steps in lap time, so the car keeps its real pace on Distance', () {
      final axis = _lap();
      final slow = advancePlayhead(
        playhead: 500,
        seconds: 1,
        rate: 1,
        axis: TraceAxis.distance,
        distanceAxis: axis,
        range: lap,
      );
      final fast = advancePlayhead(
        playhead: 1500,
        seconds: 1,
        rate: 1,
        axis: TraceAxis.distance,
        distanceAxis: axis,
        range: lap,
      );
      expect(slow.playhead, closeTo(510, 0.5));
      expect(fast.playhead, closeTo(1550, 0.5));
    });

    test('on Time it is the clock times the rate', () {
      final step = advancePlayhead(
        playhead: 130,
        seconds: 0.5,
        rate: 4,
        axis: TraceAxis.time,
        range: const ChartViewport(100, 220),
      );
      expect(step.playhead, closeTo(132, 1e-9));
    });

    test('starts at the beginning when there is no playhead, or it is '
        'outside the range', () {
      for (final at in [null, -5.0, 2400.0]) {
        final step = advancePlayhead(
          playhead: at,
          seconds: 0.016,
          rate: 1,
          axis: TraceAxis.time,
          range: const ChartViewport(40, 60),
        );
        expect(step.playhead, 40, reason: '$at');
        expect(step.ended, isFalse);
      }
    });

    test('stops at the end, or wraps when looping', () {
      const window = ChartViewport(100, 110);
      final stop = advancePlayhead(
        playhead: 109.9,
        seconds: 1,
        rate: 1,
        axis: TraceAxis.time,
        range: window,
      );
      expect(stop, (playhead: 110.0, ended: true));
      final wrap = advancePlayhead(
        playhead: 109.9,
        seconds: 1,
        rate: 1,
        axis: TraceAxis.time,
        range: window,
        loop: true,
      );
      expect(wrap, (playhead: 100.0, ended: false));
    });
  });

  group('keepUpWindow', () {
    const window = ChartViewport(400, 600);

    test('leaves the window alone while the playhead is well inside it', () {
      expect(keepUpWindow(window: window, bounds: lap, playhead: 560), isNull);
    });

    test('past 85 % it slides on, putting the playhead at 30 %', () {
      final next = keepUpWindow(window: window, bounds: lap, playhead: 580)!;
      expect(next.span, window.span);
      expect(next.normalize(580), closeTo(0.3, 1e-9));
    });

    test('never past the end of the lap, and never for the whole lap', () {
      final next = keepUpWindow(
        window: const ChartViewport(1800, 2000),
        bounds: lap,
        playhead: 1990,
      );
      expect(next, isNull);
      expect(keepUpWindow(window: lap, bounds: lap, playhead: 1990), isNull);
    });
  });

  group('PlaybackController', () {
    test('the rate chip cycles through ×4 and round to slow motion', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playbackProvider.notifier);
      final rates = <double>[];
      for (var i = 0; i < playbackRates.length; i++) {
        controller.cycleRate();
        rates.add(container.read(playbackProvider).rate);
      }
      expect(rates, [2.0, 4.0, 0.25, 0.5, 1.0]);
    });

    test('plays, pauses and loops', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(playbackProvider.notifier)
        ..toggle()
        ..setLoop(true);
      expect(
        container.read(playbackProvider),
        const PlaybackState(playing: true, loop: true),
      );
      controller.pause();
      expect(container.read(playbackProvider).playing, isFalse);
    });
  });

  group('TraceTab', () {
    test('a tab shows only when the lap carries a channel it needs', () {
      const tyres = TraceTab(
        id: 'tyres',
        label: 'Tyres',
        icon: Icons.tire_repair,
        guard: ChannelGuard.anyOf({'TyresPressure'}, reason: 'No tyres'),
      );
      const inputs = TraceTab(id: 'inputs', label: 'Inputs', icon: Icons.tune);
      expect(admittedTabs([inputs, tyres], {'Ground Speed'}), [inputs]);
      expect(admittedTabs([inputs, tyres], {'TyresPressure'}), [inputs, tyres]);
    });
  });
}
