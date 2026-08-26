/// A recording discontinuity in the master clock (SPEC.md §5.2, §9.6).
///
/// `GPS Time` advances by exactly 1/100 s per row except across a gap. A
/// row-index clock cannot see one, so every sample after a gap would be
/// permanently offset by its length — silently, with no error. Recording
/// these at import is what turns that from an invisible failure into a
/// reportable fact (§9.6), and §15.12 wants the count surfaced on Session
/// Overview so a session whose timing is load-bearing is flagged rather than
/// quietly trusted.
class ClockGap {
  const ClockGap({required this.masterRowIndex, required this.deltaSeconds});

  /// 1-based row index of the sample *after* the gap, as `row_number()`
  /// reports it.
  final int masterRowIndex;

  /// Observed step across the gap. The expected step is 0.01 s, so the lost
  /// time is `deltaSeconds - 0.01`.
  final double deltaSeconds;

  /// Time missing from the recording at this point.
  double get lostSeconds => deltaSeconds - 0.01;

  @override
  String toString() =>
      'ClockGap(row $masterRowIndex, ${lostSeconds.toStringAsFixed(4)}s lost)';
}
