// Renders the tyres & brakes view to PNG with real per-lap numbers
// (SPEC.md §8.6, §12).
//
// A widget test proves the figures and the order of the cards; it cannot prove
// that the tread strip's ink is legible across the whole ramp, that the trend
// band sits around the line and not beside it, or that four small multiples on
// one scale actually look like one scale. Those need a picture.
//
// Two frames, on purpose: the Sebring Race at full width (the headline case —
// a 19-lap stint, the car's left side worked hardest, the setup beside the
// cards), and the Spa Hypercar Qualify narrow, on tyres warming up from
// ambient (the greyed pit-lane lap, a spin on the rear-right, the setup
// dropped below the cards).
//
// Regenerate with
//   flutter test --update-goldens test/goldens/tires_brakes_golden_test.dart
// and look at the PNGs: the images are the artifact, the diff is the alarm.
// Like every golden here it matches only on the platform that made it (macOS),
// hence the tag — see render_screens_test.dart.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_selection.dart';
import 'package:pace_reader/features/tires_brakes/presentation/tires_brakes_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/tyre_reports.dart';

const _source = TelemetrySource.path('/samples/sebring.duckdb');
final _outputDir = Directory('images');

/// `flutter test` substitutes a placeholder font for everything unless the
/// real ones are loaded — see render_screens_test.dart.
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

Future<void> _render(
  WidgetTester tester,
  String name,
  TireBrakeReport report, {
  required Size size,
  TyreMetric metric = TyreMetric.pressure,
  int? lapIndex,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        tireBrakeReportProvider(_source).overrideWith((ref) async => report),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const RepaintBoundary(
          key: ValueKey('shot'),
          child: TiresBrakesScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container =
      ProviderScope.containerOf(tester.element(find.byType(TiresBrakesScreen)));
  container.read(tyreMetricSelectionProvider(_source).notifier).select(metric);
  if (lapIndex != null) {
    container.read(tyreLapSelectionProvider(_source).notifier).select(lapIndex);
  }
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

  testWidgets('tires and brakes, Sebring Race', (tester) async {
    // Lap index 18, the last complete one: the left side is hotter by 10 °C
    // on the carcass, the front-left is the most worn, and the trend frames
    // show the pressure settling at ~177 kPa after a warm-up the garage lap
    // and the cut-off lap sit outside.
    await _render(
      tester,
      'tires_brakes',
      sebringRaceTyreReport(),
      size: const Size(1440, 2450),
    );
  });

  testWidgets('tires and brakes, Spa Qualify warming up', (tester) async {
    // Narrow (1000 px, the smallest width the view is laid out for): the
    // setup card moves below the cards. Tread temperature is the quantity
    // with the most to get wrong — a band around a line, from an ambient
    // 18 °C, with the spin's lap in the table.
    await _render(
      tester,
      'tires_brakes_warmup',
      spaQualifyTyreReport(),
      size: const Size(1000, 2100),
      metric: TyreMetric.tread,
    );
  });
}
