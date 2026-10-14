// CompoundBadge: a tyre compound marked the way Le Mans Ultimate marks it
// (docs/ICONOGRAPHY-PLAN-2026-10-14.md §5).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/reference/tyre_compound.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/identity/compound_badge.dart';

import '../design_system/portal_semantics.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

const _medium = CompoundMark(kind: CompoundKind.medium, name: 'Medium');
const _soft = CompoundMark(kind: CompoundKind.soft, name: 'Soft');
const _wetSetup = CompoundMark(kind: CompoundKind.wet, name: 'Wet');
final _wet = CompoundKey.resolve(
  names: const {},
  start: const {},
).mark(3); // named through the game's order alone

/// The band colour each painted tyre is drawn with, in paint order.
List<Color> _bands(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(CompoundBadge),
      matching: find.byType(CustomPaint),
    ),
  ))
    if (paint.painter case final p?) (p as dynamic).band as Color,
];

/// Each dot of a mixed set, FL, FR, RL, RR: its fill, or for a hollow ring
/// the ring's colour, with whether it is hollow.
List<(Color, bool)> _dots(WidgetTester tester) => [
  for (final paint in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
    if (paint.painter case final p?
        when p.runtimeType.toString() == '_DotsPainter')
      for (final dynamic dot in (p as dynamic).dots as List)
        // Rounded to 8 bits a channel: a lerp lands a hair off the const.
        (dot.fill as Color).a > 0
            ? (Color((dot.fill as Color).toARGB32()), false)
            : (Color((dot.ring as Color).toARGB32()), true),
];

const _hard = CompoundMark(kind: CompoundKind.hard, name: 'Hard');

void main() {
  group('colour', () {
    test('is the game\'s own, from its stylesheet', () {
      expect(CompoundColors.soft, const Color(0xFFF3F4F8));
      expect(CompoundColors.medium, const Color(0xFFFFE500));
      expect(CompoundColors.hard, const Color(0xFFF80010));
      expect(CompoundColors.wet, const Color(0xFF4ED1EF));
      expect(compoundColor(null), isNull);
    });

    test('every band reads against the rubber at 3:1 or better', () {
      for (final kind in CompoundKind.values) {
        final band = compoundColor(kind)!;
        final hi = band.computeLuminance();
        final lo = CompoundColors.rubber.computeLuminance();
        expect(
          (hi + 0.05) / (lo + 0.05),
          greaterThanOrEqualTo(3),
          reason: '$kind',
        );
      }
    });
  });

  group('the badge', () {
    testWidgets('a compound is its letter on its colour', (tester) async {
      await tester.pumpWidget(_app(const CompoundBadge(mark: _medium)));
      expect(find.text('M'), findsOneWidget);
      expect(_bands(tester), [CompoundColors.medium]);
      expect(tester.getSize(find.byType(CompoundBadge)), const Size(20, 20));
    });

    testWidgets('an unnamed index is its number on a neutral, dashed band', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CompoundBadge(mark: CompoundMark.unnamed(2))),
      );
      expect(find.text('2'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(CompoundBadge),
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter
              as dynamic;
      expect(painter.dashed, isTrue);
      expect(painter.band, isNot(CompoundColors.soft));
    });

    testWidgets('a used set shows its tread beside it, whole band', (
      tester,
    ) async {
      final used = CompoundMark.ofSetup('70% Medium')!;
      await tester.pumpWidget(_app(CompoundBadge(mark: used)));
      expect(find.text('70 %'), findsOneWidget);
      await tester.pumpWidget(
        _app(CompoundBadge(mark: used, showTread: false)),
      );
      expect(find.text('70 %'), findsNothing);
    });

    testWidgets('a compound the game has not used before shows its initial', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(CompoundBadge(mark: CompoundMark.ofSetup('Intermediate')!)),
      );
      expect(find.text('I'), findsOneWidget);
      expect(
        compoundTooltip(CompoundMark.ofSetup('Intermediate')!),
        contains('no colour'),
      );
    });

    testWidgets('every size is as big as it says', (tester) async {
      for (final size in CompoundBadgeSize.values) {
        await tester.pumpWidget(_app(CompoundBadge(mark: _soft, size: size)));
        expect(
          tester.getSize(find.byType(CompoundBadge)).height,
          size.diameter,
        );
      }
    });
  });

  group('explaining itself', () {
    test('the tooltip says where the name came from', () {
      expect(compoundTooltip(_medium), contains('as the setup names it'));
      expect(
        compoundTooltip(CompoundMark.ofSetup('70% Medium')!),
        contains('70 % of its tread left'),
      );
      expect(compoundTooltip(_wet), contains('compound 3'));
      expect(compoundTooltip(_wet), contains('Soft, Medium, Hard, Wet'));
      final unnamed = CompoundKey.resolve(
        names: const {},
        start: const {},
      ).mark(1);
      expect(compoundTooltip(unnamed), startsWith('Compound 1, as the file'));
    });

    testWidgets('a screen reader hears a mixed set axle by axle or wheel by '
        'wheel', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _soft, _medium, _medium])),
      );
      expect(
        find.bySemanticsLabel('Mixed tyres: front Soft, rear Medium'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _app(
          const CompoundBadges(
            marks: [_medium, _soft, _medium, CompoundMark.unnamed(1)],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Mixed tyres: front left Medium, front right Soft, rear left '
          'Medium, rear right compound 1, not named',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('every tooltip keeps an anchor of its own', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Column(
            children: [
              CompoundBadges(marks: [_soft, _soft, _medium, _medium]),
              CompoundBadges(marks: [_medium, _medium, _medium, _medium]),
              CompoundBadges(marks: [_soft, _medium]),
              CompoundBadge(mark: CompoundMark.unnamed(1)),
            ],
          ),
        ),
      );
      expect(orphanablePortalAnchors(tester), isEmpty);
      expect(unlistedSemanticsNodes(tester), isEmpty);
      semantics.dispose();
    });

    testWidgets('inside something that explains it, no tooltip of its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft], tooltip: false)),
      );
      expect(find.byType(Tooltip), findsNothing);
    });
  });

  group('four corners', () {
    testWidgets('one badge when all four match, with its name if asked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const CompoundBadges(
            marks: [_medium, _medium, _medium, _medium],
            showName: true,
          ),
        ),
      );
      expect(find.byType(CompoundBadge), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
    });

    testWidgets("otherwise four dots in the wheels' places, as in the game", (
      tester,
    ) async {
      // Front and rear apart, left and right apart, one wheel apart: the
      // game draws every mixed set the same way.
      for (final marks in const [
        [_soft, _soft, _medium, _medium],
        [_medium, _soft, _medium, _soft],
        [_medium, _soft, _soft, _soft],
      ]) {
        await tester.pumpWidget(_app(CompoundBadges(marks: marks)));
        await tester.pumpAndSettle();
        expect(find.byType(CompoundBadge), findsNothing);
        expect(_dots(tester), [
          for (final m in marks) (compoundColor(m.kind)!, false),
        ]);
        expect(
          tester.getSize(find.byType(CompoundBadges)),
          const Size(16, 16),
          reason: 'the same room as one badge',
        );
        expect(find.text('F'), findsNothing);
      }
    });

    testWidgets('a wheel nothing names is a hollow ring, never white', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const CompoundBadges(
            marks: [_hard, _hard, CompoundMark.unnamed(1), _hard],
          ),
        ),
      );
      final dots = _dots(tester);
      expect(dots[2].$2, isTrue);
      expect(dots[2].$1, isNot(CompoundColors.soft));
      expect(dots[0], (CompoundColors.hard, false));
    });

    testWidgets('the name beside the dots spells the set out', (tester) async {
      await tester.pumpWidget(
        _app(
          const CompoundBadges(
            marks: [_soft, _soft, _medium, _medium],
            showName: true,
          ),
        ),
      );
      expect(find.text('F Soft, R Medium'), findsOneWidget);
    });

    testWidgets('fewer than four corners fall back to a badge per corner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _medium])),
      );
      expect(find.byType(CompoundBadge), findsNWidgets(2));
      expect(find.text('FL'), findsOneWidget);
      expect(_dots(tester), isEmpty);
    });

    test('the tooltip says how the dots read', () {
      final tip = compoundsTooltip(const [_soft, _soft, _medium, _medium]);
      expect(tip, contains('a dot per wheel'));
      expect(tip, contains('the fronts are on top'));
      expect(tip, contains('Front: Soft, as the setup names it'));
      expect(tip, contains('Rear: Medium, as the setup names it'));
      expect(
        compoundsTooltip(const [_soft, _soft, _soft, _soft]),
        compoundTooltip(_soft),
      );
    });
  });

  group('a change of compound', () {
    testWidgets('rolls the old tyre out and the new one in', (tester) async {
      await tester.pumpWidget(_app(const CompoundBadge(mark: _soft)));
      await tester.pumpWidget(_app(CompoundBadge(mark: _wet)));
      await tester.pump(AppDurations.slow ~/ 2);
      // Both on screen mid-roll, each turned off true.
      expect(_bands(tester), [CompoundColors.soft, CompoundColors.wet]);
      final turns = [
        for (final t in tester.widgetList<RotationTransition>(
          find.descendant(
            of: find.byType(CompoundBadge),
            matching: find.byType(RotationTransition),
          ),
        ))
          t.turns.value,
      ];
      expect(turns, hasLength(2));
      expect(turns.first, greaterThan(0), reason: 'the old one rolls on');
      expect(turns.last, lessThan(0), reason: 'the new one rolls in');
      await tester.pumpAndSettle();
      expect(_bands(tester), [CompoundColors.wet]);
    });

    testWidgets('one compound to a mixed set cross-fades', (tester) async {
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _soft, _soft, _soft])),
      );
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _soft, _wetSetup, _wetSetup])),
      );
      await tester.pump(AppDurations.medium ~/ 2);
      // Both on screen halfway.
      expect(_bands(tester), [CompoundColors.soft]);
      expect(_dots(tester), hasLength(4));
      await tester.pumpAndSettle();
      expect(_bands(tester), isEmpty);
    });

    testWidgets('between two mixed sets, each dot fades to its colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _soft, _medium, _medium])),
      );
      await tester.pumpWidget(
        _app(const CompoundBadges(marks: [_soft, _soft, _hard, _hard])),
      );
      await tester.pump(AppDurations.medium ~/ 2);
      final mid = _dots(tester)[2].$1;
      expect(mid, isNot(CompoundColors.medium));
      expect(mid, isNot(CompoundColors.hard));
      expect(_dots(tester)[0], (CompoundColors.soft, false));
      await tester.pumpAndSettle();
      expect(_dots(tester)[2], (CompoundColors.hard, false));
    });

    testWidgets('a used set wearing further is no change', (tester) async {
      await tester.pumpWidget(
        _app(CompoundBadge(mark: CompoundMark.ofSetup('90% Medium')!)),
      );
      await tester.pumpWidget(
        _app(CompoundBadge(mark: CompoundMark.ofSetup('80% Medium')!)),
      );
      await tester.pump();
      expect(_bands(tester), hasLength(1));
    });

    testWidgets('lands at once under reduced motion', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_app(const CompoundBadge(mark: _soft)));
      await tester.pumpWidget(_app(CompoundBadge(mark: _wet)));
      await tester.pump();
      expect(_bands(tester), [CompoundColors.wet]);
    });
  });
}
