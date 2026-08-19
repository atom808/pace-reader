/// Riverpod wiring for the data layer (SPEC.md §9.3).
///
/// Written by hand rather than with `riverpod_generator`. The generator is a
/// codegen convenience over exactly this, and on the current toolchain it's
/// the builder that trips the pinned analyzer's dot-shorthand crash (see
/// `build.yaml`); these providers are few and stable enough that generating
/// them would buy nothing. Nothing about the DI shape §9.3 asks for depends on
/// the generator — swapping to it later is mechanical.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_repository.dart';
import 'session_repository.dart';
import 'telemetry_repository.dart';

/// The currently open session, keyed by source.
///
/// `keepAlive` because the family key *is* the open file: disposing on the
/// last listener would close the DuckDB connection every time the user
/// navigated between two feature screens and reopen it on arrival — and
/// reopening re-reads the catalog and re-scans the clock (§9.6). Sessions are
/// released explicitly via [closeTelemetrySession] instead.
final telemetrySessionProvider =
    FutureProvider.family<TelemetrySession, TelemetrySource>((ref, source) async {
  final session = await openTelemetrySession(source);
  ref.onDispose(session.dispose);
  ref.keepAlive();
  return session;
});

/// Releases a session and its connection.
///
/// Explicit rather than lifecycle-driven, because "the user closed this
/// session" is a user action, not a consequence of which screen is mounted.
void closeTelemetrySession(Ref ref, TelemetrySource source) =>
    ref.invalidate(telemetrySessionProvider(source));

/// Session metadata (§8.2) — the cheapest thing to depend on when a screen
/// needs the header facts but no telemetry.
final sessionMetadataProvider =
    FutureProvider.family<SessionMetadata, TelemetrySource>(
  (ref, source) async =>
      (await ref.watch(telemetrySessionProvider(source).future)).metadata,
);

final telemetryCatalogProvider =
    FutureProvider.family<TelemetryCatalog, TelemetrySource>(
  (ref, source) async =>
      (await ref.watch(telemetrySessionProvider(source).future)).catalog,
);

final lapRepositoryProvider =
    FutureProvider.family<LapRepository, TelemetrySource>((ref, source) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return LapRepository(session.database);
});

final telemetryRepositoryProvider =
    FutureProvider.family<TelemetryRepository, TelemetrySource>(
        (ref, source) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return TelemetryRepository(session.database, session.catalog);
});

/// Every lap in the session (§8.3).
///
/// Laps are read once and shared rather than re-queried per screen: the lap
/// table, the trace view's lap picker, the track map and the fuel view all
/// need the same list, and the query is small enough that caching it beats
/// coordinating who owns it.
final lapsProvider = FutureProvider.family<List<Lap>, TelemetrySource>(
  (ref, source) async =>
      (await ref.watch(lapRepositoryProvider(source).future)).readLaps(),
);
