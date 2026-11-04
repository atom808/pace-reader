/// Suspension's reads (suspension proposal §7): `suspension_queries.dart`'s
/// rows turned into the domain's types.
library;

import 'dart:typed_data';

import '../../../data/duckdb/suspension_queries.dart';
import '../../../data/duckdb/technique_queries.dart' show LapSpan;
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../domain/platform.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';

/// A channel of the site view's traces.
enum SiteChannel {
  rideFL,
  rideFR,
  rideRL,
  rideRR,
  speed,
  brake,
  throttle,
  steering,
  line,
  lateralG,
  verticalG,
  travelFL,
  travelFR,
  travelRL,
  travelRR,
  frontThird,
  rearThird;

  static SiteChannel ride(Corner c) => values[c.index];
  static SiteChannel travel(Corner c) => values[travelFL.index + c.index];
}

/// One lap's traces through a site's window, in 1 m bins.
class SiteTrace {
  const SiteTrace({
    required this.lap,
    required this.metres,
    required this.channels,
    required this.surface,
  });

  final int lap;

  /// Each bin's metre of `Lap Dist`, ascending.
  final Float64List metres;

  /// NaN where a bin has no value.
  final Map<SiteChannel, Float64List> channels;

  /// Per bin: 0 track, 1 kerb or paint, 2 off track.
  final Uint8List surface;

  Float64List of(SiteChannel c) => channels[c]!;

  /// The value of [c] at the bin nearest [metre]; null outside the trace.
  double? at(SiteChannel c, double metre) {
    if (metres.isEmpty) return null;
    var lo = 0;
    var hi = metres.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (metres[mid] < metre) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if ((metres[lo] - metre).abs() > 3) return null;
    final v = of(c)[lo];
    return v.isNaN ? null : v;
  }
}

class SuspensionRepository {
  SuspensionRepository(this._exec, TelemetryCatalog catalog)
    : channels = SuspensionChannels.of(catalog);

  final TelemetryQueryExecutor _exec;
  final SuspensionChannels? channels;

  SuspensionChannels get _c {
    final c = channels;
    if (c == null) {
      throw StateError(
        'This recording lacks the 100 Hz ride heights Suspension reads.',
      );
    }
    return c;
  }

  static double _d(Object? v) => (v as num).toDouble();
  static double? _dn(Object? v) => (v as num?)?.toDouble();
  static int _i(Object? v) => (v as num).toInt();
  static int? _in(Object? v) => (v as num?)?.toInt();

  /// Every sample under the Close ceiling on [laps], merged into strikes.
  Future<List<Strike>> readStrikes(List<LapSpan> laps) async {
    if (laps.isEmpty) return const [];
    final rows = await _exec.rows(
      strikeSamplesSql(
        _c,
        laps,
        ceilingMetres: strikeFloorMetres + closeBandMetres,
        minSpeed: strikeMinSpeedKph,
      ),
    );
    return mergeStrikes([
      for (final r in rows)
        StrikeSample(
          row: _i(r[0]),
          seconds: _d(r[1]),
          lap: _i(r[2]),
          heights: [_d(r[3]), _d(r[4]), _d(r[5]), _d(r[6])],
          speed: _dn(r[7]),
          brake: _dn(r[8]),
          station: _dn(r[9]),
          line: _dn(r[10]),
          lateralG: _dn(r[11]),
          longitudinalG: _dn(r[12]),
          verticalG: _dn(r[13]),
          surfaces: [_in(r[14]), _in(r[15]), _in(r[16]), _in(r[17])],
        ),
    ]);
  }

  /// Every lap's lowest point at each of [sites], keyed by site.
  Future<Map<int, List<SiteLapLow>>> readSiteLows(
    List<LapSpan> laps,
    List<Site> sites,
  ) async {
    if (laps.isEmpty || sites.isEmpty) return const {};
    final rows = await _exec.rows(
      siteLapMinimaSql(_c, laps, [
        for (final s in sites)
          (
            key: s.key,
            start: s.place - siteSearchMetres,
            end: s.place + siteSearchMetres,
            corner: s.corner.index,
          ),
      ], minSpeed: strikeMinSpeedKph),
    );
    final out = <int, List<SiteLapLow>>{};
    for (final r in rows) {
      (out[_i(r[0])] ??= []).add(
        SiteLapLow(
          lap: _i(r[1]),
          depth: _d(r[2]),
          station: _dn(r[3]),
          line: _dn(r[4]),
          speed: _dn(r[5]),
          maxBrake: _dn(r[6]),
        ),
      );
    }
    return out;
  }

