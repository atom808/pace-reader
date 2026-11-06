// Balance of performance (PACE-FACTORS §5.6, §5.7): the 1.4.3 table, which
// document and track group a session falls under, which model a results car
// is, whether the event kept BoP's stint energy, and how the app words it.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_results/application/linked_results.dart';
import 'package:pace_reader/features/session_results/data/results_index_store.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/bop.dart';
import 'package:pace_reader/features/session_results/domain/bop_allowance.dart';
import 'package:pace_reader/features/session_results/domain/bop_documents.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';
import 'package:pace_reader/features/session_results/presentation/bop_text.dart';

import '../fixtures/results_xml_samples.dart';

final _template = parseResultsXml(sartheRaceXml);
final _doc = bopDocuments.single;

/// Six pace laps, each taking [share] of the energy allowance.
List<ResultsLap> _laps(double share) => [
  for (var n = 1; n <= 6; n++)
    ResultsLap(
      number: n,
      lapSeconds: 210,
      sector1Seconds: 70,
      sector2Seconds: 70,
      sector3Seconds: 70,
      energyUsedFraction: share,
    ),
];

ResultsDriver _car(
  int index,
  String carType,
  double share, {
  String carClass = 'Hyper',
  String category = 'WEC 2026, Hypercar',
}) => _template.drivers.first.copyWith(
  index: index,
  name: 'Invented Driver $index',
  isPlayer: index == 0,
  carType: carType,
  carClass: carClass,
  category: category,
  vehicleFile: 'X.VEH',
  swaps: const [],
  laps: _laps(share),
);

/// A Le Mans session on 1.4.3's game version, [day] days after 6 Oct 2026.
ResultsSession _session(
  List<ResultsDriver> cars, {
  int day = 13,
  String gameVersion = '1.4200',
  double fuelMultiplier = 1,
  String venue = 'Circuit de la Sarthe',
}) => _template.copyWith(
  startedAt: DateTime.utc(2026, 10, day, 20),
  gameVersion: gameVersion,
  fuelMultiplier: fuelMultiplier,
  trackVenue: venue,
  trackCourse: venue,
  drivers: cars,
);

ResultsFileRecord _record(String path) => ResultsFileRecord(
  path: path,
  file: const FileFacts(sizeBytes: 100, modifiedMs: 1000),
  indexedAt: DateTime.utc(2026, 11, 5),
);

