// The race-pace report read from real DuckDB files (SPEC.md §8.9).
//
// An integration_test for the reason `data_layer_test.dart` is: dart_duckdb's
// native library is linked into a compiled app, not into the `flutter test`
// runner. The derivations are covered in `test/features/race_pace_test.dart`
// against the Race readings as Dart source; what only a real file can show is
// that the two reads `racePaceReport` makes — the decimated session trace and
// the full-resolution series — and the SQL per-lap aggregates agree with each
// other and with those fixtures, which were generated from the samples by a
// separate implementation (`tool/make_gap_fixture.py`).
//
// Run with:
//   flutter test integration_test/race_pace_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"
//
// The checked-in fixture holds laps 0-3 of the Race sample. Add
// `--dart-define=SAMPLES_ROOT=/path/to/samples` to also run the same checks on
// the full Race sample and the not-a-race branch on the Qualify and Practice
// files (those are git-ignored, so the group skips without it).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/race_pace/application/race_pace.dart';

import '../test/fixtures/gap_samples.dart';
import '../test/fixtures/sebring_race_per_lap.dart';

const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');
const _samplesRoot = String.fromEnvironment('SAMPLES_ROOT');
const _fixture = 'test/fixtures/sebring_race_laps0_3.duckdb';
const _raceSample = 'Sebring International Raceway_R_2026-07-07T06_42_17Z.duckdb';
const _qualifySample =
    'Circuit de Spa-Francorchamps_Q_2026-07-24T02_06_11Z.duckdb';
const _practiceSample =
    'Autódromo José Carlos Pace_P_2026-07-22T02_43_34Z.duckdb';

/// The fixture holds each reading as the shortest decimal that round-trips the
/// file's 32-bit FLOAT; DuckDB hands the same reading back widened to a double
/// (`-0.18789291381835938`). Equal once narrowed again.
double _f32(double value) => (Float32List(1)..[0] = value)[0];

void _expectSameReadings(Float64List actual, Float64List expected,
    {int? count}) {
  final n = count ?? expected.length;
  expect(actual.length, n);
  for (var i = 0; i < n; i++) {
    expect(actual[i], _f32(expected[i]), reason: 'reading $i');
  }
}

