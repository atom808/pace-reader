// AppTooltip: a tooltip whose overlay always has a node to hang under, so
// showing it never sends the Windows accessibility bridge an update it
// rejects (see app_tooltip.dart).
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import 'portal_semantics.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

/// One semantics node holding two tooltips — a library row with a PB badge
/// and a clock gap, in miniature.
Widget _row(Widget Function(String message, String text) tip) => _app(
  Semantics(
    container: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tip('first message', 'first'),
        const SizedBox(width: 40),
        tip('second message', 'second'),
      ],
    ),
  ),
);

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _hover(WidgetTester tester, TestGesture mouse, Finder at) async {
  await mouse.moveTo(tester.getCenter(at));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'two bare tooltips in one node: the second loses its anchor, and showing '
    'it sends a node nothing lists',
    (tester) async {
      // The framework behaviour AppTooltip exists for. If this starts failing
      // after a Flutter upgrade, the bug is fixed upstream and the wrapper
      // can be reconsidered.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _row((message, text) => Tooltip(message: message, child: Text(text))),
      );
      expect(orphanablePortalAnchors(tester), hasLength(1));
      final mouse = await _mouse(tester);

      await _hover(tester, mouse, find.text('second'));
      expect(find.text('second message'), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isNotEmpty);
      handle.dispose();
    },
  );

  testWidgets('AppTooltips in one node each keep their own', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _row((message, text) => AppTooltip(message: message, child: Text(text))),
    );
    expect(orphanablePortalAnchors(tester), isEmpty);
    final mouse = await _mouse(tester);

    for (final text in ['first', 'second']) {
      await _hover(tester, mouse, find.text(text));
      expect(find.text('$text message'), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isEmpty, reason: text);
    }
    handle.dispose();
  });

  testWidgets('every message reaches a screen reader, on its anchor', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _row((message, text) => AppTooltip(message: message, child: Text(text))),
    );
    // Merged into one node, the second message was dropped with the anchor.
    expect(
      tester.getSemantics(find.text('second')),
      matchesSemantics(label: 'second', tooltip: 'second message'),
    );
    expect(
      tester.getSemantics(find.text('first')),
      matchesSemantics(label: 'first', tooltip: 'first message'),
    );
    handle.dispose();
  });

  testWidgets('excluded from semantics, it still gives the overlay a node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _row(
        (message, text) => AppTooltip(
          message: message,
          excludeFromSemantics: true,
          child: Text(text),
        ),
      ),
    );
    expect(orphanablePortalAnchors(tester), isEmpty);
    final mouse = await _mouse(tester);
    await _hover(tester, mouse, find.text('second'));
    expect(unlistedSemanticsNodes(tester), isEmpty);
    expect(
      tester.getSemantics(find.text('second')).getSemanticsData().tooltip,
      isEmpty,
    );
    handle.dispose();
  });
}
