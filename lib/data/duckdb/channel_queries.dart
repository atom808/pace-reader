/// Decimated channel reads (SPEC.md §9.5).
///
/// A 6-hour stint puts one 100 Hz channel near 2.16M rows and there are 20
/// channels at 100 Hz, so no renderer is ever handed a full-resolution
/// multi-hour trace. DuckDB does the reduction; Dart receives roughly one
/// point per pixel column.
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';
import 'time_axis.dart';

/// Min/max-per-bucket decimation over a channel row range.
///
/// ## Why min/max rather than sampling
///
/// Picking one sample per pixel column drops the extremes, and on telemetry
/// the extremes are the signal the user came for — a brake spike, a rev
/// limiter hit, a kerb strike. Each bucket therefore keeps both bounds, and
/// the painter draws the vertical extent it actually covers.
///
/// ## Why aggregate before timestamping
///
/// Timestamps come from a join against the master grid (§5.2), and joining
/// per *sample* would mean 8.7M joined rows on a 24-hour file. Bucketing is
/// pure row-index arithmetic and needs no timestamps at all, so the
/// aggregation runs first and only the ~1200 bucket representatives are
/// looked up — turning the join from session-sized into viewport-sized.
/// Measured: ~4 ms over a real 22-minute session, ~42 ms over a synthetic
/// 6-hour one, ~156 ms over a synthetic 24-hour one, ~24 ms for a zoomed
/// window of that same 24-hour table.
///
/// Returns `bucket, t, lo_0, hi_0, [lo_1, hi_1, ...]` — one lo/hi pair per
/// entry in [columns], in order, so a per-corner channel costs one scan
/// instead of four.
String decimateSql(
  ChannelDescriptor channel,
  int masterRowCount, {
  required int rowStart,
  required int rowEndExclusive,
  required int buckets,
  List<String>? columns,
}) {
  final cols = columns ?? channel.valueColumns;
  if (cols.isEmpty) {
    throw ArgumentError.value(columns, 'columns', 'must not be empty');
  }
  final span = rowEndExclusive - rowStart;
  if (span <= 0) {
    throw ArgumentError('empty row range: $rowStart..$rowEndExclusive');
  }
  if (buckets <= 0) {
    throw ArgumentError.value(buckets, 'buckets', 'must be positive');
  }

  final projected = cols.map(quoteIdent).join(', ');
  final aggregates = [
    for (var n = 0; n < cols.length; n++)
      'MIN(${quoteIdent(cols[n])}) AS lo_$n, MAX(${quoteIdent(cols[n])}) AS hi_$n',
  ].join(', ');
  final selected = [
    for (var n = 0; n < cols.length; n++) 'a.lo_$n, a.hi_$n',
  ].join(', ');

  // floor(), not a bare CAST: DuckDB's CAST from DOUBLE rounds half away from
  // zero, which would let the final row land in bucket `buckets` and yield
  // buckets + 1 groups. floor() keeps the index in 0..buckets-1.
  final bucketExpr =
      'CAST(floor((i - $rowStart) * $buckets.0 / $span.0) AS BIGINT)';

  return 'WITH ${masterGridCte()}, '
      '_ch AS (SELECT $projected, (row_number() OVER ()) - 1 AS i '
      'FROM ${quoteIdent(channel.name)}), '
      '_win AS (SELECT * FROM _ch WHERE i >= $rowStart AND i < $rowEndExclusive), '
      '_agg AS (SELECT $bucketExpr AS bucket, MIN(i) AS i0, $aggregates '
      'FROM _win GROUP BY bucket) '
      'SELECT a.bucket, m.t, $selected '
      'FROM _agg a JOIN $masterCteName m '
      'ON m.mi = ${masterRowExpression(channel, masterRowCount, rowIndexExpr: 'a.i0')} '
      'ORDER BY a.bucket';
}

/// Whether a channel holds a single distinct value across the session.
///
/// §5.4/§8.7 require this guard: `SoC` and `Regen Rate` are present in every
/// file but all-zero in GT3 ones, and a flat zero line labelled "State of
/// Charge" reads as data rather than as absence. Branch on
/// `metadata.CarClass` for *what to offer*, and on this for *what to draw* —
/// table presence proves nothing, since all three samples carry all three
/// energy tables.
String isDegenerateSql(ChannelDescriptor channel, {String? valueColumn}) {
  final column = valueColumn ?? channel.valueColumns.first;
  return 'SELECT COUNT(DISTINCT ${quoteIdent(column)}) <= 1 '
      'FROM ${quoteIdent(channel.name)}';
}

/// An event's value as of each of a channel's samples (SPEC.md §5.2, §9.2).
///
/// Uses `ASOF LEFT JOIN` — **left**, deliberately. A plain `ASOF JOIN` is
/// inner and silently *drops* samples with no match rather than surfacing
/// them, which is precisely how the Phase 0 spike shipped a clock 23.6 s out
/// of alignment and still passed: the unmatched prefix vanished and the
/// surviving rows held plausible gear numbers. With `LEFT`, an unresolvable
/// sample arrives as null — visible, not cosmetic.
String eventAsOfChannelSql(
  ChannelDescriptor channel,
  int masterRowCount, {
  required EventDescriptor event,
  String? channelColumn,
  String? eventColumn,
  ({int start, int endExclusive})? rowRange,
}) {
  final chCol = channelColumn ?? channel.valueColumns.first;
  final evCol = eventColumn ?? event.valueColumns.first;
  final filter = rowRange == null
      ? ''
      : ' WHERE i >= ${rowRange.start} AND i < ${rowRange.endExclusive}';

  return 'WITH ${masterGridCte()}, '
      '_ch AS (SELECT ${quoteIdent(chCol)}, (row_number() OVER ()) - 1 AS i '
      'FROM ${quoteIdent(channel.name)}), '
      '_timed AS (SELECT m.t AS t, c.${quoteIdent(chCol)} AS v '
      'FROM (SELECT * FROM _ch$filter) c JOIN $masterCteName m '
      'ON m.mi = ${masterRowExpression(channel, masterRowCount, rowIndexExpr: 'c.i')}) '
      'SELECT _timed.t, _timed.v, e.${quoteIdent(evCol)} AS event_value '
      'FROM _timed ASOF LEFT JOIN ${quoteIdent(event.name)} e ON e.ts <= _timed.t '
      'ORDER BY _timed.t';
}
