/// Which car a recording's `CarName` is (SPEC.md §5.1, §15.6).
///
/// The file never names its car's make or model. `CarName` is the *entry*:
/// team, season, number and a pack tag, as in `Iron Dames 2025 #85:LM`, and
/// the setup JSON has no model either. So the model comes from this table,
/// and [placeCar] reads an entry into it.
///
/// The rules are checked two ways (`test/data/car_catalog_test.dart`):
/// - against the game's own logs, which name the setup each entry loads
///   (`Found setup: GT3_992GT3R_…svm` for `Iron Dames 2025 #85:LM`): 306
///   entries, AI cars included, as of 2026-10-14;
/// - against the install's `Installed\Vehicles` folders, so a model the game
///   ships and the table lacks shows up.
///
/// A car the rules cannot place stays unplaced. The table never guesses: an
/// unknown entry shows its own name, as before there was a table.
library;

import 'car_class.dart';

/// The makes LMU races. [label] is also the name of the game's own logo for
/// the make (`Brand=<label>.svg` in the install's UI).
enum CarMake {
  adess('ADESS'),
  alpine('Alpine'),
  astonMartin('Aston Martin'),
  bmw('BMW'),
  cadillac('Cadillac'),
  chevrolet('Chevrolet', aliases: ['Corvette']),
  corvette('Corvette'),
  duqueine('Duqueine'),
  ferrari('Ferrari'),
  ford('Ford', aliases: ['Mustang']),
  genesis('Genesis'),
  ginetta('Ginetta'),
  glickenhaus('Glickenhaus', aliases: ['SCG']),
  isottaFraschini('Isotta Fraschini', aliases: ['Isotta']),
  lamborghini('Lamborghini'),
  lexus('Lexus'),
  ligier('Ligier'),
  mclaren('McLaren'),
  mercedesAmg('Mercedes-AMG', aliases: ['Mercedes', 'AMG']),
  oreca('Oreca'),
  peugeot('Peugeot'),
  porsche('Porsche'),
  toyota('Toyota'),
  vanwall('Vanwall');

  const CarMake(this.label, {this.aliases = const []});

  final String label;

  /// Other words an entry uses for the make: Isotta TIPO6, Mercedes AMG.
  final List<String> aliases;
}

/// One model, as the game ships it.
enum CarModel {
  // Hypercar.
  toyotaGr010(
    CarMake.toyota,
    'GR010 Hybrid',
    CarClassKind.hypercar,
    setups: ['HY_GR010'],
    folders: ['Toyota_GR10_2023'],
  ),
  ferrari499p(
    CarMake.ferrari,
    '499P',
    CarClassKind.hypercar,
    setups: ['HY_499P'],
    folders: ['Ferrari_499P_2023'],
  ),
  porsche963(
    CarMake.porsche,
    '963',
    CarClassKind.hypercar,
    setups: ['HY_963'],
    folders: ['Porsche_963_2023'],
  ),
  cadillacVSeriesR(
    CarMake.cadillac,
    'V-Series.R',
    CarClassKind.hypercar,
    setups: ['HY_Cadillac'],
    folders: ['Cadillac_V-lmdh_2023'],
  ),
  peugeot9x8(
    CarMake.peugeot,
    '9X8',
    CarClassKind.hypercar,
    setups: ['HY_9x8'],
    folders: ['Peugeot_9x8_2023'],
  ),
  peugeot9x8of2024(
    CarMake.peugeot,
    '9X8 2024',
    CarClassKind.hypercar,
    setups: ['HY_9x8Evo'],
    folders: ['Peugeot_9x8_2024'],
  ),
  glickenhaus007(
    CarMake.glickenhaus,
    'SCG 007 LMH',
    CarClassKind.hypercar,
    setups: ['HY_Glicken'],
    folders: ['SGC_007_2023'],
  ),
  vanwall680(
    CarMake.vanwall,
    'Vandervell 680',
    CarClassKind.hypercar,
    folders: ['Vandervell_680_2023'],
  ),
  alpineA424(
    CarMake.alpine,
    'A424',
    CarClassKind.hypercar,
    setups: ['HY_A424'],
    folders: ['Alpine_A424_2024'],
  ),
  bmwMHybridV8(
    CarMake.bmw,
    'M Hybrid V8',
    CarClassKind.hypercar,
    setups: ['HY_BMW'],
    folders: ['BMW_M_Hybrid_V8_2023'],
  ),
  lamborghiniSc63(
    CarMake.lamborghini,
    'SC63',
    CarClassKind.hypercar,
    setups: ['HY_SC63'],
    folders: ['Lamborghini_SC63_2024'],
  ),
  isottaTipo6(
    CarMake.isottaFraschini,
    'Tipo6-C',
    CarClassKind.hypercar,
    setups: ['HY_IFTipo6'],
    folders: ['Isotta_Tipo6_2024'],
  ),
  astonMartinValkyrie(
    CarMake.astonMartin,
    'Valkyrie',
    CarClassKind.hypercar,
    setups: ['HY_Valkyrie'],
    folders: ['Aston_Martin_Valkyrie_2025'],
  ),
  genesisGmr001(
    CarMake.genesis,
    'GMR-001',
    CarClassKind.hypercar,
    setups: ['HY_GMR'],
    folders: ['Genesis_GMR001_2026'],
  ),