Future<RacePaceReport> _report(String path) async {
  expect(File(path).existsSync(), isTrue, reason: 'missing $path');
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container
      .read(racePaceReportProvider(TelemetrySource.path(path)).future);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('the checked-in fixture (Race laps 0-3)', () {
    late GapSession session;

    setUpAll(() async {
      final report = await _report('$_projectRoot/$_fixture');
      expect(report.sessionType, SessionType.race);
      session = report.session!;
    });

    testWidgets('reads the same readings the whole-file fixture holds',
        (tester) async {
      // The fixture's laps end where lap 4 opens, which is not a sample
      // boundary: it ends on the last reading at or before that, and every
      // reading it does hold is the one the whole file has at that index.
      final whole = sebringRaceGapSeries();
      expect(session.readings.length, lessThan(whole.length));
      expect(session.readings.length, greaterThan(700));
      _expectSameReadings(session.readings.lows, whole.lows,
          count: session.readings.length);
      for (var i = 0; i < session.readings.length; i++) {
        expect(session.readings.times[i], closeTo(whole.times[i], 1e-9));
      }
      expect(session.originSeconds, sebringRaceGapOrigin);
    });

    testWidgets('draws from at most 1,000 buckets that cover every reading',
        (tester) async {
      final envelope = session.envelope;
      expect(envelope.length, lessThanOrEqualTo(sessionEnvelopeBuckets));
      expect(envelope.length, greaterThan(100));
      // Min/max buckets keep the extremes however hard they decimate.
      expect(envelope.minValue, session.readings.minValue);
      expect(envelope.maxValue, session.readings.maxValue);
    });

    testWidgets('finds the three passes of lap 1 and the grid start',
        (tester) async {
      expect(
        [for (final c in session.changes) c.timeSeconds - sebringRaceGapOrigin],
        [122.5, 124.0, 165.0],
      );
      expect(session.heldAtStart?.count, 86);
      expect(session.heldAtStart?.value, closeTo(-0.18789, 1e-5));
      expect(session.heldAtEnd, isNull, reason: 'the fixture stops mid-race');
    });

    testWidgets('each lap opens on the reading the SQL calls its first',
        (tester) async {
      // `lapGapsFrom` takes `start` from `lapStatsSql`'s `first` and finds the
      // closing reading in the full series by the same rule; if the two
      // disagreed about which row a boundary belongs to, this is where it
      // would show.
      for (final gap in session.laps) {
        if (gap.start == null) continue;
        final index =
            firstReadingAtOrAfter(session.readings.times, gap.lap.startSeconds);
        expect(gap.start, session.readings.lows[index],
            reason: 'lap ${gap.lap.displayNumber}');
      }
    });

    testWidgets('per-lap figures match the whole-file fixture where the next '
        'lap exists to close them', (tester) async {
      final whole = GapSession.derive(
        readings: sebringRaceGapSeries(),
        envelope: sebringRaceGapEnvelope(),
        laps: sebringRaceLaps(),
        stats: sebringRaceGapStats(),
        originSeconds: sebringRaceGapOrigin,
        endSeconds: 1364.18,
      );
      // Laps 0-2 are closed by the first reading of the lap after them, which
      // both files hold; lap 3's closing reading is lap 4's, which only the
      // whole file does.
      for (var i = 0; i < 3; i++) {
        final a = session.laps[i];
        final b = whole.laps[i];
        expect(a.start, closeTo(b.start!, 1e-6), reason: 'lap $i start');
        expect(a.end, closeTo(b.end!, 1e-6), reason: 'lap $i end');
        expect(a.gained, closeTo(b.gained!, 1e-6), reason: 'lap $i gained');
        expect(a.closest, closeTo(b.closest!, 1e-6), reason: 'lap $i closest');
        expect(a.mean, closeTo(b.mean!, 1e-4), reason: 'lap $i mean');
        expect(a.changes.length, b.changes.length);
      }
    });
  });

  group('the full samples', () {
    final root = _samplesRoot;

    testWidgets('the Race sample agrees with the fixtures end to end',
        (tester) async {
      final report = await _report('$root/$_raceSample');
      final session = report.session!;
      final whole = sebringRaceGapSeries();
      expect(session.readings.length, 2682);
      _expectSameReadings(session.readings.lows, whole.lows);
      final drawn = sebringRaceGapEnvelope();
      expect(session.envelope.length, drawn.length);
      _expectSameReadings(session.envelope.lows, drawn.lows);
      _expectSameReadings(session.envelope.highs, drawn.highs);
      expect(session.changes, hasLength(3));
      expect(session.heldAtStart?.count, 86);
      expect(session.heldAtEnd?.count, 22);
      expect(session.laps, hasLength(20));
      expect(session.countedLaps, hasLength(19));
      expect(session.netGained, closeTo(-3.47, 0.005));
      expect(session.startGap, closeTo(-0.18789, 1e-5));
      expect(session.endGap, closeTo(-6.95837, 1e-5));
    }, skip: root.isEmpty);

    testWidgets('a qualifying session is refused before the channel is read',
        (tester) async {
      final report = await _report('$root/$_qualifySample');
      expect(report.sessionType, SessionType.qualify);
      expect(report.unavailable, GapUnavailable.notARace);
      expect(report.session, isNull);
    }, skip: root.isEmpty);

    testWidgets('and so is a practice session', (tester) async {
      final report = await _report('$root/$_practiceSample');
      expect(report.sessionType, SessionType.practice);
      expect(report.unavailable, GapUnavailable.notARace);
    }, skip: root.isEmpty);
  });
}
