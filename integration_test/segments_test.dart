// Segments on the recordings themselves (comparison proposal §10, step 4).
//
// `test/features/segments_test.dart` proves the detector and the losses on
// the 5 Hz Dart laps. Here they run as the app runs them: Ground Speed read
// at 100 Hz, `Lap Dist` at 10 Hz, from the checked-in fixture attached
// read-only — and, where the user's LMU Telemetry folder is present, on the
// recordings probe 0c measured.
//
// Run with (one file per run):
//   flutter test --no-pub integration_test/segments_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_speed.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

/// The user's LMU telemetry folder. Only ever attached read-only; nothing is
/// written, copied into or deleted there.
const _telemetryFolder = String.fromEnvironment(
  'LMU_TELEMETRY',
  defaultValue:
      r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate'
      r'\UserData\Telemetry',
);

class _Open extends OpenSessions {
  _Open(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

/// [provider]'s value, held alive while it resolves: the providers are
/// auto-disposed and nothing on screen watches them here.
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_segments_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('fixture laps 2 and 4 at their recorded rate', (tester) async {
    final path = p.join(tmp.path, 'race.duckdb');
    File('$_projectRoot/$_fixture').copySync(path);
    final source = TelemetrySource.path(path);
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final set = ComparisonSet(LapRef(source, 1), LapRef(source, 3));
      final segments = (await _read(
        container,
        comparisonSegmentsProvider(set).future,
      ))!;
      final view = await _read(container, comparisonChartProvider(set).future);
      final table = segments.table!;
      final losses = segments.segments!;

      // The canonical lap is lap 4: lap 2 recorded contact (at 854 m).
      expect(table.canonical.lapIndex, 3);
      expect(
        table.boundaries,
        pairwiseCompare(
          [353, 705, 1158, 1408, 2403],
          (num expected, num actual) => (actual - expected).abs() <= 2,
          'within 2 m of',
        ),
      );
      expect(table.corners.where((c) => c.unstable), isEmpty);

      final loss = [for (final s in losses.stretches) s.loss!];
      expect(loss[1], closeTo(0.002, 0.003));
      expect(loss[2], closeTo(0.298, 0.003));
      expect(loss[3], closeTo(0.122, 0.003));
      expect(loss[4], closeTo(-0.039, 0.003));
      // Re-anchored ends, as segments_test.dart fixes them for 5 Hz.
      expect(loss[0], closeTo(0.1031, 0.0005));
      expect(loss[5], closeTo(-0.0189, 0.0005));
      expect(
        losses.total,
        closeTo(
          view.chart!.lap.lapTimeSeconds! -
              view.chart!.comparison!.reference.lapTimeSeconds!,
          1e-9,
        ),
      );

      // The pair's sector-2 residual: interior boundaries carry no anchor
      // error, so this is the trace against the game over S2 alone.
      final pair = view.chart!.comparison!.check.pair;
      expect(
        pair[TimingLine.sector2]! - pair[TimingLine.sector1]!,
        closeTo(-0.006, 0.002),
      );

      // The hairpin turns where Base stops gaining.
      final turn = losses.stretches[2].turn!;
      expect(turn.first, closeTo(-0.271, 0.02));
      expect(turn.station, closeTo(794, 10));
      // Seg 2 and Seg 6 are level, but each swings by more than 0.05 s
      // inside: the walk visits both (the widget test's 5 Hz walk agrees).
      expect(losses.stretches[1].levelButSwinging, isTrue);
      expect(losses.stretches[5].levelButSwinging, isTrue);
    } finally {
      await container.read(openSessionsProvider.notifier).close(source);
      container.dispose();
    }
  });

