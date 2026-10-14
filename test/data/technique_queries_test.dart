// Driving Technique's SQL for the two ways a build records `TC` (SPEC.md
// §5.1): an event in every file before 2026-10-13, a 100 Hz channel in a
// newer build. `integration_test/technique_test.dart` runs both on the
// fixtures and checks the measures agree; this checks, without a database,
// which read each one gets — so CI sees it too.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/technique_queries.dart';
import 'package:pace_reader/data/models/models.dart';

/// The newer build's Le Mans race: 265,740 master rows.
const _masterRows = 265740;

ChannelDescriptor _channel(String name, int hz, {int? rows}) =>
    ChannelDescriptor(
      name: name,
      frequencyHz: hz,
      unit: '',
      valueColumnCount: 1,
      rowCount: rows ?? (_masterRows * hz / 100).ceil(),
    );

EventDescriptor _event(String name) =>
    EventDescriptor(name: name, unit: '', valueColumnCount: 1, rowCount: 2);

TelemetryCatalog _catalog({
  List<ChannelDescriptor> channels = const [],
  List<EventDescriptor> events = const [],
}) => TelemetryCatalog(
  channels: [
    _channel('GPS Time', 100),
    _channel(techniquePedalChannel, 50),
    _channel(techniqueBrakeChannel, 50),
    _channel(techniqueDistanceChannel, 10),
    ...channels,
  ],
  events: [_event(techniqueAbsEvent), ...events],
  masterRowCount: _masterRows,
  origin: 0,
  endSeconds: _masterRows / 100,
);

const _laps = [(lap: 1, start: 100.0, end: 200.0)];

void main() {
  final asEvent = TechniqueChannels.of(
    _catalog(events: [_event(techniqueTcEvent)]),
  )!;
  final asChannel = TechniqueChannels.of(
    _catalog(channels: [_channel(techniqueTcEvent, 100)]),
  )!;

  group('TC as an event', () {
    test('is read from the event', () {
      expect(asEvent.hasTc, isTrue);
      expect(asEvent.tcChannel, isNull);
    });

    test('joins the pedal frame as of each sample', () {
      final sql = lapPedalStatsSql(asEvent, _laps, steeringScale: 1);
      expect(sql, contains('ASOF LEFT JOIN "TC" tc ON f.t >= tc.ts'));
      expect(sql, isNot(contains('_tc')));
    });

    test('merges episodes from the event rows', () {
      final sql = aidEpisodesSql(techniqueTcEvent, _laps);
      expect(sql, contains('FROM "TC")'));
      expect(sql, isNot(contains('_ev')));
    });
  });

  group('TC as a channel', () {
    test('is read from the channel', () {
      expect(asChannel.hasTc, isTrue);
      expect(asChannel.tcChannel?.name, techniqueTcEvent);
    });

    test('joins the pedal frame at master row 2i, by row number', () {
      final sql = lapPedalStatsSql(asChannel, _laps, steeringScale: 1);
      expect(sql, contains('_tc AS (SELECT row_number() OVER () - 1 AS r'));
      expect(sql, contains('LEFT JOIN _tc tc ON tc.r = (f.i * 2)'));
      expect(sql, contains('coalesce(tc.v, false) AS tc'));
      expect(sql, isNot(contains('ASOF LEFT JOIN "TC"')));
      // ABS is still an event in that build.
      expect(sql, contains('ASOF LEFT JOIN "ABS" ab ON f.t >= ab.ts'));
    });

    test('merges episodes from its value changes, timestamped after', () {
      final sql = aidEpisodesSql(
        techniqueTcEvent,
        _laps,
        channel: asChannel.tcChannel,
      );
      expect(sql, contains('lag(v) OVER (ORDER BY r)'));
      expect(sql, contains('WHERE pv IS DISTINCT FROM v'));
      expect(sql, contains('JOIN _master m ON m.mi = x.r)'));
      expect(sql, contains('"value" AS v FROM _ev)'));
    });

    test('maps a slower channel\'s rows by its stride', () {
      final sql = aidEpisodesSql(
        techniqueTcEvent,
        _laps,
        channel: _channel(techniqueTcEvent, 50),
      );
      expect(sql, contains('m.mi = (x.r * 2)'));
    });

    test('off the master grid, is not read at all', () {
      final c = TechniqueChannels.of(
        _catalog(channels: [_channel(techniqueTcEvent, 100, rows: 1000)]),
      )!;
      expect(c.hasTc, isFalse);
      expect(c.tcChannel, isNull);
      expect(
        lapPedalStatsSql(c, _laps, steeringScale: 1),
        contains('false AS tc'),
      );
    });
  });

  test('the pedal runs read no aid in either layout', () {
    for (final c in [asEvent, asChannel]) {
      final sql = pedalRunsSql(c, _laps, steeringScale: 1);
      expect(sql, isNot(contains('"TC"')));
      expect(sql, isNot(contains('_tc')));
    }
  });
}
