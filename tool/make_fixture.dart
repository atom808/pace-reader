// Regenerates a trimmed test fixture from a real LMU telemetry file — the Dart
// port of `make_fixture.py`, for machines without Python (the Windows dev box
// has none). Same trim rule, same invariants; see that script and
// `test/fixtures/README.md` for why the rule is the master-grid identity.
//
// `dart_duckdb`'s native library is not on the Dart VM's search path, so pass
// the one a desktop build already bundles, and run against the package's own
// resolution so nothing re-resolves `pubspec.lock`:
//
//   dart --packages=.dart_tool/package_config.json tool/make_fixture.dart \
//     --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
//     "<LMU Telemetry folder>/Sebring International Raceway_R_2026-07-07T05_57_04Z.duckdb" \
//     test/fixtures/sebring_race_b_laps0_2.duckdb --through-lap 2
//
// The source is ATTACHed READ_ONLY: it is the user's game data, and nothing
// here ever writes next to it.
import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

const _master = 'GPS Time';
const _masterHz = 100;

Future<void> main(List<String> args) async {
  String? library;
  var throughLap = 1;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--duckdb-library':
        library = args[++i];
      case '--through-lap':
        throughLap = int.parse(args[++i]);
      default:
        positional.add(args[i]);
    }
  }
  if (positional.length != 2) {
    stderr.writeln(
      'usage: make_fixture.dart [--duckdb-library <path>] '
      '<source.duckdb> <dest.duckdb> [--through-lap N]',
    );
    exitCode = 64;
    return;
  }
  if (library != null) {
    open.overrideFor(OperatingSystem.windows, library);
    open.overrideFor(OperatingSystem.linux, library);
    open.overrideFor(OperatingSystem.macOS, library);
  }
  final [source, dest] = positional;
  if (File('$source.wal').existsSync()) {
    stderr.writeln(
      '$source has a .wal beside it: the game may still be '
      'writing it. Not reading it.',
    );
    exitCode = 1;
    return;
  }
  await _build(source, dest, throughLap);
  await _verify(dest);
}

String _q(String identifier) => '"${identifier.replaceAll('"', '""')}"';
String _lit(String text) => "'${text.replaceAll("'", "''")}'";

Future<void> _build(String source, String dest, int throughLap) async {
  final file = File(dest);
  if (file.existsSync()) file.deleteSync();

  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);
  try {
    Future<List<List<Object?>>> rows(String sql) async =>
        (await con.query(sql)).fetchAll();
    Future<Object?> scalar(String sql) async => (await rows(sql)).first.first;

    await con.execute(
      'SET threads = 1',
    ); // deterministic, insertion-order scans
    await con.execute('ATTACH ${_lit(source)} AS src (READ_ONLY)');
    // The game writes 16 KB blocks, and DuckDB's default for a new file is
    // 256 KB. With ~100 tables of a few hundred rows each, that default is
    // ~90 mostly empty blocks: a 3-lap trim came out at 23 MB. Writing the
    // source's own block size is smaller and more faithful.
    final blockSize = await scalar(
      'SELECT block_size FROM '
      "pragma_database_size() WHERE database_name = 'src'",
    );
    await con.execute('ATTACH ${_lit(dest)} AS out (BLOCK_SIZE $blockSize)');
    await con.execute('USE out');

    final channels = [
      for (final r in await rows(
        'SELECT channelName, frequency '
        'FROM src.channelsList ORDER BY channelName',
      ))
        (r[0]! as String, (r[1]! as num).toInt()),
    ];
    final events = [
      for (final r in await rows(
        'SELECT eventName FROM src.eventsList ORDER BY eventName',
      ))
        r[0]! as String,
    ];

    // Cut at the start of the lap *after* the last one kept, so the kept
    // span covers whole laps. `Lap` values are 0-based (SPEC.md §5.2).
    final cutoff = await scalar(
      'SELECT MIN(ts) FROM src."Lap" WHERE value = ${throughLap + 1}',
    );
    if (cutoff == null) {
      throw StateError('source has no lap ${throughLap + 1} to cut at');
    }
    final srcMasterRows =
        (await scalar('SELECT COUNT(*) FROM src.${_q(_master)}'))! as int;
    final keptMasterRows =
        (await scalar(
              'SELECT COUNT(*) FROM '
              'src.${_q(_master)} WHERE value <= $cutoff',
            ))!
            as int;

    stdout
      ..writeln('source     : $source')
      ..writeln('cutoff     : lap ${throughLap + 1} starts at ts=$cutoff')
      ..writeln('master rows: $srcMasterRows -> $keptMasterRows');

    for (final table in const ['metadata', 'channelsList', 'eventsList']) {
      await con.execute(
        'CREATE TABLE ${_q(table)} AS SELECT * FROM src.${_q(table)}',
      );
    }

    final anomalous = <String>[];
    for (final (name, hz) in channels) {
      final srcRows =
          (await scalar('SELECT COUNT(*) FROM src.${_q(name)}'))! as int;
      final onGrid = srcRows == (srcMasterRows * hz / _masterHz).ceil();
      final int keep;
      if (onGrid) {
        keep = (keptMasterRows * hz / _masterHz).ceil();
      } else {
        // Off-grid (the two 7 Hz engine temperatures): keep the real,
        // mis-declared rate proportionally so the fixture reproduces it.
        keep = (srcRows * keptMasterRows / srcMasterRows).round();
        anomalous.add(name);
      }
      await con.execute(
        'CREATE TABLE ${_q(name)} AS '
        'SELECT * EXCLUDE (_rn) FROM ('
        '  SELECT *, row_number() OVER () AS _rn FROM src.${_q(name)}'
        ') WHERE _rn <= $keep',
      );
    }

    for (final name in events) {
      await con.execute(
        'CREATE TABLE ${_q(name)} AS '
        'SELECT * FROM src.${_q(name)} WHERE ts <= $cutoff',
      );
    }

    await con.execute('DETACH src');
    await con.execute('CHECKPOINT out');
    await con.execute('USE memory');
    await con.execute('DETACH out');
    stdout.writeln(
      'off-grid channels kept as-is: '
      '${anomalous.isEmpty ? 'none' : anomalous}',
    );
  } finally {
    await con.dispose();
    await db.dispose();
  }
  stdout.writeln(
    'wrote      : $dest '
    '(${(File(dest).lengthSync() / 1e6).toStringAsFixed(1)} MB)',
  );
}

