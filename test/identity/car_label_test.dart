// CarLabel: a recording's car by its model, from the catalog
// (docs/ICONOGRAPHY-PLAN-2026-10-14.md §2.4).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/identity/car_label.dart';
import 'package:pace_reader/widgets/identity/class_chip.dart';

import '../design_system/portal_semantics.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: 600, child: child)),
  ),
);

const _dames = ('Iron Dames 2025 #85:LM', 'GT3');
const _toyota = ('Toyota Racing 2026 #7:LM', 'Hyper');
const _unknown = ('Some New Team 2026 #1:LM', 'GT3');

CarLabel _label(
  (String, String) car, {
  CarLabelSize size = CarLabelSize.compact,
  List<String> trailing = const [],
  bool showEntry = true,
}) => CarLabel.of(
  car.$1,
  car.$2,
  size: size,
  trailing: trailing,
  showEntry: showEntry,
);

String _tooltip(WidgetTester tester) => tester
    .widget<Tooltip>(
      find
          .descendant(of: find.byType(CarLabel), matching: find.byType(Tooltip))
          .first,
    )
    .message!;

/// Whether the car mark draws a prototype.
bool _prototype(WidgetTester tester) =>
    (tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(CarMark),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as CarGlyphPainter)
        .prototype;

void main() {
  group('compact', () {
    testWidgets('the model leads, then the entry and the row\'s own facts', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_label(_dames, trailing: ['Diego'])));
      expect(
        find.text('Porsche 911 GT3 R · Iron Dames #85 · Diego'),
        findsOneWidget,
      );
      expect(find.widgetWithText(ClassChip, 'GT3'), findsOneWidget);
      // No mark in a list row until the game's logos exist: one glyph
      // repeated down a list would say nothing.
      expect(find.byType(CarMark), findsNothing);
    });

    testWidgets('without the entry, for a row that names the session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(_label(_toyota, showEntry: false, trailing: ['Race', 'Diego'])),
      );
      expect(find.text('Toyota GR010 Hybrid · Race · Diego'), findsOneWidget);
    });

    testWidgets('a car the catalog cannot place keeps its own name', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_label(_unknown, trailing: ['Diego'])));
      // The entry is the title, and not said twice.
      expect(find.text('Some New Team 2026 #1 · Diego'), findsOneWidget);
      expect(_tooltip(tester), contains('not in Pace Reader\'s catalog'));
    });
  });

  group('row and hero', () {
    testWidgets('the model over the class and entry, beside the mark', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_label(_dames, size: CarLabelSize.row)));
      expect(find.text('Porsche 911 GT3 R'), findsOneWidget);
      expect(find.text('Iron Dames 2025 #85'), findsOneWidget);
      expect(find.widgetWithText(ClassChip, 'GT3'), findsOneWidget);
      expect(find.byType(CarMark), findsOneWidget);
      expect(_prototype(tester), isFalse);
    });

    testWidgets('the hero is a headline with the class by name', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_label(_toyota, size: CarLabelSize.hero)));
      final title = tester.widget<Text>(find.text('Toyota GR010 Hybrid'));
      final theme = Theme.of(tester.element(find.byType(CarLabel)));
      expect(title.style?.fontSize, theme.textTheme.headlineSmall?.fontSize);
      expect(find.widgetWithText(ClassChip, 'HYPERCAR'), findsOneWidget);
      // A prototype's outline for a Hypercar.
      expect(_prototype(tester), isTrue);
      expect(tester.getSize(find.byType(CarMark)), const Size(80, 40));
    });

    testWidgets('a change of car cross-fades', (tester) async {
      await tester.pumpWidget(_app(_label(_dames, size: CarLabelSize.row)));
      await tester.pumpWidget(_app(_label(_toyota, size: CarLabelSize.row)));
      await tester.pump(AppDurations.medium ~/ 2);
      expect(find.text('Porsche 911 GT3 R'), findsOneWidget);
      expect(find.text('Toyota GR010 Hybrid'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Porsche 911 GT3 R'), findsNothing);
    });

    testWidgets('under reduced motion, it swaps at once', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(_label(_dames, size: CarLabelSize.row)));
      await tester.pumpWidget(_app(_label(_toyota, size: CarLabelSize.row)));
      // No time passes: one frame for the zero-length fade to end, one for
      // the switcher to drop the old car.
      await tester.pump();
      await tester.pump();
      expect(find.text('Porsche 911 GT3 R'), findsNothing);
      expect(find.text('Toyota GR010 Hybrid'), findsOneWidget);
    });
  });

  group('explained', () {
    testWidgets('hover says how the model was placed, and the file\'s name', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_label(_dames)));
      expect(
        _tooltip(tester),
        'Iron Dames ran the Porsche 911 GT3 R in LMGT3 in 2025.\n'
        'In the file: Iron Dames 2025 #85:LM',
      );
    });

    testWidgets('a screen reader hears the car, then the class', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              _label(_dames, trailing: ['Diego']),
              _label(_toyota, size: CarLabelSize.row),
              _label(_unknown, size: CarLabelSize.hero),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(
          'Porsche 911 GT3 R, Iron Dames 2025, number 85, Diego',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('LMGT3 class'), findsWidgets);
      // Nothing is read twice: the text is the label's.
      expect(find.bySemanticsLabel('Porsche 911 GT3 R'), findsNothing);
      // The label's tooltip and the chip's each hang from a node.
      expect(orphanablePortalAnchors(tester), isEmpty);
      expect(unlistedSemanticsNodes(tester), isEmpty);
      semantics.dispose();
    });
  });
}
