import 'dart:typed_data';

/// Decimated chart data for one channel over one viewport (SPEC.md §9.5).
///
/// Deliberately **not** a `freezed` model, unlike the rest of `models/`. This
/// is a rendering payload, not a domain entity: it holds thousands of points
/// that a `CustomPainter` walks every frame, so the columns are
/// [Float64List]s rather than a `List<TracePoint>` — one allocation per
/// series instead of one per sample. `freezed`'s generated `==` would also be
/// misleading here, since typed lists compare by identity.
///
/// One series carries one value column. A per-corner channel (`value1`..
/// `value4`) yields four of these rather than a nested structure, so a
/// painter never has to branch on arity.
class TraceSeries {
  TraceSeries({
    required this.channelName,
    required this.unit,
    required this.frequencyHz,
    required this.valueColumn,
    required this.times,
    required this.lows,
    required this.highs,
  })  : assert(times.length == lows.length && lows.length == highs.length,
            'columns must be parallel');

  final String channelName;
  final String unit;

  /// The channel's declared rate — for labelling only (§5.2: nominal, and
  /// wrong for two channels). The timestamps in [times] are read, not
  /// derived from this.
  final int frequencyHz;

  /// Which value column this series came from: `value`, or `value1`..`value4`
  /// for a per-corner channel.
  final String valueColumn;

  /// Bucket timestamps in elapsed seconds — the time of the first sample in
  /// each bucket, read off the master clock rather than synthesized.
  final Float64List times;

  /// Per-bucket minimum and maximum. Min/max bucketing rather than plain
  /// sampling because a downsample that picks one sample per pixel column
  /// drops the peaks — and on telemetry the peaks (a brake spike, a rev
  /// limiter hit) are the part the user is looking for.
  final Float64List lows;
  final Float64List highs;

  int get length => times.length;
  bool get isEmpty => times.isEmpty;
  bool get isNotEmpty => times.isNotEmpty;

  /// True when the whole series holds one repeated value, which §5.4/§8.7
  /// require not be plotted: `SoC` and `Regen Rate` are all-zero in GT3
  /// files, and a flat zero line labelled "State of Charge" reads as data
  /// rather than as absence.
  bool get isDegenerate {
    if (isEmpty) return true;
    final first = lows[0];
    for (var i = 0; i < length; i++) {
      if (lows[i] != first || highs[i] != first) return false;
    }
    return true;
  }

  double get minValue {
    var m = double.infinity;
    for (var i = 0; i < length; i++) {
      if (lows[i] < m) m = lows[i];
    }
    return m;
  }

  double get maxValue {
    var m = double.negativeInfinity;
    for (var i = 0; i < length; i++) {
      if (highs[i] > m) m = highs[i];
    }
    return m;
  }
}

/// A half-open time window `[startSeconds, endSeconds)` in a session's
/// elapsed-seconds clock, plus how many buckets to decimate it into.
///
/// Half-open on purpose: consecutive lap windows built from `Lap` event
/// boundaries share an endpoint, and an inclusive range would double-count
/// the sample sitting exactly on the start/finish line.
class TraceWindow {
  const TraceWindow({
    required this.startSeconds,
    required this.endSeconds,
    this.buckets = 1200,
  })  : assert(endSeconds > startSeconds, 'window must be non-empty'),
        assert(buckets > 0, 'buckets must be positive');

  final double startSeconds;
  final double endSeconds;

  /// Target bucket count — normally the chart's pixel width, since there is
  /// no point resolving finer than the display can show (§9.5). Measured
  /// cost at 1200 buckets: ~4 ms over a real 22-minute session, ~42 ms over
  /// a synthetic 6-hour one, ~24 ms for a zoomed window of a 24-hour one.
  final int buckets;

  double get durationSeconds => endSeconds - startSeconds;
}
