// Renders the Lap Analysis screen (SPEC.md §8.3) to PNG: the summary tiles, the
// trend chart with its marks, and the lap table with its incident badges.
//
// The chart is the reason this is a golden and not only a widget test. A test
// can prove the bars are the right height and the right marks exist; it
// cannot prove the fastest lap's cap is visible on a baseline, that a glyph
// sits under *its* column, that the hover band lines up with the bar it
// belongs to, or that a tooltip is not clipped. Those are pictures.
//
// Two frames, each earning its place:
//
// * **annotations** — the real Race laps and the real Race impacts, at the
//   narrow end of the layout range, with a yellow flag and a detached wheel
//   *constructed* onto two laps. No recording has ever held either, so this is
//   the only place their glyphs, badges and tooltip text are ever seen; it is
//   labelled constructed here and must not be read as measured.
// * **hover** — the pointer over a column: the tooltip, the column band, the
//   matching table row, and the lap the Trace is showing.
//
// Regenerate with `flutter test --update-goldens test/goldens/lap_analysis_golden_test.dart`,
// then look at the PNGs. Like the rest of `test/goldens/`, they are
// platform-dependent and carry the `golden` tag.
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';
import 'package:pace_reader/features/lap_analysis/presentation/lap_analysis_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

import '../fixtures/lap_incidents.dart';
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
  await load('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  await load(AppFonts.numeral, [
    'assets/fonts/JetBrainsMono-Regular.ttf',
    'assets/fonts/JetBrainsMono-Medium.ttf',
    'assets/fonts/JetBrainsMono-SemiBold.ttf',
  ]);
}

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

class _Selected extends SelectedLapIndex {
  _Selected(this._index);
  final int _index;
  @override
  int? build(TelemetrySource source) => _index;
}

/// The real Race impacts, plus — **constructed** — a yellow flag across lap
/// index 13 and a rear-left wheel that comes off in lap index 16 and is
/// refitted during 17. Nothing in any recording is like either.
SessionIncidents _incidentsWithConstructedKinds() {
  final laps = sebringRaceLaps();
  final real = sebringRaceIncidents();
  StepSeries wheel(int corner) => StepSeries.fromRows([
    (laps.first.startSeconds, 0),
    if (corner == WheelCorner.rearLeft.index) ...[(1170.0, 1), (1240.0, 0)],
  ], eventName: 'WheelsDetached');
  return SessionIncidents.derive(
    laps,
    impact: real.impact,
    yellowFlag: StepSeries.fromRows(const [
      (23.5975, 0),
      (975.0, 1),
      (1010.0, 0),
    ], eventName: 'Yellow Flag State'),
    wheelsDetached: [for (var c = 0; c < 4; c++) wheel(c)],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required SessionIncidents incidents,
  int selectedLap = 10,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source).overrideWith((ref) async => sebringRaceLaps()),
        sessionIncidentsProvider(_source)
            .overrideWith((ref) async => incidents),
        selectedLapIndexProvider(_source)
            .overrideWith(() => _Selected(selectedLap)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const RepaintBoundary(
          key: ValueKey('shot'),
          child: LapAnalysisScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    if (!_outputDir.existsSync()) _outputDir.createSync(recursive: true);
  });

  testWidgets('lap analysis with every annotation kind, narrow', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(1000, 1780),
      incidents: _incidentsWithConstructedKinds(),
    );
    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('${_outputDir.path}/lap_analysis_annotations.png'),
    );
  });

  testWidgets('lap analysis with the pointer over a column', (tester) async {
    final real = sebringRaceIncidents();
    await _pump(
      tester,
      size: const Size(1280, 1780),
      incidents: SessionIncidents.derive(
        sebringRaceLaps(),
        impact: real.impact,
        yellowFlag: real.yellowFlag,
        wheelsDetached: real.wheelsDetached,
      ),
      selectedLap: 6,
    );

    // Over lap 2's column (index 1) — a real impact lap, and one of the
    // shortest bars on the chart, which is what the wide hit target is for.
    final chart = tester.getRect(find.byType(PerLapBarChart));
    final slot = (chart.width - 48) / 20;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(Offset(chart.left + 48 + slot * 1.5, chart.top + 60));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('shot')),
      matchesGoldenFile('${_outputDir.path}/lap_analysis_hover.png'),
    );
  });
}
