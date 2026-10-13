// The Why card's findings and the lap-start conditions on the recordings
// themselves (comparison proposal §5, §7, §10 step 7).
//
// `test/features/compare_findings_test.dart` proves the definitions on
// constructed pedals and the 5 Hz Dart laps. Here they run on the checked-in
// fixtures at their own rates, attached read-only: the fixture's lap 2
// against its lap 4 (one file), and against the second Sebring School
// recording's lap 3 (two files) — and, where the user's LMU Telemetry folder
// is present, on a lap longer than `lapTelemetry`'s 6000 buckets.
//
// Run with (one file per run):
//   flutter test --no-pub integration_test/findings_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_finding_reads.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/lap_conditions.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_findings.dart';
import 'package:pace_reader/features/driver_comparison/domain/segment_losses.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';
const _second = 'test/fixtures/sebring_race_b_laps0_2.duckdb';

/// The user's LMU telemetry folder. Only ever attached read-only; nothing is
/// written, copied into or deleted there.
const _telemetryFolder = String.fromEnvironment(
  'LMU_TELEMETRY',
  defaultValue:
      r'C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate'
      r'\UserData\Telemetry',
);

/// The Qualify sample: its third lap (index 2) runs 122.7 s, past
/// `lapTelemetry`'s 6000 buckets for a 50 Hz pedal.
const _qualify = 'Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb';

