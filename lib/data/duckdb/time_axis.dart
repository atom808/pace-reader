/// Reconstructing the shared time axis (SPEC.md §5.2, §9.2).
///
/// Channel tables carry **no timestamp column** — row order is the sample
/// sequence — so elapsed time has to be reconstructed before any two signals
/// can be compared. This library owns that derivation and nothing else does:
/// feature code never needs to know a channel's native rate or that it lacks
/// a `ts`.
///
/// The derivation **reads** the clock rather than synthesizing it. Every
/// channel is a decimation of one shared 100 Hz master grid (§5.1), and
/// `GPS Time` is that grid carrying real elapsed seconds, so a channel
/// sample's timestamp is a master-grid *lookup*, not arithmetic on a declared
/// frequency. That survives all three measured failure modes at once: two
/// channels whose declared frequency is wrong by 0.25%, isolated recording
/// discontinuities a row-index clock cannot see, and the resulting
/// channel-vs-event divergence across a gap.
///
/// ## Correcting SPEC v0.6 §5.2 on *which* lookup
///
/// §5.2/§9.2 prescribe mapping channel row `i` to master row
/// `round(i * masterRows / rowCount)`. Right instinct, imprecise formula:
/// because `rowCount` is `ceil(masterRows * hz / 100)`, that ratio is
/// slightly *below* the true stride, so it compresses the axis. Measured
/// against the samples, the last sample of a 1 Hz channel lands **0.41–0.50 s
/// early** (`Track Temperature`, `Wind Speed`), and a 2 Hz channel
/// `Time Behind Next` — which §8.9's race-pace chart plots directly — lands
/// 0.32–0.41 s early.
///
/// The exact mapping is the integer stride `i * (100 / hz)`. §5.1's identity
/// `rowCount == ceil(masterRows * hz / 100)` is precisely the row count of
/// "keep every stride-th master row from row 0", so where that identity holds
/// the stride isn't an approximation of the decimation — it *is* the
/// decimation, inverted. Verified: mapped timestamps land on an exactly
/// 1/hz-spaced grid (zero deviation over the gapless Race sample), and the
/// only departures on the other two samples are precisely the known
/// recording discontinuities — which is the derivation working, since a
/// correct clock is supposed to see a gap.
///
/// The ratio formula survives as the fallback for exactly the channels that
/// need it: `Engine Oil Temp`/`Engine Water Temp` declare 7 Hz, 100/7 isn't
/// an integer, and no stride model exists for them. There the ratio is the
/// better of the two (~0.04 s worst, versus ~0.3 s for an endpoint-anchored
/// variant), because a wrong declared frequency is exactly what it corrects.
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';

/// Alias for the master-grid CTE this library emits, so query builders and
/// tests agree on one name.
const masterCteName = '_master';

/// The master-grid CTE: `GPS Time`'s value plus its 0-based row index.
///
/// `row_number() OVER ()` over an unfiltered scan is the authoritative sample
/// index (§5.2). DuckDB doesn't formally guarantee scan order, but these
/// files are written once by the game and never mutated, so insertion-order
/// scanning is safe in practice here.
String masterGridCte() =>
    '$masterCteName AS (SELECT ${quoteIdent('value')} AS t, '
    '(row_number() OVER ()) - 1 AS mi FROM ${quoteIdent(masterChannelName)})';

/// The SQL expression mapping a channel's 0-based row index to a master-grid
/// row index.
///
/// [rowIndexExpr] is the SQL expression holding the channel row index — a
/// column reference in practice, which is why this returns an expression
/// rather than a number: the mapping is applied per row inside a query.
String masterRowExpression(
  ChannelDescriptor channel,
  int masterRowCount, {
  String rowIndexExpr = 'i',
}) {
  if (channel.ridesMasterGrid(masterRowCount)) {
    // Exact: the channel is literally every stride-th master row.
    final stride = channel.masterStride;
    return stride == 1 ? rowIndexExpr : '($rowIndexExpr * $stride)';
  }
  // Off-grid fallback (§5.2's two 7 Hz channels): the declared frequency is
  // unusable, so scale by the measured row-count ratio instead. CAST after
  // round() because DuckDB's round() returns a DOUBLE, and a DOUBLE won't
  // match the BIGINT row index it's joined against.
  final ratio = masterRowCount / channel.rowCount;
  return 'CAST(round($rowIndexExpr * ${sqlDouble(ratio)}) AS BIGINT)';
}

