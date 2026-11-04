// Links between screens (map stage proposal §6.4): a focus names a lap and a
// point on it in metres, and the screen it is sent to lands it once.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/features/driving_technique/application/technique_focus.dart';
import 'package:pace_reader/features/driving_technique/application/technique_providers.dart';
import 'package:pace_reader/features/lap_focus/lap_focus.dart';
import 'package:pace_reader/features/lap_focus/lap_focus_link.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/features/telemetry_trace/application/trace_focus.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');
const _other = TelemetrySource.path('/fixture/other.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

ProviderContainer _container() {
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
  return container;
}

Future<void> _pumpTrace(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
}

void main() {
  group('LapFocus', () {
    test('points at its station, else the middle of its window', () {
      expect(const LapFocus(source: _source, lap: 1, station: 40).point, 40);
      expect(
        const LapFocus(
          source: _source,
          lap: 1,
          window: (start: 100, end: 300),
        ).point,
        200,
      );
      expect(const LapFocus(source: _source, lap: 1).point, isNull);
    });

    test('a link names the lap the way the screens do, from 1', () {
      expect(
        LapFocusLink.labelFor(
          traceFocusTarget,
          const LapFocus(source: _source, lap: 4),
        ),
        'Lap 5 in Trace',
      );
      expect(LapFocusLink.labelFor(traceFocusTarget, null), 'Open in Trace');
    });
  });

  group('the pending focus', () {
    test('is taken once, by the screen and lap it names', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final pending = container.read(pendingLapFocusProvider.notifier);
      const focus = LapFocus(source: _source, lap: 3, station: 900);
      pending.hold('/trace', focus);

      expect(pending.take('/driving-technique', _source, 3), isNull);
      // Another lap is the screen still drawing the one before: it waits.
      expect(pending.take('/trace', _source, 2), isNull);
      expect(pending.take('/trace', _other, 3), isNull);
      expect(pending.take('/trace', _source, 3), focus);
      expect(pending.take('/trace', _source, 3), isNull);
    });
  });

  test('Technique selects the segment the focus points into', () {
    const segments = [
      Segment(number: 1, start: 0, end: 500),
      Segment(number: 2, start: 500, end: 1200),
    ];
    Segment? at(LapFocus f) => focusedSegment(segments, f);
    expect(
      at(const LapFocus(source: _source, lap: 1, station: 640))?.number,
      2,
    );
    expect(
      at(const LapFocus(source: _source, lap: 1, window: (start: 0, end: 400)))
          ?.number,
      1,
    );
    expect(at(const LapFocus(source: _source, lap: 1, station: 5000)), isNull);
    expect(at(const LapFocus(source: _source, lap: 1)), isNull);
  });

  group('Trace', () {
    testWidgets('a focus puts the car on its point and frames its stretch', (
      tester,
    ) async {
      final container = _container();
      container
          .read(pendingLapFocusProvider.notifier)
          .hold(
            traceFocusTarget.route,
            const LapFocus(
              source: _source,
              lap: sebringLapIndex,
              station: 1500,
            ),
          );
      await _pumpTrace(tester, container);

      final sync = container.read(chartSyncProvider);
      expect(sync.axis, TraceAxis.distance);
      expect(sync.playhead, 1500);
      expect(sync.viewport!.start, closeTo(1500 - pointFrameMetres / 2, 1e-6));
      expect(sync.viewport!.end, closeTo(1500 + pointFrameMetres / 2, 1e-6));
      expect(container.read(pendingLapFocusProvider), isNull);
    });

    testWidgets('a segment is framed whole, the car at its start', (
      tester,
    ) async {
      final container = _container();
      container
          .read(pendingLapFocusProvider.notifier)
          .hold(
            traceFocusTarget.route,
            const LapFocus(
              source: _source,
              lap: sebringLapIndex,
              window: (start: 2000, end: 2600),
            ),
          );
      await _pumpTrace(tester, container);

      final sync = container.read(chartSyncProvider);
      expect(sync.playhead, 2000);
      expect(sync.viewport, const ChartViewport(2000, 2600));
    });

    testWidgets('a focus for another lap is left for that lap', (tester) async {
      final container = _container();
      container
          .read(pendingLapFocusProvider.notifier)
          .hold(
            traceFocusTarget.route,
            const LapFocus(source: _source, lap: 7, station: 1500),
          );
      await _pumpTrace(tester, container);

      expect(container.read(chartSyncProvider).playhead, isNull);
      expect(container.read(pendingLapFocusProvider), isNotNull);
    });

    testWidgets('the Inputs tab opens Technique at the playhead', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container);
      container.read(chartSyncProvider.notifier).setPlayhead(2300);
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(LapFocusLink),
          matching: find.text('Technique'),
        ),
      );
      await tester.pump();

      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, techniqueFocusTarget.route);
      expect(pending.focus.lap, sebringLapIndex);
      expect(pending.focus.station, 2300);
      expect(
        container.read(techniqueSelectionStateProvider(_source)).lapIndex,
        sebringLapIndex,
      );
    });

    testWidgets('Ctrl+Enter does the same from the keyboard', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container);
      container.read(chartSyncProvider.notifier).setPlayhead(800);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, '/driving-technique');
      expect(pending.focus.station, 800);
    });
  });

  testWidgets('a focus on a file behind the current one makes it current', (
    tester,
  ) async {
    final container = _container();
    late WidgetRef captured;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final context = tester.element(find.byType(SizedBox));
    openFocus(
      context,
      captured,
      traceFocusTarget,
      const LapFocus(source: _other, lap: 2),
    );
    expect(container.read(currentSessionProvider), _other);
    expect(container.read(selectedLapIndexProvider(_other)), 2);
  });
}
