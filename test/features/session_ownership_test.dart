// Who owns an open file, and what counts as the same file (comparison
// proposal §9, step 1).
//
// Compare brings a second file in without switching what every other screen
// shows, so a file can now join Open now *behind* the current session. And a
// Windows file reaches the app under more than one spelling, so the library,
// Open now and the connection family must all agree that `C:\…\Race.duckdb`
// and `c:/…/race.duckdb` are one file — or the same recording is opened
// twice, which on Windows is what kept a closed file locked (§8.1).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/application/folder_scan.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/features/session_library/presentation/library_list.dart';
import 'package:path/path.dart' as p;

import '../fixtures/session_library_samples.dart';
import 'session_library_harness.dart';

/// A container wired like the library screen's: a memory index, a fake disk,
/// a fixed clock, and the samples' real metadata and laps.
ProviderContainer _container({
  MemorySessionIndexStore? store,
  FakeSessionFileSystem? disk,
  SessionFactsReader? reader,
}) {
  final container = ProviderContainer(
    overrides: [
      sessionIndexStoreProvider.overrideWithValue(
        store ?? MemorySessionIndexStore(),
      ),
      sessionFileSystemProvider.overrideWithValue(
        disk ?? FakeSessionFileSystem(files: diskWith(sampleSessions)),
      ),
      libraryClockProvider.overrideWithValue(() => libraryNow),
      sessionFactsReaderProvider.overrideWithValue(
        reader ?? factsReaderFor(sampleSessions),
      ),
      ...sessionOverrides(sampleSessions),
    ],
  );
  addTearDown(container.dispose);
  // The import controller is auto-disposed; a listener keeps it alive for
  // the length of the test, as the screen would.
  container.listen(sessionImportProvider, (_, _) {});
  return container;
}

/// [path] as another program might spell it on Windows: lower case, forward
/// slashes.
String _respelled(String path) => path.toLowerCase().replaceAll(r'\', '/');

void main() {
  final race = sourceOf(sebringRace);
  final spa = sourceOf(spaQualify);
  final interlagos = sourceOf(interlagosPractice);

  group('OpenSessions.addBehind', () {
    test('leaves the current session current', () {
      final container = _container();
      final sessions = container.read(openSessionsProvider.notifier);
      sessions.open(race);
      sessions.addBehind(spa);
      expect(container.read(currentSessionProvider), race);
      expect(container.read(openSessionsProvider), [race, spa]);

      // The newest addition sits right behind the current session.
      sessions.addBehind(interlagos);
      expect(container.read(openSessionsProvider), [race, interlagos, spa]);
    });

    test('an already open file keeps its place and its connection', () {
      final container = _container();
      final sessions = container.read(openSessionsProvider.notifier);
      sessions.open(spa);
      sessions.open(race);
      sessions.addBehind(spa);
      sessions.addBehind(race);
      expect(container.read(openSessionsProvider), [race, spa]);
    });

    test('with nothing open, the file is the only session', () {
      final container = _container();
      container.read(openSessionsProvider.notifier).addBehind(spa);
      expect(container.read(currentSessionProvider), spa);
    });
  });

  group('SessionImport', () {
    test('open(makeCurrent: false) adds the file behind and indexes it',
        () async {
      final store = MemorySessionIndexStore();
      final container = _container(store: store);
      final import = container.read(sessionImportProvider.notifier);

      await import.open(race);
      await import.open(spa, makeCurrent: false);

      expect(container.read(currentSessionProvider), race);
      expect(container.read(openSessionsProvider), [race, spa]);
      expect(container.read(sessionImportProvider), isA<SessionImportSuccess>());
      // Indexed like any other open: it is a file the user chose.
      expect(await store.readEntry(spaQualify.path), isNotNull);
    });

    test('a drop of several files makes the first one current, in drop '
        'order', () async {
      final container = _container();
      await container
          .read(sessionImportProvider.notifier)
          .openDroppedPaths([sebringRace.path, spaQualify.path, interlagosPractice.path]);

      expect(container.read(currentSessionProvider), race);
      expect(container.read(openSessionsProvider), [race, spa, interlagos]);
    });
  });

  group('one file, many spellings (Windows rules)', () {
    late p.Context previous;
    setUp(() {
      previous = FileTelemetrySource.pathContext;
      FileTelemetrySource.pathContext = p.Context(style: p.Style.windows);
    });
    tearDown(() => FileTelemetrySource.pathContext = previous);

    final respelled = _respelled(sebringRace.path);

    test('a library row shows as open under another spelling', () {
      final row = sebringRace.entry(indexedAt: libraryIndexedAt);
      expect(isEntryOpen([TelemetrySource.path(respelled)], row), isTrue);
      expect(isEntryOpen([spa], row), isFalse);
    });

    test('opening it under another spelling refreshes the same row', () async {
      final store = MemorySessionIndexStore(
        entries: [sebringRace.entry(indexedAt: libraryIndexedAt, modifiedMs: 1000)],
      );
      final disk = FakeSessionFileSystem(
        files: {...diskWith([sebringRace]), respelled: factsOf(sebringRace)},
      );
      final container = _container(store: store, disk: disk);

      await container
          .read(sessionImportProvider.notifier)
          .open(TelemetrySource.path(respelled));

      final rows = await store.readEntries();
      expect(rows, hasLength(1));
      expect(rows.single.path, sebringRace.path);
      expect(rows.single.lastOpenedAt, libraryNow);
      expect(
        await indexedEntryFor(store, respelled),
        isA<LibraryEntry>().having((e) => e.path, 'path', sebringRace.path),
      );
    });

    test('a scan that lists another spelling updates the row in place',
        () async {
      final store = MemorySessionIndexStore(
        entries: [sebringRace.entry(indexedAt: libraryIndexedAt, modifiedMs: 1000)],
      );
      final disk = FakeSessionFileSystem(
        // Rewritten since it was indexed, so the scan re-reads it.
        files: {respelled: factsOf(sebringRace, mtime: 2000)},
        folders: {'c:/telemetry': [respelled]},
      );
      final container = _container(
        store: store,
        disk: disk,
        reader: (source) async => sebringRace.facts,
      );

      await container.read(folderScanProvider.notifier).scan(['c:/telemetry']);

      final finished = container.read(folderScanProvider) as FolderScanFinished;
      expect(finished.summary.added, 0);
      expect(finished.summary.updated, 1);
      final rows = await store.readEntries();
      expect(rows, hasLength(1));
      expect(rows.single.path, sebringRace.path);
      expect(rows.single.modifiedMs, 2000);
    });
  });

  test('under posix rules another spelling is another file', () async {
    final previous = FileTelemetrySource.pathContext;
    addTearDown(() => FileTelemetrySource.pathContext = previous);
    FileTelemetrySource.pathContext = p.Context(style: p.Style.posix);

    final store = MemorySessionIndexStore(
      entries: [sebringRace.entry(indexedAt: libraryIndexedAt)],
    );
    expect(await indexedEntryFor(store, _respelled(sebringRace.path)), isNull);
  });
}
