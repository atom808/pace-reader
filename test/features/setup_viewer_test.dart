// The car-setup parse and grouping (SPEC.md §8.10), against the real JSON of
// all three samples.
//
// Most of what is asserted here is *not* "the parser returns what it was
// given". The fields of a setting object are easy to read plausibly and wrong
// (§5's v0.7 note), so the interesting tests hold a derived reading up against
// something independent of the field: the telemetry in the same file, or
// arithmetic across settings. `car_setup_samples.dart` carries those
// telemetry figures, and `tool/make_car_setup_fixture.py` shows how each was
// queried.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup.dart';

import '../fixtures/car_setup_samples.dart';

final _samples = {
  'Interlagos (Practice, GT3)': interlagosCarSetup,
  'Spa (Qualify, Hypercar)': spaCarSetup,
  'Sebring (Race, GT3)': sebringCarSetup,
};

/// The first number in a game-formatted string: `-1.8 deg` → -1.8,
/// `8,250` → 8250, `40.9L (22.0 laps)` → 40.9.
double _leading(String text) => double.parse(
      RegExp(r'-?\d+(\.\d+)?').firstMatch(text.replaceAll(',', ''))!.group(0)!,
    );

Map<String, dynamic> _raw(CarSetupSample s) =>
    jsonDecode(s.json) as Map<String, dynamic>;

