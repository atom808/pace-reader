// Renders the Session Library to PNG with the four real recordings
// (SPEC.md §8.1, §9.6, §12).
//
// What a widget test cannot see: whether the best-lap column lines up down the
// list, whether a personal-best badge crowds the lap number, whether the
// "file not found" row still reads as a row, and whether the "Open now" cards
// hold together at ~1000 px. Those are the regressions that only show up in a
// picture.
//
// Regenerate with
// `flutter test --update-goldens test/goldens/session_library_golden_test.dart`,
// then look at the PNGs. Platform-dependent like every golden here (macOS), so
// tagged `golden` — see `render_screens_test.dart` for why.
@Tags(['golden'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/features/session_library/application/folder_scan.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../features/session_library_harness.dart';
import '../fixtures/session_library_samples.dart';

const _folder =
    r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate\UserData\Telemetry';

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

Widget _shot(Widget app) =>
    RepaintBoundary(key: const ValueKey('shot'), child: app);

Future<void> _expectGolden(String name) => expectLater(
  find.byKey(const ValueKey('shot')),
  matchesGoldenFile('images/$name.png'),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadFonts();
  });

  testWidgets('library: two sessions open, four indexed, one file gone', (
    tester,
  ) async {
    await pumpLibraryScreen(
      tester,
      size: const Size(1280, 1090),
      indexed: sampleSessions,
      // Interlagos has left the disk: its row says so and offers removal.
      onDisk: [spaQualify, sebringRace, sebringFixture],
      open: [sebringRace, spaQualify],
      lastOpened: {
        sebringRace.path: libraryNow.subtract(const Duration(hours: 2)),
        spaQualify.path: libraryNow.subtract(const Duration(days: 1, hours: 1)),
      },
      folders: [
        LibraryFolder(
          path: _folder,
          addedAt: libraryIndexedAt,
          lastScannedAt: libraryNow.subtract(const Duration(minutes: 14)),
          lastScanFileCount: 4,
        ),
      ],
      wrap: _shot,
    );
    await _expectGolden('session_library');
  });

  testWidgets('library at ~1000 px with a scan running', (tester) async {
    final gate = FolderScanReaderGate(holdAt: sebringFixture.path);
    final h = await pumpLibraryScreen(
      tester,
      size: const Size(1000, 1000),
      indexed: [interlagosPractice, spaQualify],
      fileSystem: FakeSessionFileSystem(
        files: diskWith(sampleSessions),
        folders: {
          _folder: [for (final s in sampleSessions) s.path],
        },
      ),
      factsReader: (source) async {
        await gate.wait(source);
        return factsReaderFor(sampleSessions)(source);
      },
      wrap: _shot,
    );
    final scan = h.container.read(folderScanProvider.notifier);
    final running = scan.addAndScan(_folder);
    await gate.reached;
    await tester.pumpAndSettle();
    await _expectGolden('session_library_scanning');
    gate.release();
    await running;
    await tester.pumpAndSettle();
  });

  testWidgets('library filtered to nothing', (tester) async {
    await pumpLibraryScreen(
      tester,
      size: const Size(1280, 760),
      indexed: sampleSessions,
      wrap: _shot,
    );
    await tester.enterText(find.byType(TextField), 'monza');
    await tester.pumpAndSettle();
    await _expectGolden('session_library_no_match');
  });

  testWidgets('welcome: nothing open, nothing indexed', (tester) async {
    await pumpLibraryScreen(tester, size: const Size(1280, 760), wrap: _shot);
    await _expectGolden('session_library_welcome');
  });
}
