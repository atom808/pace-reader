// Suspension's SQL (suspension proposal §7), without a database: which
// channels each query reads and what it leaves out when a file lacks one.
// The queries themselves were run on the Le Mans 24 Oct race (775,594
// master rows): the Indianapolis site's laps reach their lowest at
// 9,638–9,640 m, and the third ceilings come out at 9.79 / 14.51 mm.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/suspension_queries.dart';
import 'package:pace_reader/data/models/models.dart';

const _masterRows = 775594;

ChannelDescriptor _channel(String name, int hz, {int columns = 1}) =>
    ChannelDescriptor(
      name: name,
      frequencyHz: hz,
      unit: '',
      valueColumnCount: columns,
      rowCount: (_masterRows * hz / 100).ceil(),
    );

TelemetryCatalog _catalog({
  bool rideHeights = true,
  bool third = true,
  bool surface = true,
}) => TelemetryCatalog(
  channels: [
    _channel('GPS Time', 100),
    if (rideHeights) _channel(suspensionRideHeightChannel, 100, columns: 4),
    _channel(suspensionTravelChannel, 100, columns: 4),
    _channel(suspensionSpeedChannel, 100),
    _channel(suspensionBrakeChannel, 50),
    _channel(suspensionThrottleChannel, 50),
    _channel(suspensionDistanceChannel, 10),
    _channel(suspensionLineChannel, 10),
    _channel(suspensionLateralGChannel, 10),
    _channel(suspensionLongitudinalGChannel, 10),
    _channel(suspensionVerticalGChannel, 10),
    if (third) ...[
      _channel(suspensionFrontThirdChannel, 100),
      _channel(suspensionRearThirdChannel, 100),
    ],
  ],
  events: [
    if (surface)
      const EventDescriptor(
        name: suspensionSurfaceEvent,
        unit: '',
        valueColumnCount: 4,
        rowCount: 10,
      ),
  ],
  masterRowCount: _masterRows,
  origin: 0,
  endSeconds: _masterRows / 100,
);

const _laps = [(lap: 80, start: 17471.84, end: 17681.68)];

void main() {
  test('nothing is read without 100 Hz ride heights', () {
    expect(SuspensionChannels.of(_catalog(rideHeights: false)), isNull);
  });

  test('the strike read filters ride heights before joining anything', () {
    final c = SuspensionChannels.of(_catalog())!;
    final sql = strikeSamplesSql(c, _laps, ceilingMetres: 0.009, minSpeed: 60);
    expect(sql, contains('least(h1, h2, h3, h4) < 0.009'));
    expect(sql, contains('greatest(h1, h2, h3, h4) < $rideHeightGlitchMetres'));
    expect(sql, contains('ASOF LEFT JOIN "SurfaceTypes"'));
    expect(sql, contains('WHERE v > 60.0'));
    // Brake is 50 Hz: master row mi reads its row mi // 2.
    expect(sql, contains('_b.r = (k.mi // 2)'));
    // Lap Dist is interpolated, but never across the wrap.
    expect(sql, contains('_d.d1 >= _d.d AND _d.d1 - _d.d < 50'));
  });

  test('a file without the surface event reads every strike as track', () {
    final c = SuspensionChannels.of(_catalog(surface: false))!;
    final sql = strikeSamplesSql(c, _laps, ceilingMetres: 0.009, minSpeed: 60);
    expect(sql, isNot(contains('SurfaceTypes')));
    expect(sql, contains('NULL::INTEGER AS sf1'));
  });

  test('without third channels the platform has no ceilings or packers', () {
    final c = SuspensionChannels.of(_catalog(third: false))!;
    expect(c.hasThirdChannels, isFalse);
    final sql = lapPlatformSql(
      c,
      _laps,
      minSpeed: 60,
      packerSpeed: 100,
      packerMarginMetres: 0.0003,
      rollMinG: 0.3,
    );
    expect(sql, contains('NULL::DOUBLE AS fc'));
    expect(sql, isNot(contains('quantile_cont(f3')));
  });

  test('site minima take the chosen corner within each span', () {
    final c = SuspensionChannels.of(_catalog())!;
    final sql = siteLapMinimaSql(c, _laps, [
      (key: 3, start: 9615, end: 9665, corner: 2),
    ], minSpeed: 60);
    expect(sql, contains('(3, 9615.0, 9665.0, 2)'));
    expect(sql, contains('arg_min(pl, h)'));
  });

  test('damper bins cover every edge, bump positive', () {
    final c = SuspensionChannels.of(_catalog())!;
    final sql = damperHistogramSql(c, _laps);
    for (final edge in damperSpeedEdges.skip(1)) {
      expect(sql, contains('WHEN a < ${edge.toDouble()}'));
    }
    expect(sql, contains('* 50000.0'));
  });
}
