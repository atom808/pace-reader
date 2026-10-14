/// Driving Technique's reads (SPEC.md §8.13.9): `technique_queries.dart`'s
/// rows turned into plain numbers.
library;

import 'dart:typed_data';

import '../../../data/duckdb/technique_queries.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../domain/countersteer.dart';
import '../domain/pedal_spans.dart';
import '../domain/shifts.dart';
import 'technique_reads.dart';

/// Reads one open file for the technique screen.
///
/// A file lacking a channel loses the measures that need it rather than
/// failing: the G-G needs both G channels, countersteer needs steering, the
/// shift panel needs `Gear` and `Engine RPM`. [channels] is null only when
/// the pedal frame itself cannot be built, and then nothing here is read.
class TechniqueRepository {
  TechniqueRepository(this._exec, this._catalog)
    : channels = TechniqueChannels.of(_catalog);

  final TelemetryQueryExecutor _exec;
  final TelemetryCatalog _catalog;
  final TechniqueChannels? channels;

  TechniqueChannels get _c {
    final c = channels;
    if (c == null) {
      throw StateError(
        'This recording lacks the pedal channels Driving Technique reads.',
      );
    }
    return c;
  }

  static double _d(Object? v) => (v as num).toDouble();
  static double? _dn(Object? v) => (v as num?)?.toDouble();
  static int _i(Object? v) => (v as num).toInt();

  static bool _truthy(Object? value) => switch (value) {
    final bool b => b,
    final num n => n != 0,
    _ => false,
  };

  /// The session's largest |`Steering Pos`|; null without the channel.
  Future<double?> readSteeringMaxAbs() async {
    if (!_catalog.hasChannel(techniqueSteeringChannel)) return null;
    return _dn(await _exec.scalar(steeringMaxAbsSql()));
  }

  /// An on/off event's rows, `(seconds, on)`; empty without the event.
  Future<List<(double, bool)>> readFlag(String eventName) async {
    if (!_catalog.hasEvent(eventName)) return const [];
    return [
      for (final row in await _exec.rows(flagRowsSql(eventName)))
        (_d(row[0]), _truthy(row[1])),
    ];
  }

  /// The pedal frame's totals over [laps], and over each stretch given.
  Future<PedalReads> readPedalStats(
    List<LapSpan> laps, {
    required double steeringScale,
    List<StretchSpan> segments = const [],
    List<StretchSpan> corners = const [],
  }) async {
    if (laps.isEmpty) return const PedalReads(laps: {});
    final rows = await _exec.rows(
      lapPedalStatsSql(
        _c,
        laps,
        steeringScale: steeringScale,
        segments: segments,
        corners: corners,
      ),
    );
    final hz = _c.pedal.frequencyHz;
    final perLap = <int, PedalTotals>{};
    final perSegment = <int, Map<int, PedalTotals>>{};
    final perCorner = <int, Map<int, PedalTotals>>{};
    for (final row in rows) {
      final totals = PedalTotals(
        samples: _i(row[3]),
        hz: hz,
        braking: _i(row[4]),
        overlap: _i(row[5]),
        coast: _i(row[6]),
        fullThrottle: _i(row[7]),
        trail: _i(row[8]),
        tc: _i(row[9]),
        abs: _i(row[10]),
        coastMetres: _d(row[11]),
        slowest: _dn(row[12]),
        steerAtApex: _dn(row[13]),
      );
      final lap = _i(row[1]);
      switch (_i(row[0])) {
        case 0:
          perLap[lap] = totals;
        case 1:
          (perSegment[lap] ??= {})[_i(row[2])] = totals;
        case 2:
          (perCorner[lap] ??= {})[_i(row[2])] = totals;
      }
    }
    return PedalReads(laps: perLap, segments: perSegment, corners: perCorner);
  }

  /// Each lap's pedal states, run-length encoded.
  Future<Map<int, List<PedalRun>>> readPedalRuns(
    List<LapSpan> laps, {
    required double steeringScale,
  }) async {
    if (laps.isEmpty) return const {};
    final out = <int, List<PedalRun>>{};
    for (final row in await _exec.rows(
      pedalRunsSql(_c, laps, steeringScale: steeringScale),
    )) {
      (out[_i(row[0])] ??= []).add(
        PedalRun(PedalState.values[_i(row[1])], _i(row[2])),
      );
    }
    return out;
  }

  /// [eventName]'s merged episodes per lap; empty without the event.
  Future<Map<int, int>> readAidEpisodes(
    String eventName,
    List<LapSpan> laps,
  ) async {
    if (laps.isEmpty || !_catalog.hasEvent(eventName)) return const {};
    return {
      for (final row in await _exec.rows(aidEpisodesSql(eventName, laps)))
        _i(row[0]): _i(row[1]),
    };
  }

  /// Every `Gear` row; empty without the event.
  Future<List<GearRow>> readGearRows() async {
    if (!_catalog.hasEvent(techniqueGearEvent)) return const [];
    return [
      for (final row in await _exec.rows(gearRowsSql()))
        GearRow(_d(row[0]), _i(row[1])),
    ];
  }

