// The results index (results proposal, R1): both stores against the same
// cases, and the link from a recording to its session.

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/session_metadata.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_results/data/results_database.dart';
import 'package:pace_reader/features/session_results/data/results_file_system.dart';
import 'package:pace_reader/features/session_results/data/results_index_store.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/results_link.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';

import '../fixtures/results_xml_samples.dart';

const _bahrainPath =
    r'C:\LMU\UserData\Log\Results\2026_11_05_00_06_52-48P1.xml';
const _sarthePath = r'C:\LMU\UserData\Log\Results\2026_10_23_00_48_40-12R1.xml';

final _bahrain = parseResultsXml(bahrainPracticeXml);
final _sarthe = parseResultsXml(sartheRaceXml);

ResultsFileRecord _record(String path, {int size = 100, int mtime = 1000}) =>
    ResultsFileRecord(
      path: path,
      file: FileFacts(sizeBytes: size, modifiedMs: mtime),
      indexedAt: DateTime.utc(2026, 11, 5, 12),
    );

/// The library row for the user's Bahrain recording: what the index says
/// about `Bahrain International Circuit_P_2026-11-05T02_38_28Z.duckdb`.
LibraryEntry _recording({
  String recordingTime = '2026-11-05T02_38_28Z',
  String carName = 'Ferrari AF Corse 2026 #50:LM',
  String carClass = 'Hyper',
  String driverName = 'Test Driver',
  String trackLayout = 'Bahrain International Circuit',
  SessionType sessionType = SessionType.practice,
  double? best = 107.7979,
}) => LibraryEntry(
  path: r'C:\LMU\UserData\Telemetry\bahrain.duckdb',
  fileName: 'bahrain.duckdb',
  kind: LibrarySourceKind.file,
  sizeBytes: 1,
  modifiedMs: 1,
  trackName: 'Bahrain International Circuit',
  trackLayout: trackLayout,
  carName: carName,
  carClass: carClass,
  sessionType: sessionType,
  driverName: driverName,
  recordingTime: recordingTime,
  weather: 'Clear',
  formatVersion: '1',
  completedLaps: 5,
  timedLaps: best == null ? 0 : 3,
  bestLapSeconds: best,
  bestLapIndex: best == null ? null : 3,
  clockGapCount: 0,
  importedAt: DateTime.utc(2026, 11, 5),
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  final stores = <String, ResultsIndexStore Function()>{
    'drift (desktop)': () =>
        DriftResultsIndexStore(ResultsDatabase(NativeDatabase.memory())),
    'memory (web)': MemoryResultsIndexStore.new,
  };

  for (final MapEntry(key: name, value: open) in stores.entries) {
    group(name, () {
      late ResultsIndexStore store;
      setUp(() => store = open());
      tearDown(() => store.close());

      test('a session round-trips whole, events and stints included', () async {
        await store.putSession(_record(_sarthePath), _sarthe);
        expect(await store.readSession(_sarthePath), _sarthe);
        await store.putSession(_record(_bahrainPath), _bahrain);
        expect(await store.readSession(_bahrainPath), _bahrain);
        expect(await store.sessionCount(), 2);
      });

      test('a re-read file replaces its rows rather than adding', () async {
        await store.putSession(_record(_bahrainPath), _sarthe);
        await store.putSession(_record(_bahrainPath, mtime: 2000), _bahrain);
        expect(await store.readSession(_bahrainPath), _bahrain);
        expect(await store.sessionCount(), 1);
        expect(await store.readFileFacts(), {
          _bahrainPath: const FileFacts(sizeBytes: 100, modifiedMs: 2000),
        });
      });

      test('candidates are narrowed to track, kind and time', () async {
        await store.putSession(_record(_bahrainPath), _bahrain);
        await store.putSession(_record(_sarthePath), _sarthe);
        Future<List<String>> paths(
          DateTime at, {
          String track = 'Bahrain International Circuit',
        }) async => [
          for (final c in await store.candidates(
            trackVenue: track,
            trackCourse: track,
            kind: ResultsSessionKind.practice,
            from: at,
            to: at,
          ))
            c.path,
        ];

        final during = DateTime.utc(2026, 11, 5, 2, 40);
        expect(await paths(during), [_bahrainPath]);
        // Before the session started, after its last lap, at another track.
        expect(await paths(DateTime.utc(2026, 11, 5, 2, 30)), isEmpty);
        expect(await paths(DateTime.utc(2026, 11, 5, 3)), isEmpty);
        expect(await paths(during, track: 'Circuit de la Sarthe'), isEmpty);

        final c = (await store.candidates(
          trackVenue: 'Bahrain International Circuit',
          trackCourse: 'Bahrain International Circuit',
          kind: ResultsSessionKind.practice,
          from: during,
          to: during,
        )).single;
        expect(c.drivers.single.lapTimes, [109.8764, 108.1520, 107.7979]);
        expect(c.drivers.single.driverNames, {'Test Driver'});
      });

      test('folders are remembered in the order added', () async {
        final a = LibraryFolder(path: 'A', addedAt: DateTime.utc(2026));
        final b = LibraryFolder(path: 'B', addedAt: DateTime.utc(2027));
        await store.upsertFolder(a);
        await store.upsertFolder(b);
        await store.upsertFolder(
          a.scanned(at: DateTime.utc(2028), fileCount: 1054),
        );
        final folders = await store.readFolders();
        expect([for (final f in folders) f.path], ['A', 'B']);
        expect(folders.first.lastScanFileCount, 1054);
        await store.removeFolder('A');
        expect((await store.readFolders()).single.path, 'B');
      });
    });
  }

  group('linking a recording', () {
    final candidate = ResultsCandidate.of(_bahrainPath, _bahrain);

    test('the recording\'s best lap is one of the car\'s laps', () {
      final link = linkRecording(_recording(), [candidate]);
      expect(link, isNotNull);
      expect(link!.path, _bahrainPath);
      expect(link.driverIndex, 0);
      expect(link.basis, ResultsLinkBasis.lapTime);
      expect(link.matchedLapSeconds, 107.7979);
    });

    test('a best lap no car has links nothing', () {
      expect(linkRecording(_recording(best: 107.8000), [candidate]), isNull);
    });

    test('another car, class, layout or kind links nothing', () {
      expect(
        linkRecording(_recording(carName: 'Ferrari AF Corse 2026 #51:LM'), [
          candidate,
        ]),
        isNull,
      );
      expect(linkRecording(_recording(carClass: 'GT3'), [candidate]), isNull);
      expect(
        linkRecording(_recording(trackLayout: 'Bahrain Outer Circuit'), [
          candidate,
        ]),
        isNull,
      );
      expect(
        linkRecording(_recording(sessionType: SessionType.race), [candidate]),
        isNull,
      );
    });

    test('a recording started outside the session links nothing', () {
      // 3 min before the session's 02:37:25Z start, and after its end
      // (lap 4 ends at 02:46:12Z, plus the 1 min allowed).
      expect(
        linkRecording(_recording(recordingTime: '2026-11-05T02_34_25Z'), [
          candidate,
        ]),
        isNull,
      );
      expect(
        linkRecording(_recording(recordingTime: '2026-11-05T02_48_00Z'), [
          candidate,
        ]),
        isNull,
      );
      // Within the 2 min allowed before the start.
      expect(
        linkRecording(_recording(recordingTime: '2026-11-05T02_36_00Z'), [
          candidate,
        ]),
        isNotNull,
      );
    });

    test('with no timed lap, the driver and time decide, and say so', () {
      final link = linkRecording(_recording(best: null), [candidate]);
      expect(link!.basis, ResultsLinkBasis.timeOnly);
      expect(link.matchedLapSeconds, isNull);
    });

    test('two cars in one livery: the lap decides, then the driver', () {
      final twin = _bahrain.copyWith(
        drivers: [
          _bahrain.drivers.single.copyWith(
            index: 0,
            name: 'Someone Else',
            isPlayer: false,
            laps: [_bahrain.drivers.single.laps[1]],
          ),
          _bahrain.drivers.single.copyWith(index: 1),
        ],
      );
      final link = linkRecording(_recording(), [
        ResultsCandidate.of(_bahrainPath, twin),
      ]);
      expect(link!.driverIndex, 1, reason: 'only car 1 has the 1:47.798');

      final both = linkRecording(_recording(best: 109.8764), [
        ResultsCandidate.of(_bahrainPath, twin),
      ]);
      expect(both!.driverIndex, 1, reason: 'both have it; car 1 is the driver');
    });

    test('a restart at the same place: the lap picks the right file', () {
      final restart = _bahrain.copyWith(
        startedAt: _bahrain.startedAt.add(const Duration(minutes: 3)),
        drivers: [
          _bahrain.drivers.single.copyWith(
            laps: [
              for (final l in _bahrain.drivers.single.laps)
                l.copyWith(lapSeconds: l.lapSeconds == null ? null : 110),
            ],
          ),
        ],
      );
      final link = linkRecording(_recording(), [
        ResultsCandidate.of('restart.xml', restart),
        candidate,
      ]);
      expect(link!.path, _bahrainPath);
    });
  });

  group('the results folder beside a telemetry folder', () {
    test('is found for an LMU install, on either separator', () {
      expect(
        resultsFolderBeside(r'D:\Games\LMU\UserData\Telemetry'),
        r'D:\Games\LMU\UserData\Log\Results',
      );
      expect(
        resultsFolderBeside(r'D:\Games\LMU\userdata\telemetry\'),
        r'D:\Games\LMU\UserData\Log\Results',
      );
      expect(
        resultsFolderBeside('/mnt/lmu/UserData/Telemetry'),
        '/mnt/lmu/UserData/Log/Results',
      );
    });

    test('is not guessed for a copy elsewhere', () {
      expect(resultsFolderBeside(r'D:\LMU Files\Telemetry'), isNull);
    });
  });

  test('the index drops only other cars\' calls that came to nothing', () {
    ResultsEvent call(String driver, String text) => ResultsEvent(
      kind: ResultsEventKind.trackLimits,
      elapsed: 1,
      text: text,
      driverName: driver,
    );
    final session = _sarthe.copyWith(
      events: [
        call('Driver One', 'No Further Action'),
        call('Driver Two', 'No Further Action'),
        call('Driver Two', 'Warning'),
        ..._sarthe.events,
      ],
    );
    final kept = session.forIndex().events;
    expect(kept, hasLength(session.events.length - 1));
    expect(
      kept.where(
        (e) => e.driverName == 'Driver Two' && e.text.startsWith('No'),
      ),
      isEmpty,
    );
    expect(kept.first.driverName, 'Driver One', reason: 'the player\'s own');
  });

  test('stints survive the text column', () {
    const stints = [
      ResultsStint(startLap: 1, endLap: 302, value: '???'),
      ResultsStint(startLap: 303, endLap: 339, value: 'PlayerControl,Clutch'),
    ];
    expect(decodeStints(encodeStints(stints)), stints);
    expect(decodeStints(''), isEmpty);
  });
}
