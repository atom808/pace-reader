// Driving Technique's pure rules on constructed arrays (SPEC.md §8.13.9).

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/reference/tyre_compound.dart';
import 'package:pace_reader/features/driving_technique/domain/conditions_lens.dart';
import 'package:pace_reader/features/driving_technique/domain/countersteer.dart';
import 'package:pace_reader/features/driving_technique/domain/geometric_corners.dart';
import 'package:pace_reader/features/driving_technique/domain/pedal_spans.dart';
import 'package:pace_reader/features/driving_technique/domain/racing_laps.dart';
import 'package:pace_reader/features/driving_technique/domain/shifts.dart';
import 'package:pace_reader/features/driving_technique/domain/steering.dart';

Lap _lap(int index, double start, double? end, {double? time = 60}) => Lap(
  index: index,
  startSeconds: start,
  endSeconds: end,
  lapTimeSeconds: time,
  sectors: const SectorTimes(),
);

/// A closed course drawn as headings: straights and constant-radius arcs.
/// Returns north-up metres, one point per [step] metres.
(List<double>, List<double>) _course(
  List<(double length, double radius)> pieces, {
  double step = 1,
}) {
  final xs = <double>[0];
  final ys = <double>[0];
  var heading = 0.0;
  for (final (length, radius) in pieces) {
    final n = (length / step).round();
    for (var i = 0; i < n; i++) {
      if (radius != 0) heading += step / radius;
      xs.add(xs.last + step * math.cos(heading));
      ys.add(ys.last + step * math.sin(heading));
    }
  }
  return (xs, ys);
}

/// [xs]/[ys] as a lap's 10 Hz position channels, `Lap Dist` from 0, with a
/// sideways wobble of [noise] metres.
LapPathRead _pathLap(
  int lap,
  List<double> xs,
  List<double> ys, {
  double every = 4,
  double noise = 0,
  int seed = 0,
}) {
  final random = math.Random(seed);
  final d = <double>[];
  final lat = <double>[];
  final lon = <double>[];
  const lat0 = 50.0;
  final lonScale = 111320.0 * math.cos(lat0 * math.pi / 180);
  final stride = every.round();
  for (var i = 0; i < xs.length; i += stride) {
    final wobble = noise == 0 ? 0.0 : (random.nextDouble() - 0.5) * 2 * noise;
    d.add(i.toDouble());
    lat.add(lat0 + (ys[i] + wobble) / 111320.0);
    lon.add((xs[i] + wobble) / lonScale);
  }
  return LapPathRead(
    lap: lap,
    distances: Float64List.fromList(d),
    latitudes: Float64List.fromList(lat),
    longitudes: Float64List.fromList(lon),
  );
}

