// Compare's pure parts (comparison proposal §4): the course gate, the
// comparability strip, the pair, the workspace and the suggested targets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/application/target_suggestions.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/lines.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_selection.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import 'compare_harness.dart';

const _a = TelemetrySource.path('/compare/a.duckdb');
const _b = TelemetrySource.path('/compare/b.duckdb');

SessionMetadata _meta({
  String track = 'Sebring International Raceway',
  String layout = 'Sebring School Circuit',
  String car = 'The Bend Team WRT 2025 #31:BRZ',
  String carClass = 'GT3',
  SessionType session = SessionType.race,
  String recordingTime = '2026-07-07T06_42_17Z',
}) => SessionMetadata(
  driverName: 'Diego Pestana',
  steamId: '0',
  recordingTime: recordingTime,
  sessionTimeOfDay: '13:00:21',
  sessionType: session,
  trackName: track,
  trackLayout: layout,
  weatherConditions: 'Clear',
  carName: car,
  carClass: carClass,
  carSetupJson: '{}',
  version: '1',
);

CourseCheck _course({
  SessionMetadata? base,
  SessionMetadata? target,
  double? baseLength = 3083.313,
  double? targetLength = 3083.313,
  bool sameFile = false,
}) => CourseCheck.of(
  base: base ?? _meta(),
  baseCourse: CourseFacts(wrapLength: baseLength),
  target: target ?? _meta(),
  targetCourse: CourseFacts(wrapLength: targetLength),
  sameFile: sameFile,
);

LapAnchor _anchor(LapTelemetry t) => LapAnchor.measure(
  lap: t.lap,
  axis: DistanceAxis.fromSeries(t.lapDistance!),
  course: sebringCourse,
);

LapComparison _comparison({
  StationAlignment alignment = StationAlignment.sharedFile,
  DeltaCheck? check,
}) => LapComparison(
  target: const LapRef(_b, sebringLap3Index),
  reference: sebringLap3(),
  overlaid: true,
  timeShift: 0,
  alignment: alignment,
  check:
      check ??
      DeltaCheck.of(
        _anchor(sebringLapTelemetry()),
        _anchor(sebringLap3Telemetry()),
      ),
);

List<ComparabilityChip> _chips({
  CourseCheck? course,
  StationAlignment? alignment,
  DeltaCheck? check,
  SessionMetadata? target,
  CourseFacts targetCourse = sebringCourse,
  List<ClockGap> baseGaps = const [],
  List<ClockGap> targetGaps = const [],
}) => comparabilityChips(
  course: course ?? _course(),
  comparison: _comparison(
    alignment:
        alignment ?? StationAlignment.between(sebringCourse, targetCourse),
    check: check,
  ),
  facts: PairFacts(
    base: _meta(),
    target: target ?? _meta(),
    baseLap: sebringLap(),
    targetLap: sebringLap3(),
    baseCourse: sebringCourse,
    targetCourse: targetCourse,
    baseClockGaps: baseGaps,
    targetClockGaps: targetGaps,
  ),
);

