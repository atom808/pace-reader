// Timing-only sessions (results proposal, R5): the user's car in each
// results file, the files no recording was made in, their library rows,
// and the page they open to.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/session_library/application/library_query.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_results/application/session_results.dart';
import 'package:pace_reader/features/session_results/application/timing_only_sessions.dart';
import 'package:pace_reader/features/session_results/application/timing_session.dart';
import 'package:pace_reader/features/session_results/data/results_index_store.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';
import 'package:pace_reader/features/session_results/domain/timing_only.dart';
import 'package:pace_reader/features/session_results/presentation/timing_session_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/results_xml_samples.dart';

const _bahrainPath =
    r'C:\LMU\UserData\Log\Results\2026_11_05_02_38_14-59P1.xml';
const _sarthePath = r'C:\LMU\UserData\Log\Results\2026_10_23_00_48_40-12R1.xml';

final _bahrain = parseResultsXml(bahrainPracticeXml);
final _sarthe = parseResultsXml(sartheRaceXml);

ResultsFileRecord _record(String path) => ResultsFileRecord(
  path: path,
  file: const FileFacts(sizeBytes: 100, modifiedMs: 1000),
  indexedAt: DateTime.utc(2026, 11, 5, 12),
);

ResultsPlayerSession _human(
  String path,
  String name, {
  Set<String>? names,
  int laps = 3,
}) => ResultsPlayerSession(
  path: path,
  kind: ResultsSessionKind.race,
  trackVenue: 'Circuit de la Sarthe',
  trackCourse: 'Circuit de la Sarthe',
  startedAt: DateTime.utc(2026, 10, 23),
  endsAt: DateTime.utc(2026, 10, 23, 1),
  gameVersion: '1.4200',
  indexedAt: DateTime.utc(2026, 11, 5),
  driverIndex: 0,
  driverName: name,
  driverNames: names ?? {name},
  vehicleName: 'Custom Team 2026 #397:LM',
  carClass: 'Hyper',
  lapsCompleted: laps,
  timedLaps: laps,
  bestPaceSeconds: 206.0,
  bestPaceNumber: 2,
);

LibraryEntry _recording(String driver, {String at = '2026-10-23T00_30_00Z'}) =>
    LibraryEntry(
      path: 'C:/rec/$driver.duckdb',
      fileName: '$driver.duckdb',
      kind: LibrarySourceKind.file,
      sizeBytes: 1,
      modifiedMs: 1,
      trackName: 'Circuit de la Sarthe',
      trackLayout: 'Circuit de la Sarthe',
      carName: 'Custom Team 2026 #397:LM',
      carClass: 'Hyper',
      sessionType: SessionType.race,
      driverName: driver,
      recordingTime: at,
      weather: '',
      formatVersion: '1',
      completedLaps: 3,
      timedLaps: 2,
      bestLapSeconds: 206.0,
      bestLapIndex: 1,
      clockGapCount: 0,
      importedAt: DateTime.utc(2026),
    );

