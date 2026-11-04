// The map stage's contract with the shared sync (map stage proposal §4, §5):
// hover probes and moves nothing, a click places the playhead, the camera
// follows the playhead's car, and the user's own framing is kept.

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import 'stage_fixture.dart';

const _size = Size(800, 600);

Future<(ProviderContainer, TrackPath)> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  await tester.binding.setSurfaceSize(_size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final path = circleLap();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: _size, disableAnimations: reducedMotion),
          child: Scaffold(
            body: MapStage(
              path: path,
              colouring: RampColouring(
                path,
                ValueRamp(const Color(0xFF38C6D9)),
                fallback: const Color(0xFF38C6D9),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    ProviderScope.containerOf(tester.element(find.byType(MapStage))),
    path,
  );
}

MapCamera _camera(WidgetTester tester) {
  final paint = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(MapStage),
          matching: find.byType(CustomPaint),
        ),
      )
      .firstWhere((p) => p.painter is StagePainter);
  return (paint.painter! as StagePainter).camera.value;
}

/// Point [i] of [path] on screen, through the stage's camera.
Offset _onScreen(WidgetTester tester, TrackPath path, int i) =>
    _camera(tester).toScreen(path.projection.points[i]);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: const Offset(1, 1));
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  testWidgets('shows the whole lap until something places the playhead', (
    tester,
  ) async {
    final (_, path) = await _pump(tester);
    final fit = MapCamera.fit(
      path.projection.boundsMetres,
      Offset.zero & _size,
    );
    expect(_camera(tester).pixelsPerMetre, closeTo(fit.pixelsPerMetre, 1e-9));
  });

  testWidgets('hovering the line probes it and moves nothing', (tester) async {
    final (container, path) = await _pump(tester);
    final before = _camera(tester);
    final mouse = await _mouse(tester);

    await mouse.moveTo(_onScreen(tester, path, 120));
    await tester.pumpAndSettle();
    final sync = container.read(chartSyncProvider);
    expect(sync.probe, closeTo(path.xs[120], 2));
    expect(sync.playhead, isNull);
    expect(_camera(tester), before, reason: 'hover never moves the map');

    await mouse.moveTo(const Offset(400, 300)); // the middle of the circle
    await tester.pumpAndSettle();
    expect(container.read(chartSyncProvider).probe, isNull);
  });

  testWidgets('a click on the line places the playhead, and the camera '
      'follows the car there', (tester) async {
    final (container, path) = await _pump(tester);
    final fitZoom = _camera(tester).pixelsPerMetre;
    final at = _onScreen(tester, path, 200);

    await tester.tapAt(at);
    await tester.pumpAndSettle();

    final playhead = container.read(chartSyncProvider).playhead;
    expect(playhead, closeTo(path.xs[200], 2));
    final camera = _camera(tester);
    expect(camera.pixelsPerMetre, greaterThan(fitZoom));
    // The car sits near the middle, a little behind the look-ahead.
    final car = camera.toScreen(path.projection.points[200]);
    expect((car - const Offset(400, 300)).distance, lessThan(150));
  });

  testWidgets('a double-click fits the whole lap again', (tester) async {
    final (container, path) = await _pump(tester);
    final fitZoom = _camera(tester).pixelsPerMetre;
    container.read(chartSyncProvider.notifier).setPlayhead(path.xs[60]);
    await tester.pumpAndSettle();
    expect(_camera(tester).pixelsPerMetre, greaterThan(fitZoom));

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(_camera(tester).pixelsPerMetre, closeTo(fitZoom, 1e-6));
  });

  testWidgets('after a drag the camera stays where the user put it', (
    tester,
  ) async {
    final (container, path) = await _pump(tester);
    container.read(chartSyncProvider.notifier).setPlayhead(path.xs[60]);
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(100, 100), const Offset(120, 40));
    await tester.pumpAndSettle();
    final placed = _camera(tester);

    container.read(chartSyncProvider.notifier).setPlayhead(path.xs[220]);
    await tester.pumpAndSettle();
    expect(_camera(tester), placed);

    // Follow brings it back to the car.
    await tester.tap(find.byIcon(Icons.my_location));
    await tester.pumpAndSettle();
    final car = _camera(tester).toScreen(path.projection.points[220]);
    expect((car - const Offset(400, 300)).distance, lessThan(150));
  });

  testWidgets('under reduced motion the camera cuts rather than glides', (
    tester,
  ) async {
    final (container, path) = await _pump(tester, reducedMotion: true);
    container.read(chartSyncProvider.notifier).setPlayhead(path.xs[160]);
    await tester.pump();
    final car = _camera(tester).toScreen(path.projection.points[160]);
    expect((car - const Offset(400, 300)).distance, lessThan(150));
    final cut = _camera(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_camera(tester), cut, reason: 'nothing left to glide');
  });
}