class _Open extends OpenSessions {
  _Open(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

/// [provider]'s value, held alive while it resolves: the providers are
/// auto-disposed and nothing on screen watches them here.
Future<T> _read<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) async {
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

Future<void> _close(
  ProviderContainer container,
  Iterable<TelemetrySource> sources,
) async {
  for (final source in sources) {
    if (container.exists(telemetrySessionProvider(source))) {
      await container.read(telemetrySessionProvider(source).notifier).close();
    }
  }
  container.dispose();
}

String _f(double? v, [int d = 1]) => v == null ? '—' : v.toStringAsFixed(d);

String _describe(ComparisonFindings findings) => [
  for (final c in findings.corners)
    'corner ${_f(c.corner.station)} (Seg ${c.segment}): '
        'brake ${c.brake.withheld?.name ?? 'stated'} '
        '${_f(c.brake.base?.station)}/${_f(c.brake.target?.station)}, '
        'slowest ${_f(c.slowest.base?.speed)}@${_f(c.slowest.base?.station)}/'
        '${_f(c.slowest.target?.speed)}@${_f(c.slowest.target?.station)}, '
        'gear ${c.gear.baseLowest}/${c.gear.targetLowest}',
  for (final c in findings.contacts)
    'contact ${c.role.label} ${_f(c.station)} (Seg ${c.segment})',
].join('\n');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_findings_'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows releases the files once the app exits.
    }
  });

  testWidgets('brake points, slowest points, gears and a contact on native '
      'laps', (tester) async {
    final fixture = p.join(tmp.path, 'race.duckdb');
    final second = p.join(tmp.path, 'race_b.duckdb');
    File('$_projectRoot/$_fixture').copySync(fixture);
    File('$_projectRoot/$_second').copySync(second);
    final sources = [
      TelemetrySource.path(fixture),
      TelemetrySource.path(second),
    ];
    final container = ProviderContainer(
      overrides: [openSessionsProvider.overrideWith(() => _Open(sources))],
    );
    try {
      // One file: lap 2 against lap 4.
      final one = await _read(
        container,
        comparisonSegmentsProvider(
          ComparisonSet(LapRef(sources[0], 1), LapRef(sources[0], 3)),
        ).future,
      );
      expect(one!.findingsUnavailable, isNull);
      final findings = one.findings!;
      debugPrint('one file:\n${_describe(findings)}');

      // T1: the pedal at its recorded 50 Hz gives a brake point; the
      // Target brakes 23 m later at every threshold.
      final t1 = findings.corners.first;
      expect(t1.brake.stated, isTrue);
      expect(t1.brake.base!.station, closeTo(333.8, 1));
      expect(t1.brake.target!.station, closeTo(356.6, 1));
      for (final (threshold, difference) in [
        (2.0, -22.24),
        (5.0, -22.76),
        (10.0, -23.05),
      ]) {
        expect(
          t1.brake.differenceAt(threshold),
          closeTo(difference, 0.5),
          reason: '${threshold.toStringAsFixed(0)}%',
        );
      }
      expect(t1.brake.baseSpeed, closeTo(241.15, 0.5));
      expect(t1.brake.targetSpeed, closeTo(244.69, 0.5));
      expect((t1.gear.baseLowest, t1.gear.targetLowest), (3, 3));

      // Listed on Seg 2, its corner; flagged on Seg 1, where it starts —
      // and the walk visits Seg 2 straight after Seg 1.
      final table = one.table!;
      expect(t1.segment, 2);
      final seg1 = table.segments.firstWhere((s) => s.number == 1);
      expect(findings.brakingFrom(seg1), [t1]);
      final walk = [
        for (final stop in one.segments!.walk(SegmentOrder.mostLost))
          stop.recap ? 'recap' : stop.number,
      ];
      expect(walk, [3, 4, 1, 2, 6, 'recap']);
      expect(walk.indexOf(2), walk.indexOf(1) + 1);

      // The hairpin: Base slower and deeper, at the same apex; first gear
      // both, the Target braking 6 m earlier.
      final hairpin = findings.corners.firstWhere(
        (c) =>
            (c.slowest.base?.station ?? 0) > 790 &&
            (c.slowest.base?.station ?? 0) < 830,
      );
      expect(hairpin.slowest.stated, isTrue);
      expect(hairpin.slowest.base!.speed, closeTo(69.7, 1));
      expect(hairpin.slowest.base!.station, closeTo(813, 5));
      expect(hairpin.slowest.target!.speed, closeTo(80.2, 1));
      expect(hairpin.slowest.target!.station, closeTo(803, 5));
      expect(hairpin.slowest.differentApexes, isFalse);
      expect((hairpin.gear.baseLowest, hairpin.gear.targetLowest), (1, 1));
      expect(hairpin.brake.stated, isTrue);
      expect(hairpin.brake.difference, closeTo(6.4, 1));

      // Third gear against second at the 1495 m corner; the brake points
      // there sit within 5 m and are not called.
      final third = findings.corners.firstWhere(
        (c) => (c.corner.station - 1495).abs() < 10,
      );
      expect((third.gear.baseLowest, third.gear.targetLowest), (3, 2));
      expect(third.gear.lowestDiffers, isTrue);
      expect(third.brake.withheld, Withheld.belowFloor);

      // Base's contact, placed on Base's own axis.
      final contact = findings.contacts.single;
      expect(contact.role, ComparisonRole.base);
      expect(contact.station, closeTo(854.3, 1));
      expect(contact.segment, 3);
      expect(findings.notableSegments, {2, 3, 5, 6});

      // Two files: against the second recording's lap 3.
      final two = await _read(
        container,
        comparisonSegmentsProvider(
          ComparisonSet(LapRef(sources[0], 1), LapRef(sources[1], 2)),
        ).future,
      );
      expect(two!.findingsUnavailable, isNull);
      debugPrint('two files:\n${_describe(two.findings!)}');
      final t1b = two.findings!.corners.first;
      expect(t1b.brake.stated, isTrue);
      expect(t1b.brake.difference, closeTo(-15.4, 1));
      // The last corner's brake point is stated here, not on lap 4.
      final last = two.findings!.corners.last;
      expect(last.segment, 6);
      expect(last.brake.stated, isTrue);
      expect(last.brake.difference, closeTo(16.5, 1));
    } finally {
      await _close(container, sources);
    }
  });

  testWidgets('lap-start fuel, temperatures and the strip', (tester) async {
    final fixture = p.join(tmp.path, 'race.duckdb');
    File('$_projectRoot/$_fixture').copySync(fixture);
    final source = TelemetrySource.path(fixture);
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final conditions = await _read(
        container,
        sessionConditionsProvider(source).future,
      );
      final report = await _read(
        container,
        fuelEnergyReportProvider(source).future,
      );
      final laps = await _read(container, lapsProvider(source).future);
      for (final index in [1, 3]) {
        final lap = laps.firstWhere((l) => l.index == index);
        final own = conditions.of(lap);
        // The Fuel & Energy screen's own lap-start figure.
        expect(
          own.fuel,
          report.fuel!.laps
              .firstWhere((u) => u.lap.index == index)
              .levelAtStart,
          reason: 'lap $index',
        );
        expect(own.trackTemperature, inInclusiveRange(45.9, 47.1));
        expect(own.ambientTemperature, inInclusiveRange(31.0, 31.7));
        expect(own.wetness, (min: 0.0, max: 0.0));
        expect(own.compound, [0, 0, 0, 0]);
        debugPrint(
          'lap ${lap.displayNumber}: fuel ${_f(own.fuel)} L, track '
          '${_f(own.trackTemperature)} °C, ambient '
          '${_f(own.ambientTemperature)} °C, wear '
          '${[for (final w in own.wear.values) _f(w)]}',
        );
      }

      final chips = await _read(
        container,
        comparisonConditionsProvider(
          ComparisonSet(LapRef(source, 1), LapRef(source, 3)),
        ).future,
      );
      debugPrint(
        [for (final c in chips) '${c.label}: ${c.detail.join(' | ')}']
            .join('\n'),
      );
      expect([for (final c in chips) c.label], contains('conditions'));
      // One file: one setup, one compound and one sky.
      expect([
        for (final c in chips) c.label,
      ], isNot(anyElement(anyOf(contains('wetness'), contains('compound')))));
    } finally {
      await _close(container, [source]);
    }
  });

  testWidgets('[Lib] the pedal is read whole on a lap past 6000 buckets', (
    tester,
  ) async {
    final path = p.join(_telemetryFolder, _qualify);
    if (!File(path).existsSync() || File('$path.wal').existsSync()) {
      markTestSkipped('$_qualify is absent or still being written.');
      return;
    }
    final source = TelemetrySource.path(path);
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final reads = await _read(
        container,
        lapFindingReadsProvider(source, 2).future,
      );
      final duration = reads.lap.endSeconds! - reads.lap.startSeconds;
      expect(duration, closeTo(122.7, 0.5));
      final brake = reads.brake!;
      final decimated = (await _read(
        container,
        lapTelemetryProvider(source, 2).future,
      )).channels[brakePedalChannelName]!;
      debugPrint(
        'Spa Q lap 3 (${_f(duration, 2)} s): ${brake.length} pedal samples '
        'read whole, ${decimated.length} in lapTelemetry',
      );
      expect(brake.frequencyHz, 50);
      expect(brake.length, closeTo(duration * 50, duration * 50 * 0.02));
      expect(decimated.length, lessThan(brake.length));
      expect(reads.speed!.length, greaterThan(brake.length));
    } finally {
      await _close(container, [source]);
    }
  }, skip: !Directory(_telemetryFolder).existsSync());
}
