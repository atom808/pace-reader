// Compare's map, ghost and Time axis readout (comparison proposal §6, step
// 6), over the two real 5 Hz Sebring fixture laps: Base lap 2 (index 1)
// against Target lap 4 (index 3).

import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/presentation/compare_map_pane.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _base = CompareFile('/map/base.duckdb');
final _other = CompareFile(
  '/map/other.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

ComparisonSet _pair(CompareFile base, CompareFile target) => ComparisonSet(
  LapRef(base.source, sebringLapIndex),
  LapRef(target.source, sebringLap3Index),
);

class _Setup {
  _Setup(this.container);

  final ProviderContainer container;

  Future<ComparisonView> view(ComparisonSet set) =>
      readFuture(container, comparisonChartProvider(set).future);

  Future<ComparisonSegments?> segments(ComparisonSet set) =>
      readFuture<ComparisonSegments?>(
        container,
        comparisonSegmentsProvider(set).future,
      );
}

_Setup _setup(List<CompareFile> files, {TraceAxis axis = TraceAxis.time}) {
  final container = ProviderContainer(
    overrides: compareOverrides(files: files, open: files),
  );
  addTearDown(container.dispose);
  container.read(chartSyncProvider.notifier).setAxis(axis);
  return _Setup(container);
}

/// Base's session seconds at τ, from its re-anchored start.
double _at(ComparisonView view, double tau) =>
    view.chart!.comparison!.check.base.startSeconds + tau;

double _median(List<double> values) =>
    (Float64List.fromList(values)..sort())[values.length ~/ 2];

void main() {
  group('one frame for both laps', () {
    test("the Target sits on Base's origin: 0.42 m apart at equal Lap Dist, "
        'against 2.65 m about its own centroid', () async {
      final view = await _setup([_base, _other]).view(_pair(_base, _other));
      final map = view.map!;
      final own = TrackPath.build(
        latitude: sebringLap3Telemetry().latitude!,
        longitude: sebringLap3Telemetry().longitude!,
        axis: TraceAxis.time,
        distanceAxis: view.chart!.comparison!.referenceAxis,
      );
      final shared = <double>[];
      final separate = <double>[];
      final base = map.base;
      for (var i = 0; i < base.length; i++) {
        final station = base.stations![i];
        final onShared = map.target!.positionAtStation(station);
        final onOwn = own.positionAtStation(station);
        if (onShared != null) {
          shared.add((onShared - base.projection.points[i]).distance);
        }
        if (onOwn != null) {
          separate.add((onOwn - base.projection.points[i]).distance);
        }
      }
      expect(_median(shared), closeTo(0.42, 0.02));
      expect(_median(shared), lessThan(1));
      expect(_median(separate), closeTo(2.65, 0.05));
    });

    test("the whole-lap map is fitted to both laps' combined extent", () async {
      final view = await _setup([_base, _other]).view(_pair(_base, _other));
      final map = view.map!;
      expect(
        map.overview,
        map.base.projection.boundsMetres.expandToInclude(
          map.target!.projection.boundsMetres,
        ),
      );
    });
  });

  group('the ghost and the readout', () {
    test('at τ = 20 and 30 s the Target is 7.37 and 21.0 m ahead, and Δ is '
        '+0.264 s at 20 s', () async {
      final view = await _setup([_base, _other]).view(_pair(_base, _other));
      final map = view.map!;
      final at20 = map.readoutAt(_at(view, 20));
      final at30 = map.readoutAt(_at(view, 30));
      // §6's figures, within the step's bounds. On re-anchored starts
      // (step 3) they read 7.61 m, 21.32 m and +0.270 s.
      expect(at20.gap, closeTo(7.37, 0.5));
      expect(at30.gap, closeTo(21.0, 0.5));
      expect(at20.delta, closeTo(0.264, 0.01));
      expect(at20.tau, closeTo(20, 1e-9));
      expect(
        at20.text,
        "τ 0:20.000 · Δ +0.270 s at Base's position · Target 7.6 m ahead",
      );

      var peak = double.negativeInfinity;
      var lowest = double.infinity;
      for (var tau = 0.0; tau < 64; tau += 0.05) {
        final gap = map.readoutAt(_at(view, tau)).gap;
        if (gap == null) continue;
        peak = gap > peak ? gap : peak;
        lowest = gap < lowest ? gap : lowest;
      }
      expect(peak, closeTo(33.5, 0.5));
      expect(lowest, closeTo(-3.61, 0.5));
    });

    test(
      "the gap is the two laps' Lap Dist at one τ, never Δ × speed",
      () async {
        final fast = CompareFile(
          '/map/fast.duckdb',
          metadata: _other.metadata,
          speedScale: 2,
        );
        final setup = _setup([_base, _other, fast]);
        final view = await setup.view(_pair(_base, _other));
        final doubled = await setup.view(_pair(_base, fast));
        final comparison = view.chart!.comparison!;
        final baseAxis = view.chart!.distanceAxis!;
        final targetAxis = comparison.referenceAxis!;
        for (var tau = 1.0; tau < 60; tau += 2.5) {
          final t = _at(view, tau);
          final readout = view.map!.readoutAt(t);
          expect(
            readout.gap,
            closeTo(
              targetAxis.distanceAt(t - comparison.timeShift) -
                  baseAxis.distanceAt(t),
              1e-9,
            ),
          );
          // A speed channel twice the truth changes nothing.
          final other = doubled.map!.readoutAt(t);
          expect(other.gap, readout.gap);
          expect(other.delta, readout.delta);
        }
      },
    );

    test(
      'the Delta panel reads at the cursor what the readout states',
      () async {
        final view = await _setup([_base, _other]).view(_pair(_base, _other));
        final map = view.map!;
        final delta = view.chart!.panels.firstWhere(
          (p) => p.role == ChannelRole.delta,
        );
        for (final tau in [3.31, 12.717, 20.0, 41.05, 55.5]) {
          final t = _at(view, tau);
          expect(
            delta.series.valueAt(t),
            closeTo(map.readoutAt(t).delta!, 1e-9),
            reason: 'τ $tau',
          );
        }
      },
    );

    test("the ghost is the Target's own position at the same τ", () async {
      final view = await _setup([_base, _other]).view(_pair(_base, _other));
      final map = view.map!;
      final t = _at(view, 20);
      expect(map.ghostAt(t), map.target!.positionAt(t));
      expect(map.ghostAt(t), isNotNull);
      expect(map.ghostWithheld, isNull);
    });

    test('off either lap there is no gap and no ghost', () async {
      final view = await _setup([_base, _other]).view(_pair(_base, _other));
      final map = view.map!;
      final before = _at(view, -5);
      expect(map.readoutAt(before).gap, isNull);
      expect(map.ghostAt(before), isNull);
      // The Target is the quicker lap: 0.47 s after it crossed the line,
      // Base is still on its own.
      final after = _at(view, sebringLap3TimeSeconds + 0.3);
      expect(map.readoutAt(after).gap, isNull);
    });

    test('sector lines 8 m apart withhold the ghost, and say why', () async {
      final plus8 = CompareFile('/map/plus8.duckdb', stationOffset: 8);
      final view = await _setup([_base, plus8]).view(_pair(_base, plus8));
      final map = view.map!;
      expect(map.ghostWithheld, contains('8.0 m apart'));
      expect(map.ghostAt(_at(view, 20)), isNull);
      expect(map.readoutAt(_at(view, 20)).gap, isNull);
    });
  });

  group("the centre gate's fallback", () {
    test(
      'GPS moved 6 m along the whole lap is another course (part 3)',
      () async {
        final north6 = CompareFile('/map/north6.duckdb', northMetres: 6);
        final view = await _setup([_base, north6]).view(_pair(_base, north6));
        expect(view.refused, isTrue);
        expect(view.course!.verdict, CourseVerdict.differentCentreLine);
        expect(view.map, isNull);
      },
    );

    test("0.8 m fails only the centre gate: no Target line, and the Target "
        "marked on Base's at its own Lap Dist", () async {
      final north = CompareFile('/map/north08.duckdb', northMetres: 0.8);
      final view = await _setup([_base, north]).view(_pair(_base, north));
      expect(view.course!.verdict, CourseVerdict.sameCourse);
      expect(view.line!.withheld, contains('centre paths run'));
      final map = view.map!;
      expect(map.target, isNull);
      expect(map.targetHidden, startsWith("The Target's line is not drawn: "));
      expect(map.targetHidden, contains("marked on Base's line"));
      expect(map.overview, map.base.projection.boundsMetres);
      for (final tau in [5.0, 20.0, 40.0]) {
        final t = _at(view, tau);
        final station = map.targetStationAt(t)!;
        expect(map.ghostAt(t), map.base.positionAtStation(station));
      }
      // The readout does not depend on where the line is drawn.
      final view0 = await _setup([_base, _other]).view(_pair(_base, _other));
      expect(
        map.readoutAt(_at(view, 20)).gap,
        closeTo(view0.map!.readoutAt(_at(view0, 20)).gap!, 1e-9),
      );
    });
  });

  group('segment fit', () {
    test(
      'a stretch fits with its ghost; past 3× it stays on the stretch',
      () async {
        final setup = _setup([_base, _other]);
        final set = _pair(_base, _other);
        final view = await setup.view(set);
        final segments = (await setup.segments(set))!;
        final map = view.map!;
        final seg3 = segments.segments!.byNumber(3)!.segment;
        final clock = segments.baseClock!;
        final stretch = map.base.boundsBetweenStations(seg3.start, seg3.end)!;

        final alone = map.fitFor(seg3.start, seg3.end)!;
        expect(alone.contains(stretch.topLeft), isTrue);
        expect(alone.contains(stretch.bottomRight), isTrue);

        final window = (from: clock.at(seg3.start), to: clock.at(seg3.end));
        final withGhost = map.fitFor(seg3.start, seg3.end, window: window)!;
        final ghost = map.target!.boundsBetween(window.from, window.to)!;
        expect(withGhost.contains(ghost.topLeft), isTrue);
        expect(withGhost.contains(ghost.bottomRight), isTrue);
        expect(withGhost.contains(stretch.center), isTrue);

        // A window over most of the lap would zoom out far past 3×: the fit
        // stays on the stretch, and the chevron carries the gap.
        final far = map.fitFor(
          seg3.start,
          seg3.end,
          window: (from: clock.at(seg3.start), to: clock.at(2400)),
        );
        expect(far, alone);
      },
    );
  });

  group('on screen', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      List<CompareFile> files, {
      TraceAxis axis = TraceAxis.time,
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
      container.read(chartSyncProvider.notifier).setAxis(axis);
      final set = _pair(files.first, files.last);
      container
          .read(comparisonWorkspaceProvider.notifier)
          .start(set.base, set.target);
      await tester.pumpAndSettle();
      return container;
    }

    TrackMapView mapView(WidgetTester tester) =>
        tester.widget<TrackMapView>(find.byType(TrackMapView));

    T painter<T extends CustomPainter>(WidgetTester tester) => tester
        .widgetList<CustomPaint>(
          find.descendant(
            of: find.byType(TrackMapView),
            matching: find.byType(CustomPaint),
          ),
        )
        .map((p) => p.painter)
        .whereType<T>()
        .single;

    FilterChip ghostToggle(WidgetTester tester) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Ghost'));

    testWidgets('both laps on the map, the segments numbered, the worst '
        'ringed', (tester) async {
      await pump(tester, [_base, _other]);
      final map = mapView(tester);
      expect(map.reference, isNotNull);
      expect(map.frame, isNotNull);
      expect(map.view, isNull);
      expect(map.labels.map((l) => l.text), ['1', '2', '3', '4', '5', '6']);
      expect(map.labels.where((l) => l.ringed).single.text, '3');
      // Seg 3 is selected on open: cased, not yet fitted.
      expect(map.highlight, isNotNull);
      expect(find.textContaining('Target dotted.'), findsOneWidget);
    });

    testWidgets('the ghost toggle is off on the Distance axis, and says why', (
      tester,
    ) async {
      final container = await pump(tester, [
        _base,
        _other,
      ], axis: TraceAxis.distance);
      expect(ghostToggle(tester).onSelected, isNull);
      expect(ghostToggle(tester).selected, isFalse);
      expect(find.byTooltip(CompareMapPane.distanceAxisGhost), findsOneWidget);
      expect(mapView(tester).ghost, isNull);
      expect(find.byKey(const ValueKey('time-readout')), findsNothing);

      container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
      await tester.pumpAndSettle();
      expect(ghostToggle(tester).onSelected, isNotNull);
      expect(ghostToggle(tester).selected, isTrue);
      expect(mapView(tester).ghost, isNotNull);

      await tester.tap(find.widgetWithText(FilterChip, 'Ghost'));
      await tester.pumpAndSettle();
      expect(mapView(tester).ghost, isNull);
      expect(ghostToggle(tester).selected, isFalse);
    });

    testWidgets('the readout under the stack follows the cursor', (
      tester,
    ) async {
      final container = await pump(tester, [_base, _other]);
      final readout = find.byKey(const ValueKey('time-readout'));
      expect(
        tester.widget<Text>(readout).data,
        startsWith('Time axis: point at the traces'),
      );
      final view = await readFuture(
        container,
        comparisonChartProvider(_pair(_base, _other)).future,
      );
      container.read(chartSyncProvider.notifier).setCursor(_at(view, 20));
      await tester.pump();
      expect(
        tester.widget<Text>(readout).data,
        "τ 0:20.000 · Δ +0.270 s at Base's position · Target 7.6 m ahead",
      );
    });

    testWidgets('a scrub repaints the marks and leaves the map alone', (
      tester,
    ) async {
      final container = await pump(tester, [_base, _other]);
      final sync = container.read(chartSyncProvider.notifier);
      final view = await readFuture(
        container,
        comparisonChartProvider(_pair(_base, _other)).future,
      );
      // Zoomed onto the selected segment, as Enter does.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final first = painter<TrackMapPainter>(tester);
      expect(first.view, isNotNull);
      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(TrackMapView),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      final fit = trackMapFit(first.path, first.view, size);

      final marks = <Offset?>[];
      for (final tau in [24.0, 26.0, 28.0, 30.0, 32.0]) {
        sync.setCursor(_at(view, tau));
        await tester.pump();
        final now = painter<TrackMapPainter>(tester);
        expect(now.shouldRepaint(first), isFalse, reason: 'τ $tau');
        expect(identical(now.path, first.path), isTrue);
        expect(trackMapFit(now.path, now.view, size), fit);
        marks.add(painter<TrackCursorPainter>(tester).ghost);
      }
      expect(marks.toSet(), hasLength(marks.length));

      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.pumpAndSettle();
      expect(painter<TrackMapPainter>(tester).view, mapView(tester).frame);
      expect(mapView(tester).view, isNull);
    });

    testWidgets("past the centre gate the caption says the Target is marked "
        "on Base's line", (tester) async {
      final north = CompareFile('/map/north08.duckdb', northMetres: 0.8);
      await pump(tester, [_base, north]);
      expect(mapView(tester).reference, isNull);
      expect(
        find.textContaining("The Target's line is not drawn: "),
        findsOneWidget,
      );
      expect(mapView(tester).ghost, isNotNull);
    });
  });
}
