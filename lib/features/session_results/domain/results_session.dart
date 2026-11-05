/// One LMU session results file, typed (results proposal, R1).
///
/// LMU writes `UserData\Log\Results\<local stamp>P1.xml` (or `Q`, `R`) when a
/// session ends: the rFactor results XML. Unlike a `.duckdb` recording it
/// holds **every car's** laps, race control's calls, and the session's
/// settings. These types carry what the app reads from it, close to the
/// file's own names and units, the way `SessionMetadata` does for a recording.
///
/// What the fields mean was checked against two of the user's recordings
/// (Bahrain practice, 5 Nov 2026; Le Mans race, 23 Oct 2026): every timed lap
/// equal to 0.0001 s, and the same session clock in both files.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'results_session.freezed.dart';

/// The session element's name: `Practice1`, `Qualify` or `Race` in all 1,054
/// files measured. Anything else (a warm-up, a test day) is [other] and is
/// never linked to a recording, whose `SessionType` has only the three.
enum ResultsSessionKind {
  practice,
  qualify,
  race,
  other;

  /// Exact names with an optional number: `RaceLaps` and `RaceTime` are
  /// header fields, not sessions.
  static ResultsSessionKind fromElementName(String name) =>
      switch (_sessionName.firstMatch(name)?.group(1)) {
        'Practice' => practice,
        'Qualify' => qualify,
        'Race' => race,
        _ => other,
      };

  /// Whether [name] is a session element at all, including [other] ones.
  static bool isSessionElement(String name) => _anySession.hasMatch(name);

  static final _sessionName = RegExp(r'^(Practice|Qualify|Race)\d*$');
  static final _anySession = RegExp(
    r'^(Practice|Qualify|Race|Warmup|TestDay)\d*$',
  );
}

@freezed
abstract class ResultsSession with _$ResultsSession {
  const ResultsSession._();

  const factory ResultsSession({
    /// The session element's name, verbatim (`Practice1`).
    required String sessionElement,
    required ResultsSessionKind kind,

    /// The session's own `<DateTime>`, the second one in the file: UTC epoch
    /// seconds. Unique across all 1,054 files measured. Never the file name
    /// or `<TimeString>`, which are local time.
    required DateTime startedAt,

    /// The weekend's `<DateTime>`, the first in the file. Restarts of an
    /// offline weekend share it, so it identifies nothing on its own.
    required DateTime weekendStartedAt,

    /// `Multiplayer` or `Race Weekend` (offline).
    required String setting,
    required String serverName,

    /// `= metadata.TrackName` of a recording of the same session.
    required String trackVenue,

    /// `= metadata.TrackLayout`.
    required String trackCourse,

    /// `8 Hours of Bahrain`.
    required String trackEvent,
    double? trackLengthMetres,
    required String gameVersion,

    /// 0 for a timed race, which then has [raceMinutes].
    int? raceLaps,
    int? raceMinutes,
    double? fuelMultiplier,
    double? tyreMultiplier,

    /// `DamageMult`, a percentage: 100 is full damage.
    double? damagePercent,
    @Default(<ResultsDriver>[]) List<ResultsDriver> drivers,

    /// Race control's log, in file order. Timing lines (`Score`) and chat are
    /// not read: the first repeats the laps, the second is other people's
    /// conversation.
    @Default(<ResultsEvent>[]) List<ResultsEvent> events,
  }) = _ResultsSession;

  /// The latest session time anything in the file reaches: a lap's end or an
  /// event. Zero for a file with neither (100 of 1,054 hold no lap).
  double get lastElapsedSeconds {
    var last = 0.0;
    for (final driver in drivers) {
      for (final lap in driver.laps) {
        final start = lap.startElapsed;
        if (start == null) continue;
        final end = start + (lap.lapSeconds ?? 0);
        if (end > last) last = end;
      }
    }
    for (final event in events) {
      if (event.elapsed > last) last = event.elapsed;
    }
    return last;
  }

  /// When the last thing in the file happened: [startedAt] plus
  /// [lastElapsedSeconds].
  DateTime get endsAt => startedAt.add(
    Duration(milliseconds: (lastElapsedSeconds * 1000).round()),
  );

  ResultsDriver? get player => drivers.where((d) => d.isPlayer).firstOrNull;

  int get lapCount => drivers.fold(0, (sum, d) => sum + d.laps.length);

  /// This session as the index keeps it: without other cars' track-limit
  /// calls that came to nothing.
  ///
  /// Those are 313,457 of the 548,745 race-control lines in the user's 1,054
  /// files, and nothing reads them: the lap view shows the user's own car's
  /// calls, and a "No Further Action" for someone else changed nothing about
  /// anyone's lap. Every other line is kept, the player's car's included.
  ResultsSession forIndex() {
    final mine = player?.driverNames ?? const <String>{};
    return copyWith(
      events: [
        for (final e in events)
          if (e.kind != ResultsEventKind.trackLimits ||
              e.text != 'No Further Action' ||
              mine.contains(e.driverName))
            e,
      ],
    );
  }
}

/// One car's entry: `<Driver>`.
@freezed
abstract class ResultsDriver with _$ResultsDriver {
  const ResultsDriver._();

