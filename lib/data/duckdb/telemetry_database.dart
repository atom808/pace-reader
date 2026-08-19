/// Connection lifecycle and the desktop/web asymmetry (SPEC.md §9.2).
///
/// The only sanctioned platform difference in this app is *how* a file gets
/// opened — a path on desktop, bytes on web, since browsers can't open an
/// arbitrary filesystem path (§10). That difference is confined to
/// [TelemetrySource] and [TelemetryDatabase.open] so no feature, repository,
/// or query ever branches on platform.
library;

import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';

import '../../core/errors.dart';

/// The narrow query surface the repositories depend on.
///
/// Deliberately one method wide, and deliberately *not* `Connection`.
/// `dart_duckdb`'s native library is linked into a compiled app via
/// CocoaPods/CMake, not into the bare `flutter test` process — so a plain
/// unit test can never hold a real connection. Repositories therefore depend
/// on this instead, which a fake can implement in a few lines, keeping
/// repository logic testable without a device.
abstract interface class TelemetryQueryExecutor {
  /// Runs [sql] and returns all rows. Throws [TelemetryQueryException] on
  /// failure, with the statement attached.
  Future<List<List<Object?>>> rows(String sql);
}

/// Convenience reads over [TelemetryQueryExecutor].
extension TelemetryQueryExecutorReads on TelemetryQueryExecutor {
  /// The first row, or null when the result is empty.
  Future<List<Object?>?> firstRow(String sql) async {
    final result = await rows(sql);
    return result.isEmpty ? null : result.first;
  }

  /// The single value of a one-row, one-column result, or null if no rows.
  Future<Object?> scalar(String sql) async {
    final row = await firstRow(sql);
    return (row == null || row.isEmpty) ? null : row.first;
  }
}

/// Where a session's bytes come from.
sealed class TelemetrySource {
  const TelemetrySource();

  /// A filesystem path — desktop only, from a file picker or drag-and-drop.
  const factory TelemetrySource.path(String path) = FileTelemetrySource;

  /// In-memory bytes — the web path, and equally usable on desktop for a file
  /// that was already read.
  const factory TelemetrySource.bytes(String name, Uint8List bytes) =
      BytesTelemetrySource;

  /// Human-readable identifier for error messages.
  String get label;
}

final class FileTelemetrySource extends TelemetrySource {
  const FileTelemetrySource(this.path);

  final String path;

  @override
  String get label => path;

  // Value equality is load-bearing, not a nicety: a `TelemetrySource` is the
  // key of the Riverpod family that owns the open connection (§9.3). Without
  // it, a widget rebuilding `TelemetrySource.path(samePath)` produces a key
  // the family has never seen, and the same file is reopened — re-reading the
  // catalog and re-scanning the clock — on every rebuild.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileTelemetrySource && other.path == path);

  @override
  int get hashCode => Object.hash(FileTelemetrySource, path);
}

final class BytesTelemetrySource extends TelemetrySource {
  const BytesTelemetrySource(this.name, this.bytes);

  /// Virtual filename to register the buffer under. Needs a `.duckdb`-ish
  /// name only insofar as it must be unique within the database.
  final String name;
  final Uint8List bytes;

  @override
  String get label => name;

  // Same reasoning as [FileTelemetrySource], but the buffer is compared by
  // *identity* rather than content: these are whole telemetry files, up to
  // hundreds of megabytes (§5.5), and comparing them element-wise on every
  // provider read would cost more than the reopen it prevents. Two reads of
  // the same file therefore have to pass the same buffer instance, which is
  // what the import flow does anyway.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BytesTelemetrySource &&
          other.name == name &&
          identical(other.bytes, bytes));

  @override
  int get hashCode => Object.hash(BytesTelemetrySource, name, identityHashCode(bytes));
}

/// An open, read-only handle to one telemetry file.
///
/// Read-only is enforced at `ATTACH` time, not just intended: §3 makes
/// "editing or writing back to `.duckdb` files" a non-goal, and a
/// `READ_ONLY` attach means a bug can't violate that rather than merely
/// not doing so.
class TelemetryDatabase implements TelemetryQueryExecutor {
  TelemetryDatabase._(this._database, this._connection, this.source);

  final Database _database;
  final Connection _connection;
  final TelemetrySource source;

  /// Schema the telemetry file is attached as. Queries stay unqualified
  /// because [open] issues `USE`, so the SQL is byte-identical on every
  /// platform — the asymmetry ends here rather than leaking into every
  /// table reference.
  static const attachedSchema = 'session';

  /// Opens [source] read-only.
  ///
  /// Both platforms take the same route — open an in-memory database, then
  /// `ATTACH` the telemetry file into it — because a `.duckdb` file *is* a
  /// database, so the web path can't simply hand DuckDB-Wasm a registered
  /// buffer to open directly. Unifying on `ATTACH` means desktop and web run
  /// identical SQL instead of one of them carrying schema-qualified names.
  static Future<TelemetryDatabase> open(TelemetrySource source) async {
    Database? database;
    Connection? connection;
    try {
      database = await duckdb.open(':memory:');
      if (source is BytesTelemetrySource) {
        // Browsers can't open a path, so the bytes are registered as a
        // virtual file first and attached under that name (§9.2).
        await database.registerFileBuffer(source.name, source.bytes);
      }
      connection = await duckdb.connect(database);
      final attachTarget = switch (source) {
        FileTelemetrySource(:final path) => path,
        BytesTelemetrySource(:final name) => name,
      };
      await connection.execute(
        "ATTACH '${attachTarget.replaceAll("'", "''")}' "
        'AS $attachedSchema (READ_ONLY)',
      );
      await connection.execute('USE $attachedSchema');
      return TelemetryDatabase._(database, connection, source);
    } on Object catch (error) {
      await connection?.dispose();
      await database?.dispose();
      throw SessionOpenException(
        'Could not open telemetry file. It may be missing, in use by another '
        'program, or not a DuckDB database.',
        source: source.label,
        cause: error,
      );
    }
  }

  @override
  Future<List<List<Object?>>> rows(String sql) async {
    try {
      final result = await _connection.query(sql);
      try {
        return result.fetchAll();
      } finally {
        await result.dispose();
      }
    } on Object catch (error) {
      throw TelemetryQueryException(
        'Telemetry query failed.',
        sql: sql,
        cause: error,
      );
    }
  }

  Future<void> dispose() async {
    await _connection.dispose();
    await _database.dispose();
  }
}
