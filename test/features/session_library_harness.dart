// Shared scaffolding for the Session Library's widget tests (SPEC.md §8.1).
//
// Not a test itself (no `_test` suffix): it gives each test file the same
// four seams the library reads through — the index store, the filesystem, the
// facts reader and the clock — so a test can say "this file has gone" or
// "the scan meets a corrupt recording" without a DuckDB connection, which a
// plain `flutter test` cannot open.
//
// The rows and laps are the real ones: `session_library_samples.dart` is
// generated from the three recordings in `samples/` and the checked-in
// fixture.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_file_system.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/session_library_samples.dart';

/// "Now" for every library test: a fixed instant, so "scanned 3 min ago" and
/// `importedAt` are deterministic.
final libraryNow = DateTime.utc(2026, 9, 30, 12);

/// When the test index "first saw" its files — a week before [libraryNow].
final libraryIndexedAt = DateTime.utc(2026, 9, 23, 18, 30);

/// A filesystem held in a map.
///
/// Mutable on purpose: a test makes a file "disappear" by removing it, or
/// "change on disk" by replacing its facts, between pumps.
class FakeSessionFileSystem implements SessionFileSystem {
  FakeSessionFileSystem({
    this.supportsFolders = true,
    Map<String, FileFacts>? files,
    Map<String, List<String>>? folders,
    this.suggestion,
  }) : files = files ?? {},
       folders = folders ?? {};

  @override
  final bool supportsFolders;

  final Map<String, FileFacts> files;
  final Map<String, List<String>> folders;
  final String? suggestion;

  /// Every path [stat] was asked about, in order — for asserting the library
  /// checks files by `stat` and nothing heavier.
  final statted = <String>[];

  @override
  Future<FileFacts?> stat(String path) async {
    statted.add(path);
    return files[path];
  }

  @override
  Future<List<String>> listTelemetryFiles(String folder) async {
    final listed = folders[folder];
    if (listed == null) throw StateError('no such folder: $folder');
    return listed;
  }

  @override
  Future<bool> folderExists(String folder) async => folders.containsKey(folder);

  @override
  Future<String?> suggestedTelemetryFolder() async => suggestion;
}

/// The file facts the fake disk gives a sample: its real size, and [mtime].
FileFacts factsOf(SampleSession sample, {int mtime = 1000}) =>
    FileFacts(sizeBytes: sample.sizeBytes, modifiedMs: mtime);

/// A fake disk holding each of [samples] at the mtime the matching
/// [SampleSession.entry] row was indexed at (the default, 1000).
Map<String, FileFacts> diskWith(Iterable<SampleSession> samples) => {
  for (final s in samples) s.path: factsOf(s),
};

class _FixedOpenSessions extends OpenSessions {
  _FixedOpenSessions(this._initial);

  final List<TelemetrySource> _initial;

  @override
  List<TelemetrySource> build() => _initial;
}

/// The source the library opens [sample] as.
TelemetrySource sourceOf(SampleSession sample) =>
    TelemetrySource.path(sample.path);

/// Serves [sample]'s real metadata, laps and clock gaps wherever the open
/// session providers would have read them from the file.
List<Override> sessionOverrides(Iterable<SampleSession> samples) => [
  for (final s in samples) ...[
    sessionMetadataProvider(sourceOf(s))
        .overrideWith((ref) async => s.metadata),
    lapsProvider(sourceOf(s)).overrideWith((ref) async => s.lapList),
    sessionClockGapsProvider(sourceOf(s)).overrideWith(
      (ref) async => [
        for (var i = 0; i < s.clockGapCount; i++)
          ClockGap(masterRowIndex: 1000 * (i + 1), deltaSeconds: 30),
      ],
    ),
  ],
];

/// Builds the facts a scan would read for each sample, by path, and throws
/// [TelemetryException]s for paths in [broken].
SessionFactsReader factsReaderFor(
  Iterable<SampleSession> samples, {
  Map<String, TelemetryException> broken = const {},
  List<String>? readLog,
}) {
  final byPath = {for (final s in samples) s.path: s};
  return (source) async {
    final path = (source as FileTelemetrySource).path;
    readLog?.add(path);
    final failure = broken[path];
    if (failure != null) throw failure;
    return byPath[path]!.facts;
  };
}

/// What a test holds on to after pumping the screen.
class LibraryHarness {
  LibraryHarness({
    required this.container,
    required this.store,
    required this.fileSystem,
    required this.router,
  });

  final ProviderContainer container;
  final MemorySessionIndexStore store;
  final FakeSessionFileSystem fileSystem;
  final GoRouter router;

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  List<TelemetrySource> get open => container.read(openSessionsProvider);

  TelemetrySource? get current => container.read(currentSessionProvider);
}

