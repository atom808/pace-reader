// End-to-end verification of the Phase 1 data layer against a real LMU
// telemetry file (SPEC.md §9.2, §12).
//
// An integration_test rather than a plain `flutter test` for the same reason
// as the Phase 0 spike: dart_duckdb's native library is linked into a real
// compiled app, not into the bare test-runner process. Run with:
//   flutter test integration_test/data_layer_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"
//
// The pure logic — SQL construction, sector derivation, lap classification,
// pace statistics — is covered in `test/data/` and needs no device. What can
// only be checked here is that the SQL those builders emit actually runs, and
// that the derivations agree with the real file's own ground truth.

import 'dart:io';
import 'dart:math' as math;

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_repository.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/data/repositories/session_repository.dart';
import 'package:pace_reader/data/repositories/telemetry_repository.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late TelemetrySession session;
  late LapRepository lapRepository;
  late TelemetryRepository telemetryRepository;

  setUpAll(() async {
    final path = '$_projectRoot/$_fixture';
    expect(File(path).existsSync(), isTrue,
        reason: 'Fixture missing at $path — see test/fixtures/README.md');
    session = await openTelemetrySession(TelemetrySource.path(path));
    lapRepository = LapRepository(session.database);
    telemetryRepository =
        TelemetryRepository(session.database, session.catalog);
  });

  tearDownAll(() async => session.dispose());

  group('opening', () {
    testWidgets('reads metadata through the ATTACH path', (tester) async {
      // Both platforms attach rather than open directly, so desktop and web
      // run identical SQL. This is the check that the attach actually works
      // end-to-end with dart_duckdb, not just in a bare DuckDB shell.
      expect(session.metadata.trackName, 'Sebring International Raceway');
      expect(session.metadata.trackLayout, 'Sebring School Circuit');
      expect(session.metadata.sessionType, SessionType.race);
      expect(session.metadata.carClass, 'GT3');
      expect(session.metadata.version, '1');
      expect(session.metadata.carSetupJson, contains('WM_PRESSURE'));
    });

    testWidgets('the attached database is genuinely read-only', (tester) async {
      // §3 makes writing back to a .duckdb file a non-goal. READ_ONLY makes
      // that unviolatable rather than merely intended.
      await expectLater(
        session.database.rows('CREATE TABLE should_not_exist (x INTEGER)'),
        throwsA(isA<TelemetryQueryException>()),
      );
    });

    testWidgets('a missing file fails at open, and is not created',
        (tester) async {
      // READ_ONLY attach refuses rather than creating an empty database —
      // which is also §3's "strictly read-only" holding at the file level.
      final missing = '${Directory.systemTemp.path}/pace_reader_missing.duckdb';
      expect(File(missing).existsSync(), isFalse);

      await expectLater(
        openTelemetrySession(TelemetrySource.path(missing)),
        throwsA(isA<SessionOpenException>()
            .having((e) => e.source, 'source', missing)),
      );
      expect(File(missing).existsSync(), isFalse,
          reason: 'a failed open must not leave a file behind');
    });

    testWidgets('a valid DuckDB file that is not telemetry is rejected',
        (tester) async {
      // Distinct from the case above, and deliberately so: "this is not a
      // telemetry file" and "this file could not be opened" need different
      // messages, and a UI that cannot tell them apart has to hedge on both.
      final path = '${Directory.systemTemp.path}/pace_reader_not_telemetry.duckdb';
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      // Built with a raw writable connection, since the app's own layer can
      // only ever open files read-only.
      final scratch = await duckdb.open(path);
      final connection = await duckdb.connect(scratch);
      await connection.execute('CREATE TABLE shopping_list (item VARCHAR)');
      await connection.dispose();
      await scratch.dispose();

      await expectLater(
        openTelemetrySession(TelemetrySource.path(path)),
        throwsA(isA<NotTelemetryFileException>().having(
          (e) => e.missingTables,
          'missingTables',
          containsAll(['metadata', 'channelsList', 'eventsList']),
        )),
      );
    });
  });

  group('catalog discovery', () {
    testWidgets('finds the confirmed 56 channels and 42 events', (tester) async {
      expect(session.catalog.channels, hasLength(56));
      expect(session.catalog.events, hasLength(42));
      expect(session.catalog.origin, closeTo(23.5975, 1e-9));
    });

    testWidgets('identifies exactly the two off-grid channels', (tester) async {
      // If a third ever appears in a future LMU version, its declared
      // frequency is unusable for timing and this must fail rather than
      // silently absorb it.
      expect(
        session.catalog.offGridChannels.map((c) => c.name).toSet(),
        {'Engine Oil Temp', 'Engine Water Temp'},
      );
    });

    testWidgets('reads per-corner arity from the tables', (tester) async {
      expect(session.catalog.channel('TyresPressure')!.isPerCorner, isTrue);
      expect(session.catalog.channel('RideHeights')!.isPerCorner, isTrue);
      // Names don't predict arity: FrontRideHeight is single-valued while
      // RideHeights is per-corner.
      expect(session.catalog.channel('FrontRideHeight')!.isPerCorner, isFalse);
      expect(session.catalog.channel('Engine RPM')!.isPerCorner, isFalse);
    });

    testWidgets('this Race-derived fixture has a clean clock', (tester) async {
      expect(session.clockGaps, isEmpty);
      expect(session.hasClockGaps, isFalse);
    });
  });

  group('laps', () {
    testWidgets('derives sector durations from cumulative splits', (tester) async {
      // Ground truth measured from `Current Sector` transition timestamps on
      // the full Race sample: lap 1 is S1 23.340, S2 12.920, S3 28.240.
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);

      expect(lap1.lapTimeSeconds, closeTo(64.497, 0.001));
      expect(lap1.sectors.sector1Seconds, closeTo(23.340, 0.02));
      expect(lap1.sectors.sector2Seconds, closeTo(12.920, 0.02));
      expect(lap1.sectors.sector3Seconds, closeTo(28.240, 0.02));

      // Every sector positive, and the three summing back to the lap time —
      // the property SPEC v0.6 §8.3's formula violated.
      final sum = lap1.sectors.all.fold<double>(0, (a, s) => a + s!);
      expect(sum, closeTo(lap1.lapTimeSeconds!, 0.001));
      expect(lap1.sectors.all, everyElement(greaterThan(0)));
    });

    testWidgets('classifies the garage, partial, and open laps', (tester) async {
      final laps = await lapRepository.readLaps();
      expect(laps.map((l) => l.index), [0, 1, 2, 3, 4]);

      // Lap 0: the game timed it, but the boundary span covers garage + grid.
      final garage = laps[0];
      expect(garage.isOutLap, isTrue);
      expect(garage.isTimed, isFalse);
      expect(garage.lapTimeSeconds, closeTo(71.241, 0.001));
      expect(garage.wallClockSeconds, closeTo(172.222, 0.001));

      // Lap 2: good lap time, but S2 was written as 0.0.
      expect(laps[2].lapTimeSeconds, closeTo(64.570, 0.001));
      expect(laps[2].sectors.sector1Seconds, isNotNull);
      expect(laps[2].sectors.sector2Seconds, isNull);
      expect(laps[2].isTimed, isTrue,
          reason: 'a missing sector split must not disqualify a real lap time');

      // Lap 4: opened but never closed by the recording.
      expect(laps[4].isOpenEnded, isTrue);
      expect(laps[4].isTimed, isFalse);
    });

    testWidgets('pace statistics use only comparable laps', (tester) async {
      final laps = await lapRepository.readLaps();
      expect(laps.timed.map((l) => l.index), [1, 2, 3]);
      expect(laps.bestLap!.index, 3);
      expect(laps.bestLap!.lapTimeSeconds, closeTo(64.030, 0.001));
      expect(laps.completedCount, 4);
      expect(laps.consistencyStdDevSeconds, isNotNull);
    });

    testWidgets('the computed best agrees with the game\'s own', (tester) async {
      final laps = await lapRepository.readLaps();
      final reported = await lapRepository.readGameReportedBest();
      expect(reported, isNotNull);
      expect(laps.bestLap!.lapTimeSeconds, closeTo(reported!, 0.001));
    });

    testWidgets('sector transitions cycle S1, S2, S3 within a lap', (tester) async {
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final within = (await lapRepository.readSectorTransitions())
          .where((t) => t.$1 >= lap1.startSeconds && t.$1 < lap1.endSeconds!)
          .map((t) => t.$2)
          .toList();
      // Code 0 really is sector 3; a raw reading would show 1, 2, 0.
      expect(within, [1, 2, 3]);
    });
  });

  group('time axis', () {
    testWidgets('mapped timestamps land on an exact 1/hz grid', (tester) async {
      // The correction to §5.2: the integer stride is exact, while
      // round(i * masterRows / rowCount) compresses the axis — by up to 0.5 s
      // on a 1 Hz channel. Checked here on the slowest channels, where the
      // difference between the two mappings is largest.
      for (final name in ['Track Temperature', 'Time Behind Next', 'Lap Dist']) {
        final channel = session.catalog.channel(name)!;
        final series = await telemetryRepository.readFullResolution(
          name,
          startSeconds: session.catalog.origin,
          endSeconds: session.catalog.origin + 100,
          maxSamples: 20000,
        );
        expect(series, isNotEmpty, reason: name);

        final times = series.single.times;
        final step = 1.0 / channel.frequencyHz;
        for (var i = 1; i < times.length; i++) {
          expect((times[i] - times[i - 1]) - step, closeTo(0, 1e-9),
              reason: '$name step $i is off the declared grid');
        }
      }
    });

    testWidgets('lap boundaries resolve to the start/finish line', (tester) async {
      // External ground truth: a `Lap` event *is* the start/finish crossing,
      // so a correctly aligned channel must put `Lap Dist` at ~0 (or ~lap
      // length) there. Catches an alignment error in metres, not in floating
      // point noise. Lap 0 excluded: it starts in the garage.
      final laps = await lapRepository.readLaps();
      final lapLength =
          (await session.database.scalar('SELECT MAX(value) FROM "Lap Dist"'))
              as double;

      for (final lap in laps.where((l) => l.index > 0)) {
        final series = await telemetryRepository.readFullResolution(
          'Lap Dist',
          startSeconds: lap.startSeconds - 0.5,
          endSeconds: lap.startSeconds + 0.5,
        );
        expect(series, isNotEmpty, reason: 'lap ${lap.index}');

        var closest = double.infinity;
        for (var i = 0; i < series.single.length; i++) {
          final d = series.single.lows[i];
          closest = math.min(closest, math.min(d.abs(), (lapLength - d).abs()));
        }
        expect(closest, lessThan(10.0),
            reason: 'lap ${lap.index} resolved ${closest.toStringAsFixed(1)} m '
                'off the start/finish line');
      }
    });

    testWidgets('an off-grid channel still gets sane timestamps', (tester) async {
      // Engine Oil Temp declares 7 Hz and samples at ~7.0171 Hz, so it takes
      // the ratio fallback. It should still stay inside the recording.
      final series = await telemetryRepository.readFullResolution(
        'Engine Oil Temp',
        startSeconds: session.catalog.origin,
        endSeconds: session.catalog.origin + 60,
      );
      expect(series, isNotEmpty);

      final times = series.single.times;
      for (var i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]),
            reason: 'timestamps must be strictly increasing');
      }
      expect(times.first, greaterThanOrEqualTo(session.catalog.origin));
      expect(times.last, lessThanOrEqualTo(session.catalog.origin + 61));
    });
  });

  group('decimation', () {
    testWidgets('reduces a lap to roughly the requested bucket count',
        (tester) async {
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final series = await telemetryRepository.readTrace(
        'Ground Speed',
        window: TraceWindow(
          startSeconds: lap1.startSeconds,
          endSeconds: lap1.endSeconds!,
          buckets: 600,
        ),
      );

      expect(series, hasLength(1));
      final trace = series.single;
      expect(trace.length, lessThanOrEqualTo(600));
      expect(trace.length, greaterThan(500));
      expect(trace.unit, 'km/h');

      for (var i = 1; i < trace.length; i++) {
        expect(trace.times[i], greaterThan(trace.times[i - 1]));
      }
      for (var i = 0; i < trace.length; i++) {
        expect(trace.lows[i], lessThanOrEqualTo(trace.highs[i]));
      }
    });

    testWidgets('the min/max envelope contains the full-resolution data',
        (tester) async {
      // The reason for min/max rather than sampling: the envelope must not
      // lose the peaks. Compared against the undecimated truth over the same
      // window on a slow-enough channel to read in full.
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);

      final full = await telemetryRepository.readFullResolution(
        'Lap Dist',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );
      final decimated = await telemetryRepository.readTrace(
        'Lap Dist',
        window: TraceWindow(
          startSeconds: lap1.startSeconds,
          endSeconds: lap1.endSeconds!,
          buckets: 50,
        ),
      );

      expect(decimated.single.minValue, closeTo(full.single.minValue, 1e-9));
      expect(decimated.single.maxValue, closeTo(full.single.maxValue, 1e-9));
    });

    testWidgets('a per-corner channel yields four parallel series',
        (tester) async {
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final series = await telemetryRepository.readTrace(
        'TyresPressure',
        window: TraceWindow(
          startSeconds: lap1.startSeconds,
          endSeconds: lap1.endSeconds!,
          buckets: 200,
        ),
      );

      expect(series, hasLength(4));
      expect(series.map((s) => s.valueColumn),
          ['value1', 'value2', 'value3', 'value4']);
      expect(series.every((s) => s.length == series.first.length), isTrue);
      // Front pair vs rear pair differ; left/right within an axle is still
      // unconfirmed (§15.4), so no corner labels are asserted here.
      expect(series[0].minValue, isNot(closeTo(series[2].minValue, 0.01)));
    });

    testWidgets('refuses a full-resolution read that should be decimated',
        (tester) async {
      // §9.5: no renderer is ever handed a full-resolution multi-hour trace.
      // A guard that throws beats one that quietly returns millions of points.
      await expectLater(
        telemetryRepository.readFullResolution(
          'Engine RPM',
          startSeconds: session.catalog.origin,
          endSeconds: session.catalog.origin + 300,
          maxSamples: 1000,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('a window outside the recording returns empty, not an error',
        (tester) async {
      final series = await telemetryRepository.readTrace(
        'Ground Speed',
        window: const TraceWindow(
          startSeconds: 99000,
          endSeconds: 99100,
          buckets: 100,
        ),
      );
      expect(series, isEmpty);
    });

    testWidgets('an unknown channel fails with a clear error', (tester) async {
      await expectLater(
        telemetryRepository.readTrace(
          'Warp Core Temp',
          window: const TraceWindow(
            startSeconds: 30,
            endSeconds: 60,
            buckets: 100,
          ),
        ),
        throwsA(isA<SchemaMismatchException>()),
      );
    });
  });

  group('degenerate channels', () {
    testWidgets('detects the all-zero energy channels in a GT3 file',
        (tester) async {
      // Every file carries all three energy tables, so presence proves
      // nothing about class (§5.4). This is a GT3 session, so SoC and Regen
      // Rate are all-zero and must not be plotted.
      expect(await telemetryRepository.isDegenerate('SoC'), isTrue);
      expect(await telemetryRepository.isDegenerate('Regen Rate'), isTrue);

      // Virtual Energy is populated and meaningful in GT3 too — it is not a
      // Hypercar-only signal.
      expect(await telemetryRepository.isDegenerate('Virtual Energy'), isFalse);
      expect(await telemetryRepository.isDegenerate('Ground Speed'), isFalse);
    });
  });

  group('event alignment', () {
    testWidgets('resolves gear as of each channel sample', (tester) async {
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final aligned = await telemetryRepository.readEventAsOfChannel(
        'Lap Dist',
        eventName: 'Gear',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );

      expect(aligned, isNotEmpty);
      // Every event table's first ts equals origin, so within a lap there is
      // no unresolvable sample — a null here would mean the join lost its
      // alignment, which is exactly what a bare (inner) ASOF JOIN hides.
      expect(aligned.where((row) => row.$3 == null), isEmpty);
      for (final row in aligned) {
        expect(row.$3 as int, inInclusiveRange(0, 8));
      }
    });
  });

  group('provider wiring', () {
    testWidgets('resolves a session and its laps through Riverpod',
        (tester) async {
      // Providers that compile but don't resolve are worse than none, so the
      // DI graph is exercised against the real file rather than assumed.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source =
          TelemetrySource.path('$_projectRoot/$_fixture');

      final metadata =
          await container.read(sessionMetadataProvider(source).future);
      expect(metadata.trackLayout, 'Sebring School Circuit');

      final laps = await container.read(lapsProvider(source).future);
      expect(laps.timed.map((l) => l.index), [1, 2, 3]);

      // The family key is the open file, so a second read must reuse the same
      // session rather than reopening the database.
      final first = await container.read(telemetrySessionProvider(source).future);
      final second = await container.read(telemetrySessionProvider(source).future);
      expect(identical(first, second), isTrue);
    });
  });
}
