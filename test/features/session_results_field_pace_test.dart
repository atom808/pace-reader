// Field pace (results proposal, R2): ranks against the class, the class's
// middle half, and the band the trend chart draws from it.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/session_results/application/linked_results.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/field_pace.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';
import 'package:pace_reader/widgets/fl_chart_theme/per_lap_bar_chart.dart';

import '../fixtures/results_xml_samples.dart';

final _template = parseResultsXml(sartheRaceXml);

ResultsLap _lap(
  int number,
  double? seconds, {
  bool pit = false,
  bool sectors = true,
  double? start,
}) => ResultsLap(
  number: number,
  startElapsed: start,
  lapSeconds: seconds,
  sector1Seconds: sectors && seconds != null ? seconds / 3 : null,
  sector2Seconds: sectors && seconds != null ? seconds / 3 : null,
  sector3Seconds: sectors && seconds != null ? seconds / 3 : null,
  pit: pit,
);

/// A car of [model] in Hypercar, with [times] as laps 1, 2, ….
ResultsDriver _car(
  int index,
  List<double?> times, {
  String model = 'Model B',
  String carClass = 'Hyper',
}) => _template.drivers.first.copyWith(
  index: index,
  name: 'Driver $index',
  isPlayer: index == 0,
  carType: model,
  carClass: carClass,
  carNumber: '${index + 1}',
  swaps: const [],
  laps: [for (final (i, t) in times.indexed) _lap(i + 1, t)],
);

ResultsSession _session(
  List<ResultsDriver> cars, {
  ResultsSessionKind kind = ResultsSessionKind.practice,
}) => _template.copyWith(kind: kind, drivers: cars);

