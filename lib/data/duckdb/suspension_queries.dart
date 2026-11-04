/// Suspension's reads (suspension proposal §3, §5, §7).
///
/// Like Technique's (`technique_queries.dart`), every query builds one frame
/// of the channels it needs on the 100 Hz master grid, joined by row
/// arithmetic, assigns each sample to a racing lap by its timestamp, and
/// reduces inside DuckDB:
///
/// - `RideHeights` and `Susp Pos` (4 corners each), Ground Speed, steering
///   and the third-element deflections ride the master grid at 100 Hz, so a
///   master row is their row.
/// - `Brake Pos` and `Throttle Pos Unfiltered` are 50 Hz: master row `mi`
///   reads their row `mi // 2`.
/// - `Lap Dist` and `Path Lateral` are 10 Hz and are **interpolated** between
///   their rows, which places a strike to about 0.3 m along the track (SD
///   across laps at one bump, §1). `Lap Dist` is not interpolated across the
///   wrap, where the next row is back near zero.
/// - The three G channels are 10 Hz and read as held. `G Force Long` is
///   lateral (+ left) and `G Force Lat` longitudinal (+ slowing): swapped in
///   the export (SPEC.md §5.4).
/// - `SurfaceTypes` is an event that fires on change, one code per corner,
///   joined `ASOF` (§3.1).
///
/// Laps arrive as `(lap, start, end)` values: Dart decides which laps are
/// racing laps (Technique's rule, SPEC.md §8.13.2), so a lap through the pits
/// never reaches these queries.
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';
import 'technique_queries.dart' show LapSpan;
import 'time_axis.dart';
import '../channels.dart';

/// Channel and event names these queries read.
const suspensionRideHeightChannel = Channels.rideHeights;
const suspensionTravelChannel = Channels.suspPos;
const suspensionSpeedChannel = Channels.groundSpeed;
const suspensionBrakeChannel = Channels.brakePos;
const suspensionThrottleChannel = Channels.throttlePosUnfiltered;
const suspensionSteeringChannel = Channels.steeringPos;
const suspensionDistanceChannel = Channels.lapDist;
const suspensionLineChannel = Channels.pathLateral;
const suspensionLateralGChannel = Channels.gForceLong;
const suspensionLongitudinalGChannel = Channels.gForceLat;
const suspensionVerticalGChannel = Channels.gForceVert;
const suspensionFrontThirdChannel = Channels.front3rdDeflection;
const suspensionRearThirdChannel = Channels.rear3rdDeflection;
const suspensionSurfaceEvent = Events.surfaceTypes;

/// Ride heights above this are a glitch, not the car (an RR reading of 0.9 m
/// was seen), and a sample with any corner above it is dropped (§3).
const rideHeightGlitchMetres = 0.1;

/// The edges of the damper-speed histogram's bins, mm/s, per direction. Bin
/// `k` covers `edges[k]` to `edges[k + 1]`; the last is open. Finer where
/// the slow zone lives (the Alpine's knee is 80–150 mm/s, §0 D5), coarser
/// out to the 550–900 mm/s that kerbs reach (§3.2).
const damperSpeedEdges = <double>[
  0, 10, 25, 50, 75, 100, 150, 200, 300, 500, 800, //
];

/// The channels a suspension query reads.
///
/// Null from [SuspensionChannels.of] when the frame cannot be built: without
/// 100 Hz `RideHeights` and `Lap Dist` on the master grid there is nothing
/// to place. Every other channel is optional and its measures go when it
/// does.
class SuspensionChannels {
  const SuspensionChannels._({
    required this.masterRowCount,
    required this.rideHeight,
    required this.distance,
    required this.travel,
    required this.speed,
    required this.brake,
    required this.throttle,
    required this.steering,
    required this.line,
    required this.lateral,
    required this.longitudinal,
    required this.vertical,
    required this.frontThird,
    required this.rearThird,
    required this.hasSurface,
  });

