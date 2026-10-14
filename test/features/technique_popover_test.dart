// The ⓘ popovers on the Technique cards (SPEC.md §8.13.7). The cards are not
// semantics nodes of their own, so several share one; each popover still has
// to open under a node of its own, or the Windows accessibility bridge
// rejects the update that shows it (see AppTooltip).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/features/driving_technique/presentation/technique_widgets.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../design_system/portal_semantics.dart';

void main() {
  testWidgets('two ⓘ popovers in one node each open under their own', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Center(
            child: Semantics(
              container: true,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoPopoverButton(
                    title: 'Full throttle',
                    paragraphs: ['Pedal flat out.'],
                  ),
                  InfoPopoverButton(
                    title: 'Braking',
                    paragraphs: ['Brake pedal pressed.'],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(orphanablePortalAnchors(tester), isEmpty);

    for (final (index, text) in const [
      (0, 'Pedal flat out.'),
      (1, 'Brake pedal pressed.'),
    ]) {
      await tester.tap(find.byIcon(Icons.info_outline).at(index));
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      expect(unlistedSemanticsNodes(tester), isEmpty, reason: text);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
    handle.dispose();
  });
}
