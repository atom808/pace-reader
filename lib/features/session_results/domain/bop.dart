/// LMU's balance of performance: what Studio 397's per-patch BoP document
/// sets for each car at each track, and which document a session ran under.
///
/// The figures come from the official PDF (`LMU_BOP_<version>_Marked-up`),
/// read into [bopDocuments] by hand (PACE-FACTORS §5.6). A document applies
/// from its date to the next one's, and only to sessions on the game version
/// it shipped with: `GameVersion` 1.4200 spans two BoP documents, so the date
/// decides, and a new game version may have brought a new BoP the app does
/// not hold.
library;

import 'results_session.dart';

/// The classes whose BoP sets a stint energy.
enum BopClass {
  hypercar,
  gt3;

  /// From a results file's `CarClass` (`Hyper`, `GT3`). Null for the others
  /// (LMP2, LMP3, GTE), whose BoP sets fuel and power but no energy.
  static BopClass? of(String carClass) => switch (carClass) {
    'Hyper' => hypercar,
    'GT3' => gt3,
    _ => null,
  };
}

/// A figure, and how it changed from the previous document where the PDF
/// marks it ("1132 (+5)").
class BopValue {
  const BopValue(this.value, [this.change]);

  final double value;
  final double? change;
}

/// One car's BoP at one track group.
class BopEntry {
  const BopEntry({
    required this.group,
    required this.carClass,
    required this.model,
    required this.minWeightKg,
    required this.powerStage1,
    required this.stage1EndKph,
    required this.stage2StartKph,
    required this.powerStage2,
    required this.stintEnergyMJ,
    this.deployFromKph,
    this.dockingSeconds,
    this.rearWingMin,
    this.rearWingMax,
    this.minRideHeightMm,
  });

  /// The PDF's track group: `Le Mans`, `Bahrain`, `Paul Ricard 1A`.
  final String group;
  final BopClass carClass;

  /// The PDF's model name: `Alpine A424`, `9x8 Evo`, `BMW M4 LMGT3`.
  final String model;

  /// Including the driver (82 kg).
  final BopValue minWeightKg;

  /// kW for a Hypercar, percent of the engine's maximum for a GT3.
  final BopValue powerStage1;
  final double stage1EndKph;
  final double stage2StartKph;
  final BopValue powerStage2;
  final BopValue stintEnergyMJ;

  /// Hypercar: the speed above which the hybrid may deploy. Null for the
  /// cars without one (`-`).
  final double? deployFromKph;

  /// Hypercar: how long the hose stays on before the energy refill starts.
  final double? dockingSeconds;

  /// GT3 aero, in degrees and millimetres.
  final BopValue? rearWingMin;
  final BopValue? rearWingMax;
  final BopValue? minRideHeightMm;

  bool get isPercentPower => carClass == BopClass.gt3;
}

/// One BoP document.
class BopDocument {
  const BopDocument({
    required this.version,
    required this.year,
    required this.month,
    required this.day,
    required this.gameVersions,
    required this.layouts,
    required this.table,
  });

  /// `1.4.3`.
  final String version;
  final int year;
  final int month;
  final int day;

  /// The results files' `GameVersion` values it was in force under.
  final Set<String> gameVersions;

  /// Each track group's layouts as the PDF names them, where it does.
  final Map<String, String> layouts;

  /// One row per car per track group, in the PDF's own notation:
  /// `group|H|model|weight|power 1|stage 1 end|stage 2 start|power 2|deploy|
  /// energy|docking` for a Hypercar, `group|G|model|weight|power 1|…|power 2|
  /// energy|wing min|wing max|ride height` for a GT3. `1132(+5)` is a figure
  /// and its change from the previous document; `-` is none.
  final String table;

  /// The document's date, read as the start of that day in UTC.
  DateTime get publishedOn => DateTime.utc(year, month, day);

  /// [table], parsed once.
  List<BopEntry> get entries => _parsed[this] ??= parseBopTable(table);