void main() {
  group('racing laps', () {
    test('a lap that starts with In Pits already on is not a racing lap', () {
      // Imola's Hypercar race: the pit lane switched on 60 s before lap 1
      // and off 13.5 s into it. No `In Pits` row falls inside the lap.
      final lap = _lap(1, 100, 200);
      expect(
        whyNotRacing(
          lap,
          pitLane: const [PitInterval(40, 113.5)],
          limiter: const [],
        ),
        NotRacing.pitLane,
      );
      expect(
        whyNotRacing(
          lap,
          pitLane: const [],
          limiter: const [PitInterval(40, 113.5)],
        ),
        NotRacing.limiter,
      );
      expect(
        whyNotRacing(
          lap,
          pitLane: const [PitInterval(40, 100)],
          limiter: const [],
        ),
        isNull,
        reason: 'a stay that ended as the lap began is not part of it',
      );
    });

    test('the first lap, an untimed lap and an open lap are not', () {
      expect(
        whyNotRacing(_lap(0, 0, 50), pitLane: const [], limiter: const []),
        NotRacing.recordingStart,
      );
      expect(
        whyNotRacing(
          _lap(2, 0, 50, time: null),
          pitLane: const [],
          limiter: const [],
        ),
        NotRacing.untimed,
      );
      expect(
        whyNotRacing(_lap(3, 0, null), pitLane: const [], limiter: const []),
        NotRacing.open,
      );
      expect(
        racingLaps(
          [_lap(0, 0, 10), _lap(1, 10, 70), _lap(2, 70, 130)],
          pitLane: const [PitInterval(120)],
          limiter: const [],
        ).map((l) => l.index),
        [1],
      );
    });
  });

  group('steering scale', () {
    test('a fraction is read as percent, a percentage as itself', () {
      expect(steeringScale(0.82), 100);
      expect(steeringScale(1.0), 100);
      expect(steeringScale(51.3), 1);
      expect(steeringScale(null), 1);
      expect(steeringScale(0), 1);
    });
  });

  group('shifts', () {
    test('a shift is a change between consecutive non-zero gears', () {
      final shifts = shiftsFrom(const [
        GearRow(0, 1),
        GearRow(1.0, 0),
        GearRow(1.0425, 2),
        GearRow(3.0, 0),
        GearRow(3.0425, 3),
        GearRow(5.0, 0),
        GearRow(5.1, 2),
        GearRow(9.0, 0),
        GearRow(9.2, -1),
        GearRow(10, 0),
        GearRow(10.5, 1),
      ]);
      expect(shifts.map((s) => '${s.from}${s.to}'), ['12', '23', '32']);
      expect(shifts.where((s) => s.isUp), hasLength(2));
      expect(shifts.first.seconds, 1.0, reason: 'timed at the neutral row');
      expect(shifts.every((s) => s.neutral), isTrue);
    });

    test('a direct change with no neutral row still counts, once', () {
      final shifts = shiftsFrom(const [
        GearRow(0, 2),
        GearRow(1, 3),
        GearRow(2, 3),
      ]);
      expect(shifts, hasLength(1));
      expect(shifts.single.neutral, isFalse);
      expect(shifts.single.seconds, 1);
    });

    test('limiter bands', () {
      const l = 7500.0;
      expect(ShiftBand.of(7490, l), ShiftBand.atLimiter);
      expect(ShiftBand.of(7480, l), ShiftBand.atLimiter);
      expect(ShiftBand.of(7479, l), ShiftBand.late);
      expect(ShiftBand.of(7300, l), ShiftBand.late);
      expect(ShiftBand.of(7299, l), ShiftBand.early);
      expect(ShiftBand.of(7000, l), ShiftBand.early);
      expect(ShiftBand.of(6800, l), ShiftBand.short);
      expect(ShiftBand.of(6400, l), ShiftBand.wellBefore);
      expect(libraryAcceleration('GT3', ShiftBand.early)?.da, -0.11);
      expect(libraryAcceleration('Hyper', ShiftBand.late)?.n, 695);
      expect(libraryAcceleration('LMP3', ShiftBand.late), isNull);
    });
  });

  group('pedal spans', () {
    PedalRun r(PedalState s, int n) => PedalRun(s, n);
    const t = PedalState.throttle;
    const b = PedalState.brake;
    const o = PedalState.overlap;
    const c = PedalState.coast;
    const x = PedalState.transit;

    test('overlap by what the pedals did either side, through transits', () {
      final spans = classifySpans([
        r(t, 100), r(o, 5), r(b, 50), // entry
        r(x, 1), r(o, 3), r(x, 1), r(t, 80), // exit, through transits
        r(o, 2), r(t, 40), // dab
        r(c, 10), r(o, 4), r(b, 20), // other: a coast before it
      ]);
      expect(spans.overlap[OverlapKind.entry], 5);
      expect(spans.overlap[OverlapKind.exit], 3);
      expect(spans.overlap[OverlapKind.dab], 2);
      expect(spans.overlap[OverlapKind.other], 4);
      expect(spans.overlapSamples, 14);
      expect(spans.mainOverlap, OverlapKind.entry);
    });

    test('coast spans: lift-and-coast and mid-corner', () {
      final spans = classifySpans([
        r(t, 100), r(c, 20), r(x, 1), r(b, 50), // lift and coast
        r(c, 8), r(t, 60), // mid-corner
        r(c, 12), r(t, 10), r(c, 3), // other: the lap's edge after it
      ]);
      expect(spans.coast[CoastKind.liftAndCoast], 20);
      expect(spans.coast[CoastKind.midCorner], 8);
      expect(spans.coast[CoastKind.other], 15, reason: 'T→T and the edge');
      expect(spans.liftAndCoastSpans, 1);
      expect(spans.coastSamples, 43);
    });
  });

  group('countersteer', () {
    SteerSample s(int i, double steer, {int lap = 1}) => SteerSample(
      lap: lap,
      index: i,
      seconds: i / 10,
      station: i * 3.0,
      steer: steer,
      lateralG: -1.4,
      speed: 120,
    );

    test('runs of three or more peaking at 20 % lock', () {
      final episodes = countersteerEpisodes([
        // Spa qualifying's shape: building to −81.5 % opposite lock.
        for (var i = 0; i < 11; i++) s(100 + i, -(7 + i * 7.0)),
        // Too short.
        s(200, -40), s(201, -45),
        // Long enough, never past 20 %.
        s(300, -8), s(301, -12), s(302, -15),
        // Broken by a lap change.
        s(400, -30), s(401, -30), s(402, -30, lap: 2),
      ]);
      expect(episodes, hasLength(1));
      final e = episodes.single;
      expect(e.samples, 11);
      expect(e.peakSteer, closeTo(77, 1e-9));
      expect(e.station, 300);
    });
  });

  group('geometric corners', () {
    // 400 m straight, a 90° left of 43 m radius, 300 m straight, a chicane
    // (right then left, 60 m radius, 50° each, joined directly), 400 m
    // straight, a 30° kink at 300 m radius, then a 1.5 km bend at 800 m
    // radius that never closes to 500 m.
    final (xs, ys) = _course([
      (400, 0),
      (43 * math.pi / 2, 43),
      (300, 0),
      (60 * 50 * math.pi / 180, -60),
      (60 * 50 * math.pi / 180, 60),
      (400, 0),
      (300 * math.pi / 6, 300),
      (300, 0),
      (800 * 0.4, 800),
      (300, 0),
    ]);

    test('finds the corners, splits the chicane, ignores a gentle bend', () {
      final laps = [
        for (var k = 0; k < 5; k++)
          _pathLap(k + 1, xs, ys, noise: 0.15, seed: k),
      ];
      final profile = medianCurvature(laps);
      expect(profile.laps, 5);
      final corners = detectGeoCorners(profile);
      expect(
        corners.map((c) => c.direction.letter).join(),
        'LRLL',
        reason: 'hairpin, chicane (R then L), kink; not the 800 m bend',
      );
      final hairpin = corners.first;
      expect(hairpin.radius, closeTo(43, 6));
      expect(hairpin.turnDegrees, closeTo(90, 12));
      expect(hairpin.apex, closeTo(400 + 43 * math.pi / 4, 15));
      expect(
        corners[1].radius,
        closeTo(60, 15),
        reason: 'a 52 m arc under a ±20 m chord',
      );
      expect(corners[3].radius, closeTo(300, 40));
      expect(corners.map((c) => c.number), [1, 2, 3, 4]);
    });

    test('a lap whose distance runs backwards is left out', () {
      final good = _pathLap(1, xs, ys);
      final bad = LapPathRead(
        lap: 2,
        distances: Float64List.fromList([
          for (var i = 0; i < good.length; i++)
            i == 50 ? good.distances[i] - 10 : good.distances[i],
        ]),
        latitudes: good.latitudes,
        longitudes: good.longitudes,
      );
      expect(medianCurvature([good, bad]).laps, 1);
    });
  });

  group('conditions lens', () {
    LensLap lap(
      int n,
      double value, {
      required double time,
      List<double?> segments = const [],
      Map<LensCondition, double?> also = const {},
    }) => LensLap(
      lap: n,
      lapTime: time,
      conditions: {LensCondition.tcCut: value, ...also},
      segmentTimes: segments,
    );

    test(
      'recovers a planted effect from an alternating setting with drift',
      () {
        // TC cut 8 / 9 / 8 over laps 19–131, as at Imola: the lap time drifts
        // down 0.02 s a lap (fuel burn), and cut 9 is 0.10 s faster in segment
        // 0. A plain mean difference would mix the drift in.
        final random = math.Random(7);
        final laps = <LensLap>[];
        for (var n = 19; n <= 131; n++) {
          final nine = n > 55 && n <= 95;
          double noise() => (random.nextDouble() - 0.5) * 0.04;
          final seg0 = 30 - 0.01 * n + (nine ? -0.10 : 0) + noise();
          final seg1 = 40 - 0.01 * n + noise();
          laps.add(
            lap(n, nine ? 9 : 8, time: seg0 + seg1, segments: [seg0, seg1]),
          );
        }
        final options = lensOptions(laps);
        expect(options, hasLength(1));
        expect(options.single.baseline, 8);
        expect(options.single.other, 9);

        final result = measureLens(options.single, laps);
        expect(result.adjusted, isTrue);
        expect(result.segments[0].time.change, closeTo(-0.10, 0.015));
        expect(result.segments[0].time.withinNoise, isFalse);
        expect(result.segments[1].time.change, closeTo(0, 0.015));
        expect(result.segments[1].time.withinNoise, isTrue);
        expect(result.rankedByShare.last, 0, reason: 'segment 0 gained most');
      },
    );

    test('a change made once is compared as it is, and says so', () {
      final laps = [
        for (var n = 1; n <= 10; n++)
          lap(
            n,
            n <= 5 ? 0 : 1,
            time: n <= 5 ? 100 + n * 0.01 : 103 + n * 0.01,
            segments: [n <= 5 ? 50.0 : 52.0],
            also: {LensCondition.compound: n <= 5 ? 0 : 3},
          ),
      ];
      final option = lensOptions(laps)
          .firstWhere((o) => o.condition == LensCondition.tcCut);
      final result = measureLens(option, laps);
      expect(result.adjusted, isFalse);
      expect(result.lapTime.change, closeTo(3.05, 1e-9));
      expect(result.segments.single.timeShare, closeTo(2 / 50, 1e-9));
      // 0 and 3 are the lens's numbers for a named Soft and Wet.
      expect(result.changedTogether, ['compound Soft → Wet']);
      expect(option.label, 'TC power cut: 0 → 1');
    });

    test('a compound reads by name where the file names it, else by index', () {
      const c = LensCondition.compound;
      final wet = compoundLensValue(
        const CompoundMark(kind: CompoundKind.wet, index: 2),
      );
      final unnamed = compoundLensValue(const CompoundMark.unnamed(1));
      expect(c.format(wet), 'Wet');
      expect(c.format(unnamed), '1');
      expect(c.change(unnamed, wet), 'compound 1 → Wet');
      // A named Hard (2) and an unnamed index 2 are never the same group.
      expect(
        compoundLensValue(const CompoundMark(kind: CompoundKind.hard)),
        isNot(compoundLensValue(const CompoundMark.unnamed(2))),
      );
    });

    test('a group with too few laps is not offered; outliers are dropped', () {
      final laps = [
        for (var n = 1; n <= 8; n++) lap(n, 8, time: 100),
        lap(9, 9, time: 100),
        lap(10, 9, time: 100),
      ];
      expect(lensOptions(laps), isEmpty);
      final more = [...laps, lap(11, 9, time: 100), lap(12, 9, time: 140)];
      final result = measureLens(lensOptions(more).single, more);
      expect(result.otherLaps, 3, reason: 'the 140 s lap is an outlier');
    });
  });
}
