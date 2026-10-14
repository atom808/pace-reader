/// Driving Technique's reads (SPEC.md §8.13.2, §8.13.9).
///
/// Every measure is aggregated inside DuckDB — `lapStatsSql`'s rule (§9.5) —
/// so a 127-lap race returns a few thousand rows, never its 635,000 pedal
/// samples. Each query builds one frame of the channels it needs, joined by
/// row arithmetic on the master grid, assigns each sample to a lap by its
/// timestamp, and reduces:
///
/// - **The pedal frame** (50 Hz): `Throttle Pos Unfiltered` and `Brake Pos`
///   joined positionally — they are row-aligned — with `Steering Pos` and
///   Ground Speed at master row 2i and `Lap Dist` interpolated between its
///   10 Hz rows. Each sample is timestamped once, through master row 2i, and
///   `TC`/`ABS` join `ASOF LEFT` on that time — or, where a newer build
///   records `TC` as a 100 Hz channel (§5.1), `TC` joins at row 2i.
/// - **The G frame** (10 Hz): `G Force Long` (lateral, + left) and `G Force
///   Lat` (longitudinal, + braking) — swapped in the export, §5.4 — with
///   `Lap Dist` on the same row and Ground Speed at master row 10i.
///
/// Laps arrive as a `VALUES` list of `(lap, start, end)`: which laps are
/// racing laps is decided in Dart, from the pit-lane and limiter states
/// (§8.13.2), and the queries only ever see those.
library;

import '../models/telemetry_catalog.dart';
import 'sql.dart';
import 'time_axis.dart';

/// Channel and event names these queries read.
const techniquePedalChannel = 'Throttle Pos Unfiltered';
const techniqueBrakeChannel = 'Brake Pos';
const techniqueSteeringChannel = 'Steering Pos';
const techniqueSpeedChannel = 'Ground Speed';
const techniqueDistanceChannel = 'Lap Dist';
const techniqueLateralGChannel = 'G Force Long';
const techniqueLongitudinalGChannel = 'G Force Lat';
const techniqueRpmChannel = 'Engine RPM';
const techniqueLatitudeChannel = 'GPS Latitude';
const techniqueLongitudeChannel = 'GPS Longitude';

/// An event in every build before 2026-10-13, a channel in a newer one
/// (§5.1): [TechniqueChannels.tcChannel] says which.
const techniqueTcEvent = 'TC';
const techniqueAbsEvent = 'ABS';
const techniqueGearEvent = 'Gear';
const techniqueLimiterEvent = 'Speed Limiter';

/// A lap the queries measure.
typedef LapSpan = ({int lap, double start, double end});

/// A stretch of `Lap Dist` the queries total over: a segment or a corner.
/// [apex] is where a corner's steering is read; null for a segment.
typedef StretchSpan = ({int key, double start, double end, double? apex});

/// The channels a technique query reads, each riding the master grid.
///
/// Null from [TechniqueChannels.of] when a channel is missing or off the
/// grid: every query here maps rows by exact stride, and the two channels
/// that need the ratio fallback (§5.2's 7 Hz temperatures) are not among
/// them in any file seen.
class TechniqueChannels {
  const TechniqueChannels._({
    required this.masterRowCount,
    required this.pedal,
    required this.brake,
    required this.steering,
    required this.speed,
    required this.distance,
    required this.lateral,
    required this.longitudinal,
    required this.rpm,
    required this.latitude,
    required this.longitude,
    required this.tcChannel,
    required this.hasTc,
    required this.hasAbs,
  });

