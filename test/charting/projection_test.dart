// Track-map projection (SPEC.md §8.5).
//
// The cosine-of-latitude factor is the whole correctness question here, and
// it is checkable without a device: a synthetic circle of known radius has a
// known circumference, and dropping the factor at the fixture's latitude
// stretches it by a known amount. The same claim is checked against the real
// file — projected polyline length versus its own `Lap Dist` — in
// `integration_test/data_layer_test.dart`.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/projection.dart';

/// A circle of [radiusMetres] centred at [latitude], as the game would
/// report it in degrees.
///
/// Closed — the last point repeats the first — because [samples] chords span
/// a full circle only if the loop is closed, and a lap does come back to the
/// start/finish line. Leaving it open would lose exactly one chord, which at
/// 720 samples is 4.4 m of a 3.14 km circle and would read as a projection
/// error rather than as the missing segment it is.
(Float64List, Float64List) _circle({
  required double latitude,
  required double radiusMetres,
  int samples = 720,
}) {
  final metresPerLon =
      metresPerDegreeLatitude * math.cos(latitude * math.pi / 180);
  final lats = Float64List(samples + 1);
  final lons = Float64List(samples + 1);
  for (var i = 0; i <= samples; i++) {
    final angle = 2 * math.pi * i / samples;
    lats[i] = latitude + radiusMetres * math.sin(angle) / metresPerDegreeLatitude;
    lons[i] = radiusMetres * math.cos(angle) / metresPerLon;
  }
  return (lats, lons);
}

void main() {
  group('TrackProjection', () {
    // The checked-in fixture sits at latitude 59.99996° — the game emits a
    // local frame dressed in lat/lon units, not where Sebring actually is —
    // where the cosine factor is almost exactly one half.
    const fixtureLatitude = 59.99996;

    test('reproduces a known circumference', () {
      final (lats, lons) = _circle(latitude: fixtureLatitude, radiusMetres: 500);
      final projection = TrackProjection.fromCoordinates(lats, lons);
      // 720 chords around a circle fall a hair inside the arc.
      expect(projection.pathLengthMetres, closeTo(2 * math.pi * 500, 1));
    });

    test('a circle projects to a square bounding box, not a stretched one', () {
      // The failure the cosine prevents: without it a circuit at this latitude
      // comes out twice as wide as it is tall, and every corner is the wrong
      // shape.
      final (lats, lons) = _circle(latitude: fixtureLatitude, radiusMetres: 500);
      final bounds = TrackProjection.fromCoordinates(lats, lons).boundsMetres;
      expect(bounds.width, closeTo(1000, 1));
      expect(bounds.height, closeTo(1000, 1));
      expect(bounds.width / bounds.height, closeTo(1, 0.01));
    });

    test('the same coordinates read without the cosine are ~2x too wide', () {
      // Stated as a measurement rather than an assertion about our code: this
      // is what the naive projection would produce at this latitude, and it is
      // why the factor is not optional.
      final (lats, lons) = _circle(latitude: fixtureLatitude, radiusMetres: 500);
      var minLon = double.infinity;
      var maxLon = double.negativeInfinity;
      for (final lon in lons) {
        minLon = math.min(minLon, lon);
        maxLon = math.max(maxLon, lon);
      }
      final naiveWidth = (maxLon - minLon) * metresPerDegreeLatitude;
      expect(naiveWidth / 1000, closeTo(2, 0.01));
    });

    test('is empty rather than broken with no samples', () {
      final projection =
          TrackProjection.fromCoordinates(Float64List(0), Float64List(0));
      expect(projection.isEmpty, isTrue);
      expect(projection.boundsMetres, Rect.zero);
      expect(projection.pathLengthMetres, 0);
    });

    test('north is up once projected into screen coordinates', () {
      final projection = TrackProjection.fromCoordinates(
        Float64List.fromList([59.999, 60.001]),
        Float64List.fromList([0, 0]),
      );
      // The more northerly sample must have the smaller y.
      expect(projection.points.last.dy, lessThan(projection.points.first.dy));
    });
  });

  group('TrackFit', () {
    test('scales uniformly, so fitting never re-distorts the shape', () {
      // A fit that stretched to fill would undo the cosine correction, which
      // is the one thing the projection exists to get right.
      final (lats, lons) = _circle(latitude: 60, radiusMetres: 500);
      final projection = TrackProjection.fromCoordinates(lats, lons);
      final fit = projection.fitInto(const Rect.fromLTWH(0, 0, 900, 300));

      final drawn = [for (final p in projection.points) fit.toPixels(p)];
      var minX = double.infinity, maxX = double.negativeInfinity;
      var minY = double.infinity, maxY = double.negativeInfinity;
      for (final p in drawn) {
        minX = math.min(minX, p.dx);
        maxX = math.max(maxX, p.dx);
        minY = math.min(minY, p.dy);
        maxY = math.max(maxY, p.dy);
      }
      expect((maxX - minX) / (maxY - minY), closeTo(1, 0.01));
      // And it fits, centred, inside the panel.
      expect(minX, greaterThanOrEqualTo(0));
      expect(maxX, lessThanOrEqualTo(900));
      expect(minY, greaterThanOrEqualTo(0));
      expect(maxY, lessThanOrEqualTo(300));
    });

    test('fits a wide circuit to the width and a tall one to the height', () {
      final (lats, lons) = _circle(latitude: 60, radiusMetres: 500);
      final projection = TrackProjection.fromCoordinates(lats, lons);
      const padding = 18.0;
      final wide = projection.fitInto(const Rect.fromLTWH(0, 0, 400, 1000),
          padding: padding);
      expect(wide.scale * projection.boundsMetres.width,
          closeTo(400 - padding * 2, 1));
      final tall = projection.fitInto(const Rect.fromLTWH(0, 0, 1000, 400),
          padding: padding);
      expect(tall.scale * projection.boundsMetres.height,
          closeTo(400 - padding * 2, 1));
    });
  });
}
