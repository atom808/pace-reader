// The Setup Viewer (SPEC.md §8.10) rendered to PNG from the real samples' JSON.
//
// A widget test proves the strings and the counts; it says nothing about
// whether a range track is drawn past its end, the sawtooth of the shift
// diagram sits on its axes, a 2x2 wheel group wraps, or the pinned toolbar
// collides with the cards. Those only show up in a picture — so each frame
// here is one of those questions:
//
// - `setup_viewer` — the top of the Race sample (a fixed-setup race, so the
//   "adjustable" marks and the lock chip are on): header, key figures, the
//   pinned toolbar, and the first sections.
// - `setup_viewer_gearing` — the Qualify sample's seven-speed gearing, reached
//   the way a user reaches it (the Gearing chip): shift diagram and table.
// - `setup_viewer_wheels` — the Practice sample's suspension, per-wheel groups
//   with their range tracks, and the "Δ" pills' absence where nothing moved.
// - `setup_viewer_search` — a search at ~1000 px wide, the narrowest the
//   layout is asked to work at.
// - `setup_viewer_gearing_narrow` — the shift diagram and its table at the same
//   width, where the two must share a row or stack.
//
// Regenerate with `flutter test --update-goldens test/goldens/setup_viewer_golden_test.dart`,
// then look at the PNGs. Platform-dependent like every golden here, hence the tag.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/car_setup_samples.dart';
import '../fixtures/setup_viewer_harness.dart';

final _outputDir = Directory('images');
const _boundary = ValueKey('shot');

Future<void> _expectGolden(String name) => expectLater(
  find.byKey(_boundary),
  matchesGoldenFile('${_outputDir.path}/$name.png'),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    if (!_outputDir.existsSync()) _outputDir.createSync(recursive: true);
  });

  testWidgets('setup viewer, a fixed-setup race', (tester) async {
    await pumpSetupViewer(
      tester,
      sample: sebringCarSetup,
      size: const Size(1440, 1000),
      boundary: _boundary,
    );
    await _expectGolden('setup_viewer');
  });

  testWidgets('setup viewer, the shift diagram', (tester) async {
    await pumpSetupViewer(
      tester,
      sample: spaCarSetup,
      size: const Size(1440, 1000),
      boundary: _boundary,
    );
    await tester.tap(find.widgetWithText(InkWell, 'Gearing').first);
    await tester.pumpAndSettle();
    await _expectGolden('setup_viewer_gearing');
  });

  testWidgets('setup viewer, per-wheel groups', (tester) async {
    await pumpSetupViewer(
      tester,
      sample: interlagosCarSetup,
      size: const Size(1440, 1000),
      boundary: _boundary,
    );
    await tester.tap(find.widgetWithText(InkWell, 'Suspension').first);
    await tester.pumpAndSettle();
    await _expectGolden('setup_viewer_wheels');
  });

  testWidgets('setup viewer, a search at 1000 px', (tester) async {
    await pumpSetupViewer(
      tester,
      sample: spaCarSetup,
      size: const Size(1000, 820),
      boundary: _boundary,
    );
    await tester.enterText(find.byType(TextField), 'camber');
    await tester.pumpAndSettle();
    await _expectGolden('setup_viewer_search');
  });

  testWidgets('setup viewer, the shift diagram at 1000 px', (tester) async {
    await pumpSetupViewer(
      tester,
      sample: spaCarSetup,
      size: const Size(1000, 900),
      boundary: _boundary,
    );
    await tester.tap(find.widgetWithText(InkWell, 'Gearing').first);
    await tester.pumpAndSettle();
    await _expectGolden('setup_viewer_gearing_narrow');
  });
}