  const factory ResultsDriver({
    /// 0-based order in the file. The slot numbers in the event log
    /// (`Name(10)`, `ID="21"`) are the server's and are not this.
    required int index,

    /// The car's driver when the file was written. For a shared car, every
    /// driver is in [swaps].
    required String name,
    required bool isPlayer,
    required String vehicleFile,

    /// `= metadata.CarName` of a recording in this car.
    required String vehicleName,

    /// The model, `Ferrari 499P`.
    required String carType,

    /// `= metadata.CarClass` (`Hyper`, `GT3`, `LMP2_ELMS`).
    required String carClass,

    /// `WEC 2026, Hypercar, Ferrari 499P`.
    required String category,
    required String teamName,
    required String carNumber,
    int? gridPosition,
    int? classGridPosition,
    int? position,
    int? classPosition,
    double? bestLapSeconds,
    double? finishElapsed,
    required int lapsCompleted,
    required int pitStops,
    required String finishStatus,
    String? dnfReason,
    @Default(<ResultsStint>[]) List<ResultsStint> swaps,
    @Default(<ResultsStint>[]) List<ResultsStint> aids,
    @Default(<ResultsLap>[]) List<ResultsLap> laps,
  }) = _ResultsDriver;

  /// Everyone who drove the car: [name] and every [swaps] name. `???` is the
  /// file's own "unknown" and is left out.
  Set<String> get driverNames => {
    name,
    for (final s in swaps)
      if (s.value != '???') s.value,
  };
}

/// A lap range and what held over it: a `<Swap>` (who drove) or a
/// `<ControlAndAids>` (`PlayerControl,Clutch,AutoBlip`).
@freezed
abstract class ResultsStint with _$ResultsStint {
  const factory ResultsStint({
    required int startLap,
    required int endLap,
    required String value,
  }) = _ResultsStint;
}

/// One `<Lap>`.
@freezed
abstract class ResultsLap with _$ResultsLap {
  const ResultsLap._();

  const factory ResultsLap({
    /// 1-based, as the file writes it. A recording's 0-based `Lap` value is
    /// `number - 1`.
    required int number,

    /// Overall position at the lap's end.
    int? position,

    /// `et`: session time at the lap's **start**, on the recording's clock
    /// (Bahrain lap 3 starts at 311.2858; the recording's lap 2 ends at
    /// 311.30). Null on a first lap, where the file writes `--.---`.
    double? startElapsed,

    /// Null where the file writes `--.----`: the laps the recording also
    /// leaves untimed.
    double? lapSeconds,

    /// Per sector, **not** cumulative (unlike the recording's sector events,
    /// SPEC §8.3.1). An invalidated lap keeps its time and loses its sectors.
    double? sector1Seconds,
    double? sector2Seconds,
    double? sector3Seconds,

    /// km/h. `0.00` on laps nobody measured (spectated ones) reads as null.
    double? topSpeedKmh,

    /// Fractions of the tank, after the lap.
    double? fuelFraction,
    double? fuelUsedFraction,

    /// Fractions of the energy allowance. Only some sessions carry them
    /// (4,400 of 21,519 laps in one 24-hour race; none in the Le Mans race),
    /// so null means "not in the file", never zero.
    double? energyFraction,
    double? energyUsedFraction,

    /// Tread left per corner after the lap, 1.0 when new: the recording's
    /// `Tyres Wear` channel (FL, FR, RL, RR) at the lap's end, held in
    /// 256ths, so to within 0.2 % (checked on all 13 laps of the Bahrain
    /// practice, proposal §4). Every offline file has it; some servers
    /// leave it, fuel and energy out for every car.
    double? wearFrontLeft,
    double? wearFrontRight,
    double? wearRearLeft,
    double? wearRearRight,

    /// `1,Medium` per axle, verbatim.
    String? compoundFront,
    String? compoundRear,

    /// `pit="1"`: the lap includes a stop.
    @Default(false) bool pit,
  }) = _ResultsLap;

  bool get hasAllSectors =>
      sector1Seconds != null &&
      sector2Seconds != null &&
      sector3Seconds != null;
}

/// What a race-control line is.
enum ResultsEventKind {
  /// `<TrackLimits>`: an excursion and what race control decided.
  trackLimits,

  /// `<Incident>`: a reported contact.
  incident,

  /// `<Penalty>`: given or served.
  penalty,

  /// `<Sector>`: damage reports, new sector bests.
  sector,

  /// `<DriverChange>` and `<Sent>`: who took over a car.
  driverChange,
}

/// One race-control line from `<Stream>`.
@freezed
abstract class ResultsEvent with _$ResultsEvent {
  const factory ResultsEvent({
    required ResultsEventKind kind,

    /// `et`, on the same clock as the laps.
    required double elapsed,

    /// The line's text, verbatim (`No Further Action`, `… reported contact
    /// (1081.22) with Immovable`).
    required String text,

    /// From the attributes where the line has them (`TrackLimits`, a given
    /// `Penalty`), else parsed from the text's leading `Name(slot)`.
    String? driverName,
    int? slot,

    /// `TrackLimits Lap`: **0-based**, the recording's own lap index.
    int? lap,

    /// `TrackLimits Resolution` code; [text] holds its words.
    int? resolution,
    double? warningPoints,
    double? currentPoints,

    /// A given penalty's kind and reason (`Drive Thru`, `Track Limits`).
    String? penalty,
    String? reason,
  }) = _ResultsEvent;
}
