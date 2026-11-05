/// Reads an LMU results file (`UserData\Log\Results\*.xml`) into a
/// [ResultsSession] (results proposal, R1).
///
/// Pure Dart over a string, so it runs in an isolate during a scan and in a
/// plain `flutter test`. Read-only by nature: nothing here can write a file.
library;

import 'dart:convert';

import 'package:xml/xml.dart';

import '../domain/results_session.dart';

/// Thrown for a file that isn't an LMU results file, with a reason a scan
/// can show next to the file's name.
class ResultsFormatException implements Exception {
  const ResultsFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Decodes a results file's bytes. The files say `utf-8`; a stray byte in a
/// driver's name becomes U+FFFD rather than failing the whole session.
String decodeResultsBytes(List<int> bytes) =>
    utf8.decode(bytes, allowMalformed: true);

/// Parses one results file.
///
/// Throws [ResultsFormatException] when the text isn't XML or has no
/// `<RaceResults>` with one session element in it.
ResultsSession parseResultsXml(String text) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(text);
  } on XmlException catch (error) {
    throw ResultsFormatException(
      'it is not well-formed XML (${error.message})',
    );
  }
  final results = document.rootElement.getElement('RaceResults');
  if (results == null) {
    throw const ResultsFormatException('it has no <RaceResults>');
  }
  // One per file in all 1,054 measured. The first, if a file ever has more.
  final session = results.childElements
      .where((e) => ResultsSessionKind.isSessionElement(e.name.local))
      .firstOrNull;
  if (session == null) {
    throw const ResultsFormatException('it has no session in it');
  }

  final weekendStart = _epoch(_text(results, 'DateTime'));
  final sessionStart = _epoch(_text(session, 'DateTime')) ?? weekendStart;
  if (sessionStart == null || weekendStart == null) {
    throw const ResultsFormatException('it has no session time');
  }

  final raceLaps = _int(_text(results, 'RaceLaps'));
  final raceMinutes = _int(_text(results, 'RaceTime'));

  return ResultsSession(
    sessionElement: session.name.local,
    kind: ResultsSessionKind.fromElementName(session.name.local),
    startedAt: sessionStart,
    weekendStartedAt: weekendStart,
    setting: _text(results, 'Setting') ?? '',
    serverName: _text(results, 'ServerName') ?? '',
    trackVenue: _text(results, 'TrackVenue') ?? '',
    trackCourse: _text(results, 'TrackCourse') ?? '',
    trackEvent: _text(results, 'TrackEvent') ?? '',
    trackLengthMetres: _double(_text(results, 'TrackLength')),
    gameVersion: _text(results, 'GameVersion') ?? '',
    raceLaps: raceLaps == 0 ? null : raceLaps,
    raceMinutes: raceMinutes == 0 ? null : raceMinutes,
    fuelMultiplier: _double(_text(results, 'FuelMult')),
    tyreMultiplier: _double(_text(results, 'TireMult')),
    damagePercent: _double(_text(results, 'DamageMult')),
    drivers: [
      for (final (i, d) in session.findElements('Driver').indexed)
        _driver(i, d),
    ],
    events: [
      for (final e
          in session.getElement('Stream')?.childElements ??
              const <XmlElement>[])
        ?_event(e),
    ],
  );
}

ResultsDriver _driver(int index, XmlElement d) => ResultsDriver(
  index: index,
  name: _text(d, 'Name') ?? '',
  isPlayer: _text(d, 'isPlayer') == '1',
  vehicleFile: _text(d, 'VehFile') ?? '',
  vehicleName: _text(d, 'VehName') ?? '',
  carType: _text(d, 'CarType') ?? '',
  carClass: _text(d, 'CarClass') ?? '',
  category: _text(d, 'Category') ?? '',
  teamName: _text(d, 'TeamName') ?? '',
  carNumber: _text(d, 'CarNumber') ?? '',
  gridPosition: _int(_text(d, 'GridPos')),
  classGridPosition: _int(_text(d, 'ClassGridPos')),
  position: _int(_text(d, 'Position')),
  classPosition: _int(_text(d, 'ClassPosition')),
  bestLapSeconds: _time(_text(d, 'BestLapTime')),
  finishElapsed: _time(_text(d, 'FinishTime')),
  lapsCompleted: _int(_text(d, 'Laps')) ?? 0,
  pitStops: _int(_text(d, 'Pitstops')) ?? 0,
  finishStatus: _text(d, 'FinishStatus') ?? '',
  dnfReason: _text(d, 'DNFReason'),
  swaps: [for (final s in d.findElements('Swap')) _stint(s)],
  aids: [for (final s in d.findElements('ControlAndAids')) _stint(s)],
  laps: [for (final l in d.findElements('Lap')) ?_lap(l)],
);

