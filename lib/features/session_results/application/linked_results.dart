/// The open recording's session in LMU's results: what the Overview's facts
/// (results proposal, R4) and the race-control marks (R3) read.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/models/models.dart';
import '../domain/race_control.dart';
import '../domain/results_link.dart';
import '../domain/results_session.dart';
import 'session_results.dart';

part 'linked_results.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// A recording's results session, the car in it, and how they were matched.
class LinkedResults {
  const LinkedResults({required this.link, required this.session});

  final ResultsLink link;
  final ResultsSession session;

  /// The recording's car in [session].
  ResultsDriver get car =>
      session.drivers.firstWhere((d) => d.index == link.driverIndex);

  /// The cars in [car]'s class, [car] included.
  List<ResultsDriver> get classField => [
    for (final d in session.drivers)
      if (d.carClass == car.carClass) d,
  ];
}

/// The results session [source] was recorded in, read whole from the index,
/// or null when no file links (or no results folder was ever added).
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<LinkedResults?> linkedResults(Ref ref, TelemetrySource source) async {
  ref.watch(resultsIndexRevisionProvider);
  final store = ref.watch(resultsIndexStoreProvider);
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final laps = await ref.watch(lapsProvider(source).future);
  final link = await findResultsLink(
    store,
    RecordingKey.ofSession(metadata, laps),
  );
  if (link == null) return null;
  final session = await store.readSession(link.path);
  if (session == null) return null;
  if (!session.drivers.any((d) => d.index == link.driverIndex)) return null;
  return LinkedResults(link: link, session: session);
}

/// Race control's calls about the recording's car, and the laps they fell
/// on (results proposal, R3).
class SessionRaceControl {
  const SessionRaceControl({required this.calls, required this.byLap});

  final List<RaceControlCall> calls;

  /// Keyed by `Lap.index`; only laps with a call.
  final Map<int, List<RaceControlCall>> byLap;

  List<RaceControlCall> of(Lap lap) => byLap[lap.index] ?? const [];
}

/// Null when the recording links to no results file.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionRaceControl?> sessionRaceControl(
  Ref ref,
  TelemetrySource source,
) async {
  final linked = await ref.watch(linkedResultsProvider(source).future);
  if (linked == null) return null;
  final laps = await ref.watch(lapsProvider(source).future);
  final calls = raceControlFor(linked.session, linked.car);
  return SessionRaceControl(calls: calls, byLap: raceControlByLap(calls, laps));
}