  // LMP2: one chassis, which the class's two specs (WEC and ELMS) share.
  oreca07(
    CarMake.oreca,
    '07',
    CarClassKind.lmp2,
    setups: ['LMP2_Oreca07WEC', 'LMP2_Oreca07ELMS', 'AI_LMP2'],
    folders: ['Oreca_07_LM_2023', 'Oreca_07_ELMS_2023'],
  ),

  // LMP3.
  ligierJsP325(
    CarMake.ligier,
    'JS P325',
    CarClassKind.lmp3,
    folders: ['Ligier_JSP325_2025'],
  ),
  duqueineD09(
    CarMake.duqueine,
    'D09',
    CarClassKind.lmp3,
    setups: ['LMP3_Duqueine'],
    folders: ['Duqueine_D09LMP3_2026'],
  ),
  ginettaG61(
    CarMake.ginetta,
    'G61-LT-P3 Evo',
    CarClassKind.lmp3,
    folders: ['Ginetta_G61Evo_2025'],
  ),
  adessAd25(
    CarMake.adess,
    'AD25',
    CarClassKind.lmp3,
    folders: ['ADESS_AD25_2026'],
  ),

  // LMGTE.
  ferrari488Gte(
    CarMake.ferrari,
    '488 GTE Evo',
    CarClassKind.lmgte,
    folders: ['Ferrari_488GTE_LM_2023'],
  ),
  porsche911Rsr(
    CarMake.porsche,
    '911 RSR-19',
    CarClassKind.lmgte,
    folders: ['Porsche_911RSR-19_2023'],
  ),
  astonMartinVantageGte(
    CarMake.astonMartin,
    'Vantage AMR',
    CarClassKind.lmgte,
    folders: ['Aston_Martin_Vantage_AMR_2023'],
  ),
  corvetteC8r(
    CarMake.chevrolet,
    'Corvette C8.R',
    CarClassKind.lmgte,
    folders: ['Chevrolet_C8R_LM_2023'],
  ),

  // LMGT3.
  porsche911Gt3R(
    CarMake.porsche,
    '911 GT3 R',
    CarClassKind.lmgt3,
    setups: ['GT3_992GT3R'],
    folders: ['911GT3R_2024'],
  ),
  ferrari296Gt3(
    CarMake.ferrari,
    '296 GT3',
    CarClassKind.lmgt3,
    setups: ['GT3_296'],
    folders: ['Ferrari_296GT3_2023'],
  ),
  bmwM4Gt3(
    CarMake.bmw,
    'M4 GT3',
    CarClassKind.lmgt3,
    setups: ['GT3_M4'],
    folders: ['BMW_M4_LMGT3_2023'],
  ),
  corvetteZ06Gt3R(
    CarMake.corvette,
    'Z06 GT3.R',
    CarClassKind.lmgt3,
    setups: ['GT3_Z06GT3R'],
    folders: ['Corvette_Z06GT3R_2023'],
  ),
  mclaren720sGt3Evo(
    CarMake.mclaren,
    '720S GT3 Evo',
    CarClassKind.lmgt3,
    setups: ['GT3_720SEvo'],
    folders: ['McLaren_720sGT3Evo_2023'],
  ),

