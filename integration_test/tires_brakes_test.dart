// The tyres & brakes reads against the real fixture (SPEC.md §8.6).
//
// Its own file for README.md's reason — one integration file per run — and
// because what it pins is new SQL: the multi-column form of `lapStatsSql`,
// which has to agree with the single-column form it generalises before any
// per-corner chart is allowed to rest on it.
//
// Run with:
//   flutter test integration_test/tires_brakes_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/session_repository.dart';
import 'package:pace_reader/data/repositories/telemetry_repository.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TelemetrySession session;
  late TelemetryRepository telemetry;

  setUpAll(() async {
    final path = '$_projectRoot/$_fixture';
    expect(File(path).existsSync(), isTrue,
        reason: 'Fixture missing at $path — see test/fixtures/README.md');
    session = await openTelemetrySession(TelemetrySource.path(path));
    telemetry = TelemetryRepository(session.database, session.catalog);
  });

  tearDownAll(() async => session.dispose());

  group('readLapStatsByColumn', () {
    // One of each rate the view reads: 10, 100, 5, 10 and 50 Hz.
    for (final channel in [
      'TyresPressure',
      'TyresTempLeft',
      'TyresCarcassTemp',
      'Tyres Wear',
      'Brakes Temp',
    ]) {
      test('$channel: one scan equals four single-column reads, lap for lap',
          () async {
        final together = await telemetry.readLapStatsByColumn(channel);
        expect(together.keys, Corner.valueColumns);
        for (final column in Corner.valueColumns) {
          final alone =
              await telemetry.readLapStats(channel, valueColumn: column);
          final multi = together[column]!;
          expect(multi.map((s) => s.lapIndex), alone.map((s) => s.lapIndex));
          for (var i = 0; i < alone.length; i++) {
            final reason = '$channel $column lap ${alone[i].lapIndex}';
            expect(multi[i].first, alone[i].first, reason: reason);
            expect(multi[i].last, alone[i].last, reason: reason);
            expect(multi[i].min, alone[i].min, reason: reason);
            expect(multi[i].max, alone[i].max, reason: reason);
            expect(multi[i].mean, closeTo(alone[i].mean, 1e-9),
                reason: reason);
            expect(multi[i].samples, alone[i].samples, reason: reason);
          }
        }
      });
    }

    test('real values: carcass, pressure and wear on laps 0-3', () async {
      final carcass = await telemetry.readLapStatsByColumn('TyresCarcassTemp');
      // Lap 4 opens after the channels stop: absent, not zero.
      expect(carcass['value1']!.map((s) => s.lapIndex), [0, 1, 2, 3]);
      expect(carcass['value1']!.map((s) => s.samples), [862, 322, 323, 320]);
      // Clockwise Sebring loads the left side: FL runs 7 °C over FR by lap 3.
      expect(carcass['value1']![3].mean, closeTo(90.8487, 1e-4));
      expect(carcass['value2']![3].mean, closeTo(84.0258, 1e-4));

      final pressure = await telemetry.readLapStatsByColumn('TyresPressure');
      // Warm from the first sample — the race starts on pre-heated tyres,
      // 35 kPa over the setup's cold 136.
      expect(pressure['value1']![0].first, closeTo(171.7706, 1e-4));
      expect(pressure['value1']![1].mean, closeTo(173.6018, 1e-4));
      expect(pressure['value4']![3].max, closeTo(175.8517, 1e-4));

      final wear = await telemetry.readLapStatsByColumn('Tyres Wear');
      expect(wear['value1']![0].first, 100.0);
      expect(wear['value1']![1].first, closeTo(99.6328, 1e-4));
      expect(wear['value1']![2].first, closeTo(99.1675, 1e-4));
    });

    test('a subset of columns is read in the order asked for', () async {
      final rear = await telemetry.readLapStatsByColumn(
        'TyresPressure',
        valueColumns: const ['value4', 'value3'],
      );
      expect(rear.keys, ['value4', 'value3']);
      expect(rear['value4']![1].mean, closeTo(172.4032, 1e-4));
      expect(rear['value3']![1].mean, closeTo(173.5457, 1e-4));
    });

    test('an unknown column is a schema mismatch, not a SQL error', () async {
      await expectLater(
        telemetry.readLapStatsByColumn('TyresPressure',
            valueColumns: const ['value5']),
        throwsA(isA<SchemaMismatchException>()),
      );
    });
  });

  group('the report', () {
    testWidgets('reads the real file end to end', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = TelemetrySource.path('$_projectRoot/$_fixture');
      final report =
          await container.read(tireBrakeReportProvider(source).future);

      expect(report.hidden, isEmpty, reason: '${report.hidden}');
      expect(report.availableMetrics, TyreMetric.values);
      expect(report.pitVisits, isEmpty);
      // The last lap the fixture closes; lap 4 is open-ended.
      expect(report.defaultLap!.index, 3);

      final lap3 = report.laps.firstWhere((l) => l.index == 3);
      final fl = report.snapshot(lap3)[Corner.frontLeft]!;
      final fr = report.snapshot(lap3)[Corner.frontRight]!;
      // Inner is TyresTempRight on a left wheel and TyresTempLeft on a right
      // one — each hotter than its outer edge.
      expect(fl.tread!.inner.mean, closeTo(91.8556, 1e-4));
      expect(fl.tread!.outer.mean, closeTo(82.5670, 1e-4));
      expect(fr.tread!.inner.mean, closeTo(87.6934, 1e-4));
      expect(fr.tread!.outer.mean, closeTo(74.3068, 1e-4));
      expect(fl.coldPressure!.number, 136);
      expect(fl.brake!.max, closeTo(631.5695, 1e-4));
      // Wear per lap by the fuel view's differencing: lap 3's first reading
      // minus lap 4's — lap 4 has none here, so its own last.
      expect(fl.wear!.used, closeTo(98.6606 - 98.2782, 1e-4));
      expect(report.hottestOn(lap3), Corner.frontLeft);
      expect(report.mostWornOn(lap3), Corner.frontLeft);

      // The recorded settings: one row each, never changed.
      expect(report.brakeBiasRear!.initial, closeTo(0.4875, 1e-6));
      expect(report.brakeBiasRear!.isConstant, isTrue);
      expect(report.brakeMigration!.initial, 0);
      expect(report.compoundChanges, 0);
      expect(report.setup.brakeBalance!.text, '51.2:48.8');
      expect(report.setup.compound[Corner.rearRight]!.text, 'Medium');
      expect(report.setup.camber[Corner.frontLeft]!.number, -2.3);
      expect(report.setup.discThickness[Corner.rearLeft]!.number, 3.2);

      // The garage lap and the open final lap are kept, greyed.
      final pressure = report.series(TyreMetric.pressure, Corner.frontLeft);
      expect(pressure.map((p) => p.lap.index), [0, 1, 2, 3, 4]);
      expect(pressure.first.exclusion, UsageExclusion.outLap);
      expect(pressure.last.exclusion, UsageExclusion.noData);
      expect([for (final p in pressure) p.muted],
          [true, false, false, false, true]);
    });
  });
}
