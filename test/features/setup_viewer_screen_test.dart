// The Setup Viewer screen (SPEC.md §8.10), driven the way a person drives it,
// on the real `CarSetup` JSON of the three samples — no DuckDB behind it, the
// provider is overridden with `CarSetup.parse(sample.json)`.
//
// `setup_viewer_test.dart` holds the parse to what the files say; this holds
// the page to the parse: that a chip reaches a section thousands of pixels
// down, that a search leaves the counts saying so, that the four corners sit
// FL FR over RL RR, that a blank or broken setup is stated rather than drawn
// as an empty page.

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup.dart';
import 'package:pace_reader/features/setup_viewer/presentation/gear_panel.dart';
import 'package:pace_reader/features/setup_viewer/presentation/setting_widgets.dart';
import 'package:pace_reader/features/setup_viewer/presentation/setup_section_card.dart';
import 'package:pace_reader/features/setup_viewer/presentation/setup_toolbar.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../design_system/portal_semantics.dart';
import '../fixtures/car_setup_samples.dart';
import '../fixtures/setup_viewer_harness.dart';

Finder _section(SetupSectionId id) =>
    find.byWidgetPredicate((w) => w is SetupSectionCard && w.section.id == id);

/// The title in a section's own header (the chip above it reads the same).
Finder _header(SetupSectionId id) =>
    find.descendant(of: _section(id), matching: find.text(id.title));

/// The toolbar's chip for a section, found by its short label.
Finder _chip(String label) => find.widgetWithText(InkWell, label).first;

/// Where a section card's top should land after a chip jump: under the app
/// bar and the pinned toolbar, with its 4 px gap.
const _belowToolbar = kToolbarHeight + setupToolbarExtent;

/// Scrolls to the foot of the page, where the footer is. It is its own sliver,
/// so it is not built until it is near the viewport.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
  await tester.pumpAndSettle();
}

