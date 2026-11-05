/// A timing-only session, opened from the library (results proposal, R5):
/// everything LMU's results file says about the player's car, with no
/// recording behind it.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/models.dart';
import '../domain/field_pace.dart';
import '../domain/race_control.dart';
import '../domain/results_session.dart';
import 'session_results.dart';

part 'timing_session.g.dart';

/// Which results file, and whose car in it: online, every human in a file
/// is marked a player, so the path alone does not say which car is the
/// user's.
typedef TimingSessionKey = ({String path, String driverName});

/// The timing page's session, or null for none.
///
/// App state rather than a route parameter, for the reason the router gives
/// for recordings: a path does not belong in a URL.
@Riverpod(keepAlive: true)
class OpenTimingSession extends _$OpenTimingSession {
  @override
  TimingSessionKey? build() => null;

  void open(String path, String driverName) =>
      state = (path: path, driverName: driverName);
}

/// One results file's session, read whole, from the player's car.
class TimingSession {
  TimingSession({required this.path, required this.session, required this.car})
    : laps = lapsOfResults(car.laps),
      pace = FieldPace.of(session, car) {
    calls = raceControlFor(session, car);
    callsByLap = raceControlByLap(calls, laps);
  }

  final String path;
  final ResultsSession session;
  final ResultsDriver car;

  /// [car]'s laps as the app's own lap model, on the file's clock: what the
  /// lap table, its marks and race control's calls are placed by.
  final List<Lap> laps;
  final FieldPace pace;
  late final List<RaceControlCall> calls;
  late final Map<int, List<RaceControlCall>> callsByLap;

  /// The file's lap for [lap].
  ResultsLap resultsLap(Lap lap) =>
      car.laps.firstWhere((l) => l.number == lap.displayNumber);
}

/// The file's laps as [Lap]s: 0-based like a recording's, each starting at
/// its `et` (or where the one before ended, for a first lap the file gives
/// no start) and ending where the next starts.
List<Lap> lapsOfResults(List<ResultsLap> laps) {
  final sorted = [...laps]..sort((a, b) => a.number.compareTo(b.number));
  final starts = <double?>[];
  double? previousEnd;
  for (final l in sorted) {
    final start = l.startElapsed ?? previousEnd;
    starts.add(start);
    previousEnd = start != null && l.lapSeconds != null
        ? start + l.lapSeconds!
        : null;
  }
  return [
    for (final (i, l) in sorted.indexed)
      Lap(
        index: l.number - 1,
        startSeconds: starts[i] ?? 0,
        endSeconds: i + 1 < sorted.length
            ? (starts[i + 1] ??
                  (starts[i] != null && l.lapSeconds != null
                      ? starts[i]! + l.lapSeconds!
                      : null))
            : (starts[i] != null && l.lapSeconds != null
                  ? starts[i]! + l.lapSeconds!
                  : null),
        // An invalidated lap keeps its time and loses its sectors: it is
        // not a timed lap, as a recording would not call it one.
        lapTimeSeconds: l.hasAllSectors && !l.pit ? l.lapSeconds : null,
        sectors: SectorTimes(
          sector1Seconds: l.sector1Seconds,
          sector2Seconds: l.sector2Seconds,
          sector3Seconds: l.sector3Seconds,
        ),
      ),
  ];
}

/// Null when the file is no longer in the index or has no such car.
@Riverpod(retry: _neverRetry)
Future<TimingSession?> timingSession(
  Ref ref,
  String path,
  String driverName,
) async {
  ref.watch(resultsIndexRevisionProvider);
  final session = await ref.watch(resultsIndexStoreProvider).readSession(path);
  if (session == null) return null;
  final car =
      session.drivers
          .where((d) => d.driverNames.contains(driverName))
          .firstOrNull ??
      session.player;
  if (car == null) return null;
  return TimingSession(path: path, session: session, car: car);
}

Duration? _neverRetry(int retryCount, Object error) => null;
