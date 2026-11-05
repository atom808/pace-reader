// LMU results files (results proposal, R1): what the parser reads, checked
// against the meanings measured on the user's own files.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/session_results/data/results_xml.dart';
import 'package:pace_reader/features/session_results/domain/results_session.dart';

import '../fixtures/results_xml_samples.dart';

void main() {
  group('an offline practice', () {
    final session = parseResultsXml(bahrainPracticeXml);
    final me = session.drivers.single;

    test('reads the header, and times in UTC from <DateTime>', () {
      expect(session.kind, ResultsSessionKind.practice);
      expect(session.sessionElement, 'Practice1');
      expect(session.setting, 'Race Weekend');
      expect(session.serverName, '');
      // The session's own stamp, not the weekend's, and never the local
      // <TimeString> (23:37 in Brazil).
      expect(session.startedAt, DateTime.utc(2026, 11, 5, 2, 37, 25));
      expect(session.weekendStartedAt, DateTime.utc(2026, 11, 5, 2, 37, 23));
      expect(session.trackVenue, 'Bahrain International Circuit');
      expect(session.trackCourse, 'Bahrain International Circuit');
      expect(session.trackEvent, '8 Hours of Bahrain');
      expect(session.trackLengthMetres, 5386.8);
      expect(session.gameVersion, '1.4200');
      expect(session.raceLaps, isNull, reason: '0 laps means a timed race');
      expect(session.raceMinutes, 60);
      expect(session.fuelMultiplier, 1);
      expect(session.tyreMultiplier, 1);
      expect(session.damagePercent, 100);
    });

    test('reads the car the way a recording names it', () {
      expect(me.isPlayer, isTrue);
      expect(session.player, me);
      expect(me.vehicleName, 'Ferrari AF Corse 2026 #50:LM');
      expect(me.carType, 'Ferrari 499P');
      expect(me.carClass, 'Hyper');
      expect(me.bestLapSeconds, 107.7979);
      expect(me.aids.single.value, 'PlayerControl,Clutch,AutoBlip');
    });

    test('a first lap has no start time and no lap time', () {
      final lap1 = me.laps.first;
      expect(lap1.number, 1);
      expect(lap1.startElapsed, isNull);
      expect(lap1.lapSeconds, isNull);
      expect(lap1.fuelFraction, 0.694);
      expect(lap1.compoundFront, '1,Medium');
    });

    test('sectors are per sector and add up to the lap', () {
      final lap2 = me.laps[1];
      expect(lap2.startElapsed, 201.4094);
      expect(lap2.lapSeconds, 109.8764);
      expect(
        lap2.sector1Seconds! + lap2.sector2Seconds! + lap2.sector3Seconds!,
        closeTo(109.8764, 1e-9),
      );
      expect(lap2.hasAllSectors, isTrue);
      expect(lap2.energyFraction, 0.937);
      expect(lap2.wearRearLeft, 0.976);
    });

    test('an invalidated lap keeps its time and loses its sectors', () {
      final lap4 = me.laps[3];
      expect(lap4.lapSeconds, 107.7979);
      expect(lap4.hasAllSectors, isFalse);
      expect(lap4.sector1Seconds, isNull);
    });

    test('a top speed of 0.00 was not measured', () {
      expect(me.laps.last.topSpeedKmh, isNull);
      expect(me.laps.last.lapSeconds, isNull);
    });

    test('track-limit calls keep their 0-based lap and resolution', () {
      expect(session.events, hasLength(2));
      final call = session.events.last;
      expect(call.kind, ResultsEventKind.trackLimits);
      expect(call.driverName, 'Test Driver');
      expect(call.slot, 0);
      expect(call.lap, 3, reason: 'the recording\'s lap index: lap 4 here');
      expect(call.resolution, 5);
      expect(call.text, 'Invalid Lap Cut Track');
      expect(call.elapsed, 510.2);
    });

    test('lastElapsedSeconds reaches the last lap\'s end', () {
      expect(session.lastElapsedSeconds, closeTo(419.4378 + 107.7979, 1e-9));
    });
  });

  group('an online race', () {
    final session = parseResultsXml(sartheRaceXml);

    test('reads every car, the multipliers and the server', () {
      expect(session.kind, ResultsSessionKind.race);
      expect(session.setting, 'Multiplayer');
      expect(session.serverName, 'Test Server 2');
      expect(session.drivers.map((d) => d.carType), [
        'Alpine A424',
        'BMW M Hybrid V8',
        'Lexus RC F LMGT3',
      ]);
      expect(session.fuelMultiplier, 2);
      expect(session.tyreMultiplier, 3);
      expect(session.damagePercent, 50);
      expect(session.lapCount, 6);
    });

    test('reads grid, finish and pit facts', () {
      final me = session.player!;
      expect(me.gridPosition, 4);
      expect(me.classGridPosition, 3);
      expect(me.finishElapsed, 812.6001);
      expect(me.pitStops, 1);
      expect(me.laps.last.pit, isTrue);
      expect(me.laps.first.pit, isFalse);
      expect(me.laps.first.energyFraction, isNull, reason: 'no ve in file');

      final dnf = session.drivers[1];
      expect(dnf.finishStatus, 'DNF');
      expect(dnf.dnfReason, 'Accident');
      expect(dnf.gridPosition, isNull);
    });

    test('a shared car names every driver but the unknown one', () {
      final shared = session.drivers[2];
      expect(shared.swaps, hasLength(3));
      expect(shared.driverNames, {'Driver Four', 'Driver Three'});
    });

    test('reads race control, and never the timing lines or the chat', () {
      expect(session.events.map((e) => e.kind), [
        ResultsEventKind.incident,
        ResultsEventKind.incident,
        ResultsEventKind.incident,
        ResultsEventKind.sector,
        ResultsEventKind.penalty,
        ResultsEventKind.penalty,
        ResultsEventKind.driverChange,
        ResultsEventKind.driverChange,
      ]);
      expect(session.events.any((e) => e.text.contains('gg')), isFalse);

      final contact = session.events.first;
      expect(contact.driverName, 'Driver One');
      expect(contact.slot, 10);
      expect(contact.text, contains('(1081.22) with Immovable'));

      final hit = session.events[2];
      expect(hit.driverName, 'Driver Two');
      expect(hit.text, endsWith('with another vehicle Driver One(10)'));

      final given = session.events[4];
      expect(given.driverName, 'Driver Two');
      expect(given.slot, 31);
      expect(given.penalty, 'Drive Thru');
      expect(given.reason, 'Track Limits');
      // A served penalty has no attributes; its name starts the text.
      expect(session.events[5].driverName, isNull);

      final change = session.events[6];
      expect(change.driverName, 'Driver Four');
      expect(change.slot, 44);
      expect(change.text, contains('Old="Driver Three"'));
      expect(session.events[7].driverName, 'Driver Four');
    });
  });

  group('not a results file', () {
    test('malformed XML says so', () {
      expect(
        () => parseResultsXml('<rFactorXML><RaceResults>'),
        throwsA(isA<ResultsFormatException>()),
      );
    });

    test('XML without results says so', () {
      expect(
        () => parseResultsXml('<?xml version="1.0"?><other/>'),
        throwsA(
          isA<ResultsFormatException>().having(
            (e) => e.message,
            'message',
            'it has no <RaceResults>',
          ),
        ),
      );
    });

    test('a stray byte in a name decodes rather than failing', () {
      final bytes = [...'<a>Jos'.codeUnits, 0xE9, ...'</a>'.codeUnits];
      expect(decodeResultsBytes(bytes), '<a>Jos�</a>');
    });
  });
}