  BopEntry? entry(String group, BopClass carClass, String model) {
    for (final e in entries) {
      if (e.group == group && e.carClass == carClass && e.model == model) {
        return e;
      }
    }
    return null;
  }

  static final _parsed = Expando<List<BopEntry>>();
}

final _cell = RegExp(r'^(-?\d+(?:\.\d+)?)(?:\(([+-]\d+(?:\.\d+)?)\))?$');

BopValue? _value(String cell) {
  final m = _cell.firstMatch(cell.trim());
  if (m == null) return null;
  final change = m.group(2);
  return BopValue(
    double.parse(m.group(1)!),
    change == null ? null : double.parse(change.replaceFirst('+', '')),
  );
}

/// [BopDocument.table]'s rows. A row that does not read is left out.
List<BopEntry> parseBopTable(String table) => [
  for (final line in table.split('\n')) ?_row(line.trim()),
];

BopEntry? _row(String line) {
  final c = line.split('|');
  if (c.length < 11) return null;
  final hyper = c[1] == 'H';
  if (!hyper && c[1] != 'G') return null;
  if (c.length != (hyper ? 11 : 12)) return null;
  final weight = _value(c[3]);
  final power1 = _value(c[4]);
  final end1 = _value(c[5]);
  final start2 = _value(c[6]);
  final power2 = _value(c[7]);
  final energy = _value(hyper ? c[9] : c[8]);
  if (weight == null ||
      power1 == null ||
      end1 == null ||
      start2 == null ||
      power2 == null ||
      energy == null) {
    return null;
  }
  return BopEntry(
    group: c[0],
    carClass: hyper ? BopClass.hypercar : BopClass.gt3,
    model: c[2],
    minWeightKg: weight,
    powerStage1: power1,
    stage1EndKph: end1.value,
    stage2StartKph: start2.value,
    powerStage2: power2,
    stintEnergyMJ: energy,
    deployFromKph: hyper ? _value(c[8])?.value : null,
    dockingSeconds: hyper ? _value(c[10])?.value : null,
    rearWingMin: hyper ? null : _value(c[9]),
    rearWingMax: hyper ? null : _value(c[10]),
    minRideHeightMm: hyper ? null : _value(c[11]),
  );
}

/// The document a session ran under, from [documents] (oldest first): the
/// latest dated on or before it, when the session's game version is one that
/// document shipped with. Null otherwise.
BopDocument? bopDocumentFor(
  ResultsSession session, {
  List<BopDocument> documents = const [],
}) {
  BopDocument? found;
  for (final d in documents) {
    if (!d.publishedOn.isAfter(session.startedAt)) found = d;
  }
  if (found == null || !found.gameVersions.contains(session.gameVersion)) {
    return null;
  }
  return found;
}

/// When [document] stops applying: the next document's date, or never.
DateTime? bopDocumentEnds(
  BopDocument document, {
  List<BopDocument> documents = const [],
}) {
  for (final d in documents) {
    if (d.publishedOn.isAfter(document.publishedOn)) return d.publishedOn;
  }
  return null;
}

