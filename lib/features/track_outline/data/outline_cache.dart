/// Where a layout's pooled outline is kept between runs, so the library's
/// recordings are read once, not every time a map opens (map stage proposal
/// §3.4).
///
/// One small JSON file per layout in the app-support directory: the pool's
/// sums and counts, and which recordings (by size and mtime) went into it.
/// Under `flutter test` nothing is read or written, as with the settings
/// file: a test must neither depend on nor overwrite the developer's own.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class OutlineCacheStore {
  /// The kept JSON for [layout]; null when there is none.
  Future<Map<String, Object?>?> read(String layout);

  Future<void> write(String layout, Map<String, Object?> json);
}

/// `track_outlines/<layout>.json` in the app-support directory. Nothing
/// under a plain `flutter test`, which sets `FLUTTER_TEST`.
class FileOutlineCacheStore implements OutlineCacheStore {
  const FileOutlineCacheStore();

  Future<File?> _file(String layout) async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return null;
    try {
      final dir = await getApplicationSupportDirectory();
      return File(p.join(dir.path, 'track_outlines', '${slug(layout)}.json'));
    } on Object {
      return null;
    }
  }

  /// A file name for [layout]: letters and digits, the rest as dashes.
  static String slug(String layout) => layout
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  @override
  Future<Map<String, Object?>?> read(String layout) async {
    final file = await _file(layout);
    if (file == null || !await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString());
      return json is Map<String, Object?> ? json : null;
    } on Object {
      // A damaged file is a pool to build again, not an error to show.
      return null;
    }
  }

  @override
  Future<void> write(String layout, Map<String, Object?> json) async {
    final file = await _file(layout);
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(json));
    } on Object {
      // A cache: failing to keep it costs a re-read next run, nothing more.
    }
  }
}

/// Outlines held for the run only: what an integration test gives the real
/// app, and what a widget test reads back.
class MemoryOutlineCacheStore implements OutlineCacheStore {
  final kept = <String, Map<String, Object?>>{};

  @override
  Future<Map<String, Object?>?> read(String layout) async => kept[layout];

  @override
  Future<void> write(String layout, Map<String, Object?> json) async =>
      kept[layout] = json;
}