  static TechniqueChannels? of(TelemetryCatalog catalog) {
    final rows = catalog.masterRowCount;
    ChannelDescriptor? onGrid(String name) {
      final c = catalog.channel(name);
      return c != null && c.ridesMasterGrid(rows) ? c : null;
    }

    final pedal = onGrid(techniquePedalChannel);
    final brake = onGrid(techniqueBrakeChannel);
    final distance = onGrid(techniqueDistanceChannel);
    if (pedal == null || brake == null || distance == null) return null;
    if (pedal.rowCount != brake.rowCount) return null;
    final tcEvent = catalog.hasEvent(techniqueTcEvent);
    final tcChannel = tcEvent ? null : onGrid(techniqueTcEvent);
    return TechniqueChannels._(
      masterRowCount: rows,
      pedal: pedal,
      brake: brake,
      steering: onGrid(techniqueSteeringChannel),
      speed: onGrid(techniqueSpeedChannel),
      distance: distance,
      lateral: onGrid(techniqueLateralGChannel),
      longitudinal: onGrid(techniqueLongitudinalGChannel),
      rpm: onGrid(techniqueRpmChannel),
      latitude: onGrid(techniqueLatitudeChannel),
      longitude: onGrid(techniqueLongitudeChannel),
      tcChannel: tcChannel,
      hasTc: tcEvent || tcChannel != null,
      hasAbs: catalog.hasEvent(techniqueAbsEvent),
    );
  }

  final int masterRowCount;
  final ChannelDescriptor pedal;
  final ChannelDescriptor brake;
  final ChannelDescriptor? steering;
  final ChannelDescriptor? speed;
  final ChannelDescriptor distance;
  final ChannelDescriptor? lateral;
  final ChannelDescriptor? longitudinal;
  final ChannelDescriptor? rpm;
  final ChannelDescriptor? latitude;
  final ChannelDescriptor? longitude;

  /// `TC` where the file records it as a channel, a 100 Hz `BOOLEAN` on the
  /// master grid (§5.1); null where it is an event or absent. [hasTc] is
  /// true for either kind.
  final ChannelDescriptor? tcChannel;
  final bool hasTc;
  final bool hasAbs;

  bool get hasG => lateral != null && longitudinal != null;
  bool get hasPosition => latitude != null && longitude != null;
}

/// `name AS (row index r, value as [as])` over a channel's rows.
String _rows(String alias, ChannelDescriptor channel, String as) =>
    '$alias AS (SELECT row_number() OVER () - 1 AS r, '
    '${quoteIdent('value')} AS $as FROM ${quoteIdent(channel.name)})';

/// The SQL for [channel]'s row at master row [masterRow], which must be a
/// multiple of the channel's stride wherever it is used.
String _rowAt(ChannelDescriptor channel, String masterRow) =>
    channel.masterStride == 1
    ? masterRow
    : '(($masterRow) // ${channel.masterStride})';

String _lapsCte(List<LapSpan> laps) {
  if (laps.isEmpty) throw ArgumentError.value(laps, 'laps', 'empty');
  final values = [
    for (final l in laps)
      '(${l.lap}, ${sqlDouble(l.start)}, ${sqlDouble(l.end)})',
  ].join(', ');
  return '_laps(lap, ts, te) AS (VALUES $values)';
}

String _stretchCte(String alias, List<StretchSpan> spans) {
  final values = [
    for (final s in spans)
      '(${s.key}, ${sqlDouble(s.start)}, ${sqlDouble(s.end)}, '
          '${s.apex == null ? 'NULL::DOUBLE' : sqlDouble(s.apex!)})',
  ].join(', ');
  return '$alias(k, s0, s1, apex) AS (VALUES $values)';
}

/// The session's largest |`Steering Pos`|, for its unit (§8.13.1).
String steeringMaxAbsSql() =>
    'SELECT max(abs(${quoteIdent('value')})) '
    'FROM ${quoteIdent(techniqueSteeringChannel)}';

/// An on/off event as `(ts, on)` rows, in order: `In Pits`, `Speed Limiter`.
String flagRowsSql(String eventName) =>
    'SELECT ts, ${quoteIdent('value')} FROM ${quoteIdent(eventName)} '
    'ORDER BY ts';

