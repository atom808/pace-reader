/// Query results at a viewport, turned into render-ready points
/// (SPEC.md §9.5).
///
/// This is the seam between the repository layer and the painters, and it
/// deliberately sits outside the widget tree: everything here is pure
/// arithmetic over the typed arrays `TelemetryRepository` returns, so it runs
/// in a plain `flutter test` without a DuckDB connection — the same split the
/// data layer makes between its SQL builders and its integration tests.
///
/// The heavy reduction already happened in SQL: `channel_queries.dart`
/// min/max-buckets a channel inside DuckDB so Dart never sees a
/// full-resolution multi-hour trace (§9.5). What is left for this layer is
/// the part SQL cannot do — choosing how finely to ask, remapping the time
/// axis onto lap distance for §8.4's Distance/Time toggle, and packing the
/// result into arrays a `CustomPainter` can walk every frame.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/models/models.dart';
import 'viewport.dart';

/// Maps elapsed seconds to distance around the lap (SPEC.md §8.4, §8.5).
///
/// Built from the `Lap Dist` channel, which is 10 Hz — an order of magnitude
/// coarser than the 100 Hz channels a trace panel plots — so a channel sample
/// almost never lands on a distance sample and the mapping interpolates
/// between the two that bracket it.
///
/// Both axes come off the same master clock (§5.2), so this is a *resample*,
/// not an alignment guess: `Lap Dist`'s timestamps and a trace's timestamps
/// are the same clock read at different rates.
class DistanceAxis {
  DistanceAxis._(this.times, this.distances, this.isMonotonic);

  /// Builds an axis from a full-resolution `Lap Dist` read over one lap.
  ///
  /// The series arrives as min/max pairs like any other; at full resolution
  /// both hold the same sample, and [lows] is read for that reason rather
  /// than averaged.
  factory DistanceAxis.fromSeries(TraceSeries lapDistance) {
    final n = lapDistance.length;
    final times = Float64List(n);
    final distances = Float64List(n);
    var monotonic = true;
    for (var i = 0; i < n; i++) {
      times[i] = lapDistance.times[i];
      distances[i] = lapDistance.lows[i];
      if (i > 0 && distances[i] < distances[i - 1] - _monotonicTolerance) {
        monotonic = false;
      }
    }
    return DistanceAxis._(times, distances, monotonic);
  }

  /// A `Lap Dist` sample can repeat while the car is stationary, so equality
  /// is not a violation; only a measurable step *backwards* is.
  static const _monotonicTolerance = 1e-6;

  final Float64List times;
  final Float64List distances;

  /// False when lap distance runs backwards somewhere in this window.
  ///
  /// The garage lap is the case that produces it — measured on the checked-in
  /// fixture, lap 0 has one backwards step while laps 1–3 have none — because
  /// the car is manoeuvring in the pits rather than driving the lap. A
  /// distance axis there would fold the chart back over itself, so the UI
  /// falls back to time and says why, instead of drawing a plausible-looking
  /// tangle.
  final bool isMonotonic;

  bool get isUsable => isMonotonic && times.length >= 2;

  ChartViewport get bounds =>
      ChartViewport(distances.first, math.max(distances.last, distances.first + 1));

  /// Distance at [seconds], linearly interpolated between bracketing samples.
  ///
  /// Clamped to the endpoints rather than returning null outside the range: a
  /// 100 Hz channel legitimately has up to a tenth of a second of samples
  /// before the first 10 Hz distance sample and after the last, and dropping
  /// those would trim the ends off every trace.
  double distanceAt(double seconds) {
    if (times.isEmpty) return 0;
    if (seconds <= times.first) return distances.first;
    if (seconds >= times.last) return distances.last;
    final upper = _upperBound(seconds);
    final lower = upper - 1;
    final t0 = times[lower];
    final t1 = times[upper];
    final gap = t1 - t0;
    if (gap <= 0) return distances[lower];
    final fraction = (seconds - t0) / gap;
    return distances[lower] + (distances[upper] - distances[lower]) * fraction;
  }

  /// The inverse: elapsed seconds at [distance].
  ///
  /// Well defined only because [isMonotonic] is checked before a distance
  /// axis is ever offered — an axis that ran backwards would have two times
  /// for one distance, and this would silently return one of them. Used when
  /// the Distance/Time toggle has to carry a cursor or a zoom window across,
  /// so switching axis moves the axis and not the point of the lap the user
  /// was looking at.
  double timeAt(double distance) {
    if (times.isEmpty) return 0;
    if (distance <= distances.first) return times.first;
    if (distance >= distances.last) return times.last;
    var low = 1;
    var high = distances.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (distances[mid] > distance) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    final gap = distances[low] - distances[low - 1];
    if (gap <= 0) return times[low - 1];
    final fraction = (distance - distances[low - 1]) / gap;
    return times[low - 1] + (times[low] - times[low - 1]) * fraction;
  }

  /// Index of the first sample strictly after [seconds]; assumes
  /// `times.first < seconds < times.last`, which [distanceAt] guarantees.
  int _upperBound(double seconds) {
    var low = 1;
    var high = times.length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (times[mid] > seconds) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }
}

/// Which axis the synced charts and the track map are plotted against
/// (SPEC.md §8.4 — both reference apps offer this toggle).
enum TraceAxis {
  time('Time', 's'),
  distance('Distance', 'm');

  const TraceAxis(this.label, this.unit);

  final String label;
  final String unit;
}

