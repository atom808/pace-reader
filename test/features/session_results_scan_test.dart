// Reading LMU's results folder (results proposal, R1): what the scan reads,
// skips and reports, and how the library shows the folder and each link.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/session_metadata.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/features/session_results/application/session_results.dart';
import 'package:pace_reader/features/session_results/data/results_file_system.dart';
import 'package:pace_reader/features/session_results/data/results_index_store.dart';
import 'package:pace_reader/features/session_results/domain/results_link.dart';
import 'package:pace_reader/features/session_results/presentation/results_widgets.dart';
import 'package:pace_reader/widgets/design_system/app_tooltip.dart';

import '../fixtures/results_xml_samples.dart';
import 'session_library_harness.dart';

const _folder = r'C:\LMU\UserData\Log\Results';
const _bahrain = '$_folder\\2026_11_05_00_06_52-48P1.xml';
const _sarthe = '$_folder\\2026_10_23_00_48_40-12R1.xml';
const _broken = '$_folder\\2026_10_01_00_00_00-00P1.xml';

/// A results folder held in memory.
class FakeResultsFileSystem implements ResultsFileSystem {
  FakeResultsFileSystem(this.files, {this.folderPresent = true});

  /// Path → (facts, text).
  final Map<String, (FileFacts, String)> files;
  final bool folderPresent;
  final reads = <String>[];