/// The pedal frame, assigned to [laps], as a CTE chain ending in `_x`:
/// `i, t, tu, b, s, v, ld, dld, lap, tc, ab`.
String _pedalFrame(
  TechniqueChannels c,
  List<LapSpan> laps, {
  required double steeringScale,
  bool aids = true,
}) {
  final p = c.pedal.masterStride;
  final d = c.distance.masterStride;
  final master = '(p.i * $p)';
  final steering = c.steering;
  final speed = c.speed;
  final value = quoteIdent('value');
  // `TC` at each pedal row: the event's latest edge at or before its time,
  // or, as a channel, its row at master row 2i — the same 10 ms tick the
  // event is read at, joined on row number like `Steering Pos`.
  final tcChannel = aids ? c.tcChannel : null;
  final (tc, tcJoin) = !aids || !c.hasTc
      ? ('false', '')
      : tcChannel != null
      ? (
          'coalesce(tc.v, false)',
          ' LEFT JOIN _tc tc ON tc.r = ${_rowAt(tcChannel, '(f.i * $p)')}',
        )
      : (
          'coalesce(tc.$value, false)',
          ' ASOF LEFT JOIN ${quoteIdent(techniqueTcEvent)} tc ON f.t >= tc.ts',
        );
  final ctes = [
    masterGridCte(),
    _lapsCte(laps),
    '_p AS (SELECT row_number() OVER () - 1 AS i, tu.$value AS tu, '
        'b.$value AS b FROM ${quoteIdent(c.pedal.name)} tu '
        'POSITIONAL JOIN ${quoteIdent(c.brake.name)} b)',
    if (steering != null)
      '_s AS (SELECT row_number() OVER () - 1 AS r, '
          '$value * ${sqlDouble(steeringScale)} AS s '
          'FROM ${quoteIdent(steering.name)})',
    if (speed != null) _rows('_v', speed, 'v'),
    '_d0 AS (SELECT row_number() OVER () - 1 AS r, $value AS d '
        'FROM ${quoteIdent(c.distance.name)})',
    '_d AS (SELECT r, d, lead(d) OVER (ORDER BY r) AS d1 FROM _d0)',
    // Lap Dist between its 10 Hz rows, except across the wrap, where the
    // next row is back near zero and interpolating would invent a station.
    '_f AS (SELECT p.i, m.t, p.tu, p.b, '
        '${steering == null ? 'NULL::DOUBLE' : 's.s'} AS s, '
        '${speed == null ? 'NULL::DOUBLE' : 'v.v'} AS v, '
        'CASE WHEN d.d1 IS NOT NULL AND d.d1 >= d.d AND d.d1 - d.d < 50 '
        'THEN d.d + (d.d1 - d.d) * (($master % $d) / ${d.toDouble()}) '
        'ELSE d.d END AS ld '
        'FROM _p p JOIN $masterCteName m ON m.mi = $master '
        '${steering == null ? '' : 'LEFT JOIN _s s ON s.r = ${_rowAt(steering, master)} '}'
        '${speed == null ? '' : 'LEFT JOIN _v v ON v.r = ${_rowAt(speed, master)} '}'
        'LEFT JOIN _d d ON d.r = $master // $d)',
    if (tcChannel != null) _rows('_tc', tcChannel, 'v'),
    '_x AS MATERIALIZED (SELECT f.*, l.lap, $tc AS tc, '
        '${aids && c.hasAbs ? 'coalesce(ab.$value, false)' : 'false'} AS ab, '
        'coalesce(lead(f.ld) OVER (PARTITION BY l.lap ORDER BY f.i) - f.ld, 0) '
        'AS dld '
        'FROM _f f JOIN _laps l ON f.t >= l.ts AND f.t < l.te'
        '$tcJoin'
        '${aids && c.hasAbs ? ' ASOF LEFT JOIN ${quoteIdent(techniqueAbsEvent)} ab ON f.t >= ab.ts' : ''})',
  ];
  return 'WITH ${ctes.join(', ')}';
}

