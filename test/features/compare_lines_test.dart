// Lines and courses (comparison proposal §4 "Course" part 3, "Centre path",
// "Track Edge"; §6 "Line panel"; step 5), over the two real 5 Hz Sebring
// fixture laps: Base lap 2 (index 1) against Target lap 4 (index 3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/lines.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/features/driver_comparison/presentation/why_card.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/presentation/lap_view_panes.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _base = CompareFile('/lines/base.duckdb');
final _other = CompareFile(
  '/lines/other.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

/// Base's lap and the Target's lap in one frame, on one set of normals, as
/// Compare builds them.
(LapLine, LapLine) _lines(LapTelemetry base, LapTelemetry target) {
  final (b, t) = LapLine.pair(base, target, frame: LocalFrame.around(base)!);
  return (b!, t!);
}

ComparisonSet _pair(CompareFile base, CompareFile target) => ComparisonSet(
  LapRef(base.source, sebringLapIndex),
  LapRef(target.source, sebringLap3Index),
);

class _Setup {
  _Setup(this.container, this.reads, this.speedReads);

  final ProviderContainer container;
  final LapReadLog reads;
  final LapReadLog speedReads;

  Future<ComparisonView> view(ComparisonSet set) =>
      readFuture(container, comparisonChartProvider(set).future);

  Future<ComparisonSegments?> segments(ComparisonSet set) =>
      readFuture<ComparisonSegments?>(
        container,
        comparisonSegmentsProvider(set).future,
      );
}

_Setup _setup(List<CompareFile> files) {
  final reads = <(String, int)>[];
  final speedReads = <(String, int)>[];
  final container = ProviderContainer(
    overrides: compareOverrides(
      files: files,
      open: files,
      reads: reads,
      speedReads: speedReads,
    ),
  );
  addTearDown(container.dispose);
  return _Setup(container, reads, speedReads);
}

/// The panel stack's scroll view, of the several on screen.
final _stack = find
    .descendant(
      of: find.byType(LapPanelStack),
      matching: find.byType(Scrollable),
    )
    .first;

TracePanelSpec? _linePanel(ComparisonView view) =>
    view.chart!.panels.where((p) => p.role == ChannelRole.line).firstOrNull;

List<String> _titles(ComparisonView view) =>
    view.chart!.panels.map((p) => p.title).toList();

ComparabilityChip? _chip(ComparisonView view, String start) =>
    view.chips.where((c) => c.label.startsWith(start)).firstOrNull;

void main() {
  group('the centre path', () {
    test("two laps of one recording rebuild one centre path", () {
      final (base, target) = _lines(
        sebringLapTelemetry(),
        sebringLap3Telemetry(),
      );
      final centre = CentreComparison.between(base, target)!;
      // 5 Hz: the library's two-pass rms is 0.19 m at 10 Hz within a file.
      expect(centre.rms, closeTo(0.164, 0.005));
      expect(centre.max, lessThan(0.5));
      expect(centre.bins, greaterThan(600));
      expect(centre.sameCourse, isTrue);
      expect(centre.linesComparable, isTrue);
    });

    test('a course drawn 1 m to the north is the course, its lines not '
        'comparable', () {
      final moved = CompareFile('/lines/north.duckdb', northMetres: 1);
      final (base, target) = _lines(
        sebringLapTelemetry(),
        moved.telemetry(sebringLap3Index),
      );
      final centre = CentreComparison.between(base, target)!;
      expect(centre.rms, closeTo(1.0, 0.05));
      expect(centre.sameCourse, isTrue);
      expect(centre.linesComparable, isFalse);
    });

    test('200 m of the course 6 m to one side is another course', () {
      final variant = CompareFile(
        '/lines/variant.duckdb',
        sideways: (1400, 1600, 6),
      );
      final (base, target) = _lines(
        sebringLapTelemetry(),
        variant.telemetry(sebringLap3Index),
      );
      final centre = CentreComparison.between(base, target)!;
      expect(centre.max, closeTo(6, 0.5));
      expect(centre.maxStation, inInclusiveRange(1400, 1600));
      expect(centre.sameCourse, isFalse);
    });

    test('the pit lane is left out', () {
      final telemetry = sebringLapTelemetry();
      final frame = LocalFrame.around(telemetry)!;
      final whole = LapLine.of(telemetry, frame: frame)!;
      final start = telemetry.startSeconds;
      final pitted = LapLine.of(
        telemetry,
        frame: frame,
        pitLane: [PitInterval(start + 20, start + 30)],
      )!;
      expect(pitted.length, lessThan(whole.length));
      expect(
        pitted.times.where((t) => t > start + 20 && t < start + 30),
        isEmpty,
      );
      // Across the cut there is nothing to compare against.
      final cut = whole.stations[whole.times.indexWhere((t) => t > start + 25)];
      expect(pitted.pathLateralAt(cut), isNull);
      expect(pitted.centreAt(cut), isNull);
    });
  });

  group('the line', () {
    test(
      "at 814 m the Target is 3.1 m right of Base: the hairpin's inside",
      () {
        final (base, target) = _lines(
          sebringLapTelemetry(),
          sebringLap3Telemetry(),
        );
        // Native: Base −2.01 m, Target +1.07 m, +3.08 m.
        expect(base.pathLateralAt(814), closeTo(-1.92, 0.01));
        expect(target.pathLateralAt(814), closeTo(1.19, 0.01));
        expect(base.turnAt(814), TurnSide.right);
        expect(
          lineAt(base, target, 814),
          'Target 3.1 m further right, the inside of this right-hander',
        );
        final difference = pathLateralDifference(base, target)!;
        final axis = DistanceAxis.fromSeries(
          sebringLapTelemetry().lapDistance!,
        );
        final at = [
          for (var i = 0; i < difference.length; i++)
            (axis.distanceAt(difference.times[i]), difference.lows[i]),
        ].reduce((a, b) => (a.$1 - 814).abs() < (b.$1 - 814).abs() ? a : b);
        expect(at.$2, closeTo(3.1, 0.15));
      },
    );

    test('under 0.5 m, no side is stated', () {
      final (base, target) = _lines(
        sebringLapTelemetry(),
        sebringLap3Telemetry(),
      );
      expect(lineAt(base, target, 760), 'Target within 0.5 m of Base');
    });

    test('a straight has no inside', () {
      final (base, target) = _lines(
        sebringLapTelemetry(),
        sebringLap3Telemetry(),
      );
      // The run from the line to turn 1.
      expect(base.turnAt(150), isNull);
    });
  });

  group('track edges', () {
    test('two laps of one recording find the same edges', () {
      final (base, target) = _lines(
        sebringLapTelemetry(),
        sebringLap3Telemetry(),
      );
      final edges = TrackEdgeAgreement.between(base, target)!;
      expect(edges.matched, greaterThan(40));
      expect(edges.share, greaterThanOrEqualTo(0.85));
      expect(edges.agrees, isTrue);
    });

    test('edges a game update moved disagree everywhere', () {
      final moved = CompareFile('/lines/edges.duckdb', trackEdgeShift: 0.2);
      final (base, target) = _lines(
        sebringLapTelemetry(),
        moved.telemetry(sebringLap3Index),
      );
      final edges = TrackEdgeAgreement.between(base, target)!;
      expect(edges.share, 0);
      expect(edges.agrees, isFalse);
      expect(edges.differing, isNotEmpty);
    });
  });

  group('Compare', () {
    test('two files of one course: the Line panel after Steering', () async {
      final s = _setup([_base, _other]);
      final view = await s.view(_pair(_base, _other));
      final titles = _titles(view);
      expect(titles.indexOf('Line'), titles.indexOf('Steering') + 1);
      final panel = _linePanel(view)!;
      expect(panel.unit, 'm');
      final series = panel.series as DeltaSeriesPanel;
      expect(series.floorBand, lineFloor);
      expect(series.valueRange.min, lessThanOrEqualTo(-lineFloor));
      final centre = _chip(view, 'centre path')!;
      expect(centre.label, 'centre path 0.16 m');
      expect(centre.tone, ChipTone.passed);
      expect(_chip(view, 'track edges'), isNull);
      expect(view.line!.shown, isTrue);
    });

    test('edges that differ get a chip, and the Line panel stays', () async {
      final moved = CompareFile('/lines/edges.duckdb', trackEdgeShift: 0.2);
      final view = await _setup([_base, moved]).view(_pair(_base, moved));
      final chip = _chip(view, 'track edges differ')!;
      expect(chip.label, 'track edges differ (game update?)');
      expect(chip.tone, ChipTone.neutral);
      expect(chip.detail.first, startsWith('0% of '));
      expect(_linePanel(view), isNotNull);
    });

    test('centre paths 1 m apart hide the Line panel, and say why', () async {
      final moved = CompareFile('/lines/north.duckdb', northMetres: 1);
      final view = await _setup([_base, moved]).view(_pair(_base, moved));
      expect(view.refused, isFalse);
      expect(_linePanel(view), isNull);
      final chip = _chip(view, 'line hidden')!;
      expect(chip.label, 'line hidden: centre paths 1.02 m apart');
      expect(chip.tone, ChipTone.warning);
      expect(
        view.line!.withheld,
        "the two laps' centre paths run 1.02 m apart (rms), more than the "
        '0.5 m lines can be compared within',
      );
      // The delta does not depend on the line, and is drawn.
      expect(view.chart!.comparison!.delta, isNotNull);
    });

    test('200 m 6 m to one side: refused before anything is drawn', () async {
      final variant = CompareFile(
        '/lines/variant.duckdb',
        metadata: sebringMetadata.copyWith(
          trackLayout: 'Sebring School Circuit Endurance',
        ),
        sideways: (1400, 1600, 6),
      );
      final s = _setup([_base, variant]);
      final set = _pair(_base, variant);
      final view = await s.view(set);
      expect(view.refused, isTrue);
      expect(view.course!.verdict, CourseVerdict.differentCentreLine);
      expect(
        view.course!.reason,
        matches(
          RegExp(
            r'^a different course: the centre lines part by up to '
            r'[56]\.\d m at 1[45]\d\d m$',
          ),
        ),
      );
      expect(view.chart, isNull);
      expect(await s.segments(set), isNull);
      expect(s.speedReads, isEmpty);
    });

    test('a variant without Path Lateral is refused, unchecked', () async {
      final variant = CompareFile(
        '/lines/blind.duckdb',
        metadata: sebringMetadata.copyWith(
          trackLayout: 'Sebring School Circuit Endurance',
        ),
        withoutPathLateral: true,
      );
      final view = await _setup([_base, variant]).view(_pair(_base, variant));
      expect(view.course!.verdict, CourseVerdict.centreLineUnchecked);
      expect(view.refused, isTrue);
    });

    test('one layout without Path Lateral: compared, no Line panel', () async {
      final blind = CompareFile(
        '/lines/blind.duckdb',
        withoutPathLateral: true,
      );
      final view = await _setup([_base, blind]).view(_pair(_base, blind));
      expect(view.refused, isFalse);
      expect(view.course!.verdict, CourseVerdict.sameCourse);
      expect(_linePanel(view), isNull);
      expect(
        view.line!.withheld,
        "the Target's lap recorded no GPS or Path Lateral",
      );
    });

    test(
      "a variant is compared on segments cut from Base's layout only",
      () async {
        final variant = CompareFile(
          '/lines/variant.duckdb',
          metadata: sebringMetadata.copyWith(
            recordingTime: '2026-07-07T05_57_04Z',
            trackLayout: 'Sebring School Circuit Endurance',
          ),
        );
        final s = _setup([_base, variant]);
        final segments = (await s.segments(_pair(_base, variant)))!;
        // The Target's lap 4 would be canonical for one layout; here only
        // Base's file is read, and its own lap 4 is.
        expect(
          segments.table!.canonical.recording,
          _base.metadata.recordingIdentity,
        );
        expect(segments.table!.key, TrackKey.of(sebringMetadata));
        expect(s.speedReads.map((r) => r.$1).toSet(), {_base.path});
      },
    );

    test('one file: the Line panel, without the gates it shares', () async {
      final s = _setup([_base]);
      final view = await s.view(
        ComparisonSet(
          LapRef(_base.source, sebringLapIndex),
          LapRef(_base.source, sebringLap3Index),
        ),
      );
      expect(_linePanel(view), isNotNull);
      expect(view.line!.centre, isNull);
      expect(view.line!.trackEdge, isNull);
      expect(_chip(view, 'centre path'), isNull);
    });

    test("raw: each lap's own Path Lateral", () async {
      final s = _setup([_base, _other]);
      s.container.read(linePanelRawProvider.notifier).toggle();
      final view = await s.view(_pair(_base, _other));
      final series = _linePanel(view)!.series as LineSeries;
      expect(series.reference, isNotNull);
      // Base at the hairpin's apex, as recorded: left of the centre path
      // (the readout is the nearest 5 Hz sample's).
      expect(view.chart!.axis, TraceAxis.distance);
      expect(series.valueAt(814), closeTo(-2.0, 0.5));
      expect(series.referenceValueAt(814), closeTo(1.2, 0.5));
    });
  });

  group('on screen', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      List<CompareFile> files,
    ) async {
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: compareOverrides(files: files, open: files),
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Router<Object>)),
      );
      final set = _pair(files.first, files.last);
      container
          .read(comparisonWorkspaceProvider.notifier)
          .start(set.base, set.target);
      await tester.pumpAndSettle();
      return container;
    }

    String whyText(WidgetTester tester) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(WhyCard),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join('\n');

    testWidgets("the Why card states the line at Base's slowest point", (
      tester,
    ) async {
      await pump(tester, [_base, _other]);
      expect(
        whyText(tester),
        contains(
          // Base's slowest 5 Hz sample in the corner (813 m natively).
          'Line at 810 m: Target 3.1 m further right, the inside of this '
          'right-hander.',
        ),
      );
    });

    testWidgets('the Line panel switches to raw Path Lateral and back', (
      tester,
    ) async {
      final c = await pump(tester, [_base, _other]);
      final raw = find.text('Show raw Path Lateral');
      await tester.scrollUntilVisible(raw, 200, scrollable: _stack);
      await tester.tap(raw);
      await tester.pumpAndSettle();
      expect(c.read(linePanelRawProvider), isTrue);
      expect(find.text('Show the difference'), findsOneWidget);
      await tester.tap(find.text('Show the difference'));
      await tester.pumpAndSettle();
      expect(c.read(linePanelRawProvider), isFalse);
    });

    testWidgets('a hidden Line panel says why, where it would be', (
      tester,
    ) async {
      final moved = CompareFile('/lines/north.duckdb', northMetres: 1);
      await pump(tester, [_base, moved]);
      final note = find.textContaining('No Line panel: the two laps');
      await tester.scrollUntilVisible(note, 200, scrollable: _stack);
      expect(note, findsOneWidget);
      expect(
        whyText(tester),
        contains("Line not compared: the two laps' centre paths run 1.02 m"),
      );
      expect(find.text('Show raw Path Lateral'), findsNothing);
    });

    testWidgets('a course that parts by 6 m is refused, and says where', (
      tester,
    ) async {
      final variant = CompareFile(
        '/lines/variant.duckdb',
        sideways: (1400, 1600, 6),
      );
      await pump(tester, [_base, variant]);
      expect(find.text('These laps cannot be compared'), findsOneWidget);
      expect(
        find.textContaining(
          'The Target is from a different course: the centre lines part by',
        ),
        findsOneWidget,
      );
    });
  });
}
