// Compare's gates, end to end through its chart provider (comparison
// proposal §4, §10 step 3).
//
// Each "file" serves the two real 5 Hz Sebring fixture laps under a path of
// its own (`compare_harness.dart`), so every cross-file gate runs: copies
// whose sector lines sit further on, whose whole `Lap Dist` is shifted,
// recorded later, claiming a longer lap, or on another track.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/compare_source_guard.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/data/models/models.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

final _base = CompareFile('/compare/base.duckdb');

/// The fixture pair's delta at the last distance both 5 Hz laps reach
/// (3062.84 m), from re-anchored starts: 3.5 ms short of the game's
/// 0.468 s difference, where the Lap events alone gave 0.459 s.
const _finalDelta = 0.46423;

Future<ComparisonView> _view(
  CompareFile target, {
  CompareFile? base,
  int baseLap = sebringLapIndex,
  int targetLap = sebringLap3Index,
  LapReadLog? reads,
  List<CompareFile>? open,
}) async {
  final b = base ?? _base;
  final files = [b, if (target.path != b.path) target];
  final container = ProviderContainer(
    overrides: compareOverrides(
      files: files,
      open: open ?? files,
      reads: reads,
    ),
  );
  addTearDown(container.dispose);
  return readFuture(
    container,
    comparisonChartProvider(
      ComparisonSet(
        LapRef(b.source, baseLap),
        LapRef(target.source, targetLap),
      ),
    ).future,
  );
}

LapComparison _comparison(ComparisonView view) => view.chart!.comparison!;

List<String> _titles(ComparisonView view) =>
    view.chart!.panels.map((p) => p.title).toList();

