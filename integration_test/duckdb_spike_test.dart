// Phase 0 spike (SPEC.md §14): proves dart_duckdb can open a real LMU
// telemetry file, and validates the synthetic time-axis derivation from
// §5.2/§9.2 (channels carry no timestamp — elapsed time is `origin +
// row_index / frequency`) against real data before any chart depends on it.
//
// This is an integration_test, not a plain `flutter test`: dart_duckdb's
// native library is linked into the real compiled app via CocoaPods/CMake
// (see its macos/windows/linux podspec/CMakeLists), which a bare `flutter
// test` process doesn't have — only a real running app does. Run with:
//   flutter test integration_test/duckdb_spike_test.dart -d macos
//
// Fixture: test/fixtures/sebring_race_lap1.duckdb — lap 1 only, trimmed
// from the real Sebring Race sample (see test/fixtures/README.md).

import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The launched app's working directory isn't the project root, so the
/// project root is passed in explicitly rather than assumed. Run with:
///   flutter test integration_test/duckdb_spike_test.dart -d macos \
///     --dart-define=PROJECT_ROOT="$(pwd)"
const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late Connection conn;

  setUpAll(() async {
    final fixturePath = '$_projectRoot/test/fixtures/sebring_race_lap1.duckdb';
    expect(
      File(fixturePath).existsSync(),
      isTrue,
      reason: 'Fixture missing at $fixturePath — see test/fixtures/README.md '
          '(pass --dart-define=PROJECT_ROOT="\$(pwd)" if running from elsewhere)',
    );
    db = await duckdb.open(fixturePath);
    conn = await duckdb.connect(db);
  });

  tearDownAll(() async {
    await conn.dispose();
    await db.dispose();
  });

  testWidgets('metadata matches the real recording', (tester) async {
    final result = await conn.query('SELECT key, value FROM metadata');
    final rows = {for (final row in result.fetchAll()) row[0] as String: row[1]};

    expect(rows['TrackName'], 'Sebring International Raceway');
    expect(rows['SessionType'], 'Race');
    expect(rows['CarClass'], 'GT3');
  });

  testWidgets(
      'channelsList/eventsList catalogs are queryable (§9.2 catalog-driven discovery)',
      (tester) async {
    final channels = await conn.query('SELECT COUNT(*) FROM channelsList');
    final events = await conn.query('SELECT COUNT(*) FROM eventsList');

    expect(channels.fetchAll().single.single, 56);
    expect(events.fetchAll().single.single, 42);
  });

  testWidgets('a 100Hz channel table has no timestamp column', (tester) async {
    final result = await conn.query('SELECT * FROM "Engine RPM" LIMIT 1');
    expect(result.columnNames, ['value']);
  });

  testWidgets(
      'synthetic time-axis derivation matches GPS Time to sub-ms precision (§5.2, §15.3)',
      (tester) async {
    // GPS Time is itself a 100Hz channel whose *value* is the real elapsed
    // seconds — so row i's stored value is ground truth to check the
    // `origin + row_index / frequency` formula against.
    final freqRow = await conn.query(
      "SELECT frequency FROM channelsList WHERE channelName = 'GPS Time'",
    );
    final frequency = (freqRow.fetchAll().single.single as int).toDouble();
    expect(frequency, 100.0);

    final gpsTime = await conn.query('SELECT value FROM "GPS Time"');
    final values = gpsTime.fetchAll().map((r) => r.single as double).toList();
    final origin = values.first;

    for (final i in [0, 100, 1000, 5000, values.length - 1]) {
      final derived = origin + i / frequency;
      final actual = values[i];
      expect(
        (derived - actual).abs(),
        lessThan(0.001),
        reason: 'row $i: derived=$derived actual=$actual',
      );
    }
  });

  testWidgets('ASOF JOIN resolves an event value as of a channel sample (§5.2, §9.2)',
      (tester) async {
    // "What gear was the car in as of each Engine RPM sample?" — the
    // pattern every trace/track-map feature needs for event-to-channel
    // alignment, exercised here with DuckDB's native ASOF JOIN rather than
    // a hand-rolled backward scan.
    final result = await conn.query('''
      WITH engine_rpm_grid AS (
        SELECT
          value AS rpm,
          (row_number() OVER () - 1) / 100.0 AS t
        FROM "Engine RPM"
      )
      SELECT g.t, g.rpm, gear."value" AS gear
      FROM engine_rpm_grid g
      ASOF JOIN "Gear" gear ON gear.ts <= g.t
      ORDER BY g.t
      LIMIT 5
    ''');

    final rows = result.fetchAll();
    expect(rows, hasLength(5));
    for (final row in rows) {
      final gear = row[2] as int;
      expect(gear, inInclusiveRange(0, 8));
    }
  });
}
