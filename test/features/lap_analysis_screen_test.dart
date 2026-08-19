// Widget tests for the lap table (SPEC.md §12: "widget tests for individual
// screens with Riverpod provider overrides supplying fixture data, no real DB
// needed").
//
// These are worth having specifically because the lap table is where the
// §8.3.1 corrections become visible to a user: a regression there shows up as
// a plausible-looking number, not as a crash.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_analysis/presentation/lap_analysis_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

/// The real Sebring Race laps 0-4, as the repository would map them.
List<Lap> _realLaps() {
  Lap lap(int index, double start, double? end, double? time, double? s1,
          double? s2cum) =>
      Lap(
        index: index,
        startSeconds: start,
        endSeconds: end,
        lapTimeSeconds: time,
        sectors: SectorTimes.fromCumulative(
          sector1: s1,
          sector2Cumulative: s2cum,
          lapTimeSeconds: time,
        ),
      );

  return [
    lap(0, 23.5975, 195.82, 71.24098205566406, 29.218246459960938, 42.20904541015625),
    lap(1, 195.82, 260.32, 64.49739074707031, 23.346588134765625, 36.260711669921875),
    lap(2, 260.32, 324.88, 64.57025146484375, 23.408477783203125, null),
    lap(3, 324.88, 388.92, 64.02963256835938, 22.9844970703125, 35.852996826171875),
    lap(4, 388.92, null, null, null, null),
  ];
}

Future<void> _pumpLapScreen(WidgetTester tester, List<Lap> laps) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source).overrideWith((ref) async => laps),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const LapAnalysisScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

void main() {
  testWidgets('renders the corrected sector splits, not the cumulative values',
      (tester) async {
    await _pumpLapScreen(tester, _realLaps());

    // Lap 1's raw values are S1 23.347 and a *cumulative* 36.261. The table
    // must show S2 as a duration (12.914) and derive S3 (28.237) — the old
    // formula would have shown 4.890 for S3.
    expect(find.text('23.347'), findsWidgets);
    expect(find.text('12.914'), findsOneWidget);
    expect(find.text('28.237'), findsOneWidget);
    expect(find.text('36.261'), findsNothing,
        reason: 'the cumulative split must never be shown as a sector time');
    expect(find.text('4.890'), findsNothing,
        reason: 'this is what the pre-v0.7 formula produced for S3');
  });

  testWidgets('numbers laps from 1, never 0', (tester) async {
    await _pumpLapScreen(tester, _realLaps());
    // Five laps, indices 0..4, must display as 1..5.
    for (final n in ['1', '2', '3', '4', '5']) {
      expect(find.text(n), findsWidgets, reason: 'lap $n should be listed');
    }
  });

  testWidgets('marks the laps that are not comparable instead of hiding them',
      (tester) async {
    await _pumpLapScreen(tester, _realLaps());

    // All five rows are present, each odd one labelled with why.
    expect(find.text('out lap'), findsOneWidget);
    expect(find.text('partial sectors'), findsOneWidget);
    expect(find.text('incomplete'), findsOneWidget);
  });

  testWidgets('shows the best lap time and deltas against it', (tester) async {
    await _pumpLapScreen(tester, _realLaps());

    // Lap 3 (1:04.030) is the best; lap 1 is +0.468 on it.
    expect(find.text('1:04.030'), findsOneWidget);
    expect(find.text('+0.468'), findsOneWidget);
    expect(find.text('+0.541'), findsOneWidget);
  });

  testWidgets('renders missing times as a dash rather than zero',
      (tester) async {
    // An invalidated lap: the game wrote 0.0, which must never surface as a
    // 0.000 lap time or a fastest lap.
    final laps = [
      Lap(
        index: 1,
        startSeconds: 100,
        endSeconds: 164,
        lapTimeSeconds: null,
        sectors: SectorTimes.fromCumulative(
          sector1: 22.933,
          sector2Cumulative: 0.0,
          lapTimeSeconds: null,
        ),
      ),
    ];
    await _pumpLapScreen(tester, laps);

    expect(find.text('no time'), findsOneWidget);
    expect(find.text('0:00.000'), findsNothing);
    expect(find.text('0.000'), findsNothing);
  });

  testWidgets('a session with no laps says so', (tester) async {
    await _pumpLapScreen(tester, const []);
    expect(find.text('This session recorded no laps.'), findsOneWidget);
  });
}
