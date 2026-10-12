// The Session Library's persistent index, against a real recording and a real
// SQLite file (SPEC.md §8.1, §9.6, §12).
//
// `test/features/session_library_*` prove the rules with the real numbers
// served through a seam, because a plain `flutter test` can open neither
// DuckDB nor a drift file on disk. This is the one place the whole path runs
// for real: DuckDB attached read-only → metadata, laps and the clock scan →
// an index row in a drift SQLite file → back out after a restart, and a folder
// scan that opens each file just long enough and lets go of it.
//
// The expected values are not derived from the code under test: they were read
// out of `test/fixtures/sebring_race_laps0_3.duckdb` with the `duckdb` Python
// package (`Lap Time` = 0.0 / 71.241 / 64.497 / 64.570 / 64.030 at the five
// `Lap` boundaries; lap 0 is the garage lap and is not timed, §8.3.1).
//
// Run with (one file per run):
//   flutter test integration_test/session_library_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/folder_scan.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_database.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/features/session_library/presentation/library_list.dart';
import 'package:pace_reader/features/session_library/presentation/library_widgets.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Each test opens its own database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_library_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// A path inside [tmp], spelled the way the platform lists it.
  ///
  /// `p.join` rather than `'${tmp.path}/…'`, because the scan's index keys are
  /// whatever `Directory.list` returns, and on Windows that joins with `\`: a
  /// test that builds `…/telemetry/x.duckdb` by hand looks up a row the scan
  /// stored as `…/telemetry\x.duckdb`, and finds nothing. POSIX joins with `/`
  /// either way, which is why only the Windows runner ever saw it.
  String inTmp(String part1, [String? part2, String? part3]) =>
      p.join(tmp.path, part1, part2, part3);

  /// Deletes [path] once nothing holds it open.
  ///
  /// "Close session" releases the DuckDB connection asynchronously — the
  /// button fires `close()` without awaiting it, and `dart_duckdb` tears the
  /// connection's isolate down before letting go of the file — so the handle
  /// can still be open when the tap settles. POSIX lets a test unlink an open
  /// file and never notices; Windows refuses ("being used by another
  /// process"). Bounded, so a handle that is genuinely never released still
  /// fails here, which on Windows is exactly what it caught: closing used to
  /// reopen the file in the same frame (see `TelemetrySessionHandle.close`).
  Future<void> deleteWhenReleased(String path) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        File(path).deleteSync();
        return;
      } on FileSystemException {
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  /// The desktop index — drift over a real file — at [name] inside [tmp].
  SessionIndexStore openIndex([String name = 'session_library.sqlite']) =>
      DriftSessionIndexStore(
        LibraryDatabase(NativeDatabase(File(inTmp(name)))),
      );

  /// A copy of the fixture at [path]: same bytes, its own mtime — which is
  /// what a file copied into the telemetry folder looks like.
  String copyFixture(String path) {
    File(path).parent.createSync(recursive: true);
    File('$_projectRoot/$_fixture').copySync(path);
    return path;
  }

  Future<ProviderContainer> pumpApp(
    WidgetTester tester,
    SessionIndexStore store,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/sessions');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionIndexStoreProvider.overrideWithValue(store)],
        child: const PaceReaderApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SessionLibraryScreen)),
    );
  }

  /// Tears the app down so the index can be reopened "after a restart".
  Future<void> closeApp(WidgetTester tester, SessionIndexStore store) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await store.close();
  }

  testWidgets('importing the real fixture writes an index row with the '
      'numbers measured from the file', (tester) async {
    final path = '$_projectRoot/$_fixture';
    expect(File(path).existsSync(), isTrue, reason: 'fixture missing at $path');
    final store = openIndex();
    final container = await pumpApp(tester, store);

    await container
        .read(sessionImportProvider.notifier)
        .open(const TelemetrySource.path('$_projectRoot/$_fixture'));
    await tester.pumpAndSettle();
    expect(container.read(sessionImportProvider), isA<SessionImportSuccess>());

    final row = await store.readEntry(path);
    expect(row, isNotNull, reason: 'import populates the index (§9.6)');
    // §5.1 metadata, verbatim.
    expect(row!.fileName, 'sebring_race_laps0_3.duckdb');
    expect(row.kind, LibrarySourceKind.file);
    expect(row.trackName, 'Sebring International Raceway');
    // Layout is load-bearing (§8.1): the School Circuit, not the full course.
    expect(row.trackLayout, 'Sebring School Circuit');
    expect(row.carName, 'The Bend Team WRT 2025 #31:BRZ');
    expect(row.carClass, 'GT3');
    expect(row.sessionType, SessionType.race);
    expect(row.driverName, 'Diego Pestana');
    expect(row.recordingTime, '2026-07-07T06_42_17Z');
    expect(row.recordedAt, DateTime.utc(2026, 7, 7, 6, 42, 17));
    expect(row.weather, 'Light Clouds');
    expect(row.formatVersion, '1');
    // §5.2: 5 `Lap` rows, 4 closed; laps 1-3 timed, lap 0 is the garage lap.
    expect(row.completedLaps, 4);
    expect(row.timedLaps, 3);
    // The best timed lap is index 3 (shown as lap 4): 64.0296 s.
    expect(row.bestLapSeconds, closeTo(64.02963, 1e-4));
    expect(row.bestLapIndex, 3);
    expect(row.bestLapNumber, 4);
    // §15.12: the Race recording has no clock gap.
    expect(row.clockGapCount, 0);
    // Change detection is what the file says it is, to the millisecond.
    final stat = File(path).statSync();
    expect(row.sizeBytes, stat.size);
    expect(row.sizeBytes, 23867392);
    expect(row.modifiedMs, stat.modified.millisecondsSinceEpoch);
    expect(row.lastOpenedAt, isNotNull);
    expect(
      row.importedAt.difference(DateTime.now()).inMinutes.abs(),
      lessThan(5),
    );

    // On screen: the row, with its personal best (the only session here).
    expect(
      find.text('Sebring International Raceway — Sebring School Circuit'),
      findsWidgets,
    );
    expect(find.byType(PersonalBestBadge), findsOneWidget);
    expect(find.text('1:04.030'), findsWidgets);

    await closeApp(tester, store);
  });

  testWidgets('the index survives a restart, and a row reopens its file', (
    tester,
  ) async {
    final path = copyFixture(inTmp('telemetry', 'sebring.duckdb'));

    var store = openIndex();
    var container = await pumpApp(tester, store);
    await container
        .read(sessionImportProvider.notifier)
        .open(TelemetrySource.path(path));
    await tester.pumpAndSettle();
    final before = await store.readEntry(path);
    await closeApp(tester, store);

    // A new run: nothing open, the same SQLite file.
    store = openIndex();
    container = await pumpApp(tester, store);
    expect(container.read(openSessionsProvider), isEmpty);
    expect(await store.readEntry(path), before);
    expect(find.byType(LibraryRow), findsOneWidget);
    expect(find.text('Open now'), findsNothing);
    expect(find.textContaining('File not found'), findsNothing);

    // Tapping the row opens the file — from its path, through the index.
    await tester.tap(find.byType(LibraryRow));
    await tester.pumpAndSettle();
    expect(container.read(currentSessionProvider), TelemetrySource.path(path));
    expect(
      appRouter.routerDelegate.currentConfiguration.uri.toString(),
      '/overview',
    );
    expect(find.text('Best lap'), findsOneWidget);
    expect(find.text('1:04.030'), findsWidgets);
    final reopened = await store.readEntry(path);
    expect(reopened!.lastOpenedAt, isNotNull);
    // Reopening a file that has not changed does not make it "new".
    expect(
      reopened.importedAt.millisecondsSinceEpoch,
      before!.importedAt.millisecondsSinceEpoch,
    );

    await closeApp(tester, store);
  });

  testWidgets('a folder scan indexes what it can read, names what it cannot, '
      'skips what has not changed, and holds no connection open', (
    tester,
  ) async {
    final folder = inTmp('telemetry');
    final good = copyFixture(p.join(folder, 'sebring_copy.duckdb'));
    // Not a DuckDB database at all, but named like one.
    File(p.join(folder, 'broken.duckdb'))
        .writeAsStringSync('this is not a database');
    // Not a recording by name; must not even be counted.
    File(p.join(folder, 'notes.txt')).writeAsStringSync('setup notes');

    final store = openIndex();
    final container = await pumpApp(tester, store);
    final scan = container.read(folderScanProvider.notifier);

    await scan.addAndScan(folder);
    await tester.pumpAndSettle();

    var summary =
        (container.read(folderScanProvider) as FolderScanFinished).summary;
    expect(summary.found, 2, reason: 'notes.txt is not a recording');
    expect(summary.added, 1);
    expect(summary.failures.map((f) => f.fileName), ['broken.duckdb']);
    expect(summary.failures.single.reason, contains('Could not open'));
    // The banner says so by name.
    expect(find.textContaining("broken.duckdb wasn't added"), findsOneWidget);

    final indexed = await store.readEntry(good);
    expect(indexed!.bestLapSeconds, closeTo(64.02963, 1e-4));
    expect(indexed.trackLayout, 'Sebring School Circuit');
    expect(indexed.lastOpenedAt, isNull, reason: 'scanned, not opened');
    final folders = await store.readFolders();
    expect(folders.single.path, folder);
    expect(folders.single.lastScanFileCount, 2);

    // Scanning read the file through a brief connection, not through the
    // kept-alive session provider — which would hold one per recording.
    expect(
      container.exists(telemetrySessionProvider(TelemetrySource.path(good))),
      isFalse,
    );
    expect(container.read(openSessionsProvider), isEmpty);

    // Rescan: the good file matches size and mtime and is skipped.
    await scan.refreshAll();
    summary =
        (container.read(folderScanProvider) as FolderScanFinished).summary;
    expect(summary.unchanged, 1);
    expect(summary.added, 0);
    expect(summary.failures, hasLength(1), reason: 'retried, still broken');

    // Touch it: a new mtime is a changed file, re-read and updated in place.
    File(good).setLastModifiedSync(DateTime.now().add(const Duration(days: 1)));
    await scan.refreshAll();
    summary =
        (container.read(folderScanProvider) as FolderScanFinished).summary;
    expect(summary.updated, 1);
    expect(summary.unchanged, 0);
    final updated = await store.readEntry(good);
    expect(updated!.modifiedMs, isNot(indexed.modifiedMs));
    expect(
      updated.importedAt.millisecondsSinceEpoch,
      indexed.importedAt.millisecondsSinceEpoch,
    );
    expect(
      container.exists(telemetrySessionProvider(TelemetrySource.path(good))),
      isFalse,
    );

    await closeApp(tester, store);
  });

  testWidgets('closing a session releases its file; reopening from the '
      'library brings it back; a deleted file is reported, not opened', (
    tester,
  ) async {
    final path = copyFixture(inTmp('telemetry', 'sebring.duckdb'));
    final source = TelemetrySource.path(path);
    final store = openIndex();
    final container = await pumpApp(tester, store);
    final import = container.read(sessionImportProvider.notifier);

    await import.open(source);
    await tester.pumpAndSettle();
    final first = await container.read(telemetrySessionProvider(source).future);
    expect(await first.database.rows('SELECT 1'), [
      [1],
    ]);
    expect(find.text('Open now'), findsOneWidget);

    // Close: the connection goes, the library row stays.
    await tester.tap(find.byTooltip('Close session'));
    await tester.pumpAndSettle();
    expect(container.read(openSessionsProvider), isEmpty);
    expect(find.text('Open now'), findsNothing);
    expect(find.byType(LibraryRow), findsOneWidget);
    // Released, not merely forgotten: the old handle's connection is closed.
    await expectLater(
      first.database.rows('SELECT 1'),
      throwsA(isA<TelemetryQueryException>()),
    );
    // And not reopened behind the user's back. The old handle being closed
    // proves nothing about a new one: closing used to invalidate the provider
    // while the "Open now" card still watched it, which rebuilt it — a fresh
    // connection, held until quit. Windows refuses to delete a file held that
    // way, but macOS unlinks it regardless, so the delete further down cannot
    // be the only check; the provider's own state is the one every platform
    // sees.
    expect(
      container.read(telemetrySessionProvider(source)).error,
      isA<SessionClosedException>(),
    );

    // Reopen from the index: a fresh connection, read afresh — not a stale
    // cached session served back.
    final entry = (await store.readEntry(path))!;
    expect(await import.openFromLibrary(entry), isTrue);
    await tester.pumpAndSettle();
    final second = await container.read(
      telemetrySessionProvider(source).future,
    );
    expect(identical(second, first), isFalse);
    expect(await second.database.rows('SELECT 1'), [
      [1],
    ]);
    final laps = await container.read(lapsProvider(source).future);
    expect(laps, hasLength(5));
    expect(laps.bestLap!.lapTimeSeconds, closeTo(64.02963, 1e-4));

    // Now the file goes away behind the app's back.
    await tester.tap(find.byTooltip('Close session'));
    await tester.pumpAndSettle();
    expect(
      container.read(telemetrySessionProvider(source)).error,
      isA<SessionClosedException>(),
    );
    await deleteWhenReleased(path);
    expect(await import.openFromLibrary(entry), isFalse);
    await tester.pumpAndSettle();
    expect(container.read(sessionImportProvider), isA<SessionImportFailure>());
    expect(container.read(openSessionsProvider), isEmpty);
    expect(
      find.textContaining('sebring.duckdb is no longer where'),
      findsOneWidget,
    );
    // The index kept what it knew, and "Remove" forgets only the row.
    expect(await store.readEntry(path), isNotNull);
    await container.read(sessionLibraryProvider.notifier).remove(path);
    await tester.pumpAndSettle();
    expect(find.byType(LibraryRow), findsNothing);

    await closeApp(tester, store);
  });

  // Compare's second file (comparison proposal §9, step 1): it joins Open now
  // behind the current session, so it has the one owner every file has and
  // closes the same way — and on Windows, where a held file cannot be
  // deleted, that is the proof it was really let go.
  testWidgets('a file opened behind the current session leaves it current, '
      'is one connection under any spelling, and releases its file on close', (
    tester,
  ) async {
    final basePath = copyFixture(inTmp('telemetry', 'base.duckdb'));
    final behindPath = copyFixture(inTmp('telemetry', 'behind.duckdb'));
    final base = TelemetrySource.path(basePath);
    final behind = TelemetrySource.path(behindPath);
    final store = openIndex();
    final container = await pumpApp(tester, store);
    final import = container.read(sessionImportProvider.notifier);

    await import.open(base);
    await import.open(behind, makeCurrent: false);
    await tester.pumpAndSettle();
    expect(container.read(currentSessionProvider), base);
    expect(container.read(openSessionsProvider), [base, behind]);

    final handle = await container.read(
      telemetrySessionProvider(behind).future,
    );
    final laps = await container.read(lapsProvider(behind).future);
    expect(laps.bestLap!.lapTimeSeconds, closeTo(64.02963, 1e-4));

    if (Platform.isWindows) {
      // The same file, spelled as another program might: still the one
      // connection, not a second handle on the file.
      final respelled = TelemetrySource.path(
        behindPath.toUpperCase().replaceAll(r'\', '/'),
      );
      await import.open(respelled, makeCurrent: false);
      expect(container.read(openSessionsProvider), [base, behind]);
      expect(
        identical(
          await container.read(telemetrySessionProvider(respelled).future),
          handle,
        ),
        isTrue,
      );
    }

    await container.read(openSessionsProvider.notifier).close(behind);
    await tester.pumpAndSettle();
    expect(container.read(currentSessionProvider), base);
    expect(container.read(openSessionsProvider), [base]);
    expect(
      container.read(telemetrySessionProvider(behind)).error,
      isA<SessionClosedException>(),
    );
    await deleteWhenReleased(behindPath);
    expect(File(behindPath).existsSync(), isFalse);

    // The session in front never noticed.
    final front = await container.read(telemetrySessionProvider(base).future);
    expect(await front.database.rows('SELECT 1'), [
      [1],
    ]);

    await container.read(openSessionsProvider.notifier).close(base);
    await tester.pumpAndSettle();
    await deleteWhenReleased(basePath);
    await closeApp(tester, store);
  });
}
