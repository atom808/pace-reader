// Widget tests for the lap analysis screen (SPEC.md §8.3, §12: "widget tests
// for individual screens with Riverpod provider overrides supplying fixture
// data, no real DB needed").
//
// These are worth having specifically because the lap table is where the
// §8.3.1 corrections become visible to a user: a regression there shows up as
// a plausible-looking number, not as a crash. The trend chart and incident
// marks added in v0.11 are fed the real Sebring Race laps and its real impact
// events; the yellow-flag and wheel cases are *constructed*, because no
// recording holds either (see `lap_incidents_test.dart`).

import 'dart:async';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';
import 'package:pace_reader/features/lap_analysis/presentation/lap_analysis_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

import '../fixtures/lap_incidents.dart';
import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

/// The real Sebring Race laps 0-4, as the repository would map them.
List<Lap> _realLaps() {
  Lap lap(
    int index,
    double start,
    double? end,
    double? time,
    double? s1,
    double? s2cum,
  ) => Lap(
    index: index,
    startSeconds: start,
    endSeconds: end,
    lapTimeSeconds: time,
    sectors: SectorTimes.fromCumulative(
      sector1: s1,
      sector2Cumulative: s2cum,
      lapTimeSeconds: time,
    ),
  );

  return [
    lap(0, 23.5975, 195.82, 71.24098205566406, 29.218246459960938, 42.20904541015625),
    lap(1, 195.82, 260.32, 64.49739074707031, 23.346588134765625, 36.260711669921875),
    lap(2, 260.32, 324.88, 64.57025146484375, 23.408477783203125, null),
    lap(3, 324.88, 388.92, 64.02963256835938, 22.9844970703125, 35.852996826171875),
    lap(4, 388.92, null, null, null, null),
  ];
}

/// The events the app reads from the real Race, cut into its real laps.
SessionIncidents _raceIncidents() {
  final events = sebringRaceIncidents();
  return SessionIncidents.derive(
    sebringRaceLaps(),
    impact: events.impact,
    yellowFlag: events.yellowFlag,
    wheelsDetached: events.wheelsDetached,
  );
}

/// Pumps the screen and returns its container, for reading the providers the
/// screen writes to.
Future<ProviderContainer> _pumpLapScreen(
  WidgetTester tester,
  List<Lap> laps, {
  Object? incidents,
  Size size = const Size(1400, 1900),
  bool settle = true,
  bool disableAnimations = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        lapsProvider(_source).overrideWith((ref) async => laps),
        sessionIncidentsProvider(_source).overrideWith(
          (ref) => switch (incidents) {
            final Future<SessionIncidents> f => f,
            final SessionIncidents s => Future.value(s),
            null => Future.value(const SessionIncidents()),
            final Object e => Future<SessionIncidents>.error(e),
          },
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: const LapAnalysisScreen(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(LapAnalysisScreen)));
}

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

PerLapBarChart _chart(WidgetTester tester) =>
    tester.widget<PerLapBarChart>(find.byType(PerLapBarChart));

/// [finder] among the table's own cells — the chart's key reuses the same
/// words, which is what a whole-screen `find.text` would also count.
Finder _inTable(Finder finder) =>
    find.descendant(of: find.byType(DataTable), matching: finder);

Finder _tooltipContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is Tooltip && (widget.message ?? '').contains(text),
);

/// The table's row for lap [displayNumber], via its first cell.
DataRow _row(WidgetTester tester, int displayNumber) {
  final table = tester.widget<DataTable>(find.byType(DataTable));
  return table.rows[displayNumber - 1];
}

