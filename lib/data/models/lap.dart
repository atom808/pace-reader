import 'package:freezed_annotation/freezed_annotation.dart';

part 'lap.freezed.dart';

/// Sector splits for one lap (SPEC.md §8.3).
///
/// **The catalog's sector values are cumulative splits, not durations** —
/// verified against `Current Sector` transition timestamps across all 16
/// timed laps in the three samples. `Last Sector1` is S1's duration, but
/// `Last Sector2` is *elapsed time at the S2/S3 boundary* (S1+S2), and there
/// is no Sector3 value at all.
///
/// This corrects SPEC v0.6 §8.3, which specified `s3 = lap - s1 - s2`. That
/// formula treats the cumulative value as a duration and is wrong by up to
/// 33.4 s — it produced *negative* sector-3 times (-5.371 s on the Practice
/// sample), which is how it's provable rather than merely suspected. The
/// derivations below reproduce ground truth to within 0.014 s, i.e. one
/// event-timestamp tick.
@freezed
abstract class SectorTimes with _$SectorTimes {
  const SectorTimes._();

  const factory SectorTimes({
    /// `Last Sector1` — already a duration.
    double? sector1Seconds,
    /// S2's *duration*: `Last Sector2 - Last Sector1`.
    double? sector2Seconds,
    /// S3's *duration*: `Lap Time - Last Sector2`. No Sector3 value exists
    /// in the catalog, so this is the only route to it.
    double? sector3Seconds,
  }) = _SectorTimes;

  /// Builds sector durations from the file's raw cumulative values.
  ///
  /// A raw `0.0` means "not recorded", not a zero-second sector: the game
  /// writes 0.0 for a sector it didn't time (3 of 19 Race laps), and treating
  /// it as a real value would produce a fastest sector of 0.000. Absent and
  /// zero are therefore both mapped to null.
  factory SectorTimes.fromCumulative({
    required double? sector1,
    required double? sector2Cumulative,
    required double? lapTimeSeconds,
  }) {
    final s1 = _presence(sector1);
    final s2Cum = _presence(sector2Cumulative);
    final lap = _presence(lapTimeSeconds);
    return SectorTimes(
      sector1Seconds: s1,
      sector2Seconds: (s1 != null && s2Cum != null) ? s2Cum - s1 : null,
      sector3Seconds: (s2Cum != null && lap != null) ? lap - s2Cum : null,
    );
  }

  static double? _presence(double? raw) =>
      (raw == null || raw == 0.0) ? null : raw;

  /// True only when all three splits resolved — a lap can have a valid lap
  /// time and still be missing S2/S3 (Race laps 2, 5 and 13 record S1 but
  /// write 0.0 for S2), so a sector view has to render partial rows.
  bool get isComplete =>
      sector1Seconds != null && sector2Seconds != null && sector3Seconds != null;

  List<double?> get all => [sector1Seconds, sector2Seconds, sector3Seconds];
}

/// One lap, derived from the `Lap` event table (SPEC.md §5.2, §8.3).
@freezed
abstract class Lap with _$Lap {
  const Lap._();

  const factory Lap({
    /// The raw 0-based value from the `Lap` event table.
    required int index,
    /// `ts` of this lap's `Lap` event, in elapsed seconds.
    required double startSeconds,
    /// `ts` of the next `Lap` event. Null on the final row, which opens a lap
    /// the file has no closing boundary for (§5.2).
    double? endSeconds,
    /// The game's own `Lap Time`, read at this lap's *end* boundary.
    ///
    /// Null when the file recorded no time (an untimed out-lap) or wrote 0.0
    /// (an invalidated lap — 2 of 19 Race laps, 1 of 4 Qualify laps). Never
    /// derived from `endSeconds - startSeconds`: on the Race sample lap 0
    /// those disagree by 101 s, because the wall-clock span includes garage
    /// and grid time while the game times only from the start.
    double? lapTimeSeconds,
    required SectorTimes sectors,
  }) = _Lap;

  /// What to show a user. `Lap` values are 0-based, so a raw index rendered
  /// directly reads "Lap 0" (§5.2).
  int get displayNumber => index + 1;

  /// Row 0 marks the recording start with the car in the garage/pits, not a
  /// start/finish crossing (§5.2). Its wall-clock span is meaningless and it
  /// must be excluded from pace statistics and alignment checks alike.
  bool get isOutLap => index == 0;

  /// The final row opens a lap with no closing boundary, so it can't be timed.
  bool get isOpenEnded => endSeconds == null;

  /// A lap with a usable time for pace analysis: timed, closed, and not the
  /// garage lap.
  bool get isTimed => lapTimeSeconds != null && !isOpenEnded && !isOutLap;

  /// Wall-clock span between boundaries. Diagnostic only — [lapTimeSeconds]
  /// is authoritative for anything a user sees.
  double? get wallClockSeconds =>
      endSeconds == null ? null : endSeconds! - startSeconds;
}
