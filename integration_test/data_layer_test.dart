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
import 'dart:typed_data';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/core/errors.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_repository.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/data/repositories/session_repository.dart';
import 'package:pace_reader/data/repositories/telemetry_repository.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

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
      // unconfirmed (§15.5), so no corner labels are asserted here.
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

  group('event windows', () {
    testWidgets('reads the changes inside a lap', (tester) async {
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final gear = await telemetryRepository.readEventWindow(
        'Gear',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );

      expect(gear.isNotEmpty, isTrue);
      // Every shift the game recorded, plus the gear held at the line.
      expect(gear.length, greaterThan(20));
      for (var i = 1; i < gear.length; i++) {
        expect(gear.times[i], greaterThan(gear.times[i - 1]));
      }
      // `Gear` is a TINYINT running 0..5 in this GT3 file; 0 is neutral, which
      // the game writes momentarily during every shift.
      expect(gear.minValue, greaterThanOrEqualTo(0));
      expect(gear.maxValue, lessThanOrEqualTo(8));
    });

    testWidgets('reaches back for the value in force when the window opened',
        (tester) async {
      // The case the query exists for. Measured on this fixture, `Gear` has
      // rows at 222.215 and 228.1475 and none between, so a window inside that
      // span contains no change at all — and the car is very much in a gear
      // throughout it. Without the preceding row it would render as no gear.
      final gear = await telemetryRepository.readEventWindow(
        'Gear',
        startSeconds: 223,
        endSeconds: 228,
      );

      expect(gear.isNotEmpty, isTrue,
          reason: 'a window with no gear change still has a gear');
      expect(gear.length, 1);
      expect(gear.times.first, lessThan(223),
          reason: 'the one row is the change that predates the window');
      expect(gear.valueAt(223), isNotNull);
      expect(gear.valueAt(227.9), gear.valueAt(223),
          reason: 'the value is held across the whole window');
    });

    testWidgets('an event that never changed reads as a constant',
        (tester) async {
      // §5.1: over half the event tables hold exactly one row for a whole
      // session. `In Pits` is one of them in this Race-derived fixture.
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);
      final pits = await telemetryRepository.readEventWindow(
        'In Pits',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );
      expect(pits.length, 1);
      expect(pits.isConstant, isTrue);
      expect(pits.valueAt(lap1.endSeconds!), 0);
    });

    testWidgets('an unknown event fails with a clear error', (tester) async {
      await expectLater(
        telemetryRepository.readEventWindow(
          'Warp Core Breach',
          startSeconds: 200,
          endSeconds: 210,
        ),
        throwsA(isA<SchemaMismatchException>()),
      );
    });
  });

  group('track map projection', () {
    testWidgets('the projected lap agrees with the file\'s own Lap Dist',
        (tester) async {
      // External ground truth for §8.5's projection, the same way lap
      // boundaries are ground truth for the time axis: summing the projected
      // polyline over a lap must reproduce the distance the game itself
      // measured for that lap. Without the cosine-of-latitude factor this
      // lands ~69% long, so the check discriminates rather than merely
      // passing.
      final laps = await lapRepository.readLaps();
      final lap1 = laps.firstWhere((l) => l.index == 1);

      final latitude = await telemetryRepository.readFullResolution(
        'GPS Latitude',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );
      final longitude = await telemetryRepository.readFullResolution(
        'GPS Longitude',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );
      final lapDist = await telemetryRepository.readFullResolution(
        'Lap Dist',
        startSeconds: lap1.startSeconds,
        endSeconds: lap1.endSeconds!,
      );

      expect(latitude.single.length, longitude.single.length,
          reason: 'both are 10 Hz on the same master grid, so they pair by '
              'index with no join');

      final projection = TrackProjection.fromCoordinates(
        Float64List.fromList(latitude.single.lows),
        Float64List.fromList(longitude.single.lows),
      );
      final measured = lapDist.single.maxValue - lapDist.single.minValue;

      // Within 2%. The driven line is slightly shorter than the path
      // `Lap Dist` is measured along — `Path Lateral` spans ±11 m on this lap,
      // which is exactly the room a driver has to shorten a corner — and it is
      // not chording: re-summing at every second sample changes the total by
      // 0.04%.
      expect(projection.pathLengthMetres, closeTo(measured, measured * 0.02));

      // And the circuit closes on itself.
      final gap = (projection.points.last - projection.points.first).distance;
      expect(gap, lessThan(20));
    });
  });

  group('lap telemetry', () {
    testWidgets('assembles everything the synced views read, in one pass',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = TelemetrySource.path('$_projectRoot/$_fixture');

      final telemetry =
          await container.read(lapTelemetryProvider(source, 1).future);

      expect(telemetry.lap.index, 1);
      expect(telemetry.channels.keys, containsAll(traceChannelNames));
      expect(telemetry.hasPosition, isTrue);
      expect(telemetry.hasDistance, isTrue);
      expect(telemetry.gear, isNotNull);
      // S2 and S3 crossings; S1's crossing *is* the lap boundary.
      expect(telemetry.sectorBoundaries.map((s) => s.$2), [2, 3]);

      // The distance axis this lap yields is usable — laps 1-3 are driven
      // laps, unlike the garage lap.
      final axis = DistanceAxis.fromSeries(telemetry.lapDistance!);
      expect(axis.isUsable, isTrue);
    });

    testWidgets('the garage lap has no usable distance axis', (tester) async {
      // Measured: `Lap Dist` steps backwards once during lap 0, while the car
      // manoeuvres in the pits. §8.4's toggle has to disable rather than draw
      // a chart folded back over itself.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = TelemetrySource.path('$_projectRoot/$_fixture');

      final telemetry =
          await container.read(lapTelemetryProvider(source, 0).future);
      final axis = DistanceAxis.fromSeries(telemetry.lapDistance!);
      expect(axis.isMonotonic, isFalse);
    });

    testWidgets('a lap that opens after the recording stops resolves empty',
        (tester) async {
      // Lap 4's `Lap` event sits at 388.9200 s and `GPS Time`'s last sample at
      // 388.9175 s, so this lap opens 2.5 ms after the channels stop — which
      // is what a recording stopped on a start/finish crossing looks like. It
      // has to come back as an empty lap, not as a crash or an inverted axis.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final source = TelemetrySource.path('$_projectRoot/$_fixture');

      final telemetry =
          await container.read(lapTelemetryProvider(source, 4).future);
      expect(telemetry.lap.isOpenEnded, isTrue);
      expect(telemetry.hasTelemetry, isFalse);
      expect(telemetry.channels, isEmpty);
      expect(telemetry.hasPosition, isFalse);
      expect(telemetry.durationSeconds, greaterThan(0),
          reason: 'the window stays non-empty even when nothing is in it');
    });
  });

  group('event log', () {
    test('reads every event table, preserving the recorded types', () async {
      final log = await telemetryRepository.readEventLog();

      // Every one of the 42 tables has at least one row in every sample
      // (§5.1), so the log must reach all of them — a read that skipped a
      // table would still look plausible.
      expect(log.names.length, session.catalog.events.length);
      expect(log.truncated, isFalse);
      expect(log.events, isNotEmpty);

      // The types are the point: a UNION-based read would have had to cast
      // these to one common type, and the cast that unions BOOLEAN with FLOAT
      // is the one that turns `false` into 0.
      Object? firstValueOf(String name) =>
          log.events.firstWhere((e) => e.name == name).values.first;
      expect(firstValueOf('ABS'), isA<bool>());
      expect(firstValueOf('Gear'), isA<int>());
      expect(firstValueOf('Brake Bias Rear'), isA<double>());
    });

    test('is ordered by time across tables, not within them', () async {
      final log = await telemetryRepository.readEventLog();
      for (var i = 1; i < log.events.length; i++) {
        expect(log.events[i].timeSeconds,
            greaterThanOrEqualTo(log.events[i - 1].timeSeconds),
            reason: 'row $i is out of order');
      }
      // Interleaving is what makes it a log rather than 42 concatenated
      // tables: with 42 sources the first few rows must not all be one event.
      expect(log.events.take(60).map((e) => e.name).toSet().length,
          greaterThan(1));
    });

    test('keeps a per-corner event as one row of four values', () async {
      final log = await telemetryRepository.readEventLog(names: const [
        'SurfaceTypes',
      ]);
      expect(log.events, isNotEmpty);
      expect(log.events.first.isPerCorner, isTrue);
      expect(log.events.first.values, hasLength(4));
    });

    test('a window holds only what changed inside it', () async {
      final laps = await lapRepository.readLaps();
      final lap = laps[1];
      final log = await telemetryRepository.readEventLog(
        startSeconds: lap.startSeconds,
        endSeconds: lap.endSeconds!,
      );
      expect(log.events, isNotEmpty);
      for (final event in log.events) {
        // The contrast with readEventWindow: no reach-back row, so nothing is
        // stamped before the window the caller asked for.
        expect(event.timeSeconds, greaterThanOrEqualTo(lap.startSeconds));
        expect(event.timeSeconds, lessThan(lap.endSeconds!));
      }
    });

    test('names what it clipped instead of quietly returning a prefix',
        () async {
      final log = await telemetryRepository.readEventLog(maxRowsPerEvent: 1);
      expect(log.truncated, isTrue);
      // Every event with more than one row is named, and none with one row is.
      final multiRow = session.catalog.events
          .where((e) => !e.isConstant)
          .map((e) => e.name)
          .toSet();
      expect(log.clipped.toSet(), multiRow);
      for (final name in log.names) {
        expect(log.events.where((e) => e.name == name), hasLength(1));
      }
    });

    test('every change lands on a lap that contains it', () async {
      final laps = await lapRepository.readLaps();
      final log = await telemetryRepository.readEventLog();
      for (final event in log.events) {
        final lap = laps.lapAt(event.timeSeconds);
        if (lap == null) {
          // Only possible before the first lap event, which shares the
          // origin — so in practice nothing should land here.
          expect(event.timeSeconds, lessThan(laps.first.startSeconds));
          continue;
        }
        expect(event.timeSeconds, greaterThanOrEqualTo(lap.startSeconds));
        if (lap.endSeconds != null) {
          expect(event.timeSeconds, lessThan(lap.endSeconds!));
        }
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
