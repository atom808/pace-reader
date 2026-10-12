// The Compare screen (SPEC.md §8.8; comparison proposal §3, §9, step 3).
//
// Every file is the two real 5 Hz Sebring fixture laps served under a path
// of its own (`compare_harness.dart`), so the screen runs every cross-file
// gate without a DuckDB connection.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/presentation/compare_close_guard.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _a = CompareFile('/compare/a.duckdb');

/// Another recording of the course: a distinct recording time, so it is
/// not "same recording" to Base.
final _b = CompareFile(
  '/compare/b.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

/// Records every `telemetrySessionProvider` built: the kept-alive session
/// that holds a file open until the app quits.
final class _SessionSpy extends ProviderObserver {
  final built = <TelemetrySource>[];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final provider = context.provider;
    if (provider.from == telemetrySessionProvider) {
      built.add(provider.argument! as TelemetrySource);
    }
  }
}

class _Harness {
  _Harness(this.container, this.router, this.reads, this.briefReads);

  final ProviderContainer container;
  final GoRouter router;
  final LapReadLog reads;
  final List<String> briefReads;

  ComparisonWorkspace get workspace =>
      container.read(comparisonWorkspaceProvider.notifier);

  ComparisonSet? get set => container.read(comparisonWorkspaceProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Harness> _pump(
  WidgetTester tester, {
  List<CompareFile>? files,
  List<CompareFile>? open,
  List<LibraryEntry> library = const [],
  ComparisonSet? set,
  int selected = sebringLapIndex,
  String initialLocation = '/driver-comparison',
  List<ProviderObserver> observers = const [],
  List<Override> overrides = const [],
  Size size = const Size(1440, 1000),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final opened = open ?? [_a, _b];
  final reads = <(String, int)>[];
  final briefReads = <String>[];
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/driver-comparison',
        builder: (context, state) => const DriverComparisonScreen(),
      ),
      GoRoute(
        path: '/trace',
        builder: (context, state) => const TelemetryTraceScreen(),
      ),
      GoRoute(
        path: '/close',
        builder: (context, state) => _CloseButtons(files: opened),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      observers: observers,
      overrides: [
        ...compareOverrides(
          files: files ?? [_a, _b],
          open: opened,
          library: library,
          reads: reads,
          briefReads: briefReads,
        ),
        ...overrides,
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Router<Object>)),
  );
  if (opened.isNotEmpty) {
    container
        .read(selectedLapIndexProvider(opened.first.source).notifier)
        .select(selected);
  }
  if (set != null) {
    container
        .read(comparisonWorkspaceProvider.notifier)
        .start(set.base, set.target);
  }
  await tester.pumpAndSettle();
  return _Harness(container, router, reads, briefReads);
}

ComparisonSet _pair(CompareFile base, CompareFile target) => ComparisonSet(
  LapRef(base.source, sebringLapIndex),
  LapRef(target.source, sebringLap3Index),
);

Finder _inPicker(Finder finder) =>
    find.descendant(of: find.byType(Dialog), matching: finder);

/// Scrolls the picker until [finder] is built and on screen: its list
/// builds rows as they come into view.
Future<void> _scrollPickerTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      120,
      scrollable: _inPicker(find.byType(Scrollable)).first,
    );

/// The side pane's Sectors tab — not the navigator's Sectors mode.
final _sectorsTab = find.widgetWithText(Tab, 'Sectors');

Future<void> _showSectors(WidgetTester tester) async {
  await tester.tap(_sectorsTab);
  await tester.pumpAndSettle();
}

List<String> _panelTitles(WidgetTester tester) => tester
    .widgetList<TracePanel>(find.byType(TracePanel))
    .map((p) => p.title)
    .toList();