  static SuspensionChannels? of(TelemetryCatalog catalog) {
    final rows = catalog.masterRowCount;
    ChannelDescriptor? onGrid(String name, {bool perCorner = false}) {
      final c = catalog.channel(name);
      if (c == null || !c.ridesMasterGrid(rows)) return null;
      if (perCorner && !c.isPerCorner) return null;
      return c;
    }

    ChannelDescriptor? at100(String name, {bool perCorner = false}) {
      final c = onGrid(name, perCorner: perCorner);
      return c != null && c.masterStride == 1 ? c : null;
    }

    final rideHeight = at100(suspensionRideHeightChannel, perCorner: true);
    final distance = onGrid(suspensionDistanceChannel);
    if (rideHeight == null || distance == null) return null;
    return SuspensionChannels._(
      masterRowCount: rows,
      rideHeight: rideHeight,
      distance: distance,
      travel: at100(suspensionTravelChannel, perCorner: true),
      speed: at100(suspensionSpeedChannel),
      brake: onGrid(suspensionBrakeChannel),
      throttle: onGrid(suspensionThrottleChannel),
      steering: onGrid(suspensionSteeringChannel),
      line: onGrid(suspensionLineChannel),
      lateral: onGrid(suspensionLateralGChannel),
      longitudinal: onGrid(suspensionLongitudinalGChannel),
      vertical: onGrid(suspensionVerticalGChannel),
      frontThird: at100(suspensionFrontThirdChannel),
      rearThird: at100(suspensionRearThirdChannel),
      hasSurface: catalog.hasEvent(suspensionSurfaceEvent),
    );
  }

  final int masterRowCount;
  final ChannelDescriptor rideHeight;
  final ChannelDescriptor distance;
  final ChannelDescriptor? travel;
  final ChannelDescriptor? speed;
  final ChannelDescriptor? brake;
  final ChannelDescriptor? throttle;
  final ChannelDescriptor? steering;
  final ChannelDescriptor? line;
  final ChannelDescriptor? lateral;
  final ChannelDescriptor? longitudinal;
  final ChannelDescriptor? vertical;
  final ChannelDescriptor? frontThird;
  final ChannelDescriptor? rearThird;
  final bool hasSurface;

  /// Both third-element channels. Whether the car *has* a third element is
  /// the setup's to say: GT3 files carry the channels with junk in them (up
  /// to 87 mm, §3).
  bool get hasThirdChannels => frontThird != null && rearThird != null;
}

final _value = quoteIdent('value');

String _lapsCte(List<LapSpan> laps) {
  if (laps.isEmpty) throw ArgumentError.value(laps, 'laps', 'empty');
  final values = [
    for (final l in laps)
      '(${l.lap}, ${sqlDouble(l.start)}, ${sqlDouble(l.end)})',
  ].join(', ');
  return '_laps(lap, ts, te) AS (VALUES $values)';
}

/// `alias(r, as)` over a one-column channel's rows.
String _rows(String alias, ChannelDescriptor channel, String as) =>
    '$alias AS (SELECT row_number() OVER () - 1 AS r, $_value AS $as '
    'FROM ${quoteIdent(channel.name)})';

/// `alias(r, a, a1)` over a 10 Hz channel's rows with the next row beside
/// each, for interpolating.
String _rowsWithNext(String alias, ChannelDescriptor channel, String as) =>
    '$alias AS (SELECT r, $as, lead($as) OVER (ORDER BY r) AS ${as}1 FROM '
    '(SELECT row_number() OVER () - 1 AS r, $_value AS $as '
    'FROM ${quoteIdent(channel.name)}))';

/// `x`'s row in [channel] at master row [mi].
String _rowAt(ChannelDescriptor channel, String mi) =>
    channel.masterStride == 1 ? mi : '($mi // ${channel.masterStride})';

/// [alias]'s value at master row `mi`, interpolated between its rows. With
/// [guardWrap], a next row more than 50 m back (the lap wrapping to zero) or
/// ahead is not interpolated toward.
String _interpolated(
  ChannelDescriptor channel,
  String alias,
  String col, {
  required String mi,
  bool guardWrap = false,
}) {
  final stride = channel.masterStride;
  if (stride == 1) return '$alias.$col';
  final next = '$alias.${col}1';
  final guard = guardWrap
      ? '$next >= $alias.$col AND $next - $alias.$col < 50'
      : 'abs($next - $alias.$col) < 50';
  return 'CASE WHEN $next IS NOT NULL AND $guard '
      'THEN $alias.$col + ($next - $alias.$col) * (($mi % $stride) / '
      '${stride.toDouble()}) ELSE $alias.$col END';
}

