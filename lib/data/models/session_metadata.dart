import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_metadata.freezed.dart';

/// The `metadata` table's confirmed 12 keys (SPEC.md §5.1), typed.
///
/// Fields stay close to the raw strings on purpose. `carName` bundles team,
/// year, number and model with no confirmed grammar for splitting it (§15.6),
/// and `carClass` arrives as a short code (`"GT3"`, `"Hyper"`) rather than the
/// full LMGT3/LMH name — so both are carried verbatim and given display
/// labels at the edge, rather than parsed into a structure the data doesn't
/// actually guarantee.
@freezed
abstract class SessionMetadata with _$SessionMetadata {
  const SessionMetadata._();

  const factory SessionMetadata({
    required String driverName,
    required String steamId,
    required String recordingTime,
    /// Session **start time-of-day** (e.g. `"13:00:21"`), not a duration —
    /// the name invites exactly the wrong reading (§5.1).
    required String sessionTimeOfDay,
    required SessionType sessionType,
    required String trackName,
    /// Load-bearing, not a display detail (§8.1): the Sebring Race sample is
    /// the 3.08 km "Sebring School Circuit", roughly half the full course.
    /// Index and compare on `(trackName, trackLayout)` or bests silently
    /// span different circuits.
    required String trackLayout,
    required String weatherConditions,
    required String carName,
    required String carClass,
    /// The full embedded car setup as raw JSON (§5.1) — parsed on demand by
    /// the Setup Viewer (§8.10), not eagerly here: it's a large blob with
    /// 172 top-level keys and nothing else needs it.
    required String carSetupJson,
    /// The file's own format-version stamp. Gated at open time (§5.1).
    required String version,
  }) = _SessionMetadata;

  /// `(trackName, trackLayout)` — the only correct key for grouping sessions
  /// or scoping a personal best (§8.1, §9.6).
  String get trackKey => '$trackName — $trackLayout';

  /// True when the layout name adds information beyond the track name, so UI
  /// can avoid rendering "Spa-Francorchamps — Spa-Francorchamps".
  bool get layoutIsDistinct =>
      trackLayout.isNotEmpty && trackLayout != trackName;
}

/// `metadata.SessionType` (§5.1). Endurance sessions differ enough in what's
/// worth showing — race pace and gaps only make sense for a race (§8.9) —
/// that this is worth typing rather than string-matching per feature.
enum SessionType {
  practice('Practice', 'P'),
  qualify('Qualify', 'Q'),
  race('Race', 'R');

  const SessionType(this.rawValue, this.filenameCode);

  /// Exactly as written in the file.
  final String rawValue;

  /// The letter LMU puts in the filename (§5 — redundant with, not a
  /// separate source from, this value).
  final String filenameCode;

  static SessionType? tryParse(String raw) {
    for (final type in values) {
      if (type.rawValue == raw) return type;
    }
    return null;
  }
}
