// Goldens for the app-wide UX polish (SPEC.md §9.7.2, §9.7.4, §9.7.6, §10): the
// shell's rail with its dimmed destinations, session badge and keyboard focus
// ring; the session switcher popover; and the Hoverable focus ring on a card.
//
// What a widget test cannot say is whether the ring reads as the *edge lighting
// up* or as a second border stuck on, whether a dimmed slot is still legible,
// or whether the popover sits where the badge that opened it is. Those are
// pictures. Like `render_screens_test.dart` these are macOS-platform baselines
// under the `golden` tag; the behaviour is asserted structurally in
// `test/app/app_shell_test.dart` and `test/design_system/hoverable_test.dart`.
//
// Regenerate with `flutter test --update-goldens test/goldens/ux_polish_golden_test.dart`
// and look at the PNGs.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/app/app_shell.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_overview/presentation/session_overview_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_race_per_lap.dart';

final _outputDir = Directory('images');

/// See `render_screens_test.dart`: without the real fonts every screenshot is a
/// grid of boxes.
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

class _ThreeOpen extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [
    sebringSource,
    spaSource,
    interlagosSource,
  ];
}

const _catalog = TelemetryCatalog(
  channels: [],
  events: [],
  masterRowCount: 134059,
  origin: 23.5975,
  endSeconds: 1364.18,
);

/// The shell around the real Session Overview of the Sebring Race sample, with
/// the three sample sessions open and Sebring current.
///
/// [height] is 900 by default. The rail's fourteen slots plus the badge need a
/// little over that, below which the slot list scrolls (and focus scrolls the
/// slot it lands on into view); the rail golden is taller so the whole column
/// is in the picture rather than one slot cut in half at the bottom.
Future<void> _pumpShell(WidgetTester tester, {double height = 900}) async {
  await tester.binding.setSurfaceSize(Size(1280, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/overview',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/overview',
            pageBuilder: (context, state) => appPage(
              key: state.pageKey,
              child: const SessionOverviewScreen(),
            ),
          ),
          for (final d in appNavDestinations.where((d) => d.path != '/overview'))
            GoRoute(
              path: d.path,
              pageBuilder: (context, state) =>
                  appPage(key: state.pageKey, child: const SizedBox()),
            ),
        ],
      ),
    ],
  );

  final overrides = <Override>[
    openSessionsProvider.overrideWith(_ThreeOpen.new),
    sessionMetadataProvider(sebringSource)
        .overrideWith((ref) async => sebringMetadata),
    sessionMetadataProvider(spaSource).overrideWith((ref) async => spaMetadata),
    sessionMetadataProvider(interlagosSource)
        .overrideWith((ref) async => interlagosMetadata),
    telemetryCatalogProvider(sebringSource)
        .overrideWith((ref) async => _catalog),
    sessionClockGapsProvider(sebringSource)
        .overrideWith((ref) async => const []),
    lapsProvider(sebringSource).overrideWith((ref) async => sebringRaceLaps()),
  ];

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectGolden(String name) => expectLater(
  find.byKey(const ValueKey('shot')),
  matchesGoldenFile('${_outputDir.path}/$name.png'),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
    if (!_outputDir.existsSync()) _outputDir.createSync(recursive: true);
  });

  testWidgets('rail: dimmed destinations, session badge, keyboard focus', (
    tester,
  ) async {
    await _pumpShell(tester, height: 960);

    // Keyboard focus on a slot, the way a keyboard user arrives at one: by
    // tabbing until they are on it.
    String? focused() => FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<Hoverable>()
        ?.semanticLabel;
    for (var i = 0; i < 40 && focused() != 'Track map'; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), 'Track map');
    await tester.pumpAndSettle();

    await _expectGolden('ux_polish_rail');
  });

  testWidgets('session switcher popover', (tester) async {
    await _pumpShell(tester);

    // The badge, which carries the Race sample's type code.
    await tester.tap(find.text('R').first);
    await tester.pumpAndSettle();

    await _expectGolden('ux_polish_session_switcher');
  });

  testWidgets('hoverable: idle, keyboard-focused, idle', (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget card(String label, {bool current = false}) => Hoverable(
      onTap: () {},
      child: SizedBox(
        width: 200,
        height: 120,
        child: SquircleCard(
          border: current ? AppGradients.hairlineStrong : null,
          child: Center(child: Text(label)),
        ),
      ),
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  card('Idle'),
                  const SizedBox(width: 32),
                  card('Keyboard focus'),
                  const SizedBox(width: 32),
                  card('Idle'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Tab to the second card.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await _expectGolden('ux_polish_hoverable_focus');
  });
}
