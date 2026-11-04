// Renders Compare on the stage to PNG (map stage proposal §9, P5), over the
// two real 5 Hz Sebring fixture laps: Base lap 2 against Target lap 4, on the
// Time axis with the playhead 28 s in.
//
// The widget tests prove what each layer carries — the dotted Target, the
// numbered segments with the worst ringed, the cased stretch, the ghost —
// but not that the car sits in clear map beside the HUD, that the segment
// card reads at the foot of the map, or that the Why drawer pushes the dock
// rather than covering it. Those need a picture.
//
// Two frames: 1600 px, the side dock with the drawer open beside it; and
// 900 px, the sheet with the segment card as its first row.
//
// Regenerate with
//   flutter test --update-goldens test/goldens/compare_golden_test.dart
// and look at the PNGs. Like every golden here it matches only on the
// platform that made it (macOS), hence the tag — see render_screens_test.dart.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../features/compare_harness.dart';
import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import '../fixtures/setup_viewer_harness.dart';

final _outputDir = Directory('images');

final _base = CompareFile('/golden/base.duckdb');
final _target = CompareFile(
  '/golden/target.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

Future<void> _render(WidgetTester tester, String name, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/driver-comparison',
    routes: [
      GoRoute(
        path: '/driver-comparison',
        builder: (context, state) => const RepaintBoundary(
          key: ValueKey('shot'),
          child: DriverComparisonScreen(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  final files = [_base, _target];
  await tester.pumpWidget(
    ProviderScope(
      overrides: compareOverrides(files: files, open: files),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Router<Object>)),
  );
  container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
  final set = ComparisonSet(
    LapRef(_base.source, sebringLapIndex),
    LapRef(_target.source, sebringLap3Index),
  );
  container
      .read(comparisonWorkspaceProvider.notifier)
      .start(set.base, set.target);
  await tester.pumpAndSettle();
  final view = await tester.runAsync(
    () => container.read(comparisonChartProvider(set).future),
  );
  // Mid-Seg 3, the worst: both cars on the map, apart.
  container
      .read(chartSyncProvider.notifier)
      .setPlayhead(view!.chart!.comparison!.check.base.startSeconds + 28);
  await tester.pumpAndSettle();

  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('${_outputDir.path}/$name.png'),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('compare: the side dock with the Why drawer', (tester) async {
    await _render(tester, 'compare_stage', const Size(1600, 950));
  });

  testWidgets('compare: the sheet, the segment card its first row', (
    tester,
  ) async {
    await _render(tester, 'compare_stage_sheet', const Size(900, 950));
  });
}
