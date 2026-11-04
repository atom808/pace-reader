// The Suspension, Dynamics and Energy dock tabs (map stage proposal §6.1,
// P8), and their links to Suspension, Technique and Fuel & Energy and back
// (§6.4).

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/channels.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_channels.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driving_technique/application/technique_focus.dart';
import 'package:pace_reader/features/driving_technique/application/technique_providers.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy_focus.dart';
import 'package:pace_reader/features/fuel_energy_strategy/presentation/fuel_energy_strategy_screen.dart';
import 'package:pace_reader/features/lap_focus/lap_focus.dart';
import 'package:pace_reader/features/lap_focus/lap_focus_arrival.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/suspension/application/suspension_focus.dart';
import 'package:pace_reader/features/suspension/application/suspension_providers.dart';
import 'package:pace_reader/features/suspension/domain/sites.dart';
import 'package:pace_reader/features/suspension/domain/strikes.dart';
import 'package:pace_reader/features/telemetry_trace/application/channel_tabs.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/application/stage_view.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

/// Every channel the three tabs' guards look for.
final _hypercar = {
  Channels.frontRideHeight,
  Channels.rearRideHeight,
  Channels.suspPos,
  Channels.gForceLat,
  Channels.gForceLong,
  Channels.gForceVert,
  Channels.soc,
  Channels.virtualEnergy,
  Channels.fuelLevel,
};

