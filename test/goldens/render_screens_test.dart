// Renders the Phase 1 screens to PNG with real fixture data (SPEC.md §12).
//
// The chart screens are the reason §12 asks for goldens at all: a widget test
// proves the strings and the numbers, and nothing about whether the trace is
// drawn upside down, the circuit is stretched, or the cursor readout sits off
// the panel. Those are the regressions that are easy to introduce and hard to
// eyeball-catch, and they only show up in a picture.
//
// Regenerate with `flutter test --update-goldens test/goldens/`, then look at
// the PNGs — the images are the artifact, the diff is only the alarm.
//
// The baselines are committed, so `flutter test` is self-contained: without
// them on disk `matchesGoldenFile` fails rather than skipping, and a suite that
// only passes on the machine that generated it is not a suite.
//
// They are also **platform-dependent**. Text shaping and antialiasing differ
// per OS, so these match on the platform they were generated on (macOS) and
// will not on another. That is why they carry the `golden` tag: §13's CI matrix
// runs `--exclude-tags golden` everywhere except the macOS job, which is the
// only honest way to have both a matrix and pixel baselines. Everything the
// goldens cover is *also* asserted structurally in `test/features/`, so a
// non-macOS runner still checks the behaviour — it just can't check the pixels.
//
// Run with: flutter test test/goldens/render_screens_test.dart
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` — the type a ProviderScope takes — lives in this entry point
// rather than the main one.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/events_log/presentation/events_log_screen.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/fuel_energy_strategy/presentation/fuel_energy_strategy_screen.dart';
import 'package:pace_reader/features/lap_analysis/presentation/lap_analysis_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_overview/presentation/session_overview_screen.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/features/track_map/presentation/track_map_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/samples/sebring.duckdb');
final _outputDir = Directory('images');

/// `flutter test` substitutes a placeholder font for everything unless the
/// real ones are loaded, which would make every screenshot a grid of boxes.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }

  await load(AppFonts.ui, [
    'assets/fonts/GeneralSans-Regular.ttf',
    'assets/fonts/GeneralSans-Medium.ttf',
    'assets/fonts/GeneralSans-Semibold.ttf',
    'assets/fonts/GeneralSans-Bold.ttf',
  ]);
  // Without this the icon glyphs render as empty boxes, which would make
  // every screenshot misleading about what the app actually looks like.
  await load('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  await load(AppFonts.numeral, [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
    'assets/fonts/JetBrainsMono-SemiBold.ttf',
  ]);
}

/// The real Sebring Race session, as the repositories map it.
const _metadata = SessionMetadata(
  driverName: 'Diego Pestana',
  steamId: '76561198000000000',
  recordingTime: '2026-07-07T06_42_17Z',
  sessionTimeOfDay: '13:00:21',
  sessionType: SessionType.race,
  trackName: 'Sebring International Raceway',
  trackLayout: 'Sebring School Circuit',
  weatherConditions: 'Clear',
  carName: 'The Bend Team WRT 2025 #31:BRZ',
  carClass: 'GT3',
  carSetupJson: '{}',
  version: '1',
);

/// Laps 0-19 of the real Race sample — see `sebring_race_per_lap.dart`.
List<Lap> _laps() => sebringRaceLaps();

const _catalog = TelemetryCatalog(
  channels: [],
  events: [],
  masterRowCount: 134059,
  origin: 23.5975,
  endSeconds: 1364.18,
);

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

Future<void> _render(
  WidgetTester tester,
  String name,
  Widget screen, {
  Size size = const Size(1280, 900),
  List<Lap>? laps,
  List<Override> overrides = const [],
  void Function(ProviderContainer container)? before,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        sessionMetadataProvider(_source).overrideWith((ref) async => _metadata),
        telemetryCatalogProvider(_source).overrideWith((ref) async => _catalog),
        sessionClockGapsProvider(_source).overrideWith((ref) async => const []),
        lapsProvider(_source).overrideWith((ref) async => laps ?? _laps()),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: RepaintBoundary(key: const ValueKey('shot'), child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (before != null) {
    before(ProviderScope.containerOf(tester.element(find.byWidget(screen))));
    await tester.pumpAndSettle();
  }

  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('${_outputDir.path}/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    if (!_outputDir.existsSync()) _outputDir.createSync(recursive: true);
  });

  testWidgets('session overview', (tester) async {
    await _render(tester, 'session_overview', const SessionOverviewScreen());
  });

  testWidgets('lap table', (tester) async {
    await _render(tester, 'lap_table', const LapAnalysisScreen(),
        size: const Size(1280, 1100));
  });

  testWidgets('telemetry trace', (tester) async {
    // Six stacked panels sharing one distance axis, with the track map beside
    // them on the same cursor — the whole of §8.4 in one frame.
    await _render(
      tester,
      'telemetry_trace',
      const TelemetryTraceScreen(),
      size: const Size(1440, 1000),
      laps: _lapsWithFixture(),
      overrides: _lapOverrides,
    );
  });

  testWidgets('telemetry trace vs reference', (tester) async {
    // Lap 2 against lap 4 — both real — with the cursor parked mid-lap, so the
    // frame holds everything a comparison adds: the delta panel against its
    // zero line, a dotted reference over every filled trace, and a ring
    // beside every dot. The dotted line in particular is exactly the kind of
    // mark a structural test can only prove exists.
    await _render(
      tester,
      'telemetry_trace_reference',
      const TelemetryTraceScreen(),
      size: const Size(1440, 1100),
      laps: _lapsWithBothFixtures(),
      overrides: [
        ..._lapOverrides,
        lapTelemetryProvider(_source, sebringLap3Index)
            .overrideWith((ref) async => sebringLap3Telemetry()),
        selectedLapIndexProvider(_source).overrideWith(() => _DisplayLap1()),
        referenceLapIndexProvider(_source)
            .overrideWith(() => _ReferenceLap3()),
      ],
      // After the lap loads rather than as an initial state: a lap resolving
      // is a lap change, and a lap change clears the cursor on purpose.
      // 1540 m is mid-lap, between the S2 and S3 markers.
      before: (container) =>
          container.read(chartSyncProvider.notifier).setCursor(1540),
    );
  });

  testWidgets('events log', (tester) async {
    // The one screen whose whole job is a dense column layout, which is
    // exactly what a structural test cannot check.
    await _render(
      tester,
      'events_log',
      const EventsLogScreen(),
      size: const Size(1280, 900),
      overrides: [
        sessionEventLogProvider(_source).overrideWith((ref) async => _eventLog()),
      ],
    );
  });

  testWidgets('fuel and energy', (tester) async {
    // The first standalone `fl_chart` view (§9.5), so the first place its
    // theming can drift from the custom core's: axis face, grid weight, bar
    // shape, and the greyed laps the average leaves out.
    await _render(
      tester,
      'fuel_energy',
      const FuelEnergyStrategyScreen(),
      size: const Size(1280, 1000),
      overrides: [
        fuelEnergyReportProvider(_source).overrideWith(
          (ref) async => FuelEnergyReport(
            carClass: 'GT3',
            fuel: ResourceUsage.derive(
              name: 'Fuel',
              unit: 'L',
              laps: sebringRaceLaps(),
              stats: sebringRaceFuelStats(),
            ),
            energy: ResourceUsage.derive(
              name: 'Virtual energy',
              unit: '%',
              laps: sebringRaceLaps(),
              stats: sebringRaceEnergyStats(),
            ),
            stateOfCharge: null,
            pitVisits: const [],
          ),
        ),
      ],
    );
  });

  testWidgets('track map', (tester) async {
    await _render(
      tester,
      'track_map',
      const TrackMapScreen(),
      size: const Size(1440, 900),
      laps: _lapsWithFixture(),
      overrides: _lapOverrides,
    );
  });
}

/// The session's laps, with the one the fixture carries substituted in so the
/// lap picker and the chart agree about it.
///
/// Only lap 1 has telemetry here, so it is also made the fastest: the trace
/// view defaults to the session's best lap, and a default that landed on a
/// lap with no fixture data would render a loading state forever.
List<Lap> _lapsWithFixture() => [
      for (final lap in _laps())
        if (lap.index == sebringLapIndex)
          sebringLap()
        else if (lap.lapTimeSeconds != null)
          lap.copyWith(lapTimeSeconds: lap.lapTimeSeconds! + 10)
        else
          lap,
    ];

/// Both fixture laps at their real times. Lap 4 (index 3) is then the faster,
/// so the view is pinned to lap 2 explicitly rather than left to default to
/// the best lap.
List<Lap> _lapsWithBothFixtures() => [
      for (final lap in _laps())
        if (lap.index == sebringLapIndex)
          sebringLap()
        else if (lap.index == sebringLap3Index)
          sebringLap3()
        else if (lap.lapTimeSeconds != null)
          lap.copyWith(lapTimeSeconds: lap.lapTimeSeconds! + 10)
        else
          lap,
    ];

class _DisplayLap1 extends SelectedLapIndex {
  @override
  int? build(TelemetrySource source) => sebringLapIndex;
}

class _ReferenceLap3 extends ReferenceLapIndex {
  @override
  int? build(TelemetrySource source) => sebringLap3Index;
}

/// The real Sebring Race lap 1, as `lapTelemetryProvider` would resolve it.
final _lapOverrides = <Override>[
  lapTelemetryProvider(_source, sebringLapIndex)
      .overrideWith((ref) async => sebringLapTelemetry()),
];

/// A log with the shapes that make this screen worth a picture: a boolean, a
/// widened 32-bit float, a per-corner row of four, and enough rows to fill the
/// viewport so column alignment is actually visible.
EventLog _eventLog() {
  const gears = [2, 3, 4, 5, 4, 3, 4, 5, 6, 5, 4, 5, 6, 5, 4, 3];
  return EventLog(
    events: [
      const TelemetryEvent(
          name: 'Brake Bias Rear',
          unit: '',
          timeSeconds: 23.5975,
          values: [0.48750001192092896]),
      const TelemetryEvent(
          name: 'TCLevel', unit: '', timeSeconds: 23.5975, values: [6]),
      const TelemetryEvent(
          name: 'TyresCompound',
          unit: '',
          timeSeconds: 23.5975,
          values: [1, 1, 1, 1]),
      for (var i = 0; i < gears.length; i++)
        TelemetryEvent(
            name: 'Gear',
            unit: '',
            timeSeconds: 30.0 + i * 3.5,
            values: [gears[i]]),
      for (var i = 0; i < 6; i++)
        TelemetryEvent(
            name: 'ABS',
            unit: '',
            timeSeconds: 34.0 + i * 9.0,
            values: [i.isEven]),
      for (var i = 0; i < 5; i++)
        TelemetryEvent(
            name: 'SurfaceTypes',
            unit: '',
            timeSeconds: 40.0 + i * 11.0,
            values: [0, 0, i % 2, i % 2]),
    ]..sort((a, b) {
        final byTime = a.timeSeconds.compareTo(b.timeSeconds);
        return byTime != 0 ? byTime : a.name.compareTo(b.name);
      }),
  );
}