/// The pedal frame's totals, one row per lap, and per lap and stretch when
/// [segments] or [corners] are given.
///
/// Columns: `kind` (0 lap, 1 segment, 2 corner), `lap`, `k` (the stretch's
/// key, null for a lap), then sample counts — `n`, braking, overlap, coast,
/// full throttle, trail (braking with |steer| ≥ 5 %), TC on, ABS on — then
/// coasting metres of `Lap Dist`, the slowest Ground Speed, and (corners
/// only) `Steering Pos` at the apex.
///
/// Thresholds are the ones §8.13.1 set: a pedal is applied above 2 %, full
/// throttle is ≥ 98 %, coasting is both pedals at exactly 0.
String lapPedalStatsSql(
  TechniqueChannels c,
  List<LapSpan> laps, {
  required double steeringScale,
  List<StretchSpan> segments = const [],
  List<StretchSpan> corners = const [],
}) {
  const aggregates =
      'count(*) AS n, '
      'count(*) FILTER (WHERE x.b > 2) AS braking, '
      'count(*) FILTER (WHERE x.tu > 2 AND x.b > 2) AS overlap, '
      'count(*) FILTER (WHERE x.tu = 0 AND x.b = 0) AS coast, '
      'count(*) FILTER (WHERE x.tu >= 98) AS full_throttle, '
      'count(*) FILTER (WHERE x.b > 2 AND abs(x.s) >= 5) AS trail, '
      'count(*) FILTER (WHERE x.tc) AS tc, '
      'count(*) FILTER (WHERE x.ab) AS ab, '
      'coalesce(sum(CASE WHEN x.dld > 0 AND x.dld < 10 THEN x.dld END) '
      'FILTER (WHERE x.tu = 0 AND x.b = 0), 0) AS coast_m, '
      'min(x.v) AS vmin';
  final ctes = [
    if (segments.isNotEmpty) _stretchCte('_seg', segments),
    if (corners.isNotEmpty) _stretchCte('_cor', corners),
  ];
  final selects = [
    'SELECT 0 AS kind, x.lap, NULL::INTEGER AS k, $aggregates, '
        'NULL::DOUBLE AS steer_apex FROM _x x GROUP BY x.lap',
    if (segments.isNotEmpty)
      'SELECT 1, x.lap, g.k, $aggregates, NULL::DOUBLE FROM _x x '
          'JOIN _seg g ON x.ld >= g.s0 AND x.ld < g.s1 GROUP BY x.lap, g.k',
    if (corners.isNotEmpty)
      'SELECT 2, x.lap, g.k, $aggregates, '
          'arg_min(x.s, abs(x.ld - g.apex)) FROM _x x '
          'JOIN _cor g ON x.ld >= g.s0 AND x.ld <= g.s1 GROUP BY x.lap, g.k',
  ];
  final frame = _pedalFrame(c, laps, steeringScale: steeringScale);
  return '$frame${ctes.isEmpty ? '' : ', ${ctes.join(', ')}'} '
      '${selects.join(' UNION ALL ')} ORDER BY kind, lap, k';
}

/// Each lap's pedal states run-length encoded: `(lap, state, samples)` in
/// order, state 0 coast, 1 throttle, 2 brake, 3 overlap, 4 transit — what
/// `classifySpans` reads.
String pedalRunsSql(
  TechniqueChannels c,
  List<LapSpan> laps, {
  required double steeringScale,
}) {
  final frame = _pedalFrame(c, laps, steeringScale: steeringScale, aids: false);
  return '$frame, '
      '_r AS (SELECT lap, i, CASE WHEN tu > 2 AND b > 2 THEN 3 '
      'WHEN b > 2 THEN 2 WHEN tu > 2 THEN 1 WHEN tu = 0 AND b = 0 THEN 0 '
      'ELSE 4 END AS st FROM _x), '
      '_g AS (SELECT lap, i, st, '
      'i - row_number() OVER (PARTITION BY lap, st ORDER BY i) AS grp FROM _r) '
      'SELECT lap, st, count(*) AS n, min(i) AS i0 FROM _g '
      'GROUP BY lap, st, grp ORDER BY lap, i0';
}

