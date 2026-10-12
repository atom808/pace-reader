// Compare across two real recordings (comparison proposal §10, step 3).
//
// `test/features/compare_*` prove the gates on the 5 Hz Dart laps served
// under several paths. This is where they run on the files themselves:
// DuckDB attached read-only, the course facts read from every row, the laps
// at their recorded rate, and a second, genuinely different Sebring School
// recording (`sebring_race_b_laps0_2.duckdb`, trimmed from the Race session
// of 2026-07-07 05:57) against the first.
//
// The last test reads the user's own LMU Telemetry folder, attached
// read-only like everything else, and is skipped where the folder is absent.
//
// Run with (one file per run):
//   flutter test --no-pub integration_test/compare_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/app/app.dart';
import 'package:pace_reader/app/router.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/compare_laps.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_import.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/session_index_store.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';
const _second = 'test/fixtures/sebring_race_b_laps0_2.duckdb';

/// The user's LMU telemetry folder. Only ever attached read-only; nothing is
/// written, copied into or deleted there.
const _telemetryFolder = String.fromEnvironment(
  'LMU_TELEMETRY',
  defaultValue:
      r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate'
      r'\UserData\Telemetry',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_compare_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String copy(String fixture, String name) {
    final path = p.join(tmp.path, name);
    File('$_projectRoot/$fixture').copySync(path);
    return path;
  }

  /// Deletes [path] once nothing holds it open (see
  /// `session_library_test.dart`: the connection is released asynchronously,
  /// and Windows refuses to delete a file still held).
  Future<void> deleteWhenReleased(String path) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      try {
        File(path).deleteSync();
        return;
      } on FileSystemException {
        if (DateTime.now().isAfter(deadline)) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    appRouter.go('/sessions');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionIndexStoreProvider.overrideWithValue(
            MemorySessionIndexStore(),
          ),
        ],
        child: const PaceReaderApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Router<Object>)),
    );
  }

  /// [set]'s view, held alive while it resolves: the provider is
  /// auto-disposed, and nothing on screen may be watching it.
  Future<ComparisonView> viewOf(
    ProviderContainer container,
    ComparisonSet set,
  ) async {
    final subscription = container.listen(
      comparisonChartProvider(set).future,
      (_, _) {},
    );
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

  testWidgets("the fixture's course facts are the ones the widget tests "
      'serve', (tester) async {
    final facts = await readComparableFactsBriefly(
      const TelemetrySource.path('$_projectRoot/$_fixture'),
    );
    final course = facts.course;
    // `compare_harness.dart`'s `sebringCourse`.
    expect(course.wrapLength, closeTo(3083.313, 0.001));
    expect(course.wrapCount, 3);
    expect(course.sector1Station, closeTo(1029.435, 0.001));
    expect(course.sector2Station, closeTo(1572.549, 0.001));
    expect(course.pitLane, isEmpty);
  });

  testWidgets('a second Sebring School recording passes every gate; cleared '
      'and closed, its file deletes', (tester) async {
    final basePath = copy(_fixture, 'base.duckdb');
    final targetPath = copy(_second, 'target.duckdb');
    final base = TelemetrySource.path(basePath);
    final target = TelemetrySource.path(targetPath);
    final container = await pumpApp(tester);
    final import = container.read(sessionImportProvider.notifier);
    await import.open(base);
    await import.open(target, makeCurrent: false);
    await tester.pumpAndSettle();

    final baseCourse = await container.read(courseFactsProvider(base).future);
    final targetCourse = await container.read(
      courseFactsProvider(target).future,
    );
    // Every Sebring School file in the library measures 3083.31 m; the
    // station medians of these two differ by 0.42 and 0.22 m.
    expect(
      targetCourse.wrapLength! - baseCourse.wrapLength!,
      closeTo(0, CourseCheck.lengthTolerance),
    );
    final alignment = StationAlignment.between(baseCourse, targetCourse);
    expect(alignment.worstOffset!.abs(), lessThan(0.5));

    // Base: the fixture's lap 2 (1:04.497). Target: the second recording's
    // lap 3 (index 2, 1:04.201), its one lap with all three splits. Its best,
    // lap 2 (1:04.128), wrote S1+S2 as 0.0, which is checked below.
    final targetLaps = await container.read(lapsProvider(target).future);
    final targetLap = targetLaps.singleWhere((l) => l.index == 2);
    expect(targetLap.sectors.isComplete, isTrue);
    final set = ComparisonSet(LapRef(base, 1), LapRef(target, 2));
    container
        .read(comparisonWorkspaceProvider.notifier)
        .start(set.base, set.target);
    appRouter.go('/driver-comparison');
    await tester.pumpAndSettle();
    expect(find.byType(DriverComparisonScreen), findsOneWidget);

    final view = await viewOf(container, set);
    final comparison = view.chart!.comparison!;
    expect(view.course!.verdict, CourseVerdict.sameCourse);
    expect(comparison.alignment.aligned, isTrue);
    final check = comparison.check;
    expect(check.bothReanchored, isTrue);
    expect(check.worstLap!.abs(), lessThan(DeltaCheck.perLapLimit));
    expect(check.worstPair!.abs(), lessThan(DeltaCheck.pairLimit));
    expect(check.status, DeltaCheckStatus.passed);
    // "Passes every gate with no chip": nothing to warn about or tell apart.
    expect(
      view.chips.where((c) => c.tone != ChipTone.passed).map((c) => c.label),
      isEmpty,
    );
    expect(find.text('Delta'), findsOneWidget);
    debugPrint(
      'compare fixture pair: target lap ${targetLap.displayNumber} '
      '${targetLap.lapTimeSeconds}; pair ${check.pair}; '
      'worst lap ${check.worstLap}; alignment S1 ${alignment.sector1Offset} '
      'S2 ${alignment.sector2Offset}; final delta '
      '${comparison.delta!.finalDelta}',
    );

    // The best lap, whose S1+S2 the game wrote as 0.0: it keeps its Lap
    // event, and the pair is checked at the line and S1 within 30 ms.
    final best = targetLaps.bestLap!;
    expect(best.index, 1);
    final unanchored = (await viewOf(
      container,
      ComparisonSet(LapRef(base, 1), LapRef(target, best.index)),
    )).chart!.comparison!.check;
    expect(unanchored.target.reanchored, isFalse);
    expect(unanchored.pairBound, DeltaCheck.unanchoredPairLimit);
    expect(unanchored.pair.keys, [TimingLine.sector1, TimingLine.finish]);
    expect(unanchored.status, DeltaCheckStatus.passed);
    debugPrint('best lap, kept on its Lap event: pair ${unanchored.pair}');

    // Cleared from the Target and closed, the file lets go.
    container.read(comparisonWorkspaceProvider.notifier).clearTarget();
    await tester.pumpAndSettle();
    await container.read(openSessionsProvider.notifier).close(target);
    await tester.pumpAndSettle();
    await deleteWhenReleased(targetPath);
    expect(File(targetPath).existsSync(), isFalse);

    container.read(comparisonWorkspaceProvider.notifier).clear();
    await container.read(openSessionsProvider.notifier).close(base);
    await tester.pumpAndSettle();
    await deleteWhenReleased(basePath);
  });

  testWidgets(
    "[Lib] Paul Ricard 1A against 1A-V2 is refused before any lap read; "
    'Spa against Spa Endurance passes parts 1 and 2 as a layout variant',
    (tester) async {
      /// The first readable recording of each layout of [track] that ran a
      /// full lap, read briefly: open, read, dispose.
      Future<Map<String, (TelemetrySource, ComparableFile)>> byLayout(
        String track,
        int layouts,
      ) async {
        final found = <String, (TelemetrySource, ComparableFile)>{};
        final files =
            Directory(_telemetryFolder)
                .listSync()
                .whereType<File>()
                .map((f) => f.path)
                .where(
                  (path) =>
                      p.basename(path).startsWith('${track}_') &&
                      path.endsWith('.duckdb') &&
                      // The game may still be writing it.
                      !File('$path.wal').existsSync(),
                )
                .toList()
              ..sort();
        for (final path in files) {
          if (found.length == layouts) break;
          final source = TelemetrySource.path(path);
          final ComparableFile file;
          try {
            file = await readComparableFactsBriefly(source);
          } on Object {
            continue; // an empty or unreadable recording
          }
          if (file.course.wrapLength == null) continue;
          found.putIfAbsent(file.metadata.trackLayout, () => (source, file));
        }
        return found;
      }

      final ricard = await byLayout('Paul Ricard Circuit', 2);
      expect(ricard.keys.toSet(), {'Paul Ricard - 1A', 'Paul Ricard - 1A-V2'});
      final (aSource, a) = ricard['Paul Ricard - 1A']!;
      final (bSource, b) = ricard['Paul Ricard - 1A-V2']!;
      final ricardCheck = CourseCheck.of(
        base: a.metadata,
        baseCourse: a.course,
        target: b.metadata,
        targetCourse: b.course,
        sameFile: false,
      );
      expect(a.course.wrapLength, closeTo(5698.65, 0.5));
      expect(b.course.wrapLength, closeTo(5758.32, 0.5));
      expect(ricardCheck.verdict, CourseVerdict.differentLength);

      // Through the provider, with both files open (read-only): refused, and
      // no lap of either was read.
      final container = await pumpApp(tester);
      final import = container.read(sessionImportProvider.notifier);
      await import.open(aSource);
      await import.open(bSource, makeCurrent: false);
      final set = ComparisonSet(
        LapRef(aSource, a.laps.bestLap?.index ?? a.laps.last.index),
        LapRef(bSource, b.laps.bestLap?.index ?? b.laps.last.index),
      );
      final view = await viewOf(container, set);
      expect(view.refused, isTrue);
      expect(view.chart, isNull);
      for (final (source, file) in [(aSource, a), (bSource, b)]) {
        for (final lap in file.laps) {
          expect(
            container.exists(lapTelemetryProvider(source, lap.index)),
            isFalse,
            reason: '${source.label} lap ${lap.index} was read',
          );
        }
      }
      await container.read(openSessionsProvider.notifier).close(bSource);
      await container.read(openSessionsProvider.notifier).close(aSource);
      await tester.pumpAndSettle();

      final spa = await byLayout('Circuit de Spa-Francorchamps', 2);
      expect(spa.keys.toSet(), {
        'Circuit de Spa-Francorchamps',
        'Circuit de Spa-Francorchamps Endurance',
      });
      final (_, short) = spa['Circuit de Spa-Francorchamps']!;
      final (_, endurance) = spa['Circuit de Spa-Francorchamps Endurance']!;
      final spaCheck = CourseCheck.of(
        base: short.metadata,
        baseCourse: short.course,
        target: endurance.metadata,
        targetCourse: endurance.course,
        sameFile: false,
      );
      // One geometry under two names: the same length, the same lines.
      expect(
        (short.course.wrapLength! - endurance.course.wrapLength!).abs(),
        lessThan(CourseCheck.lengthTolerance),
      );
      // Part 3, the centre line, decides it once the laps are read: see
      // `lines_test.dart`, where the pair is compared.
      expect(spaCheck.verdict, CourseVerdict.layoutVariant);
      expect(spaCheck.refuses, isFalse);
      debugPrint(
        'library: Paul Ricard 1A ${a.course.wrapLength} vs 1A-V2 '
        '${b.course.wrapLength}; Spa ${short.course.wrapLength} vs '
        'Endurance ${endurance.course.wrapLength}, stations '
        '${StationAlignment.between(short.course, endurance.course).worstOffset}',
      );
    },
    skip: !Directory(_telemetryFolder).existsSync(),
  );
}
