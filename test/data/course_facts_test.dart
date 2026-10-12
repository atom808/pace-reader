// What a recording says about its course (comparison proposal §4): the
// station medians, the pit-lane stays and the alignment of two files.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';

void main() {
  group('median', () {
    test('of an odd count is the middle value', () {
      expect(median([3, 1, 2]), 2);
    });

    test('of an even count is the mean of the middle two', () {
      expect(median([4, 1, 3, 2]), 2.5);
    });

    test('of nothing is null', () {
      expect(median([]), isNull);
    });
  });

  group('robustStation', () {
    test('drops a crossing more than 5 m from the first median', () {
      // The garage teleport: Lap Dist jumps 0 → 2044 m in one sample, and
      // the crossing interpolated across the jump lands nowhere near the
      // line.
      expect(robustStation([1029.3, 1029.5, 1029.4, 1400.0]), 1029.4);
    });

    test('keeps a crossing exactly at the outlier bound', () {
      // First median 1001: 996 is 5.0 m out and stays, 995.9 is 5.1 m out
      // and goes.
      expect(robustStation([996, 1000, 1002, 1003]), 1001);
      expect(robustStation([995.9, 1000, 1002, 1003]), 1002);
    });

    test('of nothing is null', () {
      expect(robustStation([]), isNull);
    });
  });

  group('pitIntervalsFrom', () {
    test('a stay runs from the first true to the next false', () {
      expect(
        pitIntervalsFrom([(10, true), (12, true), (40, false), (90, true)]),
        [const PitInterval(10, 40), const PitInterval(90)],
      );
    });

    test('a false with no stay open is ignored', () {
      expect(pitIntervalsFrom([(5, false), (10, true), (20, false)]), [
        const PitInterval(10, 20),
      ]);
    });

    test('an open stay overlaps everything after it', () {
      const open = PitInterval(90);
      expect(open.overlaps(100, 200), isTrue);
      expect(open.overlaps(10, 90), isFalse);
    });
  });

  group('CourseFacts.fromReads', () {
    test('S1 from entering sector 2, S2 from entering sector 3', () {
      final facts = CourseFacts.fromReads(
        wrapLength: 3083.31,
        wrapCount: 2,
        crossings: [
          (sector: 2, seconds: 219.16, station: 1029.3),
          (sector: 3, seconds: 232.08, station: 1572.5),
          (sector: 2, seconds: 283.6, station: 1029.5),
          (sector: 3, seconds: 296.5, station: 1572.7),
        ],
        inPits: const [],
      );
      expect(facts.sector1Station, closeTo(1029.4, 1e-9));
      expect(facts.sector2Station, closeTo(1572.6, 1e-9));
      expect(facts.wrapLength, 3083.31);
      expect(facts.timingLineStation, closeTo(3081.51, 1e-9));
    });

    test('a crossing made in the pit lane is not a crossing of the line', () {
      // Sebring School's pit lane bypasses the timing line: the sector change
      // recorded there sits metres off the circuit's.
      final facts = CourseFacts.fromReads(
        wrapLength: 3083.31,
        wrapCount: 1,
        crossings: [
          (sector: 2, seconds: 50.0, station: 1026.0),
          (sector: 2, seconds: 219.16, station: 1029.3),
          (sector: 2, seconds: 283.6, station: 1029.5),
        ],
        inPits: const [(40.0, true), (60.0, false)],
      );
      expect(facts.sector1Station, closeTo(1029.4, 1e-9));
      expect(facts.pitLane, [const PitInterval(40, 60)]);
      expect(facts.pitLaneDuring(30, 45), isTrue);
      expect(facts.pitLaneDuring(60, 120), isFalse);
    });

    test('a file with no crossing and no wrap knows nothing', () {
      final facts = CourseFacts.fromReads(
        wrapLength: null,
        wrapCount: 0,
        crossings: const [],
        inPits: const [],
      );
      expect(facts, CourseFacts.unknown);
      expect(facts.timingLineStation, isNull);
    });
  });

  group('StationAlignment', () {
    CourseFacts at(double s1, double s2) =>
        CourseFacts(sector1Station: s1, sector2Station: s2);

    test('one file needs no measuring', () {
      const shared = StationAlignment.sharedFile;
      expect(shared.aligned, isTrue);
      expect(shared.withholdsDistance, isFalse);
      expect(shared.unchecked, isFalse);
    });

    test('the larger offset decides, with its sign', () {
      final a = StationAlignment.between(at(1000, 1500), at(1000.4, 1497.0));
      expect(a.sector1Offset, closeTo(0.4, 1e-9));
      expect(a.sector2Offset, closeTo(-3.0, 1e-9));
      expect(a.worstOffset, closeTo(-3.0, 1e-9));
    });

    test('within 2.5 m is one coordinate', () {
      final a = StationAlignment.between(at(1000, 1500), at(1002.5, 1500));
      expect(a.aligned, isTrue);
      expect(a.withholdsDistance, isFalse);
    });

    test('2.5–5 m warns but keeps the delta', () {
      final a = StationAlignment.between(at(1000, 1500), at(1003, 1503));
      expect(a.aligned, isFalse);
      expect(a.withholdsDistance, isFalse);
    });

    test('past 5 m nothing is compared at equal distance', () {
      final a = StationAlignment.between(at(1000, 1500), at(1008, 1508));
      expect(a.aligned, isFalse);
      expect(a.withholdsDistance, isTrue);
    });

    test('a file with no crossing leaves it unchecked, not passed', () {
      final a = StationAlignment.between(at(1000, 1500), CourseFacts.unknown);
      expect(a.unchecked, isTrue);
      expect(a.aligned, isFalse);
      expect(a.withholdsDistance, isFalse);
    });
  });
}
