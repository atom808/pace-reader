/// Indexing a folder of recordings (SPEC.md §8.1: "a scan/watch location").
library;

import 'package:file_picker/file_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../data/library_entry.dart';
import '../data/session_file_system.dart';
import 'session_library.dart';

part 'folder_scan.g.dart';

/// Scans remembered folders and adds what it finds to the library.
///
/// On demand — "Add folder" and "Refresh" — rather than a filesystem
/// watcher. A watcher would pick up a recording LMU is still writing, whose
/// `Lap` table grows until the session ends, and index it half-finished; and
/// a rescan that skips unchanged files is cheap enough that pressing Refresh
/// after a session costs a second, not a minute.
///
/// Kept alive so a scan keeps going, and keeps reporting, when the user
/// navigates to another screen mid-way.
@Riverpod(keepAlive: true)
class FolderScan extends _$FolderScan {
  bool _stopRequested = false;

  @override
  FolderScanState build() => const FolderScanIdle();

  bool get isRunning => state is FolderScanRunning;

  /// Asks for a folder, remembers it, and scans it.
  ///
  /// On Windows the chooser opens on LMU's default folder when it exists
  /// (§5), since that is where nearly every user's recordings are.
  Future<void> pickAndScan() async {
    if (isRunning) return;
    final fs = ref.read(sessionFileSystemProvider);
    final String? folder;
    try {
      folder = await FilePicker.getDirectoryPath(
        dialogTitle: 'Choose a folder of Le Mans Ultimate recordings',
        initialDirectory: await fs.suggestedTelemetryFolder(),
      );
    } on Object catch (error) {
      state = FolderScanFailed(
        message: 'The folder chooser could not be opened.',
        detail: '$error',
      );
      return;
    }
    if (folder == null) return;
    await addAndScan(folder);
  }

  /// Remembers [folder] and scans it — also the one-click path for the
  /// suggested LMU folder.
  Future<void> addAndScan(String folder) async {
    if (isRunning) return;
    await ref.read(libraryFoldersProvider.notifier).add(folder);
    await scan([folder]);
  }

  /// Rescans every remembered folder.
  Future<void> refreshAll() async {
    if (isRunning) return;
    final folders = await ref.read(libraryFoldersProvider.future);
    await scan([for (final f in folders) f.path]);
  }

  /// Stops after the file being read now. Everything already indexed stays.
  void stop() {
    if (isRunning) _stopRequested = true;
  }

  void dismiss() {
    if (!isRunning) state = const FolderScanIdle();
  }

  /// Indexes every `*.duckdb` in [folders], skipping files whose size and
  /// mtime match the index.
  ///
  /// Sequential by design. Each file is opened read-only, read, and closed
  /// before the next one (see [readSessionFactsBriefly]), so at most one
  /// extra connection exists at a time; reading several at once would trade
  /// that guarantee for a speed-up on a job that already takes milliseconds
  /// per file.
  ///
  /// A file that fails is reported by name with the reason, not skipped
  /// silently — a scan that says "12 indexed" when there were 13 recordings
  /// is exactly the silent cap the app promises not to have. It is retried
  /// on the next scan, since nothing is recorded for it.
  Future<void> scan(List<String> folders) async {
    if (isRunning || folders.isEmpty) return;
    _stopRequested = false;
    final fs = ref.read(sessionFileSystemProvider);
    final store = ref.read(sessionIndexStoreProvider);
    final read = ref.read(sessionFactsReaderProvider);
    final library = ref.read(sessionLibraryProvider.notifier);
    final clock = ref.read(libraryClockProvider);

    // What the index already holds, matched on the canonical path: a file
    // indexed under another spelling (a drive letter's case, a separator) is
    // refreshed in its row rather than indexed twice. Read once, not per file.
    final indexed = {
      for (final e in await store.readEntries())
        if (e.kind == LibrarySourceKind.file) canonicalSessionPath(e.path): e,
    };

    final summary = FolderScanSummaryBuilder(folders);
    // Listed up front, all folders, so the progress bar has a true
    // denominator from the first file rather than resetting per folder.
    final work = <(String folder, String file)>[];
    for (final folder in folders) {
      try {
        final files = await fs.listTelemetryFiles(folder);
        summary.foundIn(folder, files.length);
        work.addAll([for (final file in files) (folder, file)]);
      } on Object catch (error) {
        summary.unreadableFolder(folder, _describe(error));
      }
    }

    for (var i = 0; i < work.length; i++) {
      if (_stopRequested) {
        summary.stoppedWith(work.length - i);
        break;
      }
      final (_, file) = work[i];
      state = FolderScanRunning(
        folders: folders,
        done: i,
        total: work.length,
        currentFile: baseName(file),
      );
      try {
        final facts = await fs.stat(file);
        if (facts == null) {
          summary.failed(file, 'it disappeared during the scan');
          continue;
        }
        final key = canonicalSessionPath(file);
        final previous = indexed[key];
        if (previous != null && facts.matches(previous)) {
          summary.unchanged++;
          continue;
        }
        final path = previous?.path ?? file;
        final entry = LibraryEntry.derive(
          path: path,
          fileName: baseName(path),
          kind: LibrarySourceKind.file,
          file: facts,
          facts: await read(TelemetrySource.path(file)),
          now: clock(),
          previous: previous,
        );
        // Written one at a time, so the list fills in as the scan goes
        // instead of all at once at the end.
        await library.record(entry);
        indexed[key] = entry;
        previous == null ? summary.added++ : summary.updated++;
      } on Object catch (error) {
        summary.failed(file, _describe(error));
      }
    }

    final folderNotifier = ref.read(libraryFoldersProvider.notifier);
    for (final (folder, count) in summary.fileCounts) {
      await folderNotifier.markScanned(folder, fileCount: count);
    }
    // Rows check their file with a `stat` when built and then keep the
    // answer. A rescan is the moment the user asks "what is on disk now", so
    // it is also when the rows that said "file not found" — or "present" —
    // are asked again.
    ref.invalidate(libraryFileStatusProvider);
    state = FolderScanFinished(summary.build());
  }

