/// The render-ready track map payload (SPEC.md §8.5).
///
/// The map's counterpart to `TracePlot`: a projected path plus, per point,
/// the value colouring it and the domain position that ties it to the trace
/// panels' shared cursor. Building all three together is what makes the
/// cursor genuinely shared — the map and the panels index the same axis, so
/// there is no second alignment to keep in step.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../data/models/models.dart';
import 'decimation.dart';
import 'projection.dart';
import 'viewport.dart';

class TrackPath {
  TrackPath({
    required this.projection,
    required this.xs,
    required this.values,
    required this.valueRange,
    required this.valueLabel,
    required this.valueUnit,
    this.stations,
  });

  /// Builds a path from the position channels of one lap.
  ///
  /// [latitude] and [longitude] are full-resolution reads of two 10 Hz
  /// channels, so sample `i` of each is the same instant (§5.1) and the pair
  /// needs no join. [colorBy] is any channel already projected onto [axis];
  /// its value is sampled at each position point rather than the other way
  /// round, because the map has an order of magnitude fewer points than a
  /// 100 Hz trace and resampling toward the coarser side is the cheap
  /// direction.
  ///
  /// A second lap drawn on the same map — Compare's Target — passes the
  /// first's [origin], so both share one frame, and its [timeShift], which
  /// places it on the first lap's clock as its traces are (comparison
  /// proposal §6). On the Distance axis it is placed by its own
  /// [distanceAxis], as its traces are.
  factory TrackPath.build({
    required TraceSeries latitude,
    required TraceSeries longitude,
    required TraceAxis axis,
    DistanceAxis? distanceAxis,
    TracePlot? colorBy,
    ({double latitude, double longitude})? origin,
    double timeShift = 0,
  }) {
    final projection = TrackProjection.fromCoordinates(
      Float64List.fromList(latitude.lows),
      Float64List.fromList(longitude.lows),
      origin: origin,
    );

    final n = projection.points.length;
    final xs = Float64List(n);
    final values = Float64List(n);
    final stations = distanceAxis == null ? null : Float64List(n);
    final useDistance = axis == TraceAxis.distance && distanceAxis != null;
    for (var i = 0; i < n; i++) {
      final seconds = latitude.times[i];
      final station = distanceAxis?.distanceAt(seconds);
      stations?[i] = station!;
      xs[i] = useDistance ? station! : seconds + timeShift;
      values[i] = colorBy?.valueAt(xs[i]) ?? 0;
    }

    return TrackPath(
      projection: projection,
      xs: xs,
      values: values,
      // The colouring scale comes from the channel's own extent over the lap,
      // not from the sampled points: a lap's true peak can fall between two
      // 10 Hz position samples, and a scale that missed it would paint the
      // fastest point of the lap as merely fast.
      valueRange: colorBy?.valueRange ?? const ValueRange(0, 1),
      valueLabel: colorBy?.label ?? '',
      valueUnit: colorBy?.unit ?? '',
      stations: stations,
    );
  }

  final TrackProjection projection;

  /// Domain position per point, on whichever axis the charts are showing.
  final Float64List xs;

  /// Colouring value per point.
  final Float64List values;

  final ValueRange valueRange;
  final String valueLabel;
  final String valueUnit;

  /// `Lap Dist` per point, whichever axis the charts show; null for a lap
  /// without a distance axis. What places a stretch of the lap on the map —
  /// a segment's casing, its fit — and what marks a lap by distance on
  /// another lap's line.
  final Float64List? stations;

  int get length => projection.points.length;
  bool get isEmpty => length == 0;
  bool get hasColouring => valueLabel.isNotEmpty;

  /// Index of the point nearest domain position [x] — how the shared cursor
  /// finds the car on the map.
  int nearestIndex(double x) {
    if (isEmpty) return -1;
    if (x <= xs.first) return 0;
    if (x >= xs.last) return length - 1;
    var low = 0;
    var high = length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (xs[mid] < x) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low > 0 && (x - xs[low - 1]).abs() <= (xs[low] - x).abs()) {
      return low - 1;
    }
    return low;
  }

  /// The position, in metres, at domain position [x], interpolated between
  /// the two points either side; null outside the path's own span, where
  /// the lap was not yet, or no longer, on it.
  Offset? positionAt(double x) => _interpolate(xs, x);

  /// The position at `Lap Dist` [station]: the first time the lap reached
  /// it, interpolated. Null without [stations], or off the lap's span.
  Offset? positionAtStation(double station) {
    final s = stations;
    return s == null ? null : _interpolate(s, station);
  }

  /// The extent of the points whose `Lap Dist` lies in [from]–[to], with
  /// the positions at both ends; null when none do.
  Rect? boundsBetweenStations(double from, double to) {
    final s = stations;
    if (s == null) return null;
    return _boundsWhere((i) => s[i] >= from && s[i] <= to, [
      positionAtStation(from),
      positionAtStation(to),
    ]);
  }

  /// The extent of the points whose domain position lies in [from]–[to],
  /// with the positions at both ends; null when none do.
  Rect? boundsBetween(double from, double to) => _boundsWhere(
    (i) => xs[i] >= from && xs[i] <= to,
    [positionAt(from), positionAt(to)],
  );

  Rect? _boundsWhere(bool Function(int) inside, List<Offset?> ends) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    void add(Offset p) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }

    final points = projection.points;
    for (var i = 0; i < length; i++) {
      if (inside(i)) add(points[i]);
    }
    for (final end in ends) {
      if (end != null) add(end);
    }
    return minX.isFinite ? Rect.fromLTRB(minX, minY, maxX, maxY) : null;
  }

  /// The point at [value] along [keys], which run forwards: interpolated
  /// between the first pair that brackets it.
  Offset? _interpolate(Float64List keys, double value) {
    final n = math.min(keys.length, length);
    if (n == 0 || value.isNaN || value < keys.first || value > keys[n - 1]) {
      return null;
    }
    var low = 0;
    var high = n - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (keys[mid] >= value) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    final points = projection.points;
    if (low == 0 || keys[low] == value) return points[low];
    final gap = keys[low] - keys[low - 1];
    if (gap <= 0) return points[low];
    final fraction = (value - keys[low - 1]) / gap;
    return Offset.lerp(points[low - 1], points[low], fraction);
  }
}
