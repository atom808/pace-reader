// The Session Library screen over a populated index (SPEC.md §8.1, §9.6):
// search, filter chips, personal-best badges, reopening, the missing-file
// row, and the "Open now" section.
//
// Every row is one of the four real recordings in `session_library_samples.dart`
// (three samples plus the checked-in fixture), so the numbers asserted are the
// ones read out of the files — Sebring's 1:03.941 and Interlagos's 1:37.300 —
// not invented ones.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/presentation/library_list.dart';
import 'package:pace_reader/features/session_library/presentation/library_widgets.dart';
import 'package:pace_reader/features/session_library/presentation/open_now_section.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/identity/class_chip.dart';

import '../design_system/portal_semantics.dart';
import '../fixtures/session_library_samples.dart';
import 'session_library_harness.dart';

/// Tall enough that every row is built: the list is a lazy sliver, and with
/// the "Open now" cards above it the last rows fall below a 900 px viewport.
const _tall = Size(1280, 1500);

Finder _row(SampleSession s) => find.byKey(ValueKey(s.path));

Finder _rowText(SampleSession s, String text) =>
    find.descendant(of: _row(s), matching: find.textContaining(text));

Finder _chip(String label) => find.widgetWithText(FilterChip, label);

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  group('the list', () {
    testWidgets('shows every indexed session, newest recording first, '
        'from the index alone', (tester) async {
      final h = await pumpLibraryScreen(tester, indexed: sampleSessions);

      expect(find.byType(LibraryRow), findsNWidgets(4));
      // Newest first: Spa (24 Jul), Interlagos (22 Jul), then the Sebring
      // pair, which is the same 7 Jul recording.
      final spa = tester.getTopLeft(_row(spaQualify)).dy;
      final interlagos = tester.getTopLeft(_row(interlagosPractice)).dy;
      final sebring = tester.getTopLeft(_row(sebringRace)).dy;
      expect(spa, lessThan(interlagos));
      expect(interlagos, lessThan(sebring));

      // Facts straight from each file's metadata and laps — the row never
      // opens a recording.
      expect(
        _rowText(
          spaQualify,
          'Circuit de Spa-Francorchamps — Circuit de Spa-Francorchamps Endurance',
        ),
        findsOneWidget,
      );
      // The car by its model, then the entry without its pack tag.
      expect(
        _rowText(spaQualify, 'Ferrari 499P · AF Corse #83 · '),
        findsOneWidget,
      );
      // The class is its chip, not the file's "Hyper" in the text line.
      expect(
        find.descendant(
          of: find.descendant(
            of: _row(spaQualify),
            matching: find.byType(ClassChip),
          ),
          matching: find.text('HY'),
        ),
        findsOneWidget,
      );
      expect(_rowText(spaQualify, 'Hyper'), findsNothing);
      expect(_rowText(spaQualify, '2:02.737'), findsOneWidget);
      expect(_rowText(sebringRace, '1:03.941'), findsOneWidget);
      expect(_rowText(sebringRace, 'lap 11'), findsOneWidget);
      expect(_rowText(interlagosPractice, '1:37.300'), findsOneWidget);
      // Interlagos names its layout after the track, so the circuit is not
      // printed twice.
      expect(
        _rowText(interlagosPractice, 'Autódromo José Carlos Pace —'),
        findsNothing,
      );
      // The recording clock's discontinuities are counted at import (§5.2).
      expect(_rowText(spaQualify, '1 clock gap'), findsOneWidget);
      expect(_rowText(sebringRace, 'clock gap'), findsNothing);
      // A recording date in the recording's own (UTC) clock.
      expect(_rowText(sebringRace, '7 Jul 2026'), findsOneWidget);
      expect(_rowText(sebringRace, '06:42 UTC'), findsOneWidget);

      // A check that every row is present is a `stat`, not an open.
      expect(h.fileSystem.statted, isNotEmpty);
      expect(h.open, isEmpty);
    });

    testWidgets('a session with no timed lap says so instead of showing '
        '0:00.000', (tester) async {
      // Spa's two rows stripped to the garage lap and the open final lap:
      // an out-and-in run, which is a real thing to record.
      final untimed = LibraryEntry.derive(
        path: r'C:\LMU\out_and_in.duckdb',
        fileName: 'out_and_in.duckdb',
        kind: LibrarySourceKind.file,
        file: const FileFacts(sizeBytes: 4200000, modifiedMs: 1000),
        facts: SessionFacts(
          metadata: spaQualify.metadata,
          laps: [spaQualify.lapList.first, spaQualify.lapList.last],
          clockGapCount: 0,
        ),
        now: libraryIndexedAt,
      );
      await pumpLibraryScreen(tester, extraEntries: [untimed]);
      final row = find.byKey(ValueKey(untimed.path));
      expect(
        find.descendant(of: row, matching: find.text('no timed lap')),
        findsOneWidget,
      );
      expect(find.byType(PersonalBestBadge), findsNothing);
    });

    testWidgets('an empty library with a remembered folder says what to do', (
      tester,
    ) async {
      await pumpLibraryScreen(
        tester,
        folders: [
          LibraryFolder(path: r'D:\LMU\Telemetry', addedAt: libraryIndexedAt),
        ],
        fileSystem: FakeSessionFileSystem(folders: {r'D:\LMU\Telemetry': []}),
      );
      expect(find.textContaining('Nothing indexed yet'), findsOneWidget);
      expect(find.text('Open a telemetry session'), findsNothing);
    });

    testWidgets('the welcome surface offers Browse and Add folder', (
      tester,
    ) async {
      await pumpLibraryScreen(tester);
      expect(find.text('Open a telemetry session'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Add folder'), findsWidgets);
    });

    testWidgets('on web there is no Add folder and the copy says uploads', (
      tester,
    ) async {
      await pumpLibraryScreen(
        tester,
        fileSystem: FakeSessionFileSystem(supportsFolders: false),
      );
      expect(find.text('Add folder'), findsNothing);
      expect(find.text('Browse'), findsOneWidget);
    });
  });

  group('personal bests', () {
    testWidgets('one badge per circuit and class, on the fastest session', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);

      // Interlagos, Spa and the Sebring race each hold their scope's best;
      // the Sebring fixture (1:04.030) is slower than the race (1:03.941)
      // over the same layout and class, so it holds none.
      expect(find.byType(PersonalBestBadge), findsNWidgets(3));
      expect(
        find.descendant(
          of: _row(sebringRace),
          matching: find.byType(PersonalBestBadge),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(sebringFixture),
          matching: find.byType(PersonalBestBadge),
        ),
        findsNothing,
      );
    });

    testWidgets('the badge states its scope and how many sessions it beat', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);

      final badge = find.descendant(
        of: _row(sebringRace),
        matching: find.byType(PersonalBestBadge),
      );
      await tester.longPress(badge);
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          'Personal best — Sebring International Raceway — Sebring School '
          'Circuit, LMGT3',
        ),
        findsOneWidget,
      );
      // The trimmed fixture beside it is a copy of this same recording, so
      // there is no second session for the best to have beaten.
      expect(
        find.textContaining('the only timed session here so far'),
        findsOneWidget,
      );
      expect(find.textContaining('1:03.941'), findsWidgets);
    });

    testWidgets('filtering does not move the badge', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await tester.tap(_chip('Race'));
      await tester.pumpAndSettle();
      // Still the same holder, because a best is a fact about the whole
      // library, not about what the filter happens to show.
      expect(find.byType(LibraryRow), findsNWidgets(2));
      expect(
        find.descendant(
          of: _row(sebringRace),
          matching: find.byType(PersonalBestBadge),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(sebringFixture),
          matching: find.byType(PersonalBestBadge),
        ),
        findsNothing,
      );
    });
  });

  group('semantics', () {
    testWidgets('each tooltip in a row has a node of its own, so showing one '
        'cannot break the Windows accessibility tree', (tester) async {
      // Spa's row holds three tooltips — the session type, the PB badge and
      // the clock gap. Merged into the row's node, the last two lost their
      // anchors, and opening either sent a node no parent listed (see
      // AppTooltip).
      final handle = tester.ensureSemantics();
      await pumpLibraryScreen(tester, indexed: sampleSessions, size: _tall);
      expect(orphanablePortalAnchors(tester), isEmpty);

      await tester.longPress(_rowText(spaQualify, 'clock gap'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The recording clock jumps'), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isEmpty);
      handle.dispose();
    });
  });

  group('search and filters', () {
    testWidgets('search matches track, car and driver, ignoring accents', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);

      await _search(tester, 'spa');
      expect(find.byType(LibraryRow), findsOneWidget);
      expect(_row(spaQualify), findsOneWidget);

      // "Autódromo José" without typing either accent.
      await _search(tester, 'autodromo jose');
      expect(find.byType(LibraryRow), findsOneWidget);
      expect(_row(interlagosPractice), findsOneWidget);

      // By car, then by driver.
      await _search(tester, 'af corse');
      expect(_row(spaQualify), findsOneWidget);
      await _search(tester, 'pestana');
      expect(find.byType(LibraryRow), findsNWidgets(4));

      // Two words, from two different fields.
      await _search(tester, 'sebring gt3');
      expect(find.byType(LibraryRow), findsNWidgets(2));
    });

    testWidgets('the count reads "x of y" while narrowed', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      expect(find.text('4 sessions'), findsOneWidget);
      await _search(tester, 'sebring');
      expect(find.text('2 of 4 sessions'), findsOneWidget);
    });

    testWidgets('chips narrow by type, class and track, and count what '
        'they would leave', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);

      // Chips exist only for what the library holds.
      expect(_chip('Practice'), findsOneWidget);
      expect(_chip('Qualify'), findsOneWidget);
      expect(_chip('Race'), findsOneWidget);
      expect(_chip('LMGT3'), findsOneWidget);
      expect(_chip('Hypercar'), findsOneWidget);
      // Three GT3 sessions, one Hypercar: named, not the file's codes.
      expect(
        find.descendant(of: _chip('LMGT3'), matching: find.text('3')),
        findsOneWidget,
      );

      await tester.tap(_chip('LMGT3'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(3));
      expect(_row(spaQualify), findsNothing);

      // Across groups chips narrow: GT3 and Race.
      await tester.tap(_chip('Race'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(2));

      // Within a group they are alternatives: Practice or Race.
      await tester.tap(_chip('Practice'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(3));

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(4));
    });

    testWidgets('a long track list folds to eight chips, says how many are '
        'folded, and never hides a selected one', (tester) async {
      // A driver's library grows one chip per circuit; unbounded, the row
      // would push the list below the fold.
      final entries = [
        for (var i = 0; i < 11; i++)
          LibraryEntry.derive(
            path: '/lmu/track_$i.duckdb',
            fileName: 'track_$i.duckdb',
            kind: LibrarySourceKind.file,
            file: const FileFacts(sizeBytes: 1000000, modifiedMs: 1000),
            facts: SessionFacts(
              metadata: spaQualify.metadata.copyWith(
                trackName: 'Track ${String.fromCharCode(65 + i)}',
                trackLayout: 'Track ${String.fromCharCode(65 + i)}',
              ),
              laps: spaQualify.lapList,
              clockGapCount: 0,
            ),
            now: libraryIndexedAt,
          ),
      ];
      await pumpLibraryScreen(tester, extraEntries: entries);

      Finder trackChip(String name) => _chip(name);
      expect(trackChip('Track A'), findsOneWidget);
      expect(trackChip('Track H'), findsOneWidget);
      expect(trackChip('Track I'), findsNothing);
      expect(find.text('+3 more'), findsOneWidget);

      await tester.tap(find.text('+3 more'));
      await tester.pumpAndSettle();
      expect(trackChip('Track K'), findsOneWidget);
      expect(find.text('Show fewer'), findsOneWidget);

      // Selecting a chip that would fold away keeps it on screen.
      await tester.tap(trackChip('Track K'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show fewer'));
      await tester.pumpAndSettle();
      expect(trackChip('Track K'), findsOneWidget);
      expect(trackChip('Track I'), findsNothing);
      expect(find.text('+2 more'), findsOneWidget);
    });

    testWidgets('the track chip keys on name and layout together', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await tester.tap(
        _chip('Sebring International Raceway — Sebring School Circuit'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(2));
      expect(_row(sebringRace), findsOneWidget);
      expect(_row(sebringFixture), findsOneWidget);
    });

    testWidgets('a filter that matches nothing names itself and offers the '
        'way back, clearing the search box too', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await _search(tester, 'monza');

      expect(find.byType(LibraryRow), findsNothing);
      expect(find.textContaining('No session matches "monza"'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear filters').last);
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(4));
      // The box is emptied with the query — not left showing "monza" over a
      // full list.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('Escape clears the search, and Cmd/Ctrl-F focuses it', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await _search(tester, 'spa');
      expect(find.byType(LibraryRow), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsNWidgets(4));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('the filter survives leaving the screen and coming back', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(tester, indexed: sampleSessions);
      await _search(tester, 'spa');
      h.router.go('/overview');
      await tester.pumpAndSettle();
      h.router.go('/sessions');
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'spa',
      );
    });
  });

  group('reopening from the index', () {
    testWidgets('tapping a present row opens it, makes it current, stamps '
        'lastOpenedAt and goes to the overview', (tester) async {
      final h = await pumpLibraryScreen(tester, indexed: sampleSessions);

      await tester.tap(_row(spaQualify));
      await tester.pumpAndSettle();

      expect(h.current, sourceOf(spaQualify));
      expect(h.location, '/overview');
      final stamped = await h.store.readEntry(spaQualify.path);
      expect(stamped!.lastOpenedAt!.isAtSameMomentAs(libraryNow), isTrue);
      // The rest of the row is what was indexed — reopening does not lose
      // `importedAt`.
      expect(
        stamped.importedAt.isAtSameMomentAs(libraryIndexedAt),
        isTrue,
        reason: 'importedAt is when the library first saw the file',
      );
    });

    testWidgets('a moved file says so by name, in the row and on a tap', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        onDisk: [interlagosPractice, sebringRace, sebringFixture],
      );

      expect(
        _rowText(spaQualify, 'File not found'),
        findsOneWidget,
        reason: 'the row explains itself without a click',
      );
      expect(_rowText(interlagosPractice, 'File not found'), findsNothing);
      // What the index kept is still shown — the best lap outlives the file.
      expect(_rowText(spaQualify, '2:02.737'), findsOneWidget);

      // Not reopenable: a tap re-checks the disk, says so by name and path,
      // and opens nothing.
      await tester.tap(_row(spaQualify));
      await tester.pumpAndSettle();
      expect(h.location, '/sessions');
      expect(h.open, isEmpty);
      expect(
        find.textContaining('${spaQualify.fileName} is no longer where it was'),
        findsOneWidget,
      );
    });

    testWidgets('a file put back is reachable again without a rescan', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        onDisk: [interlagosPractice, sebringRace, sebringFixture],
      );
      expect(_rowText(spaQualify, 'File not found'), findsOneWidget);

      // The user restores the recording from a backup.
      h.fileSystem.files[spaQualify.path] = factsOf(spaQualify);
      await tester.tap(_row(spaQualify));
      await tester.pumpAndSettle();

      expect(h.current, sourceOf(spaQualify));
      expect(h.location, '/overview');
    });

    testWidgets('a rescan asks every row again whether its file is there', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        folders: [
          LibraryFolder(
            path: r'C:\LMU\Telemetry',
            addedAt: libraryIndexedAt,
            lastScannedAt: libraryNow,
            lastScanFileCount: 4,
          ),
        ],
        fileSystem: FakeSessionFileSystem(
          files: diskWith(sampleSessions),
          folders: {
            r'C:\LMU\Telemetry': [sebringRace.path],
          },
        ),
      );
      expect(_rowText(interlagosPractice, 'File not found'), findsNothing);

      // Deleted behind the library's back; nothing has told it yet.
      h.fileSystem.files.remove(interlagosPractice.path);
      await tester.tap(find.widgetWithText(TextButton, 'Refresh'));
      await tester.pumpAndSettle();
      expect(_rowText(interlagosPractice, 'File not found'), findsOneWidget);
      expect(_rowText(spaQualify, 'File not found'), findsNothing);
    });

    testWidgets('Enter on a focused row opens it', (tester) async {
      final h = await pumpLibraryScreen(tester, indexed: sampleSessions);
      final inkWell = find.descendant(
        of: _row(spaQualify),
        matching: find.byType(InkWell),
      );
      Focus.of(
        tester.element(
          find.descendant(of: inkWell, matching: find.byType(Padding)).first,
        ),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.current, sourceOf(spaQualify));
      expect(h.location, '/overview');
    });

    testWidgets('a file rewritten since it was indexed says it will be '
        're-read', (tester) async {
      final fs = FakeSessionFileSystem(
        files: {
          ...diskWith(sampleSessions),
          // Same length, later mtime: exactly the case size alone misses.
          sebringRace.path: FileFacts(
            sizeBytes: sebringRace.sizeBytes,
            modifiedMs: 2000,
          ),
        },
      );
      await pumpLibraryScreen(tester, indexed: sampleSessions, fileSystem: fs);
      expect(_rowText(sebringRace, 'Changed on disk'), findsOneWidget);
      expect(_rowText(spaQualify, 'Changed on disk'), findsNothing);
    });

    testWidgets('Remove from library forgets the row, never the file, and '
        'offers Undo', (tester) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        onDisk: [interlagosPractice, sebringRace, sebringFixture],
      );
      final diskBefore = {...h.fileSystem.files};

      // The missing row carries its one useful action as a visible button.
      await tester.tap(
        find.descendant(
          of: _row(spaQualify),
          matching: find.byIcon(Icons.delete_sweep_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(_row(spaQualify), findsNothing);
      expect(find.byType(LibraryRow), findsNWidgets(3));
      expect(await h.store.readEntry(spaQualify.path), isNull);
      expect(h.fileSystem.files, diskBefore);
      expect(find.textContaining('The file was not touched'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(_row(spaQualify), findsOneWidget);
      expect(await h.store.readEntry(spaQualify.path), isNotNull);
    });

    testWidgets('a present row removes from its overflow menu', (tester) async {
      final h = await pumpLibraryScreen(tester, indexed: sampleSessions);
      await tester.tap(
        find.descendant(
          of: _row(sebringFixture),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      expect(_row(sebringFixture), findsNothing);
      expect(await h.store.readEntry(sebringFixture.path), isNull);
    });

    testWidgets('removing the PB holder moves the badge to the next best', (
      tester,
    ) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await tester.tap(
        find.descendant(
          of: _row(sebringRace),
          matching: find.byIcon(Icons.more_horiz),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from library'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _row(sebringFixture),
          matching: find.byType(PersonalBestBadge),
        ),
        findsOneWidget,
      );
    });
  });

  group('upload rows (web)', () {
    // A browser upload is bytes in this visit. There is no path to go back
    // to, so the row describes the session but cannot reopen it (§9.2).
    final upload = LibraryEntry.derive(
      path: 'sebring.duckdb',
      fileName: 'sebring.duckdb',
      kind: LibrarySourceKind.upload,
      file: const FileFacts(sizeBytes: 23867392, modifiedMs: 0),
      facts: sebringFixture.facts,
      now: libraryIndexedAt,
    );

    testWidgets('say so, and a tap explains instead of failing in DuckDB', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        extraEntries: [upload],
        fileSystem: FakeSessionFileSystem(supportsFolders: false),
      );
      final row = find.byKey(ValueKey(upload.path));
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('Uploaded this visit'),
        ),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A browser can only open what is uploaded to it'),
        findsOneWidget,
      );
      expect(h.location, '/sessions');
      expect(h.open, isEmpty);
    });

    testWidgets('an upload still open this visit becomes current again', (
      tester,
    ) async {
      final bytes = Uint8List(8);
      final source = TelemetrySource.bytes('sebring.duckdb', bytes);
      final h = await pumpLibraryScreen(
        tester,
        extraEntries: [upload],
        open: [sebringRace],
        overrides: [
          sessionMetadataProvider(source)
              .overrideWith((ref) async => sebringFixture.metadata),
          lapsProvider(source)
              .overrideWith((ref) async => sebringFixture.lapList),
          sessionClockGapsProvider(source)
              .overrideWith((ref) async => const []),
        ],
        fileSystem: FakeSessionFileSystem(supportsFolders: false),
        size: _tall,
      );
      h.container.read(openSessionsProvider.notifier).open(source);
      // Something else is current now.
      h.container
          .read(openSessionsProvider.notifier)
          .open(sourceOf(sebringRace));
      await tester.pumpAndSettle();
      expect(h.current, sourceOf(sebringRace));

      await tester.tap(find.byKey(ValueKey(upload.path)));
      await tester.pumpAndSettle();
      expect(h.current, source);
      expect(h.location, '/overview');
    });
  });

  group('last opened', () {
    testWidgets('is on the row, in relative terms, only once opened', (
      tester,
    ) async {
      await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        lastOpened: {
          sebringRace.path: libraryNow.subtract(const Duration(hours: 2)),
          spaQualify.path: libraryNow.subtract(
            const Duration(days: 1, hours: 1),
          ),
        },
      );
      expect(_rowText(sebringRace, 'opened 2 h ago'), findsOneWidget);
      expect(_rowText(spaQualify, 'opened yesterday'), findsOneWidget);
      expect(_rowText(interlagosPractice, 'opened'), findsNothing);
    });
  });

  group('open now', () {
    testWidgets('is absent with nothing open', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      expect(find.byType(OpenSessionCard), findsNothing);
      expect(find.text('Open now'), findsNothing);
    });

    testWidgets('shows a card per open session with the current one marked', (
      tester,
    ) async {
      await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        open: [sebringRace, spaQualify],
        size: _tall,
      );
      expect(find.text('Open now'), findsOneWidget);
      expect(find.byType(OpenSessionCard), findsNWidgets(2));
      // The front of the open list is current, and only it says so.
      expect(find.text('Current'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is OpenSessionCard && w.isCurrent,
          ),
          matching: find.text('Sebring International Raceway'),
        ),
        findsOneWidget,
      );
      // The library row of an open session says it is open.
      expect(
        find.descendant(of: _row(sebringRace), matching: find.text('open')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _row(interlagosPractice),
          matching: find.text('open'),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping the second open session makes it the current one '
        'before navigating (the Phase 1 bug)', (tester) async {
      // With two sessions open, every feature screen reads the front of the
      // list. The Phase 1 card only navigated, so tapping the second showed
      // the first.
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        open: [sebringRace, spaQualify],
        size: _tall,
      );
      expect(h.current, sourceOf(sebringRace));

      final spaCard = find.byWidgetPredicate(
        (w) => w is OpenSessionCard && w.source == sourceOf(spaQualify),
      );
      await tester.tap(spaCard);
      await tester.pumpAndSettle();

      expect(h.current, sourceOf(spaQualify));
      expect(h.open.first, sourceOf(spaQualify));
      expect(h.open, hasLength(2), reason: 'switching does not close');
      expect(h.location, '/overview');
    });

    testWidgets('the card is reachable and activatable from the keyboard', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        open: [sebringRace, spaQualify],
        size: _tall,
      );
      final spaCard = find.byWidgetPredicate(
        (w) => w is OpenSessionCard && w.source == sourceOf(spaQualify),
      );
      // `Focus.of` from inside the Hoverable finds its focus node — the
      // card's one Tab stop.
      final focus = Focus.of(
        tester.element(
          find.descendant(of: spaCard, matching: find.byType(SquircleCard)),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(h.current, sourceOf(spaQualify));
      expect(h.location, '/overview');
    });

    testWidgets('Close releases the session and the library keeps it', (
      tester,
    ) async {
      final h = await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        open: [sebringRace, spaQualify],
        size: _tall,
      );
      await tester.tap(find.byTooltip('Close session').first);
      await tester.pumpAndSettle();

      expect(h.open, [sourceOf(spaQualify)]);
      expect(h.current, sourceOf(spaQualify));
      expect(find.byType(OpenSessionCard), findsOneWidget);
      // Closing is not forgetting.
      expect(_row(sebringRace), findsOneWidget);
      expect(await h.store.readEntry(sebringRace.path), isNotNull);
    });

    testWidgets('closing the last session leaves the library, not the '
        'welcome card', (tester) async {
      await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        open: [sebringRace],
        size: _tall,
      );
      await tester.tap(find.byTooltip('Close session'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenSessionCard), findsNothing);
      expect(find.text('Open a telemetry session'), findsNothing);
      expect(find.byType(LibraryRow), findsNWidgets(4));
    });
  });

  group('index failures', () {
    testWidgets('an index that cannot be opened says so and does not block '
        'importing', (tester) async {
      await pumpLibraryScreen(tester, storeOverride: BrokenSessionIndexStore());
      expect(
        find.textContaining("The library index couldn't be opened"),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Open file'), findsOneWidget);
    });

    testWidgets('an import that opens but cannot be recorded is still open, '
        'and warns', (tester) async {
      final h = await pumpLibraryScreen(
        tester,
        storeOverride: BrokenSessionIndexStore(readable: true),
        open: const [],
        indexed: const [],
        onDisk: [sebringFixture],
      );
      await h.container
          .read(sessionImportProvider.notifier)
          .open(sourceOf(sebringFixture));
      await tester.pumpAndSettle();

      expect(h.open, [sourceOf(sebringFixture)]);
      expect(
        find.textContaining('could not be added to the library'),
        findsOneWidget,
      );
    });
  });

  group('motion', () {
    testWidgets('rows fold out when a filter removes them and in when it '
        'clears', (tester) async {
      await pumpLibraryScreen(tester, indexed: sampleSessions);
      await tester.enterText(find.byType(TextField), 'spa');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      // Mid-flight: the leaving rows are still mounted, shrinking.
      expect(find.byType(LibraryRow).evaluate().length, greaterThan(1));
      await tester.pumpAndSettle();
      expect(find.byType(LibraryRow), findsOneWidget);
    });

    testWidgets('with animations disabled the change is immediate', (
      tester,
    ) async {
      await pumpLibraryScreen(
        tester,
        indexed: sampleSessions,
        disableAnimations: true,
      );
      await tester.enterText(find.byType(TextField), 'spa');
      await tester.pump();
      await tester.pump();
      expect(find.byType(LibraryRow), findsOneWidget);
    });
  });
}
