/// Desktop implementations of the results index's two seams.
library;

import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../session_library/data/library_entry.dart';
import 'results_database.dart';
import 'results_file_system.dart';
import 'results_index_store.dart';

bool get _underFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';

/// A drift file in the app-support directory, beside the library's.
///
/// Under `flutter test` it is memory, and the filesystem is empty, for the
/// reasons `openPlatformSessionIndexStore` gives, plus one: a widget test on
/// a machine with LMU installed would otherwise find the real results folder
/// and offer it.
ResultsIndexStore openPlatformResultsIndexStore() {
  if (_underFlutterTest) return MemoryResultsIndexStore();
  return DriftResultsIndexStore(
    ResultsDatabase(
      driftDatabase(
        name: 'session_results',
        native: const DriftNativeOptions(
          databaseDirectory: getApplicationSupportDirectory,
        ),
      ),
    ),
  );
}

ResultsFileSystem platformResultsFileSystem() => _underFlutterTest
    ? const NoResultsFileSystem()
    : const IoResultsFileSystem();

class IoResultsFileSystem implements ResultsFileSystem {
  const IoResultsFileSystem();

  @override
  Future<List<String>> listResultsFiles(String folder) async {
    final paths = <String>[];
    await for (final entity in Directory(folder).list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.xml')) {
        paths.add(entity.path);
      }
    }
    return paths..sort((a, b) => b.compareTo(a));
  }

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
  Future<List<int>> readBytes(String path) => File(path).readAsBytes();

  @override
  Future<bool> folderExists(String folder) => Directory(folder).exists();
}
