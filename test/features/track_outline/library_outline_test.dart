import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/session_metadata.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/track_outline/application/road_outlines.dart';
import 'package:pace_reader/features/track_outline/data/outline_cache.dart';
import 'package:pace_reader/features/track_outline/domain/outline_pool.dart';

import '../compare_harness.dart' show FixedLibrary;
import '../session_library_harness.dart' show FakeSessionFileSystem;

const _sebring = TrackKey('Sebring International Raceway', 'Sebring');

LibraryEntry _entry(String path, {int modifiedMs = 1, String? layout}) =>
    LibraryEntry(
      path: path,
      fileName: path.split('/').last,
      kind: LibrarySourceKind.file,
      sizeBytes: 100,
      modifiedMs: modifiedMs,
      trackName: _sebring.trackName,
      trackLayout: layout ?? _sebring.trackLayout,
      carName: 'Car',
      carClass: 'GT3',
      sessionType: SessionType.practice,
      driverName: 'Driver',
      recordingTime: '2026-07-07T20_00_00Z',
      weather: 'Clear',
      formatVersion: '1',
      completedLaps: 3,
      timedLaps: 2,
      bestLapSeconds: null,
      bestLapIndex: null,
      clockGapCount: 0,
      importedAt: DateTime.utc(2026, 7, 7),
    );

/// Each recording sees the left edge at -(its number) m at station 0.
List<EdgeBin> _edgesOf(String path) {
  final n = double.parse(RegExp(r'(\d+)').firstMatch(path)!.group(1)!);
  return [(bin: 0, left: -n, right: n)];
}

class _Run {
  _Run(this.container, this.reads);

  final ProviderContainer container;
  final List<String> reads;

  /// The outline once every recording has been read.
  Future<PooledOutline> settled() async {
    final done = Completer<PooledOutline>();
    final sub = container.listen(libraryOutlineProvider(_sebring), (_, next) {
      if (!next.reading && !done.isCompleted) done.complete(next);
    }, fireImmediately: true);
    try {
      return await done.future.timeout(const Duration(seconds: 5));
    } finally {
      sub.close();
    }
  }
}

_Run _run(
  List<LibraryEntry> library, {
  required OutlineCacheStore cache,
  Set<String> walPaths = const {},
}) {
  final reads = <String>[];
  final fs = FakeSessionFileSystem(
    files: {
      for (final e in library)
        e.path: FileFacts(sizeBytes: e.sizeBytes, modifiedMs: e.modifiedMs),
      for (final p in walPaths)
        '$p.wal': const FileFacts(sizeBytes: 1, modifiedMs: 1),
    },
  );
  final container = ProviderContainer(
    overrides: [
      sessionLibraryProvider.overrideWith(() => FixedLibrary(library)),
      sessionFileSystemProvider.overrideWithValue(fs),
      outlineCacheStoreProvider.overrideWithValue(cache),
      edgeBinsReaderProvider.overrideWithValue((source) async {
        final path = (source as FileTelemetrySource).path;
        reads.add(path);
        if (path.contains('broken')) throw StateError('not a recording');
        return _edgesOf(path);
      }),
    ],
  );
  addTearDown(container.dispose);
  return _Run(container, reads);
}

void main() {
  test("pools the layout's recordings, and only that layout's", () async {
    final run = _run([
      _entry('/lmu/r2.duckdb'),
      _entry('/lmu/r4.duckdb'),
      _entry('/lmu/r9.duckdb', layout: 'Sebring School'),
    ], cache: MemoryOutlineCacheStore());
    final pooled = await run.settled();
    expect(run.reads, ['/lmu/r2.duckdb', '/lmu/r4.duckdb']);
    expect(pooled.recordings, 2);
    expect(pooled.outline!.edgesAt(1), (-3.0, 3.0));
  });

  test('a later run reads only what the cache has not seen', () async {
    final cache = MemoryOutlineCacheStore();
    final first = [_entry('/lmu/r2.duckdb'), _entry('/lmu/r4.duckdb')];
    await _run(first, cache: cache).settled();

    final again = _run(first, cache: cache);
    expect((await again.settled()).recordings, 2);
    expect(again.reads, isEmpty);

    final more = _run([...first, _entry('/lmu/r6.duckdb')], cache: cache);
    final pooled = await more.settled();
    expect(more.reads, ['/lmu/r6.duckdb']);
    expect(pooled.outline!.edgesAt(0), (-4.0, 4.0));
  });

  test('a recording that changed, or left, starts the pool again', () async {
    final cache = MemoryOutlineCacheStore();
    await _run([
      _entry('/lmu/r2.duckdb'),
      _entry('/lmu/r4.duckdb'),
    ], cache: cache).settled();

    final changed = _run([
      _entry('/lmu/r2.duckdb', modifiedMs: 2),
      _entry('/lmu/r4.duckdb'),
    ], cache: cache);
    expect((await changed.settled()).recordings, 2);
    expect(changed.reads, ['/lmu/r2.duckdb', '/lmu/r4.duckdb']);

    final left = _run([_entry('/lmu/r4.duckdb')], cache: cache);
    final pooled = await left.settled();
    expect(left.reads, ['/lmu/r4.duckdb']);
    expect(pooled.outline!.edgesAt(0), (-4.0, 4.0));
  });

  test('skips a file the game is still writing, and one that is gone; '
      'a broken one is not tried again', () async {
    final cache = MemoryOutlineCacheStore();
    final library = [
      _entry('/lmu/r2.duckdb'),
      _entry('/lmu/r3.duckdb'), // being written
      _entry('/lmu/broken5.duckdb'),
    ];
    final run = _run(
      [...library, _entry('/lmu/gone7.duckdb')],
      cache: cache,
      walPaths: {'/lmu/r3.duckdb'},
    );
    // The fake filesystem holds every entry; take one away.
    final fs =
        run.container.read(sessionFileSystemProvider) as FakeSessionFileSystem;
    fs.files.remove('/lmu/gone7.duckdb');
    final pooled = await run.settled();
    expect(run.reads, ['/lmu/r2.duckdb', '/lmu/broken5.duckdb']);
    expect(pooled.recordings, 1);

    final next = _run(library, cache: cache);
    await next.settled();
    expect(next.reads, ['/lmu/r3.duckdb'], reason: 'now that it is written');
  });
}
