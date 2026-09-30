/// The Session Library's persistence seam (SPEC.md §9.6).
library;

import 'library_entry.dart';

/// Where the library keeps its index.
///
/// Deliberately small — rows in, rows out — and deliberately *not* where
/// searching, filtering or ranking happen. Those run in Dart over
/// [readEntries] (see `library_query.dart`), for two reasons:
///
/// - There are two implementations. Desktop keeps a drift (SQLite) file in
///   the app-support directory ([DriftSessionIndexStore]); web keeps
///   [MemorySessionIndexStore]. A filter written as SQL on one and as Dart on
///   the other is two definitions of the same product rule, and they would
///   drift apart.
/// - The index is small. A row is ~20 short fields; even a user with a
///   thousand recordings is a few hundred kilobytes, which a substring match
///   walks in well under a frame — so re-querying per keystroke buys nothing
///   the list in memory does not already have.
abstract interface class SessionIndexStore {
  /// Every indexed session, newest recording first ([compareNewestFirst]).
  Future<List<LibraryEntry>> readEntries();

  Future<LibraryEntry?> readEntry(String path);

  /// Inserts or replaces the row for [LibraryEntry.path].
  Future<void> upsertEntry(LibraryEntry entry);

  /// Forgets a session. Never touches the file itself — the index is a
  /// cache of recordings the user owns, and §3 makes writing to them a
  /// non-goal; deleting one is further still.
  Future<void> removeEntry(String path);

  Future<void> markOpened(String path, DateTime at);

  /// Remembered scan folders, in the order they were added.
  Future<List<LibraryFolder>> readFolders();

  Future<void> upsertFolder(LibraryFolder folder);

  /// Forgets a folder. The sessions indexed from it stay: they are still
  /// sessions the user recorded, and the folder was only how they were found.
  Future<void> removeFolder(String path);

  Future<void> close();
}

/// The web index, and every widget test's.
///
/// **Why web keeps the index in memory rather than in drift-on-wasm.** A
/// persistent browser index would need `sqlite3.wasm` plus a compiled drift
/// worker served next to the app — a second vendored WebAssembly pipeline
/// beside DuckDB-Wasm's (`tool/fetch_web_deps.py`), version-locked to the
/// `sqlite3` package — and it would buy almost nothing, because what the
/// index is *for* does not exist in a browser. A web session is an uploaded
/// byte buffer (§9.2): there is no path to reopen it from on the next visit
/// and no folder to rescan, so a persisted row could only ever say "you once
/// looked at a file you must upload again". What does carry over is the
/// behaviour inside one visit — search, filters and personal bests over
/// everything opened so far — and this store gives the web build exactly
/// that, with the same rules as desktop because the rules live above the
/// store.
class MemorySessionIndexStore implements SessionIndexStore {
  MemorySessionIndexStore({
    Iterable<LibraryEntry> entries = const [],
    Iterable<LibraryFolder> folders = const [],
  }) {
    for (final entry in entries) {
      _entries[entry.path] = entry;
    }
    for (final folder in folders) {
      _folders[folder.path] = folder;
    }
  }

  final _entries = <String, LibraryEntry>{};
  // Insertion-ordered, which is "the order they were added".
  final _folders = <String, LibraryFolder>{};

  @override
  Future<List<LibraryEntry>> readEntries() async =>
      _entries.values.toList()..sort(compareNewestFirst);

  @override
  Future<LibraryEntry?> readEntry(String path) async => _entries[path];

  @override
  Future<void> upsertEntry(LibraryEntry entry) async {
    _entries[entry.path] = entry;
  }

  @override
  Future<void> removeEntry(String path) async {
    _entries.remove(path);
  }

  @override
  Future<void> markOpened(String path, DateTime at) async {
    final entry = _entries[path];
    if (entry != null) _entries[path] = entry.copyWith(lastOpenedAt: at);
  }

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