LibraryEntry _entry(
  String path, {
  required double best,
  int bestIndex = 3,
  String layout = 'Sebring School Circuit',
  String car = 'The Bend Team WRT 2025 #31:BRZ',
  String? recordingTime,
}) => LibraryEntry(
  path: path,
  fileName: path.split('/').last,
  kind: LibrarySourceKind.file,
  sizeBytes: 1,
  modifiedMs: 1,
  trackName: 'Sebring International Raceway',
  trackLayout: layout,
  carName: car,
  carClass: 'GT3',
  sessionType: SessionType.race,
  driverName: 'Diego Pestana',
  // One recording per row unless a test says otherwise: rows of one
  // recording are deduped, which is a test of its own.
  recordingTime: recordingTime ?? 'recorded as $path',
  weather: 'Clear',
  formatVersion: '1',
  completedLaps: 10,
  timedLaps: 9,
  bestLapSeconds: best,
  bestLapIndex: bestIndex,
  clockGapCount: 0,
  importedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  group('CourseCheck', () {
    test('one file is one course by construction', () {
      final check = _course(sameFile: true, targetLength: 3000);
      expect(check.verdict, CourseVerdict.sameFile);
      expect(check.refuses, isFalse);
    });

    test('the same name, layout and length is the same course', () {
      final check = _course(targetLength: 3083.35);
      expect(check.verdict, CourseVerdict.sameCourse);
      expect(check.refuses, isFalse);
    });

    test('another track is refused', () {
      final check = _course(
        target: _meta(track: 'Circuit de Spa-Francorchamps'),
      );
      expect(check.verdict, CourseVerdict.differentTrack);
      expect(check.refuses, isTrue);
      expect(check.reason, 'a different track');
    });

    test('a lap 1 m longer is another course of the track', () {
      final check = _course(targetLength: 3084.313);
      expect(check.verdict, CourseVerdict.differentLength);
      expect(check.refuses, isTrue);
      expect(check.reason, contains('3084.31 m, not 3083.31 m'));
    });

    test('length decides before the layout string (Paul Ricard 1A-V2)', () {
      final check = _course(
        base: _meta(track: 'Paul Ricard', layout: '1A'),
        target: _meta(track: 'Paul Ricard', layout: '1A-V2'),
        baseLength: 5698.65,
        targetLength: 5758.32,
      );
      expect(check.verdict, CourseVerdict.differentLength);
    });

    group('a layout variant of one length (Spa)', () {
      CourseCheck spa() => _course(
        base: _meta(
          track: 'Circuit de Spa-Francorchamps',
          layout: 'Circuit de Spa-Francorchamps',
        ),
        target: _meta(
          track: 'Circuit de Spa-Francorchamps',
          layout: 'Circuit de Spa-Francorchamps Endurance',
        ),
        baseLength: 6981.60,
        targetLength: 6981.60,
      );
      CentreComparison apart(double max) =>
          CentreComparison(bins: 1396, rms: 0.16, max: max, maxStation: 512.5);

      test('is let through to the centre line', () {
        final check = spa();
        expect(check.verdict, CourseVerdict.layoutVariant);
        expect(check.refuses, isFalse);
        expect(
          check.reason,
          'a layout variant (Circuit de Spa-Francorchamps Endurance) of the '
          'same length',
        );
      });

      test('compared when the centre lines agree within 3 m', () {
        // The library's Spa against Spa Endurance: 1.48 m at worst.
        final check = spa().withCentreLine(apart(1.48));
        expect(check.verdict, CourseVerdict.layoutVariant);
        expect(check.refuses, isFalse);
      });

      test('refused as another course past 3 m', () {
        final check = spa().withCentreLine(apart(6.02));
        expect(check.verdict, CourseVerdict.differentCentreLine);
        expect(check.refuses, isTrue);
        expect(
          check.reason,
          'a different course: the centre lines part by up to 6.0 m at 513 m',
        );
      });

      test('refused when the centre line cannot be checked', () {
        final check = spa().withCentreLine(null);
        expect(check.verdict, CourseVerdict.centreLineUnchecked);
        expect(check.refuses, isTrue);
      });
    });

    test(
      'one layout string is left to parts 1 and 2 without a centre line',
      () {
        expect(
          _course().withCentreLine(null).verdict,
          CourseVerdict.sameCourse,
        );
      },
    );

    test('a different layout of another length never reaches part 3', () {
      final check = _course(
        target: _meta(layout: 'Sebring International Raceway'),
        targetLength: 6019.0,
      );
      expect(check.verdict, CourseVerdict.differentLength);
      expect(
        check
            .withCentreLine(
              const CentreComparison(bins: 1, rms: 0, max: 0, maxStation: 0),
            )
            .verdict,
        CourseVerdict.differentLength,
      );
    });

    test('a file with no full lap is let through, unchecked', () {
      final check = _course(targetLength: null);
      expect(check.verdict, CourseVerdict.lengthUnchecked);
      expect(check.refuses, isFalse);
    });
  });

  group('comparabilityChips', () {
    String labels(List<ComparabilityChip> chips) =>
        chips.map((c) => c.label).join(' | ');

    test('a clean pair from two files shows only passed gates', () {
      final chips = _chips();
      expect(chips.map((c) => c.tone), everyElement(ChipTone.passed));
      expect(
        labels(chips),
        startsWith(
          'same course | distance aligned 0.0 m | '
          'delta checked',
        ),
      );
    });

    test('one file skips the alignment chip', () {
      final chips = _chips(
        course: _course(sameFile: true),
        alignment: StationAlignment.sharedFile,
      );
      expect(labels(chips), startsWith('same file | delta checked'));
    });

    test('3 m apart warns with the offset', () {
      final chips = _chips(
        targetCourse: const CourseFacts(
          wrapLength: 3083.313,
          sector1Station: 1032.435,
          sector2Station: 1575.549,
        ),
      );
      final chip = chips[1];
      expect(chip.label, 'distance offset 3.0 m');
      expect(chip.tone, ChipTone.warning);
      expect(chip.detail[1], 'S1 +3.00 m, S2 +3.00 m');
    });

    test('8 m apart says the delta is withheld', () {
      final chips = _chips(
        targetCourse: const CourseFacts(
          wrapLength: 3083.313,
          sector1Station: 1037.435,
          sector2Station: 1580.549,
        ),
      );
      expect(chips[1].label, 'distance offset 8.0 m: delta withheld');
    });

    test('a failed check is the one chip in the error colour', () {
      final bad = sebringLap().copyWith(
        sectors: SectorTimes.fromCumulative(
          sector1: sebringLapSector1 + 0.05,
          sector2Cumulative: sebringLapSector2Cumulative,
          lapTimeSeconds: sebringLapTimeSeconds,
        ),
      );
      final t = sebringLapTelemetry();
      final check = DeltaCheck.of(
        LapAnchor.measure(
          lap: bad,
          axis: DistanceAxis.fromSeries(t.lapDistance!),
          course: sebringCourse,
        ),
        _anchor(sebringLap3Telemetry()),
      );
      final chips = _chips(check: check);
      final chip = chips.singleWhere((c) => c.tone == ChipTone.error);
      expect(chip.label, 'delta check failed');
      expect(chip.detail.last, 'Allowed: 15.0 ms per lap, 20.0 ms per pair.');
    });

    test('pit-lane time in a lap is flagged on its side', () {
      final chips = _chips(
        targetCourse: const CourseFacts(
          wrapLength: 3083.313,
          sector1Station: 1029.435,
          sector2Station: 1572.549,
          pitLane: [PitInterval(380, 385)],
        ),
      );
      expect(labels(chips), contains('pit lane: Target'));
      expect(labels(chips), isNot(contains('pit lane: Base')));
    });

    test('a clock gap inside a lap warns; one elsewhere is neutral', () {
      final chips = _chips(
        baseGaps: const [
          ClockGap(masterRowIndex: 5000, deltaSeconds: 0.4, atSeconds: 230),
        ],
        targetGaps: const [
          ClockGap(masterRowIndex: 100, deltaSeconds: 0.4, atSeconds: 30),
        ],
      );
      final base = chips.singleWhere((c) => c.label.contains('Base'));
      final target = chips.singleWhere((c) => c.label.contains('Target'));
      expect(base.label, "clock gap in Base's lap");
      expect(base.tone, ChipTone.warning);
      expect(target.label, 'clock gaps: Target');
      expect(target.tone, ChipTone.neutral);
    });

    test('car, class and session differences are neutral facts', () {
      final chips = _chips(
        target: _meta(
          car: 'Iron Lynx 2025 #60:LM',
          carClass: 'GT3 Pro',
          session: SessionType.qualify,
        ),
      );
      final differences = chips.where((c) => c.label.startsWith('≠')).toList();
      expect(differences.map((c) => c.label), [
        '≠ car',
        '≠ class',
        '≠ session',
      ]);
      expect(differences.map((c) => c.tone), everyElement(ChipTone.neutral));
      expect(differences.first.detail, [
        'Base: The Bend Team WRT 2025 #31:BRZ',
        'Target: Iron Lynx 2025 #60:LM',
      ]);
      // Classes by name; one this build does not know keeps its own.
      expect(differences[1].detail, ['Base: LMGT3', 'Target: GT3 Pro']);
    });
  });

  group('ComparisonSet', () {
    const base = LapRef(_a, 1);
    const target = LapRef(_b, 3);

    test('a Target that is Base itself is dropped', () {
      expect(const ComparisonSet(base).withTarget(base).target, isNull);
      expect(const ComparisonSet(base).withTarget(target).target, target);
    });

    test('Swap exchanges the two', () {
      final swapped = const ComparisonSet(base, target).swapped();
      expect(swapped.base, target);
      expect(swapped.target, base);
    });

    test('knows which files it uses', () {
      const set = ComparisonSet(base, target);
      expect(set.uses(_a), isTrue);
      expect(set.uses(_b), isTrue);
      expect(
        set.uses(const TelemetrySource.path('/compare/c.duckdb')),
        isFalse,
      );
    });

    test('is a value', () {
      expect(
        const ComparisonSet(base, target),
        ComparisonSet(LapRef(_a, 1), LapRef(_b, 3)),
      );
    });
  });

  group('the workspace', () {
    ProviderContainer container({int? selected}) {
      final c = ProviderContainer(
        overrides: [
          openSessionsProvider.overrideWith(() => FixedOpenSessions([_a])),
          lapsProvider(_a).overrideWith(
            (ref) async => [sebringLap0(), sebringLap(), sebringLap3()],
          ),
        ],
      );
      addTearDown(c.dispose);
      if (selected != null) {
        c.read(selectedLapIndexProvider(_a).notifier).select(selected);
      }
      return c;
    }

    test('unchosen, it follows the current session alone', () async {
      final c = container(selected: sebringLapIndex);
      expect(
        await readFuture(c, activeComparisonProvider.future),
        const ComparisonSet(LapRef(_a, sebringLapIndex)),
      );
    });

    test("a session showing its first lap opens Compare on its best", () async {
      final c = container(selected: 0);
      expect(
        await readFuture(c, activeComparisonProvider.future),
        const ComparisonSet(LapRef(_a, sebringLap3Index)),
      );
    });

    test('a choice fixes the pair; Swap and Clear act on it', () async {
      final c = container(selected: sebringLapIndex);
      final workspace = c.read(comparisonWorkspaceProvider.notifier);
      workspace.start(
        const LapRef(_a, sebringLapIndex),
        const LapRef(_b, sebringLap3Index),
      );
      c.read(selectedLapIndexProvider(_a).notifier).select(sebringLap3Index);
      expect(
        await readFuture(c, activeComparisonProvider.future),
        const ComparisonSet(
          LapRef(_a, sebringLapIndex),
          LapRef(_b, sebringLap3Index),
        ),
      );

      workspace.swap();
      expect(
        c.read(comparisonWorkspaceProvider)!.base,
        const LapRef(_b, sebringLap3Index),
      );

      workspace.clearTarget();
      expect(c.read(comparisonWorkspaceProvider)!.target, isNull);
      // Without a Target there is nothing to swap with.
      workspace.swap();
      expect(
        c.read(comparisonWorkspaceProvider)!.base,
        const LapRef(_b, sebringLap3Index),
      );

      workspace.clear();
      expect(c.read(comparisonWorkspaceProvider), isNull);
    });

    test("a recording's first lap is its first Lap event, whatever its "
        'number', () {
      final laps = [
        sebringLap0().copyWith(index: 12),
        sebringLap().copyWith(index: 13),
      ];
      expect(isRecordingStart(laps, laps.first), isTrue);
      expect(isRecordingStart(laps, laps.last), isFalse);
    });
  });

  group('suggestTargets', () {
    const base = LapRef(_a, sebringLapIndex); // 1:04.497
    final baseSeconds = sebringLapTimeSeconds;

    List<TargetSuggestion> suggest(
      List<LibraryEntry> library, {
      LapRef? chosen,
      LapRef baseLap = base,
    }) => suggestTargets(
      base: baseLap,
      metadata: sebringMetadata,
      laps: [sebringLap0(), sebringLap(), sebringLap3()],
      library: library,
      chosen: chosen,
    );

    test('in-window sessions, same car first and nearest a second', () {
      final suggestions = suggest([
        _entry('/l/close.duckdb', best: baseSeconds - 0.1),
        _entry('/l/half.duckdb', best: baseSeconds - 0.5),
        _entry('/l/one.duckdb', best: baseSeconds - 1.1),
        _entry(
          '/l/other_car.duckdb',
          best: baseSeconds - 1.0,
          car: 'Iron Lynx 2025 #60:LM',
        ),
        _entry(
          '/l/full.duckdb',
          best: baseSeconds - 1.0,
          layout: 'Sebring International Raceway',
        ),
      ]);
      final library = suggestions
          .where((s) => s.kind == SuggestionKind.librarySession)
          .map((s) => (s.lap.source as FileTelemetrySource).path)
          .toList();
      expect(library, [
        '/l/one.duckdb',
        '/l/half.duckdb',
        '/l/other_car.duckdb',
      ]);
    });

    test('the PB is offered beyond the window, with its warning', () {
      final suggestions = suggest([
        _entry('/l/pb.duckdb', best: baseSeconds - 2.4),
      ]);
      final pb = suggestions.singleWhere(
        (s) => s.kind == SuggestionKind.personalBest,
      );
      expect(pb.gapSeconds, closeTo(2.4, 1e-9));
      expect(pb.tooFast, isTrue);
    });

    test("the file's best is offered unless it is Base", () {
      final fileBest = suggest(const []).single;
      expect(fileBest.kind, SuggestionKind.fileBest);
      expect(fileBest.lap, const LapRef(_a, sebringLap3Index));
      expect(
        fileBest.gapSeconds,
        closeTo(sebringLapTimeSeconds - sebringLap3TimeSeconds, 1e-9),
      );

      expect(
        suggest(const [], baseLap: const LapRef(_a, sebringLap3Index)),
        isEmpty,
      );
    });

    test("never Base's own recording, nor the Target already chosen", () {
      final suggestions = suggest([
        _entry(
          '/l/copy.duckdb',
          best: baseSeconds - 1.0,
          recordingTime: sebringMetadata.recordingTime,
        ),
        _entry('/l/chosen.duckdb', best: baseSeconds - 0.9),
      ], chosen: const LapRef(_a, sebringLap3Index));
      expect(
        suggestions.map((s) => s.kind),
        isNot(contains(SuggestionKind.fileBest)),
      );
      expect(
        suggestions.map((s) => (s.lap.source as FileTelemetrySource).path),
        ['/l/chosen.duckdb'],
      );
    });
  });
}