  /// The Logitech G Challenge's car. Its own folder, so kept apart from the
  /// WEC car: nothing says the two drive alike.
  mclaren720sGChallenge(
    CarMake.mclaren,
    '720S GT3 Evo',
    CarClassKind.lmgt3,
    edition: 'Logitech G Challenge',
    folders: ['McLaren_720sGChallenge_2026'],
  ),
  lexusRcfGt3(
    CarMake.lexus,
    'RC F GT3',
    CarClassKind.lmgt3,
    setups: ['GT3_RCF'],
    folders: ['LexusRCF_GT3_2024'],
  ),
  fordMustangGt3(
    CarMake.ford,
    'Mustang GT3',
    CarClassKind.lmgt3,
    setups: ['GT3_FM'],
    folders: ['Ford_Mustang_GT3_2024'],
  ),
  astonMartinVantageGt3(
    CarMake.astonMartin,
    'Vantage AMR GT3 Evo',
    CarClassKind.lmgt3,
    setups: ['GT3_Vantage'],
    folders: ['Vantage_AMR_GT3Evo_2024'],
  ),
  mercedesAmgGt3Evo(
    CarMake.mercedesAmg,
    'GT3 Evo',
    CarClassKind.lmgt3,
    setups: ['GT3_MAMGEvo'],
    folders: ['Mercedes_AMGGT3Evo_2025'],
  ),
  lamborghiniHuracanGt3(
    CarMake.lamborghini,
    'Huracán GT3 Evo2',
    CarClassKind.lmgt3,
    setups: ['GT3_Huracan'],
    folders: ['Lamborghini_Huracan_GT3_2024'],
  ),

  /// Leads the field; not raced.
  porschePaceCar(
    CarMake.porsche,
    '911 pace car',
    null,
    setups: ['992S_PC'],
    folders: ['992S_PC_2023'],
  );

  const CarModel(
    this.make,
    this.model,
    this.kind, {
    this.edition,
    this.setups = const [],
    this.folders = const [],
  });

  final CarMake make;

  /// The model without the make: "911 GT3 R".
  final String model;

  /// The class it races in; null for the pace car.
  final CarClassKind? kind;

  /// A second car under the same name, told apart: the G Challenge's 720S.
  final String? edition;

  /// The prefixes of the game's own setups for it (`GT3_992GT3R_…svm`),
  /// which the game's logs name for every entry it loads.
  final List<String> setups;

  /// Its folders under the install's `Installed\Vehicles`.
  final List<String> folders;

  /// "Porsche 911 GT3 R". A model named after its make (the Corvette C8.R
  /// under Chevrolet) is not prefixed twice.
  String get label =>
      model.startsWith(make.label) ? model : '${make.label} $model';

  /// The model whose install folder is [folder], ignoring case.
  static CarModel? ofFolder(String folder) {
    final key = folder.toLowerCase();
    for (final model in values) {
      if (model.folders.any((f) => f.toLowerCase() == key)) return model;
    }
    return null;
  }

  /// The model a game setup's file name is for: `GT3_992GT3R_Balanced.svm`.
  static CarModel? ofSetup(String setupFile) {
    CarModel? best;
    var length = 0;
    for (final model in values) {
      for (final prefix in model.setups) {
        // Longest prefix wins: HY_9x8Evo is not HY_9x8.
        if (prefix.length > length &&
            setupFile.toLowerCase().startsWith('${prefix.toLowerCase()}_')) {
          best = model;
          length = prefix.length;
        }
      }
    }
    return best;
  }
}