  /// Every upshift's neutral row with its RPM, da, pedal and limiter time.
  Future<List<UpshiftRead>> readUpshifts({double? limiter}) async {
    if (!_catalog.hasEvent(techniqueGearEvent)) return const [];
    return [
      for (final row in await _exec.rows(upshiftReadsSql(_c, limiter: limiter)))
        UpshiftRead(
          seconds: _d(row[0]),
          rpm: _dn(row[1]),
          accelerationChange: _dn(row[2]),
          pedal: _dn(row[3]),
          limiterSeconds: _dn(row[4]) ?? 0,
        ),
    ];
  }

  /// The G frame reduced over [laps]; null without both G channels.
  Future<GgReads?> readGg(
    List<LapSpan> laps, {
    List<StretchSpan> segments = const [],
    List<StretchSpan> corners = const [],
  }) async {
    if (laps.isEmpty || !_c.hasG) return null;
    final rows = await _exec.rows(
      lapGgSql(_c, laps, segments: segments, corners: corners),
    );
    final perLap = <int, GgLap>{};
    final perSegment = <int, Map<int, GgStretch>>{};
    final perCorner = <int, Map<int, GgStretch>>{};
    final envelope = <SpeedBand, Map<int, ({double g, int n})>>{};
    final density = <(int, int), int>{};
    final limits = <SpeedBand, GgLimits>{};
    double? e;
    for (final row in rows) {
      switch (_i(row[0])) {
        case 0:
          perLap[_i(row[1])] = GgLap(
            sustainedPeak: _dn(row[2]),
            utilisationSum: _dn(row[3]) ?? 0,
            utilisationSamples: _i(row[4]),
            samples: _i(row[5]),
          );
        case final kind && (1 || 2):
          final stretch = GgStretch(
            peakLateral: _dn(row[3]),
            utilisationSum: _dn(row[4]) ?? 0,
            utilisationSamples: _i(row[5]),
          );
          final into = kind == 1 ? perSegment : perCorner;
          (into[_i(row[1])] ??= {})[_i(row[2])] = stretch;
        case 3:
          final band = SpeedBand.values[_i(row[1])];
          (envelope[band] ??= {})[_i(row[2])] = (g: _d(row[3]), n: _i(row[4]));
        case 4:
          density[(_i(row[1]), _i(row[2]))] = _i(row[3]);
        case 5:
          final band = SpeedBand.values[_i(row[1])];
          limits[band] = GgLimits(
            braking: _d(row[2]),
            traction: _d(row[3]),
            lateral: _d(row[4]),
          );
          if (band == SpeedBand.all) e = _dn(row[5]);
      }
    }
    return GgReads(
      laps: perLap,
      segments: perSegment,
      corners: perCorner,
      envelope: envelope,
      density: density,
      limits: limits,
      e: e,
    );
  }

  /// One lap's G-G points; empty without both G channels.
  Future<List<GgPoint>> readLapGgPoints(LapSpan lap) async {
    if (!_c.hasG) return const [];
    return [
      for (final row in await _exec.rows(lapGgPointsSql(_c, lap)))
        if (row[0] != null)
          GgPoint(
            station: _d(row[0]),
            lateral: _d(row[1]),
            longitudinal: _d(row[2]),
            speed: _dn(row[3]),
            throttle: _dn(row[4]),
            brake: _dn(row[5]),
          ),
    ];
  }

  /// The samples of [laps] that meet the countersteer condition; empty
  /// without steering or the G channels.
  Future<List<SteerSample>> readCountersteerSamples(
    List<LapSpan> laps, {
    required double steeringScale,
  }) async {
    if (laps.isEmpty || !_c.hasG || _c.steering == null || _c.speed == null) {
      return const [];
    }
    return [
      for (final row in await _exec.rows(
        countersteerSamplesSql(_c, laps, steeringScale: steeringScale),
      ))
        SteerSample(
          lap: _i(row[0]),
          index: _i(row[1]),
          seconds: _d(row[2]),
          station: _dn(row[3]) ?? 0,
          steer: _d(row[4]),
          lateralG: _d(row[5]),
          speed: _d(row[6]),
        ),
    ];
  }

  /// [laps]' 10 Hz path and speed; empty without position or speed.
  Future<List<LapProfileRead>> readLapProfiles(List<LapSpan> laps) async {
    if (laps.isEmpty || !_c.hasPosition || _c.speed == null) return const [];
    final rows = await _exec.rows(lapProfilesSql(_c, laps));
    final out = <LapProfileRead>[];
    var start = 0;
    while (start < rows.length) {
      final lap = _i(rows[start][0]);
      var end = start;
      while (end < rows.length && _i(rows[end][0]) == lap) {
        end++;
      }
      Float64List column(int c) => Float64List.fromList([
        for (var r = start; r < end; r++) _dn(rows[r][c]) ?? double.nan,
      ]);
      out.add(
        LapProfileRead(
          lap: lap,
          times: column(1),
          distances: column(2),
          speeds: column(3),
          latitudes: column(4),
          longitudes: column(5),
        ),
      );
      start = end;
    }
    return out;
  }
}
