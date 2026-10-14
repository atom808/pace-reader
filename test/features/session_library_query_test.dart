// Searching, filtering and ranking the library (SPEC.md §8.1), over the four
// real recordings in `session_library_samples.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/session_library/application/library_query.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';

import '../fixtures/session_library_samples.dart';

final _at = DateTime.utc(2026, 9, 1);
final _entries = [for (final s in sampleSessions) s.entry(indexedAt: _at)]
  ..sort(compareNewestFirst);

List<String> _names(List<LibraryEntry> entries) => [
  for (final e in entries) e.fileName,
];

void main() {
  group('an index row is what the file says', () {
    test('the Race sample', () {
      final race = sebringRace.entry(indexedAt: _at);
      // 20 Lap rows: 19 closed, 16 timed (garage lap, two invalidated laps
      // and the open final lap are not), best 1:03.941 on lap 11.
      expect(race.completedLaps, 19);
      expect(race.timedLaps, 16);
      expect(race.bestLapSeconds, closeTo(63.9409, 1e-4));
      expect(race.bestLapNumber, 11);
      expect(race.clockGapCount, 0);
      expect(race.recordedAt, DateTime.utc(2026, 7, 7, 6, 42, 17));
      expect(
        race.circuitLabel,
        'Sebring International Raceway — Sebring School Circuit',
      );
    });

    test('the Practice sample names its only layout after the track', () {
      final practice = interlagosPractice.entry(indexedAt: _at);
      expect(practice.layoutIsDistinct, isFalse);
      expect(practice.circuitLabel, 'Autódromo José Carlos Pace');
      // Lap 1 is the untimed out-lap; lap 3 is 1:37.300.
      expect(practice.timedLaps, 2);
      expect(practice.bestLapSeconds, closeTo(97.3003, 1e-4));
      expect(practice.bestLapNumber, 3);
      expect(practice.clockGapCount, 1);
    });

    test('the Qualify sample has one timed lap out of four closed', () {
      final quali = spaQualify.entry(indexedAt: _at);
      expect(quali.completedLaps, 4);
      expect(quali.timedLaps, 1);
      expect(quali.bestLapSeconds, closeTo(122.7366, 1e-4));
      expect(quali.clockGapCount, 1);
    });

    test('an unrecognised recording time is null, not a guess', () {
      expect(
        parseRecordingTime('2026-07-07T06_42_17Z'),
        DateTime.utc(2026, 7, 7, 6, 42, 17),
      );
      expect(parseRecordingTime('yesterday'), isNull);
    });
  });

  group('search', () {
    test('ignores accents and case', () {
      final hits = applyLibraryQuery(
        _entries,
        const LibraryQuery(search: 'autodromo JOSE'),
      );
      expect(_names(hits), [interlagosPractice.fileName]);
    });

    test('matches the layout, not only the track name', () {
      final hits = applyLibraryQuery(
        _entries,
        const LibraryQuery(search: 'school'),
      );
      expect(hits, hasLength(2));
      expect(
        hits.every((e) => e.trackLayout == 'Sebring School Circuit'),
        isTrue,
      );
    });

    test('every word must match, across fields', () {
      // "spa" is in the track, "wec" only in the car name.
      expect(
        _names(
          applyLibraryQuery(_entries, const LibraryQuery(search: 'spa wec')),
        ),
        [spaQualify.fileName],
      );
      expect(
        applyLibraryQuery(_entries, const LibraryQuery(search: 'spa brz')),
        isEmpty,
      );
    });

    test('matches the driver and the car class', () {
      expect(
        applyLibraryQuery(_entries, const LibraryQuery(search: 'pestana')),
        hasLength(4),
      );
      expect(
        _names(
          applyLibraryQuery(_entries, const LibraryQuery(search: 'hyper')),
        ),
        [spaQualify.fileName],
      );
    });

    test('matches the class by the name its chip shows, too', () {
      // The file says "Hyper" and "GT3"; the chips say HYPERCAR and LMGT3.
      expect(
        _names(
          applyLibraryQuery(_entries, const LibraryQuery(search: 'hypercar')),
        ),
        [spaQualify.fileName],
      );
      expect(
        applyLibraryQuery(_entries, const LibraryQuery(search: 'lmgt3')),
        hasLength(3),
      );
    });

    test('matches the car by its model, which no file names', () {
      // AF Corse #83 is a Ferrari 499P; The Bend's #31 a BMW M4 GT3.
      expect(
        _names(
          applyLibraryQuery(_entries, const LibraryQuery(search: 'ferrari')),
        ),
        [spaQualify.fileName],
      );
      expect(
        applyLibraryQuery(_entries, const LibraryQuery(search: 'bmw m4')),
        hasLength(2),
      );
      expect(
        applyLibraryQuery(_entries, const LibraryQuery(search: 'mustang')),
        hasLength(1),
      );
    });
  });

  group('filters', () {
    test('within a group chips are alternatives', () {
      final hits = applyLibraryQuery(
        _entries,
        const LibraryQuery(
          sessionTypes: {SessionType.practice, SessionType.qualify},
        ),
      );
      expect(_names(hits), [spaQualify.fileName, interlagosPractice.fileName]);
    });

    test('across groups they narrow', () {
      final hits = applyLibraryQuery(
        _entries,
        const LibraryQuery(
          sessionTypes: {SessionType.race},
          carClasses: {'Hyper'},
        ),
      );
      expect(hits, isEmpty);
    });

    test('the track chip is track *and* layout', () {
      final hits = applyLibraryQuery(
        _entries,
        const LibraryQuery(
          tracks: {
            (
              trackName: 'Sebring International Raceway',
              trackLayout: 'Sebring School Circuit',
            ),
          },
        ),
      );
      expect(hits, hasLength(2));
      final fullCourse = applyLibraryQuery(
        _entries,
        const LibraryQuery(
          tracks: {
            (
              trackName: 'Sebring International Raceway',
              trackLayout: 'Sebring International Raceway',
            ),
          },
        ),
      );
      expect(
        fullCourse,
        isEmpty,
        reason: 'the School Circuit is not the full course (§8.1)',
      );
    });

    test('the car chip is the model, whichever entry ran it', () {
      final m4 = carOf(sebringRace.entry(indexedAt: _at)).key;
      final query = LibraryQuery(cars: {m4});
      expect(applyLibraryQuery(_entries, query), hasLength(2));
      expect(query.activeFilterCount, 1);
      expect(query.isEmpty, isFalse);
      expect(query, LibraryQuery(cars: {m4}));
    });

    test('an empty query keeps the store order', () {
      expect(applyLibraryQuery(_entries, const LibraryQuery()), _entries);
    });
  });

  group('personal bests', () {
    test('are ranked per track, layout and class', () {
      final bests = personalBestsOf(_entries);
      // Three scopes: Interlagos GT3, Spa Hyper, Sebring School GT3.
      expect(bests, hasLength(3));

      final sebring =
          bests[(
            trackName: 'Sebring International Raceway',
            trackLayout: 'Sebring School Circuit',
            carClass: 'GT3',
          )]!;
      // The full race (1:03.941, lap 11) beats the trimmed fixture's best
      // (1:04.030, lap 4) — two rows, one badge. The fixture is laps 0–3 of
      // that same race, so it is one recording, counted once: "fastest of 2"
      // would claim a second session the driver never ran.
      expect(sebring.path, sebringRace.path);
      expect(sebring.lapSeconds, closeTo(63.9409, 1e-4));
      expect(sebring.lapIndex, 10);
      expect(sebring.sessionCount, 1);
    });

    test('copies of one recording count once; different recordings each '
        'count', () {
      final race = sebringRace.entry(indexedAt: _at);
      LibraryEntry copyAt(String path, {String? recordingTime}) =>
          LibraryEntry.derive(
            path: path,
            fileName: path.split('/').last,
            kind: LibrarySourceKind.file,
            file: const FileFacts(sizeBytes: 1, modifiedMs: 1),
            facts: SessionFacts(
              metadata: sebringRace.metadata.copyWith(
                recordingTime:
                    recordingTime ?? sebringRace.metadata.recordingTime,
              ),
              laps: sebringRace.lapList,
              clockGapCount: 0,
            ),
            now: _at,
          );

      final copied = copyAt('/elsewhere/copy.duckdb');
      expect(copied.recordingIdentity, race.recordingIdentity);
      expect(personalBestsOf([race, copied]).values.single.sessionCount, 1);

      final another = copyAt(
        '/elsewhere/next_day.duckdb',
        recordingTime: '2026-07-08T06_42_17Z',
      );
      expect(another.recordingIdentity, isNot(race.recordingIdentity));
      expect(
        personalBestsOf([race, copied, another]).values.single.sessionCount,
        2,
      );
    });

    test('a different class at the same layout is its own scope', () {
      // Same recording, relabelled Hyper: it must not take the GT3 badge.
      final race = sebringRace.entry(indexedAt: _at);
      final hyper = LibraryEntry.derive(
        path: '/tmp/hyper.duckdb',
        fileName: 'hyper.duckdb',
        kind: LibrarySourceKind.file,
        file: const FileFacts(sizeBytes: 1, modifiedMs: 1),
        facts: SessionFacts(
          metadata: sebringRace.metadata.copyWith(carClass: 'Hyper'),
          laps: sebringRace.lapList,
          clockGapCount: 0,
        ),
        now: _at,
      );
      final bests = personalBestsOf([race, hyper]);
      expect(bests, hasLength(2));
      expect(bests.values.every((b) => b.sessionCount == 1), isTrue);
    });

    test('ignore the filter — a best is a fact about the whole library', () {
      // Narrowed to Practice, neither Sebring session is on screen — and the
      // School Circuit best must still belong to the race, not be recomputed
      // from whatever happens to be visible.
      final view = LibraryView.of(
        _entries,
        const LibraryQuery(sessionTypes: {SessionType.practice}),
      );
      expect(_names(view.visible), [interlagosPractice.fileName]);
      final fixture = _entries.firstWhere((e) => e.path == sebringFixture.path);
      final race = _entries.firstWhere((e) => e.path == sebringRace.path);
      expect(view.personalBestHeldBy(fixture), isNull);
      // One recording, under two rows (see the first test in this group).
      expect(view.personalBestHeldBy(race)?.sessionCount, 1);
    });

    test('an exact tie stays with the earlier recording', () {
      final early = sebringRace.entry(indexedAt: _at);
      final lateMeta = sebringRace.metadata.copyWith(
        recordingTime: '2026-08-01T10_00_00Z',
      );
      final late = LibraryEntry.derive(
        path: '/tmp/a_later_copy.duckdb',
        fileName: 'a_later_copy.duckdb',
        kind: LibrarySourceKind.file,
        file: const FileFacts(sizeBytes: 1, modifiedMs: 1),
        facts: SessionFacts(
          metadata: lateMeta,
          laps: sebringRace.lapList,
          clockGapCount: 0,
        ),
        now: _at,
      );
      final best = personalBestsOf([late, early]).values.single;
      expect(best.path, early.path);
    });
  });

  test('facets offer only what the library holds, weekend-ordered', () {
    final facets = LibraryFacets.from(_entries);
    expect(
      [for (final f in facets.sessionTypes) (f.label, f.count)],
      [('Practice', 1), ('Qualify', 1), ('Race', 2)],
    );
    // Named as the chips name them, in running order, keyed by the raw code.
    expect(
      [for (final f in facets.carClasses) (f.label, f.count)],
      [('Hypercar', 1), ('LMGT3', 3)],
    );
    expect([for (final f in facets.carClasses) f.value], ['Hyper', 'GT3']);
    // Cars by model, by class in running order, then by name.
    expect(
      [for (final f in facets.cars) (f.label, f.count)],
      [('Ferrari 499P', 1), ('BMW M4 GT3', 2), ('Ford Mustang GT3', 1)],
    );
    expect(
      [for (final f in facets.tracks) f.label],
      [
        'Autódromo José Carlos Pace',
        'Circuit de Spa-Francorchamps — Circuit de Spa-Francorchamps Endurance',
        'Sebring International Raceway — Sebring School Circuit',
      ],
    );
  });

  test('foldForSearch strips Latin diacritics', () {
    expect(
      foldForSearch('Autódromo José Carlos Pace'),
      'autodromo jose carlos pace',
    );
    expect(foldForSearch('Nürburgring Łódź'), 'nurburgring lodz');
  });
}
