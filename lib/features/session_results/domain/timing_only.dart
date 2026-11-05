/// Sessions the user drove that have a results file and no recording
/// (results proposal, R5): most of two years of laps, never recorded.
library;

import '../../../data/models/models.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/data/session_file_system.dart' show baseName;
import 'results_session.dart';

/// The player's car in one results file, in brief: what a library row and a
/// personal best need, without reading the session whole.
class ResultsPlayerSession {
  const ResultsPlayerSession({
    required this.path,
    required this.kind,
    required this.trackVenue,
    required this.trackCourse,
    required this.startedAt,
    required this.endsAt,
    required this.gameVersion,
    required this.indexedAt,
    required this.driverIndex,
    required this.driverName,
    required this.driverNames,
    required this.vehicleName,
    required this.carClass,
    required this.lapsCompleted,
    required this.timedLaps,
    required this.bestPaceSeconds,
    required this.bestPaceNumber,
  });

  final String path;
  final ResultsSessionKind kind;
  final String trackVenue;
  final String trackCourse;
  final DateTime startedAt;

  /// The last lap or event: where the session's span ends.
  final DateTime endsAt;
  final String gameVersion;
  final DateTime indexedAt;
  final int driverIndex;

  /// The car's driver when the file was written.
  final String driverName;

  /// Everyone who drove the car: what tells the user's car apart in an
  /// online file, where every human driver is marked a player.
  final Set<String> driverNames;

  /// `= metadata.CarName` of a recording in this car.
  final String vehicleName;
  final String carClass;
  final int lapsCompleted;

  /// Laps the file gives a time.
  final int timedLaps;

  /// The fastest lap with all three sectors and no stop: the laps a
  /// recording would also call timed and valid.
  final double? bestPaceSeconds;

  /// That lap's 1-based number.
  final int? bestPaceNumber;

  /// As a library row, so the list, its filters, its search and its personal
  /// bests treat it as one more session. Null for a kind the library has no
  /// type for.
  ///
  /// [driverName] is the user, for a car they shared: the file names whoever
  /// drove it last.
  LibraryEntry? toLibraryEntry({String? driverName}) {
    final type = switch (kind) {
      ResultsSessionKind.practice => SessionType.practice,
      ResultsSessionKind.qualify => SessionType.qualify,
      ResultsSessionKind.race => SessionType.race,
      ResultsSessionKind.other => null,
    };
    if (type == null) return null;
    return LibraryEntry(
      path: path,
      fileName: baseName(path),
      kind: LibrarySourceKind.results,
      sizeBytes: 0,
      modifiedMs: 0,
      trackName: trackVenue,
      trackLayout: trackCourse,
      carName: vehicleName,
      carClass: carClass,
      sessionType: type,
      driverName: driverName ?? this.driverName,
      recordingTime: formatRecordingTime(startedAt),
      weather: '',
      formatVersion: '',
      completedLaps: lapsCompleted,
      timedLaps: timedLaps,
      bestLapSeconds: bestPaceSeconds,
      bestLapIndex: bestPaceNumber == null ? null : bestPaceNumber! - 1,
      clockGapCount: 0,
      importedAt: indexedAt,
    );
  }
}

/// [time] the way LMU stamps a recording: `2026-07-07T06_42_17Z`, so a
/// timing-only row sorts and dates exactly as a recorded one does.
String formatRecordingTime(DateTime time) {
  final t = time.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}'
      'T${two(t.hour)}_${two(t.minute)}_${two(t.second)}Z';
}

/// [driver]'s brief from its laps.
({int timed, double? best, int? bestNumber}) paceSummaryOf(
  Iterable<ResultsLap> laps,
) {
  var timed = 0;
  double? best;
  int? bestNumber;
  for (final lap in laps) {
    if (lap.lapSeconds == null) continue;
    timed++;
    if (!lap.hasAllSectors || lap.pit) continue;
    if (best == null || lap.lapSeconds! < best) {
      best = lap.lapSeconds;
      bestNumber = lap.number;
    }
  }
  return (timed: timed, best: best, bestNumber: bestNumber);
}
