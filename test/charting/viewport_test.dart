// Viewport and axis arithmetic (SPEC.md §9.5).
//
// This is the layer every synced chart and the track map share, and it is
// pure Dart precisely so it can be checked here rather than by eye in a
// running app — the same split the data layer makes between its SQL builders
// and its integration tests.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/viewport.dart';

void main() {
  group('ChartViewport', () {
    const bounds = ChartViewport(100, 200);

    test('maps domain to pixels and back', () {
      const viewport = ChartViewport(0, 10);
      expect(viewport.toPixels(5, 400), 200);
      expect(viewport.toDomain(200, 400), 5);
      expect(viewport.toDomain(viewport.toPixels(7.25, 913), 913),
          closeTo(7.25, 1e-9));
    });

    test('zooming keeps the value under the pointer under the pointer', () {
      // The whole point of zooming about a focus: a user zooms into the
      // corner they are looking at, not into the middle of the panel.
      const viewport = ChartViewport(0, 100);
      final zoomed = viewport.zoomedAround(25, 0.5,
          bounds: const ChartViewport(0, 100));
      expect(zoomed.span, closeTo(50, 1e-9));
      expect(zoomed.normalize(25), closeTo(viewport.normalize(25), 1e-9));
    });

    test('never zooms out past its bounds', () {
      final out = const ChartViewport(120, 180)
          .zoomedAround(150, 10, bounds: bounds);
      expect(out, bounds);
    });

    test('never collapses to a point, however hard the wheel is spun', () {
      var viewport = bounds;
      for (var i = 0; i < 200; i++) {
        viewport = viewport.zoomedAround(150, 0.5, bounds: bounds);
      }
      expect(viewport.span, greaterThan(0));
      // Still recoverable: one zoom-out step must widen it again.
      expect(viewport.zoomedAround(150, 2, bounds: bounds).span,
          greaterThan(viewport.span));
    });

    test('panning slides rather than clips at an edge', () {
      // Clipping would silently change the zoom level mid-drag, so a pan that
      // hit the end of the lap and came back would not return where it began.
      const viewport = ChartViewport(110, 130);
      final panned = viewport.pannedBy(-50, bounds: bounds);
      expect(panned.span, closeTo(viewport.span, 1e-9));
      expect(panned.start, 100);

      final other = viewport.pannedBy(500, bounds: bounds);
      expect(other.span, closeTo(viewport.span, 1e-9));
      expect(other.end, 200);
    });

    test('a window wider than its bounds is replaced by them', () {
      expect(const ChartViewport(0, 1000).slidInside(bounds), bounds);
    });

    test('reports how far it is zoomed in', () {
      expect(bounds.zoomFactorWithin(bounds), closeTo(1, 1e-9));
      expect(const ChartViewport(100, 125).zoomFactorWithin(bounds),
          closeTo(4, 1e-9));
    });
  });

  group('ValueRange', () {
    test('ignores NaN and infinity rather than poisoning the range', () {
      // A degenerate query result must not make an axis unreadable — §10 wants
      // bad data visible, and an axis running to infinity shows nothing at all.
      final range = ValueRange.ofAll([1, double.nan, 5, double.infinity, -2]);
      expect(range, const ValueRange(-2, 5));
      expect(ValueRange.ofAll(const []), isNull);
    });

    test('pads a flat series with an absolute amount, not a proportion', () {
      // §5.4/§8.7 make a flat channel a real case: SoC is all-zero in every
      // GT3 file. A proportional pad of zero span stays zero and yields a
      // degenerate scale.
      final flat = const ValueRange(0, 0).padded();
      expect(flat.span, greaterThan(0));
      expect(flat.min, lessThan(0));
      expect(flat.max, greaterThan(0));
    });

    test('ticks land on round numbers a reader can name', () {
      expect(const ValueRange(0, 100).ticks(target: 4), [0, 25, 50, 75, 100]);
      expect(const ValueRange(0, 1).ticks(target: 4), [0, 0.25, 0.5, 0.75, 1]);
      // No float dust: a tick must print as 0.3, not 0.30000000000000004.
      for (final tick in const ValueRange(0, 1.5).ticks(target: 5)) {
        expect(tick.toString().length, lessThan(6), reason: '$tick');
      }
    });

    test('ticks stay inside the range', () {
      final range = const ValueRange(-23.77, 51.32);
      for (final tick in range.ticks()) {
        expect(tick, greaterThanOrEqualTo(range.min));
        expect(tick, lessThanOrEqualTo(range.max));
      }
    });

    test('never emits negative zero, which would render as "-0"', () {
      // Real ranges cross zero constantly — brake and throttle sit on it,
      // steering straddles it — so this shows up on most panels or none.
      for (final range in [
        const ValueRange(-6, 106),
        const ValueRange(-28.3, 55.8),
        const ValueRange(-1.2, 2.4),
      ]) {
        for (final tick in range.ticks()) {
          expect(tick.toStringAsFixed(1), isNot(startsWith('-0.0')));
        }
      }
    });

    test('a zero-span range normalizes to the middle instead of dividing by zero',
        () {
      expect(const ValueRange(5, 5).normalize(5), 0.5);
    });
  });
}
