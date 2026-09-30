/// Desktop implementations of the library's two seams.
library;

import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'library_database.dart';
import 'library_entry.dart';
import 'session_file_system.dart';
import 'session_index_store.dart';

/// The index as a drift file in the app-support directory, not the
/// documents folder drift_flutter defaults to: it is the app's own state, not
/// a document the user made, and it has no business appearing next to their
/// files (on macOS, `~/Library/Application Support/<bundle id>/`).
///
/// Under `flutter test` it is [MemorySessionIndexStore] instead (the runner
/// sets `FLUTTER_TEST`). Two reasons, both about what an un-overridden test
/// would otherwise do: drift's native connection runs on a background isolate,
/// which a widget test's fake clock never waits for — the library would sit on
/// its loading skeleton and `pumpAndSettle` would time out — and a test that
/// pumps the whole app would read and write the developer's own library. A
/// test that wants the real SQL says so (`NativeDatabase.memory()` in the
/// index tests, a temp file in `integration_test/session_library_test.dart`,
/// which runs inside the compiled app and so never sees this variable).
SessionIndexStore openPlatformSessionIndexStore() {
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return MemorySessionIndexStore();
  }
  return DriftSessionIndexStore(
    LibraryDatabase(
      driftDatabase(
        name: 'session_library',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    ),
  );
}

SessionFileSystem platformSessionFileSystem() => const IoSessionFileSystem();

class IoSessionFileSystem implements SessionFileSystem {
  const IoSessionFileSystem();

  @override
  bool get supportsFolders => true;

  @override
  Future<FileFacts?> stat(String path) async {
    final stat = await FileStat.stat(path);
    if (stat.type != FileSystemEntityType.file) return null;
    return FileFacts(
      sizeBytes: stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<String>> listTelemetryFiles(String folder) async {
    final paths = <String>[];
    await for (final entity in Directory(folder).list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.duckdb')) {
        paths.add(entity.path);
      }
    }
    return paths..sort();
  }

  @override
  Future<bool> folderExists(String folder) => Directory(folder).exists();

  @override
  Future<String?> suggestedTelemetryFolder() async {
    if (!Platform.isWindows) return null;
    return await Directory(lmuDefaultTelemetryFolder).exists()
        ? lmuDefaultTelemetryFolder
        : null;
  }
}
