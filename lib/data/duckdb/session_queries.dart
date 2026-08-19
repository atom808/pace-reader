/// Metadata, catalog discovery, and clock-integrity queries (SPEC.md §5.1,
/// §5.2, §9.2, §9.6).
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';

/// Tables every LMU telemetry file must have (§5.1). Their absence means the
/// file isn't telemetry at all, which §10 wants reported as a clear error
/// rather than discovered as a failed query later.
const requiredCatalogTables = ['metadata', 'channelsList', 'eventsList'];

/// Format versions this build understands (§5.1). All three samples are `"1"`.
const supportedFormatVersions = ['1'];

String metadataSql() =>
    'SELECT key, ${quoteIdent('value')} FROM metadata';

/// Table names actually present in the file, for validating the catalog
/// against reality before trusting it.
String tableNamesSql() =>
    "SELECT table_name FROM information_schema.tables WHERE table_schema = 'main'";

/// `(table_name, column_count)` for every table, in one round trip.
///
/// Channel/event tables are `value` or `value1..value4` (§5.1), and which one
/// is read from the table rather than guessed from the name — a per-corner
/// channel isn't identifiable from its name alone (`RideHeights` is
/// per-corner, `FrontRideHeight` isn't).
String valueColumnCountsSql() =>
    'SELECT table_name, COUNT(*) FROM information_schema.columns '
    "WHERE table_schema = 'main' AND column_name LIKE 'value%' "
    'GROUP BY table_name';

String channelCatalogSql() =>
    'SELECT channelName, frequency, unit FROM channelsList ORDER BY channelName';

String eventCatalogSql() =>
    'SELECT eventName, unit FROM eventsList ORDER BY eventName';

/// Row counts for many tables in a single statement.
///
/// One `COUNT(*)` per table would be ~98 round trips at open time (§5.1 —
/// every catalog entry names a table). Row count is not incidental here: it's
/// an input to the time-axis derivation for every channel, so it has to be
/// read for all of them, not lazily per chart.
String rowCountsSql(Iterable<String> tableNames) {
  final names = tableNames.toList();
  if (names.isEmpty) {
    throw ArgumentError.value(tableNames, 'tableNames', 'must not be empty');
  }
  return names
      .map((n) =>
          'SELECT ${quoteLiteral(n)} AS t, COUNT(*) AS n FROM ${quoteIdent(n)}')
      .join(' UNION ALL ');
}

/// The file's own t=0 and the master grid's length.
///
/// `origin` is `GPS Time`'s first value, which §5.2 confirms equals `MIN(ts)`
/// of all 42 event tables to the bit — so the file states its own origin
/// unambiguously, and it is read rather than assumed. Measured across the
/// samples at 381.09 / 34.57 / 23.60 s, a spread wide enough that a
/// hardcoded value or a plausibility range would both be wrong.
String masterClockSql() => 'SELECT '
    '(SELECT ${quoteIdent('value')} FROM ${quoteIdent(masterChannelName)} LIMIT 1), '
    '(SELECT COUNT(*) FROM ${quoteIdent(masterChannelName)})';

/// Recording discontinuities in the master clock (§5.2, §9.6).
///
/// `GPS Time` advances by exactly 1/100 s per row except across a gap. A
/// row-index clock cannot see a gap, so every sample after one is
/// permanently offset — silently, with no error. §9.6 wants the count
/// recorded at import so a session whose timing needs the mapped derivation
/// is flagged rather than quietly trusted.
///
/// Returns `(row_index, delta_seconds)` per gap. Measured: one ~0.39 s gap in
/// the Practice sample, one ~0.38 s in Qualify, none in Race — and in both
/// cases *after* the last lap boundary, which is luck about where the
/// recording stopped rather than a property to rely on.
String discontinuityScanSql({double toleranceSeconds = 1e-9}) {
  const step = 1.0 / masterFrequencyHz;
  return 'WITH _g AS (SELECT ${quoteIdent('value')} AS v, '
      'row_number() OVER () AS i FROM ${quoteIdent(masterChannelName)}), '
      '_d AS (SELECT i, v - lag(v) OVER (ORDER BY i) AS dt FROM _g) '
      'SELECT i, dt FROM _d '
      'WHERE dt IS NOT NULL AND abs(dt - $step) > ${sqlDouble(toleranceSeconds)} '
      'ORDER BY i';
}

/// A single value out of the embedded `CarSetup` JSON (§5.1, §8.10).
///
/// Setup entries are objects with a `stringValue` field (e.g.
/// `WM_PRESSURE-W_FL` → `"136 kPa"`), across 172 top-level keys — so the
/// Setup Viewer needs no parsing infrastructure beyond `json_extract` on this
/// one column.
///
/// This is also the answer key for §15.4's open FL/FR/RL/RR question: the
/// setup names corners explicitly where `value1..value4` don't, so one file
/// with a left/right-asymmetric setup resolves the ordering by
/// cross-reference. All 15 per-corner groups are symmetric in all three
/// samples on hand (FL and FR pressures are identical), so that still needs a
/// deliberately asymmetric test setup rather than more waiting.
String carSetupValueSql(String key) {
  final path = quoteLiteral('\$.${key.replaceAll(r'$', r'\$')}.stringValue');
  return 'SELECT json_extract_string(${quoteIdent('value')}, $path) '
      "FROM metadata WHERE key = 'CarSetup'";
}

/// Every top-level key in the `CarSetup` blob, for driving the Setup Viewer
/// off the data rather than a hardcoded field list.
String carSetupKeysSql() =>
    'SELECT unnest(json_keys(${quoteIdent('value')})) '
    "FROM metadata WHERE key = 'CarSetup'";
