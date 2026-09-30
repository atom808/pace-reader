// Indexing a folder of recordings (SPEC.md §8.1, §9.6): what the scan reads,
// what it skips, what it reports, and how the banner and folder chips show it.
//
// The facts the scan "reads" are the real ones (`session_library_samples.dart`)
// served through the facts-reader seam, because a plain `flutter test` cannot
// open DuckDB. That the real reader opens each file read-only and closes it
// again is what `integration_test/session_library_test.dart` checks.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/folder_scan.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_file_system.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/features/session_library/presentation/library_list.dart';

import '../fixtures/session_library_samples.dart';
import 'session_library_harness.dart';

const _folder = r'C:\LMU\UserData\Telemetry';
const _other = r'D:\Backup\Telemetry';

/// A container with the scan's four seams faked, holding [samples] in
/// [_folder] unless [folders] says otherwise.
({
  ProviderContainer container,
  MemorySessionIndexStore store,
  FakeSessionFileSystem fs,
  List<String> reads,
})
_scanKit({
  Iterable<SampleSession> samples = sampleSessions,
  Map<String, TelemetryException> broken = const {},
  Map<String, List<String>>? folders,
  FolderScanReaderGate? gate,
}) {
  final store = MemorySessionIndexStore();
  final reads = <String>[];
  final fs = FakeSessionFileSystem(
    files: diskWith(samples),
    folders:
        folders ??
        {
          _folder: [for (final s in samples) s.path],
        },
  );
  final reader = factsReaderFor(samples, broken: broken, readLog: reads);
  final container = ProviderContainer(
    overrides: [
      sessionIndexStoreProvider.overrideWithValue(store),
      sessionFileSystemProvider.overrideWithValue(fs),
      libraryClockProvider.overrideWithValue(() => libraryNow),
      sessionFactsReaderProvider.overrideWithValue(
        gate == null
            ? reader
            : (source) async {
                await gate.wait(source);
                return reader(source);
              },
      ),
    ],
  );
  addTearDown(container.dispose);
  // Listened to, as the screen does: the providers are kept alive, but a
  // container with no listener could dispose them between awaits.
  container.listen(sessionLibraryProvider, (_, _) {});
  container.listen(libraryFoldersProvider, (_, _) {});
  container.listen(folderScanProvider, (_, _) {});
  return (container: container, store: store, fs: fs, reads: reads);
}

FolderScanSummary _summary(ProviderContainer c) =>
    (c.read(folderScanProvider) as FolderScanFinished).summary;

