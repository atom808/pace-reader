// The Phase 1 golden path, in the real app (SPEC.md §12: "integration tests
// covering the import → analyze golden path").
//
// Unlike the widget tests in `test/features/`, nothing here is faked: this
// pumps the actual `PaceReaderApp`, imports a real telemetry file through the
// real import controller, and navigates the real router. It is the only check
// that the whole stack — DuckDB, the derivations, the providers, the widgets —
// works together rather than each part working in isolation.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps the real app at a desktop-class size (§9.7).
  ///
  /// `appRouter` is a top-level final, so its location survives a
  /// `pumpWidget` — a second test would otherwise start wherever the first one
  /// navigated to. Reset explicitly rather than depending on test order.
  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/sessions');
    await tester.pumpWidget(const ProviderScope(child: PaceReaderApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SessionLibraryScreen)),
    );
  }

  Future<void> tapNav(WidgetTester tester, IconData icon) async {
    await tester.tap(find.byIcon(icon).first);
    await tester.pumpAndSettle();
  }

  testWidgets('import → overview → laps, against a real recording',
      (tester) async {
    final path = '$_projectRoot/$_fixture';
    expect(File(path).existsSync(), isTrue, reason: 'fixture missing at $path');

    final container = await pumpApp(tester);

    // 1. The library starts as the import surface.
    expect(find.text('Open a telemetry session'), findsOneWidget);

    // 2. Import through the real controller — the same path the file picker
    //    and the drag-and-drop handler both funnel into.
    await container
        .read(sessionImportProvider.notifier)
        .open(const TelemetrySource.path('$_projectRoot/$_fixture'));
    await tester.pumpAndSettle();

    expect(container.read(sessionImportProvider), isA<SessionImportSuccess>());

    // 3. The session card shows facts read out of the file itself.
    expect(find.textContaining('Sebring International Raceway'), findsOneWidget);
    expect(find.textContaining('Sebring School Circuit'), findsOneWidget);
    expect(find.text('3 timed laps'), findsOneWidget);

    // 4. Overview: the derived statistics.
    await tapNav(tester, Icons.dashboard_outlined);
    expect(find.text('Best lap'), findsOneWidget);
    // The real best of this recording, formatted for a user.
    expect(find.text('1:04.030'), findsWidgets);
    expect(find.text('Completed laps'), findsOneWidget);
    // 5 lap starts, 4 closed — the distinction §8.2 insists on.
    expect(find.text('4'), findsWidgets);
    expect(find.text('5 started · 3 timed'), findsOneWidget);
    // This fixture is derived from the gapless Race sample.
    expect(find.textContaining('discontinuit'), findsNothing);

    // 5. Laps: the corrected sector splits, end to end from the file.
    await tapNav(tester, Icons.timer_outlined);
    expect(find.text('12.914'), findsOneWidget,
        reason: 'S2 must be a duration, not the cumulative split');
    expect(find.text('28.237'), findsOneWidget, reason: 'S3 is derived');
    expect(find.text('36.261'), findsNothing,
        reason: 'the raw cumulative value must never be displayed');
    expect(find.text('out lap'), findsOneWidget);
    expect(find.text('partial sectors'), findsOneWidget);
  });

  testWidgets('a non-telemetry file is refused with a readable message',
      (tester) async {
    final container = await pumpApp(tester);
    final path = '${Directory.systemTemp.path}/pace_reader_flow_bogus.duckdb';
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    await file.writeAsString('this is not a duckdb database');

    await container
        .read(sessionImportProvider.notifier)
        .open(TelemetrySource.path(path));
    await tester.pumpAndSettle();

    // §10: a clear error, not a crash — and the library stays usable.
    expect(container.read(sessionImportProvider), isA<SessionImportFailure>());
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Open a telemetry session'), findsOneWidget);
  });
}
