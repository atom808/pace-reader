// The friction circle's lap change (SPEC.md §8.13.8 "Verified"): stepping a
// lap runs the 450 ms morph to completion and lands on the new lap's points
// and numbers; under reduced motion it lands at once.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/driving_technique/application/technique_providers.dart';
import 'package:pace_reader/features/driving_technique/data/technique_reads.dart';
import 'package:pace_reader/features/driving_technique/domain/lap_technique.dart';
import 'package:pace_reader/features/driving_technique/presentation/gg_panel.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

final _source = TelemetrySource.path('technique_gg_panel_test.duckdb');

const _metadata = SessionMetadata(
  driverName: 'D',
  steamId: '1',
  recordingTime: '2026-07-07T06_42_17Z',
  sessionTimeOfDay: '13:00:21',
  sessionType: SessionType.race,
  trackName: 'Sebring International Raceway',
  trackLayout: 'Sebring School Circuit',
  weatherConditions: 'Clear',
  carName: 'The Bend Team WRT 2025 #31:BRZ',
  carClass: 'GT3',
  carSetupJson: '{}',
  version: '1',
);

Lap _lap(int index) => Lap(
  index: index,
  startSeconds: 60.0 * index,
  endSeconds: 60.0 * index + 60,
  lapTimeSeconds: 60,
  sectors: const SectorTimes(),
);

LapTechnique _technique(int index, double peak) => LapTechnique(
  lap: _lap(index),
  pedals: const PedalTotals(samples: 3000, hz: 50),
  gg: GgLap(samples: 600, sustainedPeak: peak),
);

/// Ten points a lap at the same stations, every one at ([lateral],
/// [braking]).
List<GgPoint> _points(double lateral, double braking) => [
  for (var i = 0; i < 10; i++)
    GgPoint(
      station: 10.0 * i,
      lateral: lateral,
      longitudinal: braking,
      throttle: 50,
      brake: 0,
    ),
];

void main() {
  final a = _technique(1, 2.0);
  final b = _technique(2, 2.4);
  final overview = TechniqueOverview(
    session: TechniqueSession(
      metadata: _metadata,
      laps: [a.lap, b.lap],
      racing: [a.lap, b.lap],
      excluded: const {},
      steeringScale: 1,
      hasPedals: true,
    ),
    laps: {1: a, 2: b},
    upshifts: const [],
    countersteer: const [],
    gg: GgReads(
      laps: const {},
      envelope: {
        SpeedBand.all: {for (var k = 0; k < 36; k++) k: (g: 2.0, n: 100)},
      },
      density: const {(0, 0): 10, (4, -2): 3},
      limits: const {},
      e: 2.2,
    ),
  );

  Future<ValueNotifier<LapTechnique>> pumpPanel(
    WidgetTester tester, {
    bool reduced = false,
  }) async {
    final shown = ValueNotifier(a);
    addTearDown(shown.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          techniqueCourseProvider(_source)
              .overrideWith((ref) async => const TechniqueCourse()),
          techniqueLapPointsProvider(
            _source,
            1,
          ).overrideWith((ref) async => _points(1.0, 0.5)),
          techniqueLapPointsProvider(
            _source,
            2,
          ).overrideWith((ref) async => _points(-1.0, -0.3)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: ValueListenableBuilder(
                    valueListenable: shown,
                    builder: (context, lap, _) =>
                        GgPanel(source: _source, overview: overview, lap: lap),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return shown;
  }

  List<Offset> cloud(WidgetTester tester) {
    for (final paint in tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    )) {
      final points = ggPointsNow(paint.painter);
      if (points != null) return points;
    }
    fail('no G-G points painter');
  }

  void expectAllAt(List<Offset> points, Offset at) {
    expect(points, hasLength(10));
    for (final p in points) {
      expect(p.dx, closeTo(at.dx, 1e-6));
      expect(p.dy, closeTo(at.dy, 1e-6));
    }
  }

  testWidgets('stepping a lap morphs the cloud and lands on the new lap', (
    tester,
  ) async {
    final shown = await pumpPanel(tester);
    // Right is −lateral (lateral is + left), up is braking.
    expectAllAt(cloud(tester), const Offset(-1.0, 0.5));
    expect(find.text('2.00 G'), findsOneWidget);

    shown.value = b;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // In flight: every point is on its way, from where lap 1 was at the same
    // Lap Dist, not yet where lap 2 was.
    for (final p in cloud(tester)) {
      expect(p.dx, greaterThan(-1.0));
      expect(p.dx, lessThan(1.0));
    }
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 320));
    await tester.pumpAndSettle();
    expectAllAt(cloud(tester), const Offset(1.0, -0.3));
    expect(find.text('2.40 G'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('under reduced motion the lap lands at once', (tester) async {
    final shown = await pumpPanel(tester, reduced: true);
    shown.value = b;
    await tester.pump();
    await tester.pump();
    expectAllAt(cloud(tester), const Offset(1.0, -0.3));
    expect(find.text('2.40 G'), findsOneWidget);
  });
}
