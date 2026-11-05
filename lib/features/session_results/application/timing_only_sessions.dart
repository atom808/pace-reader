/// The library's timing-only rows (results proposal, R5): results files the
/// player drove in that no recording in the library was made in.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../session_library/application/session_library.dart';
import '../../session_library/data/library_entry.dart';
import '../domain/results_link.dart';
import '../domain/timing_only.dart';
import 'session_results.dart';

part 'timing_only_sessions.g.dart';

/// Timing-only rows, and what their chips need.
class TimingOnlySessions {
  const TimingOnlySessions({
    required this.entries,
    required this.gameVersions,
    required this.newestGameVersion,
  });

  static const none = TimingOnlySessions(
    entries: [],
    gameVersions: {},
    newestGameVersion: null,
  );

  final List<LibraryEntry> entries;

  /// Each row's `GameVersion`, by path.
  final Map<String, String> gameVersions;

  /// The version of the newest results file: what "≠ game version" is
  /// measured from.
  final String? newestGameVersion;

  /// Whether [entry] was driven on another game version than the newest:
  /// physics and track builds change between versions, so its times may
  /// not compare.
  bool otherVersion(LibraryEntry entry) {
    final version = gameVersions[entry.path];
    return version != null &&
        version.isNotEmpty &&
        newestGameVersion != null &&
        version != newestGameVersion;
  }
}

/// Whether [recording] was made in [session]: same place, kind and car, and
/// started within the session's span (the first two of [linkRecording]'s
/// rules). The lap check is left out on purpose: it decides between two
/// files for one recording, and here the question is only whether a file
/// has a recording at all.
bool recordedIn(LibraryEntry recording, ResultsPlayerSession session) {
  final at = recording.recordedAt;
  return at != null &&
      recording.trackName == session.trackVenue &&
      recording.trackLayout == session.trackCourse &&
      resultsKindOf(recording.sessionType) == session.kind &&
      recording.carName == session.vehicleName &&
      recording.carClass == session.carClass &&
      !at.isBefore(session.startedAt.subtract(resultsLinkEarlySlack)) &&
      !at.isAfter(session.endsAt.add(resultsLinkLateSlack));
}

/// The user's car in each file.
///
/// A file in the user's own log with one human car in it is the user's:
/// offline, or alone on a server. Its driver is who the user is, under every
/// name they have raced as. Online, every human is marked a player, so the
/// user's car is the one one of those names drove. Only with no such file to
/// learn from are [recordingNames] used instead: the library can hold other
/// people's recordings, so they are the weaker evidence.
Iterable<({ResultsPlayerSession car, String driver})> userCars(
  List<ResultsPlayerSession> humans,
  Set<String> recordingNames,
) sync* {
  final byFile = <String, List<ResultsPlayerSession>>{};
  for (final h in humans) {
    (byFile[h.path] ??= []).add(h);
  }
  final alone = {
    for (final cars in byFile.values)
      if (cars.length == 1) ...cars.single.driverNames,
  };
  final names = alone.isNotEmpty ? alone : recordingNames;
  for (final cars in byFile.values) {
    if (cars.length == 1 && alone.isNotEmpty) {
      yield (car: cars.single, driver: cars.single.driverName);
    } else if (cars.where((c) => c.driverNames.any(names.contains)).firstOrNull
        case final mine?) {
      yield (car: mine, driver: mine.driverNames.firstWhere(names.contains));
    }
  }
}

/// Empty until a results folder has been added.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TimingOnlySessions> timingOnlySessions(Ref ref) async {
  ref.watch(resultsIndexRevisionProvider);
  final folders = await ref.watch(resultsFoldersProvider.future);
  if (folders.isEmpty) return TimingOnlySessions.none;
  final store = ref.watch(resultsIndexStoreProvider);
  final library = await ref.watch(sessionLibraryProvider.future);
  final players = await store.playerSessions();

  final recordings = <String, List<LibraryEntry>>{};
  // Who the user is: the names their recordings were made under. Online,
  // every human in a file is marked a player, so this is what finds the
  // user's car among them.
  final names = <String>{};
  for (final e in library) {
    if (e.kind == LibrarySourceKind.results) continue;
    (recordings['${e.trackName}\u0000${e.trackLayout}'] ??= []).add(e);
    if (e.driverName.isNotEmpty) names.add(e.driverName);
  }

  final entries = <LibraryEntry>[];
  final versions = <String, String>{};
  ResultsPlayerSession? newest;
  for (final (car: p, :driver) in userCars(players, names)) {
    if (newest == null || p.startedAt.isAfter(newest.startedAt)) newest = p;
    // A car that never completed or timed a lap was entered, not driven.
    if (p.lapsCompleted == 0 && p.timedLaps == 0) continue;
    final here = recordings['${p.trackVenue}\u0000${p.trackCourse}'];
    if (here != null && here.any((r) => recordedIn(r, p))) continue;
    final entry = p.toLibraryEntry(driverName: driver);
    if (entry == null) continue;
    entries.add(entry);
    versions[p.path] = p.gameVersion;
  }
  return TimingOnlySessions(
    entries: entries,
    gameVersions: versions,
    newestGameVersion: newest?.gameVersion,
  );
}

Duration? _neverRetry(int retryCount, Object error) => null;
