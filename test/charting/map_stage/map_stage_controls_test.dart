// The map stage's own controls (map stage proposal §4, P4): the minimap and
// its zoom, the camera commands a host's keys call, the trace window framed
// and cased, and a new colouring fading in over the old.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import 'stage_fixture.dart';

const _size = Size(900, 640);
const _cyan = Color(0xFF38C6D9);
const _amber = Color(0xFFF2A93B);

LineColouring _plain(TrackPath path, Color colour) =>
    RampColouring(path, ValueRamp(colour), fallback: colour);

Widget _stage(
  TrackPath path, {
  LineColouring? colouring,
  MapStageController? controller,
  bool minimap = true,
  bool reducedMotion = false,
  Size size = _size,
}) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: reducedMotion),
      child: Scaffold(
        body: MapStage(
          path: path,
          colouring: colouring ?? _plain(path, _cyan),
          controller: controller,
          minimap: minimap,
        ),
      ),
    ),
  ),
);

Future<(ProviderContainer, TrackPath)> _pump(
  WidgetTester tester, {
  MapStageController? controller,
  bool minimap = true,
  Size size = _size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final path = circleLap();
  await tester.pumpWidget(
    _stage(path, controller: controller, minimap: minimap, size: size),
  );
  await tester.pumpAndSettle();
  return (
    ProviderScope.containerOf(tester.element(find.byType(MapStage))),
    path,
  );
}

StagePainter _painter(WidgetTester tester) =>
    tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(MapStage),
                matching: find.byType(CustomPaint),
              ),
            )
            .firstWhere((p) => p.painter is StagePainter)
            .painter!
        as StagePainter;

MapCamera _camera(WidgetTester tester) => _painter(tester).camera.value;

