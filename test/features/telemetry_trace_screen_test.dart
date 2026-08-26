// Widget tests for the synced trace view (SPEC.md §8.4, §12).
//
// Fed by `test/fixtures/sebring_lap1.dart` — the real Sebring Race lap 1,
// resampled — so these assert against telemetry the game actually recorded
// rather than a curve invented to make the test pass.

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 1000),
  List<Lap>? laps,
  LapTelemetry? telemetry,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final lapList = laps ?? [sebringLap()];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source).overrideWith((ref) async => lapList),
        lapTelemetryProvider(_source, sebringLapIndex)
            .overrideWith((ref) async => telemetry ?? sebringLapTelemetry()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const TelemetryTraceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A mouse the test can move around; returned so one test can hover a panel
/// and then move away without adding a second pointer.
Future<TestGesture> _mouse(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer();
  addTearDown(gesture.removePointer);
  return gesture;
}

/// Hovers the first trace panel at [fraction] across its width.
Future<void> _hoverPanel(
  WidgetTester tester,
  TestGesture gesture,
  double fraction,
) async {
  final panel = tester.widgetList<TracePanel>(find.byType(TracePanel)).first;
  final box = tester.getRect(find.byWidget(panel));
  await gesture.moveTo(Offset(
    box.left + box.width * fraction,
    // Below the header row, inside the plot itself.
    box.bottom - 20,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('stacks one panel per channel, never overlaying them',
      (tester) async {
    // One channel per panel is the whole reason for the stack: overlaying
    // signals with unrelated units on one pair of axes invents crossings the
    // data does not contain.
    await _pump(tester);
    for (final title in ['Speed', 'Throttle', 'Brake', 'Steering',
      'Engine RPM', 'Gear']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.byType(TracePanel), findsNWidgets(6));
  });

  testWidgets('labels each panel with the unit the file reports',
      (tester) async {
    await _pump(tester);
    expect(find.text('km/h'), findsOneWidget);
    expect(find.text('RPM'), findsOneWidget);
    expect(find.text('%'), findsNWidgets(3));
  });

  testWidgets('names the lap it is showing, with its real time', (tester) async {
    await _pump(tester);
    // The real Sebring Race lap 1, and its sectors derived from the
    // cumulative splits (§8.3.1) rather than read raw.
    // Twice: once in the lap picker, once in the summary bar. Never "Lap 1"
    // — the raw index is 0-based and must be shown +1 (§5.2).
    expect(find.text('Lap 2'), findsNWidgets(2));
    expect(find.text('Lap 1'), findsNothing);
    // Also twice, for the same reason: the picker names the lap by its time.
    expect(find.text('1:04.497'), findsNWidgets(2));
    expect(find.text('23.347'), findsOneWidget);
    expect(find.text('12.914'), findsOneWidget);
    expect(find.text('28.237'), findsOneWidget);
  });

  testWidgets('defaults to the distance axis and reports the lap length',
      (tester) async {
    await _pump(tester);
    expect(find.text('Distance'), findsOneWidget);
    // The lap's own distance span, from the fixture's first sample to its
    // last: 3066 m of Sebring School Circuit, roughly half the full course —
    // which is exactly why §8.1 treats TrackLayout as load-bearing.
    expect(find.text('3066 m'), findsOneWidget);
  });

  testWidgets('switching to the time axis re-labels the footer', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Distance ·'), findsOneWidget);

    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Time ·'), findsOneWidget);
    // The recorded span of the lap, in seconds, replaces its length.
    expect(find.text('64.5 s'), findsOneWidget);
  });

  testWidgets('hovering one panel reads every channel at that point',
      (tester) async {
    // The behaviour §9.5 built a custom chart core for: a cursor in one panel
    // is a cursor in all of them, and on the track map beside them.
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TelemetryTraceScreen)),
    );
    expect(container.read(chartSyncProvider).cursor, isNull);

    await _hoverPanel(tester, await _mouse(tester), 0.5);

    final cursor = container.read(chartSyncProvider).cursor;
    expect(cursor, isNotNull);
    // Mid-panel on the distance axis is mid-lap by distance.
    expect(cursor, closeTo(1540, 200));

    // Each panel's header now carries its own value at that point, so six
    // readouts appear where there were none.
    final readouts = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.textAlign == TextAlign.right && (t.data ?? '').isNotEmpty)
        .length;
    expect(readouts, 6);
  });

  testWidgets('the cursor leaves when the pointer does', (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TelemetryTraceScreen)),
    );
    final gesture = await _mouse(tester);
    await _hoverPanel(tester, gesture, 0.4);
    expect(container.read(chartSyncProvider).cursor, isNotNull);

    await gesture.moveTo(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(container.read(chartSyncProvider).cursor, isNull);
  });

  testWidgets('shows the track map beside the panels on a wide window',
      (tester) async {
    // §9.7 asks for multi-pane desktop layouts specifically so trace and map
    // can be read together — a shared cursor only reads as shared when both
    // things it drives are on screen.
    await _pump(tester);
    expect(find.byType(TrackMapView), findsOneWidget);
  });

  testWidgets('drops the map pane rather than squeezing the panels',
      (tester) async {
    await _pump(tester, size: const Size(900, 900));
    expect(find.byType(TrackMapView), findsNothing);
    expect(find.byType(TracePanel), findsNWidgets(6));
  });

  testWidgets('offers the distance axis only where the lap has one',
      (tester) async {
    // The garage lap: `Lap Dist` runs backwards while the car manoeuvres in
    // the pits, so a distance axis there would fold the trace over itself.
    final telemetry = sebringLapTelemetry();
    final scrambled = LapTelemetry(
      lap: telemetry.lap,
      startSeconds: telemetry.startSeconds,
      endSeconds: telemetry.endSeconds,
      channels: telemetry.channels,
      gear: telemetry.gear,
      lapDistance: TraceSeries(
        channelName: 'Lap Dist',
        unit: 'm',
        frequencyHz: 5,
        valueColumn: 'value',
        times: telemetry.lapDistance!.times,
        // Reversed, so it runs strictly backwards.
        lows: _reversed(telemetry.lapDistance!.lows),
        highs: _reversed(telemetry.lapDistance!.highs),
      ),
      latitude: telemetry.latitude,
      longitude: telemetry.longitude,
      sectorBoundaries: telemetry.sectorBoundaries,
    );

    await _pump(tester, telemetry: scrambled);

    // The control still exists — a missing toggle would leave the user
    // wondering where it went — but says why it cannot be used.
    expect(find.textContaining('Time ·'), findsOneWidget);
    expect(
      find.byTooltip(
        'This lap has no usable distance axis — lap distance runs backwards '
        'while the car manoeuvres in the pits.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a session with no laps says so instead of rendering empty axes',
      (tester) async {
    await _pump(tester, laps: const []);
    expect(find.text('This session recorded no laps to trace.'), findsOneWidget);
  });
}

Float64List _reversed(Float64List values) =>
    Float64List.fromList(values.reversed.toList());
