/// Where the track's edges are (map stage proposal §3.4, P0.1), read inside
/// DuckDB so a 22-minute recording returns a few thousand stations, never
/// its samples.
///
/// `Lap Dist`, `Path Lateral` and `Track Edge` are row-aligned 10 Hz
/// channels, joined positionally; the caller checks they share a rate.
/// `Track Edge` is the edge on the car's own side, signed like `Path
/// Lateral` (+ right): a recording knows one edge at a time, and a layout's
/// recordings together know both (P0.1).
library;

import '../channels.dart';
import 'sql.dart';

/// The channels both queries read.
const outlineChannels = [Channels.lapDist, Channels.pathLateral];
const edgeChannel = Channels.trackEdge;

String _frame(List<(String channel, String alias)> columns) {
  final value = quoteIdent('value');
  final select = [
    for (final (i, (_, alias)) in columns.indexed) 't$i.$value AS $alias',
  ].join(', ');
  final from = [
    for (final (i, (channel, _)) in columns.indexed)
      '${quoteIdent(channel)} t$i',
  ].join(' POSITIONAL JOIN ');
  return 'SELECT $select FROM $from';
}

/// Per [binMetres] station of `Lap Dist`, the median left (`l`, < 0) and
/// right (`r`, > 0) `Track Edge` seen there, as `(b, l, r)`.
///
/// Only samples on the track are kept, P0.1's rules: the edge on the side
/// the car is (`sign(Track Edge) = sign(Path Lateral)`), the car inside it
/// (`|Path Lateral| ≤ |Track Edge| + 0.5 m`), and a plausible half-width
/// (2–20 m) — a pit lane or a run-off reads otherwise.
String trackEdgeBinsSql({double binMetres = 2}) =>
    'SELECT CAST(floor(d / ${sqlDouble(binMetres)}) AS INTEGER) AS b, '
    'median(e) FILTER (WHERE e < 0) AS l, '
    'median(e) FILTER (WHERE e > 0) AS r '
    'FROM (${_frame([(Channels.lapDist, 'd'), (Channels.pathLateral, 'p'), (edgeChannel, 'e')])}) '
    'WHERE d >= 0 AND sign(e) = sign(p) AND abs(p) <= abs(e) + 0.5 '
    'AND abs(e) BETWEEN 2 AND 20 '
    'GROUP BY b ORDER BY b';

/// Per [binMetres] station, how far either side of the centre path this
/// recording's car went, as `(b, l, r)`: the 2nd and 98th percentiles of
/// `Path Lateral`, so one trip across the grass doesn't widen the road.
/// Stations seen fewer than [minSamples] times are left out.
String pathLateralEnvelopeSql({double binMetres = 2, int minSamples = 4}) =>
    'SELECT CAST(floor(d / ${sqlDouble(binMetres)}) AS INTEGER) AS b, '
    'quantile_cont(p, 0.02) AS l, quantile_cont(p, 0.98) AS r '
    'FROM (${_frame([(Channels.lapDist, 'd'), (Channels.pathLateral, 'p')])}) '
    'WHERE d >= 0 AND abs(p) <= 15 '
    'GROUP BY b HAVING count(*) >= $minSamples ORDER BY b';
