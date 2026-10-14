// The tyres & brakes view (SPEC.md §8.6), fed the real Sebring Race and Spa
// Qualify numbers from the generated per-lap fixtures.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_selection.dart';
import 'package:pace_reader/features/tires_brakes/application/tyre_setup.dart';
import 'package:pace_reader/features/tires_brakes/presentation/corner_card.dart';
import 'package:pace_reader/features/tires_brakes/presentation/setup_card.dart';
import 'package:pace_reader/features/tires_brakes/presentation/tires_brakes_screen.dart';
import 'package:pace_reader/features/tires_brakes/presentation/tyre_trends.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_trend_chart.dart';

import '../fixtures/sebring_race_per_lap.dart';
import '../fixtures/tyre_reports.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

class _NoSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [];
}

Future<void> _pump(
  WidgetTester tester,
  Future<TireBrakeReport> Function() report, {
  Size size = const Size(1400, 2000),
  bool reduceMotion = false,
  bool settle = true,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        tireBrakeReportProvider(_source).overrideWith((ref) => report()),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const TiresBrakesScreen(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

String _carcassText(TireBrakeReport report, int lapIndex) => report
    .snapshot(
      report.laps.firstWhere((l) => l.index == lapIndex),
    )[Corner.frontLeft]!
    .carcass!
    .mean
    .toStringAsFixed(1);

Finder _inCard(Corner corner, String text) =>
    find.descendant(of: _card(corner), matching: find.text(text));

Finder _card(Corner corner) => find.byWidgetPredicate(
  (w) => w is CornerCard && w.snapshot.corner == corner,
);

CornerCard _cardWidget(WidgetTester tester, Corner corner) =>
    tester.widget<CornerCard>(_card(corner));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(TiresBrakesScreen)));

Future<void> _tapSegment(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(SegmentedButton<TyreMetric>),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// A report that carries only the channels it is given — a file that lacks
/// the rest.
TireBrakeReport _partial({
  bool pressure = true,
  List<HiddenChannel> hidden = const [],
}) {
  final full = sebringRaceTyreReport();
  return TireBrakeReport(
    laps: full.laps,
    setup: full.setup,
    pressure: pressure ? full.pressure : null,
    hidden: hidden,
  );
}

void main() {
  group('Sebring Race', () {
    testWidgets('opens on the last complete lap, four corners nose up', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // Index 18 is the 19th lap a driver counts.
      expect(find.text('Lap 19'), findsOneWidget);
      expect(find.textContaining('last complete lap'), findsOneWidget);
      expect(find.text('FRONT'), findsOneWidget);
      // FL / FR above RL / RR, left to right.
      final fl = tester.getTopLeft(_card(Corner.frontLeft));
      final fr = tester.getTopLeft(_card(Corner.frontRight));
      final rl = tester.getTopLeft(_card(Corner.rearLeft));
      final rr = tester.getTopLeft(_card(Corner.rearRight));
      expect(fl.dy, fr.dy);
      expect(rl.dy, rr.dy);
      expect(fl.dx, rl.dx);
      expect(fr.dx, rr.dx);
      expect(fl.dx, lessThan(fr.dx));
      expect(fl.dy, lessThan(rl.dy));
    });

    testWidgets('prints the carcass temperatures the findings quote', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // §15.5: carcass FL 93.4 against FR 83.3 °C on this lap.
      expect(
        find.descendant(
          of: _card(Corner.frontLeft),
          matching: find.text('93.4'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card(Corner.frontRight),
          matching: find.text('83.3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pressure is printed against the cold setting', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // FL: 177.3 kPa hot, 136 cold, +41.3 gained.
      final fl = _card(Corner.frontLeft);
      expect(
        find.descendant(of: fl, matching: find.text('177.3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fl, matching: find.text('cold 136 · +41.3')),
        findsOneWidget,
      );
    });

    testWidgets('wear shows the level left and what the lap took', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // FL ends lap index 18 at 91.9050 after using 0.4434 — two decimals,
      // with a true minus sign.
      final fl = _card(Corner.frontLeft);
      expect(
        find.descendant(of: fl, matching: find.text('−0.44 this lap')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fl, matching: find.textContaining('91.9')),
        findsOneWidget,
      );
    });

    testWidgets('the hottest and most worn corner is tagged, only it', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // Clockwise Sebring: the left-front does the work.
      expect(_cardWidget(tester, Corner.frontLeft).hottest, isTrue);
      expect(_cardWidget(tester, Corner.frontLeft).mostWorn, isTrue);
      for (final corner in [
        Corner.frontRight,
        Corner.rearLeft,
        Corner.rearRight,
      ]) {
        expect(_cardWidget(tester, corner).hottest, isFalse, reason: '$corner');
        expect(
          _cardWidget(tester, corner).mostWorn,
          isFalse,
          reason: '$corner',
        );
      }
      expect(find.text('hottest'), findsOneWidget);
      expect(find.text('most worn'), findsOneWidget);
    });

    testWidgets('the tread strip keeps car-frame order, labelled per side', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      double dx(Corner corner, String label) => tester
          .getCenter(
            find.descendant(of: _card(corner), matching: find.text(label)),
          )
          .dx;
      // A left wheel's outer edge faces the left of the screen …
      expect(
        dx(Corner.frontLeft, 'outer'),
        lessThan(dx(Corner.frontLeft, 'inner')),
      );
      expect(
        dx(Corner.rearLeft, 'outer'),
        lessThan(dx(Corner.rearLeft, 'inner')),
      );
      // … a right wheel's faces the right.
      expect(
        dx(Corner.frontRight, 'inner'),
        lessThan(dx(Corner.frontRight, 'outer')),
      );
      expect(
        dx(Corner.rearRight, 'inner'),
        lessThan(dx(Corner.rearRight, 'outer')),
      );
      // FL's inner zone is the hottest thing on the tyre: 94.2 °C against
      // 85.0 outside.
      expect(
        find.descendant(
          of: _card(Corner.frontLeft),
          matching: find.text('94.2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _card(Corner.frontLeft),
          matching: find.text('85.0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('stepping laps: buttons, keys, and a way back', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      expect(find.text('Back to last complete lap'), findsNothing);

      await tester.tap(find.byTooltip('Next lap (→)'));
      await tester.pumpAndSettle();
      // Lap index 19 is the one the recording cut off.
      expect(find.text('Lap 20'), findsOneWidget);
      expect(find.textContaining('incomplete'), findsWidgets);
      expect(find.text('Back to last complete lap'), findsOneWidget);
      // It is the last lap: nothing further to step to.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Lap 19'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('Lap 18'), findsOneWidget);
      expect(find.text('Back to last complete lap'), findsOneWidget);

      await tester.tap(find.text('Back to last complete lap'));
      await tester.pumpAndSettle();
      expect(find.text('Lap 19'), findsOneWidget);
      expect(find.text('Back to last complete lap'), findsNothing);
    });

    testWidgets('the garage lap is the first stop, and says so', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      _container(tester)
          .read(tyreLapSelectionProvider(_source).notifier)
          .select(0);
      await tester.pumpAndSettle();
      expect(find.text('Lap 1'), findsOneWidget);
      expect(find.textContaining('out lap'), findsWidgets);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets(
      'a selected lap that the file lacks falls back to the default',
      (tester) async {
        await _pump(tester, () async => sebringRaceTyreReport());
        _container(tester)
            .read(tyreLapSelectionProvider(_source).notifier)
            .select(99);
        await tester.pumpAndSettle();
        expect(find.text('Lap 19'), findsOneWidget);
      },
    );

    testWidgets('one metric drives four charts on one scale', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      // Pressure is the opening quantity.
      var charts = tester
          .widgetList<PerLapTrendChart>(find.byType(PerLapTrendChart))
          .toList();
      expect(charts, hasLength(4));
      expect({for (final c in charts) c.minY}, hasLength(1));
      expect({for (final c in charts) c.maxY}, hasLength(1));
      for (final chart in charts) {
        expect(chart.points, hasLength(20), reason: 'every lap keeps its slot');
        expect(chart.points.where((p) => p.muted), hasLength(2));
        expect(chart.highlightLap, 19, reason: 'the lap the cards show');
      }
      // An unanchored quantity is never drawn from zero.
      expect(charts.first.minY, greaterThan(100));

      await _tapSegment(tester, 'Carcass');
      charts = tester
          .widgetList<PerLapTrendChart>(find.byType(PerLapTrendChart))
          .toList();
      expect(charts, hasLength(4));
      expect(charts.first.minY, greaterThan(70));
      expect(find.byType(PerLapBarChart), findsNothing);
    });

    testWidgets('wear is an amount: bars from zero, one scale', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      await _tapSegment(tester, 'Wear');
      final charts = tester
          .widgetList<PerLapBarChart>(find.byType(PerLapBarChart))
          .toList();
      expect(charts, hasLength(4));
      expect({for (final c in charts) c.maxValue}, hasLength(1));
      expect(charts.first.maxValue, closeTo(0.5069, 1e-3));
      expect(find.byType(PerLapTrendChart), findsNothing);
      // The table says what each lap took, and the level it went through.
      expect(find.text('99.63 → 99.17'), findsOneWidget);
    });

    testWidgets('brake temperature is drawn in the brake colour', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      await _tapSegment(tester, 'Brake temp');
      final channels = ChannelColors.resolve(
        tester.element(find.byType(TiresBrakesScreen)),
      );
      for (final chart in tester.widgetList<PerLapTrendChart>(
        find.byType(PerLapTrendChart),
      )) {
        expect(chart.color, channels.brake);
      }
      await _tapSegment(tester, 'Pressure');
      for (final chart in tester.widgetList<PerLapTrendChart>(
        find.byType(PerLapTrendChart),
      )) {
        expect(chart.color, channels.tyre);
      }
    });

    testWidgets('a figure on a card is the way into its trend', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      await tester.tap(
        find.descendant(
          of: _card(Corner.frontRight),
          matching: find.text('Carcass'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _container(tester).read(tyreMetricSelectionProvider(_source)),
        TyreMetric.carcass,
      );
      await tester.tap(
        find.descendant(
          of: _card(Corner.rearLeft),
          matching: find.text('Brake peak'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _container(tester).read(tyreMetricSelectionProvider(_source)),
        TyreMetric.brake,
      );
    });

    testWidgets('the table carries every value the charts draw', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      var table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows, hasLength(20));
      expect(table.columns, hasLength(6), reason: 'lap, four corners, note');
      expect(find.text('out lap'), findsWidgets);
      expect(find.text('incomplete'), findsWidgets);

      await _tapSegment(tester, 'Tread temp');
      table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows, hasLength(20));
      // Lap index 18, FL: inner 94.2 · centre 94.8 · outer 85.0.
      expect(find.text('94.2 · 94.8 · 85.0'), findsOneWidget);
    });

    testWidgets('a table row chooses the lap the cards show', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      final table = tester.widget<DataTable>(find.byType(DataTable));
      table.rows[3].onSelectChanged!(true);
      await tester.pumpAndSettle();
      expect(find.text('Lap 4'), findsWidgets);
      expect(_container(tester).read(tyreLapSelectionProvider(_source)), 3);
    });

    testWidgets('the setup card names the reference values', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      expect(find.byType(TyreSetupCard), findsOneWidget);
      expect(find.text('As the car left the garage'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('136 kPa'), findsOneWidget);
      expect(find.textContaining('-2.30 deg'), findsOneWidget);
      expect(find.text('51.2:48.8 F:R'), findsOneWidget);
      // The recorded bias agrees with the setup and never moved.
      expect(find.textContaining('never changed'), findsWidgets);
    });

    testWidgets('setup sits beside the cars wide, below them narrow', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      final wide = tester.getTopLeft(find.byType(TyreSetupCard));
      expect(
        wide.dx,
        greaterThan(tester.getTopRight(_card(Corner.frontRight)).dx),
      );

      await tester.binding.setSurfaceSize(const Size(1000, 2400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final narrow = tester.getTopLeft(find.byType(TyreSetupCard));
      expect(
        narrow.dy,
        greaterThan(tester.getBottomLeft(_card(Corner.rearLeft)).dy),
      );
    });

    testWidgets('reduced motion settles a lap change in one frame', (
      tester,
    ) async {
      final report = sebringRaceTyreReport();
      final before = _carcassText(report, 18);
      final after = _carcassText(report, 17);
      expect(after, isNot(before), reason: 'the two laps must differ');
      await _pump(tester, () async => report, reduceMotion: true);
      expect(_inCard(Corner.frontLeft, before), findsOneWidget);
      await tester.tap(find.byTooltip('Previous lap (←)'));
      await tester.pump();
      // The new lap's own number straight away, with no tween in flight.
      expect(find.text('Lap 18'), findsOneWidget);
      expect(_inCard(Corner.frontLeft, after), findsOneWidget);
    });

    testWidgets('animated numbers ease when the lap changes', (tester) async {
      final report = sebringRaceTyreReport();
      final before = _carcassText(report, 18);
      final after = _carcassText(report, 17);
      await _pump(tester, () async => report);
      await tester.tap(find.byTooltip('Previous lap (←)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // Mid-tween: the card is neither where it was nor where it is going.
      expect(_inCard(Corner.frontLeft, after), findsNothing);
      await tester.pumpAndSettle();
      expect(_inCard(Corner.frontLeft, after), findsOneWidget);
      expect(_inCard(Corner.frontLeft, before), findsNothing);
    });

    // ← → ← → with key repeat, inside the lap label's 120 ms fade. A switcher
    // keyed by the lap left two fading copies of one lap in its stack here
    // and threw "Duplicate keys found".
    testWidgets('stepping back and forth inside the fade', (tester) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      for (final key in [
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ]) {
        await tester.sendKeyEvent(key);
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(find.text('Lap 19'), findsOneWidget);
      expect(find.text('Lap 18'), findsNothing);
    });

    testWidgets('switching metrics back and forth inside the fade', (
      tester,
    ) async {
      await _pump(tester, () async => sebringRaceTyreReport());
      for (final label in ['Carcass', 'Pressure', 'Carcass', 'Pressure']) {
        await tester.tap(
          find.descendant(
            of: find.byType(SegmentedButton<TyreMetric>),
            matching: find.text(label),
          ),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CornerTrends>(find.byType(CornerTrends))
            .single
            .metric,
        TyreMetric.pressure,
      );
    });
  });

  group('Spa Qualify (warm-up)', () {
    testWidgets('the spin shows as rear-right wear on its lap', (tester) async {
      await _pump(tester, () async => spaQualifyTyreReport());
      // Lap index 3 is the last complete one, and the spin's.
      expect(find.text('Lap 4'), findsOneWidget);
      expect(_cardWidget(tester, Corner.rearRight).mostWorn, isTrue);
      expect(_cardWidget(tester, Corner.rearLeft).mostWorn, isFalse);
    });

    testWidgets('a garage lap at ambient crowns no corner', (tester) async {
      await _pump(tester, () async => spaQualifyTyreReport());
      _container(tester)
          .read(tyreLapSelectionProvider(_source).notifier)
          .select(0);
      await tester.pumpAndSettle();
      expect(find.text('hottest'), findsNothing);
      expect(find.textContaining('out lap'), findsWidgets);
    });

    testWidgets('setup facts are the Hypercar’s own', (tester) async {
      await _pump(tester, () async => spaQualifyTyreReport());
      expect(find.text('Soft'), findsOneWidget);
      expect(find.text('2.5% F'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('no session open says so', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [openSessionsProvider.overrideWith(() => _NoSessions())],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const TiresBrakesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('tyre and brake data'), findsOneWidget);
      expect(find.byType(CornerCard), findsNothing);
    });

    testWidgets('loading holds the layout with skeletons', (tester) async {
      final pending = Completer<TireBrakeReport>();
      addTearDown(() => pending.complete(sebringRaceTyreReport()));
      await _pump(tester, () => pending.future, settle: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(CornerCard), findsNothing);
    });

    testWidgets('an error is said, not swallowed', (tester) async {
      await _pump(tester, () => Future.error(StateError('no per-corner data')));
      expect(find.textContaining('no per-corner data'), findsOneWidget);
    });

    testWidgets('a file with no laps says so', (tester) async {
      await _pump(
        tester,
        () async => TireBrakeReport(laps: const [], setup: const TyreSetup()),
      );
      expect(find.textContaining('no laps to summarise'), findsOneWidget);
    });

    testWidgets('a file with none of the channels lists why', (tester) async {
      await _pump(
        tester,
        () async => TireBrakeReport(
          laps: sebringRaceLaps(),
          setup: const TyreSetup(),
          hidden: const [
            HiddenChannel('TyresPressure', 'not in this recording'),
          ],
        ),
      );
      expect(
        find.textContaining('none of the tyre or brake channels'),
        findsOneWidget,
      );
      expect(
        find.textContaining('TyresPressure — not in this recording'),
        findsOneWidget,
      );
      expect(find.byType(CornerCard), findsNothing);
    });

    testWidgets('a partial file draws what it has and names what it lacks', (
      tester,
    ) async {
      await _pump(
        tester,
        () async => _partial(
          hidden: const [
            HiddenChannel('TyresRimTemp', 'not in this recording'),
            HiddenChannel(
              'Brakes Temp',
              'one value all session on every corner — not drawn flat',
            ),
          ],
        ),
      );
      expect(
        find.textContaining('TyresRimTemp — not in this recording'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Brakes Temp — one value all session'),
        findsOneWidget,
      );
      // Pressure is all there is: four pressure charts, the other quantities'
      // segments disabled rather than silently dead.
      expect(find.byType(PerLapTrendChart), findsNWidgets(4));
      final selector = tester.widget<SegmentedButton<TyreMetric>>(
        find.byType(SegmentedButton<TyreMetric>),
      );
      expect(
        {for (final s in selector.segments) s.value: s.enabled},
        {
          TyreMetric.pressure: true,
          TyreMetric.tread: false,
          TyreMetric.carcass: false,
          TyreMetric.wear: false,
          TyreMetric.brake: false,
        },
      );
      // The cards say what is missing instead of inventing a figure.
      expect(find.text('No tread temperatures for this lap'), findsNWidgets(4));
    });

    testWidgets('a metric the file cannot draw falls back to one it can', (
      tester,
    ) async {
      await _pump(tester, () async => _partial());
      _container(tester)
          .read(tyreMetricSelectionProvider(_source).notifier)
          .select(TyreMetric.wear);
      await tester.pumpAndSettle();
      expect(find.byType(PerLapTrendChart), findsNWidgets(4));
      expect(find.byType(PerLapBarChart), findsNothing);
    });
  });
}
