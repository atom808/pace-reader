// Lines and courses on the recordings themselves (comparison proposal §10,
// step 5).
//
// `test/features/compare_lines_test.dart` proves the centre path, the line
// and the gates on the 5 Hz Dart laps. Here they run as the app runs them:
// GPS, `Lap Dist`, `Path Lateral` and `Track Edge` at 10 Hz from the
// checked-in fixtures attached read-only; a constructed variant, a temp copy
// of the second Sebring recording with 200 m of its GPS moved 6 m sideways;
// and, where the user's LMU Telemetry folder is present, Spa against Spa
// Endurance, COTA's March against its September, and every pair of Sebring
// School recordings.
//
// Run with (one file per run):
//   flutter test --no-pub integration_test/lines_test.dart -d windows \
//     --dart-define=PROJECT_ROOT="$(pwd)"

import 'dart:io';
import 'dart:math' as math;

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/comparison_chart.dart';
import 'package:pace_reader/features/driver_comparison/application/segment_tables.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparability.dart';
import 'package:pace_reader/features/driver_comparison/domain/comparison_set.dart';
import 'package:pace_reader/features/driver_comparison/domain/lines.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/color_tokens.dart';

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

class _Open extends OpenSessions {
  _Open(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

/// [provider]'s value, held alive while it resolves.
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

Future<void> _closeAll(
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

/// One lap's car positions by station, for measuring GPS against `Path
/// Lateral` without either of the app's own reconstructions.
class _CarPath {
  _CarPath(LapTelemetry lap, LocalFrame frame) {
    final d = lap.lapDistance!;
    for (var i = 0; i < d.length; i++) {
      if (stations.isNotEmpty && d.lows[i] <= stations.last) continue;
      stations.add(d.lows[i]);
      points.add(frame.project(lap.latitude!.lows[i], lap.longitude!.lows[i]));
      lateral.add(lap.pathLateral!.lows[i]);
    }
  }

  final stations = <double>[];
  final points = <Offset>[];
  final lateral = <double>[];

  int _k(double s) {
    var k = 0;
    while (k < stations.length - 2 && stations[k + 1] < s) {
      k++;
    }
    return k;
  }

  Offset at(double s) {
    final k = _k(s);
    final u = (s - stations[k]) / (stations[k + 1] - stations[k]);
    return Offset.lerp(points[k], points[k + 1], u)!;
  }

  double lateralAt(double s) {
    final k = _k(s);
    final u = (s - stations[k]) / (stations[k + 1] - stations[k]);
    return lateral[k] + (lateral[k + 1] - lateral[k]) * u;
  }
}

/// The least-squares slope of [ys] on [xs].
double _slope(List<double> xs, List<double> ys) {
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxx = 0.0;
  var sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sxx += (xs[i] - mx) * (xs[i] - mx);
    sxy += (xs[i] - mx) * (ys[i] - my);
  }
  return sxy / sxx;
}

/// Moves the GPS of [path]'s laps [metres] to the right of the car's heading
/// wherever `Lap Dist` is in [from, to): a course that keeps its length but
/// bends differently over one stretch. [path] is a temp copy, opened
/// read-write by this test alone.
Future<int> _displace(
  String path, {
  required double from,
  required double to,
  required double metres,
}) async {
  final db = await duckdb.open(path);
  final con = await duckdb.connect(db);
  try {
    final rows = (await con.query(
      'SELECT d.rowid, d.value, la.value, lo.value FROM "Lap Dist" d '
      'JOIN "GPS Latitude" la ON la.rowid = d.rowid '
      'JOIN "GPS Longitude" lo ON lo.rowid = d.rowid ORDER BY d.rowid',
    )).fetchAll();
    const perDegree = 111320.0;
    final lat = [for (final r in rows) (r[2]! as num).toDouble()];
    final lon = [for (final r in rows) (r[3]! as num).toDouble()];
    final lonScale = perDegree * math.cos(lat.first * math.pi / 180);
    var moved = 0;
    for (var i = 1; i < rows.length - 1; i++) {
      final d = (rows[i][1]! as num).toDouble();
      if (d < from || d >= to) continue;
      final dx = (lon[i + 1] - lon[i - 1]) * lonScale;
      final dy = (lat[i + 1] - lat[i - 1]) * perDegree;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length == 0) continue;
      final rowid = rows[i][0];
      // The right-hand normal: the heading turned a quarter clockwise.
      await con.execute(
        'UPDATE "GPS Latitude" SET value = '
        '${lat[i] - dx / length * metres / perDegree} WHERE rowid = $rowid',
      );
      await con.execute(
        'UPDATE "GPS Longitude" SET value = '
        '${lon[i] + dy / length * metres / lonScale} WHERE rowid = $rowid',
      );
      moved++;
    }
    return moved;
  } finally {
    await con.dispose();
    await db.dispose();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pace_lines_'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('fixture laps 2 and 4 at their recorded rate', (tester) async {
    final path = p.join(tmp.path, 'race.duckdb');
    File('$_projectRoot/$_fixture').copySync(path);
    final source = TelemetrySource.path(path);
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final base = await _read(
        container,
        lapTelemetryProvider(source, 1).future,
      );
      final target = await _read(
        container,
        lapTelemetryProvider(source, 3).future,
      );
      expect(base.pathLateral!.length, base.lapDistance!.length);
      expect(base.trackEdge!.length, base.lapDistance!.length);
      final frame = LocalFrame.around(base)!;

      // Path Lateral is the GPS's lateral separation, + to the right:
      // −0.997 against the left-hand normal (§6).
      final baseCar = _CarPath(base, frame);
      final targetCar = _CarPath(target, frame);
      final gps = <double>[];
      final lateral = <double>[];
      for (var i = 0; i < targetCar.stations.length; i++) {
        final s = targetCar.stations[i];
        if (s < baseCar.stations.first + 5 || s > baseCar.stations.last - 5) {
          continue;
        }
        final heading = baseCar.at(s + 3) - baseCar.at(s - 3);
        final left = Offset(-heading.dy, heading.dx) / heading.distance;
        final apart = targetCar.points[i] - baseCar.at(s);
        gps.add(apart.dx * left.dx + apart.dy * left.dy);
        lateral.add(targetCar.lateral[i] - baseCar.lateralAt(s));
      }
      expect(_slope(lateral, gps), closeTo(-0.997, 0.02));

      final (b!, t!) = LapLine.pair(base, target, frame: frame);
      final centre = CentreComparison.between(b, t)!;
      expect(centre.rms, lessThanOrEqualTo(0.25));
      final edges = TrackEdgeAgreement.between(b, t)!;
      expect(edges.share, greaterThanOrEqualTo(0.85));

      // The hairpin: Base −2.01 m, Target +1.07 m (§6).
      expect(t.pathLateralAt(814)! - b.pathLateralAt(814)!, closeTo(3.08, 0.3));
      expect(b.turnAt(814), TurnSide.right);
      expect(lineAt(b, t, 814), endsWith('the inside of this right-hander'));
      debugPrint(
        'fixture: slope ${_slope(lateral, gps).toStringAsFixed(4)}, centre '
        'rms ${centre.rms.toStringAsFixed(3)} max '
        '${centre.max.toStringAsFixed(2)}, edges '
        '${(edges.share * 100).toStringAsFixed(1)}% of ${edges.matched}, '
        'ΔPL at 814 m '
        '${(t.pathLateralAt(814)! - b.pathLateralAt(814)!).toStringAsFixed(2)} '
        '(Base ${b.pathLateralAt(814)!.toStringAsFixed(2)}, Target '
        '${t.pathLateralAt(814)!.toStringAsFixed(2)})',
      );

      // One file: the Line panel, with no centre gate to pass.
      final view = await _read(
        container,
        comparisonChartProvider(
          ComparisonSet(LapRef(source, 1), LapRef(source, 3)),
        ).future,
      );
      expect(
        view.chart!.panels.where((panel) => panel.role == ChannelRole.line),
        hasLength(1),
      );
      expect(view.line!.centre, isNull);
    } finally {
      await _closeAll(container, [source]);
    }
  });

  testWidgets('the second Sebring recording, and a copy 6 m off over 200 m', (
    tester,
  ) async {
    final fixture = p.join(tmp.path, 'race.duckdb');
    final second = p.join(tmp.path, 'race_b.duckdb');
    final variant = p.join(tmp.path, 'race_b_variant.duckdb');
    File('$_projectRoot/$_fixture').copySync(fixture);
    File('$_projectRoot/$_second').copySync(second);
    File('$_projectRoot/$_second').copySync(variant);
    final moved = await _displace(variant, from: 1400, to: 1600, metres: 6);
    expect(moved, greaterThan(40));

    final sources = [
      TelemetrySource.path(fixture),
      TelemetrySource.path(second),
      TelemetrySource.path(variant),
    ];
    final container = ProviderContainer(
      overrides: [openSessionsProvider.overrideWith(() => _Open(sources))],
    );
    try {
      final secondLaps = await _read(
        container,
        lapsProvider(sources[1]).future,
      );
      final best = secondLaps.bestLap!.index;

      final real = ComparisonSet(
        LapRef(sources[0], 1),
        LapRef(sources[1], best),
      );
      final view = await _read(container, comparisonChartProvider(real).future);
      expect(view.refused, isFalse);
      expect(view.course!.verdict, CourseVerdict.sameCourse);
      expect(view.course!.centre!.max, lessThanOrEqualTo(1.1));
      expect(view.line!.centre!.rms, lessThanOrEqualTo(0.5));
      expect(view.line!.shown, isTrue);
      expect(
        view.chips.map((c) => c.label),
        contains(startsWith('centre path ')),
      );

      final constructed = ComparisonSet(
        LapRef(sources[0], 1),
        LapRef(sources[2], best),
      );
      final refused = await _read(
        container,
        comparisonChartProvider(constructed).future,
      );
      expect(refused.refused, isTrue);
      expect(refused.course!.verdict, CourseVerdict.differentCentreLine);
      expect(refused.course!.centre!.max, closeTo(6, 0.6));
      expect(refused.course!.centre!.maxStation, inInclusiveRange(1400, 1600));
      debugPrint(
        'second recording: centre max ${view.course!.centre!.max.toStringAsFixed(2)} '
        'm, rms ${view.line!.centre!.rms.toStringAsFixed(3)} m, edges '
        '${(view.line!.trackEdge!.share * 100).toStringAsFixed(1)}%; variant '
        '($moved samples moved): ${refused.course!.reason}',
      );
      // Nothing drawn: no delta, no segments, so no finding either.
      expect(refused.chart, isNull);
      expect(
        await _read(container, comparisonSegmentsProvider(constructed).future),
        isNull,
      );
    } finally {
      await _closeAll(container, sources);
    }
  });

  final library = Directory(_telemetryFolder).existsSync();

  testWidgets('[Lib] Spa against Spa Endurance: a variant, compared', (
    tester,
  ) async {
    final view = await _libraryPair(
      'Circuit de Spa-Francorchamps_R_2026-08-14T23_23_50Z.duckdb',
      'Circuit de Spa-Francorchamps_R_2026-07-24T02_18_56Z.duckdb',
    );
    expect(view.refused, isFalse);
    expect(view.course!.verdict, CourseVerdict.layoutVariant);
    final labels = view.chips.map((c) => c.label).toList();
    expect(
      labels,
      contains('layout variant: Circuit de Spa-Francorchamps Endurance'),
    );
    expect(labels, contains('track edges differ (game update?)'));
    expect(view.line!.shown, isTrue);
  }, skip: !library);

  testWidgets("[Lib] COTA's March against its September: edges differ, the "
      'line stays', (tester) async {
    final view = await _libraryPair(
      'Circuit of the Americas_R_2026-03-14T00_37_16Z.duckdb',
      'Circuit of the Americas_R_2026-09-11T22_28_14Z.duckdb',
    );
    expect(view.course!.verdict, CourseVerdict.sameCourse);
    expect(
      view.chips.map((c) => c.label),
      contains('track edges differ (game update?)'),
    );
    expect(
      view.chart!.panels.where((panel) => panel.role == ChannelRole.line),
      hasLength(1),
    );
  }, skip: !library);

  testWidgets('[Lib] an in-lap: its pit-lane stay is left out of its line', (
    tester,
  ) async {
    // COTA's March race: its in-laps also jump 43 m in Lap Dist at the pit
    // entry (§4 "Pit-lane laps").
    final source = TelemetrySource.path(
      p.join(
        _telemetryFolder,
        'Circuit of the Americas_R_2026-03-14T00_37_16Z.duckdb',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        openSessionsProvider.overrideWith(() => _Open([source])),
      ],
    );
    try {
      final course = await _read(container, courseFactsProvider(source).future);
      final laps = await _read(container, lapsProvider(source).future);
      final inLap = laps.firstWhere(
        (lap) =>
            lap.endSeconds != null &&
            lap.index != laps.first.index &&
            course.pitLaneDuring(lap.startSeconds, lap.endSeconds!),
      );
      final telemetry = await _read(
        container,
        lapTelemetryProvider(source, inLap.index).future,
      );
      final frame = LocalFrame.around(telemetry)!;
      final whole = LapLine.of(telemetry, frame: frame)!;
      final line = LapLine.of(
        telemetry,
        frame: frame,
        pitLane: course.pitLane,
      )!;
      bool inPits(double t) =>
          course.pitLane.any((pit) => pit.overlaps(t, t + 1e-9));
      expect(whole.times.where(inPits), isNotEmpty);
      expect(line.times.where(inPits), isEmpty);
      expect(line.length, lessThan(whole.length));
    } finally {
      await _closeAll(container, [source]);
    }
  }, skip: !library);

  testWidgets('[Lib] every pair of Sebring School recordings passes part 3', (
    tester,
  ) async {
    final files = [
      for (final f in Directory(_telemetryFolder).listSync())
        if (f is File &&
            p.basename(f.path).startsWith('Sebring International Raceway_') &&
            f.path.endsWith('.duckdb') &&
            !File('${f.path}.wal').existsSync())
          TelemetrySource.path(f.path),
    ];
    final container = ProviderContainer(
      overrides: [openSessionsProvider.overrideWith(() => _Open(files))],
    );
    try {
      final best = <(TelemetrySource, LapTelemetry, CourseFacts)>[];
      for (final source in files) {
        final laps = await _read(container, lapsProvider(source).future);
        final lap = laps.bestLap;
        if (lap == null) continue;
        best.add((
          source,
          await _read(
            container,
            lapTelemetryProvider(source, lap.index).future,
          ),
          await _read(container, courseFactsProvider(source).future),
        ));
      }
      expect(best.length, greaterThanOrEqualTo(10));
      var pairs = 0;
      var worst = 0.0;
      for (var i = 0; i < best.length; i++) {
        for (var j = i + 1; j < best.length; j++) {
          final line = LineCheck.measure(
            base: best[i].$2,
            target: best[j].$2,
            baseCourse: best[i].$3,
            targetCourse: best[j].$3,
            sameFile: false,
            alignment: StationAlignment.between(best[i].$3, best[j].$3),
          );
          final centre = line.centre!;
          expect(
            centre.sameCourse,
            isTrue,
            reason:
                '${best[i].$1.label} against ${best[j].$1.label}: '
                '${centre.max.toStringAsFixed(2)} m at '
                '${centre.maxStation.toStringAsFixed(0)} m',
          );
          expect(centre.linesComparable, isTrue);
          worst = math.max(worst, centre.max);
          pairs++;
        }
      }
      debugPrint(
        'Sebring School: $pairs pairs of ${best.length} files, '
        'worst bin ${worst.toStringAsFixed(2)} m',
      );
    } finally {
      await _closeAll(container, files);
    }
  }, skip: !library);
}

