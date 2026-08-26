/// The render-ready track map payload (SPEC.md §8.5).
///
/// The map's counterpart to `TracePlot`: a projected path plus, per point,
/// the value colouring it and the domain position that ties it to the trace
/// panels' shared cursor. Building all three together is what makes the
/// cursor genuinely shared — the map and the panels index the same axis, so
/// there is no second alignment to keep in step.
library;

import 'dart:typed_data';

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
  factory TrackPath.build({
    required TraceSeries latitude,
    required TraceSeries longitude,
    required TraceAxis axis,
    DistanceAxis? distanceAxis,
    TracePlot? colorBy,
  }) {
    final projection = TrackProjection.fromCoordinates(
      Float64List.fromList(latitude.lows),
      Float64List.fromList(longitude.lows),
    );

    final n = projection.points.length;
    final xs = Float64List(n);
    final values = Float64List(n);
    final useDistance = axis == TraceAxis.distance && distanceAxis != null;
    for (var i = 0; i < n; i++) {
      final seconds = latitude.times[i];
      xs[i] = useDistance ? distanceAxis.distanceAt(seconds) : seconds;
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
}
