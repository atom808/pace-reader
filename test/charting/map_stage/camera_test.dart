import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

void main() {
  const camera = MapCamera(
    centre: Offset(100, -50),
    pixelsPerMetre: 2,
    focus: Offset(400, 300),
  );

  group('MapCamera', () {
    test('puts the centre at the focus, and back', () {
      expect(camera.toScreen(const Offset(100, -50)), const Offset(400, 300));
      const p = Offset(137.5, 12.25);
      final back = camera.toMetres(camera.toScreen(p));
      expect((back - p).distance, lessThan(1e-9));
    });

    test('zooming about a pixel keeps the metres under it', () {
      const pointer = Offset(650, 120);
      final under = camera.toMetres(pointer);
      final zoomed = camera.zoomedAbout(pointer, 1.7);
      expect(zoomed.pixelsPerMetre, closeTo(3.4, 1e-12));
      expect((zoomed.toScreen(under) - pointer).distance, lessThan(1e-9));
    });

    test('a drag moves the map with the pointer', () {
      const grab = Offset(500, 400);
      final under = camera.toMetres(grab);
      final moved = camera.pannedBy(const Offset(30, -12));
      expect(
        (moved.toScreen(under) - (grab + const Offset(30, -12))).distance,
        lessThan(1e-9),
      );
    });

    test('fit shows all of a rect inside the padded viewport', () {
      const lap = Rect.fromLTRB(-600, -300, 600, 300);
      const view = Rect.fromLTWH(0, 0, 800, 600);
      final fit = MapCamera.fit(lap, view, padding: 24);
      final shown = fit.visibleMetres(view.size);
      expect(shown.contains(lap.topLeft), isTrue);
      expect(shown.contains(lap.bottomRight), isTrue);
      // Width-limited: the lap fills the padded width exactly.
      expect(fit.pixelsPerMetre * lap.width, closeTo(800 - 48, 1e-9));
      expect(fit.toScreen(lap.center), view.center);
    });
  });

  group('look-ahead', () {
    test('is 0.6 s of travel along the heading', () {
      final ahead = lookAhead(
        heading: const Offset(0, -2),
        metresPerSecond: 40,
        viewMetres: 1000,
      );
      expect(ahead.dx, closeTo(0, 1e-12));
      expect(ahead.dy, closeTo(-24, 1e-12));
    });

    test('never more than a quarter of the view, so the car stays on it', () {
      final ahead = lookAhead(
        heading: const Offset(1, 0),
        metresPerSecond: 92,
        viewMetres: 120,
      );
      expect(ahead.distance, closeTo(30, 1e-12));
    });

    test('nothing when stopped', () {
      expect(
        lookAhead(
          heading: const Offset(1, 0),
          metresPerSecond: 0,
          viewMetres: 99,
        ),
        Offset.zero,
      );
    });
  });

  group('speed zoom', () {
    test('breathes ±12 % and no more (D11)', () {
      expect(speedZoomFactor(0), closeTo(1.12, 1e-12));
      expect(speedZoomFactor(1), closeTo(0.88, 1e-12));
      expect(speedZoomFactor(0.5), closeTo(1, 1e-12));
      for (final f in [-3.0, -0.1, 0.3, 0.9, 1.4, 50.0]) {
        final z = speedZoomFactor(f);
        expect(z, inInclusiveRange(0.88, 1.12), reason: '$f');
      }
    });

    test('the closest zoom shows a 5 m car at a sixth of the height', () {
      final ppm = maxPixelsPerMetre(const Size(1000, 600));
      expect(5 * ppm, closeTo(100, 1e-9));
      expect(math.max(ppm, 0), greaterThan(0));
    });
  });
}