String _caption(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(MapMinimap), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .firstWhere(
      (d) =>
          d == 'Whole lap' ||
          d == 'Free' ||
          d == 'Following the car' ||
          d == 'Trace window',
    )!;

void main() {
  group('the minimap', () {
    testWidgets('stands in for the camera buttons where there is room', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(MapMinimap), findsOneWidget);
      expect(_caption(tester), 'Whole lap');
      // Bottom right, clear of the top-right corner the buttons had.
      final rect = tester.getRect(find.byType(MapMinimap));
      expect(rect.right, greaterThan(_size.width - 40));
      expect(rect.bottom, greaterThan(_size.height - 40));
    });

    testWidgets('a small stage keeps the bare buttons', (tester) async {
      await _pump(tester, size: const Size(480, 320));
      expect(find.byType(MapMinimap), findsNothing);
      expect(find.byIcon(Icons.fit_screen_outlined), findsOneWidget);
    });

    testWidgets('says when the camera follows the car', (tester) async {
      final (container, path) = await _pump(tester);
      container.read(chartSyncProvider.notifier).setPlayhead(path.xs[100]);
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Following the car');
    });

    testWidgets('a click on it centres the map there, and frees the camera', (
      tester,
    ) async {
      final (container, path) = await _pump(tester);
      container.read(chartSyncProvider.notifier).setPlayhead(path.xs[100]);
      await tester.pumpAndSettle();

      // The minimap's map is its top part; its top-left quarter is a part
      // of the circle well away from the car at point 100.
      final mini = tester.getRect(find.byType(MapMinimap));
      await tester.tapAt(mini.topLeft + const Offset(40, 36));
      await tester.pumpAndSettle();

      expect(_caption(tester), 'Free');
      final camera = _camera(tester);
      final car = camera.toScreen(path.projection.points[100]);
      expect(
        (car - const Offset(450, 320)).distance,
        greaterThan(150),
        reason: 'the map went where the click was, not to the car',
      );
    });

    testWidgets('its slider zooms between the whole lap and close in', (
      tester,
    ) async {
      await _pump(tester);
      final whole = _camera(tester).pixelsPerMetre;
      final slider = tester.widget<Slider>(
        find.descendant(
          of: find.byType(MapMinimap),
          matching: find.byType(Slider),
        ),
      );
      expect(slider.value, closeTo(0, 0.05), reason: 'the whole lap is 0');

      slider.onChanged!(1);
      await tester.pumpAndSettle();
      expect(_camera(tester).pixelsPerMetre, greaterThan(whole * 2));
      expect(
        tester
            .widget<Slider>(
              find.descendant(
                of: find.byType(MapMinimap),
                matching: find.byType(Slider),
              ),
            )
            .value,
        closeTo(1, 0.05),
      );
    });
  });

  group('the trace window', () {
    testWidgets('a zoom on the traces frames that stretch on the map', (
      tester,
    ) async {
      final (container, path) = await _pump(tester);
      final whole = _camera(tester).pixelsPerMetre;
      container
          .read(chartSyncProvider.notifier)
          .showWindow(
            const ChartViewport(200, 500),
            bounds: ChartViewport(path.xs.first, path.xs.last),
          );
      await tester.pumpAndSettle();

      expect(_caption(tester), 'Trace window');
      final camera = _camera(tester);
      expect(camera.pixelsPerMetre, greaterThan(whole));
      final screen = Offset.zero & _size;
      for (var i = 0; i < path.xs.length; i++) {
        if (path.xs[i] < 200 || path.xs[i] > 500) continue;
        expect(
          screen.contains(camera.toScreen(path.projection.points[i])),
          isTrue,
          reason: 'point $i of the window is on screen',
        );
      }
      expect(
        _painter(tester).layers.whereType<WindowCasingLayer>(),
        hasLength(1),
        reason: 'the window is cased on the line',
      );
    });

    testWidgets('the casing leaves with the zoom', (tester) async {
      final (container, path) = await _pump(tester);
      final sync = container.read(chartSyncProvider.notifier);
      sync.showWindow(
        const ChartViewport(200, 500),
        bounds: ChartViewport(path.xs.first, path.xs.last),
      );
      await tester.pumpAndSettle();
      sync.resetViewport();
      await tester.pumpAndSettle();
      expect(_painter(tester).layers.whereType<WindowCasingLayer>(), isEmpty);
      expect(_caption(tester), 'Whole lap');
    });
  });

  group('the controller', () {
    testWidgets('fit, follow and zoom do what the keys say', (tester) async {
      final controller = MapStageController();
      final (container, path) = await _pump(tester, controller: controller);
      final whole = _camera(tester).pixelsPerMetre;

      controller.follow();
      await tester.pumpAndSettle();
      expect(
        _caption(tester),
        'Whole lap',
        reason: 'nothing to follow before a playhead',
      );

      container.read(chartSyncProvider.notifier).setPlayhead(path.xs[100]);
      await tester.pumpAndSettle();
      final following = _camera(tester).pixelsPerMetre;
      controller.zoomBy(1.25);
      await tester.pumpAndSettle();
      expect(
        _camera(tester).pixelsPerMetre,
        greaterThan(following * 1.1),
        reason: '+ closes in',
      );
      expect(
        _caption(tester),
        'Following the car',
        reason: 'and still follows',
      );

      controller.fit();
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Whole lap');
      expect(_camera(tester).pixelsPerMetre, closeTo(whole, whole * 0.01));

      controller.follow();
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Following the car');
    });
  });

  group('a new colouring', () {
    testWidgets('fades in over the old one', (tester) async {
      await tester.binding.setSurfaceSize(_size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final path = circleLap();
      await tester.pumpWidget(_stage(path));
      await tester.pumpAndSettle();

      await tester.pumpWidget(_stage(path, colouring: _plain(path, _amber)));
      await tester.pump(const Duration(milliseconds: 80));
      final lines = _painter(tester).layers.whereType<TrackLineLayer>();
      expect(lines, hasLength(2), reason: 'the old line under the new');
      expect(lines.last.opacity, inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(_painter(tester).layers.whereType<TrackLineLayer>(), hasLength(1));
    });

    testWidgets('on another lap cuts, never painting old colours on it', (
      tester,
    ) async {
      // A regression: the fading colouring was the old lap's, indexed by
      // the old lap's points, and painting it on a longer lap threw.
      await tester.binding.setSurfaceSize(_size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final short = circleLap(radius: 150);
      await tester.pumpWidget(_stage(short));
      await tester.pumpAndSettle();

      final long = circleLap();
      await tester.pumpWidget(_stage(long, colouring: _plain(long, _amber)));
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
      expect(_painter(tester).layers.whereType<TrackLineLayer>(), hasLength(1));
    });

    testWidgets('cuts under reduced motion', (tester) async {
      await tester.binding.setSurfaceSize(_size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final path = circleLap();
      await tester.pumpWidget(_stage(path, reducedMotion: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _stage(path, colouring: _plain(path, _amber), reducedMotion: true),
      );
      await tester.pump();
      expect(_painter(tester).layers.whereType<TrackLineLayer>(), hasLength(1));
    });
  });
}
