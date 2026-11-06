// The class's fuel, energy and tyres (results proposal, R6): what each car
// used per lap, its stints, and the card on Fuel & Energy.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_results/application/linked_results.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/bop.dart';
import 'package:pace_reader/features/session_results/domain/bop_allowance.dart';
import 'package:pace_reader/features/session_results/domain/bop_documents.dart';
import 'package:pace_reader/features/session_results/domain/field_pace.dart';
import 'package:pace_reader/features/session_results/domain/field_resources.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';
import 'package:pace_reader/features/session_results/presentation/field_resources_card.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/results_xml_samples.dart';

final _template = parseResultsXml(sartheRaceXml);

const _source = TelemetrySource.path('/fixture/sarthe.duckdb');

/// A lap of 100 s with all three sectors; [tread] is left on every corner.
ResultsLap _lap(
  int number, {
  bool pit = false,
  bool sectors = true,
  double seconds = 100,
  double? fuel,
  double? energy,
  double? tread,
}) => ResultsLap(
  number: number,
  lapSeconds: seconds,
  sector1Seconds: sectors ? seconds / 3 : null,
  sector2Seconds: sectors ? seconds / 3 : null,
  sector3Seconds: sectors ? seconds / 3 : null,
  fuelUsedFraction: fuel,
  energyUsedFraction: energy,
  wearFrontLeft: tread,
  wearFrontRight: tread,
  wearRearLeft: tread,
  wearRearRight: tread,
  pit: pit,
);

ResultsDriver _car(int index, List<ResultsLap> laps, {String? name}) =>
    _template.drivers.first.copyWith(
      index: index,
      name: name ?? 'Driver $index',
      isPlayer: index == 0,
      carType: 'Model ${String.fromCharCode(65 + index)}',
      carClass: 'Hyper',
      carNumber: '${index + 1}',
      swaps: const [],
      laps: laps,
    );

/// [count] laps of [seconds], each using 6 % fuel, 8 % energy and 1 % tread.
List<ResultsLap> _steady(int count, double seconds, {bool figures = true}) => [
  for (var n = 1; n <= count; n++)
    _lap(
      n,
      seconds: seconds,
      fuel: figures ? 0.06 : null,
      energy: figures ? 0.08 : null,
      tread: figures ? 1 - 0.01 * n : null,
    ),
];

FieldPace _pace(List<ResultsDriver> cars) {
  final session = _template.copyWith(
    kind: ResultsSessionKind.race,
    drivers: cars,
  );
  return FieldPace.of(session, cars.first);
}

