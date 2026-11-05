/// The filesystem reads the results index needs, behind a seam (results
/// proposal, R1).
library;

import '../../session_library/data/library_entry.dart';

/// LMU's results folder on a default Steam library: where the game writes
/// one file per session, and what the MyLMU Sync Agent watches.
const lmuDefaultResultsFolder =
    r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate\UserData\Log\Results';

/// What reading results files asks of the disk: list, `stat` and read. Never
/// a write, and never anything outside the folder the user chose.
abstract interface class ResultsFileSystem {
  /// `*.xml` files directly inside [folder], newest name first. LMU names
  /// them by local time, so this is newest session first. Not recursive.
  /// Throws when the folder can't be listed.
  Future<List<String>> listResultsFiles(String folder);

  Future<FileFacts?> stat(String path);

  Future<List<int>> readBytes(String path);

  Future<bool> folderExists(String folder);
}

/// A filesystem with nothing on it: web, and widget tests unless they say
/// otherwise.
class NoResultsFileSystem implements ResultsFileSystem {
  const NoResultsFileSystem();

  @override
  Future<List<String>> listResultsFiles(String folder) async =>
      throw UnsupportedError('Folders cannot be browsed here.');

  @override
  Future<FileFacts?> stat(String path) async => null;

  @override
  Future<List<int>> readBytes(String path) async =>
      throw UnsupportedError('Files cannot be read by path here.');

  @override
  Future<bool> folderExists(String folder) async => false;
}

/// Where LMU's results folder is, given a telemetry folder of the same
/// install: `…\UserData\Telemetry` → `…\UserData\Log\Results`. Null for a
/// folder that isn't one (a copy on another drive).
String? resultsFolderBeside(String telemetryFolder) {
  final match = RegExp(
    r'^(.*[\\/])UserData[\\/]Telemetry[\\/]?$',
    caseSensitive: false,
  ).firstMatch(telemetryFolder);
  if (match == null) return null;
  final sep = telemetryFolder.contains(r'\') ? r'\' : '/';
  return '${match.group(1)}UserData${sep}Log${sep}Results';
}
