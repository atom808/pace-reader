// Race control's calls about one car, cut into the recording's laps
// (results proposal, R3), and how Lap Analysis marks them.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';
import 'package:pace_reader/features/lap_analysis/presentation/incident_marks.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/race_control.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';

import '../fixtures/results_xml_samples.dart';

final _bahrain = parseResultsXml(bahrainPracticeXml);
final _sarthe = parseResultsXml(sartheRaceXml);

ResultsDriver _driver(ResultsSession s, String name) =>
    s.drivers.firstWhere((d) => d.name == name);

Lap _lap(int index, double start, double? end) => Lap(
  index: index,
  startSeconds: start,
  endSeconds: end,
  lapTimeSeconds: end == null ? null : end - start,
  sectors: const SectorTimes(),
);

void main() {
  final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

  group('the calls', () {
    test('track limits are the car\'s own, in time order', () {
      final calls = raceControlFor(_bahrain, _driver(_bahrain, 'Test Driver'));
      expect(calls.map((c) => c.kind), [
        RaceControlKind.trackLimits,
        RaceControlKind.trackLimits,
      ]);
      expect(calls.map((c) => c.elapsed), [503.9, 510.2]);
      expect(calls.first.severity, 0);
      expect(calls.first.sentence, 'Track limits: No Further Action');
      expect(calls.last.isSanction, isTrue);
      expect(calls.last.severity, 2);
      expect(raceControlTickLabel(calls.last), 'invalid');
    });

    test('contacts are sized against their own kind', () {
      final calls = raceControlFor(_sarthe, _driver(_sarthe, 'Driver One'));
      final contacts = [
        for (final c in calls)
          if (c.kind == RaceControlKind.contact) c,
      ];
      // 1081 against a wall is firm (median 122, 90th 3126); 54.8 on the
      // wing is firm too (19, 101); 221.9 car to car is light (293).
      expect(contacts.map((c) => c.size), [
        ContactSize.firm,
        ContactSize.firm,
        ContactSize.light,
      ]);
      expect(contacts[0].sentence, 'Firm contact with a wall or barrier');
      expect(contacts[1].sentence, 'Firm contact with the wing');
      // Driver One did not report the touch, so Driver Two's report stands.
      expect(contacts[2].reportedByOther, isTrue);
      expect(contacts[2].sentence, 'Light contact from Driver Two');
    });

    test('damage and penalties go to the car named, not the player', () {
      final one = raceControlFor(_sarthe, _driver(_sarthe, 'Driver One'));
      expect(
        one.where((c) => c.kind != RaceControlKind.contact),
        isEmpty,
      );

      final two = raceControlFor(_sarthe, _driver(_sarthe, 'Driver Two'));
      expect(two.map((c) => c.sentence), [
        'Light contact with Driver One',
        'Reports new suspension damage',
        'Penalty: Drive Thru for Track Limits',
        'Served the Drive Thru penalty',
      ]);
      expect(two.map((c) => c.severity), [0, 2, 2, 2]);
    });

    test('a touch both cars report is kept once, as each car\'s own', () {
      final both = parseResultsXml(
        sartheRaceXml.replaceFirst(
          '<Sector et="3100.4">',
          '<Incident et="3001.1">Driver One(10) reported contact (300.00) '
              'with another vehicle Driver Two(31)</Incident>\n'
              '<Sector et="3100.4">',
        ),
      );
      final one = raceControlFor(both, _driver(both, 'Driver One'))
          .where((c) => c.otherCar != null)
          .toList();
      expect(one, hasLength(1));
      expect(one.single.reportedByOther, isFalse);
      expect(one.single.sentence, 'Firm contact with Driver Two');

      final two = raceControlFor(both, _driver(both, 'Driver Two'))
          .where((c) => c.otherCar != null)
          .toList();
      expect(two, hasLength(1));
      expect(two.single.reportedByOther, isFalse);
    });

    test('nothing is read from chat', () {
      final calls = [
        for (final d in _sarthe.drivers) ...raceControlFor(_sarthe, d),
      ];
      expect(calls.where((c) => c.text.contains('gg')), isEmpty);
    });
  });

  group('by lap', () {
    test('a call lands on the lap it fell in; the open lap takes the rest', () {
      final calls = raceControlFor(_bahrain, _driver(_bahrain, 'Test Driver'));
      final laps = [
        _lap(0, 100, 200),
        _lap(1, 200, 505),
        _lap(2, 505, null),
      ];
      final byLap = raceControlByLap(calls, laps);
      expect(byLap.keys, [1, 2]);
      expect(byLap[1]!.single.elapsed, 503.9);
      expect(byLap[2]!.single.elapsed, 510.2);
    });

    test('a call before the first lap is on no lap', () {
      final calls = raceControlFor(_bahrain, _driver(_bahrain, 'Test Driver'));
      expect(raceControlByLap(calls, [_lap(0, 600, null)]), isEmpty);
    });
  });

  group('the marks', () {
    test('one mark per kind, coloured by its worst call', () {
      final calls = raceControlFor(_bahrain, _driver(_bahrain, 'Test Driver'));
      final lap = _lap(3, 500, 610);
      final marks = raceControlMarks(scheme, lap, calls);
      expect(marks, hasLength(1));
      expect(marks.single.kind, IncidentKind.trackLimits);
      expect(marks.single.label, 'lap invalidated');
      expect(marks.single.color, scheme.error);
      expect(
        marks.single.tooltip.split('\n'),
        [
          '3.9 s into the lap: Track limits: No Further Action',
          '10.2 s into the lap: Track limits: Invalid Lap Cut Track',
          'From race control, in LMU\'s results file for this session.',
        ],
      );
    });

    test('a note alone is neutral, and counted', () {
      final calls = raceControlFor(
        _bahrain,
        _driver(_bahrain, 'Test Driver'),
      ).where((c) => c.severity == 0).toList();
      final marks = raceControlMarks(scheme, _lap(3, 500, 610), calls);
      expect(marks.single.label, 'limits');
      expect(marks.single.color, scheme.onSurfaceVariant);
    });

    test('race control sorts in among the recording\'s own marks', () {
      final calls = raceControlFor(_sarthe, _driver(_sarthe, 'Driver Two'));
      final lap = _lap(5, 2900, 3400);
      final marks = incidentMarks(
        scheme,
        lap,
        LapIncidents.none(lap.index),
        raceControl: calls,
      );
      expect(marks.map((m) => m.kind), [
        IncidentKind.penalty,
        IncidentKind.contact,
        IncidentKind.damage,
      ]);
      expect(marks.map((m) => m.label), ['penalty ×2', 'contact', 'damage']);
      expect(marks[1].color, scheme.onSurfaceVariant);
    });
  });
}
