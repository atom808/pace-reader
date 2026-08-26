// Pure model/derivation tests (SPEC.md §12).
//
// These run in a plain `flutter test` with no database at all, which is the
// point: `dart_duckdb`'s native library is only linked into a compiled app, so
// anything that needs a real connection has to live in `integration_test/` and
// can't run on a CI runner without a device. Keeping the derivations pure
// keeps the highest-risk logic — the sector-time correction above all — inside
// the test surface CI can always execute.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';

void main() {
  group('SectorTimes.fromCumulative', () {
    // Real values from the Race sample's lap 1, with ground truth measured
    // from `Current Sector` transition timestamps: S1 23.340, S2 12.920,
    // S3 28.240.
    test('treats Last Sector2 as cumulative, not as a duration', () {
      final sectors = SectorTimes.fromCumulative(
        sector1: 23.346588134765625,
        sector2Cumulative: 36.260711669921875,
        lapTimeSeconds: 64.49739074707031,
      );

      expect(sectors.sector1Seconds, closeTo(23.340, 0.02));
      expect(sectors.sector2Seconds, closeTo(12.920, 0.02));
      expect(sectors.sector3Seconds, closeTo(28.240, 0.02));
      expect(sectors.isComplete, isTrue);
    });

    test('the pre-v0.7 spec formula would have produced a negative sector 3', () {
      // Practice lap 1: s1 27.379, s2cum 77.140, lap 99.148. SPEC v0.6 §8.3
      // specified s3 = lap - s1 - s2, which gives -5.371 here. Pinned as a
      // test so the corrected derivation can't silently regress to it.
      const s1 = 27.37933349609375;
      const s2Cumulative = 77.1400146484375;
      const lapTime = 99.1480712890625;
      expect(lapTime - s1 - s2Cumulative, lessThan(0));

      final sectors = SectorTimes.fromCumulative(
        sector1: s1,
        sector2Cumulative: s2Cumulative,
        lapTimeSeconds: lapTime,
      );
      expect(sectors.sector3Seconds, closeTo(22.000, 0.02));
      expect(sectors.sector2Seconds, closeTo(49.760, 0.02));
      expect(sectors.all.every((s) => s! > 0), isTrue);
    });

    test('reads 0.0 as "not recorded" rather than a zero-second sector', () {
      // Race lap 2 really is like this: S1 valid, S2 written as 0.0, and a
      // perfectly good lap time. A partial row, not a corrupt one.
      final sectors = SectorTimes.fromCumulative(
        sector1: 23.408477783203125,
        sector2Cumulative: 0.0,
        lapTimeSeconds: 64.57025146484375,
      );

      expect(sectors.sector1Seconds, isNotNull);
      expect(sectors.sector2Seconds, isNull);
      expect(sectors.sector3Seconds, isNull,
          reason: 'S3 needs the cumulative S2 split, which was not recorded');
      expect(sectors.isComplete, isFalse);
    });

    test('an entirely untimed lap yields no sectors', () {
      final sectors = SectorTimes.fromCumulative(
        sector1: null,
        sector2Cumulative: null,
        lapTimeSeconds: null,
      );
      expect(sectors.all, everyElement(isNull));
    });
  });

  group('Lap', () {
    Lap lap({
      required int index,
      required double start,
      double? end,
      double? time,
    }) =>
        Lap(
          index: index,
          startSeconds: start,
          endSeconds: end,
          lapTimeSeconds: time,
          sectors: const SectorTimes(),
        );

    test('display number is 1-based so no lap ever renders as "Lap 0"', () {
      expect(lap(index: 0, start: 23.5975).displayNumber, 1);
      expect(lap(index: 19, start: 1353.1).displayNumber, 20);
    });

    test('lap 0 is the garage lap and is excluded from pace', () {
      // Real Race values: the game timed lap 0 at 71.241 s but the wall-clock
      // span between boundaries is 172.222 s, because the span covers garage
      // and grid time. Both are present; only one is comparable.
      final garage = lap(index: 0, start: 23.5975, end: 195.82, time: 71.24098205566406);
      expect(garage.isOutLap, isTrue);
      expect(garage.isTimed, isFalse);
      expect(garage.wallClockSeconds, closeTo(172.222, 0.001));
      expect(
        (garage.wallClockSeconds! - garage.lapTimeSeconds!).abs(),
        greaterThan(100),
        reason: 'why lap time must never be derived from boundary timestamps',
      );
    });

    test('the final lap has no closing boundary and cannot be timed', () {
      final open = lap(index: 19, start: 1353.1);
      expect(open.isOpenEnded, isTrue);
      expect(open.isTimed, isFalse);
      expect(open.wallClockSeconds, isNull);
    });

    test('an invalidated lap is not timed', () {
      // Race lap 5: 0.0 lap time from the game, mapped to null upstream.
      final invalid = lap(index: 5, start: 452.96, end: 517.38);
      expect(invalid.isTimed, isFalse);
      expect(invalid.wallClockSeconds, closeTo(64.42, 0.001));
    });

    test('a normal flying lap is timed', () {
      expect(lap(index: 1, start: 195.82, end: 260.32, time: 64.497).isTimed, isTrue);
    });
  });

  group('ChannelDescriptor', () {
    // Real Race sample: GPS Time has 134,059 rows.
    const masterRows = 134059;

    test('an on-grid channel maps by exact integer stride', () {
      const lapDist = ChannelDescriptor(
        name: 'Lap Dist',
        frequencyHz: 10,
        unit: 'm',
        valueColumnCount: 1,
        rowCount: 13406,
      );
      expect(lapDist.ridesMasterGrid(masterRows), isTrue);
      expect(lapDist.masterStride, 10);
      expect(lapDist.valueColumns, ['value']);
      expect(lapDist.isPerCorner, isFalse);
    });

    test('the two 7 Hz channels are off-grid and cannot be timed by frequency', () {
      // 9,408 actual rows against ceil(134059 * 7 / 100) = 9,385 expected:
      // ~0.25% fast, which compounds to +3.28 s by the end of this 22-minute
      // recording and ~+53 s over a 6-hour stint.
      const oilTemp = ChannelDescriptor(
        name: 'Engine Oil Temp',
        frequencyHz: 7,
        unit: 'C',
        valueColumnCount: 1,
        rowCount: 9408,
      );
      expect(oilTemp.ridesMasterGrid(masterRows), isFalse);
      expect((masterRows * 7 / 100).ceil(), 9385);
    });

    test('a per-corner channel exposes value1..value4', () {
      const tyres = ChannelDescriptor(
        name: 'TyresPressure',
        frequencyHz: 10,
        unit: 'kPa',
        valueColumnCount: 4,
        rowCount: 13406,
      );
      expect(tyres.isPerCorner, isTrue);
      expect(tyres.valueColumns, ['value1', 'value2', 'value3', 'value4']);
    });

    test('a 100 Hz channel has stride 1', () {
      const rpm = ChannelDescriptor(
        name: 'Engine RPM',
        frequencyHz: 100,
        unit: 'RPM',
        valueColumnCount: 1,
        rowCount: masterRows,
      );
      expect(rpm.ridesMasterGrid(masterRows), isTrue);
      expect(rpm.masterStride, 1);
    });
  });

  group('EventDescriptor', () {
    test('single-row events are the norm and read as constants', () {
      // 21-25 of the 42 event tables hold exactly one row in each sample.
      const tcLevel = EventDescriptor(
        name: 'TCLevel',
        unit: '',
        valueColumnCount: 1,
        rowCount: 1,
      );
      expect(tcLevel.isConstant, isTrue);

      const gear = EventDescriptor(
        name: 'Gear',
        unit: '',
        valueColumnCount: 1,
        rowCount: 758,
      );
      expect(gear.isConstant, isFalse);
    });
  });

  group('LapPaceStatistics', () {
    List<Lap> lapsFrom(List<(int, double?, double?, double?, double?)> spec) => [
          for (final (index, time, s1, s2cum, end) in spec)
            Lap(
              index: index,
              startSeconds: index * 100.0,
              endSeconds: end,
              lapTimeSeconds: time,
              sectors: SectorTimes.fromCumulative(
                sector1: s1,
                sector2Cumulative: s2cum,
                lapTimeSeconds: time,
              ),
            ),
        ];

    test('excludes the garage lap, invalid laps and the open final lap', () {
      final laps = lapsFrom([
        (0, 71.241, 29.218, 42.209, 195.82), // garage lap: timed, not comparable
        (1, 64.497, 23.347, 36.261, 260.32),
        (2, null, 23.408, null, 324.88), // invalidated
        (3, 64.029, 22.984, 35.853, 388.92),
        (4, null, null, null, null), // open final lap
      ]);

      expect(laps.timed.map((l) => l.index), [1, 3]);
      expect(laps.bestLap!.index, 3);
      expect(laps.completedCount, 4);
    });

    test('theoretical best sums the best sector from any lap', () {
      final laps = lapsFrom([
        (1, 64.497, 23.347, 36.261, 260.32), // S1 23.347 S2 12.914 S3 28.236
        (2, 64.029, 22.984, 35.853, 324.88), // S1 22.984 S2 12.869 S3 28.176
      ]);
      // Best of each: 22.984 + 12.869 + 28.176
      expect(laps.theoreticalBestSeconds, closeTo(64.029, 0.01));
      expect(laps.theoreticalBestSeconds!, lessThanOrEqualTo(laps.bestLap!.lapTimeSeconds!));
    });

    test('theoretical best is null when a sector was never recorded', () {
      final laps = lapsFrom([(1, 64.497, 23.347, null, 260.32)]);
      expect(laps.theoreticalBestSeconds, isNull);
    });

    test('consistency is undefined, not zero, for a single timed lap', () {
      expect(lapsFrom([(1, 64.497, null, null, 260.32)]).consistencyStdDevSeconds, isNull);
    });

    test('consistency measures spread across timed laps', () {
      final laps = lapsFrom([
        (1, 64.0, null, null, 100.0),
        (2, 65.0, null, null, 200.0),
      ]);
      expect(laps.consistencyStdDevSeconds, closeTo(0.7071, 0.001));
    });

    test('no timed laps yields no best', () {
      expect(lapsFrom([(0, 71.2, null, null, 195.8)]).bestLap, isNull);
    });
  });

  group('SessionMetadata', () {
    const base = SessionMetadata(
      driverName: 'D',
      steamId: '1',
      recordingTime: '2026-07-07T06_42_17Z',
      sessionTimeOfDay: '13:00:21',
      sessionType: SessionType.race,
      trackName: 'Sebring International Raceway',
      trackLayout: 'Sebring School Circuit',
      weatherConditions: 'Clear',
      carName: 'The Bend Team WRT 2025 #31:BRZ',
      carClass: 'GT3',
      carSetupJson: '{}',
      version: '1',
    );

    test('track key includes the layout, which changes lap length', () {
      // The Race sample is the 3.08 km School Circuit, about half the 6.0 km
      // full course — keying on track name alone would compare different
      // circuits in the same "best lap" column.
      expect(base.trackKey, contains('Sebring School Circuit'));
      expect(base.layoutIsDistinct, isTrue);
    });

    test('a layout equal to the track name is not worth displaying twice', () {
      expect(base.copyWith(trackLayout: base.trackName).layoutIsDistinct, isFalse);
    });

    test('session type parses the confirmed values and rejects others', () {
      expect(SessionType.tryParse('Practice'), SessionType.practice);
      expect(SessionType.tryParse('Qualify'), SessionType.qualify);
      expect(SessionType.tryParse('Race'), SessionType.race);
      expect(SessionType.tryParse('Warmup'), isNull);
      expect(SessionType.race.filenameCode, 'R');
    });
  });

  group('TraceSeries', () {
    TraceSeries series(List<double> lows, List<double> highs) => TraceSeries(
          channelName: 'SoC',
          unit: '%',
          frequencyHz: 20,
          valueColumn: 'value',
          times: Float64List.fromList([0, 1, 2]),
          lows: Float64List.fromList(lows),
          highs: Float64List.fromList(highs),
        );

    test('an all-zero channel is degenerate and must not be plotted', () {
      // SoC and Regen Rate are present but all-zero in GT3 files; a flat zero
      // line labelled "State of Charge" reads as data rather than absence.
      expect(series([0, 0, 0], [0, 0, 0]).isDegenerate, isTrue);
    });

    test('a varying channel is not degenerate', () {
      expect(series([0, 1, 2], [1, 2, 3]).isDegenerate, isFalse);
      expect(series([5, 5, 5], [5, 5, 6]).isDegenerate, isFalse);
    });

    test('min/max span the low and high columns', () {
      final s = series([3, 1, 2], [4, 6, 5]);
      expect(s.minValue, 1);
      expect(s.maxValue, 6);
      expect(s.length, 3);
    });
  });

  group('ClockGap', () {
    test('lost time is the step beyond the expected 0.01 s', () {
      // The Practice sample's real gap: 0.3875 s observed at row 32,580.
      const gap = ClockGap(masterRowIndex: 32580, deltaSeconds: 0.3875);
      expect(gap.lostSeconds, closeTo(0.3775, 1e-9));
    });
  });

  group('lapAt', () {
    const noSectors = SectorTimes();
    final laps = [
      const Lap(
          index: 0,
          startSeconds: 23.6,
          endSeconds: 195.8,
          sectors: noSectors),
      const Lap(
          index: 1,
          startSeconds: 195.8,
          endSeconds: 260.3,
          sectors: noSectors),
      // The final lap has no closing boundary — the recording just stops.
      const Lap(index: 2, startSeconds: 260.3, sectors: noSectors),
    ];

    test('resolves a time inside a lap', () {
      expect(laps.lapAt(100)?.index, 0);
      expect(laps.lapAt(200)?.index, 1);
    });

    test('puts a boundary on the lap it opens, not the one it closes', () {
      // Lap windows are half-open for the same reason TraceWindow is: the
      // sample on the start/finish line must not count twice.
      expect(laps.lapAt(195.8)?.index, 1);
      expect(laps.lapAt(260.3)?.index, 2);
    });

    test('claims everything after the last lap start', () {
      // An unclosed final lap still recorded those events on that lap.
      expect(laps.lapAt(9999)?.index, 2);
    });

    test('has no answer before the first lap starts', () {
      expect(laps.lapAt(0), isNull);
      expect(<Lap>[].lapAt(100), isNull);
    });
  });

  group('EventLog', () {
    const rows = [
      TelemetryEvent(name: 'Gear', unit: '', timeSeconds: 1, values: [2]),
      TelemetryEvent(name: 'ABS', unit: '', timeSeconds: 2, values: [true]),
      TelemetryEvent(name: 'Gear', unit: '', timeSeconds: 3, values: [3]),
    ];

    test('lists each event once, in the order it first appears', () {
      expect(const EventLog(events: rows).names, ['Gear', 'ABS']);
    });

    test('is not truncated unless something was actually clipped', () {
      expect(const EventLog(events: rows).truncated, isFalse);
      const clipped = EventLog(events: rows, clipped: ['SurfaceTypes']);
      expect(clipped.truncated, isTrue);
      expect(clipped.clipped, ['SurfaceTypes']);
    });

    test('knows a per-corner reading from a single one', () {
      const corner = TelemetryEvent(
          name: 'SurfaceTypes', unit: '', timeSeconds: 1, values: [0, 0, 1, 1]);
      expect(corner.isPerCorner, isTrue);
      expect(rows.first.isPerCorner, isFalse);
    });
  });
}
