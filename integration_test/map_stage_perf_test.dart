// Frame cost of the map stage during playback (map stage proposal §3.2, §7,
// P0.2).
//
// The worst case the stage has: a lap played back at ×1, the camera
// following the car so the whole map moves every frame, the seven-panel dock
// over it, and the dock, play bar and a HUD chip all on glass. It is run once
// per glass variant, so the cost of blur is read against the same scene
// without it.
//
// Numbers only mean something in profile mode:
//
//   flutter drive -d windows --profile \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/map_stage_perf_test.dart \
//     --dart-define=SESSION="C:\path\to\Circuit de la Sarthe_R_....duckdb" \
//     --dart-define=WINDOW=2560x1080
//
// which writes build/stage_<variant>_perf.json. WINDOW resizes the real
// window on Windows (physical pixels), so the scene is measured at the size it
// will be used at rather than the runner's 1280 × 720 default.

import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:pace_reader/features/telemetry_trace/presentation/lap_view_panes.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _session = String.fromEnvironment(
  'SESSION',
  defaultValue: 'test/fixtures/sebring_race_laps0_3.duckdb',
);
const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _window = String.fromEnvironment('WINDOW');

/// Seconds of playback measured per variant.
const _seconds = 8;

enum _Glass {
  none('tint only', null, false),
  blur20('σ 20', 20, false),
  blur20Bounded('σ 20 bounded', 20, true),
  blur28('σ 28', 28, false);

  const _Glass(this.label, this.sigma, this.bounded);
  final String label;
  final double? sigma;
  final bool bounded;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('map stage playback', (tester) async {
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

    final glass = ValueNotifier(_Glass.none);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: SyncOwner(
            owner: LapRef(source, lap.index),
            child: ValueListenableBuilder(
              valueListenable: glass,
              builder: (context, g, _) => _SpikeStage(chart: chart, glass: g),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    binding.framePolicy =
        LiveTestWidgetsFlutterBindingFramePolicy.benchmarkLive;

    for (final g in _Glass.values) {
      glass.value = g;
      await tester.pump();
      await binding.watchPerformance(() async {
        await _play(container, chart, const Duration(seconds: _seconds));
      }, reportKey: 'stage_${g.name}');
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

/// Plays the lap at ×1 from its start for [length], one cursor per vsync.
Future<void> _play(
  ProviderContainer container,
  LapChart chart,
  Duration length,
) async {
  final sync = container.read(chartSyncProvider.notifier);
  final start = chart.telemetry.startSeconds;
  final clock = Stopwatch()..start();
  while (clock.elapsed < length) {
    final seconds = start + clock.elapsedMicroseconds / 1e6 + 20;
    final domain = switch (chart.axis) {
      TraceAxis.distance => chart.distanceAxis!.distanceAt(seconds),
      TraceAxis.time => seconds,
    };
    sync.setPlayhead(domain);
    await SchedulerBinding.instance.endOfFrame;
  }
}

/// The stage as P2 will build it, reduced to what costs frame time: a map
/// that repaints under a moving camera every frame, a car, and glass over it.
class _SpikeStage extends ConsumerWidget {
  const _SpikeStage({required this.chart, required this.glass});

  final LapChart chart;
  final _Glass glass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cursor = ref.watch(chartSyncProvider.select((s) => s.playhead));
    final path = chart.trackPath!;
    final car = cursor == null
        ? path.projection.points.first
        : path.positionAt(cursor) ?? path.projection.points.first;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final dockWidth = box.maxWidth * 0.45;
          // The car sits in the middle of the visible map, left of the dock.
          final focus = Offset(
            (box.maxWidth - dockWidth) / 2,
            box.maxHeight / 2,
          );
          return BackdropGroup(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _WorldPainter(
                      path: path,
                      centre: car,
                      focus: focus,
                      pixelsPerMetre: 2.2,
                      band: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
                      line: ChannelColors.resolve(context).speed,
                      ink: scheme.onSurface,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  width: 260,
                  height: 84,
                  child: _Glassy(glass: glass, child: const SizedBox.expand()),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  bottom: 96,
                  width: dockWidth,
                  child: _Glassy(
                    glass: glass,
                    child: LapPanelStack(chart: chart),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  height: 64,
                  child: _Glassy(glass: glass, child: const SizedBox.expand()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Glassy extends StatelessWidget {
  const _Glassy({required this.glass, required this.child});

  final _Glass glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(
          alpha: glass.sigma == null ? 0.85 : 0.55,
        ),
      ),
      child: child,
    );
    final sigma = glass.sigma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: sigma == null
          ? tint
          : LayoutBuilder(
              builder: (context, box) => BackdropFilter.grouped(
                filter: ui.ImageFilter.compose(
                  outer: const ui.ColorFilter.matrix(_vibrancy),
                  inner: ui.ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    bounds: glass.bounded ? Offset.zero & box.biggest : null,
                  ),
                ),
                child: tint,
              ),
            ),
    );
  }
}

/// Saturation ×1.15, brightness ×0.85.
const _vibrancy = <double>[
  0.9417, 0.0896, 0.0187, 0, 0, //
  0.0263, 1.0080, 0.0157, 0, 0, //
  0.0263, 0.0896, 0.9341, 0, 0, //
  0, 0, 0, 1, 0,
];

/// The map as seen through a camera at [centre] metres, drawn at [focus]
/// pixels: the band, the line coloured by its value, and the car. Points off
/// screen are culled, because at stage zoom most of the lap is.
class _WorldPainter extends CustomPainter {
  _WorldPainter({
    required this.path,
    required this.centre,
    required this.focus,
    required this.pixelsPerMetre,
    required this.band,
    required this.line,
    required this.ink,
  });

  final TrackPath path;
  final Offset centre;
  final Offset focus;
  final double pixelsPerMetre;
  final Color band;
  final Color line;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final points = path.projection.points;
    final view = (Offset.zero & size).inflate(40);
    Offset toScreen(Offset m) => (m - centre) * pixelsPerMetre + focus;

    final bandPath = Path();
    const buckets = 12;
    final lines = List.generate(buckets, (_) => Path());
    final range = path.valueRange;
    var drawing = false;
    for (var i = 0; i < points.length - 1; i++) {
      final a = toScreen(points[i]);
      final b = toScreen(points[i + 1]);
      if (!view.contains(a) && !view.contains(b)) {
        drawing = false;
        continue;
      }
      if (!drawing) bandPath.moveTo(a.dx, a.dy);
      bandPath.lineTo(b.dx, b.dy);
      drawing = true;
      final v = range.span <= 0
          ? 0.0
          : ((path.values[i] - range.min) / range.span).clamp(0.0, 1.0);
      final k = math.min(buckets - 1, (v * buckets).floor());
      lines[k]
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
    canvas.drawPath(
      bandPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12 * pixelsPerMetre
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = band,
    );
    for (var k = 0; k < buckets; k++) {
      canvas.drawPath(
        lines[k],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            line.withValues(alpha: 0.35),
            line,
            k / buckets,
          )!,
      );
    }
    final car = Rect.fromCenter(
      center: toScreen(centre),
      width: 2 * pixelsPerMetre * 2,
      height: 5 * pixelsPerMetre * 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(car, const Radius.circular(4)),
      Paint()..color = ink,
    );
  }

  @override
  bool shouldRepaint(_WorldPainter old) =>
      old.centre != centre || old.path != path || old.focus != focus;
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
