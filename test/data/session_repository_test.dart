// Repository tests against a fake executor (SPEC.md §10, §12).
//
// The point of these is §10's resilience requirement: a malformed or
// unexpected file must produce a *clear, specific* error rather than a crash
// or a wrong number. That's much easier to prove against a fake — real
// malformed telemetry files aren't available to test with, and hand-crafting
// broken .duckdb fixtures for each failure mode would be far more work than
// the failure modes justify.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_repository.dart';
import 'package:pace_reader/data/repositories/session_repository.dart';

/// Answers queries by matching a distinctive fragment of the SQL.
///
/// Matching on a fragment rather than the whole statement keeps these tests
/// about *behaviour* — they'd otherwise fail on any harmless reformatting of a
/// query, which is the classic way a test suite turns into a change tax.
class FakeExecutor implements TelemetryQueryExecutor {
  FakeExecutor(this.responses);

  final Map<String, List<List<Object?>>> responses;
  final List<String> executed = [];

  @override
  Future<List<List<Object?>>> rows(String sql) async {
    executed.add(sql);
    for (final entry in responses.entries) {
      if (sql.contains(entry.key)) return entry.value;
    }
    throw StateError('unstubbed query: $sql');
  }
}

/// The 12 confirmed metadata keys, as `(key, value)` rows.
List<List<Object?>> metadataRows({
  String version = '1',
  String sessionType = 'Race',
  Map<String, String> overrides = const {},
}) {
  final values = {
    'DriverName': 'Diego Pestana',
    'SteamID': '7656',
    'RecordingTime': '2026-07-07T06_42_17Z',
    'SessionTime': '13:00:21',
    'SessionType': sessionType,
    'TrackName': 'Sebring International Raceway',
    'TrackLayout': 'Sebring School Circuit',
    'WeatherConditions': 'Clear',
    'CarName': 'The Bend Team WRT 2025 #31:BRZ',
    'CarClass': 'GT3',
    'CarSetup': '{"WM_PRESSURE-W_FL":{"stringValue":"136 kPa"}}',
    'Version': version,
    ...overrides,
  };
  return [for (final e in values.entries) [e.key, e.value]];
}

