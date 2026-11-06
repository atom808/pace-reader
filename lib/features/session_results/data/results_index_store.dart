/// Where the app keeps what it read from LMU's results files (results
/// proposal, R1).
///
/// A cache of the files, rebuildable from them at any time, kept in its own
/// database beside the Session Library's: a change here can never cost the
/// user their remembered folders or "last opened" stamps.
library;

import '../../session_library/data/library_entry.dart';
import '../domain/bop_allowance.dart';
import '../domain/results_link.dart';
import '../domain/results_session.dart';
import '../domain/timing_only.dart';

/// [player]'s brief in [session].
ResultsPlayerSession playerSessionOf(
  String path,
  DateTime indexedAt,
  ResultsSession session,
  ResultsDriver player,
) {
  final pace = paceSummaryOf(player.laps);
  return ResultsPlayerSession(
    path: path,
    kind: session.kind,
    trackVenue: session.trackVenue,
    trackCourse: session.trackCourse,
    startedAt: session.startedAt,
    endsAt: session.endsAt,
    gameVersion: session.gameVersion,
    indexedAt: indexedAt,
    driverIndex: player.index,
    driverName: player.name,
    driverNames: player.driverNames,
    vehicleName: player.vehicleName,
    carClass: player.carClass,
    lapsCompleted: player.lapsCompleted,
    timedLaps: pace.timed,
    bestPaceSeconds: pace.best,
    bestPaceNumber: pace.bestNumber,
  );
}

/// One indexed results file: where it is, its change-detection pair, and when
/// it was read.
class ResultsFileRecord {
  const ResultsFileRecord({
    required this.path,
    required this.file,
    required this.indexedAt,
  });

  final String path;
  final FileFacts file;
  final DateTime indexedAt;
}

/// The results index's persistence seam: drift on desktop
/// ([DriftResultsIndexStore]), memory on web and under `flutter test`
/// ([MemoryResultsIndexStore]).
abstract interface class ResultsIndexStore {
  /// Every indexed file's size and mtime, keyed by path: what a rescan
  /// compares against to skip unchanged files without opening them.
  Future<Map<String, FileFacts>> readFileFacts();

  /// Stores [session] as the content of [record]'s file, replacing whatever
  /// was stored for that path before, in one transaction.
  Future<void> putSession(ResultsFileRecord record, ResultsSession session);

  /// The session stored for [path], whole.
  Future<ResultsSession?> readSession(String path);

  /// Sessions at one track and layout, of one kind, whose time span
  /// overlaps `[from, to]`, with each car's timed laps: what linking a
  /// recording needs, and nothing else.
  Future<List<ResultsCandidate>> candidates({
    required String trackVenue,
    required String trackCourse,
    required ResultsSessionKind kind,
    required DateTime from,
    required DateTime to,
  });

  Future<int> sessionCount();

  /// Every car a human drove (`isPlayer`), in brief. Online, that is every
  /// human in the session, not only the user.
  Future<List<ResultsPlayerSession>> playerSessions();

  /// Each BoP model's median energy share per pace lap, one per model per
  /// file, for files at [trackVenue] that started in [from] .. [to] (`to`
  /// exclusive, open when null): what a session's own shares are checked
  /// against (BoP allowance, PACE-FACTORS §5.7).
  Future<List<EnergyShareSample>> energyShares({
    required String trackVenue,
    required DateTime from,
    DateTime? to,
  });

  /// Remembered results folders, in the order they were added.
  Future<List<LibraryFolder>> readFolders();

  Future<void> upsertFolder(LibraryFolder folder);

  /// Forgets a folder. What was read from it stays: the files may still be
  /// there, and the index is only a cache of them.
  Future<void> removeFolder(String path);

  Future<void> close();
}

/// The web index, and every widget test's.
class MemoryResultsIndexStore implements ResultsIndexStore {
  MemoryResultsIndexStore({Iterable<LibraryFolder> folders = const []}) {
    for (final folder in folders) {
      _folders[folder.path] = folder;
    }
  }

  final _sessions = <String, (ResultsFileRecord, ResultsSession)>{};
  final _folders = <String, LibraryFolder>{};

  @override
  Future<Map<String, FileFacts>> readFileFacts() async => {
    for (final MapEntry(:key, :value) in _sessions.entries) key: value.$1.file,
  };

  @override
  Future<void> putSession(
    ResultsFileRecord record,
    ResultsSession session,
  ) async {
    _sessions[record.path] = (record, session);
  }

  @override
  Future<ResultsSession?> readSession(String path) async => _sessions[path]?.$2;

  @override
  Future<List<ResultsCandidate>> candidates({
    required String trackVenue,
    required String trackCourse,
    required ResultsSessionKind kind,
    required DateTime from,
    required DateTime to,
  }) async => [
    for (final MapEntry(key: path, value: (_, session)) in _sessions.entries)
      if (session.trackVenue == trackVenue &&
          session.trackCourse == trackCourse &&
          session.kind == kind &&
          !session.startedAt.isAfter(to) &&
          !session.endsAt.isBefore(from))
        ResultsCandidate.of(path, session),
  ];

  @override
  Future<int> sessionCount() async => _sessions.length;

  @override
  Future<List<ResultsPlayerSession>> playerSessions() async => [
    for (final MapEntry(key: path, value: (record, s)) in _sessions.entries)
      for (final p in s.drivers)
        if (p.isPlayer) playerSessionOf(path, record.indexedAt, s, p),
  ];

  @override
  Future<List<EnergyShareSample>> energyShares({
    required String trackVenue,
    required DateTime from,
    DateTime? to,
  }) async => [
    for (final MapEntry(key: path, value: (_, s)) in _sessions.entries)
      if (s.trackVenue == trackVenue &&
          !s.startedAt.isBefore(from) &&
          (to == null || s.startedAt.isBefore(to)))
        ...energySharesOf(path, s),
  ];

  @override
  Future<List<LibraryFolder>> readFolders() async => _folders.values.toList();

  @override
  Future<void> upsertFolder(LibraryFolder folder) async {
    _folders[folder.path] = folder;
  }

  @override
  Future<void> removeFolder(String path) async {
    _folders.remove(path);
  }

  @override
  Future<void> close() async {}
}
