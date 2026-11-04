/// The outlines a stage can lay its road band on (map stage proposal §3.4,
/// D6): the layout's, pooled from every recording of it in the library, and
/// this session's own envelope for when the library knows too little.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../driver_comparison/domain/segments.dart' show TrackKey;
import '../../session_library/application/open_sessions.dart';
import '../../session_library/application/session_library.dart';
import '../../session_library/data/library_entry.dart';
import '../data/outline_cache.dart';
import '../data/outline_repository.dart';
import '../domain/outline_pool.dart';

part 'road_outlines.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// Reads one recording's edges: open, read, close.
typedef EdgeBinsReader = Future<List<EdgeBin>> Function(TelemetrySource source);

/// [readEdgeBinsBriefly], as a provider so a test can serve edges without a
/// DuckDB connection.
@Riverpod(keepAlive: true)
EdgeBinsReader edgeBinsReader(Ref ref) => readEdgeBinsBriefly;

@Riverpod(keepAlive: true)
OutlineCacheStore outlineCacheStore(Ref ref) => const FileOutlineCacheStore();

/// A layout's outline as pooled so far.
@immutable
class PooledOutline {
  const PooledOutline({
    this.outline,
    this.recordings = 0,
    this.reading = false,
  });

  /// Null until a recording with edges has been read.
  final TrackOutline? outline;
  final int recordings;

  /// Still reading the library's recordings of the layout.
  final bool reading;
}

/// The library's outline of a layout, filled in as its recordings are read.
///
/// Kept alive and cached on disk: reading a layout's recordings takes a
/// while the first time (a second or so each), so they are read one at a
/// time in the background and the band grows as they land; later runs read
/// only recordings the cache has not seen. A recording that changed or left
/// the library starts the pool again, since a sum can't take one back out.
@Riverpod(keepAlive: true)
class LibraryOutline extends _$LibraryOutline {
  static const _cacheVersion = 1;

  /// How many recordings are read between showing and keeping the pool.
  static const _batch = 10;

  @override
  PooledOutline build(TrackKey layout) {
    ref.listen(sessionLibraryProvider, (_, next) {
      if (next.hasValue) _refresh();
    }, fireImmediately: true);
    return const PooledOutline(reading: true);
  }

  String get _name => '${layout.trackName} ${layout.trackLayout}';

  Future<void>? _running;
  var _again = false;

  /// One pass at a time; a library change during one asks for another.
  void _refresh() {
    if (_running != null) {
      _again = true;
      return;
    }
    _running = _pool().whenComplete(() {
      _running = null;
      if (_again && ref.mounted) {
        _again = false;
        _refresh();
      }
    });
  }

  Future<void> _pool() async {
    final entries = [
      for (final e in await ref.read(sessionLibraryProvider.future))
        if (e.kind == LibrarySourceKind.file &&
            e.trackName == layout.trackName &&
            e.trackLayout == layout.trackLayout)
          e,
    ];
    final store = ref.read(outlineCacheStoreProvider);
    final files = ref.read(sessionFileSystemProvider);
    final readEdges = ref.read(edgeBinsReaderProvider);
    final now = {
      for (final e in entries) e.path: '${e.sizeBytes}:${e.modifiedMs}',
    };
    final (pool, seen) = _restore(await store.read(_name), now);
    if (!ref.mounted) return;

    Future<void> keep() => store.write(_name, {
      'version': _cacheVersion,
      'read': seen,
      'pool': pool.toJson(),
    });

    var unkept = 0;
    _show(pool, reading: true);
    for (final e in entries) {
      if (seen.containsKey(e.path)) continue;
      // The game is still writing it; read it on a later pass.
      if (await files.stat('${e.path}.wal') != null) continue;
      if (await files.stat(e.path) == null) continue;
      try {
        pool.add(await readEdges(TelemetrySource.path(e.path)));
      } on Object {
        // Unreadable: marked as seen all the same, so a broken file isn't
        // opened again on every run.
      }
      seen[e.path] = now[e.path]!;
      if (!ref.mounted) return;
      if (++unkept == _batch) {
        unkept = 0;
        _show(pool, reading: true);
        await keep();
      }
    }
    if (!ref.mounted) return;
    _show(pool, reading: false);
    if (unkept > 0 || seen.length != now.length) await keep();
  }

  /// The cached pool when every recording in it is still in the library as
  /// it was; otherwise an empty one.
  (OutlinePool, Map<String, String>) _restore(
    Map<String, Object?>? json,
    Map<String, String> now,
  ) {
    final fresh = (OutlinePool(), <String, String>{});
    if (json == null || json['version'] != _cacheVersion) return fresh;
    final read = json['read'];
    final pool = OutlinePool.fromJson(json['pool']);
    if (read is! Map || pool == null) return fresh;
    final seen = <String, String>{};
    for (final MapEntry(:key, :value) in read.entries) {
      if (key is! String || value is! String || now[key] != value) {
        return fresh;
      }
      seen[key] = value;
    }
    return (pool, seen);
  }

  void _show(OutlinePool pool, {required bool reading}) =>
      state = PooledOutline(
        outline: pool.isEmpty ? null : pool.outline(),
        recordings: pool.recordings,
        reading: reading,
      );
}

/// How far either side this session's laps went, as an outline: the band
/// for a layout the library hardly knows.
///
/// Only for a file in Open now that is still on disk: the band never opens
/// a file of its own (Compare's rule, `compare_source_guard.dart`).
@Riverpod(retry: _neverRetry)
Future<TrackOutline?> sessionEnvelope(Ref ref, TelemetrySource source) async {
  if (!ref.watch(openSessionsProvider.select((o) => o.contains(source)))) {
    return null;
  }
  if (source case FileTelemetrySource(:final path)
      when await ref.read(sessionFileSystemProvider).stat(path) == null) {
    return null;
  }
  final session = await ref.watch(telemetrySessionProvider(source).future);
  final bins = await OutlineRepository(
    session.database,
    session.catalog,
  ).envelope();
  return bins.isEmpty ? null : envelopeOutline(bins);
}

/// Both outlines for [source]'s layout, for the stage to choose between.
@immutable
class RoadOutlines {
  const RoadOutlines({required this.library, this.envelope});

  final PooledOutline library;
  final TrackOutline? envelope;
}

@Riverpod(retry: _neverRetry)
Future<RoadOutlines> roadOutlines(Ref ref, TelemetrySource source) async {
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final library = ref.watch(libraryOutlineProvider(TrackKey.of(metadata)));
  final envelope = await ref.watch(sessionEnvelopeProvider(source).future);
  return RoadOutlines(library: library, envelope: envelope);
}