/// Re-opens the fixture and asserts the invariants the integration tests
/// rely on, exactly as `make_fixture.py` does.
Future<void> _verify(String dest) async {
  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);
  try {
    await con.execute('ATTACH ${_lit(dest)} AS f (READ_ONLY)');
    await con.execute('USE f');
    Future<List<List<Object?>>> rows(String sql) async =>
        (await con.query(sql)).fetchAll();
    Future<Object?> scalar(String sql) async => (await rows(sql)).first.first;

    final masterRows =
        (await scalar('SELECT COUNT(*) FROM ${_q(_master)}'))! as int;
    final origin = await scalar('SELECT value FROM ${_q(_master)} LIMIT 1');

    final offGrid = <String>[];
    for (final r in await rows(
      'SELECT channelName, frequency FROM channelsList',
    )) {
      final name = r[0]! as String;
      final hz = (r[1]! as num).toInt();
      final count = (await scalar('SELECT COUNT(*) FROM ${_q(name)}'))! as int;
      if (count != (masterRows * hz / _masterHz).ceil()) offGrid.add(name);
    }
    final emptyEvents = <String>[];
    final badOrigin = <String>[];
    for (final r in await rows('SELECT eventName FROM eventsList')) {
      final name = r[0]! as String;
      if ((await scalar('SELECT COUNT(*) FROM ${_q(name)}'))! as int == 0) {
        emptyEvents.add(name);
      }
      if (await scalar('SELECT MIN(ts) FROM ${_q(name)}') != origin) {
        badOrigin.add(name);
      }
    }
    final steps =
        (await scalar('''
        WITH g AS (SELECT value AS v, row_number() OVER () AS i FROM ${_q(_master)}),
             d AS (SELECT v - lag(v) OVER (ORDER BY i) AS dt FROM g)
        SELECT COUNT(*) FROM d WHERE dt IS NOT NULL AND abs(dt - 0.01) > 1e-9
    '''))!
            as int;

    stdout
      ..writeln('\nverification')
      ..writeln('  master rows              : $masterRows (origin $origin)')
      ..writeln('  channels off master grid : ${offGrid.length} $offGrid')
      ..writeln(
        '  empty event tables       : ${emptyEvents.length} $emptyEvents',
      )
      ..writeln(
        '  events not starting at origin: '
        '${badOrigin.length} $badOrigin',
      )
      ..writeln('  master-clock steps != 10ms   : $steps');
    final ok =
        offGrid.length <= 2 &&
        emptyEvents.isEmpty &&
        badOrigin.isEmpty &&
        steps == 0;
    stdout.writeln(
      '  RESULT: ${ok ? 'ok' : 'PROBLEM — do not check this fixture in'}',
    );
    if (!ok) exitCode = 1;
  } finally {
    await con.dispose();
    await db.dispose();
  }
}