/// An aid's merged episodes per lap: `(lap, episodes)`.
///
/// `TC` and `ABS` switch in 10–20 ms pulses with 2.5–10 ms gaps — 117–908 TC
/// edges a lap — so pulses closer than [mergeGap] seconds are one episode.
/// The merge runs here rather than in Dart because a long race holds over
/// 100,000 pulses and a few hundred episodes.
///
/// [channel] is the aid recorded as a channel instead, as a newer build
/// records `TC` (§5.1). Its edges are the rows where the value changes, its
/// first row included, as an event's first row sits at the origin. They are
/// found in row order and only then timestamped through the master grid —
/// `lapStatsSql`'s rule (§9.5) — so a 45-minute race's 265,740 rows are
/// 7,019 edges before any time is read. From there the merge is the event's.
String aidEpisodesSql(
  String eventName,
  List<LapSpan> laps, {
  ChannelDescriptor? channel,
  double mergeGap = 0.25,
}) {
  final value = quoteIdent('value');
  final edges = channel == null
      ? ''
      : '${masterGridCte()}, ${_rows('_c', channel, 'v')}, '
            '_cx AS (SELECT r, v FROM (SELECT r, v, '
            'lag(v) OVER (ORDER BY r) AS pv FROM _c) '
            'WHERE pv IS DISTINCT FROM v), '
            '_ev AS (SELECT m.t AS ts, x.v AS $value FROM _cx x '
            'JOIN $masterCteName m ON m.mi = '
            '${channel.masterStride == 1 ? 'x.r' : '(x.r * ${channel.masterStride})'}), ';
  return 'WITH $edges${_lapsCte(laps)}, '
      '_on AS (SELECT ts AS a, lead(ts) OVER (ORDER BY ts) AS b, '
      '$value AS v FROM ${channel == null ? quoteIdent(eventName) : '_ev'}), '
      '_iv AS (SELECT a, coalesce(b, a + 0.01) AS b FROM _on WHERE v), '
      '_m AS (SELECT a, b, CASE WHEN a - max(b) OVER (ORDER BY a ROWS '
      'BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) <= ${sqlDouble(mergeGap)} '
      'THEN 0 ELSE 1 END AS fresh FROM _iv), '
      '_e AS (SELECT a, b, sum(fresh) OVER (ORDER BY a ROWS UNBOUNDED '
      'PRECEDING) AS ep FROM _m), '
      '_ep AS (SELECT ep, min(a) AS a FROM _e GROUP BY ep) '
      'SELECT l.lap, count(*) FROM _ep JOIN _laps l '
      'ON _ep.a >= l.ts AND _ep.a < l.te GROUP BY l.lap ORDER BY l.lap';
}

/// Every `Gear` row: `(ts, gear)` in order. Sparse — a few rows per shift.
String gearRowsSql() =>
    'SELECT ts, ${quoteIdent('value')} FROM ${quoteIdent(techniqueGearEvent)} '
    'ORDER BY ts';