void main() {
  group('stints', () {
    test('a stop closes the stint it is in', () {
      expect(
        stintsOf([
          _lap(1),
          _lap(2),
          _lap(3, pit: true),
          _lap(4),
          _lap(5, pit: true),
          _lap(6),
        ]),
        [3, 2, 1],
      );
    });

    test(
      'no stop is one stint; a stop on the last lap leaves no empty one',
      () {
        expect(stintsOf([_lap(1), _lap(2)]), [2]);
        expect(stintsOf([_lap(1), _lap(2, pit: true)]), [2]);
        expect(stintsOf(const []), isEmpty);
      },
    );
  });

  group('a car\'s use per lap', () {
    test('is the median over its pace laps, in lap order', () {
      final resources = CarResources.of(
        FieldCar(
          _car(0, [
            _lap(3, fuel: 0.07, energy: 0.09, tread: 0.97),
            _lap(1, fuel: 0.05, energy: 0.07, tread: 0.99),
            _lap(2, fuel: 0.06, energy: 0.08, tread: 0.98),
          ]),
        ),
      );
      expect(resources.fuelPerLap, closeTo(0.06, 1e-9));
      expect(resources.energyPerLap, closeTo(0.08, 1e-9));
      // Laps 2 and 3 each took 1 % off; lap 1 has no lap before it.
      expect(resources.treadPerLap, closeTo(0.01, 1e-9));
      expect(resources.stints, [3]);
    });

    test('leaves out stops, invalidated laps and zero readings', () {
      final resources = CarResources.of(
        FieldCar(
          _car(0, [
            _lap(1, fuel: 0.06),
            _lap(2, fuel: 0.5, pit: true),
            _lap(3, fuel: 0.4, sectors: false),
            _lap(4, fuel: 0),
            _lap(5, fuel: 0.07),
          ]),
        ),
      );
      expect(resources.fuelPerLap, closeTo(0.065, 1e-9));
      expect(resources.energyPerLap, isNull);
    });

    test('tread never spans a stop, where new tyres may have gone on', () {
      final resources = CarResources.of(
        FieldCar(
          _car(0, [
            _lap(1, tread: 0.98),
            _lap(2, tread: 0.96, pit: true),
            // New tyres: compared with the stop lap this would be negative,
            // and it is not compared at all.
            _lap(3, tread: 0.99),
            _lap(4, tread: 0.97),
          ]),
        ),
      );
      expect(resources.treadPerLap, closeTo(0.02, 1e-9));
    });

    test('a file without the figures has none', () {
      final pace = _pace([
        _car(0, _steady(4, 100, figures: false)),
        _car(1, _steady(4, 99, figures: false)),
      ]);
      expect(hasResources(pace), isFalse);
      expect(CarResources.of(pace.me).fuelPerLap, isNull);
      expect(CarResources.of(pace.me).treadPerLap, isNull);
    });
  });

  group('the card', () {
    Future<void> pump(
      WidgetTester tester,
      SessionFieldPace? field, {
      SessionBop? bop,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionFieldPaceProvider(_source)
                .overrideWith((ref) async => field),
            sessionBopProvider(_source).overrideWith((ref) async => bop),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: FieldResourcesCard(source: _source),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('takes no room without a results file', (tester) async {
      await pump(tester, null);
      expect(find.text('In class'), findsNothing);
      expect(find.textContaining('no fuel, energy'), findsNothing);
    });

    testWidgets('says so when the file has no figures', (tester) async {
      await pump(
        tester,
        SessionFieldPace(
          pace: _pace([
            _car(0, _steady(4, 100, figures: false)),
            _car(1, _steady(4, 99, figures: false)),
          ]),
          laps: const [],
        ),
      );
      expect(find.text('In class'), findsNothing);
      expect(find.textContaining('no fuel, energy'), findsOneWidget);
    });

    testWidgets('lists the five fastest, then this car', (tester) async {
      await pump(
        tester,
        SessionFieldPace(
          pace: _pace([
            _car(0, _steady(6, 110), name: 'Invented Driver'),
            for (var i = 1; i <= 6; i++) _car(i, _steady(6, 100.0 + i)),
          ]),
          laps: const [],
        ),
      );
      expect(find.text('In class'), findsOneWidget);
      // Shares compare across models only with the balance of performance
      // in mind.
      expect(find.text(bopNote), findsOneWidget);
      for (var i = 1; i <= 5; i++) {
        expect(find.text('Driver $i'), findsOneWidget);
      }
      // The sixth-fastest other car is left out; this car comes last, 7th.
      expect(find.text('Driver 6'), findsNothing);
      expect(find.text('Invented Driver · this car'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('6.0 %'), findsNWidgets(6));
      expect(find.text('8.0 %'), findsNWidgets(6));
      expect(find.text('1.00 %'), findsNWidgets(6));
      expect(find.text('6'), findsNWidgets(6));
    });

    SessionBop bopFor(FieldPace pace, BopAllowanceKind kind) {
      final doc = bopDocuments.single;
      return SessionBop(
        document: doc,
        group: 'Le Mans',
        entries: {
          for (final c in pace.classCars)
            c.driver.index: doc.entry(
              'Le Mans',
              BopClass.hypercar,
              'Alpine A424',
            )!,
        },
        allowance: BopAllowance(kind: kind, ratio: 1, sessions: 4, models: 1),
      );
    }

    testWidgets('reads energy in MJ where the event kept BoP’s allowance', (
      tester,
    ) async {
      final pace = _pace([
        _car(0, _steady(6, 110), name: 'Invented Driver'),
        _car(1, _steady(6, 101)),
      ]);
      await pump(
        tester,
        SessionFieldPace(pace: pace, laps: const []),
        bop: bopFor(pace, BopAllowanceKind.matches),
      );
      // 8 % of the Alpine's 903 MJ at Le Mans.
      expect(find.text('72 MJ'), findsNWidgets(2));
      expect(find.text('903 MJ'), findsNWidgets(2));
      expect(find.text('Allowance'), findsOneWidget);
      expect(find.textContaining('match 4 other sessions'), findsOneWidget);
    });

    testWidgets('keeps shares where it could not check the allowance', (
      tester,
    ) async {
      final pace = _pace([
        _car(0, _steady(6, 110), name: 'Invented Driver'),
        _car(1, _steady(6, 101)),
      ]);
      await pump(
        tester,
        SessionFieldPace(pace: pace, laps: const []),
        bop: bopFor(pace, BopAllowanceKind.unchecked),
      );
      expect(find.text('8.0 %'), findsNWidgets(2));
      expect(find.text('72 MJ'), findsNothing);
      // The allowance itself is BoP's figure either way.
      expect(find.text('903 MJ'), findsNWidgets(2));
      expect(find.textContaining('energy stays a share'), findsOneWidget);
    });
  });
}
