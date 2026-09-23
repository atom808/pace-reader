// Comparing a lap against a reference lap (SPEC.md §8.3, §8.4).
//
// Fed by the two real Sebring fixture laps — lap 2 (index 1, 1:04.497) and
// lap 4 (index 3, 1:04.030) — so the delta these tests read is one the game's
// own lap times can confirm.

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/features/track_map/presentation/track_map_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

/// Lap 2 on display. Left to its default the view would open on the session's
/// best lap, which is the other one.
class _Displayed extends SelectedLapIndex {
  @override
  int? build(TelemetrySource source) => sebringLapIndex;
}

class _Reference extends ReferenceLapIndex {
  _Reference(this.index);

  final int index;

  @override
  int? build(TelemetrySource source) => index;
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  int? reference,
  LapTelemetry? referenceTelemetry,
  Widget screen = const TelemetryTraceScreen(),
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source)
            .overrideWith((ref) async => [sebringLap(), sebringLap3()]),
        selectedLapIndexProvider(_source).overrideWith(() => _Displayed()),
        if (reference != null)
          referenceLapIndexProvider(_source)
              .overrideWith(() => _Reference(reference)),
        lapTelemetryProvider(_source, sebringLapIndex)
            .overrideWith((ref) async => sebringLapTelemetry()),
        lapTelemetryProvider(_source, sebringLap3Index).overrideWith(
            (ref) async => referenceTelemetry ?? sebringLap3Telemetry()),
      ],
      child: MaterialApp(theme: AppTheme.dark(), home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byWidget(screen)));
}

List<TracePanel> _panels(WidgetTester tester) =>
    tester.widgetList<TracePanel>(find.byType(TracePanel)).toList();

/// The reference lap with its `Lap Dist` reversed — the shape the garage lap
/// has, where lap distance runs backwards while the car is in the pits.
LapTelemetry _withoutDistanceAxis(LapTelemetry lap) => LapTelemetry(
      lap: lap.lap,
      startSeconds: lap.startSeconds,
      endSeconds: lap.endSeconds,
      channels: lap.channels,
      gear: lap.gear,
      lapDistance: TraceSeries(
        channelName: 'Lap Dist',
        unit: 'm',
        frequencyHz: 5,
        valueColumn: 'value',
        times: lap.lapDistance!.times,
        lows: Float64List.fromList(lap.lapDistance!.lows.reversed.toList()),
        highs: Float64List.fromList(lap.lapDistance!.highs.reversed.toList()),
      ),
      latitude: lap.latitude,
      longitude: lap.longitude,
      sectorBoundaries: lap.sectorBoundaries,
    );

