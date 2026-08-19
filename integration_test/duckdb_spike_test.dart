// Phase 0 spike (SPEC.md §14), now doubling as the regression net for the
// data-model claims in §5: proves dart_duckdb can open a real LMU telemetry
// file, and validates the time-axis derivation from §5.2/§9.2 (channels
// carry no timestamp — elapsed time has to be reconstructed) against real
// data before any chart depends on it.
//
// This is an integration_test, not a plain `flutter test`: dart_duckdb's
// native library is linked into the real compiled app via CocoaPods/CMake
// (see its macos/windows/linux podspec/CMakeLists), which a bare `flutter
// test` process doesn't have — only a real running app does. Run with:
//   flutter test integration_test/duckdb_spike_test.dart -d macos \
//     --dart-define=PROJECT_ROOT="$(pwd)"
//
// Fixture: test/fixtures/sebring_race_lap1.duckdb — lap 0 plus the lap-1
// boundary, trimmed from the real Sebring Race sample by
// tool/make_fixture.py (see test/fixtures/README.md). `samples/` is
// git-ignored, so this fixture is the only telemetry CI ever sees — which
// is why the checks below assert on the *shape* of the data (master grid,
// clock continuity, declared frequencies) and not just on a few values.

import 'dart:io';
import 'dart:math' as math;

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The launched app's working directory isn't the project root, so the
/// project root is passed in explicitly rather than assumed. Run with:
///   flutter test integration_test/duckdb_spike_test.dart -d macos \
///     --dart-define=PROJECT_ROOT="$(pwd)"
const _projectRoot = String.fromEnvironment('PROJECT_ROOT', defaultValue: '.');

/// The 100 Hz elapsed-seconds channel every other channel's row grid is a
/// decimation of, and the only one carrying real timestamps (SPEC.md §5.2).
const _masterChannel = 'GPS Time';
const _masterHz = 100;