/// Pumps the library screen, inside a router that knows `/overview` so a tap
/// that navigates can be seen to.
///
/// [indexed] are written to the store as rows (mtime 1000, as
/// [diskWith] provides); [onDisk] is what the fake disk holds — by default
/// every indexed sample, so each row is "present" until a test says
/// otherwise.
Future<LibraryHarness> pumpLibraryScreen(
  WidgetTester tester, {
  Iterable<SampleSession> indexed = const [],
  Iterable<LibraryEntry> extraEntries = const [],
  Iterable<SampleSession>? onDisk,
  Iterable<SampleSession> open = const [],
  Iterable<LibraryFolder> folders = const [],
  Map<String, DateTime> lastOpened = const {},
  List<Override> overrides = const [],
  FakeSessionFileSystem? fileSystem,
  SessionIndexStore? storeOverride,
  SessionFactsReader? factsReader,
  Size size = const Size(1280, 900),
  bool disableAnimations = false,
  Widget Function(Widget screen)? wrap,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final store = MemorySessionIndexStore(
    entries: [
      for (final s in indexed)
        s.entry(
          indexedAt: libraryIndexedAt,
          modifiedMs: 1000,
          lastOpenedAt: lastOpened[s.path],
        ),
      ...extraEntries,
    ],
    folders: folders,
  );
  final fs =
      fileSystem ??
      FakeSessionFileSystem(
        files: {
          ...diskWith(onDisk ?? indexed),
          for (final e in extraEntries)
            e.path: FileFacts(sizeBytes: e.sizeBytes, modifiedMs: e.modifiedMs),
        },
      );
  // Every real sample can be "read" by a scan, wherever a test puts it.
  final samples = {...sampleSessions, ...indexed, ...open, ...?onDisk};

  final router = GoRouter(
    initialLocation: '/sessions',
    routes: [
      GoRoute(
        path: '/sessions',
        builder: (context, state) => const SessionLibraryScreen(),
      ),
      GoRoute(
        path: '/overview',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('OVERVIEW SCREEN'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionIndexStoreProvider.overrideWithValue(storeOverride ?? store),
        sessionFileSystemProvider.overrideWithValue(fs),
        libraryClockProvider.overrideWithValue(() => libraryNow),
        sessionFactsReaderProvider.overrideWithValue(
          factsReader ?? factsReaderFor(samples),
        ),
        openSessionsProvider.overrideWith(
          () => _FixedOpenSessions([for (final s in open) sourceOf(s)]),
        ),
        ...sessionOverrides(samples),
        ...overrides,
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routerConfig: router,
        builder: (context, child) {
          final app = disableAnimations
              ? MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(disableAnimations: true),
                  child: child!,
                )
              : child!;
          return wrap == null ? app : wrap(app);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return LibraryHarness(
    container: ProviderScope.containerOf(
      tester.element(find.byType(SessionLibraryScreen)),
    ),
    store: store,
    fileSystem: fs,
    router: router,
  );
}

/// A store that cannot be read — or, with [readable], one that reads an empty
/// index fine but cannot write it.
///
/// The two ways the desktop index fails in the field: a corrupt or locked
/// SQLite file, and a read-only or full disk.
class BrokenSessionIndexStore implements SessionIndexStore {
  BrokenSessionIndexStore({this.readable = false});

  final bool readable;

  Never _fail() => throw StateError('database disk image is malformed');

  @override
  Future<List<LibraryEntry>> readEntries() async =>
      readable ? const [] : _fail();

  @override
  Future<LibraryEntry?> readEntry(String path) async =>
      readable ? null : _fail();

  @override
  Future<void> upsertEntry(LibraryEntry entry) async => _fail();

  @override
  Future<void> removeEntry(String path) async => _fail();

  @override
  Future<void> markOpened(String path, DateTime at) async => _fail();

  @override
  Future<List<LibraryFolder>> readFolders() async =>
      readable ? const [] : _fail();

  @override
  Future<void> upsertFolder(LibraryFolder folder) async => _fail();

  @override
  Future<void> removeFolder(String path) async => _fail();

  @override
  Future<void> close() async {}
}

/// Holds a scan on one file until released, so a test can look at the banner
/// and the half-filled list mid-scan.
class FolderScanReaderGate {
  FolderScanReaderGate({required this.holdAt});

  final String holdAt;
  final _reached = Completer<void>();
  final _release = Completer<void>();

  /// Completes when the scan is blocked on [holdAt].
  Future<void> get reached => _reached.future;

  Future<void> wait(TelemetrySource source) async {
    if ((source as FileTelemetrySource).path != holdAt) return;
    if (!_reached.isCompleted) _reached.complete();
    await _release.future;
  }

  void release() => _release.complete();
}
