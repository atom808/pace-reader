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
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/channels.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_corner_telemetry.dart';
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

  group('the Tyres and Brakes dock tabs', () {
    // Map stage P3's acceptance check: the tabs' traces are the lap the
    // report summarises. The min/max envelope keeps every extreme, so the
    // lap's low and high match the report's; the mean of the buckets'
    // midpoints is close to its mean, not equal, since a bucket's midpoint
    // is not its average.
    testWidgets('trace the same lap the report summarises', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = TelemetrySource.path('$_projectRoot/$_fixture');
      final report = await container.read(
        tireBrakeReportProvider(source).future,
      );
      final sub = container.listen(
        lapCornerTelemetryProvider((source, 3)).future,
        (_, _) {},
      );
      addTearDown(sub.close);
      final lap = await sub.read();
      final lap3 = report.laps.firstWhere((l) => l.index == 3);

      expect(lap.flat, isEmpty);
      expect(lap.channels.keys.toSet(), cornerChannelNames.toSet());
      // Recorded once, never changed: the front share the setup writes.
      expect(lap.brakeBiasRear!.values.single, closeTo(0.4875, 1e-6));

      double low(TraceSeries s) => s.lows.reduce(math.min);
      double high(TraceSeries s) => s.highs.reduce(math.max);
      double mean(TraceSeries s) {
        var sum = 0.0;
        for (var i = 0; i < s.length; i++) {
          sum += (s.lows[i] + s.highs[i]) / 2;
        }
        return sum / s.length;
      }

      for (final corner in Corner.values) {
        final snapshot = report.snapshot(lap3)[corner]!;
        for (final (channel, stats, tolerance) in [
          (Channels.tyresPressure, report.pressure!.at(corner, 3)!, 0.5),
          (Channels.tyresCarcassTemp, report.carcass!.at(corner, 3)!, 0.5),
          (Channels.brakesTemp, report.brakes!.at(corner, 3)!, 5.0),
        ]) {
          final trace = lap[channel]![corner]!;
          final why = '$channel ${corner.short}';
          expect(low(trace), closeTo(stats.min, 1e-3), reason: why);
          expect(high(trace), closeTo(stats.max, 1e-3), reason: why);
          expect(mean(trace), closeTo(stats.mean, tolerance), reason: why);
        }
        // The tab's surface temperature is the report's tread figure: the
        // three zones' average.
        final zones = [
          for (final c in [
            Channels.tyresTempLeft,
            Channels.tyresTempCentre,
            Channels.tyresTempRight,
          ])
            mean(lap[c]![corner]!),
        ];
        expect(
          zones.reduce((a, b) => a + b) / 3,
          closeTo(snapshot.tread!.mean, 0.5),
          reason: 'surface ${corner.short}',
        );
      }
    });
  });
}
