/// Riverpod wiring for the data layer (SPEC.md §9.3).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_repository.dart';
import 'session_repository.dart';
import 'telemetry_repository.dart';

part 'providers.g.dart';

/// Opt every provider in this layer out of Riverpod 3's automatic retry.
///
/// The default retries a failed provider forever, doubling the delay up to
/// 6.4 s. That suits a flaky network call; it is actively wrong here, because
/// every failure this layer produces is *deterministic* — a corrupt file, an
/// unsupported format version, a schema mismatch, a malformed query (§10).
/// Re-reading the same broken file on a timer cannot succeed, burns CPU on a
/// multi-hundred-megabyte read, and leaves the app permanently unsettled with
/// a pending timer. Failing once and letting the user act is the correct
/// behaviour; retrying is only correct when a cause can go away on its own.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The open session for a given source.
///
/// `keepAlive` because the family key *is* the open file: disposing on the
/// last listener would close the DuckDB connection whenever the user navigated
/// between two feature screens, and reopening re-reads the catalog and
/// re-scans the clock (§9.6). Sessions are released explicitly instead.
///
/// Note this only works because [TelemetrySource] has value equality — a
/// family keyed on identity would reopen the file on every rebuild.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TelemetrySession> telemetrySession(Ref ref, TelemetrySource source) async {
  final session = await openTelemetrySession(source);
  ref.onDispose(session.dispose);
  return session;
}

/// Session metadata (§8.2) — the cheapest thing to depend on when a screen
/// needs the header facts but no telemetry.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionMetadata> sessionMetadata(Ref ref, TelemetrySource source) async =>
    (await ref.watch(telemetrySessionProvider(source).future)).metadata;

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TelemetryCatalog> telemetryCatalog(Ref ref, TelemetrySource source) async =>
    (await ref.watch(telemetrySessionProvider(source).future)).catalog;

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<LapRepository> lapRepository(Ref ref, TelemetrySource source) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return LapRepository(session.database);
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TelemetryRepository> telemetryRepository(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return TelemetryRepository(session.database, session.catalog);
}

/// Recording discontinuities (§5.2, §15.12).
///
/// Its own provider rather than reached through the session handle, so a
/// screen showing the notice depends on a `List<ClockGap>` it can be given in
/// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
/// connection, and a screen that requires one is a screen only an
/// `integration_test` can cover.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<List<ClockGap>> sessionClockGaps(Ref ref, TelemetrySource source) async =>
    (await ref.watch(telemetrySessionProvider(source).future)).clockGaps;

/// Every lap in the session (§8.3).
///
/// Read once and shared rather than re-queried per screen: the lap table, the
/// trace view's lap picker, the track map and the fuel view all need the same
/// list, and the query is small enough that caching it beats coordinating who
/// owns it.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<List<Lap>> laps(Ref ref, TelemetrySource source) async =>
    (await ref.watch(lapRepositoryProvider(source).future)).readLaps();

/// Every recorded change in the session, in time order (§8.12).
///
/// Session-scoped rather than window-scoped because the Events Log is a
/// filtering view over the whole recording, and the whole recording is small:
/// 4,280–20,304 rows across all 42 tables in the three real samples, read in
/// 62 ms. Filtering happens in Dart over the loaded list, so changing the
/// filter costs nothing and re-querying per keystroke never arises.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<EventLog> sessionEventLog(Ref ref, TelemetrySource source) async =>
    (await ref.watch(telemetryRepositoryProvider(source).future)).readEventLog();
