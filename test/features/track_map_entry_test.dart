// Widget tests for the Track map entry: the lap stage with its traces folded
// away (SPEC.md §8.5, map stage proposal §9).
//
// Same real lap as the trace tests, so the two views are checked against one
// recording — which is the point of them sharing a view model at all.

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
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Size size = const Size(1400, 900),
  LapTelemetry? telemetry,
  bool collapsed = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source).overrideWith((ref) async => [sebringLap()]),
        lapTelemetryProvider(
          _source,
          sebringLapIndex,
        ).overrideWith((ref) async => telemetry ?? sebringLapTelemetry()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: TelemetryTraceScreen(dockCollapsed: collapsed),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(TelemetryTraceScreen)),
  );
}

TrackPath _path(WidgetTester tester) =>
    tester.widgetList<MapStage>(find.byType(MapStage)).first.path;

void main() {
  testWidgets('draws the circuit from the recording position channels', (
    tester,
  ) async {
    await _pump(tester);
    final path = _path(tester);

    // The real Sebring School Circuit: 3.08 km, and closed — a lap comes back
    // to the start/finish line.
    expect(path.length, greaterThan(100));
    expect(path.projection.pathLengthMetres, closeTo(3040, 60));
    final start = path.projection.points.first;
    final end = path.projection.points.last;
    expect(
      (end - start).distance,
      lessThan(30),
      reason: 'a lap must close on the start/finish line',
    );
  });

  testWidgets('projects without stretching the circuit east-west', (
    tester,
  ) async {
    // The failure the cosine-of-latitude factor prevents: at this recording's
    // latitude, omitting it would report the lap as ~5.2 km rather than
    // ~3.04 km, and every corner would be the wrong shape.
    await _pump(tester);
    final bounds = _path(tester).projection.boundsMetres;
    expect(bounds.width, closeTo(1130, 60));
    expect(bounds.height, closeTo(570, 40));
  });

  testWidgets('marks the start/finish line and both sector boundaries', (
    tester,
  ) async {
    await _pump(tester);
    final markers = tester
        .widgetList<MapStage>(find.byType(MapStage))
        .first
        .markers;
    expect(markers.map((m) => m.$2), ['S/F', 'S2', 'S3']);
    // Each lands on a real point of the path rather than at index 0 by
    // default, which is what a failed lookup would look like.
    for (final (index, label) in markers.skip(1)) {
      expect(index, greaterThan(0), reason: label);
      expect(index, lessThan(_path(tester).length));
    }
  });

  testWidgets('colours the lap by speed and scales the legend to it', (
    tester,
  ) async {
    await _pump(tester);
    final path = _path(tester);
    expect(path.valueLabel, 'Speed');
    expect(path.valueUnit, 'km/h');
    // The colouring scale is the channel's own extent over the lap, not the
    // extent of the sampled points — a lap's true peak can fall between two
    // position samples.
    expect(path.valueRange.max, closeTo(250, 15));
    expect(path.valueRange.min, lessThan(80));
  });

  testWidgets('recolours by brake when asked', (tester) async {
    // §8.5 names speed, throttle and brake as the colouring choices.
    final container = await _pump(tester);
    // Through the HUD's Colour by menu; 'Brake' also names a live chip, so
    // the menu's own item is the last one on screen once it is open.
    await tester.tap(find.byKey(const ValueKey('colour-by')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brake').last);
    await tester.pumpAndSettle();

    expect(container.read(trackMapChannelProvider), 'Brake Pos');
    final path = _path(tester);
    expect(path.valueLabel, 'Brake');
    expect(path.valueUnit, '%');
    expect(path.valueRange.max, closeTo(100, 1));
  });

  testWidgets('a trace panel probes the map on hover and places the car on a '
      'click', (tester) async {
    // The behaviour §9.5 built the shared controller for: the map answers
    // "where", the traces answer "what the car was doing there". Hover only
    // reads; the car moves when asked to (map stage proposal §5).
    final container = await _pump(tester, collapsed: false);
    expect(find.byType(TracePanel), findsWidgets);

    final panel = tester.widgetList<TracePanel>(find.byType(TracePanel)).first;
    final box = tester.getRect(find.byWidget(panel));
    final at = Offset(box.left + box.width * 0.5, box.bottom - 12);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(at);
    await tester.pumpAndSettle();

    final probe = container.read(chartSyncProvider).probe;
    expect(probe, isNotNull);
    expect(container.read(chartSyncProvider).playhead, isNull);
    final index = _path(tester).nearestIndex(probe!);
    expect(index, greaterThan(0));
    expect(index, lessThan(_path(tester).length - 1));

    await gesture.down(at);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(chartSyncProvider).playhead, closeTo(probe, 1e-9));
  });

  testWidgets('a lap with no position shows its traces alone', (tester) async {
    final source = sebringLapTelemetry();
    final blind = LapTelemetry(
      lap: source.lap,
      startSeconds: source.startSeconds,
      endSeconds: source.endSeconds,
      channels: source.channels,
      gear: source.gear,
      lapDistance: source.lapDistance,
      latitude: null,
      longitude: null,
      sectorBoundaries: source.sectorBoundaries,
    );
    await _pump(tester, telemetry: blind);

    // No position, no map: the traces alone, rather than an empty stage.
    expect(find.byType(MapStage), findsNothing);
    expect(find.byType(TracePanel), findsWidgets);
  });

  testWidgets('opens on the map alone, the traces folded away', (tester) async {
    await _pump(tester, size: const Size(900, 800));
    expect(find.byType(MapStage), findsOneWidget);
    expect(find.byType(TracePanel), findsNothing);
  });

  testWidgets('mismatched position arrays are treated as no position at all', (
    tester,
  ) async {
    // Latitude and longitude are paired by index because both are 10 Hz on
    // the same master grid (§5.1). If that ever stops holding, pairing them
    // anyway would draw a plausible-looking wrong circuit.
    final source = sebringLapTelemetry();
    final truncated = LapTelemetry(
      lap: source.lap,
      startSeconds: source.startSeconds,
      endSeconds: source.endSeconds,
      channels: source.channels,
      gear: source.gear,
      lapDistance: source.lapDistance,
      latitude: source.latitude,
      longitude: TraceSeries(
        channelName: 'GPS Longitude',
        unit: 'deg',
        frequencyHz: sebringLapSampleHz,
        valueColumn: 'value',
        times: Float64List.sublistView(source.longitude!.times, 0, 10),
        lows: Float64List.sublistView(source.longitude!.lows, 0, 10),
        highs: Float64List.sublistView(source.longitude!.highs, 0, 10),
      ),
      sectorBoundaries: source.sectorBoundaries,
    );
    await _pump(tester, telemetry: truncated);
    // No position, no map: the traces alone, rather than an empty stage.
    expect(find.byType(MapStage), findsNothing);
    expect(find.byType(TracePanel), findsWidgets);
  });
}
