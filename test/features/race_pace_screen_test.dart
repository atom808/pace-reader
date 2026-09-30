// The race pace and gaps view (SPEC.md §8.9), fed the real Sebring Race
// readings — and, for the "why is this blank" states, the shapes the other two
// samples and a bare file would give it.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart'
    show PitVisit;
import 'package:pace_reader/features/race_pace/application/race_pace.dart';
import 'package:pace_reader/features/race_pace/presentation/gap_session_chart.dart';
import 'package:pace_reader/features/race_pace/presentation/race_pace_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

import '../fixtures/gap_samples.dart';
import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

class _NoOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [];
}

GapSession _session({List<PitVisit> pitVisits = const []}) => GapSession.derive(
      readings: sebringRaceGapSeries(),
      envelope: sebringRaceGapEnvelope(),
      laps: sebringRaceLaps(),
      stats: sebringRaceGapStats(),
      originSeconds: sebringRaceGapOrigin,
      endSeconds: 1364.18,
      pitVisits: pitVisits,
    );

RacePaceReport _raceReport({List<PitVisit> pitVisits = const []}) =>
    RacePaceReport(
      sessionType: SessionType.race,
      session: _session(pitVisits: pitVisits),
    );

Future<void> _pump(
  WidgetTester tester,
  Future<RacePaceReport> Function() report, {
  Size size = const Size(1400, 1800),
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        racePaceReportProvider(_source).overrideWith((ref) => report()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const RacePaceScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

StatTile _tile(WidgetTester tester, String label) =>
    tester.widget<StatTile>(find.widgetWithText(StatTile, label));

void main() {
  group('the headline', () {
    testWidgets('opens on the grid, ends where the flag froze the channel',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      final start = _tile(tester, 'Gap at the start');
      expect(start.value, '-0.19 s');
      expect(start.caption, 'first reading, unchanged for 42.5\u00A0s');
      final end = _tile(tester, 'Gap at the end');
      expect(end.value, '-6.96 s');
      expect(end.caption, 'last reading, unchanged for the last 10.5\u00A0s');
    });

    testWidgets('nets the laps without counting the passes', (tester) async {
      await _pump(tester, () async => _raceReport());
      final net = _tile(tester, 'Net against the car ahead');
      // -6.96 - (-0.19) is -6.77 raw; the three passes of lap 1 are -3.30 of
      // that, so the driver fell back by 3.47 s over 19 racing laps.
      expect(net.value, '-3.47 s');
      expect(
        net.caption,
        'lost over 19 laps, not counting the 3 changes of car ahead',
      );
      expect(net.emphasised, isTrue);
    });

    testWidgets('closest approach is level with the car ahead, in lap 1',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      final closest = _tile(tester, 'Closest approach');
      expect(closest.value, '+0.001 s');
      expect(closest.caption, 'at 1:59.0 · lap 1');
    });

    testWidgets('says how many times the car ahead changed, and after what',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      final changed = _tile(tester, 'Car ahead changed');
      expect(changed.value, '3×');
      expect(changed.caption, 'each right after closing to within 0.11 s');
    });
  });

  group('the charts', () {
    testWidgets('one signed bar per lap, the cut-off lap drawn grey',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      final chart = tester.widget<PerLapBarChart>(find.byType(PerLapBarChart));
      expect(chart.signed, isTrue);
      expect(chart.bars, hasLength(20), reason: 'every lap keeps its slot');
      expect(chart.bars.where((b) => b.muted), hasLength(1));
      expect(chart.bars.last.muted, isTrue);
      expect(chart.bars.last.note, 'incomplete');
      // Lap 1 gained 0.97 s *because* its three passes are taken out: the raw
      // movement of the gap is -2.33 s, which would draw as a lap lost.
      expect(chart.bars.first.value, closeTo(0.97, 0.005));
      expect(chart.bars.first.note, contains('car ahead changed 3×'));
      expect(chart.bars[1].value, lessThan(0));
      // The dashed reference is the mean of the counted laps: -3.47 / 19.
      expect(chart.reference, closeTo(-3.47 / 19, 0.005));
      expect(chart.referenceLabel, 'avg -0.18 s');
    });

    testWidgets('one gap chart, its caption saying what was drawn from what',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      expect(find.byType(GapSessionChart), findsOneWidget);
      expect(
        find.textContaining('Drawn from 1000 min/max buckets of 2682 readings'),
        findsOneWidget,
      );
      expect(find.textContaining('Rings mark where the car ahead changed'),
          findsOneWidget);
      expect(find.textContaining('Dimmed stretches did not change at all'),
          findsOneWidget);
      // No pit visit in the Race sample: nothing to say about shading.
      expect(find.textContaining('Shaded bands'), findsNothing);
    });

    testWidgets('a pit visit is shaded and announced', (tester) async {
      final lap = sebringRaceLaps()[7];
      await _pump(
        tester,
        () async => _raceReport(pitVisits: [
          PitVisit(
            enteredSeconds: lap.startSeconds + 30,
            exitedSeconds: lap.startSeconds + 52.5,
          ),
        ]),
      );
      expect(find.textContaining('Shaded bands are pit-lane visits'),
          findsOneWidget);
      // The lap with the visit drops out of the net.
      expect(find.text('pit lane'), findsOneWidget);
      expect(find.textContaining('lost over 18 laps'), findsOneWidget);
    });
  });

  group('the changes of car ahead', () {
    testWidgets('are listed with what the gap did across each',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      expect(find.text('+0.11 s  →  -0.46 s'), findsOneWidget);
      expect(find.text('-0.059 s  →  -0.71 s'), findsOneWidget);
      expect(find.text('-0.023 s  →  -2.10 s'), findsOneWidget);
      expect(find.text('lap 1 · 2:02.5'), findsOneWidget);
      expect(find.text('lap 1 · 2:45.0'), findsOneWidget);
    });

    testWidgets('hovering a row rings that change on the chart',
        (tester) async {
      await _pump(tester, () async => _raceReport());
      CarAheadChange? ringed() {
        final paint = tester.widget<CustomPaint>(find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is CarAheadHighlightPainter));
        return (paint.painter! as CarAheadHighlightPainter).change;
      }

      expect(ringed(), isNull);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('-0.023 s  →  -2.10 s')));
      await tester.pump();
      expect(ringed()?.after, closeTo(-2.0976, 1e-4));

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(ringed(), isNull);
    });

    testWidgets('a race with none states it instead of leaving a blank card',
        (tester) async {
      final clean = GapSession.derive(
        readings: _withoutPasses(),
        envelope: _withoutPasses(),
        laps: sebringRaceLaps(),
        stats: sebringRaceGapStats(),
        originSeconds: sebringRaceGapOrigin,
        endSeconds: 1364.18,
      );
      await _pump(
        tester,
        () async => RacePaceReport(
          sessionType: SessionType.race,
          session: clean,
        ),
      );
      expect(clean.changes, isEmpty);
      expect(find.textContaining('No reading stepped by 0.4 s or more'),
          findsOneWidget);
      expect(_tile(tester, 'Car ahead changed').value, '0');
    });
  });

  group('the table', () {
    testWidgets('carries every value the charts draw', (tester) async {
      await _pump(tester, () async => _raceReport());
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows, hasLength(20));
      expect(find.text('incomplete'), findsOneWidget);
      expect(find.text('car ahead changed 3×'), findsOneWidget);
      // Lap 2: -2.52 at the start, -3.26 at the end, 0.74 s lost, no change.
      expect(find.text('-2.52'), findsWidgets);
      expect(find.text('-0.74'), findsWidgets);
    });
  });

  group('when there is no gap to show', () {
    testWidgets('a qualifying session is explained, not drawn',
        (tester) async {
      await _pump(
        tester,
        () async => const RacePaceReport(
          sessionType: SessionType.qualify,
          unavailable: GapUnavailable.notARace,
        ),
      );
      expect(find.text('This view is for races'), findsOneWidget);
      expect(find.textContaining('This is a qualifying session.'),
          findsOneWidget);
      expect(find.byType(GapSessionChart), findsNothing);
      expect(find.byType(StatTile), findsNothing);
    });

    testWidgets('a practice session is named as one', (tester) async {
      await _pump(
        tester,
        () async => const RacePaceReport(
          sessionType: SessionType.practice,
          unavailable: GapUnavailable.notARace,
        ),
      );
      expect(find.textContaining('This is a practice session.'),
          findsOneWidget);
    });

    testWidgets('a race without the channel says so', (tester) async {
      await _pump(
        tester,
        () async => const RacePaceReport(
          sessionType: SessionType.race,
          unavailable: GapUnavailable.noChannel,
        ),
      );
      expect(find.text('No gap channel in this recording'), findsOneWidget);
    });

    testWidgets('a race with only zeros says no car was timed',
        (tester) async {
      await _pump(
        tester,
        () async => const RacePaceReport(
          sessionType: SessionType.race,
          unavailable: GapUnavailable.noCarAhead,
        ),
      );
      expect(find.text('No car ahead was timed'), findsOneWidget);
    });

    testWidgets('no open session points at the library', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            openSessionsProvider.overrideWith(() => _NoOpenSessions()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const RacePaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No session open'), findsOneWidget);
      expect(find.textContaining('pace and gaps of a race'), findsOneWidget);
    });
  });

  group('loading and failing', () {
    testWidgets('shows the shape of the page while the report is read',
        (tester) async {
      final pending = Completer<RacePaceReport>();
      await _pump(tester, () => pending.future, settle: false);
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(StatTile), findsNothing);

      pending.complete(_raceReport());
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(StatTile), findsNWidgets(5));
    });

    testWidgets('a failed read is reported, not swallowed', (tester) async {
      await _pump(
        tester,
        () => Future<RacePaceReport>.error(StateError('disk on fire')),
      );
      expect(find.byType(StatTile), findsNothing);
      expect(find.textContaining('disk on fire'), findsWidgets);
    });
  });

  group('the gap chart on its own', () {
    Future<ValueNotifier<double?>> pumpChart(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final cursor = ValueNotifier<double?>(null);
      addTearDown(cursor.dispose);
      final highlighted = ValueNotifier<int?>(null);
      addTearDown(highlighted.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: GapSessionChart(
                session: _session(),
                color: Colors.teal,
                cursor: cursor,
                highlightedChange: highlighted,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return cursor;
    }

    testWidgets('the arrow keys walk the readings, Home and End jump',
        (tester) async {
      final cursor = await pumpChart(tester);
      // A tap puts the cursor on the pointer and focus on the chart.
      await tester.tapAt(tester.getTopLeft(find.byType(GapSessionChart)) +
          const Offset(300, 120));
      await tester.pump();
      expect(cursor.value, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      expect(cursor.value, sebringRaceGapOrigin);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(cursor.value, closeTo(sebringRaceGapOrigin + 0.5, 1e-9));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(cursor.value, closeTo(sebringRaceGapOrigin + 10.5, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(cursor.value, closeTo(sebringRaceGapOrigin + 10.0, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      expect(cursor.value, closeTo(sebringRaceGapOrigin + 1340.5, 1e-9));
      // One more to the right stays on the last reading rather than running off.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(cursor.value, closeTo(sebringRaceGapOrigin + 1340.5, 1e-9));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(cursor.value, isNull);
    });

    testWidgets('the pointer snaps to a reading and lets go on exit',
        (tester) async {
      final cursor = await pumpChart(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getTopLeft(find.byType(GapSessionChart)) +
          const Offset(400, 120));
      await tester.pump();
      final at = cursor.value!;
      // On the half-second grid the channel is sampled on.
      final steps = (at - sebringRaceGapOrigin) / 0.5;
      expect(steps, closeTo(steps.roundToDouble(), 1e-6));

      await mouse.moveTo(const Offset(2, 2));
      await tester.pump();
      expect(cursor.value, isNull);
    });
  });
}

/// The Race readings with each pass's step closed up, so no two neighbours are
/// 0.4 s apart: the same shape with the passes smoothed out.
TraceSeries _withoutPasses() {
  final source = sebringRaceGapSeries();
  final values = source.lows.toList();
  for (final change in carAheadChangesIn(source)) {
    final index = source.times.indexOf(change.timeSeconds);
    final offset = change.after - change.before;
    for (var i = index; i < values.length; i++) {
      values[i] -= offset;
    }
  }
  final data = Float64List.fromList(values);
  return TraceSeries(
    channelName: source.channelName,
    unit: source.unit,
    frequencyHz: source.frequencyHz,
    valueColumn: source.valueColumn,
    times: source.times,
    lows: data,
    highs: data,
  );
}
