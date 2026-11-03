import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

/// The wheel over a trace: a bare scroll moves the page, Ctrl zooms the
/// trace and Shift pans it — and a claimed wheel never also moves the page.
void main() {
  const bounds = ChartViewport(0, 1000);
  final xs = Float64List.fromList([for (var i = 0; i <= 100; i++) i * 10.0]);
  final plot = TracePlot(
    label: 'Speed',
    unit: 'km/h',
    xs: xs,
    lows: Float64List.fromList(xs),
    highs: Float64List.fromList(xs),
    valueRange: const ValueRange(0, 1000),
  );

  late ProviderContainer container;
  late ScrollController scroll;

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.binding.setSurfaceSize(const Size(800, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                for (var i = 0; i < 6; i++)
                  TracePanel(
                    key: ValueKey(i),
                    series: LineSeries(plot),
                    bounds: bounds,
                    color: Colors.blue,
                    title: 'Speed $i',
                    formatValue: (v) => '$v',
                    formatDomain: (d) => '$d',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> wheel(WidgetTester tester, Offset delta) async {
    final at = tester.getCenter(find.byKey(const ValueKey(0)));
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(at));
    await tester.sendEventToBinding(pointer.scroll(delta));
    await tester.pump();
  }

  ChartViewport visible() => container.read(chartSyncProvider).visible(bounds);

  testWidgets('a bare wheel scrolls the page and leaves the trace', (
    tester,
  ) async {
    await pump(tester);
    await wheel(tester, const Offset(0, 100));
    expect(scroll.offset, greaterThan(0));
    expect(visible(), bounds);
  });

  testWidgets('Ctrl + wheel zooms the trace and not the page', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await wheel(tester, const Offset(0, -100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(scroll.offset, 0);
    expect(visible().span, lessThan(bounds.span));
  });

  testWidgets('Shift + wheel pans a zoomed trace and not the page', (
    tester,
  ) async {
    await pump(tester);
    container
        .read(chartSyncProvider.notifier)
        .zoomAround(500, 0.5, bounds: bounds);
    final before = visible();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await wheel(tester, const Offset(0, 100));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(scroll.offset, 0);
    expect(visible().start, greaterThan(before.start));
    expect(visible().span, closeTo(before.span, 1e-6));
  });
}