/// The 100 Hz frame as a CTE chain ending in `_x`, one row per master row of
/// a racing lap, restricted to the master rows `_rh0` keeps when [rideWhere]
/// is given (a predicate over `h1`–`h4`).
///
/// Columns: `mi, t, lap, h1, h2, h3, h4` (ride heights, m), `v` (km/h), `b`
/// and `tu` (brake and throttle, %), `st` (steering, as recorded), `ld` (m),
/// `pl` (m, + right of centre, §3.1), `glat` (+ left), `glon` (+ slowing), `gv`,
/// `s1`–`s4` (travel, m, compression positive), `f3`, `r3` (third
/// deflection, m) and, with [surface], `sf1`–`sf4`.
String _frame(
  SuspensionChannels c,
  List<LapSpan> laps, {
  String? rideWhere,
  bool surface = false,
}) {
  const mi = 'k.mi';
  String opt(ChannelDescriptor? ch, String expr) =>
      ch == null ? 'NULL::DOUBLE' : expr;
  final ctes = <String>[
    masterGridCte(),
    _lapsCte(laps),
    '_rh0 AS (SELECT row_number() OVER () - 1 AS r, value1 AS h1, '
        'value2 AS h2, value3 AS h3, value4 AS h4 '
        'FROM ${quoteIdent(c.rideHeight.name)})',
    '_rh AS (SELECT * FROM _rh0'
        '${rideWhere == null ? '' : ' WHERE $rideWhere'})',
    // The kept master rows with their time and lap, before anything else
    // joins: on a filtered read this is a few thousand rows of 700,000.
    '_k AS (SELECT h.r AS mi, m.t, l.lap, h.h1, h.h2, h.h3, h.h4 FROM _rh h '
        'JOIN $masterCteName m ON m.mi = h.r '
        'JOIN _laps l ON m.t >= l.ts AND m.t < l.te)',
    _rowsWithNext('_d', c.distance, 'd'),
    if (c.line case final line?) _rowsWithNext('_pl', line, 'p'),
    if (c.speed case final ch?) _rows('_v', ch, 'v'),
    if (c.brake case final ch?) _rows('_b', ch, 'b'),
    if (c.throttle case final ch?) _rows('_tu', ch, 'tu'),
    if (c.steering case final ch?) _rows('_st', ch, 'st'),
    if (c.lateral case final ch?) _rows('_glat', ch, 'g'),
    if (c.longitudinal case final ch?) _rows('_glon', ch, 'g'),
    if (c.vertical case final ch?) _rows('_gv', ch, 'g'),
    if (c.frontThird case final ch?) _rows('_f3', ch, 'f'),
    if (c.rearThird case final ch?) _rows('_r3', ch, 'f'),
    if (c.travel case final ch?)
      '_s AS (SELECT row_number() OVER () - 1 AS r, value1 AS s1, '
          'value2 AS s2, value3 AS s3, value4 AS s4 '
          'FROM ${quoteIdent(ch.name)})',
  ];
  String join(ChannelDescriptor? ch, String alias) =>
      ch == null ? '' : ' LEFT JOIN $alias ON $alias.r = ${_rowAt(ch, mi)}';
  final line = c.line;
  final travel = c.travel;
  final columns = [
    'k.mi',
    'k.t',
    'k.lap',
    'k.h1',
    'k.h2',
    'k.h3',
    'k.h4',
    '${opt(c.speed, '_v.v')} AS v',
    '${opt(c.brake, '_b.b')} AS b',
    '${opt(c.throttle, '_tu.tu')} AS tu',
    '${opt(c.steering, '_st.st')} AS st',
    '${_interpolated(c.distance, '_d', 'd', mi: mi, guardWrap: true)} AS ld',
    '${line == null ? 'NULL::DOUBLE' : _interpolated(line, '_pl', 'p', mi: mi)} AS pl',
    '${opt(c.lateral, '_glat.g')} AS glat',
    '${opt(c.longitudinal, '_glon.g')} AS glon',
    '${opt(c.vertical, '_gv.g')} AS gv',
    for (var i = 1; i <= 4; i++) '${opt(travel, '_s.s$i')} AS s$i',
    '${opt(c.frontThird, '_f3.f')} AS f3',
    '${opt(c.rearThird, '_r3.f')} AS r3',
  ];
  final from = StringBuffer('FROM _k k')
    ..write(join(c.distance, '_d'))
    ..write(join(line, '_pl'))
    ..write(join(c.speed, '_v'))
    ..write(join(c.brake, '_b'))
    ..write(join(c.throttle, '_tu'))
    ..write(join(c.steering, '_st'))
    ..write(join(c.lateral, '_glat'))
    ..write(join(c.longitudinal, '_glon'))
    ..write(join(c.vertical, '_gv'))
    ..write(join(c.frontThird, '_f3'))
    ..write(join(c.rearThird, '_r3'))
    ..write(join(travel, '_s'));
  ctes.add('_x0 AS (SELECT ${columns.join(', ')} $from)');
  if (surface && c.hasSurface) {
    ctes.add(
      '_x AS (SELECT x.*, su.value1 AS sf1, su.value2 AS sf2, '
      'su.value3 AS sf3, su.value4 AS sf4 FROM _x0 x '
      'ASOF LEFT JOIN ${quoteIdent(suspensionSurfaceEvent)} su '
      'ON x.t >= su.ts)',
    );
  } else {
    ctes.add(
      '_x AS (SELECT x.*, NULL::INTEGER AS sf1, NULL::INTEGER AS sf2, '
      'NULL::INTEGER AS sf3, NULL::INTEGER AS sf4 FROM _x0 x)',
    );
  }
  return 'WITH ${ctes.join(', ')}';
}

