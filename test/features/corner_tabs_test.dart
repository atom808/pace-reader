// The Tyres and Brakes dock tabs (map stage proposal §6.1, P3), and their
// links to Tires & Brakes and back (§6.4).

import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/channels.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_corner_telemetry.dart';
import 'package:pace_reader/data/repositories/lap_surface.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_focus/lap_focus.dart';
import 'package:pace_reader/features/lap_focus/lap_focus_link.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/application/corner_chart.dart';
import 'package:pace_reader/features/telemetry_trace/application/stage_view.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_selection.dart';
import 'package:pace_reader/features/tires_brakes/application/tires_brakes_focus.dart';
import 'package:pace_reader/features/tires_brakes/presentation/corner_card.dart';
import 'package:pace_reader/features/tires_brakes/presentation/tires_brakes_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../charting/map_stage/stage_fixture.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/tyre_reports.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

/// The Sebring lap, from a file that carries [fileChannels].
LapTelemetry _lap({Set<String> fileChannels = const {}}) {
  final t = sebringLapTelemetry();
  return LapTelemetry(
    lap: t.lap,
    startSeconds: t.startSeconds,
    endSeconds: t.endSeconds,
    channels: t.channels,
    gear: t.gear,
    lapDistance: t.lapDistance,
    latitude: t.latitude,
    longitude: t.longitude,
    pathLateral: t.pathLateral,
    trackEdge: t.trackEdge,
    sectorBoundaries: t.sectorBoundaries,
    fileChannels: fileChannels,
  );
}

/// [channel] holding [value] plus the corner's index all lap — FL 0, FR 1,
/// RL 2, RR 3 — so each corner reads as itself.
Map<Corner, TraceSeries> _corners(String channel, String unit, double value) {
  const n = 200;
  final start = sebringLapStartSeconds;
  final step = (sebringLapEndSeconds - start) / (n - 1);
  final times = Float64List.fromList([
    for (var i = 0; i < n; i++) start + i * step,
  ]);
  return {
    for (final c in Corner.values)
      c: TraceSeries(
        channelName: channel,
        unit: unit,
        frequencyHz: 10,
        valueColumn: c.valueColumn,
        times: times,
        lows: Float64List(n)..fillRange(0, n, value + c.index * 2),
        highs: Float64List(n)..fillRange(0, n, value + c.index * 2),
      ),
  };
}

final _cornerTelemetry = LapCornerTelemetry(
  channels: {
    Channels.tyresPressure: _corners(Channels.tyresPressure, 'kPa', 170),
    Channels.tyresTempLeft: _corners(Channels.tyresTempLeft, 'C', 80),
    Channels.tyresTempCentre: _corners(Channels.tyresTempCentre, 'C', 85),
    Channels.tyresTempRight: _corners(Channels.tyresTempRight, 'C', 90),
    Channels.tyresCarcassTemp: _corners(Channels.tyresCarcassTemp, 'C', 95),
    Channels.brakesTemp: _corners(Channels.brakesTemp, 'C', 400),
  },
  flat: {Channels.tyresRimTemp},
  brakeBiasRear: StepSeries(
    eventName: Events.brakeBiasRear,
    unit: '',
    times: Float64List.fromList([sebringLapStartSeconds]),
    values: Float64List.fromList([0.45]),
  ),
);

