/// The filesystem reads the Session Library needs, behind a seam (SPEC.md
/// §8.1, §9.2).
library;

import 'library_entry.dart';

/// LMU's default telemetry folder on a default Steam library (§5, confirmed).
///
/// A suggestion, never an assumption: Steam libraries are commonly on another
/// drive, so the library offers this only when it actually exists, and "Add
/// folder" takes any path regardless.
const lmuDefaultTelemetryFolder =
    r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate\UserData\Telemetry';

/// `stat` and directory listing — the only two things the library asks of
/// the filesystem, and neither of them opens a recording.
///
/// An interface for the same reason `TelemetryQueryExecutor` is one: `dart:io`
/// doesn't exist on web, and a widget test should be able to say "this file
/// is gone" without a real one on disk.
abstract interface class SessionFileSystem {
  /// False on web, where a browser can't browse a folder or reopen a path —
  /// which is what hides "Add folder" there rather than offering a button
  /// that cannot work.
  bool get supportsFolders;

  /// The file's size and mtime, or null when nothing is at [path].
  Future<FileFacts?> stat(String path);

  /// `*.duckdb` files directly inside [folder], sorted by name.
  ///
  /// Not recursive, on purpose: LMU writes every recording flat into one
  /// folder, and a recursive walk turns a mis-click on a drive root into a
  /// scan of the whole disk. Throws when the folder can't be listed.
  Future<List<String>> listTelemetryFiles(String folder);

  Future<bool> folderExists(String folder);

  /// LMU's default folder when this platform can have one *and* it exists —
  /// Windows only by nature, since LMU runs nowhere else (§5).
  Future<String?> suggestedTelemetryFolder();
}

/// A filesystem with nothing on it: web, where there are no paths.
class NoSessionFileSystem implements SessionFileSystem {
  const NoSessionFileSystem();

  @override
  bool get supportsFolders => false;

  @override
  Future<FileFacts?> stat(String path) async => null;

  @override
  Future<List<String>> listTelemetryFiles(String folder) async =>
      throw UnsupportedError('Folders cannot be browsed in a web browser.');

  @override
  Future<bool> folderExists(String folder) async => false;

  @override
  Future<String?> suggestedTelemetryFolder() async => null;
}

/// The last path segment, on either separator — Windows paths reach a
/// desktop build on Windows, and a test may run anywhere.
String baseName(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut < 0 ? path : path.substring(cut + 1);
}
