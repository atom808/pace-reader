// The trace's driver-aid pulses on the recordings (driver-aids proposal
// §3, P1).
//
// `test/data/driver_aids_test.dart` proves the merge rule on constructed
// edges. Here each racing lap of both fixtures — `TC` as an event and, re-
// recorded, as a channel (SPEC.md §5.1) — is read through `lapAidsProvider`
// and checked against Driving Technique's per-lap figures: the same episodes,
// and the same time on to within the 50 Hz sampling Technique counts in.
//
// Run with:
//   flutter test --no-pub integration_test/driver_aids_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd -W)"

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_aids.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driving_technique/application/technique_providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';
const _tcChannelFixture =
    'test/fixtures/sebring_race_tc_channel_laps0_3.duckdb';

class _Open extends OpenSessions {
  _Open(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

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

/// One racing lap: Technique's figures beside the overlay's.
typedef _Lap = ({
  int tcEpisodes,
  double tcSeconds,
  int absEpisodes,
  double absSeconds,
  LapAids aids,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_aids_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows releases the files once the app exits.
    }
  });

  /// Every racing lap of [fixture], read both ways.
  Future<Map<int, _Lap>> measure(String fixture) async {
    final path = p.join(tmp.path, p.basename(fixture));
    File('$_projectRoot/$fixture').copySync(path);
    final source = TelemetrySource.path(path);
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final overview = await _read(
        container,
        techniqueOverviewProvider(source).future,
      );
      return {
        for (final MapEntry(key: index, value: t) in overview.laps.entries)
          index: (
            tcEpisodes: t.tcEpisodes,
            tcSeconds: t.pedals.seconds(t.pedals.tc),
            absEpisodes: t.absEpisodes,
            absSeconds: t.pedals.seconds(t.pedals.abs),
            aids: await _read(
              container,
              lapAidsProvider((source, index)).future,
            ),
          ),
      };
    } finally {
      if (container.exists(telemetrySessionProvider(source))) {
        await container.read(telemetrySessionProvider(source).notifier).close();
      }
      container.dispose();
    }
  }

  void expectAgrees(Map<int, _Lap> laps, {required bool hasAbs}) {
    // Not two empties agreeing: TC acts on every racing lap of the fixture.
    expect(laps.keys, [1, 2, 3]);
    for (final MapEntry(key: index, value: lap) in laps.entries) {
      final tc = lap.aids.tc!;
      expect(tc.episodeCount, lap.tcEpisodes, reason: 'lap $index TC');
      expect(tc.episodeCount, greaterThan(0));
      // Technique counts 50 Hz samples with TC on; the pulses are timed to
      // their edges. 130–150 pulses of 10–20 ms a lap against a 20 ms grid
      // differ by up to 10 % (measured: lap 3's TC 2.795 s against 2.540 s,
      // ABS 3.700 against 3.380), so the two agree in size, not to the
      // sample.
      expect(
        tc.activeSeconds,
        closeTo(lap.tcSeconds, 0.12 * lap.tcSeconds),
        reason: 'lap $index TC time',
      );
      final abs = lap.aids.abs;
      if (!hasAbs) continue;
      expect(abs!.episodeCount, lap.absEpisodes, reason: 'lap $index ABS');
      expect(
        abs.activeSeconds,
        closeTo(lap.absSeconds, 0.12 * lap.absSeconds),
        reason: 'lap $index ABS time',
      );
    }
  }

  testWidgets('TC and ABS episodes match Driving Technique (TC an event)', (
    tester,
  ) async {
    final laps = await measure(_fixture);
    for (final MapEntry(key: i, value: l) in laps.entries) {
      debugPrint(
        'lap $i: TC ${l.aids.tc!.episodeCount} ep / '
        '${l.aids.tc!.pulseCount} pulses / '
        '${l.aids.tc!.activeSeconds.toStringAsFixed(3)} s '
        '(Technique ${l.tcEpisodes} / ${l.tcSeconds.toStringAsFixed(3)} s); '
        'ABS ${l.aids.abs?.episodeCount} / '
        '${l.aids.abs?.activeSeconds.toStringAsFixed(3)} s '
        '(Technique ${l.absEpisodes} / ${l.absSeconds.toStringAsFixed(3)} s)',
      );
    }
    expectAgrees(laps, hasAbs: true);
  });

  testWidgets('TC read from its channel gives the same episodes (§5.1)', (
    tester,
  ) async {
    final event = await measure(_fixture);
    final channel = await measure(_tcChannelFixture);
    expectAgrees(channel, hasAbs: true);
    for (final index in event.keys) {
      final a = event[index]!.aids.tc!;
      final b = channel[index]!.aids.tc!;
      debugPrint(
        'lap $index: event ${a.pulseCount} pulses, channel ${b.pulseCount}',
      );
      // Pulses shorter than a 10 ms tick fall between the channel's rows, so
      // the pulse lists differ; the episodes they merge into do not.
      expect(b.episodeCount, a.episodeCount, reason: 'lap $index');
      expect(b.episodes.length, a.episodes.length, reason: 'lap $index');
    }
  });
}
