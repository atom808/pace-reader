// The segment navigator and the Why card on the Compare screen (comparison
// proposal §3, §5, step 4), over the two real 5 Hz Sebring fixture laps:
// Base lap 2 (index 1) against Target lap 4 (index 3) from another file.

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_losses.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/features/driver_comparison/presentation/why_card.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _a = CompareFile('/nav/a.duckdb');
final _b = CompareFile(
  '/nav/b.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

final _pair = ComparisonSet(
  LapRef(_a.source, sebringLapIndex),
  LapRef(_b.source, sebringLap3Index),
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  ComparisonSet? set,
  List<CompareFile>? files,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final router = GoRouter(
    initialLocation: '/driver-comparison',
    routes: [
      GoRoute(
        path: '/driver-comparison',
        builder: (context, state) => const DriverComparisonScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  final served = files ?? [_a, _b];
  await tester.pumpWidget(
    ProviderScope(
      overrides: compareOverrides(files: served, open: served),
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Router<Object>)),
  );
  final chosen = set ?? _pair;
  container
      .read(comparisonWorkspaceProvider.notifier)
      .start(chosen.base, chosen.target);
  await tester.pumpAndSettle();
  return container;
}

/// The navigator's caption: the one line that names the selected stop.
String _caption(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .firstWhere(
      (s) =>
          s.startsWith('Seg ') && s.contains(' vs Target') ||
          s.startsWith('S') && s.contains(' vs Target ·') ||
          s.startsWith('Recap'),
    );

ChartViewport? _viewport(ProviderContainer c) =>
    c.read(chartSyncProvider).viewport;

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

String _whyText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(WhyCard), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join('\n');

void main() {
  testWidgets('opens on the worst segment, selected but not zoomed', (
    tester,
  ) async {
    final c = await _pump(tester);
    expect(
      _caption(tester),
      'Seg 3 · 698–1156 m · Base +0.296 s vs Target · most lost, 1 of 5',
    );
    expect(_viewport(c), isNull);
    expect(
      find.bySemanticsLabel(
        'Segment 3, Base lost 0.296 seconds to the Target, most lost',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Segments cut from Race'), findsOneWidget);
  });

  testWidgets('→ walks the losses, then the level segments that swing, then '
      'the recap, and holds there', (tester) async {
    await _pump(tester);
    final captions = <String>[];
    for (var i = 0; i < 6; i++) {
      await _key(tester, LogicalKeyboardKey.arrowRight);
      captions.add(_caption(tester));
    }
    expect(captions, [
      startsWith('Seg 4 · '),
      startsWith('Seg 1 · '),
      // Level overall: +0.002 s net, with legs of +0.082 and −0.080 s.
      allOf(startsWith('Seg 2 · '), contains('level overall, but…, 4 of 5')),
      allOf(startsWith('Seg 6 · '), contains('5 of 5')),
      'Recap · Base +0.468 s vs Target over the lap',
      'Recap · Base +0.468 s vs Target over the lap',
    ]);
    await _key(tester, LogicalKeyboardKey.arrowLeft);
    expect(_caption(tester), startsWith('Seg 6 · '));
  });

  testWidgets('`]` steps on a Spanish layout too, where it takes AltGr', (
    tester,
  ) async {
    await _pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight, character: ']');
    await tester.pumpAndSettle();
    expect(_caption(tester), startsWith('Seg 4 · '));

    // AltGr reaches Windows apps as Ctrl+Alt. Spanish `]` is AltGr on the
    // `+` key and `[` AltGr on the grave-accent key: the keys US `]` and
    // `[` sit on.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
    await tester.sendKeyEvent(
      LogicalKeyboardKey.add,
      physicalKey: PhysicalKeyboardKey.bracketRight,
      character: ']',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_caption(tester), startsWith('Seg 1 · '));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altRight);
    await tester.sendKeyEvent(
      LogicalKeyboardKey.backquote,
      physicalKey: PhysicalKeyboardKey.bracketLeft,
      character: '[',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(_caption(tester), startsWith('Seg 4 · '));
  });

  testWidgets('Enter zooms onto the segment, → carries the zoom, 0 and Esc '
      'return to the whole lap', (tester) async {
    final c = await _pump(tester);
    final table = c.read(segmentTableStoreProvider).values.single;
    final seg3 = table.segments[2];
    final seg4 = table.segments[3];

    await _key(tester, LogicalKeyboardKey.enter);
    expect(_viewport(c)!.start, closeTo(seg3.start - 20, 1e-9));
    expect(_viewport(c)!.end, closeTo(seg3.end + 20, 1e-9));

    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_viewport(c)!.start, closeTo(seg4.start - 20, 1e-9));

    await _key(tester, LogicalKeyboardKey.digit0);
    expect(_viewport(c), isNull);
    expect(_caption(tester), startsWith('Seg 4 · '));

    // Unzoomed, stepping leaves the whole lap in view.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_viewport(c), isNull);

    await _key(tester, LogicalKeyboardKey.enter);
    expect(_viewport(c), isNotNull);
    await _key(tester, LogicalKeyboardKey.escape);
    expect(_viewport(c), isNull);
  });

  testWidgets('a click on a segment selects and zooms it', (tester) async {
    final c = await _pump(tester);
    await tester.tap(
      find.bySemanticsLabel(
        'Segment 5, Base gained 0.039 seconds on the Target',
      ),
    );
    await tester.pumpAndSettle();
    expect(_caption(tester), startsWith('Seg 5 · '));
    expect(_viewport(c), isNotNull);
  });

  testWidgets("the Why card states the hairpin's turn as movement, never as "
      'a position', (tester) async {
    final c = await _pump(tester);
    final why = _whyText(tester);
    expect(
      why,
      contains(
        'Gained 0.269 s from 698 to 795 m, then lost 0.565 s to 1156 m '
        '(net +0.296)',
      ),
    );
    expect(why, isNot(contains('ahead')));
    expect(why, isNot(contains('behind')));

    // The movement is the Delta trace's own, between the segment's start and
    // the turn: there the trace reads about −0.16 s, a figure the card never
    // states.
    final view = await readFuture(c, comparisonChartProvider(_pair).future);
    final delta = view.chart!.comparison!.delta!;
    final segments = (await readFuture<ComparisonSegments?>(
      c,
      comparisonSegmentsProvider(_pair).future,
    ))!;
    final seg3 = segments.segments!.stretches[2];
    final turn = seg3.turn!;
    expect(
      delta.deltaAt(turn.station)! - delta.deltaAt(seg3.segment.start)!,
      closeTo(turn.first, 0.003),
    );
    expect(
      why,
      isNot(contains(delta.deltaAt(turn.station)!.toStringAsFixed(3))),
    );
  });

  testWidgets("Seg 1 says it carries the previous lap's exit", (tester) async {
    await _pump(tester);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_caption(tester), startsWith('Seg 1 · '));
    expect(
      _whyText(tester),
      contains("Starts at the line: carries the previous lap's exit."),
    );
  });

  testWidgets("Sectors: the game's splits, zoomed to Base's sector lines", (
    tester,
  ) async {
    final c = await _pump(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<SegmentMode>),
        matching: find.text('Sectors'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _caption(tester),
      'S1 · 0–1029 m · Base +0.362 s vs Target · most lost, 1 of 3',
    );
    expect(_whyText(tester), contains("Lost 0.362 s in S1, by the game's own"));

    await _key(tester, LogicalKeyboardKey.enter);
    final window = _viewport(c)!;
    expect(window.start, lessThanOrEqualTo(10));
    expect(window.end, greaterThanOrEqualTo(sebringCourse.sector1Station!));
  });

  testWidgets('Base level everywhere: a banner, and the suggestions', (
    tester,
  ) async {
    await _pump(
      tester,
      set: ComparisonSet(
        LapRef(_b.source, sebringLap3Index),
        LapRef(_a.source, sebringLap3Index),
      ),
    );
    expect(
      find.text('Base is level with or ahead of the Target everywhere'),
      findsOneWidget,
    );
    expect(
      find.text('Base loses nowhere: choose a stretch, or step with →.'),
      findsOneWidget,
    );
  });

  testWidgets('sector lines 8 m apart: no segments, and why; Sectors stay', (
    tester,
  ) async {
    final far = CompareFile('/nav/far.duckdb', stationOffset: 8);
    await _pump(
      tester,
      files: [_a, far],
      set: ComparisonSet(
        LapRef(_a.source, sebringLapIndex),
        LapRef(far.source, sebringLap3Index),
      ),
    );
    expect(
      find.text(
        'No segments: they are measured on the delta, and it is withheld.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<SegmentMode>),
        matching: find.text('Sectors'),
      ),
    );
    await tester.pumpAndSettle();
    // The copy's splits are timed at its own lines, 8 m on: S3 loses most.
    expect(_caption(tester), startsWith('S3 · '));
  });
}
