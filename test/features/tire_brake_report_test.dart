// The tyres & brakes derivations (SPEC.md §8.6), on the real Sebring Race and
// Spa Qualify numbers.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tyre_setup.dart';

import '../fixtures/sebring_race_tyres.dart';
import '../fixtures/spa_qualify_tyres.dart';
import '../fixtures/tyre_reports.dart';

Lap _lap(TireBrakeReport report, int index) =>
    report.laps.firstWhere((l) => l.index == index);

void main() {
  group('Sebring Race', () {
    final report = sebringRaceTyreReport();
    final lap18 = _lap(report, 18);

    test('opens on the last complete lap, not the cut-off one', () {
      expect(report.defaultLap!.index, 18);
      expect(report.exclusionOf(_lap(report, 0)), UsageExclusion.outLap);
      expect(report.exclusionOf(_lap(report, 19)), UsageExclusion.incomplete);
      expect(report.exclusionOf(lap18), isNull);
    });

    test('inner and outer come from the corner, not the channel name', () {
      final fl = report.tread!.at(Corner.frontLeft, 18)!;
      final fr = report.tread!.at(Corner.frontRight, 18)!;
      // Left wheel: inner is TyresTempRight, outer TyresTempLeft.
      expect(fl.inner.mean, closeTo(94.1731, 1e-4));
      expect(fl.outer.mean, closeTo(85.0361, 1e-4));
      // Right wheel: the other way round.
      expect(fr.inner.mean, closeTo(87.0272, 1e-4));
      expect(fr.outer.mean, closeTo(73.4658, 1e-4));
      // Negative camber loads the inside edge on every corner of every
      // racing lap.
      for (final corner in Corner.values) {
        for (var lap = 1; lap <= 18; lap++) {
          expect(report.tread!.at(corner, lap)!.spread, greaterThan(6.9),
              reason: '$corner lap $lap');
        }
      }
    });

    test('clockwise Sebring works the left side hardest', () {
      // §15.5's thermal evidence: lap index 18 carcass FL 93.4 vs FR 83.3.
      final snapshot = report.snapshot(lap18);
      expect(snapshot[Corner.frontLeft]!.carcass!.mean, closeTo(93.37, 0.01));
      expect(snapshot[Corner.frontRight]!.carcass!.mean, closeTo(83.28, 0.01));
      expect(report.hottestOn(lap18), Corner.frontLeft);
      expect(report.mostWornOn(lap18), Corner.frontLeft);
    });

    test('wear per lap is the fuel view’s differencing', () {
      final fl = report.wear![Corner.frontLeft]!;
      // Level at a lap's first sample minus the next lap's first sample.
      expect(fl.laps[1].used, closeTo(99.6328 - 99.1675, 1e-9));
      expect(fl.laps[18].used, closeTo(92.3484 - 91.9050, 1e-9));
      // The stint's lap means, as §15.5 quotes them: 99.39 → 92.12 on FL.
      final means = sebringRaceWear()[Corner.frontLeft]!;
      expect(means[1].mean, closeTo(99.39, 0.005));
      expect(means[18].mean, closeTo(92.12, 0.005));
      // 0.23–0.51 % a lap on every racing lap of every corner: 0.22954 (FR,
      // lap 8) to 0.50695 (FL, lap 2) from the unrounded samples. The
      // fixture holds four decimals, so its differences sit a few 1e-5 inside
      // that — hence the slack.
      for (final corner in Corner.values) {
        for (final lap in report.wear![corner]!.representative) {
          expect(lap.used, inInclusiveRange(0.2295 - 1e-4, 0.5070 + 1e-4),
              reason: '$corner lap ${lap.lap.index}');
        }
      }
      final snapshot = report.snapshot(lap18)[Corner.frontLeft]!;
      expect(snapshot.wearLeft, closeTo(91.9050, 1e-9));
    });

    test('hot pressure against the cold setting', () {
      final fl = report.snapshot(lap18)[Corner.frontLeft]!;
      expect(fl.coldPressure!.number, 136);
      expect(fl.pressure!.mean, closeTo(177.2954, 1e-4));
      expect(fl.pressureGain, closeTo(41.2954, 1e-4));
    });

    test('every lap keeps its slot on every metric', () {
      for (final metric in TyreMetric.values) {
        for (final corner in Corner.values) {
          final series = report.series(metric, corner);
          expect(series, hasLength(20), reason: '$metric $corner');
          expect(series.first.muted, isTrue);
          expect(series.last.muted, isTrue);
          expect(series.where((p) => p.muted), hasLength(2));
        }
      }
    });

    test('one scale for all four corners', () {
      final range = report.sharedRange(TyreMetric.carcass)!;
      for (final corner in Corner.values) {
        for (final point in report.series(TyreMetric.carcass, corner)) {
          expect(point.low, greaterThanOrEqualTo(range.min));
          expect(point.high, lessThanOrEqualTo(range.max));
        }
      }
      // An amount starts at zero; a temperature does not.
      expect(report.sharedRange(TyreMetric.wear)!.min, 0);
      expect(range.min, greaterThan(70));
    });

    test('the tread ramp spans the session, not the lap', () {
      final range = report.treadRampRange!;
      expect(range.min, lessThan(74));
      expect(range.max, greaterThan(95));
    });

    test('recorded settings never changed', () {
      expect(report.brakeBiasRear!.isConstant, isTrue);
      expect(report.brakeBiasRear!.initial, closeTo(0.4875, 1e-6));
      expect(report.brakeMigration!.initial, 0);
    });
  });

  group('Spa Qualify (warm-up)', () {
    final report = spaQualifyTyreReport();

    test('the out lap is out lap first, pit lane second', () {
      expect(report.exclusionOf(_lap(report, 0)), UsageExclusion.outLap);
      expect(report.defaultLap!.index, 3);
    });

    test('a garage lap at ambient crowns no hottest corner', () {
      // RL 32.13 against RR 32.05 °C: a tie, not a finding.
      expect(report.hottestOn(_lap(report, 0)), isNull);
    });

    test('the lap-3 spin shows as rear-right wear, in one lap', () {
      final lap3 = _lap(report, 3);
      final rr = report.wear![Corner.rearRight]!.laps[3];
      expect(rr.used, closeTo(95.3554 - 85.7423, 1e-9));
      expect(rr.representative, isTrue,
          reason: 'a spin is racing, not a reason to leave the lap out');
      expect(report.mostWornOn(lap3), Corner.rearRight);
    });

    test('tyres climb from ambient lap after lap', () {
      final carcass = [
        for (var lap = 0; lap <= 3; lap++)
          report.carcass!.at(Corner.frontLeft, lap)!.mean,
      ];
      expect(carcass.first, closeTo(28.9472, 1e-4));
      for (var i = 1; i < carcass.length; i++) {
        expect(carcass[i], greaterThan(carcass[i - 1]));
      }
      expect(report.setup.coldPressure[Corner.frontLeft]!.number, 131);
    });
  });

  group('TyreSetup', () {
    test('reads stringValue, not lastSavedStringValue', () {
      final setup = TyreSetup.fromJson(sebringRaceTyreSetupJson);
      // lastSavedStringValue says -5.00 deg and 57.0:43.0 here; the car ran
      // what stringValue says, which the Brake Bias Rear event confirms.
      expect(setup.camber[Corner.frontLeft]!.text, '-2.30 deg');
      expect(setup.camber[Corner.frontLeft]!.number, -2.3);
      expect(setup.brakeBalance!.text, '51.2:48.8');
      expect(setup.compound[Corner.frontLeft]!.text, 'Medium');
      expect(setup.brakePressure!.text, '108 kgf (90%)');
    });

    test('says a symmetric group once per axle', () {
      final setup = TyreSetup.fromJson(sebringRaceTyreSetupJson);
      expect(describeAxles(setup.coldPressure), [('All four', '136 kPa')]);
      expect(describeAxles(setup.camber),
          [('Front', '-2.30 deg'), ('Rear', '-1.50 deg')]);
      expect(describeAxles(setup.discThickness),
          [('Front', '3.56 cm'), ('Rear', '3.20 cm')]);
    });

    test('an asymmetric group is said per corner', () {
      final values = {
        Corner.frontLeft: SetupValue.parse('136 kPa')!,
        Corner.frontRight: SetupValue.parse('138 kPa')!,
        Corner.rearLeft: SetupValue.parse('136 kPa')!,
        Corner.rearRight: SetupValue.parse('136 kPa')!,
      };
      expect(describeAxles(values).map((r) => r.$1), ['FL', 'FR', 'RL', 'RR']);
    });

    test('a missing or malformed blob is an empty setup, not an error', () {
      expect(TyreSetup.fromJson('{}').isEmpty, isTrue);
      expect(TyreSetup.fromJson('not json').isEmpty, isTrue);
      expect(TyreSetup.fromJson('[1, 2]').isEmpty, isTrue);
      expect(SetupValue.parse('N/A'), isNull);
      expect(SetupValue.parse(' 0.0')!.number, 0);
      expect(SetupValue.parse('2.5% F')!.number, 2.5);
    });

    test('Spa: the Hypercar’s own numbers', () {
      final setup = TyreSetup.fromJson(spaQualifyTyreSetupJson);
      expect(setup.brakeMigration!.text, '2.5% F');
      expect(describeAxles(setup.discThickness), [('All four', '4.00 cm')]);
      expect(describeAxles(setup.compound), [('All four', 'Soft')]);
    });
  });

  group('CornerSeries', () {
    LapChannelStats flat(int lap) => LapChannelStats(
        lapIndex: lap, first: 3.56, last: 3.56, min: 3.56, max: 3.56,
        mean: 3.56, samples: 640);

    test('a channel with one value all session is flat', () {
      // The shape `Brake Thickness` has at two decimals: a setup value, not
      // a trace.
      final series = CornerSeries(
        channelName: 'Brake Thickness',
        byCorner: {
          for (final corner in Corner.values) corner: [flat(0), flat(1)],
        },
      );
      expect(series.isFlatEverywhere, isTrue);
      expect(series.isEmpty, isFalse);
    });

    test('a varying channel is not', () {
      final pressure = CornerSeries(
        channelName: tyrePressureChannelName,
        byCorner: sebringRacePressure(),
      );
      expect(pressure.isFlatEverywhere, isFalse);
      expect(pressure.at(Corner.rearRight, 99), isNull);
    });
  });

  test('a tyre change reads as one, not as a refill', () {
    expect(exclusionLabel(UsageExclusion.refilled), 'tyres changed');
    expect(exclusionLabel(UsageExclusion.outLap), 'out lap');
  });
}
