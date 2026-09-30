// Hoverable as the app's one tappable primitive (SPEC.md §9.7.6, §10): the
// pointer it shows, the keyboard it answers to, the focus ring it draws, the
// role it announces.
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

const _card = SizedBox(width: 200, height: 80, child: Text('card'));

/// The focus ring's opacity — 1 when it is showing, 0 when it is not.
double _ringOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byKey(const ValueKey('hoverable-focus-ring')))
    .opacity;

Finder get _scale => find.descendant(
  of: find.byType(Hoverable),
  matching: find.byType(AnimatedScale),
);

void main() {
  group('pointer', () {
    testWidgets('shows the click cursor when it does something', (tester) async {
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('card')));
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        SystemMouseCursors.click,
      );
    });

    testWidgets('leaves the cursor alone when it does nothing', (tester) async {
      await tester.pumpWidget(_app(const Hoverable(child: _card)));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('card')));
      await tester.pump();

      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        isNot(SystemMouseCursors.click),
      );
    });

    testWidgets('grows a little on hover and shrinks a little on press', (
      tester,
    ) async {
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));
      expect(tester.widget<AnimatedScale>(_scale).scale, 1.0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('card')));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(_scale).scale, 1.01);

      await mouse.down(tester.getCenter(find.text('card')));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(_scale).scale, 0.98);

      await mouse.up();
      await tester.pump();
      expect(tester.widget<AnimatedScale>(_scale).scale, 1.01);
    });
  });

  group('keyboard', () {
    testWidgets('Tab reaches it and Enter activates it', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(Hoverable(onTap: () => taps++, child: _card)));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('Space activates it too', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(Hoverable(onTap: () => taps++, child: _card)));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a Hoverable with no onTap is not in the tab order', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Hoverable(child: _card),
              Hoverable(onTap: () => taps++, child: _card),
            ],
          ),
        ),
      );

      // One Tab lands on the second card, not the first; Enter fires it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 1);
    });
  });

  group('focus ring (§9.7.2: a focused field is the edge lighting up)', () {
    testWidgets('lights up for keyboard focus', (tester) async {
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));
      expect(_ringOpacity(tester), 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(_ringOpacity(tester), 1);
    });

    testWidgets('is a gradient squircle edge in the strong hairline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(Hoverable(onTap: () {}, radius: AppRadii.md, child: _card)),
      );

      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(const ValueKey('hoverable-focus-ring')),
          matching: find.byType(DecoratedBox),
        ),
      );
      final shape = (box.decoration as ShapeDecoration).shape
          as GradientSquircleBorder;
      expect(shape.gradient, AppGradients.hairlineStrong);
      // Follows the child's corner, plus the gap it sits off by, so the ring
      // is concentric with the edge it surrounds rather than tighter at the
      // corners.
      expect(shape.radius, AppRadii.md + Hoverable.ringGap);
    });

    testWidgets('does not appear for a mouse click', (tester) async {
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('card')));
      await mouse.down(tester.getCenter(find.text('card')));
      await mouse.up();
      await tester.pumpAndSettle();

      expect(_ringOpacity(tester), 0);
    });

    testWidgets('leaves with focus', (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hoverable(onTap: () {}, child: _card),
              Hoverable(onTap: () {}, child: _card),
            ],
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final rings = tester
          .widgetList<AnimatedOpacity>(
            find.byKey(const ValueKey('hoverable-focus-ring')),
          )
          .map((w) => w.opacity);
      expect(rings, [0, 1]);
    });

    testWidgets('does not change the size the child is laid out at', (
      tester,
    ) async {
      // The ring is drawn outside the child. If it took part in layout every
      // card in the app would grow by its gap.
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));

      expect(tester.getSize(find.byType(Hoverable)), const Size(200, 80));
    });
  });

  group('semantics', () {
    testWidgets('announces a tappable one as a button, and names it', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(Hoverable(onTap: () {}, semanticLabel: 'Open laps', child: _card)),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('Open laps'))),
        matchesSemantics(
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
          label: 'Open laps\ncard',
        ),
      );
      handle.dispose();
    });

    testWidgets('does not claim to be a button when it is inert', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const Hoverable(child: _card)));

      final node = tester.getSemantics(find.text('card'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });

  group('reduced motion (§9.7.4)', () {
    testWidgets('collapses the scale and the ring to no duration', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));

      expect(tester.widget<AnimatedScale>(_scale).duration, Duration.zero);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.byKey(const ValueKey('hoverable-focus-ring')),
            )
            .duration,
        Duration.zero,
      );
    });

    testWidgets('keeps the hover state, only drops the travel', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(_app(Hoverable(onTap: () {}, child: _card)));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('card')));
      // One frame, no settling: the change has already landed.
      await tester.pump();

      expect(tester.widget<AnimatedScale>(_scale).scale, 1.01);
    });
  });
}
