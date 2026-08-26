/// Pan/zoom/transform math, shared by every chart and the track map
/// (SPEC.md §9.5).
///
/// Deliberately plain Dart with no Flutter import: the whole point of the
/// custom chart core is that trace panels and the track map share **one**
/// viewport and **one** cursor, so this type is passed between a Riverpod
/// controller, painters, and tests alike. Keeping it free of widget concerns
/// is what lets the highest-risk arithmetic here live in the test surface a
/// plain `flutter test` can always run — the same reasoning the data layer
/// applies to its SQL builders.
///
/// The domain is whatever axis the charts are on — elapsed seconds or lap
/// distance in metres (§8.4's Distance/Time toggle) — never pixels. Pixels
/// enter only in [toPixels]/[toDomain], against a width the caller supplies,
/// so one viewport can drive panels of different widths at once.
library;

import 'dart:math' as math;

/// A half-open domain window `[start, end)`.
///
/// Half-open for the same reason `TraceWindow` is: consecutive lap windows
/// built from `Lap` event boundaries share an endpoint, and an inclusive
/// range would double-count the sample sitting exactly on the start/finish
/// line.
class ChartViewport {
  const ChartViewport(this.start, this.end)
      : assert(end > start, 'viewport must be non-empty');

  final double start;
  final double end;

  double get span => end - start;
  double get center => start + span / 2;

  /// Fraction of the way across the viewport, unclamped so a painter can
  /// tell "just off the left edge" from "far off it".
  double normalize(double value) => (value - start) / span;

  double toPixels(double value, double width) => normalize(value) * width;

  double toDomain(double pixels, double width) =>
      start + (pixels / width) * span;

  bool contains(double value) => value >= start && value < end;

  /// Moves this window by [delta] domain units, then slides it back inside
  /// [bounds] rather than shrinking it.
  ///
  /// Sliding rather than clipping matters: clipping at an edge would silently
  /// change the zoom level mid-drag, so a pan that hits the end of the lap
  /// and comes back would not return to where it started.
  ChartViewport pannedBy(double delta, {required ChartViewport bounds}) =>
      ChartViewport(start + delta, end + delta).slidInside(bounds);

  /// Scales the window by [factor] about [focus], keeping the domain value
  /// under the pointer under the pointer.
  ///
  /// [factor] below 1 zooms in. The result never exceeds [bounds] and never
  /// shrinks below [minSpan], which stops a fast scroll wheel from collapsing
  /// the window to a single point that no pan can recover from.
  ChartViewport zoomedAround(
    double focus,
    double factor, {
    required ChartViewport bounds,
    double? minSpan,
  }) {
    final floor = minSpan ?? bounds.span / _maxZoom;
    final target = (span * factor).clamp(floor, bounds.span);
    // Anchor on the focus's fractional position so the value under the
    // pointer does not drift while zooming.
    final anchor = ((focus - start) / span).clamp(0.0, 1.0);
    final newStart = focus - anchor * target;
    return ChartViewport(newStart, newStart + target).slidInside(bounds);
  }

  /// Translates this window so it lies inside [bounds], widening it to
  /// [bounds] only if it is genuinely wider.
  ChartViewport slidInside(ChartViewport bounds) {
    if (span >= bounds.span) return bounds;
    if (start < bounds.start) {
      return ChartViewport(bounds.start, bounds.start + span);
    }
    if (end > bounds.end) return ChartViewport(bounds.end - span, bounds.end);
    return this;
  }

  /// How far this window is zoomed in relative to [bounds]; 1 is fully out.
  double zoomFactorWithin(ChartViewport bounds) => bounds.span / span;

  /// Deepest zoom any viewport allows, as a multiple of its bounds. 500× of a
  /// 64-second lap is a 128 ms window — already finer than a single sample of
  /// the slowest channel a trace panel plots.
  static const _maxZoom = 500.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartViewport && other.start == start && other.end == end);

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      'ChartViewport(${start.toStringAsFixed(3)}..${end.toStringAsFixed(3)})';
}

/// A value (vertical) range, with the tick generation every axis shares.
class ValueRange {
  const ValueRange(this.min, this.max);

  /// The range covering every value in [values], or null if there are none.
  static ValueRange? ofAll(Iterable<double> values) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    var any = false;
    for (final v in values) {
      if (v.isNaN || v.isInfinite) continue;
      any = true;
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return any ? ValueRange(lo, hi) : null;
  }

  final double min;
  final double max;

  double get span => max - min;

  /// Where [value] sits between [min] and [max], 0 at the bottom.
  double normalize(double value) => span == 0 ? 0.5 : (value - min) / span;

  ValueRange union(ValueRange other) =>
      ValueRange(math.min(min, other.min), math.max(max, other.max));

  /// Adds headroom so a trace never touches the panel edge.
  ///
  /// A flat series — which §5.4/§8.7 make a real case, not an edge one — has
  /// zero span, so it gets an absolute pad instead of a proportional one that
  /// would stay zero and produce a degenerate scale.
  ValueRange padded({double fraction = 0.06, double minimumPad = 0.5}) {
    final pad = span == 0 ? minimumPad : span * fraction;
    return ValueRange(min - pad, max + pad);
  }

  /// Gridline values at "nice" intervals, at most [target] + 1 of them.
  ///
  /// Round steps rather than `span / n`: a reader checks a value against a
  /// gridline, and 1/2/2.5/5/10 × 10ⁿ are the intervals that can be read
  /// without arithmetic.
  List<double> ticks({int target = 4}) {
    final step = _niceStep(span, target);
    if (step == 0) return [min];
    final first = (min / step).ceilToDouble() * step;
    final out = <double>[];
    for (var v = first; v <= max + step * 1e-6; v += step) {
      // Snap away the accumulated float error so a tick prints 0.3, not
      // 0.30000000000000004 — and fold negative zero into zero, which
      // otherwise renders as "-0" on any axis whose range crosses it.
      final snapped = (v / step).roundToDouble() * step;
      out.add(snapped == 0 ? 0.0 : snapped);
    }
    return out;
  }

  static double _niceStep(double span, int target) {
    if (span <= 0 || target <= 0) return 0;
    final rough = span / target;
    final magnitude = math.pow(10, (math.log(rough) / math.ln10).floor())
        .toDouble();
    final normalized = rough / magnitude;
    final multiple = normalized <= 1
        ? 1.0
        : normalized <= 2
            ? 2.0
            : normalized <= 2.5
                ? 2.5
                : normalized <= 5
                    ? 5.0
                    : 10.0;
    return multiple * magnitude;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValueRange && other.min == min && other.max == max);

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'ValueRange($min..$max)';
}
