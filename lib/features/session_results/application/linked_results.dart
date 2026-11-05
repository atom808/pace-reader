/// The open recording's session in LMU's results: what the Overview's facts
/// (results proposal, R4) and the race-control marks (R3) read.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
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