void main() {
  group('the scan', () {
    test('indexes every recording it finds and remembers the folder', () async {
      final kit = _scanKit();
      await kit.container.read(folderScanProvider.notifier).addAndScan(_folder);

      final summary = _summary(kit.container);
      expect(summary.found, 4);
      expect(summary.added, 4);
      expect(summary.updated, 0);
      expect(summary.unchanged, 0);
      expect(summary.hasProblems, isFalse);

      final rows = await kit.store.readEntries();
      expect(rows, hasLength(4));
      // The real numbers, from the files: Sebring's best is lap 11 at 63.941.
      final race = rows.firstWhere((e) => e.path == sebringRace.path);
      expect(race.bestLapSeconds, closeTo(63.9409, 1e-4));
      expect(race.bestLapNumber, 11);
      expect(race.trackLayout, 'Sebring School Circuit');
      expect(race.importedAt.isAtSameMomentAs(libraryNow), isTrue);
      // A scan reads files; it does not open them in the app.
      expect(race.lastOpenedAt, isNull);

      final folders = await kit.store.readFolders();
      expect(folders.single.path, _folder);
      expect(folders.single.lastScanFileCount, 4);
      expect(
        folders.single.lastScannedAt!.isAtSameMomentAs(libraryNow),
        isTrue,
      );
    });

    test(
      'never opens a session in the app: the scan reads facts and stops',
      () async {
        final kit = _scanKit();
        await kit.container
            .read(folderScanProvider.notifier)
            .addAndScan(_folder);
        // `telemetrySessionProvider` is kept alive by design; had the scan gone
        // through it, there would be one live connection per recording.
        for (final sample in sampleSessions) {
          expect(
            kit.container.exists(telemetrySessionProvider(sourceOf(sample))),
            isFalse,
          );
        }
        expect(kit.container.read(openSessionsProvider), isEmpty);
        expect(kit.reads, hasLength(4));
      },
    );

    test('a rescan skips files whose size and mtime match, without reading '
        'them', () async {
      final kit = _scanKit();
      final scan = kit.container.read(folderScanProvider.notifier);
      await scan.addAndScan(_folder);
      kit.reads.clear();

      await scan.refreshAll();

      final summary = _summary(kit.container);
      expect(summary.found, 4);
      expect(summary.unchanged, 4);
      expect(summary.added, 0);
      expect(kit.reads, isEmpty, reason: 'unchanged files are not opened');
    });

    test('a rewritten file is re-read and updated, keeping when it was '
        'first seen and when it was last opened', () async {
      final kit = _scanKit();
      final scan = kit.container.read(folderScanProvider.notifier);
      await scan.addAndScan(_folder);
      final opened = DateTime.utc(2026, 9, 29, 20);
      await kit.store.markOpened(sebringRace.path, opened);
      kit.reads.clear();

      // Same length, later mtime: what size alone would miss.
      kit.fs.files[sebringRace.path] = FileFacts(
        sizeBytes: sebringRace.sizeBytes,
        modifiedMs: 5000,
      );
      await scan.refreshAll();

      final summary = _summary(kit.container);
      expect(summary.updated, 1);
      expect(summary.unchanged, 3);
      expect(kit.reads, [sebringRace.path]);
      final row = await kit.store.readEntry(sebringRace.path);
      expect(row!.modifiedMs, 5000);
      expect(row.lastOpenedAt!.isAtSameMomentAs(opened), isTrue);
    });

    test('a file that cannot be read is named with the reason, the rest are '
        'indexed, and it is retried next time', () async {
      final kit = _scanKit(
        broken: {
          interlagosPractice.path: const NotTelemetryFileException(
            'That file is a DuckDB database, but not a telemetry recording.',
            missingTables: ['Lap'],
          ),
        },
      );
      final scan = kit.container.read(folderScanProvider.notifier);
      await scan.addAndScan(_folder);

      var summary = _summary(kit.container);
      expect(summary.found, 4);
      expect(summary.added, 3);
      expect(summary.failures, hasLength(1));
      expect(summary.failures.single.fileName, interlagosPractice.fileName);
      expect(
        summary.failures.single.reason,
        contains('not a telemetry recording'),
      );
      expect(summary.hasProblems, isTrue);
      expect(await kit.store.readEntry(interlagosPractice.path), isNull);

      // Nothing was recorded for it, so it is attempted again.
      kit.reads.clear();
      await scan.refreshAll();
      summary = _summary(kit.container);
      expect(kit.reads, [interlagosPractice.path]);
      expect(summary.failures, hasLength(1));
      expect(summary.unchanged, 3);
    });

    test(
      'a file that vanishes mid-scan is reported, not skipped silently',
      () async {
        final kit = _scanKit();
        kit.fs.files.remove(spaQualify.path);
        await kit.container
            .read(folderScanProvider.notifier)
            .addAndScan(_folder);
        final summary = _summary(kit.container);
        expect(summary.added, 3);
        expect(summary.failures.single.fileName, spaQualify.fileName);
        expect(summary.failures.single.reason, contains('disappeared'));
      },
    );

    test('a folder that cannot be listed is reported and the others still '
        'scan', () async {
      final kit = _scanKit(
        folders: {
          _folder: [sebringRace.path],
        },
      );
      final scan = kit.container.read(folderScanProvider.notifier);
      await scan.scan([r'Z:\Gone', _folder]);
      final summary = _summary(kit.container);
      expect(summary.unreadableFolders.single.folder, r'Z:\Gone');
      expect(summary.added, 1);
      expect(summary.hasProblems, isTrue);
    });

    test(
      'an empty folder says so: zero found is not a failure but is stated',
      () async {
        final kit = _scanKit(folders: {_folder: []});
        await kit.container
            .read(folderScanProvider.notifier)
            .addAndScan(_folder);
        final summary = _summary(kit.container);
        expect(summary.found, 0);
        expect(summary.hasProblems, isFalse);
        expect((await kit.store.readFolders()).single.lastScanFileCount, 0);
      },
    );

    test('several folders scan as one job with one denominator', () async {
      final kit = _scanKit(
        folders: {
          _folder: [spaQualify.path, interlagosPractice.path],
          _other: [sebringRace.path, sebringFixture.path],
        },
      );
      final states = <FolderScanState>[];
      kit.container.listen(folderScanProvider, (_, next) => states.add(next));
      await kit.container.read(folderScanProvider.notifier).scan([
        _folder,
        _other,
      ]);

      final running = states.whereType<FolderScanRunning>().toList();
      expect([for (final r in running) r.done], [0, 1, 2, 3]);
      expect({for (final r in running) r.total}, {4});
      expect(_summary(kit.container).found, 4);
    });

    test('Stop leaves what is indexed and says how many files were not '
        'reached', () async {
      final gate = FolderScanReaderGate(holdAt: spaQualify.path);
      final kit = _scanKit(
        gate: gate,
        folders: {
          _folder: [
            interlagosPractice.path,
            spaQualify.path,
            sebringRace.path,
            sebringFixture.path,
          ],
        },
      );
      final scan = kit.container.read(folderScanProvider.notifier);
      final running = scan.addAndScan(_folder);
      await gate.reached;
      scan.stop();
      gate.release();
      await running;

      final summary = _summary(kit.container);
      expect(
        summary.added,
        2,
        reason: 'Interlagos, and Spa which was in flight',
      );
      expect(summary.notReached, 2);
      expect(summary.hasProblems, isTrue);
      expect(await kit.store.readEntries(), hasLength(2));
    });

    test('a second scan cannot start while one is running', () async {
      final gate = FolderScanReaderGate(holdAt: sebringRace.path);
      final kit = _scanKit(
        gate: gate,
        samples: [sebringRace],
        folders: {
          _folder: [sebringRace.path],
        },
      );
      final scan = kit.container.read(folderScanProvider.notifier);
      final first = scan.addAndScan(_folder);
      await gate.reached;
      await scan.refreshAll();
      gate.release();
      await first;
      expect(kit.reads, hasLength(1));
      expect(_summary(kit.container).added, 1);
    });

    test('a chooser that cannot open is reported, not swallowed', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final kit = _scanKit();
      await kit.container.read(folderScanProvider.notifier).pickAndScan();
      final state = kit.container.read(folderScanProvider);
      expect(state, isA<FolderScanFailed>());
      expect(
        (state as FolderScanFailed).message,
        'The folder chooser could not be opened.',
      );
      expect(state.detail, isNotEmpty);
    });
  });

  group('the folder list', () {
    test('forgetting a folder keeps its sessions', () async {
      final kit = _scanKit();
      await kit.container.read(folderScanProvider.notifier).addAndScan(_folder);
      await kit.container.read(libraryFoldersProvider.notifier).remove(_folder);
      expect(await kit.store.readFolders(), isEmpty);
      expect(await kit.store.readEntries(), hasLength(4));
    });

    test('adding a folder twice keeps what was known about it', () async {
      final kit = _scanKit();
      final scan = kit.container.read(folderScanProvider.notifier);
      await scan.addAndScan(_folder);
      await scan.addAndScan(_folder);
      final folders = await kit.store.readFolders();
      expect(folders, hasLength(1));
      expect(folders.single.lastScanFileCount, 4);
    });

    test('LMU\'s folder is suggested only when it exists here and is not '
        'remembered yet', () async {
      final store = MemorySessionIndexStore();
      final fs = FakeSessionFileSystem(
        suggestion: lmuDefaultTelemetryFolder,
        folders: {lmuDefaultTelemetryFolder: []},
      );
      final container = ProviderContainer(
        overrides: [
          sessionIndexStoreProvider.overrideWithValue(store),
          sessionFileSystemProvider.overrideWithValue(fs),
          libraryClockProvider.overrideWithValue(() => libraryNow),
        ],
      );
      addTearDown(container.dispose);
      container.listen(suggestedTelemetryFolderProvider, (_, _) {});

      expect(
        await container.read(suggestedTelemetryFolderProvider.future),
        lmuDefaultTelemetryFolder,
      );
      await container
          .read(libraryFoldersProvider.notifier)
          .add(lmuDefaultTelemetryFolder);
      container.invalidate(suggestedTelemetryFolderProvider);
      expect(
        await container.read(suggestedTelemetryFolderProvider.future),
        isNull,
      );
    });

    test(
      'no folder is suggested where folders cannot be browsed (web)',
      () async {
        final container = ProviderContainer(
          overrides: [
            sessionIndexStoreProvider.overrideWithValue(
              MemorySessionIndexStore(),
            ),
            sessionFileSystemProvider.overrideWithValue(
              FakeSessionFileSystem(
                supportsFolders: false,
                suggestion: lmuDefaultTelemetryFolder,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        expect(
          await container.read(suggestedTelemetryFolderProvider.future),
          isNull,
        );
      },
    );
  });

  group('on screen', () {
    testWidgets('the banner shows progress while it runs, then the outcome', (
      tester,
    ) async {
      final gate = FolderScanReaderGate(holdAt: spaQualify.path);
      final h = await pumpLibraryScreen(
        tester,
        fileSystem: FakeSessionFileSystem(
          files: diskWith(sampleSessions),
          folders: {
            _folder: [
              interlagosPractice.path,
              spaQualify.path,
              sebringRace.path,
            ],
          },
        ),
        factsReader: (source) async {
          await gate.wait(source);
          return factsReaderFor(sampleSessions)(source);
        },
      );
      // With nothing indexed the screen is the welcome card.
      expect(find.text('Open a telemetry session'), findsOneWidget);

      final scan = h.container.read(folderScanProvider.notifier);
      final running = scan.addAndScan(_folder);
      await gate.reached;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Progress is stated in words, with the file being read.
      expect(find.textContaining('Indexing 2 of 3'), findsOneWidget);
      expect(find.textContaining(spaQualify.fileName), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Stop'), findsOneWidget);
      // The first row is already in the list; it fills in as the scan goes.
      expect(find.byType(LibraryRow), findsOneWidget);
      // "Add folder" and Refresh are disabled while it runs.
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add folder'),
            )
            .onPressed,
        isNull,
      );

      gate.release();
      await running;
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Scanned 3 recordings: 3 new'),
        findsOneWidget,
      );
      expect(find.byType(LibraryRow), findsNWidgets(3));
      // The folder is now a chip with what the scan found.
      expect(
        find.textContaining('3 recordings · scanned just now'),
        findsOneWidget,
      );
      // Dismissing clears the banner.
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Scanned 3 recordings'), findsNothing);
    });

    testWidgets('a scan with a bad file names it in the banner', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        fileSystem: FakeSessionFileSystem(
          files: diskWith(sampleSessions),
          folders: {
            _folder: [spaQualify.path, sebringRace.path],
          },
        ),
        factsReader: factsReaderFor(
          sampleSessions,
          broken: {
            sebringRace.path: const SchemaMismatchException(
              'The recording is missing the Lap table.',
              detail: 'Lap',
            ),
          },
        ),
      );
      await h.container.read(folderScanProvider.notifier).addAndScan(_folder);
      await tester.pumpAndSettle();
      expect(
        find.textContaining("${sebringRace.fileName} wasn't added"),
        findsOneWidget,
      );
      expect(find.textContaining('missing the Lap table'), findsOneWidget);
      expect(find.byType(LibraryRow), findsOneWidget);
    });

    testWidgets('Refresh rescans every remembered folder', (tester) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: [spaQualify],
        folders: [LibraryFolder(path: _folder, addedAt: libraryIndexedAt)],
        fileSystem: FakeSessionFileSystem(
          files: diskWith(sampleSessions),
          folders: {
            _folder: [spaQualify.path, sebringRace.path],
          },
        ),
      );
      expect(find.textContaining('not scanned yet'), findsOneWidget);
      expect(find.byType(LibraryRow), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Refresh'));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryRow), findsNWidgets(2));
      expect(find.textContaining('1 new'), findsOneWidget);
      expect(find.textContaining('1 unchanged'), findsOneWidget);
      expect((await h.store.readFolders()).single.lastScanFileCount, 2);
    });

    testWidgets("LMU's folder is offered as one click, and taken", (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        fileSystem: FakeSessionFileSystem(
          files: diskWith([sebringRace]),
          folders: {
            lmuDefaultTelemetryFolder: [sebringRace.path],
          },
          suggestion: lmuDefaultTelemetryFolder,
        ),
      );
      // On the welcome card the suggestion replaces the generic button and
      // the path it found is shown.
      expect(find.text("Index LMU's telemetry folder"), findsOneWidget);
      expect(find.textContaining('Found at'), findsOneWidget);

      await tester.tap(find.text("Index LMU's telemetry folder"));
      await tester.pumpAndSettle();

      expect(find.byType(LibraryRow), findsOneWidget);
      expect(
        (await h.store.readFolders()).single.path,
        lmuDefaultTelemetryFolder,
      );
      // Remembered now, so it is no longer offered.
      expect(find.text("Add LMU's telemetry folder"), findsNothing);
    });

    testWidgets('forgetting a folder from its chip keeps the rows', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: [sebringRace],
        folders: [LibraryFolder(path: _folder, addedAt: libraryIndexedAt)],
      );
      await tester.tap(
        find.byTooltip('Forget this folder (its sessions stay in the library)'),
      );
      await tester.pumpAndSettle();
      expect(await h.store.readFolders(), isEmpty);
      expect(find.byType(LibraryRow), findsOneWidget);
    });
  });
}
