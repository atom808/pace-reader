// Re-records a fixture in the newer LMU build's layout (SPEC.md §5.1,
// 2026-10-13): `TC` becomes a 100 Hz channel and `SurfaceTypes` a 5 Hz one,
// and both move from `eventsList` to `channelsList`. Every other table is
// copied unchanged.
//
// A channel row holds the event's value as of its master row: the latest
// event row at or before that row's time, which is how the app reads an
// event at a sample (`ASOF LEFT`, §9.2). The result is the source's data in
// the other shape, so the two can run side by side:
// `integration_test/technique_test.dart` checks that Driving Technique's TC
// measures agree on both.
//
// Run it the way `make_fixture.dart` runs, on the DuckDB library a desktop
// build bundles and the package's existing resolution:
//
//   dart --packages=.dart_tool/package_config.json \
//     tool/make_tc_channel_fixture.dart \
//     --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
//     test/fixtures/sebring_race_laps0_3.duckdb \
//     test/fixtures/sebring_race_tc_channel_laps0_3.duckdb
//
// The source is ATTACHed READ_ONLY.
import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

const _master = 'GPS Time';
const _masterHz = 100;

/// The events the newer build records as channels, at its rates.
const _asChannels = {'SurfaceTypes': 5, 'TC': 100};

/// The game's block size. A file written with DuckDB's 256 KB default comes
/// out several times larger with ~100 small tables (`make_fixture.dart`), and
/// the Python-made fixture this is first run on was written with it.
const _blockSize = 16384;

Future<void> main(List<String> args) async {
  String? library;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--duckdb-library':
        library = args[++i];
      default:
        positional.add(args[i]);
    }
  }
  if (positional.length != 2) {
    stderr.writeln(
      'usage: make_tc_channel_fixture.dart [--duckdb-library <path>] '
      '<source.duckdb> <dest.duckdb>',
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
  await _build(source, dest);
  await _verify(source, dest);
}

String _q(String identifier) => '"${identifier.replaceAll('"', '""')}"';
String _lit(String text) => "'${text.replaceAll("'", "''")}'";

Future<void> _build(String source, String dest) async {
  final file = File(dest);
  if (file.existsSync()) file.deleteSync();

  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);
  try {
    Future<List<List<Object?>>> rows(String sql) async =>
        (await con.query(sql)).fetchAll();

    await con.execute(
      'SET threads = 1',
    ); // deterministic, insertion-order scans
    await con.execute('ATTACH ${_lit(source)} AS src (READ_ONLY)');
    await con.execute('ATTACH ${_lit(dest)} AS out (BLOCK_SIZE $_blockSize)');
    await con.execute('USE out');

    final channels = [
      for (final r in await rows(
        'SELECT channelName FROM src.channelsList ORDER BY channelName',
      ))
        r[0]! as String,
    ];
    final events = [
      for (final r in await rows(
        'SELECT eventName FROM src.eventsList ORDER BY eventName',
      ))
        r[0]! as String,
    ];
    for (final name in _asChannels.keys) {
      if (!events.contains(name)) {
        throw StateError('source has no $name event to re-record');
      }
    }
    final moved = [for (final name in _asChannels.keys) _lit(name)].join(', ');
    final rates = [
      for (final MapEntry(key: name, value: hz) in _asChannels.entries)
        '(${_lit(name)}, $hz)',
    ].join(', ');

    stdout
      ..writeln('source     : $source')
      ..writeln('as channels: $_asChannels');

    await con.execute('CREATE TABLE metadata AS SELECT * FROM src.metadata');
    // Both lists are in name order in every file, the newer build's too.
    await con.execute(
      'CREATE TABLE channelsList AS SELECT * FROM ('
      'SELECT * FROM src.channelsList UNION ALL '
      'SELECT e.eventName, r.hz, e.unit FROM src.eventsList e '
      'JOIN (VALUES $rates) r(name, hz) ON r.name = e.eventName'
      ') ORDER BY channelName',
    );
    await con.execute(
      'CREATE TABLE eventsList AS SELECT * FROM src.eventsList '
      'WHERE eventName NOT IN ($moved)',
    );
    for (final name in [...channels, ...events]) {
      if (_asChannels.containsKey(name)) continue;
      await con.execute(
        'CREATE TABLE ${_q(name)} AS SELECT * FROM src.${_q(name)}',
      );
    }
    for (final MapEntry(key: name, value: hz) in _asChannels.entries) {
      final stride = _masterHz ~/ hz;
      await con.execute(
        'CREATE TABLE ${_q(name)} AS SELECT e.* EXCLUDE (ts) FROM ('
        '  SELECT * FROM (SELECT value AS t, row_number() OVER () - 1 AS mi '
        '  FROM src.${_q(_master)}) WHERE mi % $stride = 0'
        ') m ASOF LEFT JOIN src.${_q(name)} e ON m.t >= e.ts ORDER BY m.mi',
      );
    }

    await con.execute('DETACH src');
    await con.execute('CHECKPOINT out');
    await con.execute('USE memory');
    await con.execute('DETACH out');
  } finally {
    await con.dispose();
    await db.dispose();
  }
  stdout.writeln(
    'wrote      : $dest '
    '(${(File(dest).lengthSync() / 1e6).toStringAsFixed(1)} MB)',
  );
}

