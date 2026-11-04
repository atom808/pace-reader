import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/map_stage/path_hit_test.dart';

/// A straight from [from] to [to] sampled every [step] metres.
List<Offset> _line(Offset from, Offset to, {double step = 5}) {
  final n = ((to - from).distance / step).ceil();
  return [for (var i = 0; i <= n; i++) Offset.lerp(from, to, i / n)!];
}

void main() {
  group('PathHitIndex', () {
    test('lands between samples, not on the nearest vertex', () {
      // 300 km/h at 10 Hz: 8.3 m between samples.
      final index = PathHitIndex([
        const Offset(0, 0),
        const Offset(8.3, 0),
        const Offset(16.6, 0),
      ]);
      final hit = index.nearest(const Offset(4, 1), radius: 5)!;
      expect(hit.index, closeTo(4 / 8.3, 1e-9));
      expect(hit.point.dx, closeTo(4, 1e-9));
      expect(hit.distance, closeTo(1, 1e-9));
    });

    test('misses outside the radius', () {
      final index = PathHitIndex(_line(Offset.zero, const Offset(100, 0)));
      expect(index.nearest(const Offset(50, 30), radius: 20), isNull);
    });

    test('a figure-eight crossing keeps to the leg the playhead is on', () {
      // Two legs through the origin: index 0–40 runs west→east, then a loop,
      // then 80+ runs south→north through the same point.
      final points = [
        ..._line(const Offset(-100, 0), const Offset(100, 0)),
        for (var a = 0; a <= 20; a++)
          Offset(
            100 + 50 * math.sin(a * math.pi / 20),
            -50 + 50 * math.cos(a * math.pi / 20),
          ),
        ..._line(const Offset(100, -100), const Offset(0, -100)),
        ..._line(const Offset(0, -100), const Offset(0, 100)),
      ];
      final index = PathHitIndex(points);
      final onEastWest = 20.0; // the origin on the first leg
      final hitA = index.nearest(
        const Offset(0.5, 0.4),
        radius: 10,
        near: onEastWest - 1,
        tieMetres: 3,
      )!;
      expect(hitA.index, closeTo(20, 0.5));

      final northSouthStart = points.length - 41.0;
      final hitB = index.nearest(
        const Offset(0.5, 0.4),
        radius: 10,
        near: northSouthStart + 19,
        tieMetres: 3,
      )!;
      expect(hitB.index, greaterThan(northSouthStart));
      expect(hitB.point.dx, closeTo(0, 1e-9));
    });

    test('a hairpin picks the nearer leg when it is clearly nearer', () {
      final points = [
        ..._line(Offset.zero, const Offset(200, 0)),
        ..._line(const Offset(200, 8), const Offset(0, 8)),
      ];
      final index = PathHitIndex(points);
      // 2 m from the second leg, 6 m from the first: no tie at 3 m.
      final hit = index.nearest(
        const Offset(100, 6),
        radius: 10,
        near: 10,
        tieMetres: 3,
      )!;
      expect(hit.point.dy, 8);
    });

    test('a hairpin keeps the playhead leg when both are nearly as close', () {
      final points = [
        ..._line(Offset.zero, const Offset(200, 0)),
        ..._line(const Offset(200, 8), const Offset(0, 8)),
      ];
      final index = PathHitIndex(points);
      // 3.5 m from the first leg, 4.5 m from the second: within the 3 m tie.
      final first = index.nearest(
        const Offset(100, 3.5),
        radius: 10,
        near: 20,
        tieMetres: 3,
      )!;
      expect(first.point.dy, 0);
      final second = index.nearest(
        const Offset(100, 3.5),
        radius: 10,
        near: 60,
        tieMetres: 3,
      )!;
      expect(second.point.dy, 8);
    });

    test('a long lap answers from nearby cells only', () {
      // 13.6 km at Le Mans' 10 Hz density: ~2,700 segments.
      final points = _line(Offset.zero, const Offset(13600, 0));
      final index = PathHitIndex(points);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        index.nearest(Offset(i * 13.0, 2), radius: 10);
      }
      // 1,000 hovers well inside one frame's budget.
      expect(watch.elapsedMilliseconds, lessThan(16));
    });
  });
}