void main() {
  testWidgets('without a reference the stack is the single-lap one',
      (tester) async {
    await _pump(tester);
    expect(find.text('No reference'), findsOneWidget);
    expect(find.text('Delta'), findsNothing);
    expect(_panels(tester).any((p) => p.series.hasReference), isFalse);
  });

  testWidgets('the picker marks the best lap and never offers the one shown',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('No reference'));
    await tester.pumpAndSettle();

    // A lap compared with itself is a flat line that looks like a result, so
    // lap 2 — on display — is not offered.
    expect(find.text('vs Lap 4'), findsOneWidget);
    expect(find.text('vs Lap 2'), findsNothing);
    expect(find.text('best'), findsOneWidget);
  });

  testWidgets('choosing a reference puts a delta panel on top of the stack',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('No reference'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vs Lap 4').last);
    await tester.pumpAndSettle();

    final panels = _panels(tester);
    // First, as in both reference apps: the delta is the summary the channel
    // panels below it explain.
    expect(panels.first.title, 'Delta');
    expect(panels.first.series, isA<DeltaSeriesPanel>());
    expect(panels, hasLength(7));
  });

  testWidgets('every channel panel carries the reference lap', (tester) async {
    await _pump(tester, reference: sebringLap3Index);
    final channels =
        _panels(tester).where((p) => p.series is! DeltaSeriesPanel).toList();
    expect(channels, hasLength(6));
    for (final panel in channels) {
      expect(panel.series.hasReference, isTrue, reason: panel.title);
    }
  });

  testWidgets('the delta ends at the difference the game timed',
      (tester) async {
    // 64.497 s against 64.030 s. The 5 Hz fixture stops the comparison ~17 m
    // short of the line, which measured 0.009 s short of the difference.
    await _pump(tester, reference: sebringLap3Index);
    final delta = _panels(tester).first.series as DeltaSeriesPanel;
    expect(
      delta.plot.lows.last,
      closeTo(sebringLapTimeSeconds - sebringLap3TimeSeconds, 0.03),
    );
  });

  testWidgets('the summary states the lap-time difference, signed',
      (tester) async {
    await _pump(tester, reference: sebringLap3Index);
    // Twice each: the picker names the reference by its time, and the summary
    // bar states it again beside the difference.
    expect(find.text('1:04.030'), findsNWidgets(2));
    // The game's own lap times rather than the end of the trace, so the
    // headline is exact.
    expect(find.text('+0.468'), findsOneWidget);
    // The delta is derived, not a channel the file holds.
    expect(find.text('6 channels'), findsOneWidget);
  });

  testWidgets('hovering reads the reference beside the lap\'s own value',
      (tester) async {
    await _pump(tester, reference: sebringLap3Index);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    final speed = _panels(tester).firstWhere((p) => p.title == 'Speed');
    final box = tester.getRect(find.byWidget(speed));
    await gesture.moveTo(Offset(box.left + box.width * 0.5, box.bottom - 20));
    await tester.pumpAndSettle();

    // Six channel panels with two readouts each, and the delta with one.
    final readouts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textAlign == TextAlign.right && (t.data ?? '').isNotEmpty)
        .length;
    expect(readouts, 13);
  });

  testWidgets(
      'a reference with no usable distance axis is compared by time and says '
      'so', (tester) async {
    await _pump(
      tester,
      reference: sebringLap3Index,
      referenceTelemetry: _withoutDistanceAxis(sebringLap3Telemetry()),
    );
    // On the distance axis it cannot be placed at all, and there is no delta.
    expect(find.text('Delta'), findsNothing);
    expect(_panels(tester).any((p) => p.series.hasReference), isFalse);
    expect(
      find.textContaining('Lap 4 has no usable distance axis'),
      findsOneWidget,
    );

    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();

    // By time it can: both laps start at their own line crossing.
    expect(find.text('Delta'), findsNothing);
    expect(_panels(tester).every((p) => p.series.hasReference), isTrue);
    expect(find.textContaining('compared by time only'), findsOneWidget);
  });

  testWidgets('stepping onto the reference lap drops the comparison, and '
      'stepping off restores it', (tester) async {
    final container = await _pump(tester, reference: sebringLap3Index);
    expect(find.text('Delta'), findsOneWidget);

    container
        .read(selectedLapIndexProvider(_source).notifier)
        .select(sebringLap3Index);
    await tester.pumpAndSettle();
    expect(find.text('Delta'), findsNothing);
    expect(find.text('No reference'), findsOneWidget);

    container
        .read(selectedLapIndexProvider(_source).notifier)
        .select(sebringLapIndex);
    await tester.pumpAndSettle();
    expect(find.text('Delta'), findsOneWidget);
  });

  testWidgets('the track map\'s trace strip shows the same comparison',
      (tester) async {
    // One synced system (§9.5): the map screen must not show a lap
    // uncompared while the trace view compares it.
    await _pump(
      tester,
      reference: sebringLap3Index,
      screen: const TrackMapScreen(),
    );
    expect(find.text('Delta'), findsOneWidget);
    expect(find.text('+0.468'), findsOneWidget);
  });
}