LapTelemetry _lap(Set<String> fileChannels) {
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

/// [channel] holding [value] all lap, in the file's [unit].
TraceSeries _series(
  String channel,
  String unit,
  double value, {
  String valueColumn = 'value',
}) {
  const n = 200;
  final start = sebringLapStartSeconds;
  final step = (sebringLapEndSeconds - start) / (n - 1);
  return TraceSeries(
    channelName: channel,
    unit: unit,
    frequencyHz: 100,
    valueColumn: valueColumn,
    times: Float64List.fromList([for (var i = 0; i < n; i++) start + i * step]),
    lows: Float64List(n)..fillRange(0, n, value),
    highs: Float64List(n)..fillRange(0, n, value),
  );
}

final _suspension = LapChannels(
  single: {
    Channels.frontRideHeight: _series(Channels.frontRideHeight, 'm', 0.0452),
    Channels.rearRideHeight: _series(Channels.rearRideHeight, 'm', 0.061),
    Channels.front3rdDeflection: _series(
      Channels.front3rdDeflection,
      'm',
      0.012,
    ),
  },
  corners: {
    Channels.suspPos: {
      for (final c in Corner.values)
        c: _series(
          Channels.suspPos,
          'm',
          0.020 + c.index * 0.002,
          valueColumn: c.valueColumn,
        ),
    },
  },
  flat: {Channels.rear3rdDeflection},
);

final _dynamics = LapChannels(
  single: {
    Channels.gForceLong: _series(Channels.gForceLong, 'g', -1.84),
    Channels.gForceLat: _series(Channels.gForceLat, 'g', 0.5),
    Channels.gForceVert: _series(Channels.gForceVert, 'g', 1.02),
    Channels.pathLateral: _series(Channels.pathLateral, 'm', 2.4),
  },
  corners: const {},
);

/// A car without a hybrid: its charge and regen sit at zero.
final _energy = LapChannels(
  single: {
    Channels.virtualEnergy: _series(Channels.virtualEnergy, '%', 63.5),
    Channels.fuelLevel: _series(Channels.fuelLevel, 'L', 42.25),
  },
  corners: const {},
  flat: {Channels.soc, Channels.regenRate},
);

/// A site the lap struck at mid-lap, on the front left.
Site _site({double seconds = 228, StrikeTier tier = StrikeTier.strike}) {
  final strike = Strike(
    lap: sebringLapIndex,
    seconds: seconds,
    row: 0,
    depth: -0.001,
    corner: Corner.frontLeft,
    tier: tier,
    phase: StrikePhase.braking,
    surface: StrikeSurface.track,
    samples: 3,
    station: 2000,
  );
  return Site(
    key: 0,
    place: 2000,
    corner: Corner.frontLeft,
    strikes: [strike],
    lapLows: {sebringLapIndex: strike},
  );
}

const _metadata = SessionMetadata(
  driverName: 'D',
  steamId: '1',
  recordingTime: '2026-07-07T06_42_17Z',
  sessionTimeOfDay: '13:00:21',
  sessionType: SessionType.race,
  trackName: 'Sebring International Raceway',
  trackLayout: 'Sebring School Circuit',
  weatherConditions: 'Clear',
  carName: 'Hypercar',
  carClass: 'Hyper',
  carSetupJson: '{}',
  version: '1',
);

ProviderContainer _container({Set<String>? fileChannels}) {
  final container = ProviderContainer(
    overrides: [
      openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
      lapsProvider(_source).overrideWith((ref) async => [sebringLap()]),
      lapTelemetryProvider(
        _source,
        sebringLapIndex,
      ).overrideWith((ref) async => _lap(fileChannels ?? _hypercar)),
      for (final (set, read) in [
        (LapChannelSet.suspension, _suspension),
        (LapChannelSet.dynamics, _dynamics),
        (LapChannelSet.energy, _energy),
      ])
        lapChannelsProvider((_source, sebringLapIndex, set))
            .overrideWith((ref) async => read),
      suspensionOverviewProvider(_source).overrideWith(
        (ref) async => SuspensionOverview(
          session: TechniqueSession(
            metadata: _metadata,
            laps: [sebringLap()],
            racing: [sebringLap()],
            excluded: const {},
            steeringScale: 1,
            hasPedals: true,
          ),
          hasRideHeights: true,
          sites: [_site()],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpTrace(
  WidgetTester tester,
  ProviderContainer container, {
  String? tab,
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
  // The playhead mid-lap, so every panel reads a value.
  container.read(chartSyncProvider.notifier).setPlayhead(2000);
  await tester.pumpAndSettle();
}

Finder _inPanels(String text) =>
    find.descendant(of: find.byType(TracePanel), matching: find.text(text));

Finder _panelsTitled(String title) =>
    find.byWidgetPredicate((w) => w is TracePanel && w.title == title);

/// The open tab's detail link, by the key the link names.
Future<void> _openDetail(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

LapChart _chart(ProviderContainer container) =>
    container.read(lapChartProvider(_source, sebringLapIndex, null)).value!;

void main() {
  group('the tabs', () {
    testWidgets('all six show for a file that carries them, named', (
      tester,
    ) async {
      await _pumpTrace(tester, _container());
      final tabs = tester.widget<DockTabs>(find.byType(DockTabs)).tabs;
      expect(tabs.map((t) => t.id), [
        'inputs',
        'suspension',
        'dynamics',
        'energy',
      ]);
      expect(find.text('Suspension'), findsOneWidget);
      expect(find.text('Dynamics'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
    });

    testWidgets('and are absent for one that does not', (tester) async {
      await _pumpTrace(tester, _container(fileChannels: const {}));
      final tabs = tester.widget<DockTabs>(find.byType(DockTabs)).tabs;
      expect(tabs.map((t) => t.id), ['inputs']);
    });

    test('each guard says what the recording lacks', () {
      for (final tab in [suspensionTab, dynamicsTab, energyTab]) {
        expect(admittedTabs([tab], const {}), isEmpty);
        expect(tab.guard.reason, startsWith('${tab.label}:'));
      }
      // Energy for any car with one of its channels, not only a hybrid.
      expect(admittedTabs([energyTab], {Channels.fuelLevel}), [energyTab]);
    });

    testWidgets('Suspension: heights in mm, the dampers per corner, a still '
        'channel named', (tester) async {
      await _pumpTrace(tester, _container(), tab: 'suspension');
      expect(_panelsTitled('Front ride height'), findsOneWidget);
      expect(_panelsTitled('Rear ride height'), findsOneWidget);
      expect(_panelsTitled('Damper'), findsNWidgets(4));
      expect(_panelsTitled('Front 3rd element'), findsOneWidget);
      expect(_inPanels('45.2'), findsOneWidget);
      expect(_inPanels('61.0'), findsOneWidget);
      // FL 20 mm, two more on each corner after it.
      expect(_inPanels('20.0'), findsOneWidget);
      expect(_inPanels('26.0'), findsOneWidget);
      expect(find.text('FRONT LEFT'), findsOneWidget);
      expect(find.textContaining('Rear 3rd element'), findsOneWidget);
    });

    testWidgets('Suspension marks the lap\'s strikes on every panel, named '
        'once, on the top one', (tester) async {
      await _pumpTrace(tester, _container(), tab: 'suspension');
      final panels = tester
          .widgetList<TracePanel>(find.byType(TracePanel))
          .toList();
      expect(panels.first.markers.map((m) => m.$2), contains('Strike FL'));
      for (final panel in panels.skip(1)) {
        expect(panel.markers.length, panels.first.markers.length);
        expect(panel.markers.map((m) => m.$2), isNot(contains('Strike FL')));
      }
    });

    testWidgets('Dynamics: the file\'s swapped G axes named for what they '
        'are, the line signed', (tester) async {
      await _pumpTrace(tester, _container(), tab: 'dynamics');
      expect(_panelsTitled('Lateral G'), findsOneWidget);
      expect(_panelsTitled('Longitudinal G'), findsOneWidget);
      expect(_panelsTitled('Vertical G'), findsOneWidget);
      expect(_panelsTitled('Line'), findsWidgets);
      expect(_inPanels('-1.84'), findsOneWidget);
      expect(_inPanels('+2.4'), findsWidgets);
    });

    testWidgets('Energy: a car without a hybrid says why charge and regen '
        'are missing', (tester) async {
      await _pumpTrace(tester, _container(), tab: 'energy');
      expect(_panelsTitled('Virtual energy'), findsOneWidget);
      expect(_panelsTitled('Fuel'), findsOneWidget);
      expect(_panelsTitled('State of charge'), findsNothing);
      expect(_inPanels('42.25'), findsOneWidget);
      expect(
        find.textContaining('Regen / deploy, State of charge'),
        findsOneWidget,
      );
      expect(find.textContaining('without a hybrid'), findsOneWidget);
    });

    for (final (name, size) in [
      ('the default dock', const Size(1400, 1000)),
      ('the sheet under the map', const Size(900, 1000)),
    ]) {
      testWidgets('all three fit $name', (tester) async {
        final container = _container();
        for (final tab in ['suspension', 'dynamics', 'energy']) {
          await _pumpTrace(tester, container, tab: tab, size: size);
        }
      });
    }
  });

  group('buildChannelTab', () {
    testWidgets('keeps the tab\'s order, a per-corner channel in its place', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container);
      final tab = buildChannelTab(
        _chart(container),
        _suspension,
        set: LapChannelSet.suspension,
      );
      expect(tab.rows.map((r) => r.runtimeType), [
        PanelRow,
        PanelRow,
        CornerRow,
        PanelRow,
      ]);
      expect(tab.flat, {'Rear 3rd element'});
      expect((tab.rows.first as PanelRow).panel.unit, 'mm');
    });

    testWidgets('regen in kW, though the file writes watts', (tester) async {
      final container = _container();
      await _pumpTrace(tester, container);
      final tab = buildChannelTab(
        _chart(container),
        LapChannels(
          single: {
            Channels.regenRate: _series(Channels.regenRate, 'kW', 120000),
          },
          corners: const {},
        ),
        set: LapChannelSet.energy,
      );
      final panel = (tab.rows.single as PanelRow).panel;
      expect(panel.unit, 'kW');
      expect((panel.series as LineSeries).plot.highs.first, closeTo(120, 1e-9));
    });

    testWidgets('strike marks: only a strike on this lap, at its time', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container);
      final chart = _chart(container);
      final marks = strikeMarkers(chart, [
        _site(),
        _site(tier: StrikeTier.close),
      ]);
      expect(marks.map((m) => m.$2), ['Strike FL']);
      final domain = switch (chart.axis) {
        TraceAxis.distance => chart.distanceAxis!.distanceAt(228),
        TraceAxis.time => 228.0,
      };
      expect(marks.single.$1, closeTo(domain, 1e-9));
    });
  });

  group('links', () {
    testWidgets('Suspension opens the Suspension screen on the lap', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'suspension');
      await _openDetail(tester);
      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, '/suspension');
      expect(pending.focus.point, closeTo(2000, 1));
      expect(
        container.read(suspensionSelectionStateProvider(_source)).lapIndex,
        sebringLapIndex,
      );
    });

    testWidgets('Dynamics opens Technique, bound for its G-G panel', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'dynamics');
      await _openDetail(tester);
      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, '/driving-technique');
      expect(revealsGg(pending.focus), isTrue);
    });

    testWidgets('Energy opens Fuel & Energy with the lap picked', (
      tester,
    ) async {
      final container = _container();
      await _pumpTrace(tester, container, tab: 'energy');
      await _openDetail(tester);
      expect(container.read(pendingLapFocusProvider)!.route, '/fuel-energy');
      expect(container.read(fuelEnergyLapProvider(_source)), sebringLapIndex);
    });
  });

  group('the focus targets', () {
    test('a site within 150 m of the point is the one looked at', () {
      final site = _site();
      LapFocus at(double station) =>
          LapFocus(source: _source, lap: 1, station: station);
      expect(focusedSite([site], at(2140)), site);
      expect(focusedSite([site], at(2160)), isNull);
      expect(
        focusedSite([site], const LapFocus(source: _source, lap: 1)),
        isNull,
      );
    });

    test('only a focus from G forces lands on the G-G panel', () {
      LapFocus from(String? channel) =>
          LapFocus(source: _source, lap: 1, channel: channel);
      expect(revealsGg(from(Channels.gForceLong)), isTrue);
      expect(revealsGg(from(Channels.gForceVert)), isTrue);
      expect(revealsGg(from(null)), isFalse);
      expect(revealsGg(from(Channels.brakesTemp)), isFalse);
    });
  });

  group('Fuel & Energy', () {
    final laps = sebringRaceLaps();
    final report = FuelEnergyReport(
      carClass: 'GT3',
      fuel: ResourceUsage.derive(
        name: 'Fuel',
        unit: 'L',
        laps: laps,
        stats: sebringRaceFuelStats(),
        pitVisits: const [],
      ),
      energy: null,
      stateOfCharge: null,
      pitVisits: const [],
    );

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      LapFocus? arriving,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
          fuelEnergyReportProvider(_source).overrideWith((ref) async => report),
          telemetryCatalogProvider(_source).overrideWith(
            (ref) async => const TelemetryCatalog(
              channels: [],
              events: [],
              masterRowCount: 1,
              origin: 0,
              endSeconds: 1,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      if (arriving != null) {
        // As `openFocus` does before it navigates.
        container
            .read(fuelEnergyLapProvider(_source).notifier)
            .select(arriving.lap);
        container
            .read(pendingLapFocusProvider.notifier)
            .hold(fuelEnergyFocusTarget.route, arriving);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const FuelEnergyStrategyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    DataTable table(WidgetTester tester) =>
        tester.widget<DataTable>(find.byType(DataTable));

    testWidgets('a click on a row picks the lap, and Trace opens it on '
        'Energy', (tester) async {
      final container = await pump(tester);
      expect(find.text('Open in Trace'), findsOneWidget);
      final lap = laps[2];
      final cell = find.descendant(
        of: find.byType(DataTable),
        matching: find.text('${lap.displayNumber}'),
      );
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(container.read(fuelEnergyLapProvider(_source)), lap.index);
      expect(table(tester).rows.where((r) => r.selected).map((r) => r.key), [
        ValueKey('lap-${lap.index}'),
      ]);

      await tester.tap(find.text('Lap ${lap.displayNumber} in Trace'));
      await tester.pump();
      final pending = container.read(pendingLapFocusProvider)!;
      expect(pending.route, '/trace');
      expect(pending.focus.tab, 'energy');
      expect(container.read(traceTabProvider), 'energy');
    });

    testWidgets('a lap sent from Trace arrives highlighted, the table in '
        'view', (tester) async {
      final lap = laps[3];
      final container = await pump(
        tester,
        arriving: LapFocus(source: _source, lap: lap.index),
      );
      expect(container.read(pendingLapFocusProvider), isNull);
      expect(table(tester).rows.where((r) => r.selected).map((r) => r.key), [
        ValueKey('lap-${lap.index}'),
      ]);
      // Scrolled so the lap's row is on screen, below the app bar.
      final row = find.ancestor(
        of: find.text('${lap.displayNumber}'),
        matching: find.byType(LapFocusReveal),
      );
      expect(row, findsOneWidget);
      expect(tester.getCenter(row).dy, inInclusiveRange(100, 800));
      // The reveal's wait for its panel runs out.
      await tester.pump(revealPatience);
    });
  });
}
