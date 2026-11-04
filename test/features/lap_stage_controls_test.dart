// The lap stage's controls (map stage proposal §5.1, §6.4, §7.4, P4): its
// keys, the way back from a detail screen, the one-time offer of
// Performance mode, and a narrow window.
//
// On the real Sebring lap (`test/fixtures/sebring_lap1.dart`).

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_focus/lap_focus.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/settings/application/app_settings.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/application/stage_view.dart';
import 'package:pace_reader/features/telemetry_trace/application/trace_focus.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/lap_stage.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');
const _stutter = 'Playback is stuttering. Turn on Performance mode?';

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 1000),
  PendingLapFocus? pending,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final container = ProviderContainer(
    overrides: [
      openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
      lapsProvider(_source).overrideWith((ref) async => [sebringLap()]),
      lapTelemetryProvider(
        _source,
        sebringLapIndex,
      ).overrideWith((ref) async => sebringLapTelemetry()),
    ],
  );
  addTearDown(container.dispose);
  if (pending != null) {
    container
        .read(pendingLapFocusProvider.notifier)
        .hold(pending.route, pending.focus);
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const TelemetryTraceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

LapChart _chart(WidgetTester tester) =>
    tester.widget<LapStage>(find.byType(LapStage)).chart;

double? _playhead(ProviderContainer c) => c.read(chartSyncProvider).playhead;

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? holding,
}) async {
  if (holding != null) await tester.sendKeyDownEvent(holding);
  await tester.sendKeyEvent(key);
  if (holding != null) await tester.sendKeyUpEvent(holding);
  await tester.pump();
}

String _caption(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(MapMinimap), matching: find.byType(Text)),
    )
    .map((t) => t.data)
    .firstWhere(
      (d) => const {
        'Whole lap',
        'Free',
        'Following the car',
        'Trace window',
      }.contains(d),
    )!;

