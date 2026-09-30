// Renders the race pace and gaps view (SPEC.md §8.9) to PNG with the real
// Sebring Race readings.
//
// Its own file rather than another case in `render_screens_test.dart`: the
// picture is the only thing that shows whether the envelope band sits on the
// line, the rings land on the passes, the dimmed grid and flag stretches are
// where the readings stopped changing, and the signed bars grow from a zero
// line rather than a floor. A widget test proves the numbers; none of those is
// a number.
//
// Regenerate with `flutter test --update-goldens test/goldens/race_pace_golden_test.dart`
// and look at the PNGs — see `render_screens_test.dart` for why the baselines
// are committed, why they only match on macOS, and what the `golden` tag is for.
@Tags(['golden'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/race_pace/application/race_pace.dart';
import 'package:pace_reader/features/race_pace/presentation/race_pace_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/gap_samples.dart';
import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/samples/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

/// `flutter test` substitutes a placeholder font for everything unless the
/// real ones are loaded — see `render_screens_test.dart`.
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

Future<void> _render(
  WidgetTester tester,
  String name,
  RacePaceReport report, {
  required Size size,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        racePaceReportProvider(_source).overrideWith((ref) async => report),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const RepaintBoundary(
          key: ValueKey('shot'),
          child: RacePaceScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byKey(const ValueKey('shot')),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('race pace and gaps', (tester) async {
    await _render(
      tester,
      'race_pace',
      RacePaceReport(
        sessionType: SessionType.race,
        session: GapSession.derive(
          readings: sebringRaceGapSeries(),
          envelope: sebringRaceGapEnvelope(),
          laps: sebringRaceLaps(),
          stats: sebringRaceGapStats(),
          originSeconds: sebringRaceGapOrigin,
          endSeconds: 1364.18,
        ),
      ),
      size: const Size(1440, 2040),
    );
  });

  testWidgets('race pace, not a race', (tester) async {
    await _render(
      tester,
      'race_pace_not_a_race',
      const RacePaceReport(
        sessionType: SessionType.qualify,
        unavailable: GapUnavailable.notARace,
      ),
      size: const Size(1280, 720),
    );
  });
}