/// A `CarName` taken apart: `Iron Dames 2025 #85:LM` is team "Iron Dames",
/// season 2025, number 85, pack tag "LM".
class CarEntry {
  const CarEntry._({
    required this.raw,
    required this.team,
    this.season,
    this.number,
    this.tag,
  });

  factory CarEntry.parse(String carName) {
    var rest = carName.trim();
    String? tag;
    final colon = rest.lastIndexOf(':');
    if (colon > 0) {
      tag = rest.substring(colon + 1).trim();
      rest = rest.substring(0, colon);
    }
    String? number;
    rest = rest.replaceFirstMapped(RegExp(r'#\s*(\w+)'), (m) {
      number = m[1];
      return '';
    });
    int? season;
    final words = <String>[];
    for (final word in rest.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      if (RegExp(r'^20\d\d$').hasMatch(word)) {
        season = int.parse(word);
      } else {
        words.add(word);
      }
    }
    return CarEntry._(
      raw: carName,
      team: words.join(' '),
      season: season,
      number: number,
      tag: tag == null || tag.isEmpty ? null : tag,
    );
  }

  /// Exactly as the file wrote it.
  final String raw;

  /// "Iron Dames"; "VLMDH Custom Team" for a custom livery.
  final String team;

  /// The season pack, from the name or else the tag (`ELMS25` is 2025);
  /// null for the game's launch entries, which carry neither.
  final int? season;

  /// The race number as written: "85", "007".
  final String? number;

  /// The pack tag after the colon: "LM", "WEC", "ELMS25". Not a series:
  /// `LM` is the Le Mans pack, and others (`BL`, `BRZ`, `LGC`) are events.
  final String? tag;

  /// [season], or the one an `ELMS25`-style tag carries.
  int? get year {
    if (season != null) return season;
    final digits = RegExp(r'(\d\d)$').firstMatch(tag ?? '')?[1];
    return digits == null ? null : 2000 + int.parse(digits);
  }

  /// The European Le Mans Series pack (`ELMS`, `ELMS25`, `ELMS2`).
  bool get elms => tag?.toUpperCase().startsWith('ELMS') ?? false;

  /// A livery on a car of the player's own: "VLMDH Custom Team".
  bool get isCustom => _customCode != null;

  /// What precedes "Custom Team": the game's code for the car.
  String? get _customCode => RegExp(
    r'^(.+?)\s+Custom Team\b',
    caseSensitive: false,
  ).firstMatch(team)?[1];

  @override
  String toString() => 'CarEntry($raw)';
}

/// How [placeCar] found the model, which its tooltip explains.
enum CarPlacementRule {
  /// A custom livery's code names the car (`VLMDH Custom Team`).
  customCode,

  /// The catalog knows the team's car for that class and season.
  entry,

  /// The entry names the make, which has one car in the class.
  make,

  /// The class has one car (every LMP2 is an Oreca 07).
  singleMake,

  /// Nothing placed it.
  unknown,

  /// More than one car fits, and nothing says which.
  ambiguous,
}

/// A recording's car: its entry and, where the catalog places it, its model.
class CarPlacement {
  const CarPlacement._(this.entry, this.carClass, this.model, this.rule);

  final CarEntry entry;
  final CarClass carClass;
  final CarModel? model;
  final CarPlacementRule rule;

  bool get isPlaced => model != null;

  /// "Porsche 911 GT3 R", or the entry's own name where nothing placed it.
  String get title => model?.label ?? entryLabel;

  /// The team as a reader needs it: a placed custom livery's code says the
  /// car again, so "VLMDH Custom Team" reads "Custom Team" beside the
  /// Cadillac's name. Unplaced, the code is all there is, and stays.
  String get _team => isPlaced && entry.isCustom ? 'Custom Team' : entry.team;

  /// "Iron Dames 2025 #85": the entry without its pack tag.
  String get entryLabel => [
    _team,
    if (entry.season != null) '${entry.season}',
    if (entry.number != null) '#${entry.number}',
  ].join(' ');