/// Whether [channel] can be timed by exact stride, or needs the fallback.
/// Exposed so callers can report *which* derivation a session used (§9.6
/// wants the discontinuity count recorded at import for the same reason).
bool usesExactStride(ChannelDescriptor channel, int masterRowCount) =>
    channel.ridesMasterGrid(masterRowCount);

/// Full-resolution timestamped channel data.
///
/// Every row gets a real timestamp via a join against the master grid. Use
/// this for sparse or short-window reads — a lap of a 10 Hz channel, the
/// track-map path — and **never** for a whole multi-hour session: §9.5 is
/// explicit that no renderer should be handed a full-resolution multi-hour
/// trace, and at 100 Hz over 24 h this join is 8.7M rows. Decimated reads go
/// through `channel_queries.dart`, which aggregates *before* timestamping and
/// so only ever looks up one timestamp per bucket.
String timedChannelSql(
  ChannelDescriptor channel,
  int masterRowCount, {
  String? valueColumn,
  ({int start, int endExclusive})? rowRange,
}) {
  final columns = valueColumn == null ? channel.valueColumns : [valueColumn];
  final selected =
      columns.map((c) => 'c.${quoteIdent(c)} AS ${quoteIdent(c)}').join(', ');
  final projected = columns.map(quoteIdent).join(', ');
  final filter = rowRange == null
      ? ''
      : ' WHERE i >= ${rowRange.start} AND i < ${rowRange.endExclusive}';

  return 'WITH ${masterGridCte()}, '
      '_ch AS (SELECT $projected, (row_number() OVER ()) - 1 AS i '
      'FROM ${quoteIdent(channel.name)})'
      ' SELECT m.t AS t, $selected FROM (SELECT * FROM _ch$filter) c '
      'JOIN $masterCteName m '
      'ON m.mi = ${masterRowExpression(channel, masterRowCount, rowIndexExpr: 'c.i')} '
      'ORDER BY c.i';
}

/// Resolves a wall-clock window in elapsed seconds to a channel row range.
///
/// Done as a lookup against `GPS Time` rather than
/// `(t - origin) * frequency`, because the arithmetic version is blind to
/// recording discontinuities: after a gap it names the wrong rows, silently.
/// Returns one row, `(start, end_exclusive)`, either of which may be null
/// when the window falls entirely outside the recording.
String channelRowRangeSql(
  ChannelDescriptor channel,
  int masterRowCount, {
  required double startSeconds,
  required double endSeconds,
}) {
  final stride =
      channel.ridesMasterGrid(masterRowCount) ? channel.masterStride : null;
  // Master rows covered by the window, then converted to channel rows. With a
  // stride, a channel row exists only every `stride` master rows, so the
  // start rounds up and the end rounds down to stay inside the window.
  final startExpr = stride == null
      ? 'CAST(floor(m0 * ${sqlDouble(channel.rowCount / masterRowCount)}) AS BIGINT)'
      : 'CAST(ceil(m0 / $stride.0) AS BIGINT)';
  final endExpr = stride == null
      ? 'CAST(ceil(m1 * ${sqlDouble(channel.rowCount / masterRowCount)}) AS BIGINT)'
      : 'CAST(floor(m1 / $stride.0) AS BIGINT) + 1';

  return 'WITH ${masterGridCte()}, '
      '_b AS (SELECT MIN(mi) AS m0, MAX(mi) AS m1 FROM $masterCteName '
      'WHERE t >= ${sqlDouble(startSeconds)} AND t < ${sqlDouble(endSeconds)}) '
      'SELECT CASE WHEN m0 IS NULL THEN NULL ELSE greatest($startExpr, 0) END, '
      'CASE WHEN m1 IS NULL THEN NULL '
      'ELSE least($endExpr, ${channel.rowCount}) END FROM _b';
}