  @override
  Future<List<String>> listResultsFiles(String folder) async {
    if (!folderPresent) throw StateError('no such folder: $folder');
    return files.keys.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<FileFacts?> stat(String path) async => files[path]?.$1;

  @override
  Future<List<int>> readBytes(String path) async {
    reads.add(path);
    return files[path]!.$2.codeUnits;
  }

  @override
  Future<bool> folderExists(String folder) async =>
      folderPresent && folder == _folder;
}

FakeResultsFileSystem _disk({bool broken = false}) => FakeResultsFileSystem({
  _bahrain: (const FileFacts(sizeBytes: 10, modifiedMs: 1), bahrainPracticeXml),
  _sarthe: (const FileFacts(sizeBytes: 20, modifiedMs: 1), sartheRaceXml),
  if (broken) _broken: (const FileFacts(sizeBytes: 5, modifiedMs: 1), '<half'),
});

/// The parse on the test's own zone: a widget test's fake clock never waits
/// for another isolate.
final _syncParser = resultsParserProvider.overrideWithValue(
  (bytes) async => parseResultsBytes(bytes),
);

List<Override> _results(FakeResultsFileSystem fs, ResultsIndexStore store) => [
  resultsFileSystemProvider.overrideWithValue(fs),
  resultsIndexStoreProvider.overrideWithValue(store),
  _syncParser,
];

/// The user's Bahrain recording, as the library indexes it.
final _recording = LibraryEntry(
  path: r'C:\LMU\UserData\Telemetry\Bahrain International Circuit_P_2026-11-05T02_38_28Z.duckdb',
  fileName: 'Bahrain International Circuit_P_2026-11-05T02_38_28Z.duckdb',
  kind: LibrarySourceKind.file,
  sizeBytes: 31092736,
  modifiedMs: 1000,
  trackName: 'Bahrain International Circuit',
  trackLayout: 'Bahrain International Circuit',
  carName: 'Ferrari AF Corse 2026 #50:LM',
  carClass: 'Hyper',
  sessionType: SessionType.practice,
  driverName: 'Test Driver',
  recordingTime: '2026-11-05T02_38_28Z',
  weather: 'Clear',
  formatVersion: '1',
  completedLaps: 5,
  timedLaps: 3,
  bestLapSeconds: 107.7979,
  bestLapIndex: 3,
  clockGapCount: 0,
  importedAt: DateTime.utc(2026, 11, 5),
);

void main() {
  group('the scan', () {
    late FakeResultsFileSystem fs;
    late MemoryResultsIndexStore store;
    late ProviderContainer container;

    void setUpWith(FakeResultsFileSystem disk) {
      fs = disk;
      store = MemoryResultsIndexStore();
      container = ProviderContainer(
        overrides: [
          ..._results(fs, store),
          libraryClockProvider.overrideWithValue(() => libraryNow),
          // The library's own index, empty: the suggestion reads its
          // folders to find the results folder beside them.
          sessionIndexStoreProvider.overrideWithValue(
            MemorySessionIndexStore(),
          ),
        ],
      );
      addTearDown(container.dispose);
    }

    test('reads every file, newest first, and remembers the folder', () async {
      setUpWith(_disk());
      await container.read(resultsScanProvider.notifier).addAndScan(_folder);

      expect(fs.reads, [_bahrain, _sarthe]);
      expect(await store.sessionCount(), 2);
      final summary =
          (container.read(resultsScanProvider) as ResultsScanFinished).summary;
      expect(summary.added, 2);
      expect(summary.hasProblems, isFalse);
      final folder = (await container.read(resultsFoldersProvider.future))
          .single;
      expect(folder.path, _folder);
      expect(folder.lastScanFileCount, 2);
      expect(container.read(resultsIndexRevisionProvider), 1);
    });

    test('a rescan skips unchanged files and re-reads changed ones', () async {
      setUpWith(_disk());
      final scan = container.read(resultsScanProvider.notifier);
      await scan.addAndScan(_folder);
      fs.reads.clear();
      fs.files[_sarthe] = (
        const FileFacts(sizeBytes: 21, modifiedMs: 2),
        sartheRaceXml,
      );
      await scan.refreshAll();

      expect(fs.reads, [_sarthe]);
      final summary =
          (container.read(resultsScanProvider) as ResultsScanFinished).summary;
      expect(summary.unchanged, 1);
      expect(summary.updated, 1);
    });

    test(
      'a file that isn\'t results is named, and the rest are read',
      () async {
        setUpWith(_disk(broken: true));
        await container.read(resultsScanProvider.notifier).addAndScan(_folder);

        final summary = (container.read(
          resultsScanProvider,
        ) as ResultsScanFinished).summary;
        expect(summary.added, 2);
        expect(
          summary.failures.single.fileName,
          '2026_10_01_00_00_00-00P1.xml',
        );
        expect(summary.failures.single.reason, contains('not well-formed XML'));
      },
    );

    test('a folder that has gone is reported, not thrown', () async {
      setUpWith(FakeResultsFileSystem({}, folderPresent: false));
      await container.read(resultsScanProvider.notifier).addAndScan(_folder);
      final summary =
          (container.read(resultsScanProvider) as ResultsScanFinished).summary;
      expect(summary.unreadableFolders.single.folder, _folder);
    });

    test('a recording links once its session has been read', () async {
      setUpWith(_disk());
      expect(
        await container.read(resultsLinkProvider(_recording).future),
        isNull,
      );
      await container.read(resultsScanProvider.notifier).addAndScan(_folder);
      final link = await container.read(resultsLinkProvider(_recording).future);
      expect(link!.path, _bahrain);
      expect(link.basis, ResultsLinkBasis.lapTime);
    });

    test('the folder is offered from beside a telemetry folder', () async {
      setUpWith(_disk());
      // The default Steam path isn't on the fake disk; this install is.
      await container
          .read(libraryFoldersProvider.notifier)
          .add(r'C:\LMU\UserData\Telemetry');
      expect(
        await container.read(suggestedResultsFolderProvider.future),
        _folder,
      );

      await container.read(resultsFoldersProvider.notifier).add(_folder);
      expect(
        await container.read(suggestedResultsFolderProvider.future),
        isNull,
      );
    });
  });

  group('in the library', () {
    testWidgets('offers the folder, reads it, and marks the linked row', (
      tester,
    ) async {
      final fs = _disk();
      final harness = await pumpLibraryScreen(
        tester,
        extraEntries: [_recording],
        folders: [
          LibraryFolder(
            path: r'C:\LMU\UserData\Telemetry',
            addedAt: DateTime.utc(2026, 9),
          ),
        ],
        overrides: _results(fs, MemoryResultsIndexStore()),
      );
      expect(find.byIcon(resultsIcon), findsNothing, reason: 'not read yet');

      await tester.tap(find.text("Add LMU's results"));
      await tester.pumpAndSettle();

      expect(find.text("Add LMU's results"), findsNothing);
      expect(
        find.text(r'…\Log\Results · 2 sessions · read just now'),
        findsOneWidget,
      );
      // The chip's flag and the row's.
      final rowGlyph = find.descendant(
        of: find.byType(ResultsLinkGlyph),
        matching: find.byIcon(resultsIcon),
      );
      expect(rowGlyph, findsOneWidget);
      final tooltip = tester.widget<AppTooltip>(
        find.ancestor(of: rowGlyph, matching: find.byType(AppTooltip)).first,
      );
      expect(tooltip.message, contains('2026_11_05_00_06_52-48P1.xml'));
      expect(tooltip.message, contains('1:47.798'));
      expect(
        harness.container.read(resultsScanProvider),
        isA<ResultsScanFinished>(),
      );
    });

    testWidgets('Refresh reads the results folder too', (tester) async {
      final fs = _disk();
      final store = MemoryResultsIndexStore(
        folders: [LibraryFolder(path: _folder, addedAt: DateTime.utc(2026))],
      );
      await pumpLibraryScreen(
        tester,
        extraEntries: [_recording],
        overrides: _results(fs, store),
      );
      expect(find.text(r'…\Log\Results · not read yet'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Refresh'));
      await tester.pumpAndSettle();

      expect(fs.reads, hasLength(2));
      expect(
        find.text(r'…\Log\Results · 2 sessions · read just now'),
        findsOneWidget,
      );
    });
  });
}
