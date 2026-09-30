// Frame cost while scrubbing the trace view (SPEC.md §15.3).
//
// The layer split — trace and cursor in separate `RepaintBoundary`s, plots
// memoised across cursor moves (§9.5) — is verified by construction: the
// painters' identity checks only fail when the data or the viewport changes.
// Whether that lands inside a frame budget is a measurement, and this is it:
// the real app, a real recording, a mouse swept across the six-panel stack at
// pointer rate while the engine reports every frame's build and raster time.
//
// Numbers only mean something in profile mode, which needs `flutter drive`:
//
//   flutter drive -d macos --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/scrub_perf_test.dart \
//     --dart-define=PROJECT_ROOT="$(pwd)" \
//     --dart-define=SESSION="samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb"
//
// which writes build/scrub_perf.json. Under plain `flutter test` (as CI's
// integration loop runs it) it still sweeps and asserts the sweep rendered,
// in debug mode, where the timings are not worth reading.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show MouseRegion, Offset, Size, SystemMouseCursors;
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_database.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';
import 'package:pace_reader/widgets/charting/sync/chart_sync.dart';
import 'package:pace_reader/widgets/charting/trace_panel.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _session = String.fromEnvironment(
  'SESSION',
  defaultValue: 'test/fixtures/sebring_race_laps0_3.duckdb',
);

/// One sweep's worth of pointer moves, at roughly a 125 Hz mouse's rate —
/// faster than the display, so every frame has a new cursor to draw.
const _moves = 480;
const _moveInterval = Duration(milliseconds: 8);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scrubbing the trace stack', (tester) async {
    final path = _session.startsWith('/')
        ? _session
        : '$_projectRoot/$_session';
    expect(File(path).existsSync(), isTrue, reason: 'no recording at $path');

    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/sessions');
    // The library index in memory: a benchmark must not write the recording
    // it opens into the developer's own library.
    final index = DriftSessionIndexStore(
      LibraryDatabase(NativeDatabase.memory()),
    );
    addTearDown(index.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionIndexStoreProvider.overrideWithValue(index)],
        child: const PaceReaderApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionLibraryScreen)),
    );
    await container
        .read(sessionImportProvider.notifier)
        .open(TelemetrySource.path(path));
    await tester.pumpAndSettle();
    appRouter.go('/trace');
    await tester.pumpAndSettle();

    final panels = find.byType(TracePanel);
    expect(panels, findsWidgets);
    // The plot's own hover region — the one with the precise cursor — rather
    // than the panel: a panel also holds its title row, where a pointer sets
    // no cursor, and a sweep there would time six idle panels.
    final plot = find.descendant(
      of: panels.at(panels.evaluate().length ~/ 2),
      matching: find.byWidgetPredicate(
        (w) => w is MouseRegion && w.cursor == SystemMouseCursors.precise,
      ),
    );
    expect(plot, findsOneWidget);
    final area = tester.getRect(plot);
    final y = area.center.dy;

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset(area.left + 4, y));
    addTearDown(mouse.removePointer);

    // Real frames at the engine's pace rather than the test's: benchmark
    // mode lets the pointer run ahead of the display, as a mouse does.
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

    await binding.watchPerformance(() async {
      for (var pass = 0; pass < 2; pass++) {
        for (var i = 0; i <= _moves; i++) {
          final t = i / _moves;
          final x = pass.isEven
              ? area.left + 4 + t * (area.width - 8)
              : area.right - 4 - t * (area.width - 8);
          await mouse.moveTo(Offset(x, y));
          await Future<void>.delayed(_moveInterval);
        }
      }
    }, reportKey: 'scrub');

    // The sweep reached the stack: a cursor is set, which is what every
    // frame above was spent drawing.
    expect(container.read(chartSyncProvider).cursor, isNotNull);
  });
}
