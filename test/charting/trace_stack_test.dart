// Panels that share the dock's height (map stage P9a), and the scale a
// zoomed panel fits to.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _padding = EdgeInsets.all(10);

Future<void> _pump(WidgetTester tester, Widget child, {double height = 600}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 600, height: height, child: child),
        ),
      ),
    ),
  );
}

Widget _box(String key) => SizedBox.expand(key: ValueKey(key));

double _height(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).height;

TracePlot _plot(List<double> values) {
  final xs = Float64List.fromList([
    for (var i = 0; i < values.length; i++) i * 10.0,
  ]);
  final ys = Float64List.fromList(values);
  return TracePlot(
    label: 'x',
    unit: '',
    xs: xs,
    lows: ys,
    highs: ys,
    valueRange: ValueRange.ofAll(values)!,
  );
}

void main() {
  group('TraceStack', () {
    testWidgets('panels share the height they are given, by weight', (
      tester,
    ) async {
      await _pump(
        tester,
        TraceStack(
          padding: _padding,
          gap: 8,
          rows: [
            TraceStackRow.panels(_box('a')),
            TraceStackRow.panels(_box('b'), weight: 2),
          ],
        ),
      );
      // 600 less the padding and one gap, in thirds.
      expect(_height(tester, 'a'), closeTo((600 - 20 - 8) / 3, 0.01));
      expect(_height(tester, 'b'), closeTo((600 - 20 - 8) * 2 / 3, 0.01));
    });

    testWidgets('a row at its own height keeps it; the panels share the rest', (
      tester,
    ) async {
      await _pump(
        tester,
        TraceStack(
          padding: _padding,
          gap: 8,
          maxPanel: 1000,
          rows: [
            const TraceStackRow.fixed(SizedBox(key: ValueKey('f'), height: 30)),
            TraceStackRow.panels(_box('a')),
          ],
        ),
      );
      expect(_height(tester, 'f'), 30);
      expect(_height(tester, 'a'), closeTo(600 - 20 - 8 - 30, 0.01));
    });

    testWidgets('too short a dock scrolls instead of squashing the panels', (
      tester,
    ) async {
      await _pump(
        tester,
        TraceStack(
          padding: _padding,
          minPanel: 100,
          rows: [
            for (final k in ['a', 'b', 'c', 'd']) TraceStackRow.panels(_box(k)),
          ],
        ),
        height: 300,
      );
      expect(_height(tester, 'a'), closeTo(100, 0.01));
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tall dock stops growing panels at their tallest', (
      tester,
    ) async {
      await _pump(
        tester,
        TraceStack(
          padding: _padding,
          maxPanel: 150,
          rows: [TraceStackRow.panels(_box('a'))],
        ),
      );
      expect(_height(tester, 'a'), closeTo(150, 0.01));
    });

    test('a grid of corners takes two rows, or four when narrow', () {
      const row = TraceStackRow.corners(SizedBox(), perCell: 2);
      expect(row.weightAt(CornerGrid.twoColumnsWidth), 4);
      expect(row.weightAt(CornerGrid.twoColumnsWidth - 1), 8);
      expect(const TraceStackRow.fixed(SizedBox()).weightAt(500), 0);
      expect(row.withChild(const SizedBox()).weightAt(500), 4);
    });
  });

  group('the scale a zoomed panel fits', () {
    test('the trace inside the window, counting the samples at its edges', () {
      final plot = _plot([0, 5, 50, 7, 3, 100]);
      final range = plot.rangeIn(const ChartViewport(10, 40))!;
      expect(range.min, 3);
      expect(range.max, 50);
    });

    test('a window that barely moves keeps a tenth of the lap\'s span', () {
      const full = ValueRange(0, 100);
      final shown = shownRange(full, const ValueRange(41, 42));
      expect(shown.span, closeTo(10, 1e-9));
      expect((shown.min + shown.max) / 2, closeTo(41.5, 1e-9));
      expect(
        shownRange(full, const ValueRange(20, 60)),
        const ValueRange(20, 60),
      );
      expect(shownRange(full, null), full);
    });

    testWidgets('a panel with no height in a plain list takes its default', (
      tester,
    ) async {
      final plot = _plot([0, 1, 2, 3]);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: ListView(
                children: [
                  TracePanel(
                    key: const ValueKey('p'),
                    series: LineSeries(plot),
                    bounds: const ChartViewport(0, 30),
                    color: Colors.blue,
                    title: 'Speed',
                    formatValue: (v) => '$v',
                    formatDomain: (d) => '$d',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(_height(tester, 'p'), TracePanel.defaultHeight);
      // The title sits in a chip over the trace, not in a row above it.
      final title = tester.getRect(find.text('Speed'));
      final panel = tester.getRect(find.byKey(const ValueKey('p')));
      expect(title.top, greaterThan(panel.top));
    });
  });
}
