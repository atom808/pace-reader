/// One lap of one session (comparison proposal §4, §9).
library;

import '../duckdb/telemetry_database.dart';

/// A lap, named by the file it is in and its `Lap` value — the same pair
/// every per-lap provider is keyed on (`lapTelemetryProvider(source, index)`).
///
/// Compare's Base and Target are each one of these. They can sit in two
/// different files, so a lap index alone no longer says which lap is meant.
/// Equality follows [TelemetrySource]'s, so two spellings of one Windows path
/// are the same lap.
class LapRef {
  const LapRef(this.source, this.lapIndex);

  final TelemetrySource source;

  /// The 0-based `Lap` value (`Lap.index`); shown `+1`.
  final int lapIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LapRef && other.source == source && other.lapIndex == lapIndex);

  @override
  int get hashCode => Object.hash(LapRef, source, lapIndex);

  @override
  String toString() => 'LapRef(${source.label}, lap index $lapIndex)';
}
