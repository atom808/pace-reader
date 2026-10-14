// ClassChip: a car class badged the way Le Mans Ultimate badges it
// (docs/ICONOGRAPHY-PLAN-2026-10-14.md §4).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/reference/car_class.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/identity/class_chip.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

const _known = ['Hyper', 'LMP2', 'LMP2_ELMS', 'LMP3', 'GTE', 'GT3'];

/// The palette [raw] is drawn in, read through a real [BuildContext].
Future<ClassPalette> _palette(WidgetTester tester, String raw) async {
  late ClassPalette palette;
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) {
          palette = ClassPalette.of(context, CarClass.parse(raw));
          return const SizedBox();
        },
      ),
    ),
  );
  return palette;
}

void main() {
  group('colour', () {
    test('is the game\'s own, from its stylesheet', () {
      expect(ClassColors.hypercar, const Color(0xFFE21E19));
      expect(ClassColors.lmgt3, const Color(0xFF009639));
      expect(ClassColors.lmp2, const Color(0xFF005096));
      expect(ClassColors.lmp2ElmsMarker, const Color(0xFFE95B0C));
      expect(ClassColors.lmp3, const Color(0xFF411C52));
      expect(ClassColors.lmgte, const Color(0xFFF08C00));
    });

    testWidgets('every known class letters its name at 3:1 or better', (
      tester,
    ) async {
      for (final raw in _known) {
        final p = await _palette(tester, raw);
        expect(
          contrastRatio(p.label, p.fill),
          greaterThanOrEqualTo(3),
          reason: raw,
        );
      }
    });

    test('white, as in the game, except on GTE orange', () {
      expect(ClassPalette.labelOn(ClassColors.hypercar), Colors.white);
      expect(ClassPalette.labelOn(ClassColors.lmp2), Colors.white);
      expect(ClassPalette.labelOn(ClassColors.lmp3), Colors.white);
      expect(ClassPalette.labelOn(ClassColors.lmgt3), Colors.white);
      // White measures 3.9:1 on the game's GT3 green and 2.5:1 on its orange.
      expect(
        contrastRatio(Colors.white, ClassColors.lmgt3),
        closeTo(3.9, 0.05),
      );
      expect(contrastRatio(Colors.white, ClassColors.lmgte), lessThan(3));
      expect(ClassPalette.labelOn(ClassColors.lmgte), AppColors.surfaceBase);
    });

    test('the edge is lighter than the fill, so dark classes still read', () {
      // LMP3's fill is 1.4:1 on the app's base surface; its edge is not.
      expect(
        contrastRatio(ClassColors.lmp3, AppColors.surfaceBase),
        lessThan(1.5),
      );
      for (final fill in [
        ClassColors.hypercar,
        ClassColors.lmp2,
        ClassColors.lmp3,
        ClassColors.lmgte,
        ClassColors.lmgt3,
      ]) {
        final edge = ClassPalette.liftedEdge(fill);
        expect(
          edge.computeLuminance(),
          greaterThan(fill.computeLuminance()),
          reason: '$fill',
        );
      }
      expect(
        contrastRatio(
          ClassPalette.liftedEdge(ClassColors.lmp3),
          AppColors.surfaceBase,
        ),
        greaterThan(2),
      );
    });

    testWidgets('only the ELMS LMP2 carries the orange corner', (tester) async {
      expect((await _palette(tester, 'LMP2_ELMS')).marker.a, 1);
      for (final raw in ['LMP2', 'Hyper', 'GT3 Pro']) {
        expect((await _palette(tester, raw)).marker.a, 0, reason: raw);
      }
    });
  });

  group('the chip', () {
    testWidgets('shows the short code when compact, the name otherwise', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              ClassChip.raw('Hyper', size: ClassChipSize.compact),
              ClassChip.raw('Hyper'),
              ClassChip.raw('GT3', size: ClassChipSize.large),
            ],
          ),
        ),
      );
      expect(find.text('HY'), findsOneWidget);
      expect(find.text('HYPERCAR'), findsOneWidget);
      expect(find.text('LMGT3'), findsOneWidget);
      expect(find.text('Hyper'), findsNothing);
    });

    testWidgets('is as tall as its size says', (tester) async {
      for (final size in ClassChipSize.values) {
        await tester.pumpWidget(_app(ClassChip.raw('LMP3', size: size)));
        expect(tester.getSize(find.byType(ClassChip)).height, size.height);
      }
    });

    testWidgets('is as wide as its label, even where a Wrap offers more', (
      tester,
    ) async {
      // Overview, Setup and Technique hold it in a Wrap, whose children are
      // offered the whole row: it once stretched across all of it.
      for (final size in ClassChipSize.values) {
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 800,
              child: Wrap(children: [ClassChip.raw('Hyper', size: size)]),
            ),
          ),
        );
        expect(
          tester.getSize(find.byType(ClassChip)).width,
          lessThan(140),
          reason: '$size',
        );
      }
    });

    testWidgets('names the class to a screen reader, ELMS included', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Column(
            children: [ClassChip.raw('Hyper'), ClassChip.raw('LMP2_ELMS')],
          ),
        ),
      );
      expect(find.bySemanticsLabel('Hypercar class'), findsOneWidget);
      expect(find.bySemanticsLabel('LMP2 ELMS class'), findsOneWidget);
      // The letters on the block are not read out a second time.
      expect(find.bySemanticsLabel('HYPERCAR'), findsNothing);
      semantics.dispose();
    });

    testWidgets('says the file\'s own code in its tooltip', (tester) async {
      await tester.pumpWidget(_app(ClassChip.raw('Hyper')));
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('"Hyper"'));
      expect(classTooltip(CarClass.parse('LMP2_ELMS')), contains('orange'));
      expect(classTooltip(CarClass.parse('GT3 Pro')), contains('no colour'));
    });

    testWidgets('an unknown class shows its raw name on a neutral block', (
      tester,
    ) async {
      await tester.pumpWidget(_app(ClassChip.raw('GT3 Pro')));
      expect(find.text('GT3 PRO'), findsOneWidget);
      final p = await _palette(tester, 'GT3 Pro');
      expect(p.fill, AppColors.surfaceHighest);
    });
  });

  group('a change of class', () {
    Color fillNow(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ClassChip),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      return (paint.painter as dynamic).palette.fill as Color;
    }

    testWidgets('travels between the two colours', (tester) async {
      await tester.pumpWidget(_app(ClassChip.raw('Hyper')));
      await tester.pumpWidget(_app(ClassChip.raw('GT3')));
      await tester.pump(AppDurations.medium ~/ 2);
      final mid = fillNow(tester);
      expect(mid, isNot(ClassColors.hypercar));
      expect(mid, isNot(ClassColors.lmgt3));
      await tester.pumpAndSettle();
      expect(fillNow(tester), ClassColors.lmgt3);
    });

    testWidgets('lands at once under reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(ClassChip.raw('Hyper')));
      await tester.pumpWidget(_app(ClassChip.raw('GT3')));
      await tester.pump();
      expect(fillNow(tester), ClassColors.lmgt3);
    });
  });
}
