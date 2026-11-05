// The peaks a trace marks for clicking (map stage P9b).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

TracePlot _plot(List<double> values) {
  final ys = Float64List.fromList(values);
  return TracePlot(
    label: 'x',
    unit: '',
    xs: Float64List.fromList([for (var i = 0; i < values.length; i++) i * 1.0]),
    lows: ys,
    highs: ys,
    valueRange: ValueRange.ofAll(values)!,
  );
}

/// A base of 100 with bumps of [heights] at [at], each 20 samples wide, on
/// 1,000 samples with a little noise.
List<double> _bumps(List<int> at, List<double> heights, {double sign = 1}) => [
  for (var i = 0; i < 1000; i++)
    100 +
        0.3 * math.sin(i * 1.7) +
        sign *
            [
              for (var k = 0; k < at.length; k++)
                heights[k] * math.max(0, 1 - (i - at[k]).abs() / 10),
            ].fold(0.0, (a, b) => a + b),
];

void main() {
  test('the highs, most prominent first, returned along the lap', () {
    final peaks = findPeaks(
      _plot(_bumps([100, 300, 500, 700, 900], [40, 10, 60, 20, 30])),
      kind: PeakKind.highs,
      count: 3,
    );
    expect(peaks.map((p) => p.at), [100, 500, 900]);
    expect(peaks[1].value, closeTo(160, 0.5));
  });

  test('a ride height\'s lows', () {
    final peaks = findPeaks(
      _plot(_bumps([250, 750], [30, 50], sign: -1)),
      kind: PeakKind.lows,
    );
    expect(peaks.map((p) => p.at), [250, 750]);
    expect(peaks[1].value, closeTo(50, 0.5));
  });

  test('noise and a flat trace have none', () {
    expect(
      findPeaks(
        _plot(_bumps(const [], const [])),
        kind: PeakKind.highs,
        minRise: 2,
      ),
      isEmpty,
    );
    expect(
      findPeaks(_plot(List.filled(100, 5.0)), kind: PeakKind.highs),
      isEmpty,
    );
  });

  test('a ragged top close together is one peak', () {
    final peaks = findPeaks(
      _plot(_bumps([400, 415], [50, 48])),
      kind: PeakKind.highs,
    );
    expect(peaks, hasLength(1));
    expect(peaks.single.at, 400);
  });

  group('on a panel', () {
    final plot = _plot(_bumps([300, 700], [40, 60]));
    final peaks = findPeaks(plot, kind: PeakKind.highs);

    Future<ProviderContainer> pump(WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1000, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 1000,
                  height: 200,
                  child: TracePanel(
                    key: const ValueKey('panel'),
                    series: LineSeries(plot),
                    bounds: const ChartViewport(0, 999),
                    color: Colors.orange,
                    title: 'Brake temp',
                    peaks: peaks,
                    formatValue: (v) => v.toStringAsFixed(0),
                    formatDomain: (d) => '$d',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    PeakPainter painterOf(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byWidgetPredicate(
                    (w) => w is CustomPaint && w.painter is PeakPainter,
                  ),
                )
                .painter!
            as PeakPainter;

    /// Where [peak]'s mark is on screen.
    Offset markOf(WidgetTester tester, TracePeak peak) {
      final rect = tester.getRect(find.byKey(const ValueKey('panel')));
      final geometry = painterOf(tester).geometry;
      return rect.topLeft + Offset(geometry.x(peak.at), geometry.y(peak.value));
    }

    testWidgets('each peak is marked, below the chip', (tester) async {
      await pump(tester);
      expect(peaks, hasLength(2));
      expect(painterOf(tester).peaks, peaks);
      final top = tester.getRect(find.byKey(const ValueKey('panel'))).top;
      for (final peak in peaks) {
        expect(markOf(tester, peak).dy - top, greaterThanOrEqualTo(32));
      }
    });

    testWidgets('a click near a peak puts the playhead exactly on it', (
      tester,
    ) async {
      final container = await pump(tester);
      final peak = peaks.last;
      await tester.tapAt(markOf(tester, peak) + const Offset(6, 4));
      await tester.pumpAndSettle();
      expect(container.read(chartSyncProvider).playhead, peak.at);
    });

    testWidgets('a click away from them places it where it lands', (
      tester,
    ) async {
      final container = await pump(tester);
      await tester.tapAt(markOf(tester, peaks.last) + const Offset(-200, 60));
      await tester.pumpAndSettle();
      final playhead = container.read(chartSyncProvider).playhead!;
      expect(playhead, isNot(peaks.last.at));
      expect(playhead, closeTo(peaks.last.at - 200 / 1000 * 999, 2));
    });
  });
}
