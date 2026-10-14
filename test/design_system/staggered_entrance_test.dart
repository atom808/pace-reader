// StaggeredEntrance and useStaggeredFadeIn (SPEC.md §9.7.4, §9.7.6).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _keys = [ValueKey('a'), ValueKey('b'), ValueKey('c')];

Widget _row({int count = 3}) => MaterialApp(
  home: Scaffold(
    body: Wrap(
      spacing: 16,
      children: [
        for (var i = 0; i < count; i++)
          StaggeredEntrance(
            index: i,
            child: SizedBox(key: _keys[i], width: 100, height: 60),
          ),
      ],
    ),
  ),
);

Widget _plainRow({int count = 3}) => MaterialApp(
  home: Scaffold(
    body: Wrap(
      spacing: 16,
      children: [
        for (var i = 0; i < count; i++)
          SizedBox(key: _keys[i], width: 100, height: 60),
      ],
    ),
  ),
);

double _opacity(WidgetTester tester, Key key) {
  var opacity = 1.0;
  final fades = find.ancestor(
    of: find.byKey(key),
    matching: find.byType(FadeTransition),
  );
  for (final element in fades.evaluate()) {
    opacity *= (element.widget as FadeTransition).opacity.value;
  }
  return opacity;
}

void main() {
  group('StaggeredEntrance', () {
    testWidgets('starts every item hidden and low', (tester) async {
      await tester.pumpWidget(_row());

      for (final key in _keys) {
        expect(_opacity(tester, key), 0);
      }
    });

    testWidgets('is in the semantics tree while it waits its turn', (
      tester,
    ) async {
      // Faded is not absent: a tooltip opened on an item still at zero had no
      // anchor in the tree (see AppTooltip).
      final handle = tester.ensureSemantics();
      const key = ValueKey('waiting');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredEntrance(
              index: 10,
              child: Text('waiting', key: key),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_opacity(tester, key), 0);
      expect(find.bySemanticsLabel('waiting'), findsOneWidget);
      await tester.pumpAndSettle();
      handle.dispose();
    });

    testWidgets('starts each item 40 ms after the one before', (tester) async {
      await tester.pumpWidget(_row());

      // 20 ms in: the first has begun, the second's turn has not come.
      await tester.pump(const Duration(milliseconds: 20));
      expect(_opacity(tester, _keys[0]), greaterThan(0));
      expect(_opacity(tester, _keys[1]), 0);
      expect(_opacity(tester, _keys[2]), 0);

      // 60 ms in: the second is under way, the third (due at 80) is not.
      await tester.pump(const Duration(milliseconds: 40));
      expect(_opacity(tester, _keys[1]), greaterThan(0));
      expect(_opacity(tester, _keys[2]), 0);

      // 100 ms in: all three are moving, and in order.
      await tester.pump(const Duration(milliseconds: 40));
      final opacities = [for (final key in _keys) _opacity(tester, key)];
      expect(opacities[2], greaterThan(0));
      expect(opacities[0], greaterThan(opacities[1]));
      expect(opacities[1], greaterThan(opacities[2]));
    });

    testWidgets('rises 8 px into place', (tester) async {
      await tester.pumpWidget(_plainRow());
      final settledTop = tester.getTopLeft(find.byKey(_keys[0])).dy;

      await tester.pumpWidget(_row());
      expect(tester.getTopLeft(find.byKey(_keys[0])).dy, settledTop + 8);

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(_keys[0])).dy, settledTop);
    });

    testWidgets('settles on exactly the layout it would have had unwrapped', (
      tester,
    ) async {
      // What lets a golden `pumpAndSettle` and see today's picture.
      await tester.pumpWidget(_plainRow());
      final expected = [
        for (final key in _keys) tester.getRect(find.byKey(key)),
      ];

      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();

      expect([
        for (final key in _keys) tester.getRect(find.byKey(key)),
      ], expected);
      for (final key in _keys) {
        expect(_opacity(tester, key), 1);
      }
    });

    testWidgets('leaves nothing but the child behind once it has landed', (
      tester,
    ) async {
      // A finished FadeTransition still paints through an offscreen layer, and
      // that moved one pixel of the Session Overview golden by one blue step.
      await tester.pumpWidget(_row());
      expect(
        find.ancestor(
          of: find.byKey(_keys[0]),
          matching: find.byType(FadeTransition),
        ),
        findsWidgets,
      );

      await tester.pumpAndSettle();

      for (final key in _keys) {
        expect(
          find.ancestor(
            of: find.byKey(key),
            matching: find.byType(StaggeredEntrance),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(StaggeredEntrance).at(_keys.indexOf(key)),
            matching: find.byType(FadeTransition),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byType(StaggeredEntrance).at(_keys.indexOf(key)),
            matching: find.byType(Transform),
          ),
          findsNothing,
        );
      }
    });

    testWidgets('keeps the child\'s state across the moment it lands', (
      tester,
    ) async {
      // The wrapper steps out of the tree when the animation ends; the child
      // must be carried over, not rebuilt from nothing (a tile with hover or
      // focus state would lose it).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaggeredEntrance(index: 0, child: const _Counter()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('taps: 1'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('taps: 1'), findsOneWidget);
    });

    testWidgets('does not reflow its parent while it arrives', (tester) async {
      // The rise is a paint offset: a Wrap of these must be the same size on
      // the first frame as on the last, or the page would jump under the
      // pointer as the tiles land.
      await tester.pumpWidget(_row());
      final first = tester.getSize(find.byType(Wrap));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(Wrap)), first);
    });

    testWidgets('does not restart when its parent rebuilds', (tester) async {
      await tester.pumpWidget(_row());
      await tester.pump(const Duration(milliseconds: 200));
      final before = _opacity(tester, _keys[0]);

      await tester.pumpWidget(_row());
      // Same widget position, new widget instances: still the same item.
      expect(_opacity(tester, _keys[0]), before);
    });

    testWidgets('reduced motion: everything is in place on the first frame', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_plainRow());
      final settledTop = tester.getTopLeft(find.byKey(_keys[2])).dy;

      await tester.pumpWidget(_row());
      await tester.pump();

      for (final key in _keys) {
        expect(_opacity(tester, key), 1);
      }
      expect(tester.getTopLeft(find.byKey(_keys[2])).dy, settledTop);
    });

    testWidgets('a larger index waits longer but finishes later, not sooner', (
      tester,
    ) async {
      await tester.pumpWidget(_row());
      // 360 ms is the first item's whole run; the third, 80 ms behind, is
      // still finishing.
      await tester.pump(const Duration(milliseconds: 360));

      expect(_opacity(tester, _keys[0]), 1);
      expect(_opacity(tester, _keys[2]), lessThan(1));

      await tester.pump(const Duration(milliseconds: 80));
      expect(_opacity(tester, _keys[2]), 1);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: SizedBox(width: 100, height: 60, child: Text('taps: $taps')),
  );
}
