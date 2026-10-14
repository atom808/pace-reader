// Driving Technique on the recordings themselves (SPEC.md §8.13.9).
//
// `test/features/technique_domain_test.dart` proves the rules on constructed
// arrays. Here the queries run on the checked-in fixture, pinned at the
// values §8.13 measured, and — where the user's LMU Telemetry folder is
// present — on the recordings each of §8.13's findings came from. The folder
// is only ever attached read-only.
//
// Run with:
//   flutter test --no-pub integration_test/technique_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/technique_queries.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driving_technique/application/technique_providers.dart';
import 'package:pace_reader/features/driving_technique/domain/conditions_lens.dart';
import 'package:pace_reader/features/driving_technique/domain/countersteer.dart';
import 'package:pace_reader/features/driving_technique/domain/racing_laps.dart';
import 'package:pace_reader/features/driving_technique/domain/technique_thresholds.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

/// [_fixture] with `TC` re-recorded as a 100 Hz channel, as a newer build
/// records it (§5.1), by `tool/make_tc_channel_fixture.dart`.
const _tcChannelFixture =
    'test/fixtures/sebring_race_tc_channel_laps0_3.duckdb';

/// A recording from the newer build, `TC` a channel in it (§5.1). None is in
/// the user's library; pass one with
/// `--dart-define=LMU_TC_CHANNEL_RECORDING=<path>`. Only ever opened as the
/// app opens a file.
const _tcChannelRecording = String.fromEnvironment('LMU_TC_CHANNEL_RECORDING');

/// The user's LMU telemetry folder. Only ever attached read-only; nothing is
/// written, copied into or deleted there.
const _telemetryFolder = String.fromEnvironment(
  'LMU_TELEMETRY',
  defaultValue:
      r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate'
      r'\UserData\Telemetry',
);

/// The countersteer ground truth: the spin on lap 3 (§8.13.3).
const _spaQualify =
    'Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb';

/// A February race: `Steering Pos` stored as a fraction (§8.13.1).
const _february = 'Circuit de la Sarthe_R_2026-02-28T16_31_27Z.duckdb';

/// An LMP2 setup at 240° of lock, whose `Steering Pos` is 0.714976 of its
/// unfiltered twin (§8.13.1).
const _lmp2Lock240 =
    'Michelin Raceway Road Atlanta_P_2026-09-25T18_15_14Z.duckdb';

/// The Hypercar race whose first lap left the pits with `In Pits` and the
/// limiter switched on before it began (§8.13.2).
const _imolaHypercar =
    'Autodromo Enzo e Dino Ferrari_R_2026-08-21T01_09_11Z.duckdb';

/// The wet Daytona Hypercar race (§8.13.6).
const _daytonaWet =
    'Daytona International Speedway_R_2026-08-05T02_39_19Z.duckdb';