/// `Engine Oil Temp`/`Engine Water Temp` declare 7 Hz but sample at
/// ~7.0171 Hz — the only two channels in any sample whose declared
/// frequency doesn't reproduce their row count (SPEC.md §5.2). Named here
/// rather than tolerated generically, so a *third* one showing up in a
/// future LMU version fails this suite instead of slipping through.
const _offGridChannels = {'Engine Oil Temp', 'Engine Water Temp'};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late Connection conn;

  /// First `GPS Time` value: the file's own definition of t=0 for every
  /// channel and event. Per-file, never a constant — §5.2 measured
  /// 381.09 s / 34.57 s / 23.60 s across the three samples.
  late double origin;
  late int masterRows;

  Future<List<List<Object?>>> rows(String sql) async =>
      (await conn.query(sql)).fetchAll();

  Future<Object?> scalar(String sql) async => (await rows(sql)).single.single;

  setUpAll(() async {
    final fixturePath = '$_projectRoot/test/fixtures/sebring_race_lap1.duckdb';
    expect(
      File(fixturePath).existsSync(),
      isTrue,
      reason: 'Fixture missing at $fixturePath — see test/fixtures/README.md '
          '(pass --dart-define=PROJECT_ROOT="\$(pwd)" if running from elsewhere)',
    );
    db = await duckdb.open(fixturePath);
    conn = await duckdb.connect(db);
    origin = (await scalar('SELECT value FROM "$_masterChannel" LIMIT 1')) as double;
    masterRows = (await scalar('SELECT COUNT(*) FROM "$_masterChannel"')) as int;
  });

  tearDownAll(() async {
    await conn.dispose();
    await db.dispose();
  });

  testWidgets('metadata matches the real recording', (tester) async {
    final result = await conn.query('SELECT key, value FROM metadata');
    final meta = {for (final row in result.fetchAll()) row[0] as String: row[1]};

    expect(meta['TrackName'], 'Sebring International Raceway');
    expect(meta['SessionType'], 'Race');
    expect(meta['CarClass'], 'GT3');

    // TrackLayout is a separate dimension from TrackName and can change lap
    // length dramatically — this recording is the 3.08 km School Circuit, not
    // the 6.0 km full course. The Session Library index (§8.1/§9.6) has to key
    // on both, or cross-session bests will compare different circuits.
    expect(meta['TrackLayout'], 'Sebring School Circuit');

    // The file states its own format version (§5.1) — the cheapest place for
    // §10's resilience requirement to fail clearly on an unknown format.
    expect(meta['Version'], '1');
    expect(meta.keys, hasLength(12));
  });

  testWidgets(
      'channelsList/eventsList catalogs are queryable (§9.2 catalog-driven discovery)',
      (tester) async {
    expect(await scalar('SELECT COUNT(*) FROM channelsList'), 56);
    expect(await scalar('SELECT COUNT(*) FROM eventsList'), 42);
  });

  testWidgets('a 100Hz channel table has no timestamp column', (tester) async {
    final result = await conn.query('SELECT * FROM "Engine RPM" LIMIT 1');
    expect(result.columnNames, ['value']);
  });

  testWidgets('every channel rides the shared master grid (§5.1)', (tester) async {
    // rows == ceil(masterRows * frequency / 100) for every channel except the
    // two known off-grid ones. This is the invariant that makes channel-vs-
    // channel alignment exact, and the one a mis-trimmed fixture breaks — the
    // original hand-trimmed fixture violated it on 36 of 56 channels while
    // still passing every other check here (§12, §14).
    final catalog = await rows('SELECT channelName, frequency FROM channelsList');
    final offGrid = <String, String>{};

    for (final row in catalog) {
      final name = row[0] as String;
      final hz = row[1] as int;
      final count = (await scalar('SELECT COUNT(*) FROM "$name"')) as int;
      final expected = (masterRows * hz / _masterHz).ceil();
      if (count != expected) offGrid[name] = '${hz}Hz: $count rows, expected $expected';
    }

    expect(
      offGrid.keys.toSet(),
      _offGridChannels,
      reason: 'channels off the master grid changed — if a new one appears, its '
          'declared frequency is unusable for timing (§5.2) and the derivation '
          'must go through $_masterChannel: $offGrid',
    );
  });

  testWidgets('the master clock is contiguous — no recording gaps (§5.2)',
      (tester) async {
    // GPS Time advances by exactly 0.01 s per row, except across a recording
    // discontinuity. The Practice and Qualify samples each contain one ~0.38 s
    // gap; this Race-derived fixture has none. A row-index clock cannot see a
    // gap, so import should run this scan and report what it finds rather than
    // silently mis-timing everything after one.
    final gaps = await scalar('''
      WITH g AS (
        SELECT value AS v, row_number() OVER () AS i FROM "$_masterChannel"
      ),
      d AS (SELECT v - lag(v) OVER (ORDER BY i) AS dt FROM g)
      SELECT COUNT(*) FROM d WHERE dt IS NOT NULL AND abs(dt - 0.01) > 1e-9
    ''');
    expect(gaps, 0);
  });

  testWidgets('derived time matches GPS Time across the whole fixture (§5.2)',
      (tester) async {
    // GPS Time's *value* is real elapsed seconds, so it is ground truth for
    // `origin + row_index / frequency`. Checked over every row rather than a
    // handful of sampled indices — a sampled check passes straight through a
    // discontinuity that falls between the samples.
    final worst = await scalar('''
      WITH g AS (
        SELECT value AS v, (row_number() OVER ()) - 1 AS i FROM "$_masterChannel"
      )
      SELECT MAX(abs(v - ($origin + i / $_masterHz.0))) FROM g
    ''');
    expect(worst as double, lessThan(1e-6));
  });

  testWidgets('a declared frequency that reproduces row count also reproduces the span',
      (tester) async {
    // A channel's last sample cannot be timed after the recording ended. That
    // makes the off-grid channels provably mis-declared rather than merely
    // suspicious, and it's the cheap assertion that catches the same class of
    // bug on any future channel.
    final span = ((await scalar('SELECT MAX(value) FROM "$_masterChannel"')) as double) - origin;
    final catalog = await rows('SELECT channelName, frequency FROM channelsList');

    for (final row in catalog) {
      final name = row[0] as String;
      final hz = row[1] as int;
      final count = (await scalar('SELECT COUNT(*) FROM "$name"')) as int;
      final derivedSpan = (count - 1) / hz;

      if (_offGridChannels.contains(name)) {
        expect(
          derivedSpan,
          greaterThan(span),
          reason: '$name is meant to overshoot — that is the bug being pinned',
        );
      } else {
        // Never past the end, and never more than one sample period short of it.
        expect(derivedSpan, lessThanOrEqualTo(span + 1e-9), reason: name);
        expect(derivedSpan, greaterThan(span - 1 / hz - 1e-9), reason: name);
      }
    }
  });

  testWidgets('ASOF LEFT JOIN resolves an event value as of a channel sample (§5.2, §9.2)',
      (tester) async {
    // "What gear was the car in as of each Engine RPM sample?" — the pattern
    // every trace/track-map feature needs for event-to-channel alignment,
    // using DuckDB's native ASOF JOIN rather than a hand-rolled backward scan.
    // LEFT, not inner: see the next test for why that matters.
    final result = await rows('''
      WITH engine_rpm_grid AS (
        SELECT
          value AS rpm,
          $origin + ((row_number() OVER ()) - 1) / $_masterHz.0 AS t
        FROM "Engine RPM"
      )
      SELECT g.t, g.rpm, gear."value" AS gear
      FROM engine_rpm_grid g
      ASOF LEFT JOIN "Gear" gear ON gear.ts <= g.t
      ORDER BY g.t
    ''');

    expect(result, hasLength(masterRows));
    // Every event table's first ts equals origin (§5.2), so with origin
    // included there is no unresolvable sample — no nulls at all.
    expect(result.where((row) => row[2] == null), isEmpty);
    for (final row in result) {
      expect(row[2] as int, inInclusiveRange(0, 8));
    }
  });

  testWidgets('a plain ASOF JOIN silently drops pre-origin samples (§5.2, §14)',
      (tester) async {
    // Pinning the trap the original spike fell into: its grid omitted origin,
    // so it joined a 0-based clock against timestamps starting at origin. The
    // inner ASOF JOIN discarded the unmatched prefix and the surviving rows
    // still held plausible gear numbers, so the test passed while measuring a
    // clock 23.6 s out of alignment. The same query as LEFT exposes it.
    final dropped = (await scalar('''
      WITH bad_grid AS (
        SELECT value AS rpm, ((row_number() OVER ()) - 1) / $_masterHz.0 AS t
        FROM "Engine RPM"
      )
      SELECT COUNT(*) FROM bad_grid g ASOF JOIN "Gear" gear ON gear.ts <= g.t
    ''')) as int;

    // Exactly the samples whose (origin-less) time predates the first event.
    expect(dropped, masterRows - (origin * _masterHz).round());
    expect(dropped, lessThan(masterRows));
  });

  testWidgets('lap boundaries land on the start/finish line (§5.2)', (tester) async {
    // External ground truth for channel-vs-event alignment: a `Lap` event *is*
    // a start/finish crossing, so a correctly aligned join must put `Lap Dist`
    // at (or a sample short of) zero there. This is the check that catches an
    // alignment error in metres rather than in floating-point noise — the
    // origin-less grid above would miss by hundreds of metres.
    //
    // Lap 0 is excluded: it marks the recording start with the car in the
    // garage/pits, not a crossing (§5.2).
    final lapLength = (await scalar('SELECT MAX(value) FROM "Lap Dist"')) as double;
    final hz = (await scalar(
      "SELECT frequency FROM channelsList WHERE channelName = 'Lap Dist'",
    )) as int;

    final boundaries = await rows('''
      WITH lap_dist AS (
        SELECT value AS dist, $origin + ((row_number() OVER ()) - 1) / $hz.0 AS t
        FROM "Lap Dist"
      )
      SELECT l."value" AS lap, d.dist
      FROM "Lap" l
      ASOF LEFT JOIN lap_dist d ON d.t <= l.ts
      WHERE l."value" > 0
      ORDER BY l.ts
    ''');

    expect(boundaries, isNotEmpty);
    for (final row in boundaries) {
      final dist = row[1] as double;
      // Either just before the line (dist ≈ lap length) or just after (≈ 0).
      final offLine = math.min(dist.abs(), (lapLength - dist).abs());
      expect(
        offLine,
        lessThan(10.0),
        reason: 'lap ${row[0]} resolved ${offLine.toStringAsFixed(1)} m off the '
            'start/finish line — channel-vs-event alignment is wrong',
      );
    }
  });
}
