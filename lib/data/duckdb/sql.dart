/// SQL construction helpers for dynamically-named tables (SPEC.md §5.5).
///
/// Every channel/event-derived table and column name is a human-readable
/// string that can contain spaces (`"Engine RPM"`, `"Track Temperature"`), so
/// identifiers are **always** double-quoted rather than interpolated bare.
/// `channelsList`/`eventsList` are the source of truth for which names are
/// valid, but they're read out of a file the app doesn't control, so quoting
/// escapes rather than trusts.
library;

/// Quotes an identifier for DuckDB, escaping any embedded double quote by
/// doubling it.
///
/// The escaping isn't ceremony. Table names here come from a file's own
/// catalog, and a name containing a `"` would otherwise terminate the quoted
/// identifier early and splice the rest into the statement — the local,
/// no-network version of an injection. §10 wants a malformed file to produce
/// a clear error rather than surprising behaviour, and silently generating
/// valid-but-different SQL is squarely the latter.
String quoteIdent(String identifier) {
  if (identifier.isEmpty) {
    throw ArgumentError.value(identifier, 'identifier', 'must not be empty');
  }
  return '"${identifier.replaceAll('"', '""')}"';
}

/// Quotes a string literal, escaping embedded single quotes.
String quoteLiteral(String value) => "'${value.replaceAll("'", "''")}'";

/// Formats a double for embedding in SQL.
///
/// Timestamps are compared against values read back out of the same file, so
/// the literal has to round-trip exactly — `toString()` on a Dart double is
/// shortest-round-trip and does, but an integral value renders as `23.0`,
/// which DuckDB would read as a DOUBLE anyway. Infinity/NaN are rejected
/// rather than emitted as identifiers DuckDB won't parse.
String sqlDouble(double value) {
  if (value.isNaN || value.isInfinite) {
    throw ArgumentError.value(value, 'value', 'not representable in SQL');
  }
  return value.toString();
}