void main() {
  group('the human cars in the index', () {
    test('every isPlayer car, with its pace in brief', () async {
      final store = MemoryResultsIndexStore();
      await store.putSession(_record(_bahrainPath), _bahrain);
      await store.putSession(_record(_sarthePath), _sarthe);
      final humans = await store.playerSessions();
      expect(
        humans.map((h) => h.driverName),
        unorderedEquals(['Test Driver', 'Driver One']),
      );
      final one = humans.firstWhere((h) => h.driverName == 'Driver One');
      // Lap 3 has a stop, so lap 2 is the best pace lap.
      expect(one.bestPaceSeconds, 206.8879);
      expect(one.bestPaceNumber, 2);
      expect(one.endsAt, _sarthe.endsAt);
    });
  });

  group('the user\'s car', () {
    test('a file with one human car says who the user is', () {
      final cars = userCars(
        [
          _human('offline.xml', 'Me'),
          _human('online.xml', 'Someone'),
          _human('online.xml', 'Me', names: {'Teammate', 'Me'}),
          _human('other.xml', 'Stranger'),
          _human('other.xml', 'Another'),
        ],
        {'Stranger'},
      ).toList();
      expect(cars.map((c) => (c.car.path, c.driver)), [
        ('offline.xml', 'Me'),
        ('online.xml', 'Me'),
      ], reason: 'the recordings\' names give way to the offline file\'s');
    });

    test('with no such file, the recordings\' names decide', () {
      final cars = userCars(
        [_human('a.xml', 'Someone'), _human('a.xml', 'Me')],
        {'Me'},
      ).toList();
      expect(cars.single.driver, 'Me');
    });
  });

  test('a recording made in a session marks it recorded', () {
    final session = _human('x.xml', 'Me');
    expect(recordedIn(_recording('Me'), session), isTrue);
    expect(
      recordedIn(_recording('Me', at: '2026-10-23T02_30_00Z'), session),
      isFalse,
      reason: 'started after the session ended',
    );
  });

  group('a library row', () {
    test('carries the session as the library knows sessions', () {
      final entry = _human(
        'C:/R/x.xml',
        'Me',
      ).toLibraryEntry(driverName: 'Me too')!;
      expect(entry.kind, LibrarySourceKind.results);
      expect(entry.fileName, 'x.xml');
      expect(entry.sessionType, SessionType.race);
      expect(entry.recordedAt, DateTime.utc(2026, 10, 23));
      expect(entry.bestLapSeconds, 206.0);
      expect(entry.bestLapNumber, 2);
      expect(entry.driverName, 'Me too');
      expect(LibrarySource.of(entry), LibrarySource.timingOnly);
    });

    test('the Source filter narrows, and is offered only with a choice', () {
      final timing = _human('C:/R/x.xml', 'Me').toLibraryEntry()!;
      final recorded = _recording('Me');
      const query = LibraryQuery(sources: {LibrarySource.timingOnly});
      expect(applyLibraryQuery([timing, recorded], query), [timing]);
      expect(query.activeFilterCount, 1);
      expect(LibraryFacets.from([recorded]).sources, isEmpty);
      expect(
        LibraryFacets.from([timing, recorded]).sources.map((f) => f.count),
        [1, 1],
      );
    });

    test('a timing-only lap can hold the personal best', () {
      final timing = _human('C:/R/x.xml', 'Me').toLibraryEntry()!;
      final slower = LibraryEntry(
        path: 'C:/rec/slow.duckdb',
        fileName: 'slow.duckdb',
        kind: LibrarySourceKind.file,
        sizeBytes: 1,
        modifiedMs: 1,
        trackName: timing.trackName,
        trackLayout: timing.trackLayout,
        carName: timing.carName,
        carClass: timing.carClass,
        sessionType: SessionType.practice,
        driverName: 'Me',
        recordingTime: '2026-11-01T00_00_00Z',
        weather: '',
        formatVersion: '1',
        completedLaps: 3,
        timedLaps: 2,
        bestLapSeconds: 207.0,
        bestLapIndex: 1,
        clockGapCount: 0,
        importedAt: DateTime.utc(2026),
      );
      final best = personalBestsOf([timing, slower])[timing.personalBestKey]!;
      expect(best.path, timing.path);
      expect(best.sessionCount, 2);
    });

    test('recording times are stamped the way LMU stamps them', () {
      expect(
        formatRecordingTime(DateTime.utc(2026, 7, 7, 6, 42, 17)),
        '2026-07-07T06_42_17Z',
      );
    });
  });

  test('the file\'s laps become laps on its own clock', () {
    final laps = lapsOfResults(_bahrain.player!.laps);
    expect(laps.map((l) => l.index), [0, 1, 2, 3, 4]);
    // Lap 3 starts at 311.2858, where lap 2 ends.
    expect(laps[2].startSeconds, 311.2858);
    expect(laps[1].endSeconds, 311.2858);
    expect(laps[2].lapTimeSeconds, 108.1520);
    // Lap 4 has a time but no sectors: invalidated, so not a timed lap.
    expect(laps[3].lapTimeSeconds, isNull);
    expect(laps.last.endSeconds, isNull);
  });

  testWidgets('the page shows the timing and only the timing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = MemoryResultsIndexStore();
    await store.putSession(_record(_bahrainPath), _bahrain);
    final container = ProviderContainer(
      overrides: [resultsIndexStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    container
        .read(openTimingSessionProvider.notifier)
        .open(_bahrainPath, 'Test Driver');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TimingSessionScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Timing only'), findsWidgets);
    expect(find.text('Session results'), findsOneWidget);
    expect(find.text('Laps'), findsWidgets);
    expect(find.text('Race control'), findsOneWidget);
    expect(find.text('Track limits: Invalid Lap Cut Track'), findsOneWidget);
    expect(find.text('lap invalidated'), findsOneWidget);
    // One car in class: no class pace to show.
    expect(find.text('Class pace'), findsNothing);
  });
}
