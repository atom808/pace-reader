// Session Library import surface (SPEC.md §8.1, §10).
//
// The case that matters here is the one that shipped broken: a file chooser
// that never opens. On macOS `file_picker_darwin` rejects the call in ~6 ms
// when the app is signed without a `files.user-selected` entitlement, and the
// first version of this screen reported that as "That file could not be
// opened" — a message about a file the user had never been shown a chance to
// choose. §10 asks for a specific cause, and a wrong cause is worse than a
// vague one: it sends the reader off to check a recording that is fine.
//
// A plain `flutter test` has no file-picker plugin registered, so
// `FilePicker.pickFile` throws `UnimplementedError` — the same shape of
// failure, which makes "the chooser itself failed" reachable here without a
// device or a mock.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/presentation/session_library_screen.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

Future<ProviderContainer> pumpLibrary(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const SessionLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SessionLibraryScreen)),
  );
}

void main() {
  testWidgets('a chooser that will not open says so, and says what to do',
      (tester) async {
    final container = await pumpLibrary(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    // Whatever else happens, the one unacceptable outcome is silence.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.textContaining('file chooser could not be opened'),
        findsOneWidget);
    // The drop target still works when the panel does not, so the message
    // points at it rather than leaving the user with no route in.
    expect(find.textContaining('Drag a .duckdb recording'), findsOneWidget);

    final state = container.read(sessionImportProvider);
    expect(state, isA<SessionImportFailure>());
    // The cause is kept for a bug report even though the headline is written
    // for a user.
    expect((state as SessionImportFailure).detail, isNotEmpty);
  });

  testWidgets('the failure does not wedge the screen', (tester) async {
    final container = await pumpLibrary(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(container.read(sessionImportProvider), isA<SessionImportIdle>());
    expect(find.byIcon(Icons.error_outline), findsNothing);
    // The import surface is still there to try again from.
    expect(find.text('Open a telemetry session'), findsOneWidget);
  });

  testWidgets('a drop that is not telemetry is refused by name',
      (tester) async {
    final container = await pumpLibrary(tester);

    await container
        .read(sessionImportProvider.notifier)
        .openDroppedPaths(['/tmp/setup.json']);
    await tester.pumpAndSettle();

    expect(find.textContaining('not a Le Mans Ultimate telemetry recording'),
        findsOneWidget);
  });
}
