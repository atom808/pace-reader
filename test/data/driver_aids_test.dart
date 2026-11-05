// The trace's driver-aid pulses (driver-aids proposal §3): the merge rule
// on constructed edges, and the channel-edge SQL for a build that records
// `TC` as a channel (SPEC.md §5.1). `integration_test/driver_aids_test.dart`
// checks the episode counts against Driving Technique's on both fixtures.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/aid_queries.dart';
import 'package:pace_reader/data/models/models.dart';

/// [pulses] as `(start, end)` pairs turned into the edges an event writes.
List<(double, bool)> _edges(List<(double, double)> pulses) => [
  for (final (a, b) in pulses) ...[(a, true), (b, false)],
];

void main() {
  group('AidPulses.fromEdges', () {
    test('pulses within the merge gap are one episode', () {
      final aid = AidPulses.fromEdges(
        'TC',
        _edges([(10.00, 10.015), (10.02, 10.035), (10.04, 10.06)]),
        start: 0,
        end: 100,
      );
      expect(aid.pulseCount, 3);
      expect(aid.episodes, [const AidEpisode(10.00, 10.06, 3)]);
      expect(aid.episodeCount, 1);
      expect(aid.activeSeconds, closeTo(0.05, 1e-9));
    });

    test('a gap wider than 0.25 s starts another episode', () {
      final aid = AidPulses.fromEdges(
        'ABS',
        _edges([(10.0, 10.02), (10.26, 10.28), (10.50, 10.52)]),
        start: 0,
        end: 100,
      );
      // 10.26 − 10.02 = 0.24 merges; 10.50 − 10.28 = 0.22 merges too.
      expect(aid.episodeCount, 1);

      final apart = AidPulses.fromEdges(
        'ABS',
        _edges([(10.0, 10.02), (10.30, 10.32)]),
        start: 0,
        end: 100,
      );
      expect(apart.episodes, [
        const AidEpisode(10.0, 10.02, 1),
        const AidEpisode(10.30, 10.32, 1),
      ]);
    });

    test('an episode begun before the window is drawn, not counted', () {
      final aid = AidPulses.fromEdges(
        'TC',
        _edges([(49.8, 49.9), (50.0, 50.1), (60.0, 60.1)]),
        start: 49.95,
        end: 70,
      );
      expect(aid.episodeCount, 1);
      expect(aid.episodes.first, const AidEpisode(49.95, 50.1, 2));
      // Pulses are clipped to the window; the one before it is gone.
      expect(aid.starts, [50.0, 60.0]);
    });

    test('an episode running past the window is counted and clipped', () {
      final aid = AidPulses.fromEdges(
        'TC',
        _edges([(69.9, 70.05), (70.1, 70.2)]),
        start: 0,
        end: 70,
      );
      expect(aid.episodeCount, 1);
      expect(aid.episodes, [const AidEpisode(69.9, 70, 2)]);
      expect(aid.ends.last, 70);
    });

    test('an episode starting after the window is neither', () {
      final aid = AidPulses.fromEdges(
        'TC',
        _edges([(70.5, 70.6)]),
        start: 0,
        end: 70,
      );
      expect(aid.isEmpty, isTrue);
      expect(aid.episodes, isEmpty);
      expect(aid.episodeCount, 0);
    });

    test('an on edge holds to the next edge, the last one for 10 ms', () {
      // `aidEpisodesSql`'s rule: two on rows in a row are one pulse each,
      // the first ending where the second begins.
      final aid = AidPulses.fromEdges(
        'TC',
        [(5.0, true), (5.02, true)],
        start: 0,
        end: 10,
      );
      expect(aid.starts, [5.0, 5.02]);
      expect(aid.ends[0], 5.02);
      expect(aid.ends[1], closeTo(5.03, 1e-9));
    });

    test('a reach-back off row adds nothing', () {
      final aid = AidPulses.fromEdges(
        'ABS',
        [(-3.0, false)],
        start: 0,
        end: 10,
      );
      expect(aid.isEmpty, isTrue);
      expect(aid.episodeCount, 0);
    });

    test('episodeAt finds the episode under a time', () {
      final aid = AidPulses.fromEdges(
        'TC',
        _edges([(1.0, 1.1), (2.0, 2.1), (3.0, 3.2)]),
        start: 0,
        end: 10,
      );
      expect(aid.episodeAt(2.05), const AidEpisode(2.0, 2.1, 1));
      expect(aid.episodeAt(3.2), const AidEpisode(3.0, 3.2, 1));
      expect(aid.episodeAt(1.5), isNull);
      expect(aid.episodeAt(0.5), isNull);
      expect(aid.episodeAt(9), isNull);
    });
  });

  group('channelEdgesSql', () {
    ChannelDescriptor channel(int hz) => ChannelDescriptor(
      name: 'TC',
      frequencyHz: hz,
      unit: '',
      valueColumnCount: 1,
      rowCount: 1000 * hz ~/ 100,
    );

    test('finds the changes in row order, then timestamps them', () {
      final sql = channelEdgesSql(
        channel(100),
        1000,
        rowStart: 200,
        rowEndExclusive: 400,
      );
      expect(sql, contains('WHERE r >= 200 AND r < 400'));
      expect(sql, contains('lag(v) OVER (ORDER BY r)'));
      // The range's first row has no previous one, so it is kept: the value
      // in force when the window opens.
      expect(sql, contains('WHERE pv IS DISTINCT FROM v'));
      expect(sql, contains('JOIN _master m ON m.mi = x.r'));
      expect(sql, endsWith('ORDER BY x.r'));
    });

    test("maps a slower channel's rows by its stride", () {
      final sql = channelEdgesSql(
        channel(50),
        1000,
        rowStart: 0,
        rowEndExclusive: 10,
      );
      expect(sql, contains('m.mi = (x.r * 2)'));
    });

    test('refuses an empty range', () {
      expect(
        () => channelEdgesSql(
          channel(100),
          1000,
          rowStart: 5,
          rowEndExclusive: 5,
        ),
        throwsArgumentError,
      );
    });
  });
}