void main() {
  group('the 1.4.3 table', () {
    test('has every car at every track group', () {
      expect(_doc.entries, hasLength(21 * (14 + 10)));
      expect(_doc.publishedOn, DateTime.utc(2026, 10, 6));
    });

    test('reads a Hypercar row as the PDF prints it', () {
      final alpine = _doc.entry('Le Mans', BopClass.hypercar, 'Alpine A424')!;
      expect(alpine.minWeightKg.value, 1127);
      expect(alpine.powerStage1.value, 502);
      expect(alpine.powerStage2.value, 509.3);
      expect(alpine.stintEnergyMJ.value, 903);
      expect(alpine.deployFromKph, 0);
      expect(alpine.dockingSeconds, 1.0);

      // "1132 (+5)": the figure and its change from 1.4.2.
      final peugeot = _doc.entry('Le Mans', BopClass.hypercar, '9x8')!;
      expect(peugeot.minWeightKg.value, 1132);
      expect(peugeot.minWeightKg.change, 5);
      expect(peugeot.powerStage1.change, -5);
      expect(peugeot.deployFromKph, 150);

      // "-": no hybrid.
      final valkyrie = _doc.entry(
        'Le Mans',
        BopClass.hypercar,
        'Aston Martin Valkyrie',
      )!;
      expect(valkyrie.deployFromKph, isNull);
    });

    test('reads a GT3 row, wing and ride height included', () {
      final ferrari = _doc.entry(
        'Road Atlanta',
        BopClass.gt3,
        'Ferrari 296 LMGT3',
      )!;
      expect(ferrari.powerStage1.value, 87);
      expect(ferrari.stage1EndKph, 190);
      expect(ferrari.stintEnergyMJ.value, 775);
      expect(ferrari.rearWingMax!.value, 3.85);
      expect(ferrari.rearWingMax!.change, -0.65);
      expect(ferrari.minRideHeightMm!.change, 1);
    });

    test('skips a row that does not read', () {
      expect(parseBopTable('Le Mans|H|Alpine A424|1127|502'), isEmpty);
      expect(parseBopTable('Le Mans|X|Alpine A424|1|2|3|4|5|6|7|8'), isEmpty);
    });
  });

  group('which document', () {
    test('is the latest dated on or before the session', () {
      final s = _session(const []);
      expect(bopDocumentFor(s, documents: bopDocuments), same(_doc));
      expect(bopDocumentEnds(_doc, documents: bopDocuments), isNull);
    });

    test('is none before the oldest, or on another game version', () {
      expect(
        bopDocumentFor(_session(const [], day: 5), documents: bopDocuments),
        isNull,
      );
      expect(
        bopDocumentFor(
          _session(const [], gameVersion: '1.4300'),
          documents: bopDocuments,
        ),
        isNull,
      );
    });
  });

  test('track groups follow the results file venue and course', () {
    expect(
      bopTrackGroup('Circuit de la Sarthe', 'Circuit de la Sarthe'),
      'Le Mans',
    );
    expect(
      bopTrackGroup('Bahrain International Circuit', 'Bahrain Outer Circuit'),
      'Bahrain',
    );
    expect(
      bopTrackGroup('Paul Ricard Circuit', 'Paul Ricard - 1A-V2'),
      'Paul Ricard 1A',
    );
    expect(
      bopTrackGroup('Paul Ricard Circuit', 'Paul Ricard - ELMS'),
      'Paul Ricard',
    );
    expect(bopTrackGroup('Autódromo José Carlos Pace', 'x'), 'Interlagos');
    expect(bopTrackGroup('Lusail International Circuit', 'x'), 'Qatar');
    expect(bopTrackGroup('Algarve International Circuit', 'x'), 'Portimao');
    expect(bopTrackGroup('Autodromo Enzo e Dino Ferrari', 'x'), 'Imola');
    expect(bopTrackGroup('Nowhere Raceway', 'x'), isNull);
    // Every group the function names is one the document lists.
    for (final venue in [
      'Circuit de Barcelona',
      'Circuit of the Americas',
      'Daytona International Speedway',
      'Fuji Speedway',
      'WeatherTech Raceway Laguna Seca',
      'Grand Prix of Long Beach',
      'Autodromo Nazionale Monza',
      'Michelin Raceway Road Atlanta',
      'Sebring International Raceway',
      'Silverstone Circuit',
      'Circuit de Spa-Francorchamps',
    ]) {
      final group = bopTrackGroup(venue, venue);
      expect(_doc.entries.any((e) => e.group == group), isTrue, reason: venue);
    }
  });

  group('which model', () {
    test('maps the results files\' names to the PDF\'s', () {
      expect(bopModel(_car(0, 'Toyota TR010', 0)), 'Toyota GR010');
      expect(bopModel(_car(0, 'Genesis GMR001', 0)), 'Genesis GMR-001');
      expect(bopModel(_car(0, 'Cadillac V-lmdh', 0)), 'Cadillac V-Series.R');
      expect(
        bopModel(_car(0, 'Ferrari 296 LMGT3 Evo', 0, carClass: 'GT3')),
        'Ferrari 296 LMGT3',
      );
      expect(bopModel(_car(0, 'Oreca 07', 0, carClass: 'LMP2_ELMS')), isNull);
    });

    test('tells the two Peugeots apart by season', () {
      expect(
        bopModel(_car(0, 'Peugeot 9x8', 0, category: 'WEC 2023, Hypercar')),
        '9x8',
      );
      expect(
        bopModel(_car(0, 'Peugeot 9x8', 0, category: 'WEC 2026, Hypercar')),
        '9x8 Evo',
      );
      expect(bopModel(_car(0, 'Peugeot 9x8', 0, category: '')), isNull);
    });
  });

  group('the allowance', () {
    final mine = _session([
      _car(0, 'Alpine A424', 0.082),
      _car(1, 'BMW M Hybrid V8', 0.078),
    ]);

    BopAllowance check(ResultsSession s, List<ResultsSession> others) =>
        checkBopAllowance(
          path: 'mine.xml',
          session: s,
          document: _doc,
          documentEnds: null,
          others: [
            for (final (i, o) in others.indexed)
              ...energySharesOf('o$i.xml', o),
          ],
        );

    test('matches other sessions under the same BoP', () {
      final a = check(mine, [
        _session([_car(0, 'Alpine A424', 0.082)], day: 20),
        _session([_car(0, 'BMW M Hybrid V8', 0.082)], day: 21),
      ]);
      expect(a.kind, BopAllowanceKind.matches);
      expect(a.sessions, 2);
      expect(a.models, 2);
    });

    test('differs when each lap takes a much larger share', () {
      // 70 % of BoP's allowance: each lap takes 1/0.7 of the usual share.
      final custom = _session([
        _car(0, 'Alpine A424', 0.082 / 0.7),
        _car(1, 'BMW M Hybrid V8', 0.078 / 0.7),
      ]);
      final a = check(custom, [mine]);
      expect(a.kind, BopAllowanceKind.differs);
      expect(a.ratio, closeTo(0.7, 0.01));
    });

    test('is unchecked with nothing comparable', () {
      expect(check(mine, const []).kind, BopAllowanceKind.unchecked);
      // Before the document, multiplied, or at another track: left out.
      expect(
        check(mine, [
          _session([_car(0, 'Alpine A424', 0.05)], day: 2),
          _session([_car(0, 'Alpine A424', 0.05)], fuelMultiplier: 2),
          _session([
            _car(0, 'Alpine A424', 0.05),
          ], venue: 'Bahrain International Circuit'),
        ]).kind,
        BopAllowanceKind.unchecked,
      );
    });

    test('is not read in a session that multiplied fuel use', () {
      final doubled = _session([
        _car(0, 'Alpine A424', 0.164),
      ], fuelMultiplier: 2);
      expect(check(doubled, [mine]).kind, BopAllowanceKind.multiplied);
    });

    test('needs five pace laps of a model in a file', () {
      final few = _session([
        _car(
          0,
          'Alpine A424',
          0.082,
        ).copyWith(laps: _laps(0.082).take(4).toList()),
      ]);
      expect(energySharesOf('few.xml', few), isEmpty);
    });
  });

  group('a session\'s BoP', () {
    test(
      'lists the class\'s cars and checks the allowance in the index',
      () async {
        final store = MemoryResultsIndexStore();
        final mine = _session([
          _car(0, 'Alpine A424', 0.082),
          _car(1, 'BMW M Hybrid V8', 0.078),
          _car(2, 'BMW M4 LMGT3', 0.09, carClass: 'GT3'),
        ]);
        await store.putSession(_record('mine.xml'), mine);
        await store.putSession(
          _record('other.xml'),
          _session([_car(0, 'Alpine A424', 0.082)], day: 20),
        );
        final bop = await sessionBopOf(
          store: store,
          path: 'mine.xml',
          session: mine,
          car: mine.drivers.first,
        );
        expect(bop.group, 'Le Mans');
        expect(bop.of(mine.drivers[0])!.model, 'Alpine A424');
        expect(bop.of(mine.drivers[1])!.stintEnergyMJ.value, 888);
        // Another class is not this car's comparison.
        expect(bop.of(mine.drivers[2]), isNull);
        expect(bop.inMegajoules, isTrue);
        expect(bopStatus(bop), contains('match 1 other session of yours'));
      },
    );

    test('says why there is none', () async {
      final store = MemoryResultsIndexStore();
      final early = _session([_car(0, 'Alpine A424', 0.082)], day: 1);
      final before = await sessionBopOf(
        store: store,
        path: 'a.xml',
        session: early,
        car: early.drivers.first,
      );
      expect(before.missing, contains('before 6 Oct 2026'));
      expect(bopStatus(before), endsWith('Energy stays a share.'));

      final lmp2 = _session([_car(0, 'Oreca 07', 0.1, carClass: 'LMP2')]);
      final noEnergy = await sessionBopOf(
        store: store,
        path: 'b.xml',
        session: lmp2,
        car: lmp2.drivers.first,
      );
      expect(noEnergy.missing, 'BoP sets no stint energy for LMP2.');
      expect(noEnergy.inMegajoules, isFalse);
    });
  });

  group('the wording', () {
    test('gives a car\'s BoP in a line, changes marked', () {
      final peugeot = _doc.entry('Le Mans', BopClass.hypercar, '9x8')!;
      expect(
        bopSummary(peugeot, _doc),
        'BoP 1.4.3, Le Mans: 9x8 · 1132 kg (+5) with driver · '
        '490 kW (−5) to 250 km/h, 488 kW (−5) from 250 · 894 MJ a stint · '
        'deploys from 150 km/h · 1.2 s docking',
      );
      final bmw = _doc.entry('Le Mans', BopClass.gt3, 'BMW M4 LMGT3')!;
      expect(bopSummary(bmw, _doc), contains('rear wing −2.3° to 4.6°'));
    });

    test('says how far a custom allowance sits from BoP\'s', () {
      final bop = SessionBop(
        document: _doc,
        group: 'Le Mans',
        allowance: const BopAllowance(
          kind: BopAllowanceKind.differs,
          ratio: 0.7,
          sessions: 3,
          models: 2,
        ),
      );
      expect(bopStatus(bop), contains('run 1.43× those of 3 other sessions'));
      expect(bopStatus(bop), contains('about 70 % of BoP’s'));
      expect(bop.inMegajoules, isFalse);
    });
  });
}