/// Whether a ride-height sample is on the car (§3, §5): every corner under
/// [rideHeightGlitchMetres].
const _onCar = 'greatest(h1, h2, h3, h4) < $rideHeightGlitchMetres';

/// Every racing-lap sample with a corner under [ceilingMetres] — the Strike
/// floor plus the Close band (D6) — above [minSpeed] km/h, in master-row
/// order: the candidates `strikes.dart` merges into strikes.
///
/// Columns, by position: `mi, t, lap, h1, h2, h3, h4, v, b, ld, pl, glat,
/// glon, gv, sf1, sf2, sf3, sf4`.
String strikeSamplesSql(
  SuspensionChannels c,
  List<LapSpan> laps, {
  required double ceilingMetres,
  required double minSpeed,
}) {
  final frame = _frame(
    c,
    laps,
    rideWhere:
        'least(h1, h2, h3, h4) < ${sqlDouble(ceilingMetres)} '
        'AND $_onCar',
    surface: true,
  );
  final speedFilter = c.speed == null
      ? ''
      : ' WHERE v > ${sqlDouble(minSpeed)}';
  return '$frame SELECT mi, t, lap, h1, h2, h3, h4, v, b, ld, pl, glat, '
      'glon, gv, sf1, sf2, sf3, sf4 FROM _x$speedFilter ORDER BY mi';
}

/// A stretch of `Lap Dist` read for one site: its key, its bounds, and the
/// corner (0 FL, 1 FR, 2 RL, 3 RR) whose minimum is taken.
typedef SiteSpan = ({int key, double start, double end, int corner});

/// Per site and racing lap, the lowest sample of the site's corner within
/// its span, above [minSpeed] km/h, with where the car was then.
///
/// Columns: `k, lap, h` (m), `ld, pl, v` at that sample, `b` (the most
/// brake in the span), `n` (samples).
String siteLapMinimaSql(
  SuspensionChannels c,
  List<LapSpan> laps,
  List<SiteSpan> sites, {
  required double minSpeed,
}) {
  if (sites.isEmpty) throw ArgumentError.value(sites, 'sites', 'empty');
  final values = [
    for (final s in sites)
      '(${s.key}, ${sqlDouble(s.start)}, ${sqlDouble(s.end)}, ${s.corner})',
  ].join(', ');
  final speedFilter = c.speed == null
      ? ''
      : ' AND x.v > ${sqlDouble(minSpeed)}';
  return '${_frame(c, laps, rideWhere: _onCar)}, '
      '_w(k, s0, s1, c) AS (VALUES $values), '
      '_m AS (SELECT w.k, x.lap, x.ld, x.pl, x.v, x.b, '
      'CASE w.c WHEN 0 THEN x.h1 WHEN 1 THEN x.h2 WHEN 2 THEN x.h3 '
      'ELSE x.h4 END AS h FROM _x x JOIN _w w '
      'ON x.ld >= w.s0 AND x.ld <= w.s1$speedFilter) '
      'SELECT k, lap, min(h), arg_min(ld, h), arg_min(pl, h), arg_min(v, h), '
      'max(b), count(*) FROM _m GROUP BY k, lap ORDER BY k, lap';
}

