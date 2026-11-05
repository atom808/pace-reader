/// Reads for the trace's driver-aid overlays (driver-aids proposal §3).
library;

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
