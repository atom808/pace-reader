// The map stage as an inset (map stage proposal §9, P6): the map in a card
// on a screen with no lap clock — Driving Technique's segments, Suspension's
// sites. It reads nothing shared, hands the line under the pointer to its
// host, leaves the plain wheel to the page, and holds widgets to points.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import 'stage_fixture.dart';

const _size = Size(900, 640);

class _Hits implements StageHitTarget {
  final hovers = <double?>[];
  final taps = <double?>[];

  @override
  void hover(double? station) => hovers.add(station);

  @override
  void tap(double? station) => taps.add(station);
}

Future<(ProviderContainer, TrackPath)> _pump(
  WidgetTester tester, {
  StageHitTarget? hits,
  List<StagePin> pins = const [],
}) async {
  await tester.binding.setSurfaceSize(_size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final path = circleLap();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: MapStage.inset(
            path: path,
            colouring: const SolidColouring(Color(0xFF888888)),
            hits: hits,
            pins: pins,
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

/// Where `Lap Dist` [station] is on screen, as the camera draws it now.
Offset _screenAt(WidgetTester tester, TrackPath path, double station) =>
    tester.getTopLeft(find.byType(MapStage)) +
    stagePainter(tester).camera.value
        .toScreen(path.positionAtStation(station)!);

void main() {
  testWidgets('opens on the whole lap, and the host reads the line under '
      'the pointer as Lap Dist', (tester) async {
    final hits = _Hits();
    final (_, path) = await _pump(tester, hits: hits);
    // The whole lap is in view.
    final shown = stagePainter(tester).camera.value.visibleMetres(_size);
    expect(
      shown.inflate(1).contains(path.projection.boundsMetres.topLeft),
      isTrue,
    );
    expect(
      shown.inflate(1).contains(path.projection.boundsMetres.bottomRight),
      isTrue,
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(_screenAt(tester, path, 300));
    await tester.pump();
    expect(hits.hovers.last, closeTo(300, 3));
    // A probe ring of its own, where the pointer reads the line.
    expect(stageLayers<ProbeLayer>(tester).single.at, isNotNull);

    await tester.tapAt(_screenAt(tester, path, 600));
    await tester.pump(const Duration(milliseconds: 500));
    expect(hits.taps.last, closeTo(600, 3));

    // Off the line: the host is told so.
    await mouse.moveTo(tester.getCenter(find.byType(MapStage)));
    await tester.pump();
    expect(hits.hovers.last, isNull);
    expect(stageLayers<ProbeLayer>(tester).single.at, isNull);
  });

  testWidgets('reads nothing shared: a playhead and a probe elsewhere put no '
      'car and no ring on it', (tester) async {
    final (container, path) = await _pump(tester);
    container.read(chartSyncProvider.notifier)
      ..setPlayhead(path.xs[40])
      ..setProbe(path.xs[80]);
    await tester.pumpAndSettle();
    expect(stageLayers<CarLayer>(tester).single.cars, isEmpty);
    expect(stageLayers<ProbeLayer>(tester).single.at, isNull);
  });

  testWidgets('the plain wheel is the page\'s; Ctrl+wheel zooms', (
    tester,
  ) async {
    await _pump(tester);
    final before = stagePainter(tester).camera.value.pixelsPerMetre;
    final centre = tester.getCenter(find.byType(MapStage));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: centre);

    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(450, 320),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.pumpAndSettle();
    expect(stagePainter(tester).camera.value.pixelsPerMetre, before);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(
      const PointerScrollEvent(
        position: Offset(450, 320),
        scrollDelta: Offset(0, -120),
      ),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(
      stagePainter(tester).camera.value.pixelsPerMetre,
      greaterThan(before),
    );
  });

  testWidgets('a drag pans, and the whole-lap button brings it back', (
    tester,
  ) async {
    await _pump(tester);
    final back = find.byTooltip('Whole lap (or double-click the map)');
    double opacity() => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: back, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(opacity(), 0);
    final whole = stagePainter(tester).camera.value;

    await tester.drag(find.byType(MapStage), const Offset(-160, 90));
    await tester.pumpAndSettle();
    expect(stagePainter(tester).camera.value.centre, isNot(whole.centre));
    expect(opacity(), 1);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(
      (stagePainter(tester).camera.value.centre - whole.centre).distance,
      lessThan(0.5),
    );
    expect(opacity(), 0);
  });

  testWidgets('a pin is held to its point, at its own size', (tester) async {
    final (_, path) = await _pump(
      tester,
      pins: [
        StagePin(
          key: const ValueKey('pin'),
          at: circleLap().positionAtStation(300)!,
          size: 30,
          child: const ColoredBox(color: Color(0xFFFF0000)),
        ),
      ],
    );
    final pin = find.byKey(const ValueKey('pin'));
    expect(tester.getSize(pin), const Size(30, 30));
    expect(
      (tester.getCenter(pin) - _screenAt(tester, path, 300)).distance,
      lessThan(0.5),
    );

    await tester.drag(find.byType(MapStage), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(
      (tester.getCenter(pin) - _screenAt(tester, path, 300)).distance,
      lessThan(0.5),
    );
    expect(tester.getSize(pin), const Size(30, 30));
  });
}
