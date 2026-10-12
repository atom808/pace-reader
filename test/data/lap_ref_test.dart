// `LapRef` and `RecordingIdentity` (comparison proposal §4, §9).
//
// Compare's Base and Target can sit in two files, so a lap is named by its
// file and its index together, and a recording by what the game wrote in it
// rather than by where the file is.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:path/path.dart' as p;

import '../fixtures/session_library_samples.dart';

void main() {
  group('LapRef', () {
    const race = TelemetrySource.path('/telemetry/race.duckdb');
    const spa = TelemetrySource.path('/telemetry/spa.duckdb');

    test('the same file and lap are the same lap', () {
      expect(const LapRef(race, 3), const LapRef(race, 3));
      expect(const LapRef(race, 3).hashCode, const LapRef(race, 3).hashCode);
    });

    test('a different lap or a different file is a different lap', () {
      expect(const LapRef(race, 3), isNot(const LapRef(race, 1)));
      expect(const LapRef(race, 3), isNot(const LapRef(spa, 3)));
    });

    test('follows the source: two spellings of one Windows path are one lap',
        () {
      final previous = FileTelemetrySource.pathContext;
      addTearDown(() => FileTelemetrySource.pathContext = previous);
      FileTelemetrySource.pathContext = p.Context(style: p.Style.windows);
      expect(
        const LapRef(TelemetrySource.path('C:/T/Race.duckdb'), 3),
        const LapRef(TelemetrySource.path(r'c:\t\race.duckdb'), 3),
      );
    });
  });

  group('RecordingIdentity', () {
    test('the trimmed fixture is the same recording as the full race', () {
      // laps 0–3 of the Race recording, checked in under another name.
      expect(
        sebringFixture.metadata.recordingIdentity,
        sebringRace.metadata.recordingIdentity,
      );
    });

    test('a row and its file agree on the recording', () {
      final entry = sebringRace.entry(indexedAt: DateTime.utc(2026, 9, 1));
      expect(entry.recordingIdentity, sebringRace.metadata.recordingIdentity);
    });

    test('different recordings differ', () {
      expect(
        sebringRace.metadata.recordingIdentity,
        isNot(spaQualify.metadata.recordingIdentity),
      );
      const a = RecordingIdentity(
        recordingTime: '2026-07-07T06_42_17Z',
        driverName: 'A',
        carName: 'Car',
      );
      const b = RecordingIdentity(
        recordingTime: '2026-07-07T06_42_17Z',
        driverName: 'B',
        carName: 'Car',
      );
      // Two drivers starting a recording in the same second are two
      // recordings.
      expect(a, isNot(b));
    });
  });
}