/// Re-opens the result and checks it has the newer build's shape: every
/// listed channel on the master grid but the two 7 Hz temperatures (§5.2),
/// the re-recorded tables without `ts` and without a null, and every other
/// table identical to the source's.
Future<void> _verify(String source, String dest) async {
  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);
  try {
    await con.execute('ATTACH ${_lit(source)} AS src (READ_ONLY)');
    await con.execute('ATTACH ${_lit(dest)} AS f (READ_ONLY)');
    await con.execute('USE f');
    Future<List<List<Object?>>> rows(String sql) async =>
        (await con.query(sql)).fetchAll();
    Future<Object?> scalar(String sql) async => (await rows(sql)).first.first;

    final masterRows =
        (await scalar('SELECT COUNT(*) FROM ${_q(_master)}'))! as int;
    final offGrid = <String>[];
    for (final r in await rows(
      'SELECT channelName, frequency FROM channelsList',
    )) {
      final name = r[0]! as String;
      final hz = (r[1]! as num).toInt();
      final count = (await scalar('SELECT COUNT(*) FROM ${_q(name)}'))! as int;
      if (count != (masterRows * hz / _masterHz).ceil()) offGrid.add(name);
    }

    final problems = <String>[];
    if (offGrid.length > 2) problems.add('off the master grid: $offGrid');
    for (final name in _asChannels.keys) {
      if (offGrid.contains(name)) problems.add('$name is off the master grid');
      final columns = [
        for (final r in await rows(
          'SELECT column_name FROM information_schema.columns '
          "WHERE table_catalog = 'f' AND table_name = ${_lit(name)}",
        ))
          r[0]! as String,
      ];
      if (columns.contains('ts')) problems.add('$name still has ts');
      final nulls = await scalar(
        'SELECT COUNT(*) FROM ${_q(name)} '
        'WHERE ${[for (final c in columns) '${_q(c)} IS NULL'].join(' OR ')}',
      );
      if (nulls != 0) problems.add('$name has $nulls rows with a null');
      // Pulses shorter than a tick fall between two rows; this says how many.
      final edges = await scalar(
        'SELECT COUNT(*) FROM (SELECT ${columns.map(_q).join(', ')}, '
        'lag(row(${columns.map(_q).join(', ')})) OVER (ORDER BY r) AS p '
        'FROM (SELECT *, row_number() OVER () AS r FROM ${_q(name)})) '
        'WHERE p IS DISTINCT FROM row(${columns.map(_q).join(', ')})',
      );
      final sourceRows = await scalar('SELECT COUNT(*) FROM src.${_q(name)}');
      stdout.writeln(
        '  $name: $sourceRows event rows -> $edges changes on the '
        '${_asChannels[name]} Hz grid',
      );
    }
    final listed =
        (await scalar(
              'SELECT COUNT(*) FROM eventsList '
              'WHERE eventName IN (${_asChannels.keys.map(_lit).join(', ')})',
            ))!
            as int;
    if (listed != 0) problems.add('still listed as events');

    for (final r in await rows(
      "SELECT table_name FROM information_schema.tables WHERE table_catalog = 'f'",
    )) {
      final name = r[0]! as String;
      if (_asChannels.containsKey(name) ||
          name == 'channelsList' ||
          name == 'eventsList') {
        continue;
      }
      final differing = await scalar(
        'SELECT COUNT(*) FROM ((SELECT * FROM ${_q(name)} EXCEPT ALL '
        'SELECT * FROM src.${_q(name)}) UNION ALL (SELECT * FROM '
        'src.${_q(name)} EXCEPT ALL SELECT * FROM ${_q(name)}))',
      );
      if (differing != 0) problems.add('$name differs from the source');
    }

    stdout
      ..writeln('\nverification')
      ..writeln('  master rows              : $masterRows')
      ..writeln('  channels off master grid : ${offGrid.length} $offGrid')
      ..writeln('  RESULT: ${problems.isEmpty ? 'ok' : 'PROBLEM — $problems'}');
    if (problems.isNotEmpty) exitCode = 1;
  } finally {
    await con.dispose();
    await db.dispose();
  }
}
