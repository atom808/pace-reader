/// Session-level reads: metadata, catalog discovery, clock integrity
/// (SPEC.md §5.1, §5.2, §9.2, §9.6).
library;

import '../../core/errors.dart';
import '../duckdb/session_queries.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';

/// Reads that describe a session as a whole.
///
/// Takes a [TelemetryQueryExecutor] rather than a connection so it can be
/// exercised in a plain `flutter test` against a fake — `dart_duckdb`'s native
/// library only links into a compiled app, so a unit test can't hold a real
/// connection (see [TelemetryQueryExecutor]).
class SessionRepository {
  SessionRepository(this._exec);

  final TelemetryQueryExecutor _exec;

  /// Fails clearly when the file isn't LMU telemetry (§10).
  ///
  /// Runs before anything reads `metadata`, so "this isn't a telemetry file"
  /// is distinguishable from "this telemetry file is a version we don't
  /// understand" — a UI that can't tell those apart has to hedge on both.
  Future<void> validateSchema() async {
    final present = {
      for (final row in await _exec.rows(tableNamesSql())) row[0] as String,
    };
    final missing =
        requiredCatalogTables.where((t) => !present.contains(t)).toList();
    if (missing.isNotEmpty) {
      throw NotTelemetryFileException(
        "This doesn't look like a Le Mans Ultimate telemetry file — it's "
        'missing ${missing.join(', ')}.',
        missingTables: missing,
      );
    }
  }

  /// Reads and validates `metadata` (§5.1).
  ///
  /// The `Version` gate is here rather than deeper in because it's the
  /// earliest and cheapest point to fail clearly: an unrecognized format
  /// otherwise surfaces much later as a missing table or a wrongly-shaped
  /// column, where the real cause is no longer obvious.
  Future<SessionMetadata> readMetadata() async {
    final raw = {
      for (final row in await _exec.rows(metadataSql()))
        row[0] as String: row[1] as String? ?? '',
    };

    final version = raw['Version'];
    if (version == null) {
      throw const SchemaMismatchException(
        'This telemetry file has no format version and cannot be read safely.',
        detail: 'metadata.Version missing',
      );
    }
    if (!supportedFormatVersions.contains(version)) {
      throw UnsupportedFormatVersionException(
        'This file was recorded by a newer or older version of Le Mans '
        "Ultimate than this build understands (format $version, expected "
        '${supportedFormatVersions.join('/')}).',
        found: version,
        supported: supportedFormatVersions,
      );
    }

    final rawSessionType = raw['SessionType'] ?? '';
    final sessionType = SessionType.tryParse(rawSessionType);
    if (sessionType == null) {
      throw SchemaMismatchException(
        'Unrecognized session type "$rawSessionType".',
        detail: 'metadata.SessionType not one of '
            '${SessionType.values.map((t) => t.rawValue).join('/')}',
      );
    }

    return SessionMetadata(
      driverName: raw['DriverName'] ?? '',
      steamId: raw['SteamID'] ?? '',
      recordingTime: raw['RecordingTime'] ?? '',
      sessionTimeOfDay: raw['SessionTime'] ?? '',
      sessionType: sessionType,
      trackName: raw['TrackName'] ?? '',
      trackLayout: raw['TrackLayout'] ?? '',
      weatherConditions: raw['WeatherConditions'] ?? '',
      carName: raw['CarName'] ?? '',
      carClass: raw['CarClass'] ?? '',
      carSetupJson: raw['CarSetup'] ?? '',
      version: version,
    );
  }

