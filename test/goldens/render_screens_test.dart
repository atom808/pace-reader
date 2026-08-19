// Renders the Phase 1 screens to PNG with real fixture data (SPEC.md §12).
//
// Not `matchesGoldenFile` assertions yet — those come with the chart core,
// where visual regressions are genuinely hard to eyeball. This is the
// groundwork: font loading and a deterministic surface, plus an artifact a
// human can actually look at, since a passing widget test proves the strings
// are right and nothing about whether the screen is legible.
//
// Run with: flutter test test/goldens/render_screens_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_analysis/presentation/lap_analysis_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_overview/presentation/session_overview_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _source = TelemetrySource.path('/samples/sebring.duckdb');
final _outputDir = Directory('build/screens');

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

/// Laps 0-19 of the real Race sample, including its two invalidated laps and
/// its three laps with an unrecorded S2.
List<Lap> _laps() {
  const raw = <(int, double, double?, double?, double?, double?)>[
    (0, 23.5975, 195.82, 71.24098205566406, 29.218246459960938, 42.20904541015625),
    (1, 195.82, 260.32, 64.49739074707031, 23.346588134765625, 36.260711669921875),
    (2, 260.32, 324.88, 64.57025146484375, 23.408477783203125, null),
    (3, 324.88, 388.92, 64.02963256835938, 22.9844970703125, 35.852996826171875),
    (4, 388.92, 452.96, 64.0489501953125, 22.929290771484375, 35.82183837890625),
    (5, 452.96, 517.38, null, 22.9329833984375, null),
    (6, 517.38, 582.04, 64.64666748046875, 23.279296875, 36.32666015625),
    (7, 582.04, 646.44, 64.403320312, 23.203125, 36.233215332),
    (8, 646.44, 710.7, 64.268310546, 23.155029296, 36.113403320),
    (9, 710.7, 774.78, 64.079101562, 22.876220703, 35.745239257),
    (10, 774.78, 838.72, 63.94091796875, 22.808349609, 35.752197265),
    (11, 838.72, 902.86, 64.139404296, 22.899169921, 35.831054687),
    (12, 902.86, 966.94, 64.082031250, 22.989013671, 35.953125),
    (13, 966.94, 1031.56, null, 22.9656982421875, null),
    (14, 1031.56, 1095.88, 64.309082031, 22.952148437, 36.042480468),
    (15, 1095.88, 1160.58, 64.701171875, 23.329101562, 36.406249),
    (16, 1160.58, 1224.74, 64.154296875, 22.945068359, 35.913085937),
    (17, 1224.74, 1289.0, 64.261230468, 23.032226562, 36.087402343),
    (18, 1289.0, 1353.1, 64.114257812, 22.964355468, 35.960205078),
    (19, 1353.1, null, null, null, null),
  ];
  return [
    for (final (index, start, end, time, s1, s2cum) in raw)
      Lap(
        index: index,
        startSeconds: start,
        endSeconds: end,
        lapTimeSeconds: time,
        sectors: SectorTimes.fromCumulative(
          sector1: s1,
          sector2Cumulative: s2cum,
          lapTimeSeconds: time,
        ),
      ),
  ];
}

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
        lapsProvider(_source).overrideWith((ref) async => _laps()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: RepaintBoundary(key: const ValueKey('shot'), child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();

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
}
