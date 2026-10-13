// Compare's map on the recordings themselves (comparison proposal §6, §10
// step 6).
//
// `test/features/compare_map_test.dart` proves the shared frame, the ghost
// and the readout on the 5 Hz Dart laps. Here they run on the checked-in
// fixtures at their own 10 Hz, attached read-only: the fixture's lap 2
// against its lap 4 (one file), and against the second Sebring School
// recording's lap 3 (two files).
//
// Run with (one file per run):
//   flutter test --no-pub integration_test/map_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/color_tokens.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';
const _second = 'test/fixtures/sebring_race_b_laps0_2.duckdb';

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

double _median(List<double> values) =>
    (Float64List.fromList(values)..sort())[values.length ~/ 2];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('one frame, the ghost and the gap on native laps', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('pace_map_');
    final fixture = p.join(tmp.path, 'race.duckdb');
    final second = p.join(tmp.path, 'race_b.duckdb');
    File('$_projectRoot/$_fixture').copySync(fixture);
    File('$_projectRoot/$_second').copySync(second);
    final sources = [
      TelemetrySource.path(fixture),
      TelemetrySource.path(second),
    ];
    final container = ProviderContainer(
      overrides: [openSessionsProvider.overrideWith(() => _Open(sources))],
    );
    container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
    try {
      for (final (name, target) in [
        ('one file', LapRef(sources[0], 3)),
        ('two files', LapRef(sources[1], 2)),
      ]) {
        final set = ComparisonSet(LapRef(sources[0], 1), target);
        final view = await _read(
          container,
          comparisonChartProvider(set).future,
        );
        final map = view.map!;
        final comparison = view.chart!.comparison!;
        expect(map.target, isNotNull, reason: name);
        expect(map.ghostWithheld, isNull, reason: name);

        // Both laps about Base's centroid, against the Target about its own.
        final telemetry = await _read(
          container,
          lapTelemetryProvider(target.source, target.lapIndex).future,
        );
        final own = TrackPath.build(
          latitude: telemetry.latitude!,
          longitude: telemetry.longitude!,
          axis: TraceAxis.time,
          distanceAxis: comparison.referenceAxis,
        );
        final shared = <double>[];
        final separate = <double>[];
        for (var i = 0; i < map.base.length; i++) {
          final station = map.base.stations![i];
          final a = map.target!.positionAtStation(station);
          final b = own.positionAtStation(station);
          final at = map.base.projection.points[i];
          if (a != null) shared.add((a - at).distance);
          if (b != null) separate.add((b - at).distance);
        }
        expect(_median(shared), lessThan(1), reason: name);

        final start = comparison.check.base.startSeconds;
        final delta = view.chart!.panels.firstWhere(
          (p) => p.role == ChannelRole.delta,
        );
        final baseAxis = view.chart!.distanceAxis!;
        final targetAxis = comparison.referenceAxis!;
        for (final tau in [5.0, 20.0, 30.0, 45.0]) {
          final t = start + tau;
          final readout = map.readoutAt(t);
          expect(
            readout.gap,
            closeTo(
              targetAxis.distanceAt(t - comparison.timeShift) -
                  baseAxis.distanceAt(t),
              1e-9,
            ),
          );
          expect(
            delta.series.valueAt(t),
            closeTo(readout.delta!, 1e-9),
            reason: '$name τ $tau',
          );
          expect(map.ghostAt(t), map.target!.positionAt(t));
        }
        debugPrint(
          '$name: separation at equal Lap Dist ${_median(shared).toStringAsFixed(3)} m '
          'shared, ${_median(separate).toStringAsFixed(3)} m own origin; '
          '${[
            for (final tau in [5.0, 20.0, 30.0]) map.readoutAt(start + tau).text,
          ].join(' | ')}',
        );
      }
    } finally {
      for (final source in sources) {
        if (container.exists(telemetrySessionProvider(source))) {
          await container
              .read(telemetrySessionProvider(source).notifier)
              .close();
        }
      }
      container.dispose();
      try {
        tmp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows releases the files once the app exits.
      }
    }
  });
}