void main() {
  group('the keys', () {
    testWidgets('← and → nudge the playhead 1 % of the window and pause', (
      tester,
    ) async {
      final container = await _pump(tester);
      final bounds = _chart(tester).bounds;

      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(
        _playhead(container),
        closeTo(bounds.start + bounds.span / 100, 1e-6),
      );
      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        _playhead(container),
        closeTo(bounds.start + bounds.span / 100, 1e-6),
      );

      await _key(tester, LogicalKeyboardKey.space);
      expect(container.read(playbackProvider).playing, isTrue);
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(
        container.read(playbackProvider).playing,
        isFalse,
        reason: 'a key is a choice of where to look',
      );
    });

    testWidgets('Shift+→ and Shift+← step between the timing lines', (
      tester,
    ) async {
      final container = await _pump(tester);
      final chart = _chart(tester);
      final marks = [
        for (final (at, _) in chart.traceMarkers)
          if (at > chart.bounds.start && at < chart.bounds.end) at,
      ]..sort();
      expect(marks, isNotEmpty, reason: 'Sebring has sector lines');

      await _key(
        tester,
        LogicalKeyboardKey.arrowRight,
        holding: LogicalKeyboardKey.shiftLeft,
      );
      expect(_playhead(container), marks.first);
      await _key(
        tester,
        LogicalKeyboardKey.arrowLeft,
        holding: LogicalKeyboardKey.shiftLeft,
      );
      expect(_playhead(container), chart.bounds.start);
    });

    testWidgets('Home and End go to the ends of the window', (tester) async {
      final container = await _pump(tester);
      container
          .read(chartSyncProvider.notifier)
          .showWindow(
            const ChartViewport(1000, 2000),
            bounds: _chart(tester).bounds,
          );
      await tester.pump();
      await _key(tester, LogicalKeyboardKey.end);
      expect(_playhead(container), 2000);
      await _key(tester, LogicalKeyboardKey.home);
      expect(_playhead(container), 1000);
    });

    testWidgets('[ and ] step the playback rate', (tester) async {
      final container = await _pump(tester);
      await _key(tester, LogicalKeyboardKey.bracketRight);
      expect(container.read(playbackProvider).rate, 2);
      await _key(tester, LogicalKeyboardKey.bracketLeft);
      await _key(tester, LogicalKeyboardKey.bracketLeft);
      expect(container.read(playbackProvider).rate, 0.5);
    });

    testWidgets('1, 2, 3 and Ctrl+Tab choose the dock tab', (tester) async {
      final container = await _pump(tester);
      final tabs = shownTraceTab(
        _chart(tester),
        container.read(traceTabProvider),
      ).tabs;
      String shown() => shownTraceTab(
        _chart(tester),
        container.read(traceTabProvider),
      ).shown.id;

      await _key(
        tester,
        LogicalKeyboardKey.tab,
        holding: LogicalKeyboardKey.controlLeft,
      );
      expect(shown(), tabs[1 % tabs.length].id);
      await _key(tester, LogicalKeyboardKey.digit1);
      expect(shown(), tabs.first.id);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(shown(), tabs.last.id, reason: 'round from the first to the last');
    });

    testWidgets('F fits, Esc follows, and + and - zoom the map', (
      tester,
    ) async {
      final container = await _pump(tester);
      container.read(chartSyncProvider.notifier).setPlayhead(1500);
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Following the car');

      await _key(tester, LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Whole lap');

      await _key(tester, LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_caption(tester), 'Following the car');

      double zoom() => tester
          .widget<Slider>(
            find.descendant(
              of: find.byType(MapMinimap),
              matching: find.byType(Slider),
            ),
          )
          .value;
      final before = zoom();
      await _key(tester, LogicalKeyboardKey.equal);
      await tester.pumpAndSettle();
      expect(zoom(), greaterThan(before));
      await _key(tester, LogicalKeyboardKey.minus);
      await _key(tester, LogicalKeyboardKey.minus);
      await tester.pumpAndSettle();
      expect(zoom(), lessThan(before));
    });
  });

  group('the way back', () {
    testWidgets('a step aside to a detail screen carries the spot', (
      tester,
    ) async {
      final container = await _pump(tester);
      container.read(chartSyncProvider.notifier)
        ..showWindow(
          const ChartViewport(600, 1200),
          bounds: _chart(tester).bounds,
        )
        ..setPlayhead(800);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final back = container.read(pendingLapFocusProvider)!.focus.back!;
      expect(back.target, traceFocusTarget);
      expect(back.label, 'Trace · 800 m');
      expect(back.focus.station, 800);
      expect(back.focus.window!.start, closeTo(600, 1e-6));
      expect(back.focus.window!.end, closeTo(1200, 1e-6));
      expect(back.focus.back, isNull, reason: 'one step, not a chain');
    });

    LapFocusReturn returnTo(double station) => LapFocusReturn(
      target: traceFocusTarget,
      focus: LapFocus(source: _source, lap: sebringLapIndex, station: station),
      label: 'Trace · ${station.round()} m',
    );

    PendingLapFocus arriving(LapFocusReturn back) => PendingLapFocus(
      traceFocusTarget.route,
      LapFocus(source: _source, lap: sebringLapIndex, station: 900, back: back),
      DateTime.now(),
    );

    testWidgets('the destination offers it, and taking it goes back', (
      tester,
    ) async {
      final back = returnTo(1500);
      final container = await _pump(tester, pending: arriving(back));
      expect(find.text('Back to Trace · 1500 m'), findsOneWidget);

      await tester.tap(find.text('Back to Trace · 1500 m'));
      await tester.pumpAndSettle();
      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, traceFocusTarget.route);
      expect(pending.focus, back.focus);
      expect(find.text('Back to Trace · 1500 m'), findsNothing);
    });

    testWidgets('closing it leaves the user where they are', (tester) async {
      final container = await _pump(tester, pending: arriving(returnTo(1500)));
      final playhead = _playhead(container);
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNotice),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassNotice), findsNothing);
      expect(_playhead(container), playhead);
    });
  });

  group('the offer of Performance mode', () {
    testWidgets('frames are watched only while playing with effects on', (
      tester,
    ) async {
      final container = await _pump(tester);
      bool watching() =>
          tester.widget<StutterWatch>(find.byType(StutterWatch)).active;
      expect(watching(), isFalse);

      await _key(tester, LogicalKeyboardKey.space);
      expect(watching(), isTrue);

      container.read(appSettingsProvider.notifier).setPerformanceMode(true);
      await tester.pump();
      expect(watching(), isFalse, reason: 'nothing left to offer');
      await _key(tester, LogicalKeyboardKey.space);
    });

    testWidgets('appears once, and Turn on turns it on', (tester) async {
      final container = await _pump(tester);
      container.read(stutterOfferProvider.notifier).stuttered();
      await tester.pumpAndSettle();
      expect(find.text(_stutter), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).performanceMode, isTrue);
      expect(find.text(_stutter), findsNothing);

      container.read(stutterOfferProvider.notifier).stuttered();
      await tester.pumpAndSettle();
      expect(find.text(_stutter), findsNothing, reason: 'once per run');
    });

    testWidgets('dismissed, it stays away and changes nothing', (tester) async {
      final container = await _pump(tester);
      container.read(stutterOfferProvider.notifier).stuttered();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(GlassNotice),
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(_stutter), findsNothing);
      expect(container.read(appSettingsProvider).performanceMode, isFalse);
      expect(container.read(stutterOfferProvider), StutterOffer.settled);
    });
  });

  group('a narrow window', () {
    for (final width in [420.0, 600.0]) {
      testWidgets('at $width px everything fits', (tester) async {
        // An overflow anywhere fails the test on its own.
        await _pump(tester, size: Size(width, 800));
        expect(find.byType(MapStage), findsOneWidget);
        expect(find.text('Open in Compare'), findsNothing);
        expect(find.byIcon(Icons.straighten), findsOneWidget);
        expect(find.text('Distance'), findsNothing);
      });
    }

    testWidgets('a wide one keeps the words', (tester) async {
      await _pump(tester);
      expect(find.text('Open in Compare'), findsOneWidget);
      expect(find.text('Distance'), findsOneWidget);
    });
  });
}
