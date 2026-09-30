// A picture of every screen in the real app, against a real recording.
//
// Not an assertion suite: goldens (test/goldens/) pin pixels on fixture data
// inside the test runner, where DuckDB cannot run and fonts are loaded by
// hand. This is the other half — the compiled app, a real `.duckdb` file read
// through the real import controller, the real router — rendered to PNGs a
// person looks at. It is how a layout that only breaks on a full session
// (19 laps instead of the fixture's 4, a 22-minute trace instead of one lap)
// gets seen before a user sees it.
//
//   flutter test integration_test/screen_tour_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)" \
//     --dart-define=SESSION="samples/Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb" \
//     --dart-define=OUT_DIR="$(pwd)/build/screens"
//
// SESSION defaults to the checked-in fixture, so the tour runs on any machine;
// `samples/` is git-ignored and only exists where the real recordings do.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/app_shell.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_database.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _session = String.fromEnvironment(
  'SESSION',
  defaultValue: 'test/fixtures/sebring_race_laps0_3.duckdb',
);
const _outDir = String.fromEnvironment(
  'OUT_DIR',
  defaultValue: 'build/screens',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tour every destination', (tester) async {
    final path = _session.startsWith('/')
        ? _session
        : '$_projectRoot/$_session';
    expect(File(path).existsSync(), isTrue, reason: 'no recording at $path');
    Directory(_outDir).createSync(recursive: true);

    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/sessions');

    // The library index in memory, not the developer's own file: a tour must
    // neither read someone's library (the pictures would depend on it) nor
    // write the recording it opens into it.
    final index = DriftSessionIndexStore(
      LibraryDatabase(NativeDatabase.memory()),
    );
    addTearDown(index.close);

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [sessionIndexStoreProvider.overrideWithValue(index)],
          child: const PaceReaderApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String name) async {
      // Two settles: a screen whose providers resolve after the first frame
      // (every DuckDB read) cross-fades from its skeleton afterwards.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_outDir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    }

    await capture('00_library_empty');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SessionLibraryScreen)),
    );
    await container
        .read(sessionImportProvider.notifier)
        .open(TelemetrySource.path(path));
    await tester.pumpAndSettle();
    expect(container.read(sessionImportProvider), isA<SessionImportSuccess>());

    for (var i = 0; i < appNavDestinations.length; i++) {
      final destination = appNavDestinations[i];
      appRouter.go(destination.path);
      final slug = destination.path.substring(1).replaceAll('/', '_');
      await capture('${(i + 1).toString().padLeft(2, '0')}_$slug');
    }
  });
}