class _Open extends OpenSessions {
  _Open(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

/// [provider]'s value, held alive while it resolves.
Future<T> _read<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) async {
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

/// A container with [source] open, closed again after [body].
Future<void> _with(
  TelemetrySource source,
  Future<void> Function(ProviderContainer container) body,
) async {
  final container = ProviderContainer(
    overrides: [
      openSessionsProvider.overrideWith(() => _Open([source])),
    ],
  );
  try {
    await body(container);
  } finally {
    if (container.exists(telemetrySessionProvider(source))) {
      await container.read(telemetrySessionProvider(source).notifier).close();
    }
    container.dispose();
  }
}

/// [name] in the user's folder, or null (and the test skipped) when it is
/// absent or still being written.
TelemetrySource? _library(String name) {
  final path = p.join(_telemetryFolder, name);
  if (!File(path).existsSync() || File('$path.wal').existsSync()) {
    markTestSkipped('$name is absent or still being written.');
    return null;
  }
  return TelemetrySource.path(path);
}

/// A racing lap's 50 Hz samples, its TC and ABS samples, and their merged
/// episodes.
typedef _AidMeasures = ({
  int samples,
  int tc,
  int tcEpisodes,
  int abs,
  int absEpisodes,
});

/// The SQL's pulse merge done again in Dart, from the raw flag rows: an
/// interval runs from an on row to the next row, intervals closer than the
/// merge gap are one episode, and an episode belongs to the lap it starts in.
Map<int, int> _mergedEpisodes(List<(double, bool)> rows, List<LapSpan> laps) {
  final intervals = <(double, double)>[];
  for (var i = 0; i < rows.length; i++) {
    final (ts, on) = rows[i];
    if (!on) continue;
    intervals.add((ts, i + 1 < rows.length ? rows[i + 1].$1 : ts + 0.01));
  }
  final starts = <double>[];
  double? reach;
  for (final (a, b) in intervals) {
    if (reach == null || a - reach > TechniqueThresholds.pulseMerge) {
      starts.add(a);
    }
    reach = reach == null || b > reach ? b : reach;
  }
  return {
    for (final lap in laps)
      if (starts.where((s) => s >= lap.start && s < lap.end).length case final n
          when n > 0)
        lap.lap: n,
  };
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_technique_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows releases the files once the app exits.
    }
  });

  testWidgets('the fixture\'s laps 1–3 at the values §8.13 measured', (
    tester,
  ) async {
    final path = p.join(tmp.path, 'race.duckdb');
    File('$_projectRoot/$_fixture').copySync(path);
    final source = TelemetrySource.path(path);
    await _with(source, (container) async {
      final overview = await _read(
        container,
        techniqueOverviewProvider(source).future,
      );
      expect([for (final l in overview.session.racing) l.index], [1, 2, 3]);
      expect(overview.session.excluded[0], NotRacing.recordingStart);
      expect(overview.session.steeringScale, 1);
      expect(overview.session.hasAbs, isTrue);

      const expected = {
        1: (
          n: 3225,
          ov: 0.81,
          co: 5.09,
          ft: 63.72,
          br: 18.95,
          tr: 70.4,
          tc: 2.12,
          abs: 3.86,
          sh: 10,
        ),
        2: (
          n: 3228,
          ov: 1.39,
          co: 4.12,
          ft: 63.04,
          br: 17.22,
          tr: 68.5,
          tc: 2.66,
          abs: 4.32,
          sh: 10,
        ),
        3: (
          n: 3202,
          ov: 0.75,
          co: 5.03,
          ft: 65.90,
          br: 17.43,
          tr: 67.6,
          tc: 2.54,
          abs: 3.38,
          sh: 9,
        ),
      };
      for (final MapEntry(key: index, value: e) in expected.entries) {
        final t = overview.laps[index]!;
        final pedals = t.pedals;
        String pct(int count) => (100 * pedals.share(count)).toStringAsFixed(2);
        expect(pedals.samples, e.n, reason: 'lap $index samples');
        // The identity that says the frame is whole: 50 Hz × Lap Time.
        expect(
          (pedals.samples - 50 * t.lap.lapTimeSeconds!).abs(),
          lessThanOrEqualTo(1),
        );
        expect(pct(pedals.overlap), e.ov.toStringAsFixed(2));
        expect(pct(pedals.coast), e.co.toStringAsFixed(2));
        expect(pct(pedals.fullThrottle), e.ft.toStringAsFixed(2));
        expect(pct(pedals.braking), e.br.toStringAsFixed(2));
        expect(
          (100 * pedals.trailShare!).toStringAsFixed(1),
          e.tr.toStringAsFixed(1),
        );
        expect(
          pedals.seconds(pedals.tc).toStringAsFixed(2),
          e.tc.toStringAsFixed(2),
        );
        expect(
          pedals.seconds(pedals.abs).toStringAsFixed(2),
          e.abs.toStringAsFixed(2),
        );
        expect(t.upshifts, e.sh, reason: 'lap $index upshifts');
        expect(t.downshifts, e.sh, reason: 'lap $index downshifts');
      }

      // The SQL's pulse merge against the same merge in Dart.
      final repo = await _read(
        container,
        techniqueRepositoryProvider(source).future,
      );
      final spans = overview.session.spans;
      final tc = _mergedEpisodes(await repo.readFlag(techniqueTcEvent), spans);
      final abs = _mergedEpisodes(
        await repo.readFlag(techniqueAbsEvent),
        spans,
      );
      for (final lap in spans) {
        expect(overview.laps[lap.lap]!.tcEpisodes, tc[lap.lap] ?? 0);
        expect(overview.laps[lap.lap]!.absEpisodes, abs[lap.lap] ?? 0);
      }
      debugPrint('fixture episodes: TC $tc, ABS $abs');
      expect(tc.values.every((n) => n > 0), isTrue);
    });
  });

  testWidgets('TC as a channel measures as TC as an event (§5.1)', (
    tester,
  ) async {
    /// Each racing lap's aid measures, and whether `TC` came from a channel.
    Future<(bool, Map<int, _AidMeasures>)> measure(String fixture) async {
      final path = p.join(tmp.path, p.basename(fixture));
      File('$_projectRoot/$fixture').copySync(path);
      final source = TelemetrySource.path(path);
      late final bool fromChannel;
      final laps = <int, _AidMeasures>{};
      await _with(source, (container) async {
        final overview = await _read(
          container,
          techniqueOverviewProvider(source).future,
        );
        final repo = await _read(
          container,
          techniqueRepositoryProvider(source).future,
        );
        fromChannel = repo.channels!.tcChannel != null;
        for (final MapEntry(key: index, value: t) in overview.laps.entries) {
          laps[index] = (
            samples: t.pedals.samples,
            tc: t.pedals.tc,
            tcEpisodes: t.tcEpisodes,
            abs: t.pedals.abs,
            absEpisodes: t.absEpisodes,
          );
        }
      });
      return (fromChannel, laps);
    }

    final (eventRead, event) = await measure(_fixture);
    final (channelRead, channel) = await measure(_tcChannelFixture);
    debugPrint('TC as an event:   $event');
    debugPrint('TC as a channel:  $channel');
    expect(eventRead, isFalse);
    expect(channelRead, isTrue);
    // Not two zeros agreeing: the event reads TC on every lap (§8.13.9).
    expect(event.keys, [1, 2, 3]);
    expect(event.values.every((l) => l.tc > 0 && l.tcEpisodes > 0), isTrue);
    // The channel is the event sampled every 10 ms, and the pedal frame reads
    // either at those ticks, so TC time is the same to the sample. Pulses
    // shorter than a tick fall between rows (1,189 event rows, 911 changes
    // on the grid), but none of them alone is an episode here.
    expect(channel, event);
  });

  testWidgets('[New build] TC read from its channel on every racing lap', (
    tester,
  ) async {
    if (!File(_tcChannelRecording).existsSync() ||
        File('$_tcChannelRecording.wal').existsSync()) {
      markTestSkipped('$_tcChannelRecording is absent or still being written.');
      return;
    }
    final source = TelemetrySource.path(_tcChannelRecording);
    await _with(source, (container) async {
      final overview = await _read(
        container,
        techniqueOverviewProvider(source).future,
      );
      final repo = await _read(
        container,
        techniqueRepositoryProvider(source).future,
      );
      expect(repo.channels!.tcChannel, isNotNull);
      expect(overview.session.racing, isNotEmpty);
      for (final l in overview.session.racing) {
        final t = overview.laps[l.index]!;
        debugPrint(
          'lap ${l.index}: TC ${t.pedals.seconds(t.pedals.tc).toStringAsFixed(2)}'
          ' s, ${t.tcEpisodes} episodes',
        );
        expect(t.pedals.tc, greaterThan(0));
        expect(t.tcEpisodes, greaterThan(0));
      }
    });
  }, skip: _tcChannelRecording.isEmpty);

  testWidgets('[Lib] Spa qualifying\'s lap-3 spin is one 11-sample episode', (
    tester,
  ) async {
    final source = _library(_spaQualify);
    if (source == null) return;
    await _with(source, (container) async {
      final session = await _read(
        container,
        techniqueSessionProvider(source).future,
      );
      final repo = await _read(
        container,
        techniqueRepositoryProvider(source).future,
      );
      // Every closed lap, racing or not: the spin's lap has no `Lap Time`.
      final spans = [
        for (final l in session.laps)
          if (l.index > 0 && l.endSeconds != null)
            (lap: l.index, start: l.startSeconds, end: l.endSeconds!),
      ];
      final episodes = countersteerEpisodes(
        await repo.readCountersteerSamples(
          spans,
          steeringScale: session.steeringScale,
        ),
      );
      for (final e in episodes) {
        debugPrint(
          'Spa Q episode: lap ${e.lap}, ${e.samples} samples, peak '
          '${e.peakSteer.toStringAsFixed(1)} %, ${e.speed.toStringAsFixed(0)} '
          'km/h at ${e.station.toStringAsFixed(0)} m',
        );
      }
      expect(episodes, hasLength(1));
      final spin = episodes.single;
      // The file's own lap 3 (the app's Lap 4): the 122.7 s `Lap Time` row at its
      // start closes lap 2, so this lap has none.
      expect(spin.lap, 3);
      expect(spin.samples, 11);
      expect(spin.peakSteer.abs(), closeTo(81.5, 0.5));
      expect(session.racing.any((l) => l.index == spin.lap), isFalse);
    });
  }, skip: !Directory(_telemetryFolder).existsSync());

  testWidgets('[Lib] a February file\'s steering is scaled to percent', (
    tester,
  ) async {
    final source = _library(_february);
    if (source == null) return;
    await _with(source, (container) async {
      final overview = await _read(
        container,
        techniqueOverviewProvider(source).future,
      );
      final repo = await _read(
        container,
        techniqueRepositoryProvider(source).future,
      );
      expect(await repo.readSteeringMaxAbs(), lessThanOrEqualTo(1.0));
      expect(overview.session.steeringScale, 100);
      // Trail braking needs |steer| ≥ 5 %: read as a fraction it would be
      // zero on every lap.
      final trail = [
        for (final t in overview.laps.values) ?t.pedals.trailShare,
      ];
      debugPrint(
        'February trail braking: ${trail.map((s) => (100 * s).round())}',
      );
      expect(trail, isNotEmpty);
      expect(trail.every((s) => s > 0.2), isTrue);
    });
  }, skip: !Directory(_telemetryFolder).existsSync());

  testWidgets('[Lib] the LMP2 240° setup and its 0.714976 steering', (
    tester,
  ) async {
    final source = _library(_lmp2Lock240);
    if (source == null) return;
    await _with(source, (container) async {
      final session = await _read(
        container,
        techniqueSessionProvider(source).future,
      );
      expect(session.steerLock?.wheel, 240);
      expect(session.steerLock?.frontWheels, closeTo(9.3, 1e-9));
      expect(session.steeringScale, 1);
      final telemetry = await _read(
        container,
        telemetrySessionProvider(source).future,
      );
      final ratio = await telemetry.database.scalar(
        'SELECT max(abs(a.value)) / max(abs(b.value)) '
        'FROM "Steering Pos" a POSITIONAL JOIN "Steering Pos Unfiltered" b',
      );
      expect((ratio! as num).toDouble(), closeTo(0.714976, 1e-6));
    });
  }, skip: !Directory(_telemetryFolder).existsSync());

  testWidgets('[Lib] Imola\'s Hypercar pit-exit lap is not a racing lap', (
    tester,
  ) async {
    final source = _library(_imolaHypercar);
    if (source == null) return;
    await _with(source, (container) async {
      final session = await _read(
        container,
        techniqueSessionProvider(source).future,
      );
      // `In Pits` went on 60 s before lap 1 began and off 13.5 s into it.
      expect(session.excluded[1], isIn([NotRacing.pitLane, NotRacing.limiter]));
      expect(session.racing.any((l) => l.index == 1), isFalse);
      expect(session.racing.length, greaterThan(20));
    });
  }, skip: !Directory(_telemetryFolder).existsSync());

  testWidgets('[Lib] wet Daytona: the infield segments lose the most', (
    tester,
  ) async {
    final source = _library(_daytonaWet);
    if (source == null) return;
    await _with(source, (container) async {
      final lens = await _read(container, techniqueLensProvider(source).future);
      final course = await _read(
        container,
        techniqueCourseProvider(source).future,
      );
      final option = lens.options.firstWhere(
        (o) => o.condition == LensCondition.wetness,
      );
      final result = measureLens(option, lens.laps);
      final segments = course.segments;
      for (final (i, s) in result.segments.indexed) {
        final seg = segments[i];
        debugPrint(
          '${seg.name} ${seg.start.toStringAsFixed(0)}–'
          '${seg.end.toStringAsFixed(0)} m, ${course.cornersIn(seg).length} '
          'corners: ${s.time.change?.toStringAsFixed(2)} s '
          '(${((s.timeShare ?? 0) * 100).toStringAsFixed(1)} %), noise '
          '${s.time.withinNoise}',
        );
      }
      debugPrint('ranked by share: ${result.rankedByShare}');
      expect(result.lapTime.change, greaterThan(0));
      expect(result.lapTime.withinNoise, isFalse);
      // Segs 2–4 are the infield (62–2032 m); 5 and 6 the banking and the
      // back straight. The infield loses the largest share of its dry time,
      // the measured 12.5–26.9 % against 6.6–8.9 % (§8.13.6).
      expect(result.rankedByShare.take(3).toSet(), {1, 2, 3});
      for (final i in [1, 2, 3]) {
        expect(result.segments[i].timeShare, greaterThan(0.125));
      }
      for (final i in [4, 5]) {
        expect(result.segments[i].timeShare, inInclusiveRange(0.066, 0.089));
      }
    });
  }, skip: !Directory(_telemetryFolder).existsSync());
}