/// [base]'s best lap against [target]'s, both from the library, through the
/// app's own provider.
Future<ComparisonView> _libraryPair(String base, String target) async {
  final sources = [
    TelemetrySource.path(p.join(_telemetryFolder, base)),
    TelemetrySource.path(p.join(_telemetryFolder, target)),
  ];
  final container = ProviderContainer(
    overrides: [openSessionsProvider.overrideWith(() => _Open(sources))],
  );
  try {
    final baseLap = (await _read(
      container,
      lapsProvider(sources[0]).future,
    )).bestLap!;
    final targetLap = (await _read(
      container,
      lapsProvider(sources[1]).future,
    )).bestLap!;
    final view = await _read(
      container,
      comparisonChartProvider(
        ComparisonSet(
          LapRef(sources[0], baseLap.index),
          LapRef(sources[1], targetLap.index),
        ),
      ).future,
    );
    debugPrint(
      '${p.basenameWithoutExtension(base)} vs '
      '${p.basenameWithoutExtension(target)}: '
      '${view.course?.verdict.name}, centre '
      '${view.course?.centre?.max.toStringAsFixed(2)} m max / '
      '${view.line?.centre?.rms.toStringAsFixed(3)} m rms, edges '
      '${view.line?.trackEdge?.share.toStringAsFixed(3)} '
      '(${view.line?.trackEdge?.differingText}), chips '
      '${view.chips.map((c) => c.label).join(' | ')}',
    );
    return view;
  } finally {
    await _closeAll(container, sources);
  }
}