  /// Every lap's traces within `[start, end]`.
  Future<List<SiteTrace>> readSiteTraces(
    List<LapSpan> laps, {
    required double start,
    required double end,
  }) async {
    if (laps.isEmpty) return const [];
    final rows = await _exec.rows(
      siteTracesSql(_c, laps, start: start, end: end),
    );
    // Columns 2.. map to the channels in this order.
    const order = [
      SiteChannel.rideFL,
      SiteChannel.rideFR,
      SiteChannel.rideRL,
      SiteChannel.rideRR,
      SiteChannel.speed,
      SiteChannel.brake,
      SiteChannel.throttle,
      SiteChannel.steering,
      SiteChannel.line,
      SiteChannel.lateralG,
      SiteChannel.verticalG,
      SiteChannel.travelFL,
      SiteChannel.travelFR,
      SiteChannel.travelRL,
      SiteChannel.travelRR,
      SiteChannel.frontThird,
      SiteChannel.rearThird,
    ];
    final out = <SiteTrace>[];
    var start0 = 0;
    while (start0 < rows.length) {
      final lap = _i(rows[start0][0]);
      var e = start0;
      while (e < rows.length && _i(rows[e][0]) == lap) {
        e++;
      }
      Float64List column(int c) => Float64List.fromList([
        for (var r = start0; r < e; r++) _dn(rows[r][c]) ?? double.nan,
      ]);
      out.add(
        SiteTrace(
          lap: lap,
          metres: column(1),
          channels: {
            for (var k = 0; k < order.length; k++) order[k]: column(k + 2),
          },
          surface: Uint8List.fromList([
            for (var r = start0; r < e; r++) _in(rows[r][19]) ?? 0,
          ]),
        ),
      );
      start0 = e;
    }
    return out;
  }

  /// Each lap's platform numbers and the session's third ceilings.
  Future<(List<LapPlatform>, ThirdCeilings)> readPlatform(
    List<LapSpan> laps,
  ) async {
    if (laps.isEmpty) return (const <LapPlatform>[], const ThirdCeilings());
    final rows = await _exec.rows(
      lapPlatformSql(
        _c,
        laps,
        minSpeed: strikeMinSpeedKph,
        packerSpeed: platformSpeedKph,
        packerMarginMetres: packerMarginMetres,
        rollMinG: rollMinG,
      ),
    );
    final out = <LapPlatform>[];
    var ceilings = const ThirdCeilings();
    for (final r in rows) {
      if (_i(r[0]) == 1) {
        ceilings = ThirdCeilings(front: _dn(r[3]), rear: _dn(r[4]));
        continue;
      }
      out.add(
        LapPlatform(
          lap: _i(r[1]),
          samplesAtSpeed: _in(r[2]) ?? 0,
          frontMedian: _dn(r[3]),
          rearMedian: _dn(r[4]),
          frontLowest: _dn(r[5]),
          rearLowest: _dn(r[6]),
          frontPackers: _dn(r[7]),
          rearPackers: _dn(r[8]),
          frontRoll: _dn(r[9]),
          frontRollR: _dn(r[10]),
          rearRoll: _dn(r[11]),
          rearRollR: _dn(r[12]),
          rollSamples: _in(r[13]) ?? 0,
        ),
      );
    }
    return (out, ceilings);
  }

  /// Each lap's damper-speed histogram per corner; empty without travel.
  Future<Map<int, Map<Corner, DamperHistogram>>> readDampers(
    List<LapSpan> laps,
  ) async {
    if (laps.isEmpty || _c.travel == null) return const {};
    final counts = <int, Map<Corner, Map<int, int>>>{};
    for (final r in await _exec.rows(damperHistogramSql(_c, laps))) {
      final corner = Corner.values[_i(r[1])];
      ((counts[_i(r[0])] ??= {})[corner] ??= {})[_i(r[2])] = _i(r[3]);
    }
    return {
      for (final MapEntry(key: lap, value: corners) in counts.entries)
        lap: {
          for (final MapEntry(key: c, value: bins) in corners.entries)
            c: DamperHistogram(bins),
        },
    };
  }
}
