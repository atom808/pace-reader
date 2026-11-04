// Suspension's domain (suspension proposal §5): strikes merge, phases and
// surfaces label, sites cluster at the 25 m rule, and the verdict reads
// planted line, speed, every-lap and noise sites the way §5 says.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/suspension/domain/platform.dart';
import 'package:pace_reader/features/suspension/domain/sites.dart';
import 'package:pace_reader/features/suspension/domain/strikes.dart';
import 'package:pace_reader/features/suspension/domain/suspension_thresholds.dart';

StrikeSample _sample(
  int row, {
  int lap = 1,
  double fl = 0.02,
  double rl = 0.02,
  double? brake,
  double? lat,
  double? lon,
  double? vert,
  double station = 1000,
  List<int?> surfaces = const [0, 0, 0, 0],
}) => StrikeSample(
  row: row,
  seconds: row / 100,
  lap: lap,
  heights: [fl, 0.03, rl, 0.03],
  speed: 250,
  brake: brake,
  station: station,
  line: 0,
  lateralG: lat,
  longitudinalG: lon,
  verticalG: vert,
  surfaces: surfaces,
);

Strike _strike({
  required int lap,
  required double station,
  double depth = 0.004,
  Corner corner = Corner.rearLeft,
  StrikeSurface surface = StrikeSurface.track,
  StrikePhase phase = StrikePhase.braking,
  double? speed,
}) => Strike(
  lap: lap,
  seconds: 0,
  row: 0,
  depth: depth,
  corner: corner,
  tier: depth < strikeFloorMetres ? StrikeTier.strike : StrikeTier.close,
  phase: phase,
  surface: surface,
  samples: 3,
  station: station,
  speed: speed,
);

