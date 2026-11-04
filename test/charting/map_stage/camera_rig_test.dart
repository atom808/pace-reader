import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

void main() {
  const start = MapCamera(
    centre: Offset.zero,
    pixelsPerMetre: 1,
    focus: Offset(400, 300),
  );

  group('CameraRig', () {
    test('glides to its target without overshooting, and settles', () {
      final rig = CameraRig(initial: start)
        ..target = start.copyWith(centre: const Offset(200, 0));
      var last = 0.0;
      var t = 0.0;
      while (!rig.settled && t < 2) {
        rig.step(1 / 60);
        t += 1 / 60;
        final x = rig.current.centre.dx;
        expect(x, greaterThanOrEqualTo(last - 1e-9), reason: 'never backs up');
        expect(x, lessThanOrEqualTo(200 + 1e-6), reason: 'never overshoots');
        last = x;
      }
      expect(rig.settled, isTrue);
      expect(t, lessThan(1.2), reason: 'ω 14 settles in about a second');
      expect(rig.current, rig.target);
    });

    test('zooms in log space: in and out by 2× take the same time', () {
      double settleTime(double factor) {
        final rig = CameraRig(initial: start)
          ..target = start.copyWith(pixelsPerMetre: factor);
        var t = 0.0;
        while (!rig.settled) {
          rig.step(1 / 120);
          t += 1 / 120;
        }
        return t;
      }

      expect(settleTime(2), closeTo(settleTime(0.5), 1 / 60));
    });

    test('a late frame is stepped in small pieces, not one leap', () {
      final rig = CameraRig(initial: start)
        ..target = start.copyWith(centre: const Offset(500, 0));
      rig.step(0.2);
      expect(rig.current.centre.dx, inExclusiveRange(0, 500));
    });

    test('jumpTo lands at once and stops', () {
      final rig = CameraRig(initial: start);
      final there = start.copyWith(centre: const Offset(9, 9));
      rig.jumpTo(there);
      expect(rig.current, there);
      expect(rig.settled, isTrue);
    });
  });

  group('LowPass', () {
    test('takes the first sample as is', () {
      expect(LowPass().add(0.7, 1 / 60), 0.7);
    });

    test('covers 63 % of a step in one time constant', () {
      final filter = LowPass(seconds: 1.5)..add(0, 0);
      var value = 0.0;
      for (var i = 0; i < 90; i++) {
        value = filter.add(1, 1 / 60);
      }
      expect(value, closeTo(1 - math.exp(-1), 1e-6));
    });
  });
}
