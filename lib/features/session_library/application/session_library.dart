/// The Session Library's state: the persistent index, its folders, and the
/// filter over it (SPEC.md §8.1, §9.6).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_repository.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/session_repository.dart';
import '../data/library_entry.dart';
import '../data/platform.dart';
import '../data/session_file_system.dart';
import '../data/session_index_store.dart';
import 'library_query.dart';

part 'session_library.g.dart';

/// See `providers.dart`: every failure here is deterministic — an index that
/// cannot be opened, a file that is not telemetry — so retrying on a timer
/// only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The index's storage: drift on desktop, memory on web (see
/// [MemorySessionIndexStore] for why). Overridden in tests.
@Riverpod(keepAlive: true)
SessionIndexStore sessionIndexStore(Ref ref) {
  final store = openPlatformSessionIndexStore();
  ref.onDispose(store.close);
  return store;
}

@Riverpod(keepAlive: true)
SessionFileSystem sessionFileSystem(Ref ref) => platformSessionFileSystem();

/// Reads what an index row needs from a file that is *not* open.
typedef SessionFactsReader = Future<SessionFacts> Function(
  TelemetrySource source,
);

/// The folder scan's reader: [readSessionFactsBriefly]. A provider so a test
/// can hand the scan real numbers without a DuckDB connection.
@Riverpod(keepAlive: true)
SessionFactsReader sessionFactsReader(Ref ref) => readSessionFactsBriefly;

/// "Now", injectable so "scanned 3 min ago" and `importedAt` are
/// deterministic under test.
@Riverpod(keepAlive: true)
DateTime Function() libraryClock(Ref ref) => DateTime.now;

/// Opens [source] read-only just long enough to read its index facts, then
/// closes it.
///
/// Deliberately *not* through `telemetrySessionProvider`: that provider is
/// kept alive by design (the family key is the open file), so a folder scan
/// routed through it would leave one DuckDB connection open per recording in
/// the folder — dozens, for a season of LMU sessions. Here the connection
/// lives for one `openTelemetrySession` + one lap read and is disposed in a
/// `finally`, whatever happens.
///
/// It runs the same open-time checks an import does (schema, `Version`,
/// catalog, clock scan), so the library can never list a file that would
/// then refuse to open.
Future<SessionFacts> readSessionFactsBriefly(TelemetrySource source) async {
  final session = await openTelemetrySession(source);
  try {
    final laps = await LapRepository(session.database).readLaps();
    return SessionFacts(
      metadata: session.metadata,
      laps: laps,
      clockGapCount: session.clockGaps.length,
    );
  } finally {
    await session.dispose();
  }
}

/// Every indexed session, newest recording first.
@Riverpod(keepAlive: true, retry: _neverRetry)
class SessionLibrary extends _$SessionLibrary {
  SessionIndexStore get _store => ref.read(sessionIndexStoreProvider);

  @override
  Future<List<LibraryEntry>> build() =>
      ref.watch(sessionIndexStoreProvider).readEntries();

  /// Writes or refreshes the row for a session that is open right now.
  ///
  /// Built from the providers the open session already fills — metadata,
  /// laps, clock gaps — so indexing at import costs no extra read of the
  /// file (§9.6: "populate/update this index at import time"), and a widget
  /// test can index a session by overriding those three.
  ///
  /// Returns null when a path source's file has gone from disk between
  /// opening and indexing, where there is no honest size/mtime to record.
  Future<LibraryEntry?> recordOpened(TelemetrySource source) async {
    final metadata = await ref.read(sessionMetadataProvider(source).future);
    final laps = await ref.read(lapsProvider(source).future);
    final gaps = await ref.read(sessionClockGapsProvider(source).future);

    final (key, kind, file) = switch (source) {
      FileTelemetrySource(:final path) => (
        path,
        LibrarySourceKind.file,
        await ref.read(sessionFileSystemProvider).stat(path),
      ),
      BytesTelemetrySource(:final name, :final bytes) => (
        name,
        LibrarySourceKind.upload,
        FileFacts(sizeBytes: bytes.length, modifiedMs: 0),
      ),
    };
    if (file == null) return null;

    final now = ref.read(libraryClockProvider)();
    final entry = LibraryEntry.derive(
      path: key,
      fileName: baseName(key),
      kind: kind,
      file: file,
      facts: SessionFacts(
        metadata: metadata,
        laps: laps,
        clockGapCount: gaps.length,
      ),
      now: now,
      previous: await _store.readEntry(key),
      openedAt: now,
    );
    await _store.upsertEntry(entry);
    await reload();
    return entry;
  }

  /// Writes a row the folder scan built.
  Future<void> record(LibraryEntry entry) async {
    await _store.upsertEntry(entry);
    await reload();
  }

  /// Forgets a session. The file on disk is never touched.
  Future<void> remove(String path) async {
    await _store.removeEntry(path);
    await reload();
  }

