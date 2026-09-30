// The per-lap trend chart's construction (SPEC.md §9.5, §8.6): what goes on
// the line, what is a band, what is greyed, and which scale it is drawn on.
//
// The values are the Sebring Race's front-left carcass (lap means and lowest–
// highest readings, °C) for the garage lap, three racing laps and the lap the
// recording cut off.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_trend_chart.dart';

const _points = [
  PerLapTrendPoint(
    lapNumber: 1,
    value: 80.7,
    low: 79.9,
    high: 81.6,
    muted: true,
    note: 'out lap',
  ),
  PerLapTrendPoint(lapNumber: 2, value: 85.1, low: 83.7, high: 86.2),
  PerLapTrendPoint(lapNumber: 3, value: 88.4, low: 86.0, high: 89.5),
  PerLapTrendPoint(lapNumber: 4, value: 90.8, low: 89.1, high: 92.3),
  PerLapTrendPoint(
    lapNumber: 5,
    value: 91.2,
    low: 90.4,
    high: 92.0,
    muted: true,
    note: 'incomplete',
  ),
];

Future<LineChartData> _pump(
  WidgetTester tester,
  List<PerLapTrendPoint> points, {
  double? minY,
  double? maxY,
  int? highlightLap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: const MediaQueryData(),
        child: Scaffold(
          body: SizedBox(
            width: 600,
            child: PerLapTrendChart(
              points: points,
              color: AppColors.channelTyre,
              formatValue: (v) => '${v.toStringAsFixed(1)} °C',
              minY: minY,
              maxY: maxY,
              highlightLap: highlightLap,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<LineChart>(find.byType(LineChart)).data;
}

void main() {
  testWidgets('the line joins racing laps only; muted laps break it', (
    tester,
  ) async {
    final data = await _pump(tester, _points);
    final mean = data.lineBarsData.first.spots;
    expect(mean, hasLength(5));
    expect(mean[0].isNull(), isTrue, reason: 'the garage lap is not the trend');
    expect([for (final s in mean.sublist(1, 4)) s.y], [85.1, 88.4, 90.8]);
    expect(mean[4].isNull(), isTrue, reason: 'nor is the cut-off lap');
  });

  testWidgets('a run of racing laps gets one band; a muted lap a whisker', (
    tester,
  ) async {
    final data = await _pump(tester, _points);
    // One fill between two invisible edge lines for laps 2–4.
    expect(data.betweenBarsData, hasLength(1));
    final band = data.betweenBarsData.single;
    final low = data.lineBarsData[band.fromIndex].spots;
    final high = data.lineBarsData[band.toIndex].spots;
    expect([for (final s in low) s.y], [83.7, 86.0, 89.1]);
    expect([for (final s in high) s.y], [86.2, 89.5, 92.3]);
    // The band is faint: it frames the line and never competes with it.
    expect(band.color!.a, lessThan(0.25));
    // Each muted lap: a two-point whisker from low to high, plus its own dot.
    final whiskers = data.lineBarsData
        .where((b) => b.spots.length == 2 && b.spots.first.x == b.spots.last.x)
        .toList();
    expect(whiskers.map((b) => b.spots.first.x), containsAll([0.0, 4.0]));
  });

  testWidgets('one lap alone is a whisker, not a zero-width band', (
    tester,
  ) async {
    final data = await _pump(tester, [_points[0], _points[2], _points[4]]);
    expect(data.betweenBarsData, isEmpty);
    final racing = data.lineBarsData.where(
      (b) => b.spots.length == 2 && b.spots.first.y == 86.0,
    );
    expect(racing, hasLength(1));
  });

  testWidgets('a shared scale is honoured and padded, not refitted', (
    tester,
  ) async {
    final own = await _pump(tester, _points);
    final shared = await _pump(tester, _points, minY: 60, maxY: 100);
    // Its own range hugs the data …
    expect(own.minY, greaterThan(70));
    expect(own.maxY, lessThan(100));
    // … a shared one holds the data range it is given, plus headroom, so
    // four corners drawn on it can be compared.
    expect(shared.minY, lessThanOrEqualTo(60));
    expect(shared.maxY, greaterThanOrEqualTo(100));
    // And it is not anchored at zero: a temperature is not an amount.
    expect(shared.minY, greaterThan(40));
  });

  testWidgets('a flat series still gets a scale', (tester) async {
    final data = await _pump(tester, [
      for (var i = 1; i <= 4; i++)
        PerLapTrendPoint(lapNumber: i, value: 136, low: 136, high: 136),
    ]);
    expect(data.maxY - data.minY, greaterThan(1));
  });

  testWidgets('a lap with no data keeps its slot', (tester) async {
    final data = await _pump(tester, [
      _points[1],
      const PerLapTrendPoint(lapNumber: 3, value: null),
      _points[3],
    ]);
    expect(data.maxX - data.minX, 3);
    final mean = data.lineBarsData.first.spots;
    expect(mean.map((s) => s.isNull()), [false, true, false]);
  });

  testWidgets('the highlighted lap is marked by a rule at its slot', (
    tester,
  ) async {
    final data = await _pump(tester, _points, highlightLap: 4);
    expect(data.extraLinesData.verticalLines, hasLength(1));
    expect(data.extraLinesData.verticalLines.single.x, 3);
    final none = await _pump(tester, _points);
    expect(none.extraLinesData.verticalLines, isEmpty);
  });

  testWidgets('an empty series draws without throwing', (tester) async {
    await _pump(tester, const []);
    expect(tester.takeException(), isNull);
  });
}