  /// "Iron Dames #85": the team and number, which is how a row tells
  /// entries apart.
  String get entryShortLabel =>
      [_team, if (entry.number != null) '#${entry.number}'].join(' ');

  /// "Porsche 911 GT3 R, Iron Dames 2025, number 85", for a screen reader.
  String get spokenLabel => [
    if (model != null) model!.label,
    [_team, if (entry.season != null) '${entry.season}'].join(' '),
    if (entry.number != null) 'number ${entry.number}',
  ].join(', ');

  /// Why the model is this one, or why there is none.
  String get reason {
    final model = this.model;
    final team = entry.team;
    return switch (rule) {
      CarPlacementRule.customCode =>
        'A custom livery on the ${model!.label}: "${entry._customCode}" is '
            'the game\'s code for it.',
      CarPlacementRule.entry =>
        '$team ${entry.year == null ? 'runs' : 'ran'} the ${model!.label} in '
            '${carClass.label}${entry.year == null ? '' : ' in ${entry.year}'}.',
      CarPlacementRule.make =>
        'The entry names ${model!.make.label}, whose only '
            '${carClass.kind == CarClassKind.unknown ? 'car' : carClass.label} '
            'in the game is the ${model.model}.',
      CarPlacementRule.singleMake =>
        'Every ${carClass.name} in the game is an ${model!.label}.',
      CarPlacementRule.ambiguous =>
        'More than one car fits "$team" in ${carClass.label}, and the file '
            'does not say which.',
      CarPlacementRule.unknown =>
        'Car not recognised: this entry is not in Pace Reader\'s catalog '
            'yet.',
    };
  }

  /// Whether this and [other] are the same car: the same model in the same
  /// class (an LMP2 ELMS Oreca drives unrestricted), or, where either is
  /// unplaced, the same entry.
  bool sameCarAs(CarPlacement other) => model != null && other.model != null
      ? model == other.model && carClass == other.carClass
      : entry.raw == other.entry.raw;

  /// What a filter keys the car by: the model, whatever the entry, or the
  /// entry where nothing placed it.
  String get key =>
      model == null ? 'entry:${entry.raw}' : 'model:${model!.name}';

  @override
  String toString() => 'CarPlacement(${entry.raw} → ${model?.label}, $rule)';
}

/// Reads a recording's `CarName` and `CarClass` into its model.
///
/// In order, the first rule that leaves exactly one model in the file's
/// class places the car:
/// 1. **A custom livery's code**: `VLMDH Custom Team` is the Cadillac.
/// 2. **The team, by class and season**: Iron Dames is a Huracán in 2024 and
///    a 911 GT3 R from 2025; Proton Competition a Mustang in GT3, but a
///    911 GT3 R in the 2026 ELMS, a 963 in Hypercar and an Oreca in LMP2.
/// 3. **A make in the name**: BMW M Team WRT in Hypercar is the M Hybrid V8.
/// 4. **A class with one car**: every LMP2 is an Oreca 07.
///
/// A rule that leaves two or more models stops the search: the car stays
/// unplaced rather than picked.
///
/// Remembered per name and class: list rows place their car on every build,
/// and a library holds a few dozen distinct entries.
CarPlacement placeCar(String carName, String carClass) =>
    _placed.putIfAbsent((carName, carClass), () => _place(carName, carClass));

final _placed = <(String, String), CarPlacement>{};

