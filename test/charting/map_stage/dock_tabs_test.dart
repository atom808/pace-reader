// The dock's tab bar in a strip too narrow for its glyphs (map stage P9e).

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _tabs = [
  TraceTab(id: 'a', label: 'Inputs', icon: Icons.tune),
  TraceTab(id: 'b', label: 'Tyres', icon: Icons.tire_repair),
  TraceTab(id: 'c', label: 'Brakes', icon: Icons.album),
  TraceTab(id: 'd', label: 'Suspension', icon: Icons.height),
  TraceTab(id: 'e', label: 'Dynamics', icon: Icons.open_with),
  TraceTab(id: 'f', label: 'Energy', icon: Icons.bolt),
];

Future<void> _pump(WidgetTester tester, TraceTab selected) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 150,
          child: DockTabs(tabs: _tabs, selected: selected, onSelected: (_) {}),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('scrolls rather than overflow, and keeps the selected tab in '
      'view', (tester) async {
    expect(DockTabs.scrollsAt(150, _tabs.length), isTrue);
    await _pump(tester, _tabs.first);
    await tester.pumpAndSettle();
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    // Picked from elsewhere, the last tab scrolls into the strip.
    await _pump(tester, _tabs.last);
    await tester.pumpAndSettle();
    final strip = tester.getRect(find.byType(SingleChildScrollView));
    final last = tester.getRect(find.byIcon(Icons.bolt));
    expect(last.left, greaterThanOrEqualTo(strip.left));
    expect(last.right, lessThanOrEqualTo(strip.right));
  });

  testWidgets('a strip wide enough for the glyphs does not scroll', (
    tester,
  ) async {
    expect(DockTabs.scrollsAt(6 * DockTabs.glyphWidth + 6, 6), isFalse);
  });
}
