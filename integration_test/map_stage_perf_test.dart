// Frame cost of the lap stage during playback (map stage proposal §3.2, §7).
//
// The worst case the stage has: a lap played back at ×1 by the real ▶, the
// camera following the car so the whole map moves every frame, the dock of
// panels over it, and the dock, play bar and HUD all on grouped glass. It is
// run with full effects and again under Performance mode, so the cost of
// blur is read against the same scene without it. (P0.2 measured a reduced
// spike of this scene; its numbers are in the proposal.)
//
// Numbers only mean something in profile mode:
//
//   flutter drive -d windows --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/map_stage_perf_test.dart \
//     --dart-define=SESSION="C:\path\to\Circuit de la Sarthe_R_....duckdb" \
//     --dart-define=WINDOW=2560x1080
//
// which writes build/stage_<level>_perf.json. WINDOW resizes the real window
// on Windows (physical pixels), so the scene is measured at the size it will
// be used at rather than the runner's 1280 × 720 default.

import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_database.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/lap_stage.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _session = String.fromEnvironment(
  'SESSION',
  defaultValue: 'test/fixtures/sebring_race_laps0_3.duckdb',
);
const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _window = String.fromEnvironment('WINDOW');

/// Seconds of playback measured per level.
const _seconds = 8;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lap stage playback', (tester) async {
    final path = File(_session).isAbsolute
        ? _session
        : '$_projectRoot/$_session';
    expect(File(path).existsSync(), isTrue, reason: 'no recording at $path');
    _resizeWindow(_window);

    final index = DriftSessionIndexStore(
      LibraryDatabase(NativeDatabase.memory()),
    );
    addTearDown(index.close);
    final container = ProviderContainer(
      overrides: [sessionIndexStoreProvider.overrideWithValue(index)],
    );
    addTearDown(container.dispose);

    final source = TelemetrySource.path(path);
    // Listened to, not read: these providers dispose themselves when nothing
    // listens, which would tear a load down halfway.
    final laps = container.listen(lapsProvider(source).future, (_, _) {});
    addTearDown(laps.close);
    final (lap, reference) = await tester.runAsync(() async {
      final timed = (await laps.read()).where((l) => l.isTimed).toList()
        ..sort((a, b) => a.lapTimeSeconds!.compareTo(b.lapTimeSeconds!));
      expect(timed.length, greaterThanOrEqualTo(2));
      return (timed[1], timed[0]);
    }) as (Lap, Lap);
    final chartSub = container.listen(
      lapChartProvider(source, lap.index, reference.index).future,
      (_, _) {},
    );
    addTearDown(chartSub.close);
    final chart = (await tester.runAsync(chartSub.read))!;
    expect(chart.trackPath, isNotNull);

    final level = ValueNotifier(EffectsLevel.full);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: ValueListenableBuilder(
            valueListenable: level,
            builder: (context, l, _) => EffectsQuality(
              level: l,
              child: SyncOwner(
                owner: LapRef(source, lap.index),
                child: Scaffold(
                  body: LapStage(source: source, chart: chart),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

    final playback = container.read(playbackProvider.notifier);
    for (final l in EffectsLevel.values) {
      level.value = l;
      container.read(chartSyncProvider.notifier).setPlayhead(null);
      await tester.pump();
      await binding.watchPerformance(() async {
        playback.play();
        await Future<void>.delayed(const Duration(seconds: _seconds));
        playback.pause();
      }, reportKey: 'stage_${l.name}');
    }
    expect(container.read(chartSyncProvider).playhead, isNotNull);
    // What was measured, so a run at the wrong size can't pass for the
    // right one.
    final view = tester.view;
    binding.reportData = {
      ...?binding.reportData,
      'stage_window': {
        'physical_width': view.physicalSize.width,
        'physical_height': view.physicalSize.height,
        'device_pixel_ratio': view.devicePixelRatio,
        'panels': chart.panels.length,
        'track_points': chart.trackPath!.length,
      },
    };
  });
}

// Windows only: resize the real window, in physical pixels, so the measured
// scene is the size it will be used at.
void _resizeWindow(String spec) {
  if (spec.isEmpty || !Platform.isWindows) return;
  final parts = spec.split('x').map(int.parse).toList();
  final user32 = DynamicLibrary.open('user32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final findWindow = user32
      .lookupFunction<
        IntPtr Function(Pointer<Uint16>, Pointer<Uint16>),
        int Function(Pointer<Uint16>, Pointer<Uint16>)
      >('FindWindowW');
  final setWindowPos = user32
      .lookupFunction<
        Int32 Function(IntPtr, IntPtr, Int32, Int32, Int32, Int32, Uint32),
        int Function(int, int, int, int, int, int, int)
      >('SetWindowPos');
  final globalAlloc = kernel32
      .lookupFunction<IntPtr Function(Uint32, IntPtr), int Function(int, int)>(
        'GlobalAlloc',
      );
  const className = 'FLUTTER_RUNNER_WIN32_WINDOW';
  final units = className.codeUnits;
  final buffer = Pointer<Uint16>.fromAddress(
    globalAlloc(0x40, (units.length + 1) * 2),
  );
  for (var i = 0; i < units.length; i++) {
    buffer[i] = units[i];
  }
  final hwnd = findWindow(buffer, nullptr);
  if (hwnd == 0) return;
  // SWP_NOZORDER | SWP_NOACTIVATE
  setWindowPos(hwnd, 0, 0, 0, parts[0], parts[1], 0x0004 | 0x0010);
}
