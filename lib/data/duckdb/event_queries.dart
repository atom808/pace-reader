/// Event-table reads (SPEC.md §5.1, §8.4, §8.12).
///
/// Event tables are the other half of the schema from `channel_queries.dart`:
/// sparse, with an explicit `ts` in elapsed seconds, and **one row per
/// change** rather than per fixed interval. They are small enough to load in
/// full — single digits to low thousands of rows even over a full race — so
/// nothing here decimates (§9.5).
///
/// What they do need is an as-of reading. A signal that never changed inside
/// a window has *no row* inside it and a perfectly well-defined value
/// throughout, which is why every query here reaches backwards past the
/// window start.
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';

/// Every row of [event] in `[startSeconds, endSeconds)`, **plus the last row
/// at or before [startSeconds]**.
///
/// ## Why the preceding row is part of the query, not an afterthought
///
/// Events record changes, so "no rows in this window" is not "no value in
/// this window" — it is the *common* case. §5.1 measures 21–25 of the 42
/// event tables holding exactly one row for a whole session, and the effect
/// reaches ordinary signals too: in the checked-in fixture the `Gear` table
/// has 36–44 rows in each of laps 0–3 and **zero** in lap 4, because the
/// recording ends before the next shift. A window query without the
/// preceding row renders that lap as "no gear at all" rather than as the gear
/// the driver was actually holding.
///
/// The preceding row keeps its own `ts`, which is earlier than
/// [startSeconds]. Callers plotting a step signal clamp it to the window edge
/// rather than extending the axis backwards — see `StepSeries`.
String eventWindowSql(
  EventDescriptor event, {
  required double startSeconds,
  required double endSeconds,
  List<String>? columns,
}) {
  if (endSeconds <= startSeconds) {
    throw ArgumentError('empty window: $startSeconds..$endSeconds');
  }
  final cols = columns ?? event.valueColumns;
  if (cols.isEmpty) {
    throw ArgumentError.value(columns, 'columns', 'must not be empty');
  }

  final table = quoteIdent(event.name);
  final projected = cols.map(quoteIdent).join(', ');
  final start = sqlDouble(startSeconds);
  final end = sqlDouble(endSeconds);

  // Wrapped in an outer SELECT so the ORDER BY unambiguously applies to the
  // union rather than to its last branch.
  return 'SELECT * FROM ('
      'SELECT ts, $projected FROM $table WHERE ts >= $start AND ts < $end '
      'UNION ALL '
      'SELECT * FROM (SELECT ts, $projected FROM $table WHERE ts < $start '
      'ORDER BY ts DESC LIMIT 1)'
      ') ORDER BY ts';
}

/// Every recorded change of [event] in `[startSeconds, endSeconds)`, in order.
///
/// The deliberate contrast with [eventWindowSql] is the **absence** of the
/// reach-back row. That query answers "what was this signal during the
/// window", so the last change before it is part of the answer. This one
/// answers "what changed during the window" — §8.12's log — and a change that
/// happened before the window did not happen in it. Including it would put a
/// row in the log at a timestamp outside the range the user asked for, which
/// in a table sorted by time reads as a bug rather than as context.
///
/// [limit] is a truncation guard, not a page size: event tables are small in
/// the samples measured (§5.1 — 4.3k–20.3k rows across all 42 for a full
/// session) but scale with session length, and §5.5's 24 h extrapolation puts
/// the busiest of them into six figures on its own. Callers ask for one more
/// row than they intend to show so they can tell a full result from a
/// truncated one and say so, rather than silently presenting a prefix as the
/// whole.
String eventLogSql(
  EventDescriptor event, {
  double? startSeconds,
  double? endSeconds,
  List<String>? columns,
  int? limit,
}) {
  if (startSeconds != null &&
      endSeconds != null &&
      endSeconds <= startSeconds) {
    throw ArgumentError('empty window: $startSeconds..$endSeconds');
  }
  if (limit != null && limit <= 0) {
    throw ArgumentError.value(limit, 'limit', 'must be positive');
  }
  final cols = columns ?? event.valueColumns;
  if (cols.isEmpty) {
    throw ArgumentError.value(columns, 'columns', 'must not be empty');
  }

  final projected = cols.map(quoteIdent).join(', ');
  final where = [
    if (startSeconds != null) 'ts >= ${sqlDouble(startSeconds)}',
    if (endSeconds != null) 'ts < ${sqlDouble(endSeconds)}',
  ];
  return 'SELECT ts, $projected FROM ${quoteIdent(event.name)}'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
      ' ORDER BY ts'
      '${limit == null ? '' : ' LIMIT $limit'}';
}
