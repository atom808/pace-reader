/// How the car moves along a [TrackPath]: its speed and heading at any
/// point, which the camera's look-ahead and speed-linked zoom read, and the
/// car glyph turns by (map stage proposal §4).
///
/// Derived from the path itself — positions over the recording's clock —
/// rather than from `Ground Speed`, so the stage needs nothing the path
/// does not carry.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../track_path.dart';

class PathKinematics {
  PathKinematics._(this._path, this._speeds, this.minSpeed, this.maxSpeed);

  factory PathKinematics.of(TrackPath path) {
    final n = path.length;
    final speeds = Float64List(n);
    final seconds = path.seconds;
    final points = path.projection.points;
    if (seconds != null && n > 1) {
      for (var i = 0; i < n; i++) {
        // Over two samples either side: one 10 Hz step of GPS is noisy
        // enough to flicker the zoom on its own.
        final a = math.max(i - 2, 0);
        final b = math.min(i + 2, n - 1);
        final dt = seconds[b] - seconds[a];
        speeds[i] = dt <= 0 ? 0 : (points[b] - points[a]).distance / dt;
      }
    }
    var low = double.infinity;
    var high = 0.0;
    for (final s in speeds) {
      low = math.min(low, s);
      high = math.max(high, s);
    }
    return PathKinematics._(path, speeds, low.isFinite ? low : 0, high);
  }

  final TrackPath _path;
  final Float64List _speeds;

  /// The lap's slowest and fastest, in metres per second.
  final double minSpeed;
  final double maxSpeed;

  bool get hasSpeed => maxSpeed > 0;

  /// Metres per second at fractional point [index].
  double speedAt(double index) {
    if (_speeds.isEmpty) return 0;
    final i = index.clamp(0, _speeds.length - 1).toDouble();
    final low = i.floor();
    final high = math.min(low + 1, _speeds.length - 1);
    return _speeds[low] + (_speeds[high] - _speeds[low]) * (i - low);
  }

  /// Where [metresPerSecond] sits in the lap's range: 0 its slowest, 1 its
  /// fastest.
  double speedFraction(double metresPerSecond) {
    final span = maxSpeed - minSpeed;
    if (span <= 0) return 0.5;
    return ((metresPerSecond - minSpeed) / span).clamp(0.0, 1.0);
  }

  /// The direction of travel at fractional point [index], as a unit vector
  /// in the map's metres: along the chord between the points about
  /// [reach] metres either side, so a GPS wobble does not twitch the car.
  Offset headingAt(double index, {double reach = 4}) {
    final points = _path.projection.points;
    final n = points.length;
    if (n < 2) return const Offset(1, 0);
    final i = index.clamp(0, n - 1).toDouble();
    final at = _pointAt(points, i);
    var back = i.floor();
    while (back > 0 && (points[back] - at).distance < reach) {
      back--;
    }
    var ahead = math.min(i.ceil(), n - 1);
    while (ahead < n - 1 && (points[ahead] - at).distance < reach) {
      ahead++;
    }
    final chord = points[ahead] - points[back];
    return chord.distance < 1e-9 ? const Offset(1, 0) : chord / chord.distance;
  }

  static Offset _pointAt(List<Offset> points, double i) {
    final low = i.floor();
    final high = math.min(low + 1, points.length - 1);
    return Offset.lerp(points[low], points[high], i - low)!;
  }
}

/// The fractional point index at domain position [x]: between the two
/// points either side; null off the path's span.
double? indexAtDomain(TrackPath path, double x) => _fractional(path.xs, x);

/// The fractional point index at `Lap Dist` [station], for the ghost; null
/// without stations or off their span.
double? indexAtStation(TrackPath path, double station) =>
    _fractional(path.stations, station);

/// The domain position at fractional point [index]: where a hit on the
/// line puts the playhead.
double domainAtIndex(TrackPath path, double index) {
  final xs = path.xs;
  final i = index.clamp(0, xs.length - 1).toDouble();
  final low = i.floor();
  final high = math.min(low + 1, xs.length - 1);
  return xs[low] + (xs[high] - xs[low]) * (i - low);
}

/// Where [value] falls along [keys], which run forwards, as a fractional
/// index; null off their span.
double? _fractional(Float64List? keys, double value) {
  if (keys == null || keys.isEmpty) return null;
  if (value.isNaN || value < keys.first || value > keys.last) return null;
  var low = 0;
  var high = keys.length - 1;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (keys[mid] >= value) {
      high = mid;
    } else {
      low = mid + 1;
    }
  }
  if (low == 0) return 0;
  final gap = keys[low] - keys[low - 1];
  return gap <= 0 ? low.toDouble() : low - 1 + (value - keys[low - 1]) / gap;
}

/// The position at fractional point [index], in metres.
Offset positionAtIndex(TrackPath path, double index) =>
    PathKinematics._pointAt(path.projection.points, index);
