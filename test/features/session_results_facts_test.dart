// The Overview's "Session results" card (results proposal, R4): which lines
// a results file gives, and when the card shows at all.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/session_results/application/linked_results.dart';
import 'package:pace_reader/features/session_results/application/session_results.dart';
import 'package:pace_reader/features/session_results/data/results_index_store.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/results_facts.dart';
import 'package:pace_reader/features/session_results/domain/results_link.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';
import 'package:pace_reader/features/session_results/presentation/results_facts_card.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/results_xml_samples.dart';

final _bahrain = parseResultsXml(bahrainPracticeXml);
final _sarthe = parseResultsXml(sartheRaceXml);

Map<String, String> _facts(ResultsSession s, int driver) => {
  for (final f in resultsFactsOf(s, s.drivers[driver])) f.label: f.value,
};

LinkedResults _linked(ResultsSession s) => LinkedResults(
  link: ResultsLink(
    path: r'C:\LMU\UserData\Log\Results\2026_10_23_00_48_40-12R1.xml',
    driverIndex: 0,
    basis: ResultsLinkBasis.lapTime,
    sessionStartedAt: s.startedAt,
    matchedLapSeconds: 206.8879,
  ),
  session: s,
);

void main() {
  group('the lines', () {
    test('an online race says everything a race has', () {
      expect(_facts(_sarthe, 0), {
        'Session': 'Online · Test Server 2',
        'Event': '24 Hours of Le Mans',
        'Race length': '1 h',
        'Rules': 'Fuel use ×2 · Tyre wear ×3 · Damage 50 %',
        'Result': 'Started P4 (P3 in class) · finished P1 (P1 in class)',
        'Field': '3 cars · 2 Hypercar',
        'Pit stops': '1',
        'Car': 'Alpine A424 · Alpine Endurance Team · #35',
        'Game version': '1.4150',
      });
    });

    test('an offline practice leaves out what does not apply', () {
      expect(_facts(_bahrain, 0), {
        'Session': 'Offline race weekend',
        'Event': '8 Hours of Bahrain',
        'Classified': 'P1 overall · P1 in class',
        'Field': '1 car',
        'Car': 'Ferrari 499P · Ferrari AF Corse · #50',
        'Aids': 'auto-clutch · auto-blip',
        'Game version': '1.4200',
      });
    });

    test('a retirement says why', () {
      expect(
        _facts(_sarthe, 1)['Result'],
        'Finished P2 (P2 in class) · DNF · Accident',
      );
    });

    test('a shared car names its drivers by lap range', () {
      final shared = _sarthe.drivers[2].copyWith(
        swaps: const [
          ResultsStint(startLap: 1, endLap: 302, value: '???'),
          ResultsStint(startLap: 303, endLap: 339, value: 'Driver Three'),
          ResultsStint(startLap: 340, endLap: 357, value: 'Driver Four'),
        ],
        aids: const [
          ResultsStint(startLap: 1, endLap: 302, value: 'UnknownControl'),
          ResultsStint(
            startLap: 303,
            endLap: 402,
            value: 'PlayerControl,TC=3,Clutch',
          ),
        ],
      );
      final facts = {
        for (final f in resultsFactsOf(_sarthe, shared)) f.label: f.value,
      };
      expect(
        facts['Drivers'],
        'laps 303–339: Driver Three · laps 340–357: Driver Four',
      );
      expect(facts['Aids'], 'TC 3 · auto-clutch');
    });
  });

  group('the card', () {
    const source = TelemetrySource.path('recording.duckdb');

    Future<void> pump(
      WidgetTester tester, {
      required bool folder,
      LinkedResults? linked,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resultsIndexStoreProvider.overrideWithValue(
              MemoryResultsIndexStore(
                folders: [
                  if (folder)
                    LibraryFolder(path: 'R', addedAt: DateTime.utc(2026)),
                ],
              ),
            ),
            linkedResultsProvider(source).overrideWith((ref) async => linked),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ResultsFactsCard(source: source),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is absent until a results folder is added', (tester) async {
      await pump(tester, folder: false, linked: _linked(_sarthe));
      expect(find.text('Session results'), findsNothing);
      expect(find.textContaining('No LMU results file'), findsNothing);
    });

    testWidgets('says so when no file matches', (tester) async {
      await pump(tester, folder: true);
      expect(
        find.textContaining('No LMU results file matches'),
        findsOneWidget,
      );
    });

    testWidgets('lists the facts and names the file', (tester) async {
      await pump(tester, folder: true, linked: _linked(_sarthe));
      expect(find.text('Session results'), findsOneWidget);
      expect(
        find.text("From LMU's results file 2026_10_23_00_48_40-12R1.xml"),
        findsOneWidget,
      );
      expect(find.text('Online · Test Server 2'), findsOneWidget);
      expect(
        find.text('Started P4 (P3 in class) · finished P1 (P1 in class)'),
        findsOneWidget,
      );
    });
  });
}