/// Each upshift's neutral row with what surrounds it: `(ts, rpm, da, pedal,
/// limiter seconds)`.
///
/// - `rpm`: the maximum `Engine RPM` in the 0.3 s before the neutral row;
/// - `da`: Ground Speed's acceleration over the 0.25 s after the neutral row
///   minus the 0.25 s before, km/h per s;
/// - `pedal`: `Throttle Pos Unfiltered` at the neutral row;
/// - limiter seconds: time within [limiterMargin] rpm of [limiter] in the
///   second before it (0 without a limiter).
///
/// An upshift is a neutral row between a gear and a higher one: every change
/// in 678 files goes old → 0 → new.
String upshiftReadsSql(
  TechniqueChannels c, {
  double? limiter,
  double limiterMargin = 100,
}) {
  final rpm = c.rpm;
  final speed = c.speed;
  final value = quoteIdent('value');
  // Rows a second of RPM holds, and the 0.3 s window inside it.
  final perSecond = rpm == null ? 0 : 100 ~/ rpm.masterStride;
  final shiftWindow = (perSecond * 0.3).round();
  final window = speed == null
      ? 0
      : (25 ~/ speed.masterStride) * speed.masterStride;
  final ctes = [
    masterGridCte(),
    '_ge AS (SELECT ts, $value AS g, lag($value) OVER (ORDER BY ts) AS pg, '
        'lead($value) OVER (ORDER BY ts) AS ng '
        'FROM ${quoteIdent(techniqueGearEvent)})',
    '_up AS (SELECT ts FROM _ge WHERE g = 0 AND pg >= 1 AND ng > pg)',
    '_um AS (SELECT u.ts, m.mi FROM _up u ASOF JOIN $masterCteName m '
        'ON u.ts <= m.t)',
    _rows('_pd', c.pedal, 'tu'),
    if (speed != null) _rows('_v', speed, 'v'),
    // The second before each neutral row, as one row per RPM sample and
    // joined on equality: a range join against a 100 Hz channel measured
    // 4.4 s on Imola's 127-lap race, this well under one. It serves both the
    // shift RPM (its last 0.3 s) and the limiter time.
    if (rpm != null) ...[
      _rows('_rpm', rpm, 'rpm'),
      '_uw AS (SELECT u.ts, ${_rowAt(rpm, 'u.mi')} - o AS r, o FROM _um u '
          'CROSS JOIN range(1, ${perSecond + 1}) t(o))',
      '_rw AS (SELECT w.ts, max(r.rpm) FILTER (WHERE w.o <= $shiftWindow) '
          'AS rpm, '
          '${limiter == null ? '0' : 'count(*) FILTER (WHERE r.rpm >= ${sqlDouble(limiter - limiterMargin)})'} '
          'AS dwell FROM _uw w JOIN _rpm r ON r.r = w.r GROUP BY w.ts)',
    ],
  ];
  String speedJoin(String alias, String offset) => speed == null
      ? ''
      : 'LEFT JOIN _v $alias ON $alias.r = '
            '${_rowAt(speed, 'u.mi + ($offset)')} ';
  return 'WITH ${ctes.join(', ')} '
      'SELECT u.ts, ${rpm == null ? 'NULL::DOUBLE' : 'rw.rpm'} AS rpm, '
      '${speed == null ? 'NULL::DOUBLE' : '((va.v - v0.v) - (v0.v - vb.v)) / ${sqlDouble(window / 100)}'} '
      'AS da, pd.tu AS pedal, '
      '${rpm == null ? '0.0' : 'coalesce(rw.dwell, 0) / ${perSecond.toDouble()}'} '
      'AS dwell FROM _um u '
      '${rpm == null ? '' : 'LEFT JOIN _rw rw ON rw.ts = u.ts '}'
      '${speedJoin('va', '$window')}${speedJoin('v0', '0')}'
      '${speedJoin('vb', '-$window')}'
      'LEFT JOIN _pd pd ON pd.r = ${_rowAt(c.pedal, 'u.mi')} '
      'ORDER BY u.ts';
}

/// The G frame, assigned to [laps], as a CTE chain ending in `_x`:
/// `r, t, lat (+ left), lng (+ braking), c (combined), ld, v, lap`, plus
/// `_e(e)`: the session's p99 of combined G.
String _gFrame(TechniqueChannels c, List<LapSpan> laps) {
  final lateral = c.lateral!;
  final longitudinal = c.longitudinal!;
  final g = lateral.masterStride;
  final speed = c.speed;
  final master = '(a.r * $g)';
  final ctes = [
    masterGridCte(),
    _lapsCte(laps),
    _rows('_a', lateral, 'lat'),
    _rows('_b', longitudinal, 'lng'),
    _rows('_d', c.distance, 'ld'),
    if (speed != null) _rows('_v', speed, 'v'),
    '_g AS (SELECT a.r, m.t, a.lat, b.lng, sqrt(a.lat * a.lat + b.lng * b.lng) '
        'AS c, d.ld, ${speed == null ? 'NULL::DOUBLE' : 'v.v'} AS v '
        'FROM _a a JOIN _b b ON b.r = a.r '
        'JOIN $masterCteName m ON m.mi = $master '
        'LEFT JOIN _d d ON d.r = ${_rowAt(c.distance, master)} '
        '${speed == null ? '' : 'LEFT JOIN _v v ON v.r = ${_rowAt(speed, master)}'})',
    '_x AS MATERIALIZED (SELECT g.*, l.lap FROM _g g JOIN _laps l '
        'ON g.t >= l.ts AND g.t < l.te)',
    '_e AS (SELECT quantile_cont(c, 0.99) AS e FROM _x)',
  ];
  return 'WITH ${ctes.join(', ')}';
}

