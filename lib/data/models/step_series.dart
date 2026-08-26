import 'dart:typed_data';

/// A sparse, step-valued signal read from an event table (SPEC.md §5.1).
///
/// Like `TraceSeries` in `trace.dart` this is a rendering payload rather than
/// a domain entity — parallel [Float64List]s a painter walks every frame, not
/// a `freezed` model — but it answers a different question. A channel is a
/// dense sample sequence that a chart interpolates between; an event is a
/// list of *changes*, and the value between two of them is the earlier one,
/// held. Drawing one as the other turns a gearshift into a ramp.
///
/// Getting "value at time t" is therefore a backward/as-of lookup (latest row
/// with `ts <= t`), never an equality or index lookup — see [valueAt].
class StepSeries {
  StepSeries({
    required this.eventName,
    required this.unit,
    required this.times,
    required this.values,
  }) : assert(times.length == values.length, 'columns must be parallel');

  /// Builds a series from raw `(ts, value)` rows as the repository reads them.
  ///
  /// Event tables carry several storage types — `Gear` is TINYINT, `TC`/`ABS`
  /// and `Speed Limiter` are BOOLEAN, `Lap` is USMALLINT — so the coercion
  /// lives here, once, rather than at each call site. A boolean maps to 1/0
  /// because an on/off signal is exactly a two-level step trace.
  ///
  /// Rows whose value is null or of an unmappable type are dropped rather
  /// than coerced to zero: a plotted zero is indistinguishable from a real
  /// zero, and `Gear` genuinely uses 0 for neutral.
  factory StepSeries.fromRows(
    List<(double, Object?)> rows, {
    required String eventName,
    String unit = '',
  }) {
    final kept = <(double, double)>[];
    for (final (ts, raw) in rows) {
      final value = _toDouble(raw);
      if (value != null) kept.add((ts, value));
    }
    final times = Float64List(kept.length);
    final values = Float64List(kept.length);
    for (var i = 0; i < kept.length; i++) {
      times[i] = kept[i].$1;
      values[i] = kept[i].$2;
    }
    return StepSeries(
      eventName: eventName,
      unit: unit,
      times: times,
      values: values,
    );
  }

  final String eventName;
  final String unit;

  /// Change timestamps in elapsed seconds, ascending. The first may sit
  /// *before* a requested window: it is the value in force when the window
  /// opened, which the query fetches deliberately (see `eventWindowSql`).
  final Float64List times;
  final Float64List values;

  int get length => times.length;
  bool get isEmpty => times.isEmpty;
  bool get isNotEmpty => times.isNotEmpty;

  /// The value in force at [seconds] — the latest row at or before it.
  ///
  /// Null only when [seconds] precedes the first row, which is genuinely "no
  /// value yet" rather than a lookup failure. §5.1's invariant that no event
  /// table is ever empty means that is the only unresolvable case.
  double? valueAt(double seconds) {
    final index = indexAt(seconds);
    return index < 0 ? null : values[index];
  }

  /// Index of the row in force at [seconds], or -1 if [seconds] precedes the
  /// first row. Binary search: a scrub cursor calls this every frame.
  int indexAt(double seconds) {
    if (isEmpty || seconds < times[0]) return -1;
    var low = 0;
    var high = length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (times[mid] <= seconds) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  /// True when every row holds the same value — the "one row, never changed"
  /// norm §5.1 describes, which UI renders as a constant rather than as an
  /// empty chart.
  bool get isConstant {
    if (isEmpty) return true;
    for (var i = 1; i < length; i++) {
      if (values[i] != values[0]) return false;
    }
    return true;
  }

  double get minValue {
    var m = double.infinity;
    for (final v in values) {
      if (v < m) m = v;
    }
    return m;
  }

  double get maxValue {
    var m = double.negativeInfinity;
    for (final v in values) {
      if (v > m) m = v;
    }
    return m;
  }

  static double? _toDouble(Object? raw) => switch (raw) {
        final num n => n.toDouble(),
        final bool b => b ? 1.0 : 0.0,
        _ => null,
      };
}
