// The car catalog: CarName entries read into models (SPEC.md §15.6),
// checked against the game's own logs and the library's names.
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/reference/car_catalog.dart';
import 'package:pace_reader/data/reference/car_class.dart';

import '../fixtures/car_entries.dart';

/// The install's `Installed\Vehicles` folders on 2026-10-14.
const _installFolders = [
  '911GT3R_2024',
  '992S_PC_2023',
  'ADESS_AD25_2026',
  'Alpine_A424_2024',
  'Aston_Martin_Valkyrie_2025',
  'Aston_Martin_Vantage_AMR_2023',
  'BMW_M4_LMGT3_2023',
  'BMW_M_Hybrid_V8_2023',
  'Cadillac_V-lmdh_2023',
  'Chevrolet_C8R_LM_2023',
  'Corvette_Z06GT3R_2023',
  'Duqueine_D09LMP3_2026',
  'Ferrari_296GT3_2023',
  'Ferrari_488GTE_LM_2023',
  'Ferrari_499P_2023',
  'Ford_Mustang_GT3_2024',
  'Genesis_GMR001_2026',
  'Ginetta_G61Evo_2025',
  'Isotta_Tipo6_2024',
  'Lamborghini_Huracan_GT3_2024',
  'Lamborghini_SC63_2024',
  'LexusRCF_GT3_2024',
  'Ligier_JSP325_2025',
  'McLaren_720sGChallenge_2026',
  'McLaren_720sGT3Evo_2023',
  'Mercedes_AMGGT3Evo_2025',
  'Oreca_07_ELMS_2023',
  'Oreca_07_LM_2023',
  'Peugeot_9x8_2023',
  'Peugeot_9x8_2024',
  'Porsche_911RSR-19_2023',
  'Porsche_963_2023',
  'SGC_007_2023',
  'Toyota_GR10_2023',
  'Vandervell_680_2023',
  'Vantage_AMR_GT3Evo_2024',
];

/// A third-party setup shop's prefixes, which name the car too.
const _shopSetups = {
  'CDA_499P': CarModel.ferrari499p,
  'CDA_BMWV8': CarModel.bmwMHybridV8,
  'CDA_9X8': CarModel.peugeot9x8,
  'CDA_9X8W': CarModel.peugeot9x8of2024,
  'CDA_P963': CarModel.porsche963,
  'CDA_LMP2ELMS': CarModel.oreca07,
  'CDA_CSVR': CarModel.cadillacVSeriesR,
  'CDA_AMVK': CarModel.astonMartinValkyrie,
  'CDA_AMV8': CarModel.astonMartinVantageGt3,
  'CDA_A424': CarModel.alpineA424,
};

/// The class code a recording of [model] would carry.
String _classCode(CarModel model) => switch (model.kind) {
  CarClassKind.hypercar => 'Hyper',
  CarClassKind.lmp2 => 'LMP2',
  CarClassKind.lmp3 => 'LMP3',
  CarClassKind.lmgte => 'GTE',
  CarClassKind.lmgt3 => 'GT3',
  _ => '',
};