void main() {
  group('shape, on every sample', () {
    for (final MapEntry(:key, :value) in _samples.entries) {
      test(key, () {
        final setup = CarSetup.parse(value.json);
        final raw = _raw(value);

        // 172 top-level keys: 170 settings + gearGraph + symmetric.
        expect(raw, hasLength(172));
        expect(setup.settingCount, 170);
        expect(setup.rawCount, 0);
        expect(setup.total, 170);

        // Nothing dropped, nothing invented: every key is either one of the
        // two special entries or exactly one setting.
        final keys = setup.allSettings.map((s) => s.key).toList();
        expect(keys.toSet(), hasLength(170), reason: 'no key listed twice');
        expect(
          keys.toSet(),
          raw.keys.toSet()..removeAll(['gearGraph', 'symmetric']),
        );

        // The catalogue is complete for the real files: had it forgotten a
        // key, that key would be misfiled under Other with a generic label.
        expect(setup.section(SetupSectionId.other), isNull);

        // Sections come out in setup-sheet order.
        final order = setup.sections.map((s) => s.id.index).toList();
        expect(order, [...order]..sort());
        expect(order, isNotEmpty);
      });
    }

    test('the same keys in the same order in all three files', () {
      final orders = [
        for (final s in _samples.values) _raw(s).keys.toList(),
      ];
      expect(orders[1], orders[0]);
      expect(orders[2], orders[0]);
    });

    test('15 per-wheel groups of four, laid out FL FR RL RR', () {
      for (final s in _samples.values) {
        final setup = CarSetup.parse(s.json);
        final groups = [
          for (final section in setup.sections) ...section.wheelGroups,
        ];
        expect(groups, hasLength(15));
        for (final group in groups) {
          expect(group.corners.keys, WheelCorner.values, reason: group.id);
          for (final MapEntry(:key, :value) in group.corners.entries) {
            // The corner comes from the JSON key itself, so labelling it is
            // safe — unlike telemetry's value1..4 (§15.5).
            expect(value.key, 'WM_${group.id}-W_${key.code}');
            expect(value.corner, key);
          }
        }
      }
    });

    test('front and rear read differently where the car says they do', () {
      // Sebring: camber -2.30 front, -1.50 rear; brake discs 3.56 / 3.20 cm.
      final setup = CarSetup.parse(sebringCarSetup.json);
      final camber = setup.wheelGroup('CAMBER')!;
      expect(camber.corners[WheelCorner.fl]!.display, '-2.30 deg');
      expect(camber.corners[WheelCorner.fr]!.display, '-2.30 deg');
      expect(camber.corners[WheelCorner.rl]!.display, '-1.50 deg');
      expect(camber.corners[WheelCorner.rr]!.display, '-1.50 deg');
      final discs = setup.wheelGroup('BRAKEDISC')!;
      expect(discs.corners[WheelCorner.fl]!.display, '3.56 cm');
      expect(discs.corners[WheelCorner.rr]!.display, '3.20 cm');
    });
  });

  group('what the fields mean', () {
    test('value is a step index inside 0..maxValue, and min is always 0', () {
      for (final s in _samples.values) {
        for (final setting in CarSetup.parse(s.json).allSettings) {
          expect(setting.minValue, 0, reason: setting.key);
          expect(setting.value, inInclusiveRange(0, setting.maxValue),
              reason: setting.key);
          expect(setting.maxValue, greaterThan(setting.minValue),
              reason: setting.key);
        }
      }
    });

    test('lastSavedStringValue is the lowest step, not a saved setup', () {
      // Interlagos camber sits at index 32 on the front and 25 on the rear,
      // from -5.0 and -3.8 degrees at index 0. If `lastSaved` were "the setup
      // as last saved" those origins would be arbitrary; instead both corners
      // work out to the same 0.1 deg step — an origin common to the list.
      final setup = CarSetup.parse(interlagosCarSetup.json);
      final camber = setup.wheelGroup('CAMBER')!;
      double step(WheelCorner c) {
        final s = camber.corners[c]!;
        return (_leading(s.display) - _leading(s.lastSavedStringValue)) /
            s.value;
      }

      expect(camber.corners[WheelCorner.fl]!.value, 32);
      expect(camber.corners[WheelCorner.rl]!.value, 25);
      expect(step(WheelCorner.fl), closeTo(0.1, 1e-9));
      expect(step(WheelCorner.rl), closeTo(0.1, 1e-9));

      // Brake bias walks 0.25 points a step from 57.0 down to 50.5.
      final bias = setup.byKey('VM_BRAKE_BALANCE')!;
      expect(bias.lastSavedStringValue, '57.0:43.0');
      expect((57.0 - _leading(bias.display)) / bias.value, closeTo(0.25, 0.01));

      // And it equals the current string wherever the setting is at step 0.
      var atZero = 0;
      for (final s in setup.allSettings.where((s) => s.value == 0)) {
        if (s.lastSavedStringValue == s.stringValue) atZero++;
      }
      expect(atZero, 120);
    });

    test('available=false always means N/A with value 0, and matches the gears',
        () {
      const unavailable = {'Interlagos (Practice, GT3)': 11, 'Spa (Qualify, Hypercar)': 10, 'Sebring (Race, GT3)': 11};
      for (final MapEntry(:key, :value) in _samples.entries) {
        final setup = CarSetup.parse(value.json);
        final off = setup.allSettings.where((s) => !s.available).toList();
        expect(off, hasLength(unavailable[key]!), reason: key);
        for (final s in off) {
          expect(s.display, 'N/A', reason: s.key);
          expect(s.value, 0, reason: s.key);
          expect(s.isNotApplicable, isTrue);
        }
        // The gear slots the car has are exactly gearGraph's forward gears.
        final gears = List.generate(9, (i) => 'VM_GEAR_${i + 1}');
        final present =
            gears.where((k) => setup.byKey(k)!.available).length;
        expect(present, setup.gears!.steps.length, reason: key);
      }
    });

    test('N/A is wider than available=false', () {
      // 58 / 38 / 54 settings read N/A; only 11 / 10 / 11 are unavailable.
      expect(CarSetup.parse(interlagosCarSetup.json).notApplicableCount, 58);
      expect(CarSetup.parse(spaCarSetup.json).notApplicableCount, 38);
      expect(CarSetup.parse(sebringCarSetup.json).notApplicableCount, 54);
    });

    test('a locked setting is one the session does not let you change', () {
      final practice = CarSetup.parse(interlagosCarSetup.json);
      final qualify = CarSetup.parse(spaCarSetup.json);
      final race = CarSetup.parse(sebringCarSetup.json);

      expect(practice.lockedCount, 0);
      expect(qualify.lockedCount, 0);
      expect(practice.hasLockedSettings, isFalse);
      expect(qualify.hasLockedSettings, isFalse);

      expect(race.lockedCount, 143);
      expect(race.adjustableCount, 27);
      expect(race.hasLockedSettings, isTrue);

      // The 27 are what a fixed-setup race leaves the driver.
      final free = race.allSettings.where((s) => s.isFree).map((s) => s.key);
      expect(
        free,
        containsAll([
          'VM_BRAKE_BALANCE',
          'VM_BRAKE_MIGRATION',
          'VM_TRACTIONCONTROLMAP',
          'VM_ANTILOCKBRAKESYSTEMMAP',
          'VM_FUEL_LEVEL',
          'VM_VIRTUAL_ENERGY',
          'VM_STEER_LOCK',
          'WM_COMPOUND-W_FL',
        ]),
      );
      // ...and none of the garage settings.
      final locked = race.allSettings.where((s) => s.isLocked).map((s) => s.key);
      expect(
        locked,
        containsAll(['WM_CAMBER-W_FL', 'WM_SPRING-W_RR', 'VM_REAR_WING', 'WM_PRESSURE-W_FL']),
      );
    });

    test('numChangesValue is a signed step count, non-zero only in Qualify', () {
      expect(CarSetup.parse(interlagosCarSetup.json).movedCount, 0);
      expect(CarSetup.parse(sebringCarSetup.json).movedCount, 0);

      final spa = CarSetup.parse(spaCarSetup.json);
      expect(spa.movedCount, 5);
      final energy = spa.byKey('VM_VIRTUAL_ENERGY')!;
      expect(energy.stepsMoved, -74);
      // 26 % now, against the 100 % Practice starts at: 26 - 100 = -74.
      expect(energy.value - 100, energy.stepsMoved);
      for (final corner in WheelCorner.values) {
        expect(
          spa.byKey('WM_COMPOUND-W_${corner.code}')!.stepsMoved,
          -1,
          reason: corner.code,
        );
      }
      expect(
        spa.allSettings.where((s) => s.isMoved).map((s) => s.key).toSet(),
        {
          'VM_VIRTUAL_ENERGY',
          'WM_COMPOUND-W_FL',
          'WM_COMPOUND-W_FR',
          'WM_COMPOUND-W_RL',
          'WM_COMPOUND-W_RR',
        },
      );
    });

    test('symmetric is true, and every left/right pair really is identical', () {
      for (final MapEntry(:key, :value) in _samples.entries) {
        final setup = CarSetup.parse(value.json);
        expect(setup.symmetric, isTrue, reason: key);
        for (final section in setup.sections) {
          for (final group in section.wheelGroups) {
            expect(group.isMirrored, isTrue, reason: '$key ${group.id}');
            for (final (a, b) in [
              (WheelCorner.fl, WheelCorner.fr),
              (WheelCorner.rl, WheelCorner.rr),
            ]) {
              final left = group.corners[a]!;
              final right = group.corners[b]!;
              expect(right.value, left.value, reason: '$key ${group.id}');
              expect(right.maxValue, left.maxValue);
              expect(right.available, left.available);
              expect(right.isFree, left.isFree);
            }
          }
        }
        for (final (l, r) in [
          ('VM_LEFT_CASTER', 'VM_RIGHT_CASTER'),
          ('VM_LEFT_FENDER_FLARE', 'VM_RIGHT_FENDER_FLARE'),
          ('VM_LEFT_TRACK_BAR', 'VM_RIGHT_TRACK_BAR'),
        ]) {
          expect(setup.byKey(r)!.display, setup.byKey(l)!.display, reason: key);
          expect(setup.byKey(r)!.value, setup.byKey(l)!.value, reason: key);
        }
      }
    });

    test('range: a track only where there is a middle to point at', () {
      final setup = CarSetup.parse(sebringCarSetup.json);
      // Brake bias: step 23 of 57.
      final bias = setup.byKey('VM_BRAKE_BALANCE')!;
      expect(bias.hasRange, isTrue);
      expect(bias.steps, 57);
      expect(bias.rangeFraction, closeTo(23 / 57, 1e-9));
      // "Available" is a two-option switch — no track.
      final abs = setup.byKey('VM_ANTILOCK_BRAKES')!;
      expect(abs.maxValue, 1);
      expect(abs.hasRange, isFalse);
      // Of the settings that read as something, 60 have a range and 56 do not.
      final shown = setup.allSettings.where((s) => !s.isNotApplicable);
      expect(shown.where((s) => s.hasRange), hasLength(60));
      expect(shown.where((s) => !s.hasRange), hasLength(56));
    });
  });

  group('against the telemetry of the same file', () {
    for (final MapEntry(:key, :value) in _samples.entries) {
      test(key, () {
        final setup = CarSetup.parse(value.json);
        SetupSetting s(String k) => setup.byKey(k)!;

        // `VM_BRAKE_BALANCE` reads front:rear, and the rear share is the
        // `Brake Bias Rear` event.
        final rear = double.parse(s('VM_BRAKE_BALANCE').display.split(':').last);
        expect(rear, closeTo(value.brakeBiasRear * 100, 0.06));

        // TC and ABS maps are the levels the events record.
        expect(s('VM_TRACTIONCONTROLMAP').value, value.tcLevel);
        expect(s('VM_ANTILOCKBRAKESYSTEMMAP').value, value.absLevel);

        // Virtual energy's step index *is* the percentage at the start.
        expect(s('VM_VIRTUAL_ENERGY').value, value.firstVirtualEnergy.round());

        // The litres in the fuel string are what the tank held at the start,
        // whatever the key says.
        expect(
          _leading(s('VM_FUEL_CAPACITY').display),
          closeTo(value.firstFuelLevel, 0.06),
        );

        // Brake-disc thickness, corner for corner, in the order the file
        // gives the telemetry — which also shows front-then-rear.
        final discs = setup.wheelGroup('BRAKEDISC')!;
        for (var i = 0; i < 4; i++) {
          expect(
            _leading(discs.corners[WheelCorner.values[i]]!.display),
            closeTo(value.brakeThicknessFirst[i], 0.005),
            reason: WheelCorner.values[i].code,
          );
        }
      });
    }
  });

  group('gear graph', () {
    test('decodes the pairs: peak rpm and rpm after the upshift', () {
      final gears = CarSetup.parse(sebringCarSetup.json).gears!;
      expect(gears.unit, 'kph');
      expect(gears.steps, hasLength(6));

      final first = gears.steps.first;
      expect(first.gear, 1);
      expect(first.topSpeed, closeTo(106.99, 0.01));
      expect(first.upshiftRpm, closeTo(7500, 0.01));
      expect(first.rpmAfterUpshift, closeTo(5760.87, 0.01));
      expect(first.rpmDrop, closeTo(1739.13, 0.01));
      // First gear starts at a standstill.
      expect(first.entrySpeed, 0);
      expect(first.entryRpm, 0);

      // Second gear starts where first ended, at the post-shift rpm.
      final second = gears.steps[1];
      expect(second.entrySpeed, first.topSpeed);
      expect(second.entryRpm, first.rpmAfterUpshift);

      // Top gear has no next gear to drop into.
      final last = gears.steps.last;
      expect(last.gear, 6);
      expect(last.topSpeed, closeTo(291.83, 0.01));
      expect(last.rpmAfterUpshift, isNull);
      expect(last.rpmDrop, isNull);
    });

    test('seven gears at Spa', () {
      final gears = CarSetup.parse(spaCarSetup.json).gears!;
      expect(gears.steps, hasLength(7));
      expect(gears.steps.first.upshiftRpm, closeTo(8500, 0.01));
      expect(gears.steps.last.topSpeed, closeTo(323.40, 0.01));
      expect(gears.maxRpm, closeTo(8500, 0.01));
      expect(gears.maxSpeed, gears.steps.last.topSpeed);
    });

    test('speeds rise, and each shift drops onto the next gear\'s line', () {
      // The after-upshift rpm of gear g is where gear g+1's line passes at g's
      // top speed: topSpeed[g] / topSpeed[g+1] * peak[g+1]. That is what makes
      // reading kiloRPM as (peak, after) pairs right, and not merely tidy.
      for (final MapEntry(:key, :value) in _samples.entries) {
        final steps = CarSetup.parse(value.json).gears!.steps;
        for (var i = 0; i < steps.length - 1; i++) {
          final now = steps[i];
          final next = steps[i + 1];
          expect(next.topSpeed, greaterThan(now.topSpeed), reason: key);
          final predicted = now.topSpeed / next.topSpeed * next.upshiftRpm;
          expect(now.rpmAfterUpshift!, closeTo(predicted, 40),
              reason: '$key gear ${now.gear}');
        }
      }
    });

    test('the peak is the rev limit the car actually reached', () {
      for (final MapEntry(:key, :value) in _samples.entries) {
        final gears = CarSetup.parse(value.json).gears!;
        expect(gears.maxRpm, closeTo(value.peakEngineRpm, 16), reason: key);
      }
    });

    test('nominal top speeds are a few percent under what the car ran', () {
      // Median speed per 1000 rpm in each gear, from telemetry, against the
      // graph's topSpeed / peak. 1.4 % to 8.3 % higher across all three files
      // — the reason the viewer calls these nominal figures.
      var lowest = double.infinity;
      var highest = 0.0;
      for (final MapEntry(:key, :value) in _samples.entries) {
        final steps = CarSetup.parse(value.json).gears!.steps;
        for (final step in steps) {
          final measured = value.kphPerKrpmByGear[step.gear];
          if (measured == null) continue;
          final nominal = step.topSpeed / (step.upshiftRpm / 1000);
          final excess = measured / nominal - 1;
          expect(excess, inInclusiveRange(0.01, 0.09),
              reason: '$key gear ${step.gear}');
          if (excess < lowest) lowest = excess;
          if (excess > highest) highest = excess;
        }
      }
      expect(lowest, closeTo(0.014, 0.001));
      expect(highest, closeTo(0.083, 0.001));
    });

    test('a malformed gearGraph is kept as a raw entry, not lost', () {
      final setup = CarSetup.parse(jsonEncode({
        'gearGraph': {'numForwardGears': 3, 'topSpeed': [0, 100]},
        'symmetric': true,
      }));
      expect(setup.gears, isNull);
      expect(setup.rawCount, 1);
      final raw = setup.byKey('gearGraph')!;
      expect(raw.isRaw, isTrue);
      expect(raw.display, contains('numForwardGears'));
    });
  });

  group('labels, sections and captions', () {
    test('humanised keys', () {
      final spa = CarSetup.parse(spaCarSetup.json);
      expect(spa.byKey('VM_FRONT_3RD_SLOWBUMP')!.label, 'Front 3rd · slow bump');
      expect(spa.byKey('VM_REAR_3RD_TENDERSPRINGTRAVEL')!.label,
          'Rear 3rd · tender spring travel');
      expect(spa.byKey('VM_FRONT_TOEIN')!.label, 'Front toe-in');
      expect(spa.byKey('VM_TRACTIONCONTROLSLIPANGLEMAP')!.label,
          'TC slip-angle map');
      expect(spa.byKey('VM_GEAR_UPSHIFT_RPM_3')!.label, 'Gear 3 upshift rpm');
      expect(spa.byKey('VM_CHASSIS_ADJ_07')!.label, 'Chassis adjuster 07');
      expect(spa.wheelGroup('SLOWREBOUND')!.label, 'Damper · slow rebound');
      expect(spa.byKey('WM_SLOWREBOUND-W_RL')!.label, 'Damper · slow rebound');
    });

    test('sections', () {
      final setup = CarSetup.parse(sebringCarSetup.json);
      SetupSectionId? sectionOf(String key) {
        for (final section in setup.sections) {
          if (section.singles.any((s) => s.key == key)) return section.id;
          for (final g in section.wheelGroups) {
            if (g.settings.any((s) => s.key == key)) return section.id;
          }
        }
        return null;
      }

      expect(sectionOf('VM_REAR_WING'), SetupSectionId.aero);
      expect(sectionOf('VM_BRAKE_BALANCE'), SetupSectionId.brakes);
      expect(sectionOf('WM_BRAKEDISC-W_FL'), SetupSectionId.brakes);
      expect(sectionOf('WM_SLOWBUMP-W_FL'), SetupSectionId.suspension);
      expect(sectionOf('VM_FRONT_ANTISWAY'), SetupSectionId.suspension);
      expect(sectionOf('VM_FRONT_3RD_PACKERS'), SetupSectionId.suspension);
      expect(sectionOf('WM_CAMBER-W_RR'), SetupSectionId.alignment);
      expect(sectionOf('VM_REAR_TOEIN'), SetupSectionId.alignment);
      expect(sectionOf('WM_PRESSURE-W_FL'), SetupSectionId.tyres);
      expect(sectionOf('VM_FRONT_TIRE_COMPOUND'), SetupSectionId.tyres);
      expect(sectionOf('VM_DIFF_PRELOAD'), SetupSectionId.differential);
      expect(sectionOf('VM_GEAR_3'), SetupSectionId.gearing);
      expect(sectionOf('VM_TRACTIONCONTROLMAP'), SetupSectionId.electronics);
      expect(sectionOf('VM_ANTILOCK_BRAKES'), SetupSectionId.electronics);
      expect(sectionOf('VM_REV_LIMITER'), SetupSectionId.engine);
      expect(sectionOf('VM_FUEL_LEVEL'), SetupSectionId.engine);
      expect(sectionOf('VM_VIRTUAL_ENERGY'), SetupSectionId.engine);
    });

    test('the game\'s captions: shown once, in sentence case, or not at all',
        () {
      for (final s in _samples.values) {
        final setup = CarSetup.parse(s.json);
        // "Max Pedal Force" in two files and "MAX PEDAL FORCE" in the third
        // read the same.
        expect(setup.byKey('VM_BRAKE_PRESSURE')!.caption, 'Max pedal force');
        expect(setup.byKey('VM_STEER_LOCK')!.caption, 'Wheel range (lock)');
        expect(setup.byKey('VM_LEFT_FENDER_FLARE')!.caption, 'Dive plane');
        // Repeats of the label say nothing new.
        expect(setup.byKey('VM_OIL_RADIATOR')!.caption, isNull);
        expect(setup.byKey('VM_WATER_RADIATOR')!.caption, isNull);
      }
      // A single space is not a caption.
      expect(
        CarSetup.parse(interlagosCarSetup.json)
            .byKey('VM_HANDFRONTBRAKE_PRESSURE')!
            .caption,
        isNull,
      );
      // Spa's one extra caption names an otherwise anonymous slot.
      expect(
        CarSetup.parse(spaCarSetup.json).byKey('VM_CHASSIS_ADJ_00')!.caption,
        'Front pushrod',
      );
    });

    test('display trims the game\'s padding but keeps its wording', () {
      final sebring = CarSetup.parse(sebringCarSetup.json);
      expect(sebring.byKey('VM_BRAKE_MIGRATION')!.stringValue, ' 0.0');
      expect(sebring.byKey('VM_BRAKE_MIGRATION')!.display, '0.0');
      expect(sebring.byKey('VM_STEER_LOCK')!.display, '516 deg(19.7 )');
      expect(sebring.byKey('VM_FUEL_CAPACITY')!.display, '40.9L (22.0 laps)');
    });

    test('a fixed value is stated quietly', () {
      final sebring = CarSetup.parse(sebringCarSetup.json);
      expect(sebring.byKey('VM_DIFF_COAST')!.isFixedByCar, isTrue);
      expect(sebring.byKey('VM_GEAR_FINAL')!.isFixedByCar, isTrue);
      expect(sebring.byKey('VM_BRAKE_BALANCE')!.isFixedByCar, isFalse);
    });
  });

  group('unknown and malformed input', () {
    test('blank means no setup', () {
      expect(CarSetup.parse('').isEmpty, isTrue);
      expect(CarSetup.parse('  \n').isEmpty, isTrue);
      expect(CarSetup.empty.total, 0);
    });

    test('text that is not a JSON object is an error, not a blank page', () {
      expect(() => CarSetup.parse('not json'), throwsA(isA<SetupFormatException>()));
      expect(() => CarSetup.parse('[1, 2]'), throwsA(isA<SetupFormatException>()));
      expect(() => CarSetup.parse('42'), throwsA(isA<SetupFormatException>()));
      expect(
        () => CarSetup.parse('[1]'),
        throwsA(predicate((e) => e.toString().contains('list'))),
      );
    });

    test('keys this build does not know go to Other, in file order', () {
      Map<String, Object?> setting(String text, {int value = 1}) => {
            'available': true,
            'stringValue': text,
            'value': value,
            'minValue': 0,
            'maxValue': 9,
            'isFreeSetting': true,
            'numChangesValue': 0,
            'diffComparisonValue': 0,
            'lastSavedStringValue': 'x',
            'key': 'irrelevant',
          };
      final setup = CarSetup.parse(jsonEncode({
        'VM_NEW_THING': setting('7 units'),
        'VM_BRAKE_BALANCE': setting('50.0:50.0'),
        'WM_SHINY_BITS-W_FL': setting('a'),
        'WM_SHINY_BITS-W_FR': setting('b'),
        'WM_SHINY_BITS-W_RL': setting('c'),
        'WM_SHINY_BITS-W_RR': setting('d'),
        'WM_ODD_CORNER-W_XX': setting('e'),
        'VM_ANOTHER_NEW': setting('8 units'),
        'mystery': [1, 2, 3],
        'note': 'hello',
        'symmetric': false,
      }));

      final other = setup.section(SetupSectionId.other)!;
      expect(other.singles.map((s) => s.key), [
        'VM_NEW_THING',
        'WM_ODD_CORNER-W_XX',
        'VM_ANOTHER_NEW',
        'mystery',
        'note',
      ]);
      expect(other.singles.first.label, 'New thing');
      // A per-wheel group nobody catalogued still lays out as a 2x2.
      expect(other.wheelGroups.single.id, 'SHINY_BITS');
      expect(other.wheelGroups.single.label, 'Shiny bits');
      expect(other.wheelGroups.single.corners.keys, WheelCorner.values);
      // The known key is filed where it belongs.
      expect(setup.section(SetupSectionId.brakes)!.singles.single.key,
          'VM_BRAKE_BALANCE');

      // Raw entries are rows too, as JSON text, and counted apart.
      expect(setup.byKey('mystery')!.display, '[1,2,3]');
      expect(setup.byKey('note')!.display, '"hello"');
      expect(setup.byKey('mystery')!.hasRange, isFalse);
      expect(setup.rawCount, 2);
      expect(setup.settingCount, 8);
      expect(setup.total, 10);
      expect(setup.symmetric, isFalse);
    });

    test('a setting object missing optional fields still parses', () {
      final setup = CarSetup.parse(jsonEncode({
        'VM_FRONT_WING': {'stringValue': '5 deg', 'value': 3},
      }));
      final wing = setup.byKey('VM_FRONT_WING')!;
      expect(wing.display, '5 deg');
      expect(wing.isFree, isTrue);
      expect(wing.available, isTrue);
      expect(wing.maxValue, 0);
      expect(wing.rangeFraction, isNull);
      expect(wing.hasRange, isFalse);
    });

    test('a long raw value is cut, with an ellipsis', () {
      final setup = CarSetup.parse(jsonEncode({'blob': List.filled(200, 1234)}));
      final shown = setup.byKey('blob')!.display;
      expect(shown.length, 158);
      expect(shown.endsWith('…'), isTrue);
    });
  });

  group('filtering', () {
    final race = CarSetup.parse(sebringCarSetup.json);

    test('by default the N/A settings are hidden, and counted', () {
      final view = race.apply(const SetupFilter());
      expect(view.total, 170);
      expect(view.shown, 116);
      expect(view.hiddenNotApplicable, 54);
      expect(view.hiddenLocked, 0);
    });

    test('show N/A brings all 170 back', () {
      final view = race.apply(const SetupFilter(showNotApplicable: true));
      expect(view.shown, 170);
      expect(view.hiddenNotApplicable, 0);
      // A group that is N/A on all four corners is in the Suspension section.
      expect(
        view.section(SetupSectionId.suspension)!.wheelGroups.map((g) => g.id),
        contains('SRUBBER'),
      );
      expect(
        race.apply(const SetupFilter()).section(SetupSectionId.suspension)!
            .wheelGroups.map((g) => g.id),
        isNot(contains('SRUBBER')),
      );
    });

    test('adjustable only keeps what a fixed-setup race lets you change', () {
      final view = race.apply(const SetupFilter(adjustableOnly: true));
      // 27 are free; 5 of them read N/A (handbrake pressures, pit-stop slots).
      expect(view.shown, 22);
      expect(view.hiddenLocked, 116 - 22);
      // N/A is checked first, so all 54 count as hidden for that reason.
      expect(view.hiddenNotApplicable, 54);
      expect(
        view.sections.expand((s) => s.singles).every((s) => s.isFree),
        isTrue,
      );
      // With N/A back on, all 27.
      expect(
        race
            .apply(const SetupFilter(adjustableOnly: true, showNotApplicable: true))
            .shown,
        27,
      );
    });

    test('a practice session has nothing locked to filter', () {
      final practice = CarSetup.parse(interlagosCarSetup.json);
      expect(practice.apply(const SetupFilter(adjustableOnly: true)).shown, 112);
      expect(practice.apply(const SetupFilter()).shown, 112);
      expect(CarSetup.parse(spaCarSetup.json).apply(const SetupFilter()).shown, 132);
    });

    test('text: one group by name, across the four corners', () {
      final view = race.apply(const SetupFilter(query: 'camber'));
      expect(view.sections.map((s) => s.id), [SetupSectionId.alignment]);
      expect(view.sections.single.singles, isEmpty);
      expect(view.sections.single.wheelGroups.single.id, 'CAMBER');
      expect(view.shown, 4);
    });

    test('text: every word must hit, in any order', () {
      final both = race.apply(const SetupFilter(query: 'rear wing'));
      expect(both.sections.single.singles.single.key, 'VM_REAR_WING');
      final reversed = race.apply(const SetupFilter(query: 'WING  rear'));
      expect(reversed.shown, both.shown);
      expect(race.apply(const SetupFilter(query: 'rear zzz')).shown, 0);
    });

    test('text: the raw key, the caption and the section title all match', () {
      expect(
        race.apply(const SetupFilter(query: 'VM_BRAKE_BALANCE')).shown,
        1,
      );
      // The caption, "Max pedal force", belongs to the brake pressure setting.
      final byCaption = race.apply(const SetupFilter(query: 'pedal force'));
      expect(byCaption.sections.single.singles.single.key, 'VM_BRAKE_PRESSURE');
      // A section title pulls in the whole section (minus N/A).
      final aero = race.apply(const SetupFilter(query: 'aero'));
      expect(aero.sections.single.id, SetupSectionId.aero);
      expect(aero.sections.single.count, greaterThanOrEqualTo(2));
    });

    test('text: the displayed value matches, so "soft" finds what reads soft',
        () {
      // Spa: both compounds and the tyre-compound group, and the fast-rebound
      // damper group whose rear pair reads "1 (soft)". A group is shown whole
      // — all four corners — so the count is 2 + 4 + 4.
      final spa = CarSetup.parse(spaCarSetup.json);
      final view = spa.apply(const SetupFilter(query: 'soft'));
      expect(view.shown, 10);
      expect(
        view.section(SetupSectionId.tyres)!.singles.map((s) => s.key),
        ['VM_FRONT_TIRE_COMPOUND', 'VM_REAR_TIRE_COMPOUND'],
      );
      expect(
        view.section(SetupSectionId.suspension)!.wheelGroups.single.id,
        'FASTREBOUND',
      );
    });

    test('text: a corner can be named', () {
      final view = race.apply(const SetupFilter(query: 'rear right camber'));
      expect(view.sections.single.wheelGroups.single.id, 'CAMBER');
    });

    test('a query that only N/A settings match says so', () {
      final view = race.apply(const SetupFilter(query: 'gear 7'));
      expect(view.shown, 0);
      expect(view.hiddenNotApplicable, greaterThan(0));
      final shown = race.apply(
        const SetupFilter(query: 'gear 7', showNotApplicable: true),
      );
      expect(shown.shown, view.hiddenNotApplicable);
    });

    test('SetupFilter is a value', () {
      expect(const SetupFilter(query: 'a'), const SetupFilter(query: 'a'));
      expect(const SetupFilter(query: 'a'), isNot(const SetupFilter(query: 'b')));
      expect(const SetupFilter().copyWith(adjustableOnly: true).adjustableOnly,
          isTrue);
      expect(const SetupFilter(query: '  Front   CAMBER ').tokens, ['front', 'camber']);
    });
  });
}
