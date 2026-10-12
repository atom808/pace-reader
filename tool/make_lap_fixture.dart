// Generates a Dart fixture holding one real lap, for widget and golden tests —
// the Dart port of `make_lap_fixture.py`, for machines without Python (the
// Windows dev box has none). Same sampling and the same output for every
// channel the Python script emits, plus three it does not:
// `Throttle Pos Unfiltered` (the pedal, comparison proposal D3), and
// `Path Lateral` and `Track Edge` (the Line panel and the course's centre
// line, proposal §4 and §6).
//
// `dart_duckdb`'s native library is not on the Dart VM's search path, so pass
// the one a desktop build already bundles, and run against the package's own
// resolution so nothing re-resolves `pubspec.lock`:
//
//   dart --packages=.dart_tool/package_config.json tool/make_lap_fixture.dart \
//     --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
//     test/fixtures/sebring_race_laps0_3.duckdb test/fixtures/sebring_lap1.dart \
//     --lap 1
//   dart --packages=.dart_tool/package_config.json tool/make_lap_fixture.dart \
//     --duckdb-library build/windows/x64/runner/Debug/duckdb.dll \
//     test/fixtures/sebring_race_laps0_3.duckdb test/fixtures/sebring_lap3.dart \
//     --lap 3 --prefix sebringLap3
//
// The source is ATTACHed READ_ONLY.
import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';

/// See `make_lap_fixture.py` for why 5 Hz, and why any divisor of the master
/// rate keeps sample i of every array on the same instant.
const _emitHz = 5;
const _masterHz = 100;

/// (channel, Dart name, decimals). The first eight are the Python script's,
/// in its order; the last three are new.
const _channels = [
  ('Ground Speed', 'speed', 2),
  ('Throttle Pos', 'throttle', 2),
  ('Brake Pos', 'brake', 2),
  ('Steering Pos', 'steering', 2),
  ('Engine RPM', 'rpm', 1),
  ('Lap Dist', 'lapDistance', 2),
  ('GPS Latitude', 'latitude', 7),
  ('GPS Longitude', 'longitude', 7),
  // The pedal, beside the throttle the engine received (D3).
  ('Throttle Pos Unfiltered', 'throttlePedal', 2),
  // Metres: millimetres keep the 0.5 m floors exact, and Track Edge is
  // written to the millimetre, so equal edges stay equal.
  ('Path Lateral', 'pathLateral', 3),
  ('Track Edge', 'trackEdge', 3),
];

/// Channels the lap carries as fields of their own rather than in its
/// `channels` map.
const _fields = {
  'lapDistance',
  'latitude',
  'longitude',
  'pathLateral',
  'trackEdge',
};

