/// Queries for what a recording says about its course (comparison proposal
/// §4): the length of a lap, where the sector lines sit, the pit lane.
///
/// Whole-recording reads, unlike every lap read, because these are facts of
/// the file. Each returns a handful of rows however long the recording is:
/// the aggregation happens in DuckDB.
library;

import '../models/telemetry_catalog.dart';
import 'lap_queries.dart';
import 'sql.dart';
import 'time_axis.dart';

const lapDistanceChannel = 'Lap Dist';
const totalDistanceChannel = 'Total Dist';
const inPitsEventTable = 'In Pits';

/// `(median wrap length, wrap count)` over every `Lap Dist` wrap.
///
/// A wrap is a sample where `Lap Dist` drops by more than half the longest
/// distance the file reached — so the small backwards steps a car makes
/// manoeuvring in the pits never count — while `Total Dist` moves forwards
/// by less than 100 m. That second condition drops the garage teleport at
/// a recording's start, where `Lap Dist` resets to zero and `Total Dist`
/// does too: the user's library shows it as a −2978 m "wrap" on the Race
/// sample.
///
/// The two channels are paired by row, so they must share a rate; the
/// caller checks that against the catalog.
String wrapLengthSql() {
  final value = quoteIdent('value');
  return 'WITH _ld AS (SELECT $value AS ld, row_number() OVER () AS i '
      'FROM ${quoteIdent(lapDistanceChannel)}), '
      '_td AS (SELECT $value AS td, row_number() OVER () AS i '
      'FROM ${quoteIdent(totalDistanceChannel)}), '
      '_j AS (SELECT i, ld, td FROM _ld JOIN _td USING (i)), '
      '_w AS (SELECT ld, td, lag(ld) OVER (ORDER BY i) AS ld0, '
      'lag(td) OVER (ORDER BY i) AS td0 FROM _j) '
      'SELECT median(ld0 + (td - td0) - ld), count(*) FROM _w '
      'WHERE ld0 - ld > 0.5 * (SELECT max(ld) FROM _j) '
      'AND td - td0 >= 0 AND td - td0 < 100';
}

/// `(sector code, ts, Lap Dist at ts)` for every crossing of the S1 and S2
/// lines.
///
/// `Lap Dist` is interpolated linearly between the samples either side of
/// the `Current Sector` event, which is how probe 0a measured the stations.
/// A pair of samples that straddles a jump — more than 0.25 s apart, running
/// backwards, or 100 m apart — has no honest value in between and is
/// skipped.
String sectorCrossingsSql(ChannelDescriptor lapDistance, int masterRowCount) {
  final value = quoteIdent('value');
  final masterRow = masterRowExpression(
    lapDistance,
    masterRowCount,
    rowIndexExpr: '_ld.i',
  );
  return 'WITH ${masterGridCte()}, '
      '_ld AS (SELECT $value AS ld, (row_number() OVER ()) - 1 AS i '
      'FROM ${quoteIdent(lapDistanceChannel)}), '
      '_s AS (SELECT m.t AS t, _ld.ld AS ld FROM _ld '
      'JOIN $masterCteName m ON m.mi = $masterRow), '
      '_cs AS (SELECT ts, $value AS code '
      'FROM ${quoteIdent(currentSectorEventTable)} WHERE $value IN (2, 0)), '
      '_a AS (SELECT _cs.ts, _cs.code, _s.t AS t0, _s.ld AS ld0 '
      'FROM _cs ASOF JOIN _s ON _s.t <= _cs.ts), '
      '_b AS (SELECT _a.ts, _a.code, _a.t0, _a.ld0, _s.t AS t1, _s.ld AS ld1 '
      'FROM _a ASOF JOIN _s ON _s.t > _a.ts) '
      'SELECT code, ts, ld0 + (ld1 - ld0) * (ts - t0) / (t1 - t0) FROM _b '
      'WHERE t1 - t0 <= 0.25 AND ld1 >= ld0 AND ld1 - ld0 < 100 '
      'ORDER BY ts';
}

/// `(ts, in pits)` rows, in time order.
String inPitsSql() =>
    'SELECT ts, ${quoteIdent('value')} FROM ${quoteIdent(inPitsEventTable)} '
    'ORDER BY ts';
