/// The lap-time trend (SPEC.md §8.3): every lap's pace against the fastest.
///
/// Plain arithmetic over the lap table, so it is reachable from a `flutter
/// test` without a DuckDB connection — the same split the data layer makes.
library;

import '../../../data/models/models.dart';

/// Why a lap is left out of the pace figures — and, in the chart, drawn as a
/// slot with no bar.
///
/// These are the three ways `Lap.isTimed` is false (§5.2, §8.3.1). They live
/// here rather than beside the table's note chip because the chart's tooltip
/// has to give the *same* reason in the *same* words: two places wording one
/// fact are two places that disagree by the next release.
enum LapExclusion {
  outLap(
    'out lap',
    'Starts in the garage rather than at the start/finish line, so its '
        'time is not comparable with a flying lap.',
  ),
  incomplete(
    'incomplete',
    'The recording ended before this lap finished, so it has no time.',
  ),
  noTime(
    'no time',
    'The game recorded no time for this lap — usually an invalidated lap.',
  );

  const LapExclusion(this.label, this.explanation);

  /// The short form, for a chip.
  final String label;

  /// The full sentence, for a tooltip.
  final String explanation;

  /// The reason [lap] is not timed, or null when it is.
  ///
  /// Checked in the order the lap table has always reported them: a garage lap
  /// is an out lap even though the game did time it (71.241 s on the Race
  /// sample), and an open final lap is incomplete even though it has no time
  /// either.
  static LapExclusion? of(Lap lap) {
    if (lap.isOutLap) return outLap;
    if (lap.isOpenEnded) return incomplete;
    if (lap.lapTimeSeconds == null) return noTime;
    return null;
  }
}

/// One lap's slot in the trend chart.
class TrendLap {
  const TrendLap({
    required this.lap,
    required this.deltaSeconds,
    required this.exclusion,
    required this.isFastest,
  });

  final Lap lap;

  /// Seconds slower than the fastest lap; exactly zero for the fastest one.
  /// Null when the lap is [exclusion]-excluded, which is what keeps its slot
  /// on the axis without giving it a bar.
  final double? deltaSeconds;

  final LapExclusion? exclusion;

  final bool isFastest;
}

/// Pace across a session, expressed as **delta to the fastest lap**.
///
/// The chart plots that rather than the lap times themselves because of the
/// scale the data has. The Race sample's 16 timed laps run 63.941–64.701 s: a
/// bar of absolute time drawn from zero puts every lap within 1.2 % of the
/// same height, so the whole 0.76 s spread — the entire story — is a sliver
/// at the top of the bar. Truncating the axis to fix that would make the
/// bars lie about their ratios, which is worse. The delta starts at zero
/// honestly and *is* §8.3's "delta to personal best".
///
/// The fastest lap therefore has a zero-height bar, and the chart marks it
/// some other way (`lap_trend_card.dart`).
class LapTrend {
  const LapTrend._({
    required this.laps,
    required this.fastest,
    required this.medianLapTimeSeconds,
    required this.stdDevSeconds,
    required this.timedCount,
    required this.slowest,
  });

  /// Every lap, in order, timed or not: dropping the untimed ones would make
  /// the lap numbering jump (the lap table's rule, §8.3).
  final List<TrendLap> laps;

  /// The best timed lap. Null when no lap in the session is timed.
  final Lap? fastest;

  /// The median of the timed laps' times, or null with none.
  ///
  /// The median rather than the mean because the laps a trend chart exists to
  /// find are the outliers: one spin adds seconds, and a mean dragged by it
  /// would describe no lap the driver actually did. A line that a slow lap
  /// can move is a line that hides the slow lap.
  final double? medianLapTimeSeconds;

  /// `LapPaceStatistics.consistencyStdDevSeconds` — §8.3's consistency
  /// measure. Null with fewer than two timed laps, where spread is undefined
  /// rather than zero.
  final double? stdDevSeconds;

  final int timedCount;

  /// The slowest *timed* lap, or null with none.
  final Lap? slowest;

  double? get _fastestTime => fastest?.lapTimeSeconds;

  /// How far the median lap is off the fastest — the dashed reference line.
  double? get medianDeltaSeconds =>
      switch ((medianLapTimeSeconds, _fastestTime)) {
        (final median?, final best?) => median - best,
        _ => null,
      };

  /// Slowest timed lap minus fastest: the chart's full height.
  double? get spreadSeconds =>
      switch ((slowest?.lapTimeSeconds, _fastestTime)) {
        (final worst?, final best?) => worst - best,
        _ => null,
      };

  static LapTrend derive(List<Lap> laps) {
    final timed = laps.timed;
    final best = laps.bestLap;
    final bestTime = best?.lapTimeSeconds;

    Lap? slowest;
    for (final lap in timed) {
      if (slowest == null || lap.lapTimeSeconds! > slowest.lapTimeSeconds!) {
        slowest = lap;
      }
    }

    return LapTrend._(
      laps: [
        for (final lap in laps)
          TrendLap(
            lap: lap,
            deltaSeconds: lap.isTimed && bestTime != null
                ? lap.lapTimeSeconds! - bestTime
                : null,
            exclusion: LapExclusion.of(lap),
            // By identity, as the table does: two laps can share a time to the
            // millisecond, and only one of them is "the" fastest.
            isFastest: best != null && identical(lap, best),
          ),
      ],
      fastest: best,
      medianLapTimeSeconds: _median([for (final l in timed) l.lapTimeSeconds!]),
      stdDevSeconds: laps.consistencyStdDevSeconds,
      timedCount: timed.length,
      slowest: slowest,
    );
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
