// The Why card's findings, the Tyres tab and the lap-start chips
// (comparison proposal §2, §5 "Findings and segments", §7, §9, step 7).
//
// The 5 Hz Sebring fixture laps — Base lap 2 (index 1) against Target lap 4
// (index 3) — carry a pedal ten times slower than the recording's, so the
// brake point reads "not stated: data rate" on them; the native values are
// asserted in `integration_test/findings_test.dart`. Here the brake logic
// runs on constructed pedals, and on the fixture's pedal resampled to 50 Hz.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_focus.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_workspace.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/lap_conditions.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_findings.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_losses.dart';
import 'package:pace_reader/features/driver_comparison/presentation/driver_comparison_screen.dart';
import 'package:pace_reader/features/driver_comparison/presentation/finding_text.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/setup_viewer/application/car_setup.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/presentation/corner_card.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

import '../fixtures/car_setup_samples.dart';
import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';
import '../fixtures/sebring_race_per_lap.dart';
import '../fixtures/tyre_reports.dart';
import 'compare_harness.dart';

final _base = CompareFile('/findings/base.duckdb');
final _other = CompareFile(
  '/findings/other.duckdb',
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

/// The same two files with the pedal resampled to 50 Hz.
final _base50 = CompareFile('/findings/base50.duckdb', brakeHz: 50);
final _other50 = CompareFile(
  '/findings/other50.duckdb',
  brakeHz: 50,
  metadata: sebringMetadata.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
);

ComparisonSet _pair(CompareFile base, CompareFile target) => ComparisonSet(
  LapRef(base.source, sebringLapIndex),
  LapRef(target.source, sebringLap3Index),
);

Future<ComparisonSegments> _segments(List<CompareFile> files) async {
  final container = ProviderContainer(
    overrides: compareOverrides(files: files, open: files),
  );
  addTearDown(container.dispose);
  return (await readFuture<ComparisonSegments?>(
    container,
    comparisonSegmentsProvider(_pair(files.first, files.last)).future,
  ))!;
}

// ---------------------------------------------------------------------------
// Constructed laps: a steady 50 m/s, so station s is reached at s / 50 s.

const _speed = 50.0;

TraceSeries _series(List<double> times, List<double> values, {int hz = 50}) =>
    TraceSeries(
      channelName: 'constructed',
      unit: '',
      frequencyHz: hz,
      valueColumn: 'value',
      times: Float64List.fromList(times),
      lows: Float64List.fromList(values),
      highs: Float64List.fromList(values),
    );

DistanceAxis _axis() => DistanceAxis.fromSeries(
  _series(
    [for (var i = 0; i <= 600; i++) i / 10],
    [for (var i = 0; i <= 600; i++) i / 10 * _speed],
    hz: 10,
  ),
);

/// [knots] as `(station, value)`, linear between them, sampled at [hz].
TraceSeries _sampled(List<(double, double)> knots, {int hz = 50}) {
  double at(double s) {
    if (s <= knots.first.$1) return knots.first.$2;
    for (var k = 1; k < knots.length; k++) {
      if (s <= knots[k].$1) {
        final (s0, v0) = knots[k - 1];
        final (s1, v1) = knots[k];
        return v0 + (v1 - v0) * (s - s0) / (s1 - s0);
      }
    }
    return knots.last.$2;
  }

  final n = 60 * hz;
  final times = [for (var i = 0; i <= n; i++) i / hz];
  return _series(times, [for (final t in times) at(t * _speed)], hz: hz);
}

/// A pedal at 0 apart from a ramp from [from] to 80% over 4 m, held to
/// [from] + 40 m.
List<(double, double)> _ramp(double from) => [
  (0, 0),
  (from, 0),
  (from + 4, 80),
  (from + 40, 80),
  (from + 45, 0),
  (3000, 0),
];

FindingLap _lap({
  List<(double, double)>? pedal,
  int pedalHz = 50,
  List<(double, double)>? speed,
  StepSeries? gear,
}) => FindingLap.of(
  axis: _axis(),
  brake: pedal == null ? null : _sampled(pedal, hz: pedalHz),
  speed: speed == null ? null : _sampled(speed, hz: 100),
  gear: gear,
);

void main() {
  group('brake points on constructed pedals', () {
    test('the main ramp, not a light pre-brake, at 2, 5 and 10%', () {
      final lap = _lap(
        pedal: [
          (0, 0),
          // An 8% touch 1.8 s before the real braking: its own zone.
          (100, 0),
          (102, 8),
          (110, 8),
          (112, 0),
          ..._ramp(200).skip(1),
        ],
      );
      final onset = mainRampOnset(lap.brake!, from: 0, to: 400)!;
      // The ramp climbs 20% a metre from 200 m.
      expect(onset.stations[2]!, closeTo(200.1, 0.02));
      expect(onset.stations[5]!, closeTo(200.25, 0.02));
      expect(onset.stations[10]!, closeTo(200.5, 0.02));
      expect(onset.peak, 80);
    });

    test("a zone that opens within a second of the lap's start is the "
        "previous corner's, never chosen", () {
      final lap = _lap(pedal: _ramp(20));
      expect(mainRampOnset(lap.brake!, from: 0, to: 400), isNull);
    });

    test('stated from 5 m when all three thresholds agree', () {
      final finding = BrakeFinding.measure(
        _lap(pedal: _ramp(100)),
        _lap(pedal: _ramp(120)),
        from: 0,
        to: 400,
      );
      expect(finding.stated, isTrue);
      for (final threshold in brakeOnsetThresholds) {
        expect(finding.differenceAt(threshold), closeTo(-20, 0.01));
      }
      expect(brakeText(finding), 'Target brakes 20 m later (120 vs 100 m).');

      final close = BrakeFinding.measure(
        _lap(pedal: _ramp(100)),
        _lap(pedal: _ramp(103)),
        from: 0,
        to: 400,
      );
      expect(close.withheld, Withheld.belowFloor);
      expect(brakeText(close), startsWith('Brake points within 5 m'));
    });

    test('not stated when the thresholds disagree on which lap is later', () {
      // Base eases on from 100 m and reaches 10% at 110 m; the Target stamps
      // on at 105.5 m: earlier at 2%, later at 10%.
      final finding = BrakeFinding.measure(
        _lap(
          pedal: [(0, 0), (100, 0), (110, 10), (112, 80), (140, 80), (145, 0)],
        ),
        _lap(pedal: [(0, 0), (105.5, 0), (106.5, 80), (140, 80), (145, 0)]),
        from: 0,
        to: 400,
      );
      expect(finding.differenceAt(2), lessThan(0));
      expect(finding.differenceAt(10), greaterThan(0));
      expect(finding.withheld, Withheld.thresholdsDisagree);
      expect(brakeText(finding), contains('disagree'));
    });

    test('not stated from a pedal slower than the recorded 50 Hz', () {
      final finding = BrakeFinding.measure(
        _lap(pedal: _ramp(100), pedalHz: 10),
        _lap(pedal: _ramp(120)),
        from: 0,
        to: 400,
      );
      expect(finding.withheld, Withheld.dataRate);
      expect(finding.withheldFor, ComparisonRole.base);
      expect(brakeText(finding), contains('not stated: data rate'));
    });
  });

  group('slowest points and gears on constructed laps', () {
    test('different apexes only across a hump of 2 km/h on both laps', () {
      final apart = SlowestFinding.measure(
        _lap(speed: [(0, 200), (780, 70), (810, 90), (840, 72), (3000, 200)]),
        _lap(speed: [(0, 200), (780, 74), (810, 90), (840, 68), (3000, 200)]),
        apex: 800,
      );
      expect(apart.base!.station, closeTo(780, 1));
      expect(apart.target!.station, closeTo(840, 1));
      expect(apart.differentApexes, isTrue);
      expect(slowestText(apart), endsWith('(different apexes).'));

      final together = SlowestFinding.measure(
        _lap(speed: [(0, 200), (790, 70), (3000, 200)]),
        _lap(speed: [(0, 200), (810, 80), (3000, 200)]),
        apex: 800,
      );
      expect(together.differentApexes, isFalse);
      expect(
        slowestText(together),
        'Slowest: Base 70 $kmh at 790 m, Target 80 $kmh at 810 m (same apex).',
      );
    });

    test("a minimum on the window's edge is not the corner's", () {
      final finding = SlowestFinding.measure(
        _lap(speed: [(0, 200), (735, 50), (3000, 200)]),
        _lap(speed: [(0, 200), (800, 80), (3000, 200)]),
        apex: 800,
      );
      expect(finding.withheld, Withheld.notFound);
      expect(finding.withheldFor, ComparisonRole.base);
      expect(slowestText(finding), startsWith('Slowest point not found'));
    });

    StepSeries gear(List<(double, double)> rows) =>
        StepSeries.fromRows(rows, eventName: 'Gear');

    test('the lowest gear is the one at the slowest point; a downshift is '
        'called from 5 m, only when both laps make the same ones', () {
      final speed = [(0.0, 200.0), (500.0, 80.0), (3000.0, 200.0)];
      // Seconds; station = 50 m/s × t.
      final base = _lap(
        speed: speed,
        gear: gear([(0, 5), (8.0, 0), (8.0025, 4), (9.0, 0), (9.0025, 3)]),
      );
      final target = _lap(
        speed: speed,
        gear: gear([(0, 5), (8.2, 0), (8.2025, 4), (9.02, 0), (9.0225, 3)]),
      );
      final slowest = SlowestFinding.measure(base, target, apex: 500);
      final finding = GearFinding.measure(
        base,
        target,
        previousApex: 0,
        apex: 500,
        slowest: slowest,
      );
      expect(finding.baseLowest, 3);
      expect(finding.sameDownshifts, isTrue);
      expect(finding.statedDownshifts, hasLength(1));
      expect(gearText(finding), [
        'Lowest gear: both 3rd.',
        'Downshift to 4th: Target 10 m later (410 vs 400 m).',
      ]);

      final skipping = GearFinding.measure(
        base,
        _lap(speed: speed, gear: gear([(0, 5), (8.2, 0), (8.2025, 3)])),
        previousApex: 0,
        apex: 500,
        slowest: slowest,
      );
      expect(skipping.statedDownshifts, isEmpty);
      expect(
        gearText(skipping).last,
        'Downshifts differ (Base 5→4→3, Target 5→3), so their stations are '
        'not compared.',
      );
    });
  });

  group('the fixture at 5 Hz', () {
    test('no brake point: the pedal is ten times too slow', () async {
      final segments = await _segments([_base, _other]);
      final findings = segments.findings!;
      expect(findings.corners, hasLength(5));
      for (final corner in findings.corners) {
        expect(corner.brake.withheld, Withheld.dataRate);
        expect(brakeText(corner.brake), contains('not stated: data rate'));
      }
      expect(throttleNotStated, contains('not stated'));
      expect(throttleNotStated, contains("the detector's threshold"));
    });

    test("the hairpin's slowest points: Base 69.7 km/h at 813 m, the Target "
        '80.2 km/h at 803 m, on one apex', () async {
      final hairpin = (await _segments([_base, _other])).findings!
          .inSegment(3)!;
      final slowest = hairpin.slowest;
      expect(slowest.base!.speed, closeTo(69.7, 1));
      expect(slowest.base!.station, closeTo(813, 5));
      expect(slowest.target!.speed, closeTo(80.2, 1));
      expect(slowest.target!.station, closeTo(803, 5));
      expect(slowest.differentApexes, isFalse);
      expect(slowestText(slowest), endsWith('(same apex).'));
      expect(gearText(hairpin.gear).first, 'Lowest gear: both 1st.');
    });

    test('the contact is in Seg 3, at 854 m on Base', () async {
      final findings = (await _segments([_base, _other])).findings!;
      final contact = findings.contacts.single;
      expect(contact.role, ComparisonRole.base);
      expect(contact.station, closeTo(854, 2));
      expect(contact.segment, 3);
      expect(contactText(contact), 'Contact recorded at 854 m (Base).');
    });

    test(
      'a level segment holding a finding is visited: Seg 2 after Seg 1',
      () async {
        final segments = await _segments([_base, _other]);
        final comparison = segments.segments!;
        expect(segments.findings!.inSegment(2)!.notable, isTrue);
        expect(comparison.byNumber(2)!.level, isTrue);
        expect(comparison.levelButNotable(comparison.byNumber(2)!), isTrue);
        expect(
          [
            for (final stop in comparison.walk(SegmentOrder.mostLost))
              stop.recap ? 'recap' : stop.number,
          ],
          [3, 4, 1, 2, 6, 'recap'],
        );
      },
    );
  });

  group('the fixture with its pedal at 50 Hz', () {
    test(
      'T1: the Target brakes later, listed on Seg 2 and flagged on Seg 1',
      () async {
        final segments = await _segments([_base50, _other50]);
        final findings = segments.findings!;
        final t1 = findings.inSegment(2)!;
        expect(t1.brake.stated, isTrue);
        for (final threshold in brakeOnsetThresholds) {
          expect(t1.brake.differenceAt(threshold), lessThan(-20));
        }
        expect(brakeText(t1.brake), matches(r'^Target brakes 2\d m later'));
        expect(t1.brake.speedStated, isTrue);
        expect(
          brakeSpeedText(t1.brake),
          startsWith('Speed at the brake point'),
        );

        final seg1 = segments.table!.segments.first;
        expect(findings.brakingFrom(seg1), [t1]);
        expect(
          brakingFromText(t1, seg1, 'Seg 2'),
          matches(r'^Braking for Seg 2 starts here: Base at 3\d\d m\.$'),
        );
        // A within-floor onset in another segment is not flagged.
        expect(findings.brakingFrom(segments.table!.segments[3]), isEmpty);
      },
    );
  });

  group('lap conditions', () {
    const level = LapConditions(
      fuel: 38.6,
      energy: 44.3,
      wetness: (min: 0, max: 0),
      compound: [0, 0, 0, 0],
      trackTemperature: 46.4,
      ambientTemperature: 31.3,
    );

    List<String> labels(List<ComparabilityChip> chips) => [
      for (final chip in chips) chip.label,
    ];

    test('every value in one neutral chip; "≠" chips only past their '
        'thresholds', () {
      expect(
        labels(conditionChips(base: level, target: level, sameCar: true)),
        ['conditions'],
      );
      const other = LapConditions(
        fuel: 64.95,
        energy: 9.05e10,
        wetness: (min: 5, max: 5),
        compound: [1, 1, 1, 1],
        trackTemperature: 51.5,
        ambientTemperature: 33,
      );
      final chips = conditionChips(base: level, target: other, sameCar: true);
      expect(labels(chips), [
        '≠ fuel 38.6 / 65.0 L',
        '≠ wetness dry / 5%',
        '≠ compound 0 / 1',
        '≠ track 46 / 52 °C',
        'conditions',
      ]);
      // Virtual energy outside 0–100 is no share of anything.
      expect(
        chips.last.detail,
        contains(startsWith('Virtual energy: 44.3% / n/a')),
      );
      // Within 25 L and 5 °C: in the popover, not a chip.
      const near = LapConditions(fuel: 50, trackTemperature: 50);
      expect(labels(conditionChips(base: level, target: near, sameCar: true)), [
        'conditions',
      ]);
      // The compound index means nothing across cars.
      expect(
        labels(conditionChips(base: level, target: other, sameCar: false)),
        isNot(contains(startsWith('≠ compound'))),
      );
    });

    test("a lap's start is the fuel view's own, and its wetness is what was "
        'in force over it', () {
      final laps = sebringRaceLaps();
      final fuel = ResourceUsage.derive(
        name: 'Fuel',
        unit: 'L',
        laps: laps,
        stats: sebringRaceFuelStats(),
      );
      final conditions = SessionConditions(
        fuel: {for (final s in sebringRaceFuelStats()) s.lapIndex: s},
        wetness: StepSeries.fromRows([
          (0.0, 0.0),
          (220.0, 5.0),
        ], eventName: 'Minimum Path Wetness'),
      );
      for (final index in [sebringLapIndex, sebringLap3Index]) {
        expect(conditions.of(laps[index]).fuel, fuel.laps[index].levelAtStart);
      }
      expect(conditions.of(laps[sebringLapIndex]).wetness, (min: 0, max: 5));
      expect(conditions.of(laps[sebringLap3Index]).wetness, (min: 5, max: 5));
    });

    test('setup: the differing settings by the game\'s rendering, and a '
        'fixed setup says so', () {
      final race = CarSetup.parse(sebringCarSetup.json);
      expect(CarSetup.diff(race, race), isEmpty);
      final moved = CarSetup.parse(
        sebringCarSetup.json.replaceFirst(
          '"stringValue":"51.2:48.8"',
          '"stringValue":"52.0:48.0"',
        ),
      );
      final differences = CarSetup.diff(race, moved);
      expect(differences.single.key, 'VM_BRAKE_BALANCE');
      expect(differences.single.base, '51.2:48.8');
      expect(differences.single.target, '52.0:48.0');
      final chip = setupChip(race, moved)!;
      expect(chip.label, 'setup: 1 difference');
      expect(
        chip.detail,
        contains(endsWith('Base 51.2:48.8, Target 52.0:48.0')),
      );
      expect(
        chip.detail,
        contains(
          'Both sessions fix the setup: only 27 of 170 settings are free.',
        ),
      );
      expect(chip.detail.where((l) => l.contains('fix')), hasLength(1));
      expect(setupChip(race, CarSetup.empty), isNull);
    });
  });

  group('on screen', () {
    Future<ProviderContainer> pump(
      WidgetTester tester,
      List<CompareFile> files,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = GoRouter(
        initialLocation: '/driver-comparison',
        routes: [
          GoRoute(
            path: '/driver-comparison',
            builder: (context, state) => const DriverComparisonScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: compareOverrides(files: files, open: files),
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Router<Object>)),
      );
      final set = _pair(files.first, files.last);
      container
          .read(comparisonWorkspaceProvider.notifier)
          .start(set.base, set.target);
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> select(
      WidgetTester tester,
      ProviderContainer container,
      List<CompareFile> files,
      int number,
    ) async {
      final set = _pair(files.first, files.last);
      final segments = await readFuture<ComparisonSegments?>(
        container,
        comparisonSegmentsProvider(set).future,
      );
      container
          .read(segmentFocusProvider.notifier)
          .select(set, WalkStop(segments!.segments!.byNumber(number)!));
      await tester.pumpAndSettle();
    }

    TrackMapView mapView(WidgetTester tester) =>
        tester.widget<TrackMapView>(find.byType(TrackMapView));

    testWidgets("the Why card states the open segment's corner", (
      tester,
    ) async {
      await pump(tester, [_base, _other]);
      // Seg 3, the worst, is open.
      expect(
        find.text('Seg 3 · Base vs Target · net +0.296 s'),
        findsOneWidget,
      );
      expect(find.textContaining('not stated: data rate'), findsOneWidget);
      expect(
        find.text(
          'Slowest: Base 70 $kmh at 810 m, Target 80 $kmh at 805 m '
          '(same apex).',
        ),
        findsOneWidget,
      );
      expect(find.text('Lowest gear: both 1st.'), findsOneWidget);
      expect(find.text('Contact recorded at 854 m (Base).'), findsOneWidget);
      expect(find.text(throttleNotStated), findsOneWidget);
      expect(find.byTooltip(findingFloors.join('\n\n')), findsOneWidget);
      // A contact is marked on the map with its segment.
      expect(
        mapView(tester).marks.map((m) => m.shape),
        containsAll([TrackMarkShape.dot, TrackMarkShape.contact]),
      );
    });

    testWidgets('a brake point that starts a segment early links to its '
        "corner's segment", (tester) async {
      final files = [_base50, _other50];
      final container = await pump(tester, files);
      await select(tester, container, files, 1);
      expect(
        find.textContaining('Braking for Seg 2 starts here: Base at'),
        findsOneWidget,
      );
      // Seg 1's map carries T1's brake points, though its corner is Seg 2's.
      expect(
        mapView(tester).marks.where((m) => m.shape == TrackMarkShape.diamond),
        hasLength(2),
      );

      await tester.tap(find.widgetWithText(TextButton, 'Seg 2 ›'));
      await tester.pumpAndSettle();
      final set = _pair(files.first, files.last);
      expect(
        container.read(segmentFocusProvider).forSet(set).selected?.number,
        2,
      );
      expect(find.textContaining('Seg 2 · Base vs Target'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^Target brakes 2\d m later')),
        findsOneWidget,
      );
      final marks = mapView(tester).marks;
      for (final shape in [TrackMarkShape.diamond, TrackMarkShape.dot]) {
        expect(marks.where((m) => m.shape == shape).map((m) => m.hollow), [
          false,
          true,
        ], reason: '$shape: Base filled, the Target hollow');
      }
    });

    testWidgets('Tyres: one corner of each lap, Base over the Target, on one '
        'scale', (tester) async {
      await pump(tester, [_base, _other]);
      await tester.tap(find.widgetWithText(Tab, 'Tyres'));
      await tester.pumpAndSettle();
      expect(find.text('Base · Lap 2'), findsOneWidget);
      expect(find.text('Target · Lap 4'), findsOneWidget);
      List<CornerCard> cards() =>
          tester.widgetList<CornerCard>(find.byType(CornerCard)).toList();
      expect(cards(), hasLength(2));
      final report = sebringRaceTyreReport();
      expect(cards().map((c) => c.rampRange).toSet(), {
        sharedTreadRampRange([report, report]),
      });
      expect(cards().first.snapshot.corner, Corner.frontLeft);
      expect(
        cards().first.snapshot.pressure!.mean,
        report
            .snapshot(report.laps[sebringLapIndex])[Corner.frontLeft]!
            .pressure!
            .mean,
      );
      // No trend beside them: no figure is a button.
      expect(cards().every((c) => c.onSelectMetric == null), isTrue);

      await tester.tap(find.text('RR'));
      await tester.pumpAndSettle();
      expect(cards().map((c) => c.snapshot.corner).toSet(), {Corner.rearRight});
    });

    testWidgets('the strip gains the conditions and the setup once read', (
      tester,
    ) async {
      final setup = sebringMetadata.copyWith(
        carSetupJson: sebringCarSetup.json,
      );
      final base = CompareFile('/findings/setup.duckdb', metadata: setup);
      final fuller = CompareFile(
        '/findings/fuller.duckdb',
        fuelOffset: 30,
        metadata: setup.copyWith(recordingTime: '2026-07-07T05_57_04Z'),
      );
      await pump(tester, [base, fuller]);
      expect(find.widgetWithText(ActionChip, 'conditions'), findsOneWidget);
      expect(
        find.widgetWithText(ActionChip, '≠ fuel 38.6 / 65.0 L'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ActionChip, 'setup: 0 differences'),
        findsOneWidget,
      );
    });
  });
}
