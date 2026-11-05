/// Which results file holds the session a recording was made in (results
/// proposal, R1).
///
/// Pure, so every rule here is tested without a database or a file.
library;

import '../../../data/models/session_metadata.dart';
import '../../session_library/data/library_entry.dart';
import 'results_session.dart';

/// One car in a candidate session: what linking compares, and nothing else.
class ResultsCandidateDriver {
  const ResultsCandidateDriver({
    required this.index,
    required this.driverNames,
    required this.isPlayer,
    required this.vehicleName,
    required this.carClass,
    required this.lapTimes,
  });

  factory ResultsCandidateDriver.of(ResultsDriver d) => ResultsCandidateDriver(
    index: d.index,
    driverNames: d.driverNames,
    isPlayer: d.isPlayer,
    vehicleName: d.vehicleName,
    carClass: d.carClass,
    lapTimes: [for (final lap in d.laps) ?lap.lapSeconds],
  );

  final int index;
  final Set<String> driverNames;
  final bool isPlayer;
  final String vehicleName;
  final String carClass;

  /// The car's timed laps, in seconds.
  final List<double> lapTimes;
}

/// One results session that might hold a recording.
class ResultsCandidate {
  const ResultsCandidate({
    required this.path,
    required this.kind,
    required this.trackVenue,
    required this.trackCourse,
    required this.startedAt,
    required this.endsAt,
    required this.drivers,
  });

  factory ResultsCandidate.of(String path, ResultsSession s) =>
      ResultsCandidate(
        path: path,
        kind: s.kind,
        trackVenue: s.trackVenue,
        trackCourse: s.trackCourse,
        startedAt: s.startedAt,
        endsAt: s.endsAt,
        drivers: [for (final d in s.drivers) ResultsCandidateDriver.of(d)],
      );

  final String path;
  final ResultsSessionKind kind;
  final String trackVenue;
  final String trackCourse;
  final DateTime startedAt;
  final DateTime endsAt;
  final List<ResultsCandidateDriver> drivers;
}

/// How a link was established.
enum ResultsLinkBasis {
  /// The recording's best lap is one of the car's laps in the file, to the
  /// millisecond. Both files checked matched every lap to 0.0001 s, so this
  /// is unambiguous.
  lapTime,

  /// The recording has no timed lap, so only the track, the car, the driver
  /// and the time say it is this session.
  timeOnly,
}

/// A recording's session in a results file.
class ResultsLink {
  const ResultsLink({
    required this.path,
    required this.driverIndex,
    required this.basis,
    required this.sessionStartedAt,
    this.matchedLapSeconds,
  });

  /// The results file.
  final String path;

  /// The car's `<Driver>` in it.
  final int driverIndex;
  final ResultsLinkBasis basis;
  final DateTime sessionStartedAt;

  /// The lap time both files share, for [ResultsLinkBasis.lapTime].
  final double? matchedLapSeconds;

  @override
  bool operator ==(Object other) =>
      other is ResultsLink &&
      other.path == path &&
      other.driverIndex == driverIndex &&
      other.basis == basis &&
      other.sessionStartedAt == sessionStartedAt &&
      other.matchedLapSeconds == matchedLapSeconds;

  @override
  int get hashCode => Object.hash(
    path,
    driverIndex,
    basis,
    sessionStartedAt,
    matchedLapSeconds,
  );

  @override
  String toString() =>
      'ResultsLink($path #$driverIndex, ${basis.name}, $matchedLapSeconds)';
}

/// How far before a session's `<DateTime>` a recording of it may start. The
/// two checked started 24 s and 65 s *after*; this allows for a clock that
/// disagrees the other way.
const resultsLinkEarlySlack = Duration(minutes: 2);

/// How far after a file's last lap or event a recording may still start: a
/// recording begun on the last lap ends no later than the file does.
const resultsLinkLateSlack = Duration(minutes: 1);

/// Lap times equal to this are the same lap. The files agree to 0.0001 s; a
/// different lap of the same car is never this close in practice, and two
/// laps of two cars this close still have to be the same car to count.
const resultsLinkLapTolerance = 0.0005;

ResultsSessionKind resultsKindOf(SessionType type) => switch (type) {
  SessionType.practice => ResultsSessionKind.practice,
  SessionType.qualify => ResultsSessionKind.qualify,
  SessionType.race => ResultsSessionKind.race,
};

/// The window a candidate session's span has to overlap for [entry]:
/// what a store query narrows on before [linkRecording] decides.
({DateTime from, DateTime to})? resultsWindowFor(LibraryEntry entry) {
  final at = entry.recordedAt;
  if (at == null) return null;
  return (
    from: at.subtract(resultsLinkLateSlack),
    to: at.add(resultsLinkEarlySlack),
  );
}

/// The results session [entry]'s recording was made in, or null.
///
/// 1. **Same place, kind and time:** the track and layout equal
///    `TrackVenue` and `TrackCourse`, the session kind matches, and the
///    recording starts between the session's start (less
///    [resultsLinkEarlySlack]) and its last lap or event (plus
///    [resultsLinkLateSlack]).
/// 2. **Same car:** `VehName` equals `CarName` and the classes agree. Not
///    unique on its own: online, many entries run the same custom livery.
/// 3. **The same lap:** the recording's best lap is one of that car's laps.
///    When the recording has a best lap and no car has it, nothing links:
///    it was another session at the same place and time (a restart).
/// 4. **No timed lap:** the driver's name (or the file's player) decides
///    instead, and the link says it was made by time only.
///
/// Ties go to the car the recording's driver drove, then to the session
/// that started nearest the recording.
ResultsLink? linkRecording(
  LibraryEntry entry,
  Iterable<ResultsCandidate> candidates,
) {
  final at = entry.recordedAt;
  if (at == null) return null;
  final kind = resultsKindOf(entry.sessionType);
  final best = entry.bestLapSeconds;

  final found = <(ResultsCandidate, ResultsCandidateDriver, double?)>[];
  for (final c in candidates) {
    if (c.trackVenue != entry.trackName ||
        c.trackCourse != entry.trackLayout ||
        c.kind != kind ||
        at.isBefore(c.startedAt.subtract(resultsLinkEarlySlack)) ||
        at.isAfter(c.endsAt.add(resultsLinkLateSlack))) {
      continue;
    }
    for (final d in c.drivers) {
      if (d.vehicleName != entry.carName || d.carClass != entry.carClass) {
        continue;
      }
      if (best != null) {
        final lap = d.lapTimes
            .where((t) => (t - best).abs() < resultsLinkLapTolerance)
            .firstOrNull;
        if (lap != null) found.add((c, d, lap));
      } else if (d.driverNames.contains(entry.driverName) || d.isPlayer) {
        found.add((c, d, null));
      }
    }
  }
  if (found.isEmpty) return null;

  int rank((ResultsCandidate, ResultsCandidateDriver, double?) f) =>
      f.$2.driverNames.contains(entry.driverName) ? 0 : 1;
  Duration distance((ResultsCandidate, ResultsCandidateDriver, double?) f) =>
      f.$1.startedAt.difference(at).abs();
  found.sort((a, b) {
    final byDriver = rank(a).compareTo(rank(b));
    return byDriver != 0 ? byDriver : distance(a).compareTo(distance(b));
  });

  final (session, driver, lap) = found.first;
  return ResultsLink(
    path: session.path,
    driverIndex: driver.index,
    basis: lap == null ? ResultsLinkBasis.timeOnly : ResultsLinkBasis.lapTime,
    sessionStartedAt: session.startedAt,
    matchedLapSeconds: lap,
  );
}