CarPlacement _place(String carName, String carClass) {
  final entry = CarEntry.parse(carName);
  final cls = CarClass.parse(carClass);
  CarPlacement placed(CarModel? model, CarPlacementRule rule) =>
      CarPlacement._(entry, cls, model, rule);

  // Every candidate must race in the file's class. A class this build does
  // not know filters nothing.
  List<CarModel> inClass(Iterable<CarModel> models) => [
    for (final model in models.toSet())
      if (cls.kind == CarClassKind.unknown || model.kind == cls.kind) model,
  ];

  final stages = <(CarPlacementRule, List<CarModel>)>[
    (CarPlacementRule.customCode, _custom(entry)),
    (CarPlacementRule.entry, _byTeam(entry)),
    (CarPlacementRule.make, _byMake(entry.team)),
    (
      CarPlacementRule.singleMake,
      cls.kind == CarClassKind.lmp2 ? const [CarModel.oreca07] : const [],
    ),
  ];
  for (final (rule, models) in stages) {
    final fits = inClass(models);
    if (fits.length == 1) return placed(fits.single, rule);
    if (fits.length > 1) return placed(null, CarPlacementRule.ambiguous);
  }
  return placed(null, CarPlacementRule.unknown);
}

/// The model a custom livery's code names; else the make the code names.
List<CarModel> _custom(CarEntry entry) {
  final code = entry._customCode;
  if (code == null) return const [];
  final model = _customCodes[_key(code)];
  return model != null ? [model] : _byMake(code);
}

/// The custom-livery codes that do not simply name a make. Those that do
/// (`Alpine Custom Team`, `Lexus Custom Team`) go through [_byMake].
final _customCodes = {
  for (final (code, model) in const [
    ('499P', CarModel.ferrari499p),
    ('BMWMH', CarModel.bmwMHybridV8),
    ('VLMDH', CarModel.cadillacVSeriesR),
    ('Z06GT3R', CarModel.corvetteZ06Gt3R),
    ('296GT3', CarModel.ferrari296Gt3),
    ('911GT3R', CarModel.porsche911Gt3R),
    ('9x8 Wing', CarModel.peugeot9x8of2024),
    ('Peugeot 9x8', CarModel.peugeot9x8),
    ('AM Valkyrie', CarModel.astonMartinValkyrie),
    ('AMR GT3', CarModel.astonMartinVantageGt3),
    ('Huracan', CarModel.lamborghiniHuracanGt3),
    // McLaren has two GT3s: the custom livery is on the WEC car.
    ('McLaren', CarModel.mclaren720sGt3Evo),
    ('Mustang', CarModel.fordMustangGt3),
    ('SC63', CarModel.lamborghiniSc63),
    ('Toyota GR010', CarModel.toyotaGr010),
    ('Toyota TR010', CarModel.toyotaGr010),
  ])
    _key(code): model,
};

/// One team's car: in a class, for a span of seasons, in or out of the
/// ELMS pack.
class _TeamCar {
  const _TeamCar(this.team, this.model, {this.until, this.from, this.elms});

  /// The team's name, matched at the start of the entry's, ignoring case.
  final String team;
  final CarModel model;

  /// Last and first season; an entry with no season is the launch roster,
  /// before 2024.
  final int? until;
  final int? from;

  /// Only in (true) or out of (false) the ELMS pack.
  final bool? elms;

  bool fits(CarEntry entry) {
    final year = entry.year ?? 2023;
    return (until == null || year <= until!) &&
        (from == null || year >= from!) &&
        (elms == null || entry.elms == elms);
  }
}

