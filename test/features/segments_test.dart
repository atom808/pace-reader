// Segments (comparison proposal §5, step 4): the detector, the frozen
// table's numbers, the losses and the walk, on the two real 5 Hz Sebring
// fixture laps — Base lap 2 (index 1, 1:04.497) against Target lap 4
// (index 3, 1:04.030).
//
// `integration_test/segments_test.dart` runs the same on the fixture at its
// recorded rate: boundaries [353, 705, 1158, 1408, 2403], Segs 2–5
// +0.002 / +0.298 / +0.122 / −0.039 s, and re-anchored Seg 1 +0.1031 and
// Seg 6 −0.0189 s. The 5 Hz laps land within a few metres and milliseconds
// of those, and are asserted against them.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_focus.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_losses.dart';
import 'package:pace_reader/features/driver_comparison/domain/segments.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_course.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

DistanceAxis _axis(LapTelemetry t) => DistanceAxis.fromSeries(t.lapDistance!);

SpeedProfile _profile(LapTelemetry t) =>
    SpeedProfile.of(speed: t.channels['Ground Speed']!, axis: _axis(t));

double _start(LapTelemetry t) => LapAnchor.measure(
  lap: t.lap,
  axis: _axis(t),
  course: sebringCourse,
).startSeconds;

final _length = sebringCourse.wrapLength!;

SegmentTable _table({double threshold = 20}) {
  final detected = SegmentDetector(threshold: threshold)
      .detect(_profile(sebringLap3Telemetry()));
  return SegmentTable(
    key: TrackKey.of(sebringMetadata),
    wrapLength: _length,
    boundaries: detected.boundaries,
    corners: detected.corners,
    canonical: CanonicalLap(
      recording: sebringMetadata.recordingIdentity,
      sessionType: 'Race',
      lapIndex: sebringLap3Index,
      lapNumber: 4,
    ),
    threshold: threshold,
  );
}

LapClock _clock(
  LapTelemetry t, {
  DistanceAxis? axis,
  double? start,
  double extra = 0,
}) {
  final from = start ?? _start(t);
  return LapClock(
    axis: axis ?? _axis(t),
    startSeconds: from,
    endSeconds: from + t.lap.lapTimeSeconds! + extra,
    wrapLength: _length,
  );
}

/// The fixture pair, Base lap 2 against Target lap 4, on re-anchored starts.
StretchComparison _fixturePair() {
  final base = sebringLapTelemetry();
  final target = sebringLap3Telemetry();
  return StretchComparison.segments(
    table: _table(),
    base: _clock(base),
    target: _clock(target),
    delta: LapDelta.between(
      lap: _axis(base),
      lapStartSeconds: _start(base),
      reference: _axis(target),
      referenceStartSeconds: _start(target),
    ),
  );
}

/// [axis] with the car held at [station] for [seconds]: the samples after
/// it all arrive that much later.
DistanceAxis _stopped(DistanceAxis axis, double station, double seconds) {
  final at = axis.firstReachTime(station)!;
  final times = <double>[];
  final distances = <double>[];
  for (var i = 0; i < axis.times.length; i++) {
    if (axis.distances[i] < station) {
      times.add(axis.times[i]);
      distances.add(axis.distances[i]);
    }
  }
  times.addAll([at, at + seconds]);
  distances.addAll([station, station]);
  for (var i = 0; i < axis.times.length; i++) {
    if (axis.distances[i] > station) {
      times.add(axis.times[i] + seconds);
      distances.add(axis.distances[i]);
    }
  }
  return _axisOf(times, distances);
}

DistanceAxis _axisOf(List<double> times, List<double> distances) =>
    DistanceAxis.fromSeries(
      TraceSeries(
        channelName: 'Lap Dist',
        unit: 'm',
        frequencyHz: 10,
        valueColumn: 'value',
        times: Float64List.fromList(times),
        lows: Float64List.fromList(distances),
        highs: Float64List.fromList(distances),
      ),
    );

/// A profile sampled every 10 m from [speed], at 100 m/s.
SpeedProfile _synthetic(double Function(double) speed, {double length = 3000}) {
  final distances = [for (var d = 0.0; d < length; d += 10) d];
  return SpeedProfile(
    Float64List.fromList([for (final d in distances) d / 100]),
    Float64List.fromList(distances),
    Float64List.fromList([for (final d in distances) speed(d)]),
  );
}