void main() {
  group('validateSchema', () {
    test('accepts a file carrying the required catalog tables', () async {
      final repo = SessionRepository(FakeExecutor({
        'information_schema.tables': [
          ['metadata'],
          ['channelsList'],
          ['eventsList'],
          ['Engine RPM'],
        ],
      }));
      await expectLater(repo.validateSchema(), completes);
    });

    test('names the missing tables when the file is not telemetry', () async {
      final repo = SessionRepository(FakeExecutor({
        'information_schema.tables': [
          ['some_other_table'],
        ],
      }));

      await expectLater(
        repo.validateSchema(),
        throwsA(isA<NotTelemetryFileException>()
            .having((e) => e.missingTables, 'missingTables',
                containsAll(['metadata', 'channelsList', 'eventsList']))
            .having((e) => e.message, 'message',
                contains('Le Mans Ultimate'))),
      );
    });
  });

  group('readMetadata', () {
    Future<SessionMetadata> read({
      String version = '1',
      String sessionType = 'Race',
      Map<String, String> overrides = const {},
    }) =>
        SessionRepository(FakeExecutor({
          'FROM metadata': metadataRows(
            version: version,
            sessionType: sessionType,
            overrides: overrides,
          ),
        })).readMetadata();

    test('maps the confirmed 12 keys', () async {
      final meta = await read();
      expect(meta.driverName, 'Diego Pestana');
      expect(meta.sessionType, SessionType.race);
      expect(meta.trackLayout, 'Sebring School Circuit');
      expect(meta.carClass, 'GT3');
      expect(meta.carSetupJson, contains('WM_PRESSURE-W_FL'));
      // SessionTime is a start time-of-day, not a duration — the field name
      // records that so the value can't be misread as one.
      expect(meta.sessionTimeOfDay, '13:00:21');
    });

    test('rejects an unknown format version at open time', () async {
      // The earliest, cheapest place to fail clearly: the alternative is
      // discovering the mismatch later as a missing table.
      await expectLater(
        read(version: '2'),
        throwsA(isA<UnsupportedFormatVersionException>()
            .having((e) => e.found, 'found', '2')
            .having((e) => e.supported, 'supported', ['1'])
            .having((e) => e.message, 'message', contains('newer'))),
      );
    });

    test('rejects a missing version rather than assuming one', () async {
      final rows = metadataRows()..removeWhere((r) => r[0] == 'Version');
      await expectLater(
        SessionRepository(FakeExecutor({'FROM metadata': rows})).readMetadata(),
        throwsA(isA<SchemaMismatchException>()),
      );
    });

    test('rejects an unrecognized session type', () async {
      await expectLater(
        read(sessionType: 'Warmup'),
        throwsA(isA<SchemaMismatchException>()
            .having((e) => e.message, 'message', contains('Warmup'))),
      );
    });
  });

  group('readCatalog', () {
    FakeExecutor catalogExecutor({
      List<List<Object?>>? channels,
      List<List<Object?>>? events,
      List<List<Object?>>? rowCounts,
      List<List<Object?>>? clock,
    }) =>
        FakeExecutor({
          'SELECT (SELECT': clock ?? [[23.5975, 17223]],
          'FROM channelsList': channels ??
              [
                ['GPS Time', 100, 's'],
                ['Lap Dist', 10, 'm'],
                ['Engine Oil Temp', 7, 'C'],
                ['TyresPressure', 10, 'kPa'],
              ],
          'FROM eventsList': events ??
              [
                ['Lap', ''],
                ['Gear', ''],
              ],
          'information_schema.columns': [
            ['TyresPressure', 4],
          ],
          'UNION ALL': rowCounts ??
              [
                ['GPS Time', 17223],
                ['Lap Dist', 1723],
                ['Engine Oil Temp', 1209],
                ['TyresPressure', 1723],
                ['Lap', 2],
                ['Gear', 96],
              ],
        });

    test('reads origin and master row count from the file', () async {
      final catalog = await SessionRepository(catalogExecutor()).readCatalog();
      // Never assumed: measured at 381.09 / 34.57 / 23.60 s across the three
      // samples, a spread too wide for a default or a plausibility check.
      expect(catalog.origin, 23.5975);
      expect(catalog.masterRowCount, 17223);
    });

    test('classifies on-grid and off-grid channels', () async {
      final catalog = await SessionRepository(catalogExecutor()).readCatalog();
      expect(catalog.channel('Lap Dist')!.ridesMasterGrid(17223), isTrue);
      expect(catalog.offGridChannels.map((c) => c.name), ['Engine Oil Temp']);
    });

    test('reads per-corner arity from the table, not the name', () async {
      final catalog = await SessionRepository(catalogExecutor()).readCatalog();
      expect(catalog.channel('TyresPressure')!.isPerCorner, isTrue);
      expect(catalog.channel('Lap Dist')!.isPerCorner, isFalse);
    });

    test('fails clearly when the catalog names a table that is absent', () async {
      // The one schema change catalog-driven discovery can't absorb: additive
      // changes are free, a rename or removal is not (§10).
      final repo = SessionRepository(catalogExecutor(rowCounts: [
        ['GPS Time', 17223],
        ['Lap Dist', 1723],
        ['Engine Oil Temp', 1209],
        ['TyresPressure', 1723],
        ['Lap', 2],
        // 'Gear' listed in eventsList but no table for it
      ]));

      await expectLater(
        repo.readCatalog(),
        throwsA(isA<SchemaMismatchException>()
            .having((e) => e.detail, 'detail', contains('Gear'))),
      );
    });

    test('fails clearly when the master clock is missing', () async {
      final repo = SessionRepository(catalogExecutor(clock: [[null, 0]]));
      await expectLater(
        repo.readCatalog(),
        throwsA(isA<SchemaMismatchException>()
            .having((e) => e.detail, 'detail', contains('GPS Time'))),
      );
    });

    test('fails clearly when both catalogs are empty', () async {
      final repo = SessionRepository(catalogExecutor(channels: [], events: []));
      await expectLater(repo.readCatalog(), throwsA(isA<SchemaMismatchException>()));
    });
  });

  group('readClockGaps', () {
    test('maps a scan result into gaps with lost time', () async {
      final repo = SessionRepository(FakeExecutor({
        'lag(v)': [
          [32580, 0.3875],
        ],
      }));
      final gaps = await repo.readClockGaps();
      expect(gaps, hasLength(1));
      expect(gaps.single.masterRowIndex, 32580);
      expect(gaps.single.lostSeconds, closeTo(0.3775, 1e-9));
    });

    test('a clean recording reports no gaps', () async {
      final repo = SessionRepository(FakeExecutor({'lag(v)': []}));
      expect(await repo.readClockGaps(), isEmpty);
    });
  });

  group('LapRepository', () {
    test('maps the real Race lap table, including its odd rows', () async {
      // Verbatim from the Sebring Race sample.
      final repo = LapRepository(FakeExecutor({
        'lead(ts)': [
          [0, 23.5975, 195.82, 71.24098205566406, 29.218246459960938, 42.20904541015625],
          [1, 195.82, 260.32, 64.49739074707031, 23.346588134765625, 36.260711669921875],
          [2, 260.32, 324.88, 64.57025146484375, 23.408477783203125, 0.0],
          [3, 324.88, 388.92, 64.02963256835938, 22.9844970703125, 35.852996826171875],
          [4, 388.92, 452.96, 0.0, 22.929290771484375, 35.82183837890625],
          [5, 452.96, null, null, null, null],
        ],
      }));

      final laps = await repo.readLaps();
      expect(laps, hasLength(6));

      // Lap 0: timed by the game, but the garage lap — not comparable pace.
      expect(laps[0].isOutLap, isTrue);
      expect(laps[0].isTimed, isFalse);

      // Lap 1: a clean flying lap, with the corrected sector split.
      expect(laps[1].isTimed, isTrue);
      expect(laps[1].sectors.sector2Seconds, closeTo(12.914, 0.01));
      expect(laps[1].sectors.sector3Seconds, closeTo(28.237, 0.01));

      // Lap 2: valid lap time, but S2 was written as 0.0 — a partial row.
      expect(laps[2].lapTimeSeconds, isNotNull);
      expect(laps[2].sectors.sector1Seconds, isNotNull);
      expect(laps[2].sectors.sector2Seconds, isNull);

      // Lap 4: 0.0 lap time means invalidated, not a zero-second lap.
      expect(laps[4].lapTimeSeconds, isNull);
      expect(laps[4].isTimed, isFalse);

      // Lap 5: open-ended.
      expect(laps[5].isOpenEnded, isTrue);

      // Pace uses every comparable lap — including lap 2, whose lap time is
      // perfectly good even though its S2 split wasn't recorded. A partial
      // sector row must not disqualify a real lap time.
      expect(laps.timed.map((l) => l.index), [1, 2, 3]);
      expect(laps.bestLap!.index, 3);
    });

    test('a zero best lap time from the game reads as no best', () async {
      final repo = LapRepository(FakeExecutor({'Best LapTime': [[0.0]]}));
      expect(await repo.readGameReportedBest(), isNull);
    });

    test('maps sector transitions with code 0 as sector 3', () async {
      final repo = LapRepository(FakeExecutor({
        'Current Sector': [
          [195.82, 1],
          [219.16, 2],
          [232.08, 0],
        ],
      }));
      expect(await repo.readSectorTransitions(),
          [(195.82, 1), (219.16, 2), (232.08, 3)]);
    });
  });
}
