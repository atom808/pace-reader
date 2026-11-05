/// The results index's state: its folders, the scan that fills it, and the
/// link from each recording to its session (results proposal, R1).
library;

import 'package:flutter/foundation.dart' show compute;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart' show canonicalSessionPath;
import '../../session_library/application/session_library.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/data/session_file_system.dart' show baseName;
import '../data/platform.dart';
import '../data/results_file_system.dart';
import '../data/results_index_store.dart';
import '../data/results_xml.dart';
import '../domain/results_link.dart';
import '../domain/results_session.dart';

part 'session_results.g.dart';

/// Every failure here is deterministic (a folder that can't be read, a file
/// that isn't results), so retrying on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true)
ResultsIndexStore resultsIndexStore(Ref ref) {
  final store = openPlatformResultsIndexStore();
  ref.onDispose(store.close);
  return store;
}

@Riverpod(keepAlive: true)
ResultsFileSystem resultsFileSystem(Ref ref) => platformResultsFileSystem();

/// Turns a file's bytes into a session.
typedef ResultsParser = Future<ResultsSession> Function(List<int> bytes);

/// [parseResultsBytes] on another isolate: the 24-hour race's 8.6 MB takes
/// half a second to parse, which would be thirty dropped frames on the UI
/// thread. A provider so a widget test can parse in its own zone.
@Riverpod(keepAlive: true)
ResultsParser resultsParser(Ref ref) =>
    (bytes) => compute(parseResultsBytes, bytes);

ResultsSession parseResultsBytes(List<int> bytes) =>
    parseResultsXml(decodeResultsBytes(bytes));

/// Moves whenever the index's content does, so everything read from it
/// (each row's link) is read again. Bumped once per scan, not per file: a
/// thousand files would otherwise re-link every visible row a thousand times.
@Riverpod(keepAlive: true)
class ResultsIndexRevision extends _$ResultsIndexRevision {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Remembered results folders, oldest first.
@Riverpod(keepAlive: true, retry: _neverRetry)
class ResultsFolders extends _$ResultsFolders {
  ResultsIndexStore get _store => ref.read(resultsIndexStoreProvider);

  @override
  Future<List<LibraryFolder>> build() =>
      ref.watch(resultsIndexStoreProvider).readFolders();

  Future<void> add(String path) async {
    final known = await _store.readFolders();
    if (known.any((f) => _same(f.path, path))) return;
    await _store.upsertFolder(
      LibraryFolder(path: path, addedAt: ref.read(libraryClockProvider)()),
    );
    await _reload();
  }

  Future<void> markScanned(String path, {required int fileCount}) async {
    final known = await _store.readFolders();
    final folder = known.where((f) => f.path == path).firstOrNull;
    if (folder == null) return;
    await _store.upsertFolder(
      folder.scanned(
        at: ref.read(libraryClockProvider)(),
        fileCount: fileCount,
      ),
    );
    await _reload();
  }

  /// Forgets the folder. What was read from it stays in the index.
  Future<void> remove(String path) async {
    await _store.removeFolder(path);
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(_store.readFolders);
  }
}

bool _same(String a, String b) =>
    canonicalSessionPath(a) == canonicalSessionPath(b);

/// LMU's results folder, when it exists and isn't remembered yet: the one
/// beside a remembered telemetry folder of the same install first, then
/// the default Steam location.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<String?> suggestedResultsFolder(Ref ref) async {
  final fs = ref.watch(resultsFileSystemProvider);
  final known = await ref.watch(resultsFoldersProvider.future);
  final telemetry = await ref.watch(libraryFoldersProvider.future);
  final options = <String>{
    for (final f in telemetry) ?resultsFolderBeside(f.path),
    lmuDefaultResultsFolder,
  };
  for (final option in options) {
    if (known.any((f) => _same(f.path, option))) continue;
    if (await fs.folderExists(option)) return option;
  }
  return null;
}

/// The results session [entry]'s recording was made in, or null.
///
/// Checked per row when the row is built, like the file's status: a store
/// query narrowed to one track, one kind and a few minutes, then
/// [linkRecording]. No recording is opened.
@Riverpod(retry: _neverRetry)
Future<ResultsLink?> resultsLink(Ref ref, LibraryEntry entry) {
  ref.watch(resultsIndexRevisionProvider);
  return findResultsLink(
    ref.watch(resultsIndexStoreProvider),
    RecordingKey.ofEntry(entry),
  );
}

/// [linkRecording] over the candidates [store] narrows [key] to.
Future<ResultsLink?> findResultsLink(
  ResultsIndexStore store,
  RecordingKey key,
) async {
  final window = resultsWindowFor(key);
  if (window == null) return null;
  final candidates = await store.candidates(
    trackVenue: key.trackName,
    trackCourse: key.trackLayout,
    kind: resultsKindOf(key.sessionType),
    from: window.from,
    to: window.to,
  );
  return linkRecording(key, candidates);
}

