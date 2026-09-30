// Shared scaffolding for the Setup Viewer's widget and golden tests: the real
// samples' session facts, and a pump that hands the screen a `CarSetup` parsed
// from a real sample's JSON with no DuckDB connection behind it.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup_provider.dart';
import 'package:pace_reader/features/setup_viewer/presentation/setup_viewer_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import 'car_setup_samples.dart';

const setupViewerSource = TelemetrySource.path('/samples/setup.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [setupViewerSource];
}

/// The `metadata` of each sample, as `SessionRepository` maps it.
SessionMetadata sampleMetadata(CarSetupSample sample) {
  final (car, carClass, type, track, layout) = switch (sample) {
    _ when identical(sample, interlagosCarSetup) => (
      'Proton Competition 2025 #77:LM',
      'GT3',
      SessionType.practice,
      'Autódromo José Carlos Pace',
      'Autódromo José Carlos Pace',
    ),
    _ when identical(sample, spaCarSetup) => (
      'AF Corse 2026 #83:WEC',
      'Hyper',
      SessionType.qualify,
      'Circuit de Spa-Francorchamps',
      'Circuit de Spa-Francorchamps Endurance',
    ),
    _ => (
      'The Bend Team WRT 2025 #31:BRZ',
      'GT3',
      SessionType.race,
      'Sebring International Raceway',
      'Sebring School Circuit',
    ),
  };
  return SessionMetadata(
    driverName: 'Diego Pestana',
    steamId: '76561198000000000',
    recordingTime: '2026-07-07T06_42_17Z',
    sessionTimeOfDay: '13:00:21',
    sessionType: type,
    trackName: track,
    trackLayout: layout,
    weatherConditions: 'Clear',
    carName: car,
    carClass: carClass,
    carSetupJson: sample.json,
    version: '1',
  );
}

List<Override> setupViewerOverrides({
  required String json,
  SessionMetadata? metadata,
  Object? loadError,
}) => [
  openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
  if (metadata != null)
    sessionMetadataProvider(setupViewerSource)
        .overrideWith((ref) async => metadata),
  carSetupProvider(setupViewerSource).overrideWith((ref) async {
    if (loadError != null) throw loadError;
    return CarSetup.parse(json);
  }),
];

/// Pumps the Setup Viewer at desktop size on a real sample.
///
/// [boundary] wraps the screen in a keyed [RepaintBoundary] for a golden.
Future<void> pumpSetupViewer(
  WidgetTester tester, {
  required CarSetupSample sample,
  Size size = const Size(1440, 1000),
  String? json,
  bool withMetadata = true,
  Object? loadError,
  Key? boundary,
  bool disableAnimations = false,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Widget screen = const SetupViewerScreen();
  if (boundary != null) screen = RepaintBoundary(key: boundary, child: screen);

  await tester.pumpWidget(
    ProviderScope(
      overrides: setupViewerOverrides(
        json: json ?? sample.json,
        metadata: withMetadata ? sampleMetadata(sample) : null,
        loadError: loadError,
      ),
      child: MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(disableAnimations: disableAnimations),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: screen,
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// `flutter test` substitutes a placeholder font (Ahem: every glyph a full-em
/// square) for everything unless the real ones are loaded. That would make a
/// golden a grid of boxes, and would make any width-sensitive assertion — does
/// the chip row fit, does a pill overflow its column — measure a font the app
/// never draws with. Call from `setUpAll`.
Future<void> loadAppFonts() async {
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