ResultsStint _stint(XmlElement e) => ResultsStint(
  startLap: _int(e.getAttribute('startLap')) ?? 0,
  endLap: _int(e.getAttribute('endLap')) ?? 0,
  value: e.innerText.trim(),
);

ResultsLap? _lap(XmlElement l) {
  final number = _int(l.getAttribute('num'));
  if (number == null) return null;
  final topSpeed = _double(l.getAttribute('topspeed'));
  return ResultsLap(
    number: number,
    position: _int(l.getAttribute('p')),
    startElapsed: _time(l.getAttribute('et')),
    lapSeconds: _time(l.innerText),
    sector1Seconds: _time(l.getAttribute('s1')),
    sector2Seconds: _time(l.getAttribute('s2')),
    sector3Seconds: _time(l.getAttribute('s3')),
    topSpeedKmh: topSpeed == null || topSpeed <= 0 ? null : topSpeed,
    fuelFraction: _double(l.getAttribute('fuel')),
    fuelUsedFraction: _double(l.getAttribute('fuelUsed')),
    energyFraction: _double(l.getAttribute('ve')),
    energyUsedFraction: _double(l.getAttribute('veUsed')),
    wearFrontLeft: _double(l.getAttribute('twfl')),
    wearFrontRight: _double(l.getAttribute('twfr')),
    wearRearLeft: _double(l.getAttribute('twrl')),
    wearRearRight: _double(l.getAttribute('twrr')),
    compoundFront: l.getAttribute('fcompound'),
    compoundRear: l.getAttribute('rcompound'),
    pit: l.getAttribute('pit') == '1',
  );
}

/// `Name(slot) rest of the line`, as `Incident` and `Sector` lines start.
final _namedSlot = RegExp(r'^(.+?)\((\d+)\) ');

ResultsEvent? _event(XmlElement e) {
  final kind = switch (e.name.local) {
    'TrackLimits' => ResultsEventKind.trackLimits,
    'Incident' => ResultsEventKind.incident,
    'Penalty' => ResultsEventKind.penalty,
    'Sector' => ResultsEventKind.sector,
    'DriverChange' || 'Sent' => ResultsEventKind.driverChange,
    _ => null,
  };
  final elapsed = _double(e.getAttribute('et'));
  if (kind == null || elapsed == null) return null;
  final text = e.innerText.trim();

  var driver = e.getAttribute('Driver');
  var slot = _int(e.getAttribute('ID'));
  if (driver == null) {
    switch (e.name.local) {
      case 'DriverChange':
        driver = _quoted(text, 'New');
        slot = _int(RegExp(r'Slot=(\d+)').firstMatch(text)?.group(1));
      case 'Sent':
        final cut = text.indexOf(' Is now driving');
        if (cut > 0) driver = text.substring(0, cut);
      default:
        final match = _namedSlot.firstMatch(text);
        if (match != null) {
          driver = match.group(1);
          slot = int.parse(match.group(2)!);
        }
    }
  }

  return ResultsEvent(
    kind: kind,
    elapsed: elapsed,
    text: text,
    driverName: driver,
    slot: slot,
    lap: _int(e.getAttribute('Lap')),
    resolution: _int(e.getAttribute('Resolution')),
    warningPoints: _double(e.getAttribute('WarningPoints')),
    currentPoints: _double(e.getAttribute('CurrentPoints')),
    penalty: e.getAttribute('Penalty'),
    reason: e.getAttribute('Reason'),
  );
}

/// `Key="value"` inside a line's text (`DriverChange`), where the file
/// writes `&quot;` that the parser has already turned into `"`.
String? _quoted(String text, String key) =>
    RegExp('$key="([^"]*)"').firstMatch(text)?.group(1);

String? _text(XmlElement parent, String name) =>
    parent.getElement(name)?.innerText.trim();

int? _int(String? raw) => raw == null ? null : int.tryParse(raw.trim());

double? _double(String? raw) =>
    raw == null ? null : double.tryParse(raw.trim());

/// A time the file may write as `--.----` (no time) or as a number.
double? _time(String? raw) {
  final value = _double(raw);
  return value == null || value <= 0 ? null : value;
}

DateTime? _epoch(String? raw) {
  final seconds = _int(raw);
  return seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
}