/// Reads remembered results folders into the index.
///
/// On demand, like the telemetry scan: when the folder is added and on
/// Refresh. LMU writes a results file once, when a session ends, so there is
/// nothing to watch for. Files whose size and mtime match the index are
/// skipped without being opened, so a Refresh after one session reads one
/// file.
@Riverpod(keepAlive: true)
class ResultsScan extends _$ResultsScan {
  bool _stopRequested = false;

  @override
  ResultsScanState build() => const ResultsScanIdle();

  bool get isRunning => state is ResultsScanRunning;

  Future<void> addAndScan(String folder) async {
    if (isRunning) return;
    await ref.read(resultsFoldersProvider.notifier).add(folder);
    await scan([folder]);
  }

  Future<void> refreshAll() async {
    if (isRunning) return;
    final folders = await ref.read(resultsFoldersProvider.future);
    await scan([for (final f in folders) f.path]);
  }

  /// Stops after the file being read now. What was read stays.
  void stop() {
    if (isRunning) _stopRequested = true;
  }

  /// Indexes every `*.xml` in [folders], newest first, so the sessions a
  /// user is most likely to open link first.
  ///
  /// A file that fails is named with its reason in the summary, and retried
  /// on the next scan, since nothing is stored for it.
  Future<void> scan(List<String> folders) async {
    if (isRunning || folders.isEmpty) return;
    _stopRequested = false;
    final fs = ref.read(resultsFileSystemProvider);
    final store = ref.read(resultsIndexStoreProvider);
    final parse = ref.read(resultsParserProvider);
    final clock = ref.read(libraryClockProvider);

    final known = await store.readFileFacts();
    final counts = <(String, int)>[];
    final unreadable = <({String folder, String reason})>[];
    final work = <String>[];
    for (final folder in folders) {
      try {
        final files = await fs.listResultsFiles(folder);
        counts.add((folder, files.length));
        work.addAll(files);
      } on Object catch (error) {
        unreadable.add((folder: folder, reason: '$error'));
      }
    }

    var added = 0, updated = 0, unchanged = 0, notReached = 0;
    final failures = <ResultsScanFailure>[];
    for (var i = 0; i < work.length; i++) {
      if (_stopRequested) {
        notReached = work.length - i;
        break;
      }
      final file = work[i];
      state = ResultsScanRunning(
        done: i,
        total: work.length,
        currentFile: baseName(file),
      );
      try {
        final facts = await fs.stat(file);
        if (facts == null) {
          failures.add((fileName: baseName(file), reason: 'it disappeared'));
          continue;
        }
        final previous = known[file];
        if (previous == facts) {
          unchanged++;
          continue;
        }
        final session = await parse(await fs.readBytes(file));
        await store.putSession(
          ResultsFileRecord(path: file, file: facts, indexedAt: clock()),
          session.forIndex(),
        );
        previous == null ? added++ : updated++;
      } on Object catch (error) {
        failures.add((fileName: baseName(file), reason: '$error'));
      }
    }

    final folderNotifier = ref.read(resultsFoldersProvider.notifier);
    for (final (folder, count) in counts) {
      await folderNotifier.markScanned(folder, fileCount: count);
    }
    ref.read(resultsIndexRevisionProvider.notifier).bump();
    state = ResultsScanFinished(
      ResultsScanSummary(
        found: work.length,
        added: added,
        updated: updated,
        unchanged: unchanged,
        failures: List.unmodifiable(failures),
        unreadableFolders: List.unmodifiable(unreadable),
        notReached: notReached,
      ),
    );
  }
}

sealed class ResultsScanState {
  const ResultsScanState();
}

final class ResultsScanIdle extends ResultsScanState {
  const ResultsScanIdle();
}

final class ResultsScanRunning extends ResultsScanState {
  const ResultsScanRunning({
    required this.done,
    required this.total,
    required this.currentFile,
  });

  final int done;
  final int total;
  final String currentFile;

  double get progress => total == 0 ? 0 : done / total;
}

final class ResultsScanFinished extends ResultsScanState {
  const ResultsScanFinished(this.summary);

  final ResultsScanSummary summary;
}

/// One file the scan could not read, and why.
typedef ResultsScanFailure = ({String fileName, String reason});

class ResultsScanSummary {
  const ResultsScanSummary({
    required this.found,
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.failures,
    required this.unreadableFolders,
    required this.notReached,
  });

  final int found;
  final int added;
  final int updated;
  final int unchanged;
  final List<ResultsScanFailure> failures;
  final List<({String folder, String reason})> unreadableFolders;
  final int notReached;

  bool get hasProblems =>
      failures.isNotEmpty || unreadableFolders.isNotEmpty || notReached > 0;
}