/// The PDF's track group for a results file's venue and course. Null for a
/// venue the documents do not cover.
String? bopTrackGroup(String venue, String course) {
  final v = venue.toLowerCase();
  final c = course.toLowerCase();
  if (v.contains('bahrain')) return 'Bahrain';
  if (v.contains('barcelona')) return 'Barcelona';
  if (v.contains('americas')) return 'COTA';
  if (v.contains('daytona')) return 'Daytona';
  if (v.contains('fuji')) return 'Fuji';
  if (v.contains('enzo e dino') || v.contains('imola')) return 'Imola';
  if (v.contains('carlos pace') || v.contains('interlagos')) {
    return 'Interlagos';
  }
  if (v.contains('laguna seca')) return 'Laguna Seca';
  if (v.contains('sarthe') || v.contains('le mans')) {
    return c.contains('mulsanne') ? 'Le Mans Mulsanne' : 'Le Mans';
  }
  if (v.contains('long beach')) return 'Long Beach';
  if (v.contains('monza')) {
    return c.contains('grande') ? 'Monza Grande' : 'Monza';
  }
  if (v.contains('ricard')) {
    return RegExp(r'\b1a').hasMatch(c) ? 'Paul Ricard 1A' : 'Paul Ricard';
  }
  if (v.contains('algarve') || v.contains('portim')) return 'Portimao';
  if (v.contains('lusail') || v.contains('qatar')) return 'Qatar';
  if (v.contains('road atlanta')) return 'Road Atlanta';
  if (v.contains('sebring')) return 'Sebring';
  if (v.contains('silverstone')) return 'Silverstone';
  if (v.contains('spa-francorchamps') || v.contains('spa ')) return 'Spa';
  return null;
}

/// The PDF's model name for a results file's car, or null for one it does
/// not list.
///
/// The PDF has two Peugeots. The results files call both "Peugeot 9x8", and
/// the category's season tells them apart: "WEC 2023, …" is the original
/// car, and 2024 on (vehicle files `…9X8W…`, with the rear wing) the Evo.
String? bopModel(ResultsDriver car) => bopModelOf(
  carClass: car.carClass,
  carType: car.carType,
  category: car.category,
  vehicleFile: car.vehicleFile,
);

/// [bopModel] from the fields it reads.
String? bopModelOf({
  required String carClass,
  required String carType,
  required String category,
  required String vehicleFile,
}) {
  final t = carType.toLowerCase();
  switch (BopClass.of(carClass)) {
    case BopClass.hypercar:
      if (t.contains('alpine')) return 'Alpine A424';
      if (t.contains('valkyrie')) return 'Aston Martin Valkyrie';
      if (t.contains('bmw')) return 'BMW M Hybrid V8';
      if (t.contains('cadillac')) return 'Cadillac V-Series.R';
      if (t.contains('499p')) return 'Ferrari 499P';
      if (t.contains('genesis')) return 'Genesis GMR-001';
      if (t.contains('glickenhaus') || t.contains('scg')) {
        return 'Glickenhaus SCG 007';
      }
      if (t.contains('isotta')) return 'Isotta Tipo 6';
      if (t.contains('sc63')) return 'Lamborghini SC63';
      if (t.contains('peugeot') || t.contains('9x8')) {
        final season = int.tryParse(
          RegExp(r'\b(20\d\d)\b').firstMatch(category)?.group(1) ?? '',
        );
        if (vehicleFile.toUpperCase().contains('9X8W') ||
            (season != null && season >= 2024)) {
          return '9x8 Evo';
        }
        return season == null ? null : '9x8';
      }
      if (t.contains('963')) return 'Porsche 963';
      if (t.contains('toyota')) return 'Toyota GR010';
      if (t.contains('vanwall')) return 'Vanwall Vandervell 680';
    case BopClass.gt3:
      if (t.contains('vantage')) return 'Aston Martin Vantage AMR LMGT3';
      if (t.contains('m4')) return 'BMW M4 LMGT3';
      if (t.contains('corvette')) return 'Corvette Z06 LMGT3.R';
      if (t.contains('296')) return 'Ferrari 296 LMGT3';
      if (t.contains('mustang')) return 'Ford Mustang LMGT3';
      if (t.contains('huracan')) return 'Lamborghini Huracan LMGT3 Evo2';
      if (t.contains('lexus') || t.contains('rcf')) return 'Lexus RC F LMGT3';
      if (t.contains('720s')) return 'McLaren 720S LMGT3 Evo';
      if (t.contains('amg') || t.contains('mercedes')) {
        return 'Mercedes AMG LMGT3';
      }
      if (t.contains('911')) return 'Porsche 911 GT3 R';
    case null:
      return null;
  }
  return null;
}
