/// The desktop Session Library index: a drift (SQLite) database, separate
/// from the `.duckdb` recordings it describes (SPEC.md §9.6).
///
/// Imports only `package:drift/drift.dart`, which is platform-neutral; the
/// native connection is opened in `platform_io.dart`, so nothing here pulls
/// `dart:ffi` into the web build.
library;

import 'package:drift/drift.dart';

import '../../../data/models/models.dart';
import 'library_entry.dart';
import 'session_index_store.dart';

part 'library_database.g.dart';

/// One row per indexed recording, keyed by its path.
///
/// Every `metadata` fact §8.1 lists is a column of its own rather than a JSON
/// blob, so a row can be read by eye in any SQLite browser when a user
/// reports "the library says X" — the index is a cache, and a cache is only
/// trustworthy if it can be checked.
@DataClassName('LibrarySessionRow')
class LibrarySessions extends Table {
  TextColumn get path => text()();
  TextColumn get fileName => text()();

  /// [LibrarySourceKind.name].
  TextColumn get kind => text()();
  IntColumn get sizeBytes => integer()();

  /// See [FileFacts.modifiedMs] — an integer so the change check is exact.
  IntColumn get modifiedMs => integer()();

  TextColumn get trackName => text()();
  TextColumn get trackLayout => text()();
  TextColumn get carName => text()();
  TextColumn get carClass => text()();

  /// `metadata.SessionType` verbatim ([SessionType.rawValue]).
  TextColumn get sessionType => text()();
  TextColumn get driverName => text()();
  TextColumn get recordingTime => text()();
  TextColumn get weather => text()();
  TextColumn get formatVersion => text()();
  IntColumn get completedLaps => integer()();
  IntColumn get timedLaps => integer()();
  RealColumn get bestLapSeconds => real().nullable()();
  IntColumn get bestLapIndex => integer().nullable()();
  IntColumn get clockGapCount => integer()();
  DateTimeColumn get importedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DataClassName('LibraryFolderRow')
class LibraryFolders extends Table {
  TextColumn get path => text()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
  IntColumn get lastScanFileCount => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DriftDatabase(tables: [LibrarySessions, LibraryFolders])
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase(super.executor);

  /// Bump with a `MigrationStrategy.onUpgrade` step whenever a column
  /// changes. The index is rebuildable from the files, but a migration that
  /// drops it would also drop the user's remembered folders and every
  /// "last opened", neither of which the files can give back.
  @override
  int get schemaVersion => 1;
}

/// [SessionIndexStore] over [LibraryDatabase].
class DriftSessionIndexStore implements SessionIndexStore {
  DriftSessionIndexStore(this._db);

  final LibraryDatabase _db;

  @override
  Future<List<LibraryEntry>> readEntries() async {
    final rows = await _db.select(_db.librarySessions).get();
    return rows.map(_toEntry).nonNulls.toList()..sort(compareNewestFirst);
  }

  @override
  Future<LibraryEntry?> readEntry(String path) async {
    final row = await (_db.select(
      _db.librarySessions,
    )..where((t) => t.path.equals(path))).getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  @override
  Future<void> upsertEntry(LibraryEntry entry) =>
      _db.into(_db.librarySessions).insertOnConflictUpdate(_toCompanion(entry));

  @override
  Future<void> removeEntry(String path) =>
      (_db.delete(_db.librarySessions)..where((t) => t.path.equals(path))).go();

  @override
  Future<void> markOpened(String path, DateTime at) =>
      (_db.update(_db.librarySessions)..where((t) => t.path.equals(path)))
          .write(LibrarySessionsCompanion(lastOpenedAt: Value(at)));

  @override
  Future<List<LibraryFolder>> readFolders() async {
    final rows = await (_db.select(
      _db.libraryFolders,
    )..orderBy([(t) => OrderingTerm.asc(t.addedAt)])).get();
    return [
      for (final row in rows)
        LibraryFolder(
          path: row.path,
          addedAt: row.addedAt,
          lastScannedAt: row.lastScannedAt,
          lastScanFileCount: row.lastScanFileCount,
        ),
    ];
  }

  @override
  Future<void> upsertFolder(LibraryFolder folder) => _db
      .into(_db.libraryFolders)
      .insertOnConflictUpdate(
        LibraryFoldersCompanion.insert(
          path: folder.path,
          addedAt: folder.addedAt,
          lastScannedAt: Value(folder.lastScannedAt),
          lastScanFileCount: Value(folder.lastScanFileCount),
        ),
      );

  @override
  Future<void> removeFolder(String path) =>
      (_db.delete(_db.libraryFolders)..where((t) => t.path.equals(path))).go();

  @override
  Future<void> close() => _db.close();

  /// Null for a row whose session type this build does not know — a row
  /// written by a newer build — which is skipped rather than guessed at.
  static LibraryEntry? _toEntry(LibrarySessionRow row) {
    final type = SessionType.tryParse(row.sessionType);
    if (type == null) return null;
    return LibraryEntry(
      path: row.path,
      fileName: row.fileName,
      kind:
          LibrarySourceKind.values.asNameMap()[row.kind] ??
          LibrarySourceKind.file,
      sizeBytes: row.sizeBytes,
      modifiedMs: row.modifiedMs,
      trackName: row.trackName,
      trackLayout: row.trackLayout,
      carName: row.carName,
      carClass: row.carClass,
      sessionType: type,
      driverName: row.driverName,
      recordingTime: row.recordingTime,
      weather: row.weather,
      formatVersion: row.formatVersion,
      completedLaps: row.completedLaps,
      timedLaps: row.timedLaps,
      bestLapSeconds: row.bestLapSeconds,
      bestLapIndex: row.bestLapIndex,
      clockGapCount: row.clockGapCount,
      importedAt: row.importedAt,
      lastOpenedAt: row.lastOpenedAt,
    );
  }

  static LibrarySessionsCompanion _toCompanion(LibraryEntry e) =>
      LibrarySessionsCompanion.insert(
        path: e.path,
        fileName: e.fileName,
        kind: e.kind.name,
        sizeBytes: e.sizeBytes,
        modifiedMs: e.modifiedMs,
        trackName: e.trackName,
        trackLayout: e.trackLayout,
        carName: e.carName,
        carClass: e.carClass,
        sessionType: e.sessionType.rawValue,
        driverName: e.driverName,
        recordingTime: e.recordingTime,
        weather: e.weather,
        formatVersion: e.formatVersion,
        completedLaps: e.completedLaps,
        timedLaps: e.timedLaps,
        bestLapSeconds: Value(e.bestLapSeconds),
        bestLapIndex: Value(e.bestLapIndex),
        clockGapCount: e.clockGapCount,
        importedAt: e.importedAt,
        lastOpenedAt: Value(e.lastOpenedAt),
      );
}