/// Every racing lap's samples within `[start, end]` of `Lap Dist`, in 1 m
/// bins: the site view's ribbon and trace stack.
///
/// Columns: `lap, m` (the bin's metre), `h1`–`h4` (each corner's lowest, m),
/// `v, b, tu, st, pl, glat` (means; `b` the most), `gv` (the largest
/// |vertical G|, signed), `s1`–`s4` (mean travel, m), `f3, r3` (largest, m),
/// `sf` (1 when any wheel was on a kerb or paint, 2 when off track).
String siteTracesSql(
  SuspensionChannels c,
  List<LapSpan> laps, {
  required double start,
  required double end,
}) {
  return '${_frame(c, laps, rideWhere: _onCar, surface: true)} '
      'SELECT lap, floor(ld)::INTEGER AS m, min(h1), min(h2), min(h3), '
      'min(h4), avg(v), max(b), avg(tu), avg(st), avg(pl), avg(glat), '
      'arg_max(gv, abs(gv)), avg(s1), avg(s2), avg(s3), avg(s4), max(f3), '
      'max(r3), max(CASE WHEN 2 IN (sf1, sf2, sf3, sf4) '
      'OR 4 IN (sf1, sf2, sf3, sf4) THEN 2 '
      'WHEN 5 IN (sf1, sf2, sf3, sf4) OR 6 IN (sf1, sf2, sf3, sf4) THEN 1 '
      'ELSE 0 END) '
      'FROM _x WHERE ld >= ${sqlDouble(start)} AND ld <= ${sqlDouble(end)} '
      'GROUP BY lap, m ORDER BY lap, m';
}

/// Per racing lap, the platform's numbers, and one row for the session's
/// third-element ceilings.
///
/// Rows of kind 0, one per lap: `kind, lap, n` (samples above
/// [packerSpeed]), the median front and rear axle ride height above it (m),
/// the lowest front and rear corner (m, above [minSpeed]), the share of
/// samples above [packerSpeed] with the front and rear third within
/// [packerMarginMetres] of its ceiling, then front and rear roll — the slope
/// of left minus right travel (mm) on lateral G for |G| over [rollMinG], and
/// its r — and the sample count the roll fit used.
///
/// The row of kind 1 carries the ceilings: `kind, NULL, NULL, front, rear`
/// (m) — each third's 99.9th percentile above [packerSpeed], which on the
/// Alpine sits at 9.75 / 14.47 mm to ±0.03 mm across 30 files (§3).
String lapPlatformSql(
  SuspensionChannels c,
  List<LapSpan> laps, {
  required double minSpeed,
  required double packerSpeed,
  required double packerMarginMetres,
  required double rollMinG,
}) {
  final third = c.hasThirdChannels;
  final ps = sqlDouble(packerSpeed);
  final ms = sqlDouble(minSpeed);
  final margin = sqlDouble(packerMarginMetres);
  final g = sqlDouble(rollMinG);
  final ceilings = third
      ? '_c AS (SELECT quantile_cont(f3, 0.999) AS fc, '
            'quantile_cont(r3, 0.999) AS rc FROM _x WHERE v > $ps)'
      : '_c AS (SELECT NULL::DOUBLE AS fc, NULL::DOUBLE AS rc)';
  final packers = third
      ? 'count(*) FILTER (WHERE x.v > $ps AND x.f3 >= _c.fc - $margin) '
            '/ greatest(count(*) FILTER (WHERE x.v > $ps), 1), '
            'count(*) FILTER (WHERE x.v > $ps AND x.r3 >= _c.rc - $margin) '
            '/ greatest(count(*) FILTER (WHERE x.v > $ps), 1)'
      : 'NULL::DOUBLE, NULL::DOUBLE';
  const front = '(x.s1 - x.s2) * 1000';
  const rear = '(x.s3 - x.s4) * 1000';
  final rollWhere = 'abs(x.glat) > $g AND x.v > $ms';
  return '${_frame(c, laps, rideWhere: _onCar)}, $ceilings '
      'SELECT 0 AS kind, x.lap, count(*) FILTER (WHERE x.v > $ps), '
      'quantile_cont((x.h1 + x.h2) / 2, 0.5) FILTER (WHERE x.v > $ps), '
      'quantile_cont((x.h3 + x.h4) / 2, 0.5) FILTER (WHERE x.v > $ps), '
      'min(least(x.h1, x.h2)) FILTER (WHERE x.v > $ms), '
      'min(least(x.h3, x.h4)) FILTER (WHERE x.v > $ms), '
      '$packers, '
      'regr_slope($front, x.glat) FILTER (WHERE $rollWhere), '
      'corr($front, x.glat) FILTER (WHERE $rollWhere), '
      'regr_slope($rear, x.glat) FILTER (WHERE $rollWhere), '
      'corr($rear, x.glat) FILTER (WHERE $rollWhere), '
      'count(*) FILTER (WHERE $rollWhere) '
      'FROM _x x, _c GROUP BY x.lap '
      'UNION ALL SELECT 1, NULL, NULL, fc, rc, NULL, NULL, NULL, NULL, NULL, '
      'NULL, NULL, NULL, NULL FROM _c ORDER BY 1, 2';
}