/// The G frame reduced (§8.13.3), as `(kind, a, b, c, d, e)` rows:
///
/// - kind 0, per lap: `lap, sustained peak, utilisation sum, utilisation n,
///   samples`. The sustained peak is the maximum of combined G's rolling
///   minimum over three samples (0.3 s); utilisation is combined G ÷ E
///   summed over samples at or above 0.5 G, E being the session's p99.
/// - kind 1 and 2, per lap and segment or corner: `lap, key, peak |lateral|,
///   utilisation sum, utilisation n`.
/// - kind 3, the envelope: `band, angle bin, p99 of combined G, samples`.
///   Band 0–2 are < 150, 150–200 and ≥ 200 km/h, 3 all speeds; the 36 bins
///   are 10° of the plot's angle, atan2(braking, −lateral).
/// - kind 4, the density grid: `cell x, cell y, samples` in 0.05 G cells of
///   (−lateral, braking), so left-hand G sits on the left.
/// - kind 5, the direction limits: `band, braking p99, traction p99, lateral
///   p99, E`.
String lapGgSql(
  TechniqueChannels c,
  List<LapSpan> laps, {
  List<StretchSpan> segments = const [],
  List<StretchSpan> corners = const [],
}) {
  const band = 'CASE WHEN x.v < 150 THEN 0 WHEN x.v < 200 THEN 1 ELSE 2 END';
  const angleBin =
      'CAST(floor((atan2(x.lng, -x.lat) + pi()) / (2 * pi() / 36)) AS INTEGER) % 36';
  const utilisation =
      'sum(x.c / _e.e) FILTER (WHERE x.c >= 0.5), '
      'count(*) FILTER (WHERE x.c >= 0.5)';
  final stretchCtes = [
    if (segments.isNotEmpty) _stretchCte('_seg', segments),
    if (corners.isNotEmpty) _stretchCte('_cor', corners),
  ];
  final selects = [
    'SELECT 0 AS kind, w.lap::DOUBLE, max(w.sus), '
        'sum(w.c / _e.e) FILTER (WHERE w.c >= 0.5), '
        'count(*) FILTER (WHERE w.c >= 0.5)::DOUBLE, count(*)::DOUBLE '
        'FROM _w w, _e GROUP BY w.lap',
    if (segments.isNotEmpty)
      'SELECT 1, x.lap, g.k, max(abs(x.lat)), $utilisation '
          'FROM _x x JOIN _seg g ON x.ld >= g.s0 AND x.ld < g.s1, _e '
          'GROUP BY x.lap, g.k',
    if (corners.isNotEmpty)
      'SELECT 2, x.lap, g.k, max(abs(x.lat)), $utilisation '
          'FROM _x x JOIN _cor g ON x.ld >= g.s0 AND x.ld <= g.s1, _e '
          'GROUP BY x.lap, g.k',
    'SELECT 3, $band, $angleBin, quantile_cont(x.c, 0.99), count(*), NULL '
        'FROM _x x WHERE x.v IS NOT NULL AND x.c >= 0.2 GROUP BY ALL',
    'SELECT 3, 3, $angleBin, quantile_cont(x.c, 0.99), count(*), NULL '
        'FROM _x x WHERE x.c >= 0.2 GROUP BY ALL',
    'SELECT 4, floor(-x.lat / 0.05), floor(x.lng / 0.05), count(*), NULL, NULL '
        'FROM _x x GROUP BY ALL',
    'SELECT 5, $band, quantile_cont(x.lng, 0.99), -quantile_cont(x.lng, 0.01), '
        'quantile_cont(abs(x.lat), 0.99), NULL FROM _x x WHERE x.v IS NOT NULL '
        'GROUP BY ALL',
    'SELECT 5, 3, quantile_cont(x.lng, 0.99), -quantile_cont(x.lng, 0.01), '
        'quantile_cont(abs(x.lat), 0.99), any_value(_e.e) FROM _x x, _e',
  ];
  return '${_gFrame(c, laps)}, '
      '_w AS (SELECT x.*, CASE WHEN count(*) OVER s = 3 THEN min(x.c) OVER s END '
      'AS sus FROM _x x WINDOW s AS (PARTITION BY x.lap ORDER BY x.r ROWS '
      'BETWEEN 2 PRECEDING AND CURRENT ROW))'
      '${stretchCtes.isEmpty ? '' : ', ${stretchCtes.join(', ')}'} '
      '${selects.join(' UNION ALL ')}';
}