double _dip(double d, double at, double depth, {double width = 80}) =>
    depth * math.exp(-math.pow((d - at) / width, 2));

SpeedMinimum _min(double station, double prominence) =>
    SpeedMinimum(station: station, speed: 100, prominence: prominence);

void main() {
  group('the detector', () {
    for (final threshold in [15.0, 20.0]) {
      test('cuts the canonical lap at its top speeds, at $threshold km/h', () {
        // Native: [353, 705, 1158, 1408, 2403].
        expect(
          _table(threshold: threshold).boundaries,
          pairwiseCompare(
            [354, 698, 1156, 1407, 2400],
            (num expected, num actual) => (actual - expected).abs() <= 5,
            'within 5 m of',
          ),
        );
      });
    }

    test("finds the fixture's five corners; the hairpin's second apex stays "
        'inside its segment', () {
      final corners = _table().corners;
      expect(
        [for (final c in corners) c.station.round()],
        [542, 805, 1268, 1494, 2634],
      );
      final minima = speedMinima(_profile(sebringLap3Telemetry()));
      final second = minima.firstWhere((m) => (m.station - 863).abs() < 5);
      // 8.7 km/h at 5 Hz, 9.4 natively: under either threshold.
      expect(second.prominence, lessThan(15));
    });

    test('searches the boundary before the first corner only after the '
        'line', () {
      // A top-speed plateau across the line, as at Daytona: one wide rise
      // centred on the line, peaking 50 m before it.
      final profile = _synthetic(
        (d) =>
            250 +
            _dip(math.min(d, 3000 - d), 0, 70, width: 150) +
            _dip(d, 2950, 10, width: 30) -
            _dip(d, 600, 150) -
            _dip(d, 1800, 130),
      );
      final detected = const SegmentDetector().detect(profile);
      expect([for (final c in detected.corners) c.station], [600, 1800]);
      // Searched across the line, the plateau's 2950 m would have won.
      expect(detected.boundaries.first, inInclusiveRange(0, 100));
      expect(detected.boundaries, everyElement(lessThan(1800)));
    });

    test('per-layout thresholds come from probe 0c', () {
      expect(cornerThresholdFor(TrackKey.of(sebringMetadata)), 20);
      expect(
        cornerThresholdFor(
          const TrackKey('Circuit of the Americas', 'Circuit of the Americas'),
        ),
        30,
      );
      expect(
        cornerThresholdFor(
          const TrackKey(
            'Autódromo José Carlos Pace',
            'Autódromo José Carlos Pace',
          ),
        ),
        15,
      );
    });
  });

  group('clean laps', () {
    Lap timed() => sebringLap3();

    test("a recording's first lap is never clean, timed or not", () {
      expect(
        whyNotCleanBeforeReading(
          lap: timed(),
          recordingStart: true,
          impact: false,
          pitLane: false,
        ),
        UncleanReason.recordingStart,
      );
    });

    test('contact, pit-lane time and no lap time rule a lap out before any '
        'read', () {
      UncleanReason? why({
        bool impact = false,
        bool pitLane = false,
        Lap? lap,
      }) => whyNotCleanBeforeReading(
        lap: lap ?? timed(),
        recordingStart: false,
        impact: impact,
        pitLane: pitLane,
      );
      expect(why(impact: true), UncleanReason.impact);
      expect(why(pitLane: true), UncleanReason.pitLane);
      expect(
        why(lap: timed().copyWith(lapTimeSeconds: null)),
        UncleanReason.untimed,
      );
      expect(why(), isNull);
    });

    test('a stop of 1 s or more under 10 km/h is a stall', () {
      SpeedProfile slowFor(double seconds) {
        final times = [for (var t = 0.0; t <= 10; t += 0.1) t];
        return SpeedProfile(
          Float64List.fromList(times),
          Float64List.fromList([for (final t in times) t * 10]),
          Float64List.fromList([
            for (final t in times) t >= 4 && t < 4 + seconds ? 5.0 : 120.0,
          ]),
        );
      }

      expect(stalled(slowFor(1.25)), isTrue);
      expect(stalled(slowFor(0.75)), isFalse);
      final t = sebringLap3Telemetry();
      expect(
        whyNotClean(
          lap: t.lap,
          recordingStart: false,
          impact: false,
          pitLane: false,
          axis: _axis(t),
          speed: slowFor(1.25),
        ),
        UncleanReason.stall,
      );
    });

    test('a forward jump in lap distance is an excursion', () {
      final axis = _axisOf([0, 0.1, 0.2, 0.3], [0, 6, 40, 46]);
      final t = sebringLap3Telemetry();
      expect(
        whyNotClean(
          lap: t.lap,
          recordingStart: false,
          impact: false,
          pitLane: false,
          axis: axis,
          speed: _profile(t),
        ),
        UncleanReason.distanceJumps,
      );
    });

    test('the fixture lap 4 is clean', () {
      final t = sebringLap3Telemetry();
      expect(
        whyNotClean(
          lap: t.lap,
          recordingStart: false,
          impact: false,
          pitLane: false,
          axis: _axis(t),
          speed: _profile(t),
        ),
        isNull,
      );
    });
  });

  group('unstable corners', () {
    final canonical = DetectedSegments(
      corners: const [
        TrackCorner(station: 500, speed: 100, prominence: 30),
        TrackCorner(station: 1000, speed: 100, prominence: 25),
      ],
      boundaries: const [300, 800],
      minima: [_min(500, 30), _min(1000, 25), _min(1500, 12)],
    );

    test('a kept corner under the threshold on a third of the laps', () {
      final stability = CornerStability.measure(
        canonical: canonical,
        others: [
          [_min(505, 31), _min(995, 26)],
          [_min(498, 29), _min(1004, 24)],
          [_min(502, 30), _min(1001, 15)],
        ],
        threshold: 20,
        wrapLength: 3000,
      );
      expect([for (final c in stability.corners) c.unstable], [false, true]);
      expect(stability.dropped, isEmpty);
    });

    test('a dropped minimum over it on a third of the laps', () {
      final stability = CornerStability.measure(
        canonical: canonical,
        others: [
          [_min(500, 30), _min(1000, 25), _min(1490, 22)],
          [_min(500, 30), _min(1000, 25), _min(1510, 11)],
          [_min(500, 30), _min(1000, 25)],
        ],
        threshold: 20,
        wrapLength: 3000,
      );
      expect([for (final c in stability.corners) c.unstable], [false, false]);
      expect([for (final m in stability.dropped) m.station], [1500]);
    });

    test('two apexes 58 m apart each match their own counterpart', () {
      final matched = matchMinima(
        [_min(803, 170), _min(861, 9)],
        [_min(806, 168), _min(859, 10)],
        _length,
      );
      expect([for (final m in matched) m!.station], [806, 859]);
    });

    test('matching runs round the line', () {
      final matched = matchMinima([_min(10, 30)], [_min(3060, 30)], _length);
      expect(matched.single!.station, 3060);
    });
  });

  group('losses', () {
    test('Segs 2–5 as measured natively, and the ends re-anchored', () {
      final losses = [for (final s in _fixturePair().stretches) s.loss!];
      expect(losses, hasLength(6));
      expect(losses[1], closeTo(0.002, 0.003));
      expect(losses[2], closeTo(0.296, 0.003));
      expect(losses[3], closeTo(0.123, 0.003));
      expect(losses[4], closeTo(-0.039, 0.003));
      // Native, re-anchored: +0.1031 and −0.0189.
      expect(losses[0], closeTo(0.1031, 0.003));
      expect(losses[5], closeTo(-0.0189, 0.003));
    });

    test("telescope to the game's lap-time difference", () {
      expect(
        _fixturePair().total,
        closeTo(sebringLapTimeSeconds - sebringLap3TimeSeconds, 1e-9),
      );
      expect(_fixturePair().total, closeTo(0.4678, 1e-4));
    });

    test('Seg 3 is the worst; Seg 2 and Seg 6 read ≈0', () {
      final pair = _fixturePair();
      expect(pair.worst!.segment.number, 3);
      expect(pair.nearTies, isEmpty);
      expect(
        [for (final s in pair.stretches) s.level],
        [false, true, false, false, false, true],
      );
    });

    test('a 3 s stop at 700 m lands in its own segment, and nowhere else', () {
      final t = sebringLap3Telemetry();
      final start = t.lap.startSeconds;
      final stretches = StretchComparison.segments(
        table: _table(),
        base: _clock(
          t,
          axis: _stopped(_axis(t), 700, 3),
          start: start,
          extra: 3,
        ),
        target: _clock(t, start: start),
      ).stretches;
      for (final s in stretches) {
        expect(
          s.loss,
          closeTo(s.segment.contains(700) ? 3 : 0, 1e-9),
          reason: '${s.segment}',
        );
      }
      expect(stretches[2].segment.contains(700), isTrue);
    });

    test('two losses within 0.05 s are both tagged', () {
      final t = sebringLap3Telemetry();
      final start = t.lap.startSeconds;
      final pair = StretchComparison.segments(
        table: _table(),
        base: _clock(
          t,
          axis: _stopped(_stopped(_axis(t), 400, 0.20), 1200, 0.17),
          start: start,
          extra: 0.37,
        ),
        target: _clock(t, start: start),
      );
      expect(pair.worst!.segment.number, 2);
      expect([for (final s in pair.nearTies) s.segment.number], [2, 4]);
    });

    test('the hairpin turns where Base stops gaining', () {
      final turn = _fixturePair().stretches[2].turn!;
      // Native: −0.267 s at 792 m (§2: "Gained 0.271 s from 705 to 794 m").
      expect(turn.station, closeTo(794, 5));
      expect(turn.first, closeTo(-0.269, 0.005));
      expect(turn.second, closeTo(0.565, 0.005));
      expect(turn.first + turn.second, closeTo(0.296, 0.003));
      expect(turn.stated, isTrue);
    });

    test('a segment lost all the way has no turn to state', () {
      // Seg 4: +0.124 to 1385 m, then −0.001.
      expect(_fixturePair().stretches[3].turn!.stated, isFalse);
    });
  });

  group('the walk', () {
    List<Object> numbers(List<WalkStop> walk) => [
      for (final s in walk) s.recap ? 'recap' : s.number!,
    ];

    test('Most lost: losses, then the level stretches that swing, then the '
        'recap', () {
      // Seg 2 and Seg 6 are level but swing by more than 0.05 s inside,
      // natively too (integration_test/segments_test.dart).
      expect(numbers(_fixturePair().walk(SegmentOrder.mostLost)), [
        3,
        4,
        1,
        2,
        6,
        'recap',
      ]);
    });

    test('Most gained and Track order', () {
      final pair = _fixturePair();
      expect(numbers(pair.walk(SegmentOrder.mostGained)), [5, 2, 6, 'recap']);
      expect(numbers(pair.walk(SegmentOrder.trackOrder)), [
        1,
        2,
        3,
        4,
        5,
        6,
        'recap',
      ]);
    });

    test('stepping holds at the ends, and starts over from off the walk', () {
      final walk = _fixturePair().walk(SegmentOrder.mostLost);
      final pair = _fixturePair();
      WalkStop seg(int n) => WalkStop(pair.byNumber(n)!);
      expect(stepAlong(walk, seg(3), forward: true), seg(4));
      expect(stepAlong(walk, seg(3), forward: false), seg(3));
      expect(
        stepAlong(walk, const WalkStop.recap(), forward: true),
        const WalkStop.recap(),
      );
      expect(stepAlong(walk, seg(5), forward: true), seg(3));
      expect(stepAlong(walk, null, forward: true), seg(3));
    });
  });

  group('sectors', () {
    test("from the game's splits, zoomed to Base's sector lines", () {
      final pair = StretchComparison.sectors(
        base: sebringLap(),
        target: sebringLap3(),
        stations: (
          sector1: sebringCourse.sector1Station,
          sector2: sebringCourse.sector2Station,
          length: _length,
        ),
      );
      final losses = [for (final s in pair.stretches) s.loss!];
      expect(losses[0], closeTo(0.362, 0.0005));
      expect(losses[1], closeTo(0.046, 0.0005));
      expect(losses[2], closeTo(0.060, 0.0005));
      expect(pair.stretches.first.segment.name, 'S1');
      expect(pair.stretches[1].segment.start, sebringCourse.sector1Station);
      expect(pair.worst!.segment.name, 'S1');
    });

    test('a split written as 0.0 is not compared', () {
      final pair = StretchComparison.sectors(
        base: sebringLap().copyWith(
          sectors: SectorTimes.fromCumulative(
            sector1: sebringLapSector1,
            sector2Cumulative: 0.0,
            lapTimeSeconds: sebringLapTimeSeconds,
          ),
        ),
        target: sebringLap3(),
        stations: (sector1: null, sector2: null, length: null),
      );
      expect(
        [for (final s in pair.stretches) s.measured],
        [true, false, false],
      );
    });
  });
}
