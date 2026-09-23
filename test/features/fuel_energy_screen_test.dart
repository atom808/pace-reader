// The fuel and energy view (SPEC.md §8.7), fed the real Sebring Race numbers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/fuel_energy_strategy/presentation/fuel_energy_strategy_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

import '../fixtures/sebring_race_per_lap.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

FuelEnergyReport _raceReport({
  String carClass = 'GT3',
  List<PitVisit> pitVisits = const [],
  List<LapChannelStats>? stateOfCharge,
}) =>
    FuelEnergyReport(
      carClass: carClass,
      fuel: ResourceUsage.derive(
        name: 'Fuel',
        unit: 'L',
        laps: sebringRaceLaps(),
        stats: sebringRaceFuelStats(),
        pitVisits: pitVisits,
      ),
      energy: ResourceUsage.derive(
        name: 'Virtual energy',
        unit: '%',
        laps: sebringRaceLaps(),
        stats: sebringRaceEnergyStats(),
        pitVisits: pitVisits,
      ),
      stateOfCharge: stateOfCharge,
      pitVisits: pitVisits,
    );

Future<void> _pump(WidgetTester tester, FuelEnergyReport report) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        fuelEnergyReportProvider(_source).overrideWith((ref) async => report),
        telemetryCatalogProvider(_source).overrideWith(
          (ref) async => const TelemetryCatalog(
            channels: [],
            events: [],
            masterRowCount: 134059,
            origin: 23.5975,
            endSeconds: 1364.18,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const FuelEnergyStrategyScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

StatTile _tile(WidgetTester tester, String label) =>
    tester.widget<StatTile>(find.widgetWithText(StatTile, label));

void main() {
  testWidgets('leads with what a lap costs and how many are left',
      (tester) async {
    await _pump(tester, _raceReport());
    // Read off the tiles themselves: the same figures recur in the table
    // below, where a lap that burnt 1.79 L says so too.
    expect(_tile(tester, 'Fuel per lap').value, '1.79 L');
    expect(_tile(tester, 'Fuel per lap').caption, 'average of 18 racing laps');
    expect(_tile(tester, 'Fuel left').value, '6.13 L');
    expect(_tile(tester, 'Fuel left').caption, '≈ 3.4 laps at that rate');
    expect(_tile(tester, 'Virtual energy per lap').value, '2.14 %');
    expect(_tile(tester, 'Virtual energy left').value, '5.59 %');
    expect(
      _tile(tester, 'Virtual energy left').caption,
      '≈ 2.6 laps at that rate',
    );
  });

  testWidgets('names the resource that ends the stint', (tester) async {
    await _pump(tester, _raceReport());
    final tile = _tile(tester, 'Runs out first');
    expect(tile.value, '2.6 laps');
    expect(tile.caption, 'virtual energy, at 2.14 % a lap');
    expect(tile.emphasised, isTrue);
  });

  testWidgets('draws one chart per resource, never one with two axes',
      (tester) async {
    await _pump(tester, _raceReport());
    final charts =
        tester.widgetList<PerLapBarChart>(find.byType(PerLapBarChart)).toList();
    expect(charts, hasLength(2));
    for (final chart in charts) {
      expect(chart.bars, hasLength(20), reason: 'every lap keeps its slot');
      // The garage lap and the cut-off final lap are drawn, greyed.
      expect(chart.bars.first.muted, isTrue);
      expect(chart.bars.last.muted, isTrue);
      expect(chart.bars.where((b) => b.muted), hasLength(2));
    }
  });

  testWidgets('a GT3 session shows no state of charge', (tester) async {
    await _pump(tester, _raceReport());
    expect(find.text('State of charge per lap'), findsNothing);
  });

  testWidgets('a Hypercar session adds its state-of-charge window',
      (tester) async {
    await _pump(
      tester,
      _raceReport(
        carClass: 'Hyper',
        stateOfCharge: [
          for (final s in sebringRaceFuelStats())
            LapChannelStats(
              lapIndex: s.lapIndex,
              first: 80,
              last: 70,
              min: 40,
              max: 90,
              mean: 65,
              samples: s.samples,
            ),
        ],
      ),
    );
    expect(find.text('State of charge per lap'), findsOneWidget);
    final charge = tester
        .widgetList<PerLapBarChart>(find.byType(PerLapBarChart))
        .last;
    expect(charge.bars.first.from, 40);
    expect(charge.bars.first.value, 90);
  });

  testWidgets('no pit stop is a normal thing to report', (tester) async {
    await _pump(tester, _raceReport());
    expect(
      find.textContaining('No pit-lane visit recorded'),
      findsOneWidget,
    );
  });

  testWidgets('a pit stop is listed and its lap is left out', (tester) async {
    final lap8 = sebringRaceLaps()[7];
    await _pump(
      tester,
      _raceReport(pitVisits: [
        PitVisit(
          enteredSeconds: lap8.startSeconds + 30,
          exitedSeconds: lap8.startSeconds + 52.5,
        ),
      ]),
    );
    // On the session clock: lap 8 starts 558.4425 s after the recording
    // does, so 30 s into it is 588.4425 — which a double holds as
    // 588.44249…, hence .442 rather than .443.
    expect(find.text('In at 9:48.442'), findsOneWidget);
    expect(find.text('· out at 10:10.942 (22.5 s)'), findsOneWidget);
    expect(_tile(tester, 'Fuel per lap').caption, 'average of 17 racing laps');
    expect(find.text('pit lane'), findsOneWidget);
  });

  testWidgets('the table carries every value the charts draw', (tester) async {
    await _pump(tester, _raceReport());
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.rows, hasLength(20));
    expect(find.text('out lap'), findsOneWidget);
    expect(find.text('incomplete'), findsOneWidget);
    // Lap 2's own figures: 38.59 L at the start, 1.80 L used.
    expect(find.text('38.59 L'), findsOneWidget);
    expect(find.text('1.80 L'), findsWidgets);
  });
}
