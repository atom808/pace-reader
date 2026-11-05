// The overlays laid over a panel's line (driver-aids proposal §2): an aid's
// episodes named at the cursor, the overlay layers on a panel, and the
// switch for each kept between runs.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/features/settings/application/app_settings.dart';
import 'package:pace_reader/features/telemetry_trace/application/aid_overlays.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

TracePlot _plot(List<double> values) {
  final ys = Float64List.fromList(values);
  return TracePlot(
    label: 'x',
    unit: '%',
    xs: Float64List.fromList([for (var i = 0; i < values.length; i++) i * 1.0]),
    lows: ys,
    highs: ys,
    valueRange: ValueRange.ofAll(values)!,
  );
}

PulseOverlay _tc() => PulseOverlay(
  label: 'TC',
  pulses: Float64List.fromList([10.5, 11.5, 12.5, 40.5]),
  episodeStarts: Float64List.fromList([10, 40]),
  episodeEnds: Float64List.fromList([13, 41]),
);

void main() {
  group('PulseOverlay', () {
    test('is active inside an episode, its ends included', () {
      final tc = _tc();
      expect(tc.activeAt(10), isTrue);
      expect(tc.activeAt(12), isTrue);
      expect(tc.activeAt(13), isTrue);
      expect(tc.activeAt(40.5), isTrue);
      expect(tc.activeAt(9.9), isFalse);
      expect(tc.activeAt(20), isFalse);
      expect(tc.activeAt(50), isFalse);
    });

    test('names the aids acting at a point, in order', () {
      final abs = PulseOverlay(
        label: 'ABS',
        pulses: Float64List(0),
        episodeStarts: Float64List.fromList([11]),
        episodeEnds: Float64List.fromList([12]),
      );
      final cut = CutOverlay(_plot(List.filled(100, 50)));
      expect(activeAidLabels([cut, _tc(), abs], 11.5), ['TC', 'ABS']);
      expect(activeAidLabels([cut, _tc(), abs], 30), isEmpty);
    });
  });

  group('on a panel', () {
    // A pedal held at 100 and an engine throttle cut to 40 from 10 to 13.
    final pedal = _plot(List.filled(100, 100));
    final engine = _plot([
      for (var i = 0; i < 100; i++) i >= 10 && i <= 13 ? 40.0 : 100.0,
    ]);
    final cut = CutOverlay(engine);
    final tc = _tc();

    Future<void> pump(WidgetTester tester, List<TraceOverlay> overlays) async {
      await tester.binding.setSurfaceSize(const Size(1000, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 1000,
                height: 200,
                child: TracePanel(
                  series: LineSeries(pedal),
                  bounds: const ChartViewport(0, 99),
                  color: Colors.green,
                  title: 'Throttle',
                  overlays: overlays,
                  formatValue: (v) => v.toStringAsFixed(0),
                  formatDomain: (d) => '$d',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Iterable<TraceOverlayPainter> painters(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is TraceOverlayPainter,
          ),
        )
        .map((w) => w.painter! as TraceOverlayPainter);

    testWidgets('each overlay gets a layer of its own', (tester) async {
      await pump(tester, [cut, tc]);
      expect(painters(tester).map((p) => p.overlay), [cut, tc]);
      // The painter draws without throwing, cut and dots alike.
      expect(tester.takeException(), isNull);
    });

    testWidgets('none, no layer', (tester) async {
      await pump(tester, const []);
      expect(painters(tester), isEmpty);
    });

    testWidgets('the chip names TC while the cursor is in an episode', (
      tester,
    ) async {
      await pump(tester, [cut, tc]);
      expect(find.text('TC'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TracePanel)),
      );
      container.read(chartSyncProvider.notifier).setPlayhead(11);
      await tester.pumpAndSettle();
      expect(find.text('TC'), findsOneWidget);
      container.read(chartSyncProvider.notifier).setPlayhead(30);
      await tester.pumpAndSettle();
      expect(find.text('TC'), findsNothing);
    });

    testWidgets('a cursor move does not repaint the layers', (tester) async {
      await pump(tester, [cut, tc]);
      final before = painters(tester).toList();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TracePanel)),
      );
      container.read(chartSyncProvider.notifier).setProbe(50);
      await tester.pump();
      final after = painters(tester).toList();
      for (var i = 0; i < before.length; i++) {
        expect(after[i].shouldRepaint(before[i]), isFalse);
      }
    });
  });

  group('the switches', () {
    test('every overlay starts on, and a hidden one is remembered', () async {
      final store = MemoryAppSettingsStore();
      final container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      expect(container.read(shownTraceAidsProvider), TraceAid.values.toSet());

      container
          .read(appSettingsProvider.notifier)
          .setTraceOverlay(TraceAid.cut.id, shown: false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(shownTraceAidsProvider), {TraceAid.tc});
      expect((await store.read())!['hiddenTraceOverlays'], ['cut']);

      final reread = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(reread.dispose);
      reread.read(appSettingsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(reread.read(shownTraceAidsProvider), {TraceAid.tc});
    });
  });
}