/// Teams whose car their name does not say. Each line is borne out by the
/// game's logs (the setup each entry loads), or by the user's own answer
/// for a car the logs never loaded.
const _teamCars = [
  // LMGT3.
  _TeamCar('13 Autosport', CarModel.corvetteZ06Gt3R),
  _TeamCar('AWA Racing', CarModel.corvetteZ06Gt3R),
  _TeamCar('TF Sport', CarModel.corvetteZ06Gt3R),
  _TeamCar('Racing Team Turkey', CarModel.corvetteZ06Gt3R),
  _TeamCar('Akkodis ASP Team', CarModel.lexusRcfGt3),
  _TeamCar("D'Station Racing", CarModel.astonMartinVantageGt3),
  _TeamCar('Heart of Racing Team', CarModel.astonMartinVantageGt3),
  _TeamCar('Racing Spirit of Léman', CarModel.astonMartinVantageGt3),
  _TeamCar('AF Corse', CarModel.ferrari296Gt3),
  _TeamCar('GR Racing', CarModel.ferrari296Gt3),
  _TeamCar('JMW Motorsport', CarModel.ferrari296Gt3),
  _TeamCar('Kessel Racing', CarModel.ferrari296Gt3),
  _TeamCar('Richard Mille AF Corse', CarModel.ferrari296Gt3),
  _TeamCar('Spirit of Race', CarModel.ferrari296Gt3),
  _TeamCar('Vista AF Corse', CarModel.ferrari296Gt3),
  // The game's own spelling of one Vista entry.
  _TeamCar('Vista AF Corsa', CarModel.ferrari296Gt3),
  _TeamCar('Ziggo Sport Tempesta', CarModel.ferrari296Gt3),
  _TeamCar('Garage 59', CarModel.mclaren720sGt3Evo),
  _TeamCar('Inception Racing', CarModel.mclaren720sGt3Evo),
  _TeamCar('United Autosports', CarModel.mclaren720sGt3Evo),
  _TeamCar('Logitech G Challenge', CarModel.mclaren720sGChallenge),
  _TeamCar('High Class Racing', CarModel.porsche911Gt3R),
  _TeamCar('Manthey', CarModel.porsche911Gt3R),
  _TeamCar('The Bend Manthey', CarModel.porsche911Gt3R),
  _TeamCar('Team WRT', CarModel.bmwM4Gt3),
  _TeamCar('The Bend Team WRT', CarModel.bmwM4Gt3),
  _TeamCar('Iron Dames', CarModel.lamborghiniHuracanGt3, until: 2024),
  _TeamCar('Iron Dames', CarModel.porsche911Gt3R, from: 2025),
  _TeamCar('Iron Lynx', CarModel.lamborghiniHuracanGt3, until: 2024),
  _TeamCar('Iron Lynx', CarModel.mercedesAmgGt3Evo, from: 2025),
  _TeamCar('Team Qatar by Iron Lynx', CarModel.mercedesAmgGt3Evo),
  _TeamCar('Proton Competition', CarModel.fordMustangGt3, elms: false),
  _TeamCar('Proton Competition', CarModel.porsche911Gt3R, elms: true),
  _TeamCar('Proton Racing', CarModel.fordMustangGt3),

  // Hypercar.
  _TeamCar('AF Corse', CarModel.ferrari499p),
  _TeamCar('Hertz Team Jota', CarModel.porsche963),
  _TeamCar('Proton Competition', CarModel.porsche963),
  _TeamCar('Peugeot TotalEnergies', CarModel.peugeot9x8, until: 2024),
  _TeamCar('Peugeot TotalEnergies', CarModel.peugeot9x8of2024, from: 2025),

  // LMP3.
  _TeamCar('DKR Engineering', CarModel.ligierJsP325),
  _TeamCar('WTM by Rinaldi Racing', CarModel.duqueineD09),

  _TeamCar('Porsche 992S Pace Car', CarModel.porschePaceCar),
];

List<CarModel> _byTeam(CarEntry entry) {
  final team = _key(entry.team);
  return [
    for (final car in _teamCars)
      if (_startsWithWords(team, _key(car.team)) && car.fits(entry)) car.model,
  ];
}

/// Every model of every make [text] names as a word: "BMW M Team WRT" gives
/// BMW's two, "Corvette Racing" the Corvette's and Chevrolet's.
List<CarModel> _byMake(String text) {
  final words = ' ${_key(text)} ';
  final makes = {
    for (final make in CarMake.values)
      for (final name in [make.label, ...make.aliases])
        if (words.contains(' ${_key(name)} ')) make,
  };
  return [
    for (final model in CarModel.values)
      if (makes.contains(model.make)) model,
  ];
}

bool _startsWithWords(String text, String prefix) =>
    text == prefix || text.startsWith('$prefix ');

/// Lowercase, with hyphens as spaces and runs of spaces collapsed.
String _key(String text) => text
    .toLowerCase()
    .replaceAll('-', ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .join(' ');