void main() {
  group('a car\'s pace laps', () {
    test('leave out stops, untimed laps and invalidated ones', () {
      final car = FieldCar(
        _template.drivers.first.copyWith(
          laps: [
            _lap(1, null),
            _lap(2, 100),
            _lap(3, 99, pit: true),
            _lap(4, 98, sectors: false),
            _lap(5, 102),
            _lap(6, 101),
          ],
        ),
      );
      expect(car.paceLaps, {2: 100.0, 5: 102.0, 6: 101.0});
      expect(car.best, 100);
      expect(car.typical, 101);
    });

    test('a car with none has no best and no typical lap', () {
      final car = FieldCar(
        _template.drivers.first.copyWith(laps: [_lap(1, null)]),
      );
      expect(car.best, isNull);
      expect(car.typical, isNull);
    });
  });

  group('ranks', () {
    test('a fastest lap can rank first and a typical lap third', () {
      final pace = FieldPace.of(
        _session([
          _car(0, [95, 101, 101, 101]),
          _car(1, [99, 99, 99]),
          _car(2, [100, 100, 100]),
          _car(3, [102, 102]),
          _car(4, [null], carClass: 'GT3'),
          _car(5, [null]),
        ]),
        _car(0, []),
      );
      expect(pace.classSize, 4, reason: 'GT3 and lapless cars are out');
      expect(pace.bestRank, 1);
      expect(pace.typicalRank, 3);
      expect(pace.classCars.first.driver.index, 1);
    });

    test('a tie shares the better rank', () {
      final pace = FieldPace.of(
        _session([
          _car(0, [100]),
          _car(1, [100]),
        ]),
        _car(0, []),
      );
      expect(pace.bestRank, 1);
      expect(pace.typicalRank, 1);
    });
  });

  group('the band', () {
    test('outside a race it is one range, from the cars\' typical laps', () {
      final pace = FieldPace.of(
        _session([
          _car(0, [100]),
          for (var i = 1; i <= 9; i++) _car(i, [100.0 + i, 100.0 + i]),
        ]),
        _car(0, []),
      );
      final band = pace.band()!;
      expect(band.perLap, isFalse);
      expect(band.cars, 9);
      // 101..109: p25 103, p75 107.
      expect(band.at(1), (103.0, 107.0));
      expect(band.at(40), (103.0, 107.0));
    });

    test('in a race it follows lap number, where enough cars ran it', () {
      final pace = FieldPace.of(
        _session(kind: ResultsSessionKind.race, [
          _car(0, [null, 100, 100]),
          for (var i = 1; i <= 9; i++)
            _car(i, [null, 100.0 + i, if (i <= 3) 110.0 + i]),
        ]),
        _car(0, []),
      );
      final band = pace.band()!;
      expect(band.perLap, isTrue);
      expect(band.at(2), (103.0, 107.0));
      expect(band.at(3), isNull, reason: 'only three cars ran lap 3');
      expect(band.at(1), isNull);
    });

    test('there is none with fewer than eight other cars', () {
      final pace = FieldPace.of(
        _session([
          for (var i = 0; i <= fieldBandMinCars - 1; i++) _car(i, [100.0 + i]),
        ]),
        _car(0, []),
      );
      expect(pace.others(), hasLength(fieldBandMinCars - 1));
      expect(pace.band(), isNull);
    });

    test('same model narrows the cars it is drawn from', () {
      final pace = FieldPace.of(
        _session([
          _car(0, [100], model: 'Model A'),
          for (var i = 1; i <= 9; i++) _car(i, [100.0 + i], model: 'Model A'),
          for (var i = 10; i <= 18; i++) _car(i, [90.0 + i]),
        ]),
        _car(0, [], model: 'Model A'),
      );
      expect(pace.others(), hasLength(18));
      expect(pace.others(sameModel: true), hasLength(9));
      expect(pace.band(sameModel: true)!.at(1), (103.0, 107.0));
      expect(pace.fastestOther()!.best, 100);
      expect(pace.fastestOther(sameModel: true)!.best, 101);
    });
  });

  test('the recording\'s laps find their numbers by start time', () {
    final me = _template.drivers.first.copyWith(
      laps: [
        _lap(1, null),
        _lap(2, 100, start: 300.0),
        _lap(3, 100, start: 400.0),
      ],
    );
    final field = SessionFieldPace(
      pace: FieldPace.of(_session([me]), me),
      laps: const [
        // A recording that began a lap late: its lap 0 is the file's lap 2.
        Lap(
          index: 0,
          startSeconds: 299.6,
          endSeconds: 400,
          sectors: SectorTimes(),
        ),
        Lap(index: 1, startSeconds: 400.2, sectors: SectorTimes()),
      ],
    );
    expect(
      field.numberOf(
        const Lap(index: 0, startSeconds: 299.6, sectors: SectorTimes()),
      ),
      2,
    );
    expect(
      field.numberOf(
        const Lap(index: 1, startSeconds: 400.2, sectors: SectorTimes()),
      ),
      3,
    );
    expect(
      field.numberOf(
        const Lap(index: 7, startSeconds: 9000, sectors: SectorTimes()),
      ),
      8,
      reason: 'a lap the file has no time for falls back to its position',
    );
  });

  test('quantiles interpolate, and ordinals read as English', () {
    expect(quantile([1, 2, 3, 4], 0.5), 2.5);
    expect(quantile([7], 0.25), 7);
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(ordinal), [
      '1st',
      '2nd',
      '3rd',
      '4th',
      '11th',
      '12th',
      '13th',
      '21st',
      '22nd',
      '101st',
      '111th',
    ]);
  });

  group('the chart band', () {
    Future<void> pump(WidgetTester tester, PerLapBand band) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: PerLapBarChart(
                bars: const [
                  PerLapBar(lapNumber: 1, value: 0),
                  PerLapBar(lapNumber: 2, value: 1.2),
                ],
                color: Colors.blue,
                formatValue: (v) => '$v',
                band: band,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a field faster than the lap opens the axis below zero', (
      tester,
    ) async {
      await pump(
        tester,
        const PerLapBand(
          ranges: [(-0.4, 0.6), (-0.2, 0.8)],
          line: -0.6,
          lineLabel: 'best other car -0.600',
        ),
      );
      expect(tester.takeException(), isNull);
      // The axis now carries a negative tick.
      expect(find.textContaining('-'), findsWidgets);
    });

    testWidgets('a new band moves rather than jumps, and settles', (
      tester,
    ) async {
      await pump(tester, const PerLapBand(ranges: [(0.2, 0.6), (0.3, 0.7)]));
      await pump(tester, const PerLapBand(ranges: [(0.1, 0.4), null]));
      expect(tester.takeException(), isNull);
    });
  });
}