  /// Reads `channelsList`/`eventsList` and everything derived from them.
  ///
  /// Catalog-driven rather than hardcoded (§9.2), so a future LMU version can
  /// add or remove signals without an app change. Row counts and value-column
  /// counts are read for *all* tables up front rather than lazily per chart,
  /// because both are inputs to the time-axis derivation and so are needed for
  /// any channel the moment it's plotted — and batching them costs two queries
  /// instead of ~200 round trips.
  Future<TelemetryCatalog> readCatalog() async {
    final clock = await _exec.firstRow(masterClockSql());
    if (clock == null || clock[0] == null) {
      throw const SchemaMismatchException(
        'This telemetry file has no master clock and cannot be time-aligned.',
        detail: '$masterChannelName missing or empty',
      );
    }
    final origin = (clock[0] as num).toDouble();
    final masterRowCount = (clock[1] as num).toInt();
    final endSeconds = (clock[2] as num?)?.toDouble() ?? origin;

    final channelRows = await _exec.rows(channelCatalogSql());
    final eventRows = await _exec.rows(eventCatalogSql());
    final names = [
      ...channelRows.map((r) => r[0] as String),
      ...eventRows.map((r) => r[0] as String),
    ];
    if (names.isEmpty) {
      throw const SchemaMismatchException(
        'This telemetry file lists no channels or events.',
        detail: 'channelsList and eventsList are both empty',
      );
    }

    final valueColumns = {
      for (final row in await _exec.rows(valueColumnCountsSql()))
        row[0] as String: (row[1] as num).toInt(),
    };
    final rowCounts = {
      for (final row in await _exec.rows(rowCountsSql(names)))
        row[0] as String: (row[1] as num).toInt(),
    };

    // A catalog entry naming a table the file doesn't contain is the one
    // schema change catalog-driven discovery can't absorb (§10): additive
    // changes are free, a rename or removal is not.
    final dangling = names.where((n) => !rowCounts.containsKey(n)).toList();
    if (dangling.isNotEmpty) {
      throw SchemaMismatchException(
        'This telemetry file lists signals it does not contain '
        '(${dangling.take(3).join(', ')}${dangling.length > 3 ? '…' : ''}).',
        detail: 'catalog entries without tables: ${dangling.join(', ')}',
      );
    }

    return TelemetryCatalog(
      origin: origin,
      endSeconds: endSeconds,
      masterRowCount: masterRowCount,
      channels: [
        for (final row in channelRows)
          ChannelDescriptor(
            name: row[0] as String,
            frequencyHz: (row[1] as num).toInt(),
            unit: row[2] as String? ?? '',
            valueColumnCount: valueColumns[row[0] as String] ?? 1,
            rowCount: rowCounts[row[0] as String]!,
          ),
      ],
      events: [
        for (final row in eventRows)
          EventDescriptor(
            name: row[0] as String,
            unit: row[1] as String? ?? '',
            valueColumnCount: valueColumns[row[0] as String] ?? 1,
            rowCount: rowCounts[row[0] as String]!,
          ),
      ],
    );
  }

  /// Scans the master clock for recording discontinuities (§5.2, §9.6).
  Future<List<ClockGap>> readClockGaps() async => [
        for (final row in await _exec.rows(discontinuityScanSql()))
          ClockGap(
            masterRowIndex: (row[0] as num).toInt(),
            deltaSeconds: (row[1] as num).toDouble(),
          ),
      ];
}

/// One open telemetry file, plus everything read once at open time.
///
/// Metadata, catalog and clock gaps are read eagerly because every feature
/// needs them and none of them can be derived later without re-reading the
/// file — §9.6 makes the same point about the local index: the file is
/// already open, so this is the cheap moment.
class TelemetrySession {
  TelemetrySession({
    required this.database,
    required this.metadata,
    required this.catalog,
    required this.clockGaps,
  });

  final TelemetryDatabase database;
  final SessionMetadata metadata;
  final TelemetryCatalog catalog;

  /// Empty for a clean recording. Non-empty means any timing after the first
  /// gap depends on the master-clock derivation being correct, so it's worth
  /// surfacing rather than absorbing (§15.11).
  final List<ClockGap> clockGaps;

  bool get hasClockGaps => clockGaps.isNotEmpty;

  Future<void> dispose() => database.dispose();
}

/// Opens a telemetry file and reads its session-level facts.
///
/// The single factory §9.2 calls for: the desktop-path/web-bytes asymmetry is
/// resolved inside [TelemetrySource]/[TelemetryDatabase.open] and nothing
/// downstream of here knows which platform it's on.
Future<TelemetrySession> openTelemetrySession(TelemetrySource source) async {
  final database = await TelemetryDatabase.open(source);
  try {
    final repository = SessionRepository(database);
    await repository.validateSchema();
    final metadata = await repository.readMetadata();
    final catalog = await repository.readCatalog();
    final clockGaps = await repository.readClockGaps();
    return TelemetrySession(
      database: database,
      metadata: metadata,
      catalog: catalog,
      clockGaps: clockGaps,
    );
  } on Object {
    // A file that opened but failed validation still holds a connection.
    await database.dispose();
    rethrow;
  }
}
