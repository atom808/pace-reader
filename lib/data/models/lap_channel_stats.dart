/// One channel summarised over one lap (SPEC.md §8.6, §8.7, §9.5).
library;

/// A channel's first, last and extreme values over one lap, computed in SQL.
///
/// The shape §9.5 calls a *per-lap aggregate*: one row per lap however long
/// the session, which is what a fuel-per-lap bar, a brake-temperature trend or
/// a state-of-charge window needs — and nothing a trace needs, which is why it
/// is its own read rather than a decimation of one.
///
/// [first] and [last] are the lap's first and last *samples*, not values
/// interpolated onto its boundaries: at 20 Hz the first sample lands within
/// 0.05 s of the line, and a consumption figure built on them is honest about
/// being a difference of two readings the game actually wrote.
class LapChannelStats {
  const LapChannelStats({
    required this.lapIndex,
    required this.first,
    required this.last,
    required this.min,
    required this.max,
    required this.mean,
    required this.samples,
  });

  /// The raw 0-based `Lap` value this row summarises.
  final int lapIndex;

  final double first;
  final double last;
  final double min;
  final double max;
  final double mean;

  /// How many of the channel's rows fell inside the lap.
  final int samples;

  @override
  String toString() => 'LapChannelStats(lap $lapIndex: '
      '${first.toStringAsFixed(3)} → ${last.toStringAsFixed(3)}, '
      '$samples samples)';
}