  /// The data layer's messages are written for a user (§10); anything else
  /// is described by its type rather than dumped whole into a banner.
  static String _describe(Object error) => switch (error) {
    TelemetryException(:final message) => message,
    _ => '$error',
  };
}

/// What the scan banner shows.
sealed class FolderScanState {
  const FolderScanState();
}

final class FolderScanIdle extends FolderScanState {
  const FolderScanIdle();
}

final class FolderScanRunning extends FolderScanState {
  const FolderScanRunning({
    required this.folders,
    required this.done,
    required this.total,
    required this.currentFile,
  });

  final List<String> folders;
  final int done;
  final int total;
  final String currentFile;

  double get progress => total == 0 ? 0 : done / total;
}

final class FolderScanFinished extends FolderScanState {
  const FolderScanFinished(this.summary);

  final FolderScanSummary summary;
}

final class FolderScanFailed extends FolderScanState {
  const FolderScanFailed({required this.message, required this.detail});

  final String message;
  final String detail;
}

/// One file the scan could not index, and why.
typedef ScanFailure = ({String fileName, String reason});

/// The outcome of one scan, every file accounted for.
class FolderScanSummary {
  const FolderScanSummary({
    required this.folders,
    required this.found,
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.failures,
    required this.unreadableFolders,
    required this.notReached,
  });

  final List<String> folders;

  /// `.duckdb` files found across [folders].
  final int found;
  final int added;
  final int updated;

  /// Skipped because size and mtime matched the index.
  final int unchanged;
  final List<ScanFailure> failures;
  final List<({String folder, String reason})> unreadableFolders;

  /// Files left unread because the scan was stopped.
  final int notReached;

  bool get hasProblems =>
      failures.isNotEmpty || unreadableFolders.isNotEmpty || notReached > 0;
}

/// Accumulates a [FolderScanSummary] as the scan walks.
class FolderScanSummaryBuilder {
  FolderScanSummaryBuilder(this.folders);

  final List<String> folders;
  final fileCounts = <(String, int)>[];
  int added = 0;
  int updated = 0;
  int unchanged = 0;
  int _notReached = 0;
  final _failures = <ScanFailure>[];
  final _unreadable = <({String folder, String reason})>[];

  void foundIn(String folder, int count) => fileCounts.add((folder, count));

  void unreadableFolder(String folder, String reason) =>
      _unreadable.add((folder: folder, reason: reason));

  void failed(String file, String reason) =>
      _failures.add((fileName: baseName(file), reason: reason));

  void stoppedWith(int remaining) => _notReached = remaining;

  FolderScanSummary build() => FolderScanSummary(
    folders: folders,
    found: fileCounts.fold(0, (sum, c) => sum + c.$2),
    added: added,
    updated: updated,
    unchanged: unchanged,
    failures: List.unmodifiable(_failures),
    unreadableFolders: List.unmodifiable(_unreadable),
    notReached: _notReached,
  );
}