/// One channel, decimated and mapped onto the chosen axis — what a painter
/// draws.
///
/// Holds the min/max envelope rather than a single value per point because
/// that is what the query returns and what the extremes require: a downsample
/// keeping one sample per pixel column drops the brake spike and the rev
/// limiter hit, which are the parts the user came for.
class TracePlot {
  TracePlot({
    required this.label,
    required this.unit,
    required this.xs,
    required this.lows,
    required this.highs,
    required this.valueRange,
  }) : assert(xs.length == lows.length && lows.length == highs.length,
            'columns must be parallel');

  /// Projects [series] onto [axis].
  ///
  /// With [TraceAxis.distance] the x values come from [distanceAxis], so
  /// every panel and the track map share one x domain. A null
  /// [distanceAxis] with a distance request falls back to time rather than
  /// throwing: whether a lap has a usable distance axis is a property of the
  /// recording (see [DistanceAxis.isMonotonic]), not a programming error.
  factory TracePlot.fromSeries(
    TraceSeries series, {
    required TraceAxis axis,
    DistanceAxis? distanceAxis,
    String? label,
  }) {
    final n = series.length;
    final xs = Float64List(n);
    final useDistance = axis == TraceAxis.distance && distanceAxis != null;
    for (var i = 0; i < n; i++) {
      xs[i] = useDistance
          ? distanceAxis.distanceAt(series.times[i])
          : series.times[i];
    }
    final range = ValueRange.ofAll([
      ...series.lows,
      ...series.highs,
    ]) ?? const ValueRange(0, 1);
    return TracePlot(
      label: label ?? series.channelName,
      unit: series.unit,
      xs: xs,
      lows: Float64List.fromList(series.lows),
      highs: Float64List.fromList(series.highs),
      valueRange: range,
    );
  }

  final String label;
  final String unit;

  /// Domain positions — elapsed seconds or lap distance in metres.
  final Float64List xs;
  final Float64List lows;
  final Float64List highs;

  /// The raw value extent, before any padding an axis adds for headroom.
  final ValueRange valueRange;

  int get length => xs.length;
  bool get isEmpty => xs.isEmpty;
  bool get isNotEmpty => xs.isNotEmpty;

  ChartViewport? get domainBounds => length < 2
      ? null
      : ChartViewport(xs.first, math.max(xs.last, xs.first + 1e-6));

  /// Index of the sample nearest [x] — what the scrub cursor reads.
  ///
  /// Nearest rather than preceding: a cursor sitting a pixel past a peak
  /// should report the peak, not the sample before it.
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

  /// Representative value at [x], for the cursor readout.
  ///
  /// The midpoint of the bucket's envelope: a bucket is a range the signal
  /// covered, so a single number for it is a summary either way, and the
  /// midpoint is the one that cannot be mistaken for a measured extreme.
  double? valueAt(double x) {
    final index = nearestIndex(x);
    if (index < 0) return null;
    return (lows[index] + highs[index]) / 2;
  }
}

/// An event signal mapped onto the chosen axis, held between changes
/// (SPEC.md §5.1).
///
/// Separate from [TracePlot] because it is drawn differently and must be:
/// interpolating between two gear values would render a shift as a ramp
/// through gears the car was never in.
class StepPlot {
  StepPlot({
    required this.label,
    required this.unit,
    required this.xs,
    required this.values,
    required this.valueRange,
  }) : assert(xs.length == values.length, 'columns must be parallel');

  /// Projects [series] onto [axis], clipped to [window] in *seconds*.
  ///
  /// The first row of an event window read legitimately sits before the
  /// window (it is the value in force when the window opened — see
  /// `eventWindowSql`), so its x is pulled forward to the window start rather
  /// than extending the axis backwards to a change that happened on a
  /// different lap.
  factory StepPlot.fromSeries(
    StepSeries series, {
    required TraceAxis axis,
    required ChartViewport window,
    DistanceAxis? distanceAxis,
    String? label,
  }) {
    final useDistance = axis == TraceAxis.distance && distanceAxis != null;
    final xs = <double>[];
    final values = <double>[];
    for (var i = 0; i < series.length; i++) {
      final seconds = math.max(series.times[i], window.start);
      if (seconds >= window.end) break;
      final x = useDistance ? distanceAxis.distanceAt(seconds) : seconds;
      // Two changes can clamp onto the same x — several gearshifts before the
      // window opened, or two inside one distance sample. The later value
      // wins, since it is the one in force from there on.
      if (xs.isNotEmpty && x <= xs.last) {
        values[values.length - 1] = series.values[i];
        continue;
      }
      xs.add(x);
      values.add(series.values[i]);
    }
    return StepPlot(
      label: label ?? series.eventName,
      unit: series.unit,
      xs: Float64List.fromList(xs),
      values: Float64List.fromList(values),
      valueRange: ValueRange.ofAll(values) ?? const ValueRange(0, 1),
    );
  }

  final String label;
  final String unit;
  final Float64List xs;
  final Float64List values;
  final ValueRange valueRange;

  int get length => xs.length;
  bool get isEmpty => xs.isEmpty;
  bool get isNotEmpty => xs.isNotEmpty;

  /// The value held at [x] — the latest change at or before it, never an
  /// interpolation.
  double? valueAt(double x) {
    if (isEmpty || x < xs.first) return null;
    var low = 0;
    var high = length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (xs[mid] <= x) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return values[low];
  }
}
