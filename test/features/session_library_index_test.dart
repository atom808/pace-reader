// The Session Library's index stores (SPEC.md §9.6), against real rows.
//
// drift runs here on an in-memory SQLite (`NativeDatabase.memory`), which a
// plain `flutter test` can open: `package:sqlite3` bundles its own SQLite
// through a build hook, unlike `dart_duckdb`, whose native library links only
// into a compiled app. So the desktop store's SQL is checked in the unit
// suite, not just under `integration_test`.
//
// Both stores run the same cases. The web build keeps its index in memory
// (see `MemorySessionIndexStore`), and the point of putting the rules above
// the store is that the two cannot disagree — which only holds if something
// checks it.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/session_library/data/library_database.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';

import '../fixtures/session_library_samples.dart';

final _indexedAt = DateTime.utc(2026, 9, 1, 12);

void main() {
  // Each test opens its own in-memory database on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final stores = <String, SessionIndexStore Function()>{
    'drift (desktop)': () =>
        DriftSessionIndexStore(LibraryDatabase(NativeDatabase.memory())),
    'memory (web)': MemorySessionIndexStore.new,
  };

  for (final MapEntry(key: name, value: open) in stores.entries) {
    group(name, () {
      late SessionIndexStore store;
      setUp(() => store = open());
      tearDown(() => store.close());

      test('a row round-trips every field, exactly', () async {
        // The fixture's own mtime, to the millisecond: drift's default
        // Unix-seconds DateTime storage would have truncated the .710 and
        // made every rescan see a changed file.
        final entry = sebringFixture.entry(
          indexedAt: _indexedAt,
          modifiedMs: 1790726677710,
          lastOpenedAt: DateTime.utc(2026, 9, 2, 8, 30, 15, 123),
        );
        await store.upsertEntry(entry);

        final read = await store.readEntry(entry.path);
        expect(read, entry);
        expect(read!.modifiedMs, 1790726677710);
        expect(
          read.lastOpenedAt!.millisecondsSinceEpoch,
          DateTime.utc(2026, 9, 2, 8, 30, 15, 123).millisecondsSinceEpoch,
        );
        // What the index says about the checked-in fixture, as measured
        // against the file: laps 1-3 timed, lap 3 (shown as 4) the best.
        expect(read.trackName, 'Sebring International Raceway');
        expect(read.trackLayout, 'Sebring School Circuit');
        expect(read.bestLapSeconds, closeTo(64.0296, 1e-4));
        expect(read.bestLapNumber, 4);
        expect(read.completedLaps, 4);
        expect(read.timedLaps, 3);
        expect(read.clockGapCount, 0);
      });

      test('reads come back newest recording first', () async {
        for (final sample in sampleSessions) {
          await store.upsertEntry(sample.entry(indexedAt: _indexedAt));
        }
        final order = [for (final e in await store.readEntries()) e.fileName];
        // Spa (24 Jul), Interlagos (22 Jul), then the two Sebring files,
        // which are the same recording (7 Jul 06:42:17Z) — tied, and broken
        // by path so the order is stable.
        expect(order, [
          'Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb',
          'Autódromo José Carlos Pace_P_2026-07-22T02_43_34Z.duckdb',
          'Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb',
          'sebring_race_laps0_3.duckdb',
        ]);
      });

      test('upsert replaces by path instead of duplicating', () async {
        final first = sebringRace.entry(indexedAt: _indexedAt, modifiedMs: 1);
        final second = sebringRace.entry(indexedAt: _indexedAt, modifiedMs: 2);
        await store.upsertEntry(first);
        await store.upsertEntry(second);
        final all = await store.readEntries();
        expect(all, hasLength(1));
        expect(all.single.modifiedMs, 2);
      });

      test('markOpened stamps one row and leaves the rest alone', () async {
        await store.upsertEntry(sebringRace.entry(indexedAt: _indexedAt));
        await store.upsertEntry(spaQualify.entry(indexedAt: _indexedAt));
        final at = DateTime.utc(2026, 9, 3, 19, 5);
        await store.markOpened(sebringRace.path, at);

        final race = await store.readEntry(sebringRace.path);
        final spa = await store.readEntry(spaQualify.path);
        expect(race!.lastOpenedAt!.isAtSameMomentAs(at), isTrue);
        expect(spa!.lastOpenedAt, isNull);
      });

      test('removing a row forgets only that row', () async {
        await store.upsertEntry(sebringRace.entry(indexedAt: _indexedAt));
        await store.upsertEntry(spaQualify.entry(indexedAt: _indexedAt));
        await store.removeEntry(sebringRace.path);
        expect(await store.readEntry(sebringRace.path), isNull);
        expect(await store.readEntry(spaQualify.path), isNotNull);
      });

      test(
        'a session with no timed lap stores a null best, not zero',
        () async {
          // Built from the Qualify sample's garage lap and open final lap only:
          // nothing timed, so there is no best to record — and 0.000 would
          // otherwise win every personal-best comparison.
          final facts = spaQualify.facts;
          final untimed = LibraryEntry.derive(
            path: '/tmp/untimed.duckdb',
            fileName: 'untimed.duckdb',
            kind: LibrarySourceKind.file,
            file: const FileFacts(sizeBytes: 1, modifiedMs: 1),
            facts: SessionFacts(
              metadata: facts.metadata,
              laps: [facts.laps.first, facts.laps.last],
              clockGapCount: 1,
            ),
            now: _indexedAt,
          );
          await store.upsertEntry(untimed);
          final read = await store.readEntry(untimed.path);
          expect(read!.bestLapSeconds, isNull);
          expect(read.bestLapIndex, isNull);
          expect(read.timedLaps, 0);
        },
      );

      test('folders are remembered in the order they were added', () async {
        final a = LibraryFolder(path: r'D:\LMU\Telemetry', addedAt: _indexedAt);
        final b = LibraryFolder(
          path: '/Users/me/Telemetry',
          addedAt: _indexedAt.add(const Duration(minutes: 1)),
        );
        await store.upsertFolder(a);
        await store.upsertFolder(b);
        await store.upsertFolder(
          a.scanned(
            at: _indexedAt.add(const Duration(hours: 1)),
            fileCount: 12,
          ),
        );

        final folders = await store.readFolders();
        expect([for (final f in folders) f.path], [a.path, b.path]);
        expect(folders.first.lastScanFileCount, 12);
        expect(folders.last.lastScannedAt, isNull);

        await store.removeFolder(a.path);
        expect([for (final f in await store.readFolders()) f.path], [b.path]);
      });
    });
  }

  test('a re-read keeps when the session was first imported', () {
    // "Imported" is when the library first saw the file; a rewrite of the
    // file must not make an old session look new.
    final first = sebringRace.entry(indexedAt: _indexedAt, modifiedMs: 1);
    final later = LibraryEntry.derive(
      path: sebringRace.path,
      fileName: sebringRace.fileName,
      kind: LibrarySourceKind.file,
      file: const FileFacts(sizeBytes: 25358336, modifiedMs: 2),
      facts: sebringRace.facts,
      now: _indexedAt.add(const Duration(days: 3)),
      previous: first.copyWith(lastOpenedAt: _indexedAt),
    );
    expect(later.importedAt, _indexedAt);
    expect(
      later.lastOpenedAt,
      _indexedAt,
      reason: 'a rescan must not forget the session was opened',
    );
    expect(later.modifiedMs, 2);
  });
}
