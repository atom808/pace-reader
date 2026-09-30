// The three real sample sessions as the app names them (SPEC.md §5.1, §8.1).
//
// Read from each file's `metadata` table in `samples/` (git-ignored): the
// track, layout, session type, car and class strings are exactly what those
// recordings say, which is the point — the shell's short names are derived from
// them, and a derivation checked only against names the test author made up
// proves the author's guesses. Only what the shell reads is carried; `steamId`
// is `0` in all three files, `carSetupJson` is not needed here.
library;

import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';

const interlagosSource = TelemetrySource.path('/samples/interlagos_p.duckdb');
const spaSource = TelemetrySource.path('/samples/spa_q.duckdb');
const sebringSource = TelemetrySource.path('/samples/sebring_r.duckdb');

/// Interlagos, GT3 Practice. `TrackLayout` repeats `TrackName` to the
/// character.
const interlagosMetadata = SessionMetadata(
  driverName: 'Diego Pestana',
  steamId: '0',
  recordingTime: '2026-07-22T02_43_34Z',
  sessionTimeOfDay: '11:06:20',
  sessionType: SessionType.practice,
  trackName: 'Autódromo José Carlos Pace',
  trackLayout: 'Autódromo José Carlos Pace',
  weatherConditions: 'Mostly Cloudy',
  carName: 'Proton Competition 2025 #77:LM',
  carClass: 'GT3',
  carSetupJson: '{}',
  version: '1',
);

/// Spa-Francorchamps, Hypercar Qualify. `TrackLayout` is the track name with
/// "Endurance" appended.
const spaMetadata = SessionMetadata(
  driverName: 'Diego Pestana',
  steamId: '0',
  recordingTime: '2026-07-24T02_06_11Z',
  sessionTimeOfDay: '14:45:34',
  sessionType: SessionType.qualify,
  trackName: 'Circuit de Spa-Francorchamps',
  trackLayout: 'Circuit de Spa-Francorchamps Endurance',
  weatherConditions: 'Partially Cloudy',
  carName: 'AF Corse 2026 #83:WEC',
  carClass: 'Hyper',
  carSetupJson: '{}',
  version: '1',
);

/// Sebring, GT3 Race, on the 3.08 km School Circuit. The layout does *not*
/// start with the track name, which is why it has to be handled separately
/// from Spa's.
const sebringMetadata = SessionMetadata(
  driverName: 'Diego Pestana',
  steamId: '0',
  recordingTime: '2026-07-07T06_42_17Z',
  sessionTimeOfDay: '13:00:21',
  sessionType: SessionType.race,
  trackName: 'Sebring International Raceway',
  trackLayout: 'Sebring School Circuit',
  weatherConditions: 'Light Clouds',
  carName: 'The Bend Team WRT 2025 #31:BRZ',
  carClass: 'GT3',
  carSetupJson: '{}',
  version: '1',
);