void main() {
  group('opening', () {
    testWidgets('unchosen, it follows the current session alone', (
      tester,
    ) async {
      await _pump(tester, open: [_a]);
      expect(find.text('BASE'), findsOneWidget);
      expect(find.textContaining('Lap 2'), findsWidgets);
      expect(find.text('Choose a lap to compare Base against'), findsOneWidget);
      expect(find.text('Fastest of this file · Lap 4'), findsOneWidget);
      expect(
        find.text('Base alone: choose a Target to compare it against.'),
        findsOneWidget,
      );
      expect(_panelTitles(tester), isNot(contains('Delta')));
    });

    testWidgets("Trace's Open in Compare carries its reference as the Target", (
      tester,
    ) async {
      final h = await _pump(tester, open: [_a], initialLocation: '/trace');
      h.container
          .read(referenceLapIndexProvider(_a.source).notifier)
          .select(sebringLap3Index);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open in Compare'));
      await tester.pumpAndSettle();

      expect(h.location, '/driver-comparison');
      expect(h.set, _pair(_a, _a));
      expect(find.text('same file ✓'), findsOneWidget);
      expect(find.text('0.468 s quicker than Base'), findsOneWidget);
    });

    testWidgets("Open in Compare is off on a recording's first lap", (
      tester,
    ) async {
      final h = await _pump(
        tester,
        open: [_a],
        selected: 0,
        initialLocation: '/trace',
      );
      final button = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Open in Compare'),
          matching: find.byWidgetPredicate((w) => w is TextButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(h.set, isNull);
    });
  });

  group('Base against a Target from another file', () {
    testWidgets('both cards, the strip, the delta and the sectors', (
      tester,
    ) async {
      final h = await _pump(tester, set: _pair(_a, _b));
      expect(find.text('TARGET'), findsOneWidget);
      expect(find.text('0.468 s quicker than Base'), findsOneWidget);
      expect(find.text('same course'), findsOneWidget);
      expect(find.text('distance aligned 0.0 m'), findsOneWidget);
      expect(find.text('delta checked +0.004 s'), findsOneWidget);
      expect(_panelTitles(tester).first, 'Delta');
      await _showSectors(tester);
      expect(find.text('Base − Target'), findsOneWidget);
      // Exactly the two laps on screen were read.
      expect(h.reads.toSet(), {
        (_a.path, sebringLapIndex),
        (_b.path, sebringLap3Index),
      });
    });

    testWidgets('a chip opens the numbers behind it', (tester) async {
      await _pump(tester, set: _pair(_a, _b));
      await tester.tap(find.text('delta checked +0.004 s'));
      await tester.pumpAndSettle();
      expect(
        find.text('Allowed: 15.0 ms per lap, 20.0 ms per pair.'),
        findsOneWidget,
      );
      expect(find.textContaining('Base re-anchored by'), findsOneWidget);
    });

    testWidgets('a copy of the same recording says so', (tester) async {
      final copy = CompareFile('/compare/copy.duckdb');
      await _pump(
        tester,
        files: [_a, copy],
        open: [_a, copy],
        set: _pair(_a, copy),
      );
      expect(find.text('same recording'), findsOneWidget);
    });

    testWidgets('Swap exchanges them, and so does Alt+S', (tester) async {
      final h = await _pump(tester, set: _pair(_a, _b));
      await tester.tap(find.byTooltip('Swap Base and Target (Alt+S)'));
      await tester.pumpAndSettle();
      expect(h.set!.base, LapRef(_b.source, sebringLap3Index));
      expect(find.text('0.468 s slower than Base'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(h.set, _pair(_a, _b));
    });

    testWidgets('a narrow window moves the map and sectors to a view of '
        'their own', (tester) async {
      await _pump(tester, set: _pair(_a, _b), size: const Size(1000, 900));
      expect(_sectorsTab, findsNothing);
      expect(_panelTitles(tester).first, 'Delta');

      await tester.tap(find.text('Map & detail'));
      await tester.pumpAndSettle();
      expect(_sectorsTab, findsOneWidget);
      expect(find.byType(TracePanel), findsNothing);

      await tester.tap(find.text('Traces'));
      await tester.pumpAndSettle();
      expect(_panelTitles(tester).first, 'Delta');
    });

    testWidgets('sector lines 8 m apart: no delta, the sectors stay', (
      tester,
    ) async {
      final far = CompareFile('/compare/far.duckdb', stationOffset: 8);
      await _pump(
        tester,
        files: [_a, far],
        open: [_a, far],
        set: _pair(_a, far),
      );
      expect(_panelTitles(tester), isNot(contains('Delta')));
      expect(find.textContaining('S1 +8.0 m, S2 +8.0 m'), findsOneWidget);
      expect(
        find.text('distance offset 8.0 m: delta withheld'),
        findsOneWidget,
      );
      await _showSectors(tester);
      expect(find.text('Base − Target'), findsOneWidget);
    });
  });

  group('a pair the course gate refuses', () {
    testWidgets('says why, reads no lap, and offers to clear', (tester) async {
      final spa = CompareFile('/compare/spa.duckdb', metadata: spaMetadata);
      final h = await _pump(
        tester,
        files: [_a, spa],
        open: [_a, spa],
        set: _pair(_a, spa),
      );
      expect(find.text('These laps cannot be compared'), findsOneWidget);
      expect(
        find.textContaining('The Target is from a different track.'),
        findsOneWidget,
      );
      expect(h.reads, isEmpty);

      await tester.tap(find.text('Clear the Target'));
      await tester.pumpAndSettle();
      expect(h.set!.target, isNull);
    });
  });

  group('a compared file that was closed', () {
    testWidgets('the Target: reopen it or clear it', (tester) async {
      final h = await _pump(tester, open: [_a], set: _pair(_a, _b));
      expect(find.text("The Target's file was closed"), findsOneWidget);
      expect(find.text('Reopen'), findsOneWidget);
      expect(h.reads.where((r) => r.$1 == _b.path), isEmpty);

      await tester.tap(find.text('Clear the Target'));
      await tester.pumpAndSettle();
      expect(h.set!.target, isNull);
    });

    testWidgets('Base: reopen it, or make the Target the base', (tester) async {
      final h = await _pump(tester, open: [_b], set: _pair(_a, _b));
      expect(find.text("Base's file was closed"), findsOneWidget);

      await tester.tap(find.text('Make the Target the base'));
      await tester.pumpAndSettle();
      expect(h.set, ComparisonSet(LapRef(_b.source, sebringLap3Index)));
    });
  });

  group('closing a file Compare uses', () {
    Future<_Harness> pumpCloser(WidgetTester tester, CompareFile file) async {
      final h = await _pump(
        tester,
        set: _pair(_a, _b),
        initialLocation: '/close',
      );
      await tester.tap(find.text('close ${file.path}'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets("the Target's asks first, then clears the Target", (
      tester,
    ) async {
      final h = await pumpCloser(tester, _b);
      expect(find.text("Close the Target's file?"), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(h.set!.target, isNull);
      expect(h.container.read(openSessionsProvider), [_a.source]);
    });

    testWidgets('Keep open changes nothing', (tester) async {
      final h = await pumpCloser(tester, _b);
      await tester.tap(find.text('Keep open'));
      await tester.pumpAndSettle();
      expect(h.set, _pair(_a, _b));
      expect(h.container.read(openSessionsProvider), [_a.source, _b.source]);
    });

    testWidgets("Base's asks too, and keeps the pair to reopen", (
      tester,
    ) async {
      final h = await pumpCloser(tester, _a);
      expect(find.text("Close the Base's file?"), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(h.set, _pair(_a, _b));
      expect(h.container.read(openSessionsProvider), [_b.source]);
    });

    testWidgets('a file Compare does not use closes without asking', (
      tester,
    ) async {
      final other = CompareFile('/compare/other.duckdb');
      final h = await _pump(
        tester,
        files: [_a, _b, other],
        open: [_a, _b, other],
        set: _pair(_a, _b),
        initialLocation: '/close',
      );
      await tester.tap(find.text('close ${other.path}'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(h.container.read(openSessionsProvider), [_a.source, _b.source]);
    });
  });

  group('the lap picker', () {
    final library = CompareFile(
      '/compare/library.duckdb',
      metadata: sebringMetadata.copyWith(recordingTime: '2026-07-06T20_00_00Z'),
    );
    final longer = CompareFile(
      '/compare/longer.duckdb',
      metadata: sebringMetadata.copyWith(recordingTime: '2026-07-05T20_00_00Z'),
      course: const CourseFacts(
        wrapLength: 3084.313,
        sector1Station: 1029.435,
        sector2Station: 1572.549,
      ),
    );
    final fullCourse = CompareFile(
      '/compare/full.duckdb',
      metadata: sebringMetadata.copyWith(
        recordingTime: '2026-07-04T20_00_00Z',
        trackLayout: 'Sebring International Raceway',
      ),
    );

    Future<_Harness> pumpPicker(
      WidgetTester tester, {
      List<ProviderObserver> observers = const [],
    }) async {
      final h = await _pump(
        tester,
        files: [_a, _b, library, longer, fullCourse],
        open: [_a, _b],
        library: [
          libraryEntryOf(library),
          libraryEntryOf(longer),
          libraryEntryOf(fullCourse),
        ],
        observers: observers,
      );
      await tester.tap(find.text('Pick a lap…'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('lists the course by section, other layouts disabled', (
      tester,
    ) async {
      await pumpPicker(tester);
      expect(find.text('Choose the Target lap'), findsOneWidget);
      for (final section in [
        'Suggested',
        'This file',
        'Open now',
        'Library',
        "Other layouts of this track (can't be compared by distance yet)",
      ]) {
        await _scrollPickerTo(tester, find.text(section));
        expect(find.text(section), findsOneWidget, reason: section);
      }
      expect(
        find.textContaining('Sebring International Raceway · Race'),
        findsOneWidget,
      );
    });

    testWidgets("never offers the recording's first lap, nor Base again", (
      tester,
    ) async {
      await pumpPicker(tester);
      await _scrollPickerTo(tester, find.text("this is Base's Lap 2 again"));
      expect(find.text("out lap: the recording's first lap"), findsOneWidget);
      expect(find.text("this is Base's Lap 2 again"), findsOneWidget);
    });

    testWidgets('a library file is checked by a brief read when expanded', (
      tester,
    ) async {
      final h = await pumpPicker(tester);
      expect(h.briefReads, isEmpty);
      final row = find.text('Diego Pestana · Race · 5 Jul 2026');
      await _scrollPickerTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(h.briefReads, [longer.path]);
      expect(
        find.text(
          'Not comparable: a different course of this track: 3084.31 m, '
          'not 3083.31 m.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosing a lap of an open file makes it the Target', (
      tester,
    ) async {
      final h = await pumpPicker(tester);
      // The open file's title: the second, after this file's.
      final title = _inPicker(find.textContaining('· best 1:04.030')).at(1);
      await _scrollPickerTo(tester, title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      // This file's lap 4, then the open file's.
      final lap = _inPicker(find.text('1:04.030')).last;
      await _scrollPickerTo(tester, lap);
      await tester.tap(lap);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(h.set!.target, LapRef(_b.source, sebringLap3Index));
    });
  });

  group('reads only what is open', () {
    testWidgets('no session is opened for a file outside Open now, across '
        'the cards, the chips and the picker', (tester) async {
      final spy = _SessionSpy();
      final library = CompareFile(
        '/compare/library.duckdb',
        metadata: sebringMetadata.copyWith(
          recordingTime: '2026-07-06T20_00_00Z',
        ),
      );
      final h = await _pump(
        tester,
        files: [_a, _b, library],
        open: [_a],
        library: [libraryEntryOf(library), libraryEntryOf(_b)],
        set: _pair(_a, _b), // the Target's file is not open
        observers: [spy],
      );
      expect(find.text("The Target's file was closed"), findsOneWidget);

      await tester.tap(find.byTooltip('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pick a lap…').last);
      await tester.pumpAndSettle();
      // Both library rows: the Target's closed file, and another.
      for (final date in ['7 Jul 2026', '6 Jul 2026']) {
        final row = find.text('Diego Pestana · Race · $date');
        await _scrollPickerTo(tester, row);
        await tester.tap(row);
        await tester.pumpAndSettle();
      }

      expect(h.briefReads, containsAll([_b.path, library.path]));
      expect(spy.built, isEmpty);
    });
  });
}

/// A close button per open file, as the session switcher and Open now have:
/// both call the same guard.
class _CloseButtons extends ConsumerWidget {
  const _CloseButtons({required this.files});

  final List<CompareFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        for (final f in files)
          TextButton(
            onPressed: () => closeSessionChecked(context, ref, f.source),
            child: Text('close ${f.path}'),
          ),
      ],
    ),
  );
}