/// Per racing lap and corner, the damper-speed histogram: travel's central
/// difference over ±10 ms, in mm/s with bump positive, counted in
/// [damperSpeedEdges]' bins. Bump bins are 0, 1, …; rebound bins −1, −2, …
/// (bin −1 is the slowest rebound).
///
/// Columns: `lap, c` (0 FL … 3 RR), `bin, n`. Empty without `Susp Pos`.
String damperHistogramSql(SuspensionChannels c, List<LapSpan> laps) {
  final travel = c.travel;
  if (travel == null) throw StateError('No Susp Pos channel.');
  final cases = StringBuffer('CASE');
  for (var k = 1; k < damperSpeedEdges.length; k++) {
    cases.write(' WHEN a < ${sqlDouble(damperSpeedEdges[k])} THEN ${k - 1}');
  }
  cases.write(' ELSE ${damperSpeedEdges.length - 1} END');
  // 0.02 s between the samples either side; metres to millimetres.
  String vel(int i) =>
      '(lead(value$i) OVER w - lag(value$i) OVER w) * 50000.0 AS v$i';
  return 'WITH ${masterGridCte()}, ${_lapsCte(laps)}, '
      '_s AS (SELECT row_number() OVER () - 1 AS r, value1, value2, value3, '
      'value4 FROM ${quoteIdent(travel.name)}), '
      '_v AS (SELECT r, ${vel(1)}, ${vel(2)}, ${vel(3)}, ${vel(4)} FROM _s '
      'WINDOW w AS (ORDER BY r)), '
      '_l AS (SELECT l.lap, v.v1, v.v2, v.v3, v.v4 FROM _v v '
      'JOIN $masterCteName m ON m.mi = v.r '
      'JOIN _laps l ON m.t >= l.ts AND m.t < l.te), '
      '_u AS (SELECT lap, 0 AS c, v1 AS vel FROM _l UNION ALL '
      'SELECT lap, 1, v2 FROM _l UNION ALL SELECT lap, 2, v3 FROM _l '
      'UNION ALL SELECT lap, 3, v4 FROM _l), '
      '_b AS (SELECT lap, c, vel, abs(vel) AS a FROM _u WHERE vel IS NOT NULL) '
      'SELECT lap, c, CASE WHEN vel >= 0 THEN $cases ELSE -($cases) - 1 END '
      'AS bin, count(*) FROM _b GROUP BY ALL ORDER BY lap, c, bin';
}