Future<void> main(List<String> args) async {
  String? library;
  var lap = 1;
  var prefix = 'sebringLap';
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--duckdb-library':
        library = args[++i];
      case '--lap':
        lap = int.parse(args[++i]);
      case '--prefix':
        prefix = args[++i];
      default:
        positional.add(args[i]);
    }
  }
  if (positional.length != 2) {
    stderr.writeln(
      'usage: make_lap_fixture.dart [--duckdb-library <path>] '
      '<source.duckdb> <output.dart> [--lap N] [--prefix name]',
    );
    exitCode = 64;
    return;
  }
  if (library != null) {
    open.overrideFor(OperatingSystem.windows, library);
    open.overrideFor(OperatingSystem.linux, library);
    open.overrideFor(OperatingSystem.macOS, library);
  }
  final [source, output] = positional;

  final db = await duckdb.open(':memory:');
  final con = await duckdb.connect(db);
  try {
    Future<List<List<Object?>>> rows(String sql) async =>
        (await con.query(sql)).fetchAll();
    await con.execute('SET threads = 1');
    await con.execute(
      "ATTACH '${source.replaceAll("'", "''")}' AS src (READ_ONLY)",
    );
    await con.execute('USE src');

    final boundaries = {
      for (final r in await rows('SELECT ts, value FROM "Lap" ORDER BY ts'))
        (r[1]! as num).toInt(): (r[0]! as num).toDouble(),
    };
    final start = boundaries[lap];
    final end = boundaries[lap + 1];
    if (start == null || end == null) {
      throw StateError('lap $lap has no closing boundary in $source');
    }

    Future<double> at(String table) async =>
        ((await rows('SELECT value FROM "$table" WHERE ts = $end')).first.first!
                as num)
            .toDouble();
    final lapTime = await at('Lap Time');
    final sector1 = await at('Last Sector1');
    final sector2 = await at('Last Sector2');

    final gear = await rows('''
      SELECT * FROM (
        SELECT ts, value FROM "Gear" WHERE ts >= $start AND ts < $end
        UNION ALL
        SELECT * FROM (SELECT ts, value FROM "Gear" WHERE ts < $start ORDER BY ts DESC LIMIT 1)
      ) ORDER BY ts
    ''');
    final sectors = await rows(
      'SELECT ts, value FROM "Current Sector" '
      'WHERE ts > $start AND ts < $end ORDER BY ts',
    );

    final present = {
      for (final r in await rows('SELECT channelName FROM channelsList'))
        r[0]! as String,
    };
    final units = <String, String>{};
    final series = <String, List<double>>{};
    List<double>? times;
    for (final (name, dart, _) in _channels) {
      if (!present.contains(name)) {
        stderr.writeln('$name: not in $source, skipped');
        continue;
      }
      final meta = (await rows(
        "SELECT frequency, unit FROM channelsList WHERE channelName = '$name'",
      )).first;
      final hz = (meta[0]! as num).toInt();
      units[dart] = meta[1]! as String;
      if (_masterHz % hz != 0 || hz % _emitHz != 0) {
        throw StateError('$name: $hz Hz is not a multiple of $_emitHz Hz');
      }
      final stride = _masterHz ~/ hz;
      final keep = hz ~/ _emitHz;
      final read = await rows('''
        WITH _m AS (SELECT value AS t, rowid AS mi FROM "GPS Time"),
             _c AS (SELECT value AS v, rowid AS i FROM "$name")
        SELECT m.t, c.v
        FROM _c c JOIN _m m ON m.mi = c.i * $stride
        WHERE m.t >= $start AND m.t < $end AND c.i % $keep = 0
        ORDER BY c.i
      ''');
      final t = [for (final r in read) (r[0]! as num).toDouble()];
      if (times == null) {
        times = t;
      } else if (t.length != times.length) {
        throw StateError(
          '$name resampled to ${t.length} rows, expected ${times.length}',
        );
      }
      series[dart] = [for (final r in read) (r[1]! as num).toDouble()];
    }

    String fmt(List<double> values, int decimals) =>
        values.map((v) => v.toStringAsFixed(decimals)).join(', ');
    String repr(Object? v) => (v! as num).toDouble().toString();

    final p = prefix;
    final parts = <String>[
      '// GENERATED by tool/make_lap_fixture.dart — do not edit by hand.',
      '//',
      '// Lap $lap of test/fixtures/sebring_race_laps0_3.duckdb, resampled to',
      '// $_emitHz Hz. Real telemetry, so a widget test asserts against numbers the',
      '// game actually recorded and a golden renders the actual circuit — see',
      '// tool/make_lap_fixture.py for why this exists as Dart source rather than as',
      '// the .duckdb file sitting next to it.',
      'library;',
      '',
      "import 'dart:typed_data';",
      '',
      "import 'package:pace_reader/data/models/models.dart';",
      "import 'package:pace_reader/data/repositories/lap_telemetry.dart';",
      '',
      'const ${p}Index = $lap;',
      'const ${p}StartSeconds = $start;',
      'const ${p}EndSeconds = $end;',
      'const ${p}TimeSeconds = $lapTime;',
      'const ${p}Sector1 = $sector1;',
      'const ${p}Sector2Cumulative = $sector2;',
      'const ${p}SampleHz = $_emitHz;',
      '',
      'final _times = Float64List.fromList(<double>[',
      '  ${fmt(times!, 4)},',
      ']);',
      '',
    ];
    for (final (_, dart, decimals) in _channels) {
      final values = series[dart];
      if (values == null) continue;
      parts.addAll([
        'final _$dart = Float64List.fromList(<double>[',
        '  ${fmt(values, decimals)},',
        ']);',
        '',
      ]);
    }
    parts.addAll([
      'const _gearRows = <(double, Object?)>[',
      '  ${[for (final r in gear) '(${repr(r[0])}, ${(r[1]! as num).toInt()})'].join(', ')}',
      '];',
      '',
      'const _sectorCrossings = <(double, int)>[',
      '  ${[for (final r in sectors) '(${repr(r[0])}, ${(r[1]! as num).toInt() == 0 ? 3 : (r[1]! as num).toInt()})'].join(', ')}',
      '];',
      '',
      'TraceSeries _series(String name, String unit, Float64List values) =>',
      '    TraceSeries(',
      '      channelName: name,',
      '      unit: unit,',
      '      frequencyHz: $_emitHz,',
      "      valueColumn: 'value',",
      '      times: _times,',
      '      lows: values,',
      '      highs: values,',
      '    );',
      '',
      '/// The lap as `lapTelemetryProvider` would resolve it.',
      'LapTelemetry ${p}Telemetry() => LapTelemetry(',
      '      lap: $p(),',
      '      startSeconds: ${p}StartSeconds,',
      '      endSeconds: ${p}EndSeconds,',
      '      channels: {',
    ]);
    for (final (name, dart, _) in _channels) {
      if (_fields.contains(dart) || !series.containsKey(dart)) continue;
      parts.add("        '$name': _series('$name', '${units[dart]}', _$dart),");
    }
    String field(String label, String name, String dart) =>
        series.containsKey(dart)
        ? "      $label: _series('$name', '${units[dart]}', _$dart),"
        : '      $label: null,';
    parts.addAll([
      '      },',
      "      gear: StepSeries.fromRows(_gearRows, eventName: 'Gear'),",
      field('lapDistance', 'Lap Dist', 'lapDistance'),
      field('latitude', 'GPS Latitude', 'latitude'),
      field('longitude', 'GPS Longitude', 'longitude'),
      field('pathLateral', 'Path Lateral', 'pathLateral'),
      field('trackEdge', 'Track Edge', 'trackEdge'),
      '      sectorBoundaries: _sectorCrossings,',
      '    );',
      '',
      'Lap $p() => Lap(',
      '      index: ${p}Index,',
      '      startSeconds: ${p}StartSeconds,',
      '      endSeconds: ${p}EndSeconds,',
      '      lapTimeSeconds: ${p}TimeSeconds,',
      '      sectors: SectorTimes.fromCumulative(',
      '        sector1: ${p}Sector1,',
      '        sector2Cumulative: ${p}Sector2Cumulative,',
      '        lapTimeSeconds: ${p}TimeSeconds,',
      '      ),',
      '    );',
      '',
    ]);

    File(output).writeAsStringSync(parts.join('\n'));
    stdout.writeln(
      'wrote $output: ${times.length} samples at $_emitHz Hz, '
      '${gear.length} gear rows, ${sectors.length} sector crossings',
    );
  } finally {
    await con.dispose();
    await db.dispose();
  }
}