void main() {
  group('the lap table', () {
    testWidgets('renders the corrected sector splits, not the cumulative values',
        (tester) async {
      await _pumpLapScreen(tester, _realLaps());

      // Lap 1's raw values are S1 23.347 and a *cumulative* 36.261. The table
      // must show S2 as a duration (12.914) and derive S3 (28.237) — the old
      // formula would have shown 4.890 for S3.
      expect(find.text('23.347'), findsWidgets);
      expect(find.text('12.914'), findsOneWidget);
      expect(find.text('28.237'), findsOneWidget);
      expect(find.text('36.261'), findsNothing,
          reason: 'the cumulative split must never be shown as a sector time');
      expect(find.text('4.890'), findsNothing,
          reason: 'this is what the pre-v0.7 formula produced for S3');
    });

    testWidgets('numbers laps from 1, never 0', (tester) async {
      await _pumpLapScreen(tester, _realLaps());
      // Five laps, indices 0..4, must display as 1..5.
      for (final n in ['1', '2', '3', '4', '5']) {
        expect(find.text(n), findsWidgets, reason: 'lap $n should be listed');
      }
    });

    testWidgets('marks the laps that are not comparable instead of hiding them',
        (tester) async {
      await _pumpLapScreen(tester, _realLaps());

      // All five rows are present, each odd one labelled with why.
      expect(find.text('out lap'), findsOneWidget);
      expect(find.text('partial sectors'), findsOneWidget);
      expect(find.text('incomplete'), findsOneWidget);
    });

    testWidgets('shows the best lap time and deltas against it', (tester) async {
      await _pumpLapScreen(tester, _realLaps());

      // Lap 4 (1:04.030) is the best: once in the fastest-lap tile, once in
      // the table. Lap 2 is +0.468 on it, lap 3 +0.541.
      expect(find.text('1:04.030'), findsNWidgets(2));
      expect(find.text('+0.468'), findsOneWidget);
      expect(find.text('+0.541'), findsOneWidget);
    });

    testWidgets('renders missing times as a dash rather than zero',
        (tester) async {
      // An invalidated lap: the game wrote 0.0, which must never surface as a
      // 0.000 lap time or a fastest lap.
      final laps = [
        Lap(
          index: 1,
          startSeconds: 100,
          endSeconds: 164,
          lapTimeSeconds: null,
          sectors: SectorTimes.fromCumulative(
            sector1: 22.933,
            sector2Cumulative: 0.0,
            lapTimeSeconds: null,
          ),
        ),
      ];
      await _pumpLapScreen(tester, laps);

      expect(find.text('no time'), findsOneWidget);
      expect(find.text('0:00.000'), findsNothing);
      expect(find.text('0.000'), findsNothing);
    });

    testWidgets('a session with no laps says so', (tester) async {
      await _pumpLapScreen(tester, const []);
      expect(find.text('This session recorded no laps.'), findsOneWidget);
    });
  });

  group('the summary tiles', () {
    testWidgets('state the pace and consistency of the real Race',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());

      expect(find.text('Fastest lap'), findsOneWidget);
      expect(find.text('lap 11'), findsOneWidget);
      // Median 1:04.208, +0.267 off the fastest; σ 0.235 s over 16 laps.
      expect(find.text('1:04.208'), findsOneWidget);
      expect(find.text('+0.267 s behind the fastest'), findsOneWidget);
      expect(find.text('±0.235 s'), findsOneWidget);
      expect(find.text('std. deviation of 16 laps'), findsOneWidget);
    });

    testWidgets('say consistency needs a second lap, rather than showing zero',
        (tester) async {
      await _pumpLapScreen(tester, spaQualifyLaps());

      expect(find.text('needs two timed laps'), findsOneWidget);
      expect(find.text('±0.000 s'), findsNothing);
    });
  });

  group('the trend chart', () {
    testWidgets('plots delta to the fastest lap, with the median as reference',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      final chart = _chart(tester);

      expect(chart.bars, hasLength(20), reason: 'every lap keeps its slot');
      double? delta(int lap) => chart.bars[lap - 1].value;

      // Lap 11 is the fastest: exactly zero, and drawn in the tertiary.
      expect(delta(11), 0);
      expect(chart.bars[10].highlight,
          Theme.of(tester.element(find.byType(PerLapBarChart))).colorScheme.tertiary);
      expect(chart.bars.where((b) => b.highlight != null), hasLength(1));

      // The slowest is lap 16, +0.760.
      expect(delta(16), closeTo(0.7598, 1e-3));
      expect(delta(2), closeTo(0.5565, 1e-3));

      // The dashed line is the median delta, and says so.
      expect(chart.reference, closeTo(0.2667, 1e-3));
      expect(chart.referenceLabel, 'median +0.267');
    });

    testWidgets('leaves laps it cannot compare as empty slots, with the reason',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      final chart = _chart(tester);

      // Out lap (1), the two invalidated laps (6, 14), the open lap (20).
      for (final lap in [1, 6, 14, 20]) {
        expect(chart.bars[lap - 1].value, isNull, reason: 'lap $lap');
        expect(chart.bars[lap - 1].note, isNotNull);
      }
      // The out lap has a time of its own and is excluded anyway: charted it
      // would be 7.3 s against 0.76 s for every other lap.
      expect(chart.bars[0].note, contains('out lap'));
      expect(chart.bars[5].note, contains('no time'));
      expect(chart.bars[19].note, contains('incomplete'));

      // Each carries a glyph whose tooltip says the same, reachable without a
      // bar to hover.
      expect(_tooltipContaining('Lap 1 is not compared — out lap.'), findsOneWidget);
      expect(_tooltipContaining('Lap 6 is not compared — no time.'), findsOneWidget);
      expect(_tooltipContaining('Lap 20 is not compared — incomplete.'), findsOneWidget);
    });

    testWidgets('marks the fastest lap in the axis, where it has no bar to show',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      expect(_tooltipContaining('Lap 11 is the fastest lap: 1:03.941.'),
          findsOneWidget);
    });

    testWidgets('a session with one timed lap says there is no trend',
        (tester) async {
      await _pumpLapScreen(tester, spaQualifyLaps());
      expect(find.byType(PerLapBarChart), findsNothing);
      expect(
        find.text('Only one lap was timed, so there is nothing to compare it '
            'with yet.'),
        findsOneWidget,
      );
    });

    testWidgets('a session with no timed lap says so', (tester) async {
      final laps = [
        for (final lap in spaQualifyLaps()) lap.copyWith(lapTimeSeconds: null),
      ];
      await _pumpLapScreen(tester, laps);
      expect(find.byType(PerLapBarChart), findsNothing);
      expect(find.textContaining('No lap in this session was timed'),
          findsOneWidget);
    });
  });

  group('the incidents', () {
    testWidgets('mark the two real Race impacts, and no other lap',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps(), incidents: _raceIncidents());

      // One badge per impact lap in the table (laps 2 and 6), and one entry
      // in the chart's key ...
      expect(_inTable(find.text('impact')), findsNWidgets(2));
      expect(find.text('impact'), findsNWidgets(3));
      // ... and the summary counts them.
      expect(find.text('2 laps'), findsOneWidget);
      expect(find.text('2 impacts'), findsOneWidget);

      // The tooltips say when — 213.8 s is 18.0 s into lap 2, 508.1 s is
      // 55.1 s into lap 6 — and what the file cannot say.
      expect(_tooltipContaining('Impact registered at 18.0 s into the lap.'),
          findsNWidgets(2), reason: 'a table badge and a chart glyph');
      expect(_tooltipContaining('Impact registered at 55.1 s into the lap.'),
          findsNWidgets(2));
      expect(_tooltipContaining('not how hard'), findsNWidgets(4));

      // The chart carries the same two marks and no others.
      final marked = [
        for (final (i, bar) in _chart(tester).bars.indexed)
          if (bar.marks.any((m) => m.tooltip.startsWith('Impact'))) i + 1,
      ];
      expect(marked, [2, 6]);
    });

    testWidgets('a lap the flag merely stayed true through is not marked',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps(), incidents: _raceIncidents());
      // The flag reads `true` from 213.8 s to 508.1 s: laps 3, 4 and 5 sit
      // inside that and had no impact of their own.
      final bars = _chart(tester).bars;
      for (final lap in [3, 4, 5]) {
        expect(bars[lap - 1].marks.where((m) => m.tooltip.contains('mpact')),
            isEmpty,
            reason: 'lap $lap');
      }
    });

    testWidgets('show a yellow flag with its code, and lost wheels by corner',
        (tester) async {
      // CONSTRUCTED — see the header. A yellow state across lap index 13 and a
      // rear-left wheel lost in lap index 16 and refitted during 17.
      final laps = sebringRaceLaps();
      StepSeries wheel(int corner) => StepSeries.fromRows([
        (laps.first.startSeconds, 0),
        if (corner == WheelCorner.rearLeft.index) ...[(1170.0, 1), (1240.0, 0)],
      ], eventName: 'WheelsDetached');
      final incidents = SessionIncidents.derive(
        laps,
        yellowFlag: StepSeries.fromRows(const [
          (23.5975, 0),
          (975.0, 4),
          (1010.0, 0),
        ], eventName: 'Yellow Flag State'),
        wheelsDetached: [for (var c = 0; c < 4; c++) wheel(c)],
      );
      await _pumpLapScreen(tester, laps, incidents: incidents);

      expect(find.text('yellow flag'), findsWidgets);
      // The code is quoted, not interpreted.
      expect(_tooltipContaining('Yellow Flag State was not clear during this lap (code 4).'),
          findsWidgets);

      // Lap index 16 lost it, 17 still has it off — the table says both.
      expect(find.text('wheel RL'), findsNWidgets(2));
      expect(_tooltipContaining('rear-left wheel detached during this lap.'),
          findsWidgets);
      expect(_tooltipContaining(
              'rear-left wheel was already detached when the lap began.'),
          findsWidgets);

      expect(find.text('3 laps'), findsOneWidget);
      expect(find.text('yellow on 1 lap, wheel off on 2 laps'), findsOneWidget);
    });

    testWidgets('a quiet session says so, in the tile rather than in silence',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      expect(find.text('None'), findsOneWidget);
      expect(find.text('no impact, yellow flag or lost wheel'), findsOneWidget);
      expect(find.text('impact'), findsNothing);
    });

    testWidgets('do not hold the table back while they are read',
        (tester) async {
      final pending = Completer<SessionIncidents>();
      await _pumpLapScreen(
        tester,
        sebringRaceLaps(),
        incidents: pending.future,
        settle: false,
      );
      await tester.pump();
      await tester.pump();

      // The table and the chart are up, the tile says it is reading.
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.byType(PerLapBarChart), findsOneWidget);
      expect(find.text('…'), findsOneWidget);
      expect(find.text('impact'), findsNothing);

      pending.complete(_raceIncidents());
      await tester.pumpAndSettle();
      expect(_inTable(find.text('impact')), findsNWidgets(2));
      expect(find.text('…'), findsNothing);
    });

    testWidgets('that fail to read are reported, and the rest still draws',
        (tester) async {
      await _pumpLapScreen(
        tester,
        sebringRaceLaps(),
        incidents: StateError('disk on fire'),
      );

      expect(find.text('the events could not be read'), findsOneWidget);
      expect(find.textContaining('Incidents could not be read'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
    });

    testWidgets('a recording without the events says the events are absent',
        (tester) async {
      await _pumpLapScreen(
        tester,
        sebringRaceLaps(),
        incidents: const SessionIncidents(unavailable: [
          impactEventName,
          yellowFlagEventName,
          wheelsDetachedEventName,
        ]),
      );
      expect(find.text('this recording has no incident events'), findsOneWidget);
      // "None" would be a claim about the session that the file cannot back.
      expect(find.text('None'), findsNothing);
    });

    testWidgets('a recording missing only some events names them', (tester) async {
      await _pumpLapScreen(
        tester,
        sebringRaceLaps(),
        incidents: const SessionIncidents(unavailable: [impactEventName]),
      );
      expect(find.textContaining('no LastImpactMagnitude event'), findsOneWidget);
    });
  });

  group('choosing a lap', () {
    testWidgets('a table row loads that lap into the Trace', (tester) async {
      final container = await _pumpLapScreen(tester, sebringRaceLaps());
      expect(container.read(selectedLapIndexProvider(_source)), isNull);

      // Lap 3 (index 2): 1:04.570.
      await tester.tap(find.text('1:04.570'));
      await tester.pumpAndSettle();

      expect(container.read(selectedLapIndexProvider(_source)), 2);
      expect(_row(tester, 3).selected, isTrue);
    });

    testWidgets('shows the best lap as the one on display until another is chosen',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      // The Trace defaults to the session's best lap (§8.4), so that is what
      // is highlighted before anyone has chosen.
      expect(_row(tester, 11).selected, isTrue);
      expect(_row(tester, 3).selected, isFalse);
      expect(_chart(tester).selectedIndex, 10);
    });

    testWidgets('a lap number under the chart is as good a target as its bar',
        (tester) async {
      final container = await _pumpLapScreen(tester, sebringRaceLaps());

      await tester.tap(find.descendant(
        of: find.byType(PerLapBarChart),
        matching: find.text('7'),
      ));
      await tester.pumpAndSettle();

      expect(container.read(selectedLapIndexProvider(_source)), 6);
      expect(_chart(tester).selectedIndex, 6);
      expect(_row(tester, 7).selected, isTrue);
    });

    testWidgets('an empty slot — the out lap — can be chosen too',
        (tester) async {
      // Its trace exists even though it has no delta, and the picker on the
      // Trace view lists it: the lane below the chart is the way to get there.
      final container = await _pumpLapScreen(tester, sebringRaceLaps());
      await tester.tap(find.descendant(
        of: find.byType(PerLapBarChart),
        matching: find.text('1'),
      ));
      await tester.pumpAndSettle();
      expect(container.read(selectedLapIndexProvider(_source)), 0);
    });

    testWidgets('a bar itself can be tapped', (tester) async {
      final container = await _pumpLapScreen(tester, sebringRaceLaps());

      // Lap 16's column, well above the baseline: the tall bar.
      final rect = tester.getRect(find.byType(PerLapBarChart));
      final slot = (rect.width - 48) / 20;
      await tester.tapAt(Offset(rect.left + 48 + slot * 15.5, rect.top + 130));
      await tester.pumpAndSettle();

      expect(container.read(selectedLapIndexProvider(_source)), 15);
    });

    testWidgets('and so can the column above the shortest one', (tester) async {
      // Lap 11 is the fastest: 4 px tall. A hit test on the bar alone would
      // need pixel precision; the column is the target.
      final container = await _pumpLapScreen(tester, sebringRaceLaps());

      final rect = tester.getRect(find.byType(PerLapBarChart));
      final slot = (rect.width - 48) / 20;
      await tester.tapAt(Offset(rect.left + 48 + slot * 10.5, rect.top + 40));
      await tester.pumpAndSettle();

      expect(container.read(selectedLapIndexProvider(_source)), 10);
    });

    testWidgets('the Open in Trace button is there, and safe without a router',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      expect(find.text('Open in Trace'), findsOneWidget);
      await tester.tap(find.text('Open in Trace'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the pointer', () {
    Future<TestGesture> mouse(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      return gesture;
    }

    testWidgets('over a chart column highlights the same lap in the table',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());
      final scheme = Theme.of(tester.element(find.byType(DataTable))).colorScheme;

      expect(_row(tester, 8).color?.resolve({}), isNull);

      final rect = tester.getRect(find.byType(PerLapBarChart));
      final slot = (rect.width - 48) / 20;
      final gesture = await mouse(tester);
      await gesture.moveTo(Offset(rect.left + 48 + slot * 7.5, rect.top + 60));
      await tester.pumpAndSettle();

      // The screen hands the chart's own hover straight back to it: that is
      // what lights the column under the pointer, and what the table row
      // below is reading.
      expect(_chart(tester).hoveredIndex, 7, reason: 'lap 8 is index 7');
      expect(_row(tester, 8).color?.resolve({}),
          scheme.onSurface.withValues(alpha: 0.06));

      // And off again.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_row(tester, 8).color?.resolve({}), isNull);
    });

    testWidgets('over a table row highlights the same lap in the chart',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps());

      final gesture = await mouse(tester);
      await gesture.moveTo(tester.getCenter(find.text('1:04.570')));
      await tester.pumpAndSettle();

      expect(_chart(tester).hoveredIndex, 2, reason: 'lap 3 is index 2');

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_chart(tester).hoveredIndex, isNull);
    });
  });

  group('motion', () {
    testWidgets('the bars grow from the baseline on first build',
        (tester) async {
      await _pumpLapScreen(tester, sebringRaceLaps(), settle: false);
      await tester.pump();

      double top(WidgetTester t, int lap) => t
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups[lap - 1]
          .barRods
          .first
          .toY;

      // First frame: every bar at the baseline. A frame later: their values.
      expect(top(tester, 16), 0);
      await tester.pump();
      expect(top(tester, 16), closeTo(0.7598, 1e-3));

      // And it settles rather than running on forever.
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('and do not, when the platform asks for less motion',
        (tester) async {
      await _pumpLapScreen(
        tester,
        sebringRaceLaps(),
        settle: false,
        disableAnimations: true,
      );
      await tester.pump();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups[15].barRods.first.toY, closeTo(0.7598, 1e-3));
      expect(chart.duration, Duration.zero);
    });
  });
}