ProviderContainer _container({
  bool tyres = true,
  List<SurfaceStretch> surfaces = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
      lapsProvider(_source).overrideWith((ref) async => [sebringLap()]),
      lapTelemetryProvider(_source, sebringLapIndex).overrideWith(
        (ref) async =>
            _lap(fileChannels: tyres ? cornerChannelNames.toSet() : const {}),
      ),
      lapCornerTelemetryProvider((_source, sebringLapIndex))
          .overrideWith((ref) async => _cornerTelemetry),
      lapSurfaceProvider((_source, sebringLapIndex))
          .overrideWith((ref) async => surfaces),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpTrace(
  WidgetTester tester,
  ProviderContainer container, {
  String? tab,
  // Wide enough that the dock keeps its tabs' words and the corners sit
  // side by side.
  Size size = const Size(1900, 1100),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  if (tab != null) container.read(traceTabProvider.notifier).selectId(tab);
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

/// Puts the playhead mid-lap, so every panel reads a value.
Future<void> _playheadMidLap(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(chartSyncProvider.notifier).setPlayhead(2000);
  await tester.pumpAndSettle();
}

Finder _inPanels(String text) =>
    find.descendant(of: find.byType(TracePanel), matching: find.text(text));

Finder _panelsTitled(String title) =>
    find.byWidgetPredicate((w) => w is TracePanel && w.title == title);

void main() {
  group('the tabs', () {
    testWidgets('Tyres and Brakes show for a file that carries them', (
      tester,
    ) async {
      await _pumpTrace(tester, _container());
      final tabs = tester.widget<DockTabs>(find.byType(DockTabs)).tabs;
      expect(tabs.map((t) => t.id), ['inputs', 'tyres', 'brakes']);
      // Named, not glyphs alone: there is room for the names.
      expect(find.text('Tyres'), findsOneWidget);
      expect(find.text('Brakes'), findsOneWidget);
    });

    testWidgets('and are absent, not greyed, for one that does not', (
      tester,
    ) async {
      await _pumpTrace(tester, _container(tyres: false));
      final tabs = tester.widget<DockTabs>(find.byType(DockTabs)).tabs;
      expect(tabs.map((t) => t.id), ['inputs']);
    });

    testWidgets('Tyres: pressure over temperature, each corner in its place', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container);
      await tester.tap(find.text('Tyres'));
      await tester.pumpAndSettle();
      await _playheadMidLap(tester, container);

      expect(_panelsTitled('Pressure'), findsNWidgets(4));
      expect(_panelsTitled('Surface'), findsNWidgets(4));
      // The surface is the tread's three zones averaged: (80 + 85 + 90) / 3
      // on the front left, two more on each corner after it.
      expect(_inPanels('85.0'), findsOneWidget);
      expect(_inPanels('91.0'), findsOneWidget);
      expect(_inPanels('170.0'), findsOneWidget);

      // The car's layout: FL left of FR, the fronts above the rears.
      final fl = tester.getCenter(find.text('FRONT LEFT'));
      final fr = tester.getCenter(find.text('FRONT RIGHT'));
      final rl = tester.getCenter(find.text('REAR LEFT'));
      expect(fl.dx, lessThan(fr.dx));
      expect(fl.dy, closeTo(fr.dy, 1));
      expect(rl.dy, greaterThan(fl.dy));
    });

    testWidgets('the chip shows the carcass instead; a temperature that '
        'never moved is not offered, and the tab says so', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'tyres');
      await _playheadMidLap(tester, container);

      expect(find.text('Rim'), findsNothing);
      expect(find.textContaining(Channels.tyresRimTemp), findsOneWidget);
      await tester.tap(find.text('Carcass'));
      await tester.pumpAndSettle();
      expect(_panelsTitled('Carcass'), findsNWidgets(4));
      expect(_inPanels('95.0'), findsOneWidget);
    });

    testWidgets('Zones draws the tread inner, centre and outer in one panel, '
        'the inner edge facing the car on either side', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'tyres');
      await _playheadMidLap(tester, container);
      await tester.tap(find.text('Zones'));
      await tester.pumpAndSettle();

      expect(_panelsTitled('Tread'), findsNWidgets(4));
      final panel = tester.widget<TracePanel>(_panelsTitled('Tread').first);
      expect(panel.series, isA<MultiLineSeries>());
      expect((panel.series as MultiLineSeries).lines, hasLength(3));

      // The fixture's left edge reads 80, the centre 85 and the right 90,
      // two more on each corner after the front left. The inner edge is the
      // right on a left wheel and the left on a right one.
      void readsInOrder(List<String> values) {
        final xs = [for (final v in values) tester.getCenter(_inPanels(v)).dx];
        expect(xs[0], lessThan(xs[1]));
        expect(xs[1], lessThan(xs[2]));
      }

      readsInOrder(['90', '85', '80']); // FL
      readsInOrder(['82', '87', '92']); // FR
      readsInOrder(['94', '89', '84']); // RL
      readsInOrder(['86', '91', '96']); // RR
    });

    for (final (name, size) in [
      ('the default dock', const Size(1400, 1000)),
      ('the sheet under the map', const Size(900, 1000)),
    ]) {
      testWidgets('both tabs fit $name', (tester) async {
        final container = _container();
        for (final tab in ['tyres', 'brakes']) {
          await _pumpTrace(tester, container, tab: tab, size: size);
          await _playheadMidLap(tester, container);
        }
        // Three readings in a quarter of the dock.
        container.read(tyreTempProvider.notifier).select(TyreTemp.zones);
        await _pumpTrace(tester, container, tab: 'tyres', size: size);
        await _playheadMidLap(tester, container);
        expect(_panelsTitled('Tread'), findsNWidgets(4));
      });
    }

    testWidgets('Brakes: four temperatures, the pedal, and the bias as the '
        'front share', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'brakes');
      await _playheadMidLap(tester, container);

      expect(_panelsTitled('Brake temp'), findsNWidgets(4));
      expect(_panelsTitled('Brake'), findsOneWidget);
      expect(_panelsTitled('Brake bias'), findsOneWidget);
      expect(_inPanels('406'), findsOneWidget);
      expect(_inPanels('55.0'), findsOneWidget);
    });
  });

  group('Colour by', () {
    testWidgets('on Tyres the line follows the corner the pointer rests on', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'tyres');
      Finder menu(String label) => find.descendant(
        of: find.byKey(const ValueKey('colour-by')),
        matching: find.text(label),
      );
      expect(menu('Surface temp · FL'), findsOneWidget);
      expect(find.byType(RampLegend), findsOneWidget);
      expect(find.text('Surface temp (°C)'), findsOneWidget);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('REAR RIGHT')));
      await tester.pumpAndSettle();
      expect(container.read(cornerFocusProvider), Corner.rearRight);
      expect(menu('Surface temp · RR'), findsOneWidget);
    });

    testWidgets('the car on the map lights the corner followed, on the '
        'corner tabs only', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'tyres');
      await _playheadMidLap(tester, container);
      CarGlyph car() =>
          stageLayers<CarLayer>(tester).single.cars
              .where((c) => !c.hollow)
              .single;
      expect(car().litWheel, Corner.frontLeft);

      container.read(cornerFocusProvider.notifier).select(Corner.rearRight);
      await tester.pumpAndSettle();
      expect(car().litWheel, Corner.rearRight);

      container.read(traceTabProvider.notifier).selectId('inputs');
      await tester.pumpAndSettle();
      expect(car().litWheel, isNull);
    });

    testWidgets('each tab keeps its own choice', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container);
      container
          .read(colourByProvider.notifier)
          .select('tyres', colourByCorner(CornerQuantity.pressure));
      await tester.pumpAndSettle();
      expect(
        colourByOf(container.read(colourByProvider), 'inputs'),
        colourByInputs,
      );
      container.read(traceTabProvider.notifier).selectId('tyres');
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('colour-by')),
          matching: find.text('Pressure · FL'),
        ),
        findsOneWidget,
      );
    });
  });

  group('kerbs and off-track (P9d)', () {
    final start = sebringLapStartSeconds;

    testWidgets('cased under the line, on the lap axis, and keyed', (
      tester,
    ) async {
      final container = _container(
        surfaces: [
          SurfaceStretch(TrackSurface.kerb, start + 10, start + 11),
          SurfaceStretch(TrackSurface.offTrack, start + 30, start + 32),
          SurfaceStretch(TrackSurface.kerb, start + 50, start + 50.6),
        ],
      );
      await _pumpTrace(tester, container);
      final layer = stageLayers<SurfaceLayer>(tester).single;
      expect(layer.kerbs, hasLength(2));
      expect(layer.offTrack, hasLength(1));
      // On the Distance axis: metres, the first kerb before the off-track.
      final (kerbStart, kerbEnd) = layer.kerbs.first;
      final (offStart, _) = layer.offTrack.single;
      expect(kerbEnd, greaterThan(kerbStart));
      expect(offStart, greaterThan(kerbEnd));
      expect(
        layer.path.xs.first <= kerbStart && kerbEnd <= layer.path.xs.last,
        isTrue,
      );
      // Under the line, which keeps the pedals' colours on top.
      final layers = stagePainter(tester).layers;
      expect(
        layers.indexOf(layer),
        lessThan(layers.indexWhere((l) => l is TrackLineLayer)),
      );
      expect(find.text('Kerbs · 2'), findsOneWidget);
      expect(find.text('Off track'), findsOneWidget);
    });

    testWidgets('a lap that stayed on the asphalt draws and keys none', (
      tester,
    ) async {
      await _pumpTrace(tester, _container());
      expect(stageLayers<SurfaceLayer>(tester), isEmpty);
      expect(find.byType(SurfaceLegend), findsNothing);
    });
  });

  group('phone width and arrival (P9e)', () {
    testWidgets('a compact lap card, a tight play bar, the map the most', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, size: const Size(420, 900));
      await _playheadMidLap(tester, container);
      // The lap's time stays; the sectors, length and keys go to the dock.
      expect(find.textContaining('Lap '), findsWidgets);
      expect(find.text('S1'), findsNothing);
      expect(find.byType(PedalLegend), findsNothing);
      // The play bar: no speed button, one axis button.
      expect(find.byTooltip('Playback speed'), findsNothing);
      expect(find.byKey(const ValueKey('axis-flip')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('axis-flip')));
      await tester.pumpAndSettle();
      expect(container.read(chartSyncProvider).axis, TraceAxis.time);
    });

    testWidgets('a link landing on a new stage is pulsed for, once', (
      tester,
    ) async {
      final container = _container();
      container.read(stageArrivalProvider.notifier).arrive();
      await _pumpTrace(tester, container);
      expect(container.read(stageArrivalProvider), isFalse);
      expect(stageLayers<ArrivalPulseLayer>(tester), isEmpty);
    });

    testWidgets('a link landing pulses the car once', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container);
      await _playheadMidLap(tester, container);
      container.read(stageArrivalProvider.notifier).arrive();
      var pulsed = false;
      for (var i = 0; i < 150 && !pulsed; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        pulsed = stageLayers<ArrivalPulseLayer>(tester).isNotEmpty;
      }
      expect(pulsed, isTrue);
      expect(container.read(stageArrivalProvider), isFalse);
      await tester.pumpAndSettle();
      expect(stageLayers<ArrivalPulseLayer>(tester), isEmpty);
    });

    testWidgets('and no other way in pulses it', (tester) async {
      await _pumpTrace(tester, _container());
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(stageLayers<ArrivalPulseLayer>(tester), isEmpty);
      }
    });
  });

  group('links', () {
    testWidgets('Tyres opens Tires & Brakes on the lap, the temperature and '
        'the corner', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'tyres');
      container.read(cornerFocusProvider.notifier).select(Corner.rearLeft);
      container.read(tyreTempProvider.notifier).select(TyreTemp.carcass);
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(LapFocusLink),
          matching: find.text('Tires & brakes'),
        ),
      );
      await tester.pump();

      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, '/tires-brakes');
      expect(pending.focus.corner, Corner.rearLeft);
      expect(
        container.read(tyreLapSelectionProvider(_source)),
        sebringLapIndex,
      );
      expect(
        container.read(tyreMetricSelectionProvider(_source)),
        TyreMetric.carcass,
      );
    });

    testWidgets('Brakes opens it on brake temperature, by Ctrl+Enter too', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'brakes');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(container.read(pendingLapFocusProvider)!.route, '/tires-brakes');
      expect(
        container.read(tyreMetricSelectionProvider(_source)),
        TyreMetric.brake,
      );
    });

    group('from Tires & Brakes', () {
      Future<ProviderContainer> pumpReport(
        WidgetTester tester, {
        LapFocus? arriving,
      }) async {
        await tester.binding.setSurfaceSize(const Size(1400, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final container = ProviderContainer(
          overrides: [
            openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
            tireBrakeReportProvider(_source)
                .overrideWith((ref) async => sebringRaceTyreReport()),
          ],
        );
        addTearDown(container.dispose);
        if (arriving != null) {
          container
              .read(pendingLapFocusProvider.notifier)
              .hold(tiresBrakesFocusTarget.route, arriving);
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: const TiresBrakesScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return container;
      }

      testWidgets('Lap N in Trace opens the tab that shows the metric', (
        tester,
      ) async {
        final container = await pumpReport(tester);
        final lap = sebringRaceTyreReport().defaultLap!;
        container
            .read(tyreMetricSelectionProvider(_source).notifier)
            .select(TyreMetric.brake);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lap ${lap.displayNumber} in Trace'));
        await tester.pump();
        final focus = container.read(pendingLapFocusProvider)!.focus;
        expect(focus.tab, 'brakes');
        expect(container.read(traceTabProvider), 'brakes');
      });

      testWidgets('a corner sent from Trace arrives lit', (tester) async {
        final lap = sebringRaceTyreReport().defaultLap!;
        final container = await pumpReport(
          tester,
          // As a link from the Tyres tab leaves it.
          arriving: LapFocus(
            source: _source,
            lap: lap.index,
            corner: Corner.rearRight,
          ),
        );
        final cards = tester.widgetList<CornerCard>(find.byType(CornerCard));
        expect(
          {
            for (final c in cards)
              if (c.lit) c.snapshot.corner,
          },
          {Corner.rearRight},
        );
        expect(container.read(pendingLapFocusProvider), isNull);
      });
    });
  });
}