  /// Re-reads the store without a loading flash: the previous list stays on
  /// screen until the new one replaces it, which is what lets rows animate
  /// in and out rather than the whole list blinking.
  Future<void> reload() async {
    state = await AsyncValue.guard(_store.readEntries);
  }
}

/// Remembered scan folders, oldest first.
@Riverpod(keepAlive: true, retry: _neverRetry)
class LibraryFolders extends _$LibraryFolders {
  SessionIndexStore get _store => ref.read(sessionIndexStoreProvider);

  @override
  Future<List<LibraryFolder>> build() =>
      ref.watch(sessionIndexStoreProvider).readFolders();

  /// Remembers [path], keeping what was known if it is already there.
  Future<void> add(String path) async {
    final known = await _store.readFolders();
    if (known.any((f) => f.path == path)) return;
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

  /// Forgets a folder; its sessions stay in the library.
  Future<void> remove(String path) async {
    await _store.removeFolder(path);
    await _reload();
  }

  Future<void> _reload() async {
    state = await AsyncValue.guard(_store.readFolders);
  }
}

/// The search box and chips. Kept alive so leaving for the Overview and
/// coming back finds the list as it was left.
@Riverpod(keepAlive: true)
class LibraryFilter extends _$LibraryFilter {
  @override
  LibraryQuery build() => const LibraryQuery();

  void setSearch(String text) => state = state.copyWith(search: text);

  void toggleSessionType(SessionType type) =>
      state = state.copyWith(sessionTypes: _toggle(state.sessionTypes, type));

  void toggleCarClass(String carClass) =>
      state = state.copyWith(carClasses: _toggle(state.carClasses, carClass));

  void toggleTrack(TrackLayoutKey track) =>
      state = state.copyWith(tracks: _toggle(state.tracks, track));

  /// Clears the chips and the search together — "show me everything".
  void clear() => state = const LibraryQuery();

  static Set<T> _toggle<T>(Set<T> set, T value) =>
      set.contains(value) ? ({...set}..remove(value)) : {...set, value};
}

/// What the library list renders: the filtered rows, plus what the chips and
/// badges need from the *whole* library.
class LibraryView {
  const LibraryView({
    required this.all,
    required this.visible,
    required this.query,
    required this.facets,
    required this.personalBests,
  });

  factory LibraryView.of(List<LibraryEntry> all, LibraryQuery query) =>
      LibraryView(
        all: all,
        visible: applyLibraryQuery(all, query),
        query: query,
        facets: LibraryFacets.from(all),
        personalBests: personalBestsOf(all),
      );

  final List<LibraryEntry> all;
  final List<LibraryEntry> visible;
  final LibraryQuery query;
  final LibraryFacets facets;
  final Map<PersonalBestKey, PersonalBest> personalBests;

  /// The best [entry] holds, or null if it holds none.
  PersonalBest? personalBestHeldBy(LibraryEntry entry) {
    final best = personalBests[entry.personalBestKey];
    return best != null && best.path == entry.path ? best : null;
  }
}

/// Synchronous over the library's [AsyncValue] rather than a
/// `FutureProvider`, so a keystroke in the search box re-filters in the same
/// frame instead of passing through a loading state first.
@Riverpod(keepAlive: true)
AsyncValue<LibraryView> libraryView(Ref ref) {
  final query = ref.watch(libraryFilterProvider);
  return ref
      .watch(sessionLibraryProvider)
      .whenData((all) => LibraryView.of(all, query));
}

/// Whether an indexed file is still where the index says.
enum LibraryFileStatus {
  /// On disk, with the size and mtime it was indexed at.
  present,

  /// On disk but rewritten since — reopening re-reads it.
  changed,

  /// Nothing at the path any more: moved, renamed or deleted.
  missing,

  /// An upload, which has no path to check (web).
  notOnDisk,
}

/// Checked per row, lazily, when the row is built — a `stat`, never an open.
///
/// Family-keyed on the entry itself rather than its path, so re-indexing a
/// file (a new size/mtime) is a new key and the status is re-checked rather
/// than served stale.
@Riverpod(retry: _neverRetry)
Future<LibraryFileStatus> libraryFileStatus(Ref ref, LibraryEntry entry) async {
  if (entry.kind == LibrarySourceKind.upload) {
    return LibraryFileStatus.notOnDisk;
  }
  final facts = await ref.watch(sessionFileSystemProvider).stat(entry.path);
  if (facts == null) return LibraryFileStatus.missing;
  return facts.matches(entry)
      ? LibraryFileStatus.present
      : LibraryFileStatus.changed;
}

/// LMU's default folder, when it exists here and isn't remembered yet.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<String?> suggestedTelemetryFolder(Ref ref) async {
  final fs = ref.watch(sessionFileSystemProvider);
  if (!fs.supportsFolders) return null;
  final suggestion = await fs.suggestedTelemetryFolder();
  if (suggestion == null) return null;
  final folders = await ref.watch(libraryFoldersProvider.future);
  return folders.any((f) => f.path == suggestion) ? null : suggestion;
}
