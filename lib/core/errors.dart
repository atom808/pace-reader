/// Error types for the telemetry data layer (SPEC.md §10 — "a malformed/
/// unexpected schema in a `.duckdb` file should produce a clear error, not a
/// crash").
///
/// Every failure a user can actually hit while opening a game-exported file
/// has its own type here, because the useful distinction isn't
/// "recoverable/not" — it's *what to tell the user*. "Recorded by a newer
/// LMU than this build understands" and "this file isn't LMU telemetry at
/// all" both surface as a failed import, but the first is a version problem
/// and the second is a wrong-file problem, and a UI that can't tell them
/// apart has to hedge on both.
library;

/// Base type for anything the data layer throws deliberately.
sealed class TelemetryException implements Exception {
  const TelemetryException(this.message, {this.cause});

  /// Phrased for a user, not a log: this is what the error surface shows.
  final String message;

  /// The underlying error, when this wraps one. Kept for logs/bug reports.
  final Object? cause;

  @override
  String toString() =>
      cause == null ? '$runtimeType: $message' : '$runtimeType: $message (cause: $cause)';
}

/// The file could not be opened at all — missing, locked, not a DuckDB
/// database, or (on macOS) blocked by App Sandbox. §13/§15 confirmed a
/// sandboxed macOS build cannot open an arbitrary path, which surfaces here.
final class SessionOpenException extends TelemetryException {
  const SessionOpenException(super.message, {required this.source, super.cause});

  /// The path (desktop) or registered buffer name (web) that failed.
  final String source;
}

/// The file opened as a DuckDB database but isn't LMU telemetry — the
/// `metadata`/`channelsList`/`eventsList` tables §5.1 requires aren't there.
final class NotTelemetryFileException extends TelemetryException {
  const NotTelemetryFileException(super.message, {required this.missingTables, super.cause});

  final List<String> missingTables;
}

/// `metadata.Version` isn't a format this build understands (§5.1). Gated at
/// open time on purpose: it's the earliest and cheapest point to fail
/// clearly, rather than discovering the mismatch later as a missing table or
/// a wrongly-shaped column.
final class UnsupportedFormatVersionException extends TelemetryException {
  const UnsupportedFormatVersionException(
    super.message, {
    required this.found,
    required this.supported,
  });

  /// The raw `Version` value read from the file. Deliberately a string, not
  /// an int — §5.1 confirms the format only as `"1"`, and a future LMU could
  /// write something that isn't an integer at all.
  final String found;
  final List<String> supported;
}

/// A catalog entry names a table (or a column) the file doesn't actually
/// contain. Catalog-driven discovery (§9.2) absorbs *additive* schema
/// changes for free; this is the other direction — a renamed or removed
/// entry — which §10 requires degrade to a clear error rather than a crash.
final class SchemaMismatchException extends TelemetryException {
  const SchemaMismatchException(super.message, {required this.detail, super.cause});

  final String detail;
}

/// A query failed against a file that opened and validated fine. Almost
/// always a bug in this layer rather than a bad file, so it carries the SQL.
final class TelemetryQueryException extends TelemetryException {
  const TelemetryQueryException(super.message, {required this.sql, super.cause});

  final String sql;
}
