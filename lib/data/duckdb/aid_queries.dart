/// Reads for the trace's driver-aid overlays (driver-aids proposal §3).
library;

import '../models/driver_aids.dart';
import '../models/telemetry_catalog.dart';
import 'sql.dart';
import 'time_axis.dart';

/// [channel]'s value changes over its rows `[rowStart, rowEndExclusive)`, as
/// `(t, value)` in order, the range's first row included.
///
/// How an on/off signal recorded as a channel — `TC` in a newer build
/// (SPEC.md §5.1) — becomes the edges an event would have written. The
/// changes are found in row order and only the survivors are timestamped
/// through the master grid (`aidEpisodesSql`'s rule, §9.5): a lap of a
/// 100 Hz channel is some 10,000 rows and a few hundred changes. The first
/// row stands in for the event's reach-back row, the value in force when the
/// range opens.
String channelEdgesSql(
  ChannelDescriptor channel,
  int masterRowCount, {
  required int rowStart,
  required int rowEndExclusive,
}) {
  if (rowEndExclusive <= rowStart) {
    throw ArgumentError('empty row range: $rowStart..$rowEndExclusive');
  }
  final value = quoteIdent('value');
  return 'WITH ${masterGridCte()}, '
      '_c AS (SELECT r, v FROM (SELECT row_number() OVER () - 1 AS r, '
      '$value AS v FROM ${quoteIdent(channel.name)}) '
      'WHERE r >= $rowStart AND r < $rowEndExclusive), '
      '_x AS (SELECT r, v FROM (SELECT r, v, lag(v) OVER (ORDER BY r) AS pv '
      'FROM _c) WHERE pv IS DISTINCT FROM v) '
      'SELECT m.t AS t, x.v AS v FROM _x x JOIN $masterCteName m ON m.mi = '
      '${masterRowExpression(channel, masterRowCount, rowIndexExpr: 'x.r')} '
      'ORDER BY x.r';
}

/// Each stretch of `Wheel Speed` rows `[rowStart, rowEndExclusive)` where a
/// wheel turned well below the car's speed under braking:
/// `(t0, t1, at, corner, ratio, km/h)`, in order.
///
/// - A row counts with the brake above [minBrake] %, the car above
///   [minSpeedKmh], and any wheel under [maxRatio] of `Ground Speed`
///   (`Wheel Speed` is m/s, `Ground Speed` km/h).
/// - Rows less than [joinRows] master rows apart are one stretch, so a lock
///   that moves from one wheel to another is one; a stretch needs
///   [minRows] rows.
/// - `corner` is the worst wheel's index (FL, FR, RL, RR) and `ratio` its
///   lowest speed against the car's, read at `at`, with the car's speed there.
///
/// The rows are joined by master-grid arithmetic and reduced in DuckDB; only
/// the stretches are timestamped (§9.5). All three channels must ride the
/// master grid.
String lockupsSql({
  required ChannelDescriptor wheels,
  required ChannelDescriptor speed,
  required ChannelDescriptor brake,
  required int rowStart,
  required int rowEndExclusive,
  double maxRatio = wheelLockRatio,
  double minBrake = wheelLockMinBrake,
  double minSpeedKmh = wheelLockMinSpeedKmh,
  int minRows = wheelLockMinRows,
  int joinRows = 10,
}) {
  if (rowEndExclusive <= rowStart) {
    throw ArgumentError('empty row range: $rowStart..$rowEndExclusive');
  }
  final value = quoteIdent('value');
  final mi = 'w.r * ${wheels.masterStride}';
  String rowOf(ChannelDescriptor c) =>
      c.masterStride == 1 ? mi : '($mi) // ${c.masterStride}';
  String ratio(String column) => 'abs(w.$column) * 3.6 / g.v';
  return 'WITH ${masterGridCte()}, '
      '_w AS (SELECT r, a, b, c, d FROM (SELECT row_number() OVER () - 1 AS r, '
      '${quoteIdent('value1')} AS a, ${quoteIdent('value2')} AS b, '
      '${quoteIdent('value3')} AS c, ${quoteIdent('value4')} AS d '
      'FROM ${quoteIdent(wheels.name)}) '
      'WHERE r >= $rowStart AND r < $rowEndExclusive), '
      '_g AS (SELECT row_number() OVER () - 1 AS r, $value AS v '
      'FROM ${quoteIdent(speed.name)}), '
      '_bp AS (SELECT row_number() OVER () - 1 AS r, $value AS p '
      'FROM ${quoteIdent(brake.name)}), '
      '_f AS (SELECT $mi AS mi, g.v, ${ratio('a')} AS fl, ${ratio('b')} AS fr, '
      '${ratio('c')} AS rl, ${ratio('d')} AS rr FROM _w w '
      'JOIN _g g ON g.r = ${rowOf(speed)} '
      'JOIN _bp p ON p.r = ${rowOf(brake)} '
      'WHERE g.v > ${sqlDouble(minSpeedKmh)} AND p.p > ${sqlDouble(minBrake)}), '
      '_l AS (SELECT mi, v, least(fl, fr, rl, rr) AS q, '
      'CASE WHEN fl <= least(fr, rl, rr) THEN 0 WHEN fr <= least(rl, rr) '
      'THEN 1 WHEN rl <= rr THEN 2 ELSE 3 END AS k FROM _f '
      'WHERE least(fl, fr, rl, rr) < ${sqlDouble(maxRatio)}), '
      '_n0 AS (SELECT *, CASE WHEN mi - lag(mi) OVER (ORDER BY mi) <= '
      '$joinRows THEN 0 ELSE 1 END AS fresh FROM _l), '
      '_n AS (SELECT *, sum(fresh) OVER (ORDER BY mi ROWS UNBOUNDED PRECEDING) '
      'AS grp FROM _n0), '
      '_e AS (SELECT min(mi) AS m0, max(mi) AS m1, arg_min(mi, q) AS mq, '
      'arg_min(k, q) AS k, min(q) AS q, arg_min(v, q) AS v FROM _n '
      'GROUP BY grp HAVING count(*) >= $minRows) '
      'SELECT a.t, b.t, c.t, e.k, e.q, e.v FROM _e e '
      'JOIN $masterCteName a ON a.mi = e.m0 '
      'JOIN $masterCteName b ON b.mi = e.m1 '
      'JOIN $masterCteName c ON c.mi = e.mq ORDER BY e.m0';
}
