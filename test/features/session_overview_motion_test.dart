// The Session Overview's stat tiles arrive as a cascade (SPEC.md §9.7.4), and
// do not when the user has asked for no motion. The final frame must be the one
// the screen had before any of this — `test/goldens/render_screens_test.dart`
// pins that picture; this file pins the way there.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_overview/presentation/session_overview_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_race_per_lap.dart';

class _OneSession extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [sebringSource];
}

const _catalog = TelemetryCatalog(
  channels: [],
  events: [],
  masterRowCount: 134059,
  origin: 23.5975,
  endSeconds: 1364.18,
);

Future<void> _pumpOverview(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(_OneSession.new),
        sessionMetadataProvider(sebringSource)
            .overrideWith((ref) async => sebringMetadata),
        telemetryCatalogProvider(sebringSource)
            .overrideWith((ref) async => _catalog),
        sessionClockGapsProvider(sebringSource)
            .overrideWith((ref) async => const []),
        lapsProvider(sebringSource).overrideWith((ref) async => sebringRaceLaps()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const SessionOverviewScreen(),
      ),
    ),
  );
}

/// Pumps one frame at a time until the tiles are in the tree, and stops on
/// the frame they first appear — the start of their entrance.
Future<void> _untilTilesMount(WidgetTester tester) async {
  for (var i = 0; i < 20 && find.byType(StatTile).evaluate().length < 5; i++) {
    await tester.pump();
  }
  expect(find.byType(StatTile), findsNWidgets(5));
}

/// How visible the nth tile is: the product of every fade above it.
double _tileOpacity(WidgetTester tester, int index) {
  var opacity = 1.0;
  final fades = find.ancestor(
    of: find.byType(StatTile).at(index),
    matching: find.byType(FadeTransition),
  );
  for (final element in fades.evaluate()) {
    opacity *= (element.widget as FadeTransition).opacity.value;
  }
  return opacity;
}

void main() {
  testWidgets('the five tiles arrive best lap first, one after another', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await _untilTilesMount(tester);

    // 200 ms in, every tile has started (the fifth is due at 160 ms) and none
    // has finished (the first runs to 360 ms): earlier tiles are further along.
    await tester.pump(const Duration(milliseconds: 200));
    final opacities = [for (var i = 0; i < 5; i++) _tileOpacity(tester, i)];
    for (var i = 1; i < opacities.length; i++) {
      expect(
        opacities[i - 1],
        greaterThan(opacities[i]),
        reason: 'tile ${i - 1} should be ahead of tile $i: $opacities',
      );
    }
  });

  testWidgets('all five settle fully visible, showing the real numbers', (
    tester,
  ) async {
    await _pumpOverview(tester);
    await tester.pumpAndSettle();

    for (var i = 0; i < 5; i++) {
      expect(_tileOpacity(tester, i), 1);
    }
    // Best lap of the real Race sample: lap 10, 63.9409 s.
    expect(find.text('1:03.941'), findsOneWidget);
    expect(find.text('Best lap'), findsOneWidget);
    expect(find.text('Recording'), findsOneWidget);
  });

  testWidgets('reduced motion: the tiles are all there on the frame they mount', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpOverview(tester);
    await _untilTilesMount(tester);

    for (var i = 0; i < 5; i++) {
      expect(_tileOpacity(tester, i), 1);
    }
  });
}