  testWidgets('[Lib] the corner-set agreement of probe 0c, at 15 km/h', (
    tester,
  ) async {
    for (final (layout, expected, files) in _probeLayouts) {
      final clean = <(String, double, SpeedProfile)>[];
      double? wrap;
      for (final file in files) {
        final path = p.join(_telemetryFolder, file);
        if (!File(path).existsSync() || File('$path.wal').existsSync()) {
          continue;
        }
        final source = TelemetrySource.path(path);
        final container = ProviderContainer();
        try {
          final laps = await _read(container, lapsProvider(source).future);
          final course = await _read(
            container,
            courseFactsProvider(source).future,
          );
          wrap ??= course.wrapLength;
          final incidents = await _read(
            container,
            sessionIncidentsProvider(source).future,
          );
          for (final lap in laps) {
            final end = lap.endSeconds;
            if (whyNotCleanBeforeReading(
                  lap: lap,
                  recordingStart: lap.index == laps.first.index,
                  impact: incidents.of(lap).hasImpact,
                  pitLane:
                      end != null &&
                      course.pitLaneDuring(lap.startSeconds, end),
                ) !=
                null) {
              continue;
            }
            final read = await _read(
              container,
              lapSpeedProvider(source, lap.index).future,
            );
            if (read.lapDistance == null || read.speed == null) continue;
            final axis = DistanceAxis.fromSeries(read.lapDistance!);
            final profile = SpeedProfile.of(speed: read.speed!, axis: axis);
            final reason = whyNotClean(
              lap: lap,
              recordingStart: false,
              impact: false,
              pitLane: false,
              axis: axis,
              speed: profile,
            );
            if (reason == null) {
              clean.add((file, lap.lapTimeSeconds!, profile));
            }
          }
        } finally {
          if (container.exists(telemetrySessionProvider(source))) {
            await container
                .read(telemetrySessionProvider(source).notifier)
                .close();
          }
          container.dispose();
        }
      }
      // Probe 0c's candidates: clean laps within 3% of their file's best.
      final best = <String, double>{};
      for (final (file, time, _) in clean) {
        best[file] = (best[file] ?? double.infinity) < time
            ? best[file]!
            : time;
      }
      final candidates = [
        for (final c in clean)
          if (c.$2 <= best[c.$1]! * 1.03) c,
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      final anchor = speedMinima(candidates.first.$3, minProminence: 15);
      var same = 0;
      for (final (_, _, profile) in candidates) {
        final corners = speedMinima(profile, minProminence: 15);
        if (corners.length == anchor.length &&
            matchMinima(anchor, corners, wrap!).every((m) => m != null)) {
          same++;
        }
      }
      expect(
        100 * same / candidates.length,
        closeTo(expected, 2),
        reason: '$layout: $same of ${candidates.length} candidate laps',
      );
    }
  }, skip: !Directory(_telemetryFolder).existsSync());
}

/// The recordings probe 0c measured per layout, and the share of candidate
/// laps whose 15 km/h corner set matched the fastest candidate's (§5).
const _probeLayouts = <(String, double, List<String>)>[
  (
    'Daytona',
    92.6,
    [
      'Daytona International Speedway_R_2026-08-30T15_00_24Z.duckdb',
      'Daytona International Speedway_R_2026-08-27T04_10_05Z.duckdb',
      'Daytona International Speedway_R_2026-08-05T19_09_21Z.duckdb',
      'Daytona International Speedway_R_2026-08-02T00_38_43Z.duckdb',
      'Daytona International Speedway_P_2026-08-02T00_01_33Z.duckdb',
      'Daytona International Speedway_R_2026-08-04T03_38_25Z.duckdb',
      'Daytona International Speedway_P_2026-08-04T02_45_31Z.duckdb',
      'Daytona International Speedway_R_2026-08-02T02_08_15Z.duckdb',
      'Daytona International Speedway_Q_2026-08-04T03_28_24Z.duckdb',
    ],
  ),
  (
    'Le Mans',
    24.8,
    [
      'Circuit de la Sarthe_R_2026-03-01T03_16_20Z.duckdb',
      'Circuit de la Sarthe_R_2026-02-28T16_31_27Z.duckdb',
      'Circuit de la Sarthe_R_2026-09-17T04_17_10Z.duckdb',
      'Circuit de la Sarthe_R_2026-09-17T02_17_42Z.duckdb',
      'Circuit de la Sarthe_R_2026-02-27T00_25_34Z.duckdb',
      'Circuit de la Sarthe_R_2026-09-17T22_17_00Z.duckdb',
      'Circuit de la Sarthe_P_2026-02-19T23_49_34Z.duckdb',
      'Circuit de la Sarthe_P_2026-06-27T22_57_25Z.duckdb',
      'Circuit de la Sarthe_P_2026-10-11T03_11_45Z.duckdb',
    ],
  ),
  (
    'Interlagos',
    85.5,
    [
      'Autódromo José Carlos Pace_R_2026-07-19T01_33_51Z.duckdb',
      'Autódromo José Carlos Pace_P_2026-07-09T03_41_27Z.duckdb',
      'Autódromo José Carlos Pace_R_2026-07-17T02_39_07Z.duckdb',
      'Autódromo José Carlos Pace_P_2026-07-07T00_17_36Z.duckdb',
      'Autódromo José Carlos Pace_R_2026-07-22T03_03_17Z.duckdb',
      'Autódromo José Carlos Pace_Q_2026-07-22T02_53_14Z.duckdb',
      'Autódromo José Carlos Pace_R_2026-04-24T00_40_39Z.duckdb',
      'Autódromo José Carlos Pace_P_2026-07-22T02_43_34Z.duckdb',
    ],
  ),
];