void main() {
  // Real fonts, not the test host's em-square placeholder: several assertions
  // here are about widths (a chip row that must fit, a pill that must not
  // overflow) and would otherwise measure a font the app never draws with.
  setUpAll(loadAppFonts);

  group('header and counts', () {
    testWidgets('a fixed-setup race says what the session locks', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: sebringCarSetup);

      expect(find.text('The Bend Team WRT 2025 #31:BRZ · GT3'), findsOneWidget);
      expect(find.text('Symmetric'), findsOneWidget);
      expect(find.text('27 of 170 adjustable in this session'), findsOneWidget);
      expect(find.textContaining('recorded change'), findsNothing);

      // 54 of the Race file's 170 read N/A; hidden by default and counted.
      expect(find.text('116 of 170'), findsOneWidget);
      expect(find.text('Show N/A · 54'), findsOneWidget);
      expect(find.text('Adjustable only · 27'), findsOneWidget);
    });

    testWidgets('the four headline figures are read from the setup', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: sebringCarSetup);
      Finder tile(String text) =>
          find.descendant(of: find.byType(StatTile), matching: find.text(text));

      expect(tile('Brake bias'), findsOneWidget);
      expect(tile('51.2:48.8'), findsOneWidget);
      expect(tile('3.3 deg'), findsOneWidget);
      expect(tile('Medium'), findsOneWidget);
      expect(tile('6'), findsOneWidget);
    });

    testWidgets('a qualifying file shows its five recorded changes', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);

      expect(find.text('5 with a recorded change'), findsOneWidget);
      // Virtual energy moved -74 steps; it is on screen as the number.
      expect(find.text('Δ −74'), findsWidgets);
    });

    testWidgets('a practice file invents no change and no lock', (
      tester,
    ) async {
      // Where the game counted nothing and locked nothing, the page draws no
      // mark and no chip: it does not state a fact the file lacks.
      await pumpSetupViewer(tester, sample: interlagosCarSetup);
      expect(find.textContaining('recorded change'), findsNothing);
      expect(find.textContaining('adjustable in this session'), findsNothing);
      expect(find.textContaining('Adjustable only'), findsNothing);
      expect(find.text('112 of 170'), findsOneWidget);
    });

    testWidgets('sections come out in setup-sheet order, one chip each', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);

      final ids = tester
          .widgetList<SetupSectionCard>(find.byType(SetupSectionCard))
          .map((c) => c.section.id)
          .toList();
      // The page is one column of every section, so all of them are laid out.
      expect(ids, [
        SetupSectionId.aero,
        SetupSectionId.brakes,
        SetupSectionId.suspension,
        SetupSectionId.alignment,
        SetupSectionId.tyres,
        SetupSectionId.differential,
        SetupSectionId.gearing,
        SetupSectionId.electronics,
        SetupSectionId.engine,
      ]);
      for (final id in ids) {
        expect(_chip(id.shortTitle), findsOneWidget);
      }
    });

    testWidgets('a file without session metadata still renders', (
      tester,
    ) async {
      await pumpSetupViewer(
        tester,
        sample: interlagosCarSetup,
        withMetadata: false,
      );
      expect(find.text('Symmetric'), findsOneWidget);
      expect(find.byType(SetupSectionCard), findsWidgets);
    });
  });

  group('navigation', () {
    testWidgets('a chip scrolls to a section far below and lights up', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSetupViewer(tester, sample: spaCarSetup);
      // Gearing is beyond six taller sections: a lazy list would not have
      // built it, and the chip would have done nothing.
      expect(
        tester.getTopLeft(_section(SetupSectionId.gearing)).dy,
        greaterThan(1500),
      );

      await tester.tap(_chip('Gearing'));
      await tester.pumpAndSettle();

      final top = tester.getTopLeft(_section(SetupSectionId.gearing)).dy;
      expect(top, closeTo(_belowToolbar + 4, 2));
      expect(find.text('Shift diagram'), findsOneWidget);

      final chip = tester.getSemantics(
        find.bySemanticsLabel(RegExp(r'^Gearing, 12 settings$')).first,
      );
      expect(chip.flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('and back to the top again', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.tap(_chip('Engine'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Aero'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(_section(SetupSectionId.aero)).dy,
        closeTo(_belowToolbar + 4, 2),
      );
    });

    testWidgets('reduced motion jumps instead of gliding', (tester) async {
      await pumpSetupViewer(
        tester,
        sample: spaCarSetup,
        disableAnimations: true,
      );
      await tester.tap(_chip('Gearing'));
      // Two frames: the tap's, then the post-frame scroll.
      await tester.pump();
      await tester.pump();
      expect(
        tester.getTopLeft(_section(SetupSectionId.gearing)).dy,
        closeTo(_belowToolbar + 4, 2),
      );
    });

    testWidgets('a chip opens a section the reader had folded', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.tap(_header(SetupSectionId.aero));
      await tester.pumpAndSettle();
      expect(find.text('Front wing'), findsNothing);

      await tester.tap(_chip('Aero'));
      await tester.pumpAndSettle();
      expect(find.text('Front wing'), findsOneWidget);
    });

    testWidgets('folding and unfolding a section', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      expect(find.text('Front wing'), findsOneWidget);

      await tester.tap(_header(SetupSectionId.aero));
      await tester.pumpAndSettle();
      expect(find.text('Front wing'), findsNothing, reason: 'folded');
      // Folding changes nothing about what is counted.
      expect(find.text('132 of 170'), findsOneWidget);

      await tester.tap(_header(SetupSectionId.aero));
      await tester.pumpAndSettle();
      expect(find.text('Front wing'), findsOneWidget, reason: 'unfolded');
    });

    testWidgets('folding animates: mid-fold the rows are still leaving', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.tap(_header(SetupSectionId.aero));
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.text('Front wing'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Front wing'), findsNothing);
    });

    testWidgets('reduced motion folds in a single frame', (tester) async {
      await pumpSetupViewer(
        tester,
        sample: spaCarSetup,
        disableAnimations: true,
      );
      await tester.tap(_header(SetupSectionId.aero));
      await tester.pump();
      expect(find.text('Front wing'), findsNothing);
    });

    for (final width in [1000.0, 1440.0]) {
      testWidgets('every section chip fits inside the bar at $width px', (
        tester,
      ) async {
        await pumpSetupViewer(
          tester,
          sample: spaCarSetup,
          size: Size(width, 900),
        );
        final bar = tester.getRect(find.byType(SetupToolbar));
        final last = tester.getRect(_chip('Engine'));
        expect(last.right, lessThanOrEqualTo(bar.right - 24));
      });
    }
  });

  group('search', () {
    testWidgets('narrows every section at once and says how much', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.enterText(find.byType(TextField), 'camber');
      await tester.pumpAndSettle();

      expect(find.text('4 of 170'), findsOneWidget);
      expect(find.byType(SetupSectionCard), findsOneWidget);
      expect(_section(SetupSectionId.alignment), findsOneWidget);
      expect(find.textContaining('settings matching “camber”'), findsOneWidget);
    });

    testWidgets('the four corners sit FL FR over RL RR', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.enterText(find.byType(TextField), 'camber');
      await tester.pumpAndSettle();

      Offset corner(String code) => tester.getTopLeft(
        find.descendant(
          of: find.byType(WheelGroupCard),
          matching: find.text(code),
        ),
      );
      final fl = corner('FL');
      final fr = corner('FR');
      final rl = corner('RL');
      final rr = corner('RR');
      expect(fl.dy, fr.dy);
      expect(rl.dy, rr.dy);
      expect(fr.dx, greaterThan(fl.dx));
      expect(rr.dx, greaterThan(rl.dx));
      expect(rl.dx, fl.dx);
      expect(rl.dy, greaterThan(fl.dy));

      // Spa: -1.0 deg up front, -0.8 deg at the rear — the JSON's own digits.
      expect(find.text('-1.0 deg'), findsNWidgets(2));
      expect(find.text('-0.8 deg'), findsNWidgets(2));
    });

    testWidgets('the clear button and Esc both bring everything back', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.enterText(find.byType(TextField), 'camber');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('132 of 170'), findsOneWidget);
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'camber');
      await tester.pumpAndSettle();
      expect(find.text('4 of 170'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('132 of 170'), findsOneWidget);
    });

    testWidgets('a search opens the sections it found, even a folded one', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.tap(_header(SetupSectionId.alignment));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'camber');
      await tester.pumpAndSettle();
      expect(find.byType(WheelGroupCard), findsOneWidget);
    });

    testWidgets('no match is stated, with a way out', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No setting matches “zzzz”'), findsOneWidget);
      expect(find.text('0 of 170'), findsOneWidget);
      expect(find.byType(SetupSectionCard), findsNothing);

      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('132 of 170'), findsOneWidget);
      expect(find.byType(SetupSectionCard), findsWidgets);
    });

    testWidgets('a match that reads N/A says so and can be shown', (
      tester,
    ) async {
      // A six-speed has no 9th gear slot: present in the JSON, N/A in the game.
      await pumpSetupViewer(tester, sample: interlagosCarSetup);
      await tester.enterText(find.byType(TextField), 'VM_GEAR_9');
      await tester.pumpAndSettle();

      expect(
        find.text(
          '1 setting matches but reads N/A on this car, so it is hidden.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Show N/A settings'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 170'), findsOneWidget);
      expect(find.text('Gear 9 ratio'), findsOneWidget);
    });

    testWidgets('Ctrl+F puts the cursor in the search box', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      final field = find.byType(EditableText);
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    });
  });

  group('filters', () {
    testWidgets('Show N/A brings all 170 back, and hides them again', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: interlagosCarSetup);
      expect(find.text('112 of 170'), findsOneWidget);
      await _scrollToEnd(tester);
      expect(
        find.text('58 settings the game marks N/A are hidden.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Show N/A · 58'));
      await tester.pumpAndSettle();
      expect(find.text('170 of 170'), findsOneWidget);
      await _scrollToEnd(tester);
      expect(find.textContaining('the game marks N/A'), findsNothing);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 20000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show N/A · 58'));
      await tester.pumpAndSettle();
      expect(find.text('112 of 170'), findsOneWidget);
    });

    testWidgets('Adjustable only keeps what a fixed race leaves free', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: sebringCarSetup);
      await tester.tap(find.text('Adjustable only · 27'));
      await tester.pumpAndSettle();

      // 27 are free; 5 of those read N/A (hidden by default), so 22 show.
      expect(find.text('22 of 170'), findsOneWidget);
      expect(_section(SetupSectionId.suspension), findsNothing);
      await _scrollToEnd(tester);
      expect(
        find.text('94 settings locked by this session are hidden.'),
        findsOneWidget,
      );

      // Two notes end the page — N/A hidden, then locked hidden — each with
      // its own way back; this is the second.
      expect(find.text('Show them'), findsNWidgets(2));
      await tester.tap(find.text('Show them').last);
      await tester.pumpAndSettle();
      expect(find.text('116 of 170'), findsOneWidget);
      expect(_section(SetupSectionId.suspension), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('a row reads as one label, and every tooltip on the page has '
        'a node of its own', (tester) async {
      // The rows used to exclude their children to read as one label, which
      // took every tooltip's anchor with them: opening the key, the step or
      // the adjustable mark then broke the Windows accessibility tree (see
      // AppTooltip).
      final handle = tester.ensureSemantics();
      await pumpSetupViewer(tester, sample: sebringCarSetup);
      expect(find.bySemanticsLabel(RegExp(r'^Brake bias, \S')), findsOneWidget);
      expect(orphanablePortalAnchors(tester), isEmpty);

      final label = find.descendant(
        of: find.byType(SettingRow),
        matching: find.text('Brake bias'),
      );
      await tester.ensureVisible(label);
      await tester.pumpAndSettle();
      await tester.longPress(label);
      await tester.pumpAndSettle();
      expect(find.text('VM_BRAKE_BALANCE'), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isEmpty);
      handle.dispose();
    });
  });

  group('the shift diagram', () {
    testWidgets('one row per forward gear, from the setup\'s gearGraph', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup);
      await tester.tap(_chip('Gearing'));
      await tester.pumpAndSettle();

      final panel = find.byType(GearPanel);
      expect(panel, findsOneWidget);
      Finder cell(String text) =>
          find.descendant(of: panel, matching: find.text(text));

      // Spa's seven gears: the first two top speeds and the rev limit.
      expect(cell('119.6'), findsOneWidget);
      expect(cell('154.7'), findsOneWidget);
      expect(cell('323.4'), findsOneWidget);
      expect(cell('8,500'), findsNWidgets(7));
      // Gear 1 drops to 6,568 rpm on the upshift; the top gear has no upshift,
      // and says so with a dash rather than a zero.
      expect(cell('6,568'), findsOneWidget);
      expect(cell('1,932'), findsOneWidget);
      expect(cell('—'), findsNWidgets(2));
    });

    testWidgets('the six-speed has six rows, not seven', (tester) async {
      await pumpSetupViewer(tester, sample: interlagosCarSetup);
      await tester.tap(_chip('Gearing'));
      await tester.pumpAndSettle();
      final panel = find.byType(GearPanel);
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('7')),
        findsNothing,
      );
      expect(
        find.descendant(of: panel, matching: find.text('6')),
        findsWidgets,
      );
    });
  });

  group('empty, loading and broken', () {
    testWidgets('no CarSetup in the file is stated, not a blank page', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup, json: '');
      expect(find.text('No car setup in this recording'), findsOneWidget);
      expect(find.byType(SetupSectionCard), findsNothing);
    });

    testWidgets('text that is not a JSON object says what it is', (
      tester,
    ) async {
      await pumpSetupViewer(tester, sample: spaCarSetup, json: '[1, 2]');
      expect(find.text('The car setup could not be read'), findsOneWidget);
      expect(find.textContaining('rather than an object'), findsOneWidget);
    });

    testWidgets('an error from the load is shown, with its message', (
      tester,
    ) async {
      await pumpSetupViewer(
        tester,
        sample: spaCarSetup,
        loadError: const SetupFormatException('the file would not open'),
      );
      expect(find.text('The car setup could not be read'), findsOneWidget);
      expect(find.text('the file would not open'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton of the page', (tester) async {
      await pumpSetupViewer(tester, sample: spaCarSetup, settle: false);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(SetupSectionCard), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(SetupSectionCard), findsWidgets);
    });
  });
}