void main() {
  group('merging', () {
    test('consecutive samples are one strike, its lowest point the depth', () {
      final strikes = mergeStrikes([
        _sample(100, rl: 0.007),
        _sample(101, rl: 0.004, vert: 0.4),
        _sample(102, rl: 0.003, vert: -1.4),
        _sample(103, rl: 0.008),
      ]);
      expect(strikes, hasLength(1));
      final s = strikes.single;
      expect(s.depth, 0.003);
      expect(s.corner, Corner.rearLeft);
      expect(s.row, 102);
      expect(s.samples, 4);
      expect(s.tier, StrikeTier.strike);
      expect(s.peakVerticalG, -1.4);
    });

    test('a gap of the merge rule or more starts a new strike', () {
      final strikes = mergeStrikes([
        _sample(100, rl: 0.004),
        _sample(100 + strikeMergeGapRows - 1, rl: 0.004),
        _sample(100 + strikeMergeGapRows * 3, rl: 0.004),
      ]);
      expect(strikes, hasLength(2));
    });

    test('a new lap starts a new strike', () {
      final strikes = mergeStrikes([
        _sample(100, rl: 0.004),
        _sample(101, lap: 2, rl: 0.004),
      ]);
      expect(strikes, hasLength(2));
    });

    test('a run that never goes under the floor is Close', () {
      final s = mergeStrikes([_sample(1, rl: 0.0075), _sample(2, rl: 0.007)]);
      expect(s.single.tier, StrikeTier.close);
    });

    test('negative heights on track are the deepest strikes, not glitches', () {
      final s = mergeStrikes([_sample(1, fl: -0.0105)]);
      expect(s.single.depth, -0.0105);
      expect(s.single.corner, Corner.frontLeft);
      expect(s.single.tier, StrikeTier.strike);
    });
  });

  group('phase', () {
    test('brake over 10 % anywhere in the strike is braking', () {
      final s = mergeStrikes([
        _sample(1, rl: 0.004, brake: 30),
        _sample(2, rl: 0.003, brake: 0),
      ]);
      expect(s.single.phase, StrikePhase.braking);
    });

    test('the four phases at their thresholds', () {
      expect(phaseOf(maxBrake: 0, longitudinalG: 0.6), StrikePhase.braking);
      expect(phaseOf(lateralG: -1.2), StrikePhase.corner);
      expect(phaseOf(maxBrake: 50, lateralG: 1.3), StrikePhase.brakingCorner);
      expect(
        phaseOf(maxBrake: 10, longitudinalG: 0.5, lateralG: 1.0),
        StrikePhase.straight,
      );
    });

    test('braking into a corner counts as braking for the filter', () {
      expect(StrikePhase.brakingCorner.isBraking, isTrue);
      expect(StrikePhase.corner.isBraking, isFalse);
    });
  });

  group('surface', () {
    test('any kerb or paint sample makes a kerb strike', () {
      expect(
        surfaceOf([
          [0, 0, 0, 0],
          [0, 5, 0, 0],
        ]),
        StrikeSurface.kerb,
      );
      expect(
        surfaceOf([
          [0, 0, 6, 0],
        ]),
        StrikeSurface.kerb,
      );
    });

    test('grass or gravel anywhere is off track, over a kerb', () {
      expect(
        surfaceOf([
          [5, 5, 0, 0],
          [2, 0, 0, 0],
        ]),
        StrikeSurface.offTrack,
      );
      expect(
        surfaceOf([
          [4, 0, 0, 0],
        ]),
        StrikeSurface.offTrack,
      );
    });

    test('code 30 and a file without the event read as track', () {
      expect(
        surfaceOf([
          [30, 0, 0, 0],
        ]),
        StrikeSurface.track,
      );
      expect(
        surfaceOf([
          [null, null, null, null],
        ]),
        StrikeSurface.track,
      );
    });
  });

  group('sites', () {
    test('strikes within 25 m on two laps are a site at their median', () {
      final sites = clusterSites([
        _strike(lap: 1, station: 9639),
        _strike(lap: 2, station: 9640),
        _strike(lap: 3, station: 9641, depth: 0.002),
      ]);
      expect(sites, hasLength(1));
      expect(sites.single.place, 9640);
      expect(sites.single.struckLaps, {1, 2, 3});
      expect(sites.single.deepest, 0.002);
      expect(sites.single.start, 9640 - siteWindowMetres);
    });

    test('26 m apart is two places, and one lap alone is not a site', () {
      final sites = clusterSites([
        _strike(lap: 1, station: 1000),
        _strike(lap: 2, station: 1000 + siteJoinMetres + 1),
      ]);
      expect(sites, isEmpty);
    });

    test('a lap striking twice at one site counts once, at its deepest', () {
      final sites = clusterSites([
        _strike(lap: 1, station: 500, depth: 0.005),
        _strike(lap: 1, station: 510, depth: 0.001),
        _strike(lap: 2, station: 505),
      ]);
      expect(sites.single.lapLows[1]!.depth, 0.001);
      expect(sites.single.lapLows, hasLength(2));
    });

    test('off-track strikes never make a site', () {
      final sites = clusterSites([
        _strike(lap: 1, station: 500, surface: StrikeSurface.offTrack),
        _strike(lap: 2, station: 505, surface: StrikeSurface.offTrack),
      ]);
      expect(sites, isEmpty);
    });

    test(
      'a site of only Close laps is Close, and ranks after Strike sites',
      () {
        final sites = rankSites(
          clusterSites([
            _strike(lap: 1, station: 100, depth: 0.008),
            _strike(lap: 2, station: 101, depth: 0.007),
            _strike(lap: 1, station: 900),
            _strike(lap: 2, station: 901),
          ]),
        );
        expect(sites.first.place, 900.5);
        expect(sites.last.tier, StrikeTier.close);
      },
    );

    test('a site is a kerb site when most of its laps struck on a kerb', () {
      final site = clusterSites([
        _strike(lap: 1, station: 100, surface: StrikeSurface.kerb),
        _strike(lap: 2, station: 101, surface: StrikeSurface.kerb),
        _strike(lap: 3, station: 102),
      ]).single;
      expect(site.isKerb, isTrue);
    });
  });

  group('verdict', () {
    // Twelve laps striking at one place; the lows are planted per case.
    final site = clusterSites([
      for (var lap = 0; lap < 12; lap++) _strike(lap: lap, station: 9640),
    ]).single;
    final rng = math.Random(7);
    double noise() => (rng.nextDouble() - 0.5) * 0.0004;

    test('depth following the line, not speed, is Line', () {
      final lows = [
        for (var lap = 0; lap < 12; lap++)
          SiteLapLow(
            lap: lap,
            line: lap * 0.2 - 1,
            // 3 mm higher per metre to the right.
            depth: 0.004 + (lap * 0.2 - 1) * 0.003 + noise(),
            speed: 250 + (lap.isEven ? 3.0 : -3.0),
          ),
      ];
      final v = verdictFor(site, lows, racingLaps: 12);
      expect(v.kind, VerdictKind.line);
      expect(v.lineSlope, closeTo(3, 0.3));
    });

    test('depth following speed, not line, is Speed', () {
      final lows = [
        for (var lap = 0; lap < 12; lap++)
          SiteLapLow(
            lap: lap,
            line: lap.isEven ? 0.5 : -0.5,
            speed: 260.0 + lap * 2,
            depth: 0.008 - lap * 0.0005 + noise(),
          ),
      ];
      final v = verdictFor(site, lows, racingLaps: 12);
      expect(v.kind, VerdictKind.speed);
      expect(v.speedSlope! < 0, isTrue);
    });

    test('struck every lap with nothing going with it is Every lap', () {
      final lows = [
        for (var lap = 0; lap < 12; lap++)
          SiteLapLow(
            lap: lap,
            line: math.sin(lap * 1.7),
            speed: 250 + math.cos(lap * 2.3) * 4,
            depth: 0.004 + math.sin(lap * 5.1) * 0.0004,
          ),
      ];
      final v = verdictFor(site, lows, racingLaps: 12);
      expect(v.lineR!.abs(), lessThan(verdictMinR));
      expect(v.speedR!.abs(), lessThan(verdictMinR));
      expect(v.kind, VerdictKind.everyLap);
    });

    test('the same noise struck on few of many laps is Not clear', () {
      final lows = [
        for (var lap = 0; lap < 12; lap++)
          SiteLapLow(
            lap: lap,
            line: math.sin(lap * 1.7),
            speed: 250 + math.cos(lap * 2.3) * 4,
            depth: 0.004 + math.sin(lap * 5.1) * 0.0004,
          ),
      ];
      final v = verdictFor(site, lows, racingLaps: 40);
      expect(v.kind, VerdictKind.notClear);
    });

    test('under eight laps is too few', () {
      final v = verdictFor(site, [
        for (var lap = 0; lap < 7; lap++)
          SiteLapLow(lap: lap, depth: 0.004, line: lap * 1.0, speed: 250),
      ], racingLaps: 12);
      expect(v.kind, VerdictKind.tooFewLaps);
    });

    test('the cleanest comparable lap holds speed and rides highest', () {
      final lows = [
        const SiteLapLow(lap: 1, depth: 0.003, speed: 250),
        const SiteLapLow(lap: 2, depth: 0.006, speed: 251),
        // Highest, but much slower: not comparable.
        const SiteLapLow(lap: 3, depth: 0.012, speed: 230),
        const SiteLapLow(lap: 4, depth: 0.004, speed: 249.5),
      ];
      expect(cleanestLap(lows), 2);
    });
  });

  group('platform', () {
    LapPlatform lap(int i, double front, double rear) =>
        LapPlatform(lap: i, frontRoll: front, rearRoll: rear);

    test('a roll-ratio step past the threshold is a balance step', () {
      final laps = [
        lap(1, -5.7, -5.8),
        lap(2, -5.7, -5.7),
        lap(3, -5.6, -5.7),
        // Front bar stiffer: the front rolls less.
        lap(4, -3.4, -5.7),
        lap(5, -3.4, -5.6),
      ];
      expect(balanceSteps(laps), [4]);
    });

    test('a steady balance has no steps', () {
      expect(
        balanceSteps([for (var i = 0; i < 8; i++) lap(i, -5.7, -5.75)]),
        isEmpty,
      );
    });

    test('histograms add and say how much ran fast', () {
      const a = DamperHistogram({0: 10, 5: 5, -1: 10, -7: 5});
      const b = DamperHistogram({0: 10});
      final sum = a + b;
      expect(sum.total, 40);
      // Bin 5 starts at 100 mm/s; bin −7 is rebound from 150.
      expect(sum.fastShare(100), 10 / 40);
      expect(DamperHistogram.lowerEdge(-7), 150);
    });

    test('the Alpine\'s split is measured, every other car a default', () {
      expect(DamperKnee.forCar('Alpine A424').measured, isTrue);
      expect(DamperKnee.forCar('BMW M4 GT3').measured, isFalse);
    });
  });
}
