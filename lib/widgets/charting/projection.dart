/// Projecting the recording's GPS channels into a drawable track shape
/// (SPEC.md §8.5).
///
/// ## The coordinates are local, not geographic
///
/// `GPS Latitude`/`GPS Longitude` are 10 Hz channels in degrees, and they are
/// **not** where the circuit is. Measured on the checked-in Sebring fixture
/// they sit at latitude 59.99996° and longitude ≈0 — the North Sea — while
/// Sebring is at 27.45°N, 81.35°W. The game emits a local frame dressed in
/// lat/lon units, so what these channels support is a *shape*, and never a
/// basemap, a real-world coordinate readout, or a distance to anywhere.
///
/// ## Why the cosine factor is not optional
///
/// A degree of longitude is a degree of latitude scaled by cos(latitude), so
/// a projection that treats the two alike stretches the map east-west. At the
/// fixture's latitude that factor is almost exactly ½, which makes the error
/// enormous rather than subtle, and the file carries its own ground truth to
/// prove it: `Lap Dist` measures the lap at 3080.7 m, and summing the
/// projected polyline over the same lap gives
///
/// - **5193.6 m** without the cosine — 69% too long, so the shape is wrong by
///   a factor, not by a rounding;
/// - **3043.3 m** with it — 1.1% short.
///
/// That remaining 1.1% is not a projection error and not polyline chording:
/// re-summing the same lap at every second sample changes the total by 1.1 m
/// (0.04%), so the segments are already straight enough that halving them
/// buys nothing. It is the driven line differing from the track path
/// `Lap Dist` is measured along — `Path Lateral` spans ±11 m on the same lap,
/// which is exactly the room a driver has to shorten a corner.
///
/// Only the *aspect ratio* is load-bearing for drawing a map, and that is
/// what the cosine fixes. The metre scale is carried anyway because it costs
/// one constant and makes the check above expressible in the unit the file
/// already reports.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// Metres per degree of latitude, spherical-Earth approximation.
///
/// Exact enough by a wide margin for a track a few kilometres across: the
/// ellipsoidal variation across a whole circuit is far below the 1.1%
/// line-versus-centreline difference measured above, and both are irrelevant
/// to a shape that gets scaled to fit a panel.
const metresPerDegreeLatitude = 111320.0;

/// A local metric frame for one recording's position channels.
class TrackProjection {
  TrackProjection._(this.originLatitude, this.originLongitude, this.points,
      this.boundsMetres);

  /// Projects parallel latitude/longitude arrays into metres.
  ///
  /// Both arrays come from 10 Hz channels riding the same master grid, so
  /// sample `i` of one is the same instant as sample `i` of the other (§5.1)
  /// — the pairing needs no join and no interpolation.
  factory TrackProjection.fromCoordinates(
    Float64List latitudes,
    Float64List longitudes,
  ) {
    final n = math.min(latitudes.length, longitudes.length);
    if (n == 0) {
      return TrackProjection._(0, 0, const [], Rect.zero);
    }

    var latSum = 0.0;
    var lonSum = 0.0;
    for (var i = 0; i < n; i++) {
      latSum += latitudes[i];
      lonSum += longitudes[i];
    }
    final originLat = latSum / n;
    final originLon = lonSum / n;
    final lonScale =
        metresPerDegreeLatitude * math.cos(originLat * math.pi / 180);

    final points = <Offset>[];
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (var i = 0; i < n; i++) {
      final x = (longitudes[i] - originLon) * lonScale;
      // Negated so north is up once the frame is drawn in screen coordinates,
      // where y grows downward. Doing it here rather than in the painter
      // keeps every consumer — hit-testing, bounds, fitting — in one frame.
      final y = -(latitudes[i] - originLat) * metresPerDegreeLatitude;
      points.add(Offset(x, y));
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    return TrackProjection._(
      originLat,
      originLon,
      points,
      Rect.fromLTRB(minX, minY, maxX, maxY),
    );
  }

  final double originLatitude;
  final double originLongitude;

  /// The path in metres east/south of the recording's own centroid.
  final List<Offset> points;

  /// Extent of [points]. Width and height are directly comparable because
  /// both are metres — which is the whole point of the cosine factor.
  final Rect boundsMetres;

  bool get isEmpty => points.isEmpty;

  /// Total driven length of the projected path.
  ///
  /// Exposed because it is the check that catches a broken projection: it
  /// should land within a couple of percent of the lap's `Lap Dist` span, and
  /// a missing cosine misses by ~69%.
  double get pathLengthMetres {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += (points[i] - points[i - 1]).distance;
    }
    return total;
  }

  /// The transform that fits [boundsMetres] into [target] without distorting
  /// the shape.
  ///
  /// Uniform scale on both axes, deliberately: a fit that stretched to fill
  /// would undo the cosine correction and reintroduce exactly the distortion
  /// this class exists to remove.
  TrackFit fitInto(Rect target, {double padding = 12}) {
    if (isEmpty || boundsMetres.width <= 0 && boundsMetres.height <= 0) {
      return const TrackFit(scale: 1, offset: Offset.zero);
    }
    final available = Size(
      math.max(target.width - padding * 2, 1),
      math.max(target.height - padding * 2, 1),
    );
    final scale = math.min(
      available.width / math.max(boundsMetres.width, 1e-6),
      available.height / math.max(boundsMetres.height, 1e-6),
    );
    final scaled = Size(boundsMetres.width * scale, boundsMetres.height * scale);
    final offset = Offset(
      target.left + (target.width - scaled.width) / 2 - boundsMetres.left * scale,
      target.top + (target.height - scaled.height) / 2 - boundsMetres.top * scale,
    );
    return TrackFit(scale: scale, offset: offset);
  }
}

/// A uniform metres→pixels mapping produced by [TrackProjection.fitInto].
class TrackFit {
  const TrackFit({required this.scale, required this.offset});

  final double scale;
  final Offset offset;

  Offset toPixels(Offset metres) => metres * scale + offset;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackFit && other.scale == scale && other.offset == offset);

  @override
  int get hashCode => Object.hash(scale, offset);
}