/// One lap's G-G points with where they were and what the pedals did:
/// `(ld, lat, lng, v, throttle, brake)` at 10 Hz, in order.
String lapGgPointsSql(TechniqueChannels c, LapSpan lap) {
  final p = c.pedal;
  final master = '(x.r * ${c.lateral!.masterStride})';
  final value = quoteIdent('value');
  return '${_gFrame(c, [lap])}, '
      '_p AS (SELECT row_number() OVER () - 1 AS r, tu.$value AS tu, '
      'b.$value AS b FROM ${quoteIdent(p.name)} tu '
      'POSITIONAL JOIN ${quoteIdent(c.brake.name)} b) '
      'SELECT x.ld, x.lat, x.lng, x.v, p.tu, p.b FROM _x x '
      'LEFT JOIN _p p ON p.r = ${_rowAt(p, master)} ORDER BY x.r';
}

/// The 10 Hz samples of [laps] that meet the countersteer condition:
/// `(lap, row, t, ld, steer %, lateral G, speed)`. Rare, so few rows.
String countersteerSamplesSql(
  TechniqueChannels c,
  List<LapSpan> laps, {
  required double steeringScale,
}) {
  final steering = c.steering!;
  final master = '(x.r * ${c.lateral!.masterStride})';
  final value = quoteIdent('value');
  return '${_gFrame(c, laps)}, '
      '_s AS (SELECT row_number() OVER () - 1 AS r, '
      '$value * ${sqlDouble(steeringScale)} AS s '
      'FROM ${quoteIdent(steering.name)}), '
      '_y AS (SELECT x.*, s.s FROM _x x JOIN _s s '
      'ON s.r = ${_rowAt(steering, master)}) '
      'SELECT lap, r, t, ld, s, lat, v FROM _y '
      'WHERE s * lat > 0 AND abs(s) >= 5 AND abs(lat) >= 0.5 AND v > 60 '
      'ORDER BY r';
}

/// [laps]' 10 Hz path and speed, for detecting segments and corners:
/// `(lap, t, ld, slowest speed over the 10 Hz row, latitude, longitude)` in
/// order. The speed is the low of the row's ten 100 Hz samples, so a corner's
/// true minimum survives, as `SpeedProfile.of` keeps a bucket's low.
String lapProfilesSql(TechniqueChannels c, List<LapSpan> laps) {
  final speed = c.speed!;
  final latitude = c.latitude!;
  final longitude = c.longitude!;
  final d = c.distance.masterStride;
  final perRow = d ~/ speed.masterStride;
  final value = quoteIdent('value');
  return 'WITH ${masterGridCte()}, ${_lapsCte(laps)}, '
      '_d AS (SELECT row_number() OVER () - 1 AS r, $value AS ld '
      'FROM ${quoteIdent(c.distance.name)}), '
      '${_rows('_la', latitude, 'la')}, ${_rows('_lo', longitude, 'lo')}, '
      '_v0 AS (SELECT row_number() OVER () - 1 AS i, $value AS v '
      'FROM ${quoteIdent(speed.name)}), '
      '_v AS (SELECT i // $perRow AS r, min(v) AS v FROM _v0 GROUP BY 1) '
      'SELECT l.lap, m.t, d.ld, v.v, la.la, lo.lo FROM _d d '
      'JOIN $masterCteName m ON m.mi = d.r * $d '
      'JOIN _laps l ON m.t >= l.ts AND m.t < l.te '
      'JOIN _v v ON v.r = d.r '
      'JOIN _la la ON la.r = ${_rowAt(latitude, 'd.r * $d')} '
      'JOIN _lo lo ON lo.r = ${_rowAt(longitude, 'd.r * $d')} '
      'ORDER BY l.lap, d.r';
}