void main() {
  group('the game\'s logs', () {
    test('every logged entry places as the setup it loaded', () {
      final wrong = <String>[];
      for (final (name, prefix) in loggedEntries) {
        final expected =
            _shopSetups[prefix] ?? CarModel.ofSetup('${prefix}_x.svm');
        expect(expected, isNotNull, reason: 'no model for setup $prefix');
        final placed = placeCar(name, _classCode(expected!));
        if (placed.model != expected) {
          wrong.add('$name ($prefix): ${placed.model?.label} by ${placed.rule}');
        }
      }
      expect(wrong, isEmpty);
      expect(loggedEntries, hasLength(306));
    });

    test('a setup names its model by the longest prefix', () {
      expect(
        CarModel.ofSetup('HY_9x8Evo_Balanced_LeMans.svm'),
        CarModel.peugeot9x8of2024,
      );
      expect(CarModel.ofSetup('HY_9x8_Balanced.svm'), CarModel.peugeot9x8);
      expect(CarModel.ofSetup('GT3_992GT3R_Low.svm'), CarModel.porsche911Gt3R);
      expect(CarModel.ofSetup('AI_LMP2_x.svm'), CarModel.oreca07);
      expect(CarModel.ofSetup('mine.svm'), isNull);
    });
  });

  group('the library', () {
    test('every recording\'s car is placed', () {
      final unplaced = [
        for (final (name, cls) in libraryEntries)
          if (!placeCar(name, cls).isPlaced) '$name ($cls)',
      ];
      expect(unplaced, isEmpty);
      expect(libraryEntries, hasLength(54));
    });

    test('the cars the logs never loaded, as their teams ran them', () {
      CarModel? model(String name, String cls) => placeCar(name, cls).model;
      expect(
        model('Racing Team Turkey by TF 2026 #34:WEC', 'GT3'),
        CarModel.corvetteZ06Gt3R,
      );
      expect(
        model('Iron Lynx 2025 #63:ELMS', 'GT3'),
        CarModel.mercedesAmgGt3Evo,
      );
      expect(
        model('Iron Lynx 2026 #79:WEC', 'GT3'),
        CarModel.mercedesAmgGt3Evo,
      );
      expect(
        model('Iron Dames 2024 #85:LM', 'GT3'),
        CarModel.lamborghiniHuracanGt3,
      );
      expect(model('Iron Dames 2025 #85:WEC', 'GT3'), CarModel.porsche911Gt3R);
      expect(
        model('ADESS Racing Team 2025 #46:ELMS', 'LMP3'),
        CarModel.adessAd25,
      );
      // One team, two classes.
      expect(model('DKR Engineering #4:ELMS25', 'LMP3'), CarModel.ligierJsP325);
      expect(model('DKR Engineering #3:ELMS25', 'LMP2_ELMS'), CarModel.oreca07);
      expect(
        model('Logitech G Challenge #9:LGC', 'GT3'),
        CarModel.mclaren720sGChallenge,
      );
    });
  });

  group('the install', () {
    test('every vehicle folder is a model, and every model has one', () {
      final models = {
        for (final folder in _installFolders) folder: CarModel.ofFolder(folder),
      };
      expect([
        for (final MapEntry(:key, :value) in models.entries)
          if (value == null) key,
      ], isEmpty);
      expect(models.values.toSet(), CarModel.values.toSet());
    });

    test('no folder or setup prefix is claimed twice', () {
      final folders = [for (final m in CarModel.values) ...m.folders];
      final setups = [for (final m in CarModel.values) ...m.setups];
      expect(folders.toSet(), hasLength(folders.length));
      expect(setups.toSet(), hasLength(setups.length));
    });

    test('every make has a model', () {
      expect({for (final m in CarModel.values) m.make}, CarMake.values.toSet());
    });
  });

  group('an entry', () {
    test('is taken apart into team, season, number and tag', () {
      final e = CarEntry.parse('Iron Dames 2025 #85:LM');
      expect(e.team, 'Iron Dames');
      expect(e.season, 2025);
      expect(e.number, '85');
      expect(e.tag, 'LM');
      expect(e.elms, isFalse);

      final repeated = CarEntry.parse('JMW Motorsport 2024 2024 #66:LM');
      expect(repeated.team, 'JMW Motorsport');
      expect(repeated.season, 2024);

      expect(
        CarEntry.parse('Aston Martin THOR Team 2026 #007:LM').number,
        '007',
      );
      expect(
        CarEntry.parse('Racing Spirit of Léman  2026 #59:LM').team,
        'Racing Spirit of Léman',
      );

      final pace = CarEntry.parse('Porsche 992S Pace Car');
      expect(pace.team, 'Porsche 992S Pace Car');
      expect(pace.number, isNull);
      expect(pace.tag, isNull);
    });

    test('an ELMS pack tag carries its season', () {
      final e = CarEntry.parse('AO by TF #99:ELMS25');
      expect(e.season, isNull);
      expect(e.year, 2025);
      expect(e.elms, isTrue);
      expect(CarEntry.parse('High Class Racing 2026 #54:ELMS2').elms, isTrue);
      expect(CarEntry.parse('Team WRT 2024 #46:WE2').year, 2024);
    });

    test('labels drop the tag, and a placed custom livery\'s code', () {
      final dames = placeCar('Iron Dames 2025 #85:LM', 'GT3');
      expect(dames.title, 'Porsche 911 GT3 R');
      expect(dames.entryLabel, 'Iron Dames 2025 #85');
      expect(dames.entryShortLabel, 'Iron Dames #85');
      expect(
        dames.spokenLabel,
        'Porsche 911 GT3 R, Iron Dames 2025, number 85',
      );

      final custom = placeCar('VLMDH Custom Team 2025 #397', 'Hyper');
      expect(custom.title, 'Cadillac V-Series.R');
      expect(custom.entryLabel, 'Custom Team 2025 #397');

      // Unplaced, the code is the only clue to the car, so it stays.
      final unknown = placeCar('XR9 Custom Team 2026 #397', 'Hyper');
      expect(unknown.isPlaced, isFalse);
      expect(unknown.title, 'XR9 Custom Team 2026 #397');
    });

    test('a model named after its make is not prefixed twice', () {
      expect(CarModel.corvetteC8r.label, 'Chevrolet Corvette C8.R');
      expect(CarModel.corvetteZ06Gt3R.label, 'Corvette Z06 GT3.R');
      expect(CarModel.mercedesAmgGt3Evo.label, 'Mercedes-AMG GT3 Evo');
    });
  });

  group('never a guess', () {
    test('a team in three classes needs the class', () {
      expect(
        placeCar('AF Corse 2026 #83:LM', 'Hyper').model,
        CarModel.ferrari499p,
      );
      expect(
        placeCar('AF Corse 2025 #51:ELMS', 'GT3').model,
        CarModel.ferrari296Gt3,
      );
      expect(placeCar('AF Corse #80:LM', 'LMP2').model, CarModel.oreca07);
      final unclassed = placeCar('AF Corse 2026 #83:LM', 'Mystery');
      expect(unclassed.model, isNull);
      expect(unclassed.rule, CarPlacementRule.ambiguous);
    });

    test('a make with two cars in the class stays unplaced', () {
      // Peugeot raced two 9X8s; only the team rule's seasons tell them apart.
      final p = placeCar('Peugeot Sport 2025 #93:LM', 'Hyper');
      expect(p.model, isNull);
      expect(p.rule, CarPlacementRule.ambiguous);
      expect(
        placeCar('Peugeot TotalEnergies #93:LM', 'Hyper').model,
        CarModel.peugeot9x8,
      );
      expect(
        placeCar('Peugeot TotalEnergies 2025 #93:LM', 'Hyper').model,
        CarModel.peugeot9x8of2024,
      );
    });

    test('an entry nothing names is unknown, and says so', () {
      final p = placeCar('Some New Team 2026 #1:LM', 'GT3');
      expect(p.model, isNull);
      expect(p.rule, CarPlacementRule.unknown);
      expect(p.title, 'Some New Team 2026 #1');
      expect(p.reason, contains('not in Pace Reader\'s catalog'));
    });

    test('a make whose car is in another class does not place it', () {
      // Duqueine builds an LMP3; its LMP2 team runs the Oreca.
      expect(
        placeCar('Duqueine Team 2026 #30:LM', 'LMP2').model,
        CarModel.oreca07,
      );
      expect(placeCar('Duqueine Team 2026 #30:LM', 'GT3').isPlaced, isFalse);
    });
  });

  group('reasons', () {
    String reason(String name, String cls) => placeCar(name, cls).reason;

    test('each rule explains itself', () {
      expect(
        reason('VLMDH Custom Team 2025 #397', 'Hyper'),
        'A custom livery on the Cadillac V-Series.R: "VLMDH" is the game\'s '
        'code for it.',
      );
      expect(
        reason('Iron Dames 2025 #85:LM', 'GT3'),
        'Iron Dames ran the Porsche 911 GT3 R in LMGT3 in 2025.',
      );
      expect(
        reason('BMW M Team WRT 2026 #20:WEC', 'Hyper'),
        'The entry names BMW, whose only Hypercar in the game is the '
        'M Hybrid V8.',
      );
      expect(
        reason('IDEC Sport #18:ELMS25', 'LMP2_ELMS'),
        'Every LMP2 in the game is an Oreca 07.',
      );
    });
  });

  group('the same car', () {
    test('is the model and class, not the entry', () {
      final a = placeCar('Ferrari AF Corse 2026 #50:LM', 'Hyper');
      final b = placeCar('AF Corse 2026 #83:WEC', 'Hyper');
      expect(a.sameCarAs(b), isTrue);

      // The ELMS LMP2 runs without the WEC's restrictor.
      final wec = placeCar('United Autosports 2025 #22:LM', 'LMP2');
      final elms = placeCar('IDEC Sport #18:ELMS25', 'LMP2_ELMS');
      expect(wec.sameCarAs(elms), isFalse);

      final dames24 = placeCar('Iron Dames 2024 #85:LM', 'GT3');
      final dames25 = placeCar('Iron Dames 2025 #85:LM', 'GT3');
      expect(dames24.sameCarAs(dames25), isFalse);
    });

    test('unplaced, it is the entry', () {
      final a = placeCar('Some New Team 2026 #1:LM', 'GT3');
      expect(a.sameCarAs(placeCar('Some New Team 2026 #1:LM', 'GT3')), isTrue);
      expect(a.sameCarAs(placeCar('Iron Dames 2025 #85:LM', 'GT3')), isFalse);
    });
  });
}