void main() {
  group('two files of one course', () {
    test('pass every gate, with the native residuals', () async {
      final view = await _view(CompareFile('/compare/other.duckdb'));
      final comparison = _comparison(view);

      expect(view.course!.verdict, CourseVerdict.sameCourse);
      expect(comparison.alignment.aligned, isTrue);
      final check = comparison.check;
      expect(check.bothReanchored, isTrue);
      expect(check.status, DeltaCheckStatus.passed);
      expect(check.pair[TimingLine.sector1], closeTo(0.004, 0.001));
      expect(check.pair[TimingLine.sector2], closeTo(-0.002, 0.001));
      expect(check.pair[TimingLine.finish], closeTo(-0.002, 0.001));
      expect(check.worstLap!.abs(), lessThan(DeltaCheck.perLapLimit));

      expect(comparison.delta!.finalDelta, closeTo(_finalDelta, 1e-5));
      expect(comparison.note, isNull);
      expect(_titles(view).first, 'Delta');
      expect(view.chips.map((c) => c.tone), everyElement(ChipTone.passed));
    });

    test('Trace shows the delta Compare shows, for the same pair', () async {
      final container = ProviderContainer(
        overrides: compareOverrides(files: [_base], open: [_base]),
      );
      addTearDown(container.dispose);
      final trace = await readFuture(
        container,
        lapChartProvider(
          _base.source,
          sebringLapIndex,
          sebringLap3Index,
        ).future,
      );
      final compare = await _view(_base);
      final traceDelta = trace.comparison!.delta!;
      final compareDelta = _comparison(compare).delta!;
      expect(traceDelta.finalDelta, compareDelta.finalDelta);
      expect(traceDelta.deltas, compareDelta.deltas);
      expect(trace.comparison!.timeShift, _comparison(compare).timeShift);
    });

    test('a copy recorded later gives the identical delta', () async {
      final now = await _view(CompareFile('/compare/now.duckdb'));
      final later = await _view(
        CompareFile('/compare/later.duckdb', timeShift: 1000),
      );
      final a = _comparison(now).delta!;
      final b = _comparison(later).delta!;
      expect(b.length, a.length);
      for (var i = 0; i < a.length; i++) {
        expect(b.deltas[i], closeTo(a.deltas[i], 1e-9));
      }
      // Placed on Base's clock 1000 s further back, and nowhere else.
      expect(
        _comparison(later).timeShift,
        closeTo(_comparison(now).timeShift - 1000, 1e-9),
      );
    });

    test('a lap missing its splits keeps its Lap event and is checked at '
        '30 ms', () async {
      final splitless = CompareFile(
        '/compare/splitless.duckdb',
        withoutSplits: true,
      );
      final view = await _view(_base, base: splitless);
      final check = _comparison(view).check;
      expect(check.base.reanchored, isFalse);
      expect(check.target.reanchored, isTrue);
      expect(check.pairBound, DeltaCheck.unanchoredPairLimit);
      expect(check.status, DeltaCheckStatus.passed);
      expect(_titles(view).first, 'Delta');
    });
  });

  group('distance alignment', () {
    test('sector lines 3 m further on warn, and keep the delta', () async {
      final view = await _view(
        CompareFile('/compare/plus3.duckdb', stationOffset: 3),
      );
      final comparison = _comparison(view);
      expect(comparison.alignment.worstOffset, closeTo(3, 1e-9));
      expect(comparison.check.status, DeltaCheckStatus.passed);
      expect(comparison.delta!.finalDelta, closeTo(_finalDelta, 1e-5));
      expect(comparison.note, contains('3.0 m apart: corner deltas may shift'));
      expect(view.chips[1].label, 'distance offset 3.0 m');
      expect(view.chips[1].tone, ChipTone.warning);
    });

    test('8 m withholds the delta and the distance overlay, and names both '
        'lines', () async {
      final view = await _view(
        CompareFile('/compare/plus8.duckdb', stationOffset: 8),
      );
      final comparison = _comparison(view);
      expect(comparison.delta, isNull);
      expect(comparison.overlaid, isFalse);
      expect(_titles(view), isNot(contains('Delta')));
      expect(view.chart!.panels.any((p) => p.series.hasReference), isFalse);
      expect(comparison.note, contains('S1 +8.0 m, S2 +8.0 m'));
      expect(view.chips[1].label, 'distance offset 8.0 m: delta withheld');
      // The sectors stay: the game's splits need no shared distance.
      expect(comparison.reference.sectors.isComplete, isTrue);
    });

    test('… but still overlays on the time axis', () async {
      final target = CompareFile('/compare/plus8.duckdb', stationOffset: 8);
      final container = ProviderContainer(
        overrides: compareOverrides(
          files: [_base, target],
          open: [_base, target],
        ),
      );
      addTearDown(container.dispose);
      container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
      final view = await readFuture(
        container,
        comparisonChartProvider(
          ComparisonSet(
            LapRef(_base.source, sebringLapIndex),
            LapRef(target.source, sebringLap3Index),
          ),
        ).future,
      );
      expect(_comparison(view).overlaid, isTrue);
      expect(_comparison(view).delta, isNull);
    });

    test(
      'a whole Lap Dist shifted 3 m is another course to the centre line',
      () async {
        // At equal `Lap Dist` the shifted copy's centre path runs 3 m along
        // the track from Base's, and further where the 5 Hz samples fall
        // apart: part 3's limit (D2).
        final view = await _view(
          CompareFile('/compare/frame3.duckdb', distanceOffset: 3),
        );
        expect(view.refused, isTrue);
        expect(view.course!.verdict, CourseVerdict.differentCentreLine);
        expect(view.course!.centre!.max, closeTo(3.33, 0.01));
        expect(view.chart, isNull);
      },
    );

    test('a whole Lap Dist shifted 2 m is caught at the timing line', () async {
      // Inside part 3's 3 m, but the line sits at the wrap length less 1.8 m
      // in every file, so a frame shifted under it puts the trace 2 m early
      // there: the check fails before the alignment warning could let a
      // wrong delta through.
      final view = await _view(
        CompareFile('/compare/frame2.duckdb', distanceOffset: 2),
      );
      expect(view.course!.verdict, CourseVerdict.sameCourse);
      final comparison = _comparison(view);
      expect(comparison.check.status, DeltaCheckStatus.failed);
      expect(comparison.delta, isNull);
      expect(_titles(view), isNot(contains('Delta')));
      expect(comparison.note, contains('The delta is not drawn'));
      expect(
        view.chips.singleWhere((c) => c.tone == ChipTone.error).label,
        'delta check failed',
      );
    });

    test('a same-file pair skips the alignment gate', () async {
      final view = await _view(_base);
      expect(view.course!.verdict, CourseVerdict.sameFile);
      expect(_comparison(view).alignment, StationAlignment.sharedFile);
      expect(view.chips.map((c) => c.label), [
        'same file',
        startsWith('delta checked'),
      ]);
    });
  });

  group('the course gate refuses before any lap is read', () {
    test('a copy whose lap is 1 m longer', () async {
      final reads = <(String, int)>[];
      final view = await _view(
        CompareFile(
          '/compare/longer.duckdb',
          course: const CourseFacts(
            wrapLength: 3084.313,
            sector1Station: 1029.435,
            sector2Station: 1572.549,
          ),
        ),
        reads: reads,
      );
      expect(view.refused, isTrue);
      expect(view.course!.verdict, CourseVerdict.differentLength);
      expect(view.chart, isNull);
      expect(reads, isEmpty);
    });

    test('a recording of another track', () async {
      final reads = <(String, int)>[];
      final view = await _view(
        CompareFile('/compare/spa.duckdb', metadata: spaMetadata),
        reads: reads,
      );
      expect(view.refused, isTrue);
      expect(view.course!.verdict, CourseVerdict.differentTrack);
      expect(reads, isEmpty);
    });

    test('a layout variant is read, then held to its centre line', () async {
      final reads = <(String, int)>[];
      final view = await _view(
        CompareFile(
          '/compare/variant.duckdb',
          metadata: sebringMetadata.copyWith(
            trackLayout: 'Sebring School Circuit Endurance',
          ),
        ),
        reads: reads,
      );
      expect(view.refused, isFalse);
      expect(view.course!.verdict, CourseVerdict.layoutVariant);
      expect(view.course!.centre!.max, lessThan(0.5));
      expect(
        view.chips.map((c) => c.label),
        contains('layout variant: Sebring School Circuit Endurance'),
      );
      expect(reads, hasLength(2));
    });

    test('a pair that passes reads exactly its two laps', () async {
      final reads = <(String, int)>[];
      await _view(CompareFile('/compare/other.duckdb'), reads: reads);
      expect(
        reads,
        unorderedEquals([
          ('/compare/base.duckdb', sebringLapIndex),
          ('/compare/other.duckdb', sebringLap3Index),
        ]),
      );
    });
  });

  group('a file that is not open', () {
    test('as the Target is a closed state, not a read', () async {
      final target = CompareFile('/compare/closed.duckdb');
      final reads = <(String, int)>[];
      await expectLater(
        _view(target, open: [_base], reads: reads),
        throwsA(
          isA<CompareSourceClosed>().having(
            (e) => e.role,
            'role',
            ComparisonRole.target,
          ),
        ),
      );
      expect(reads, isEmpty);
    });

    test('as Base is a closed state too', () async {
      final target = CompareFile('/compare/open.duckdb');
      await expectLater(
        _view(target, open: [target]),
        throwsA(
          isA<CompareSourceClosed>().having(
            (e) => e.role,
            'role',
            ComparisonRole.base,
          ),
        ),
      );
    });
  });
}
