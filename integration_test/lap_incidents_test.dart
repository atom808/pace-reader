// Runs the lap-incident reads (SPEC.md §8.3) against a real DuckDB file.
//
// Every widget and unit test of the incident annotations feeds the derivation
// a fixture, because `dart_duckdb`'s native library is linked into a compiled
// app and not into the bare test runner. What that leaves unchecked is the
// part between the file and the derivation: that `sessionIncidentsProvider`
// finds the three event tables in the catalog, reads `WheelsDetached` one
// `value1..value4` column at a time, and gets the BOOLEAN `LastImpactMagnitude`
// back as the `bool`s `StepSeries.fromRows` coerces. Run with:
//   flutter test integration_test/lap_incidents_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"
//
// The checked-in fixture is laps 0-3 of the Sebring Race, which holds the
// first of that session's two impacts (213.8 s, 18.0 s into lap 2 as a driver
// counts) and none of the second (508.1 s, on lap 6).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reads all three incident tables, and finds the real impact',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final source = TelemetrySource.path('$_projectRoot/$_fixture');

    final incidents = await container.read(
      sessionIncidentsProvider(source).future,
    );

    // All three tables are in the file and all three were read: nothing is
    // reported as missing, which is what a silently-skipped per-corner read
    // would look like.
    expect(incidents.unavailable, isEmpty);
    expect(incidents.hasNoEvents, isFalse);

    // The one impact in the fixture, on the lap a driver calls lap 2 (index
    // 1), at the timestamp the event table holds.
    expect(incidents.impactCount, 1);
    final lap = incidents.byLap[1]!;
    expect(lap.impactSeconds.single, closeTo(213.8, 1e-6));
    expect(lap.underYellow, isFalse);
    expect(lap.hasDetachedWheel, isFalse);

    // And nothing on any other lap: the carried-in BOOLEAN state at the start
    // of the recording is not an impact.
    expect(incidents.byLap.keys, [1]);
    expect(incidents.lapsUnderYellow, 0);
    expect(incidents.lapsWithDetachedWheel, 0);

    // Laps the provider cut the events into are the laps the table shows.
    final laps = await container.read(lapsProvider(source).future);
    expect(laps.first.startSeconds, lessThan(lap.impactSeconds.single));
    expect(
      incidents.of(laps[1]).impactSeconds,
      lap.impactSeconds,
      reason: 'lap 2 is index 1',
    );
  });
}
