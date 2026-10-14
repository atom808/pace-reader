// Checks the car catalog (`lib/data/reference/car_catalog.dart`) against a
// Le Mans Ultimate install: the five-minute job when a DLC lands.
//
//   dart --packages=.dart_tool/package_config.json tool/catalog_check.dart \
//     "C:\Program Files (x86)\Steam\steamapps\common\Le Mans Ultimate"
//
// It reads, and never writes:
// - `UserData\Log\trace_*.txt`, where each garage load names the entry and
//   the setup the game found for it (`Found setup: GT3_992GT3R_….svm`). The
//   setup's prefix is the model, so every entry the catalog places
//   differently, or cannot place, is listed.
// - `Installed\Vehicles`, whose folders are the models the game ships. A
//   folder no model claims is listed.
//
// New lines it prints become rows in `test/fixtures/car_entries.dart` and the
// catalog's tables. Exits 1 when it finds anything.
import 'dart:convert';
import 'dart:io';

import 'package:pace_reader/data/reference/car_catalog.dart';
import 'package:pace_reader/data/reference/car_class.dart';

final _garageLoad = RegExp(
  r'for Vehicle (.+?) & Track \S+?\. Found setup: (\S+?\.svm)',
);

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: catalog_check.dart <Le Mans Ultimate folder>');
    exit(64);
  }
  final root = Directory(args.single);
  var problems = 0;

  final pairs = <(String, String)>{};
  final logs = Directory('${root.path}/UserData/Log');
  if (logs.existsSync()) {
    for (final file in logs.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('trace_') || !name.endsWith('.txt')) continue;
      final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
      for (final m in _garageLoad.allMatches(text)) {
        pairs.add((m[1]!.trim(), m[2]!));
      }
    }
  }

  final unknownSetups = <String>{};
  final misplaced = <String>[];
  var checked = 0;
  for (final (entry, setup) in pairs.toList()..sort(_byFirst)) {
    final model = CarModel.ofSetup(setup);
    if (model == null) {
      // Third-party setups (CDA_…) and the player's own say nothing.
      final prefix = setup.split('_').take(2).join('_');
      if (RegExp(r'^(HY|GT3|LMP2|LMP3|GTE|AI)_').hasMatch(setup)) {
        unknownSetups.add(prefix);
      }
      continue;
    }
    checked++;
    final placed = placeCar(entry, _classCode(model.kind));
    if (placed.model != model) {
      misplaced.add(
        '  $entry\n'
        '    loads $setup (${model.label}); catalog: '
        '${placed.model?.label ?? placed.rule.name}',
      );
    }
  }

  stdout.writeln(
    '${pairs.length} garage loads in the logs, $checked with a game setup.',
  );
  if (unknownSetups.isNotEmpty) {
    problems += unknownSetups.length;
    stdout.writeln('\nGame setup prefixes no model claims:');
    for (final prefix in unknownSetups.toList()..sort()) {
      stdout.writeln('  $prefix');
    }
  }
  if (misplaced.isNotEmpty) {
    problems += misplaced.length;
    stdout.writeln('\nEntries the catalog places differently:');
    misplaced.forEach(stdout.writeln);
  }

  final vehicles = Directory('${root.path}/Installed/Vehicles');
  if (vehicles.existsSync()) {
    final folders = [
      for (final d in vehicles.listSync().whereType<Directory>())
        d.uri.pathSegments.where((s) => s.isNotEmpty).last,
    ]..sort();
    final orphans = [
      for (final f in folders)
        if (CarModel.ofFolder(f) == null) f,
    ];
    stdout.writeln('\n${folders.length} vehicle folders installed.');
    if (orphans.isNotEmpty) {
      problems += orphans.length;
      stdout.writeln('Folders no model claims:');
      for (final f in orphans) {
        stdout.writeln('  $f');
      }
    }
  } else {
    stdout.writeln('\nNo Installed\\Vehicles folder under ${root.path}.');
  }

  stdout.writeln(
    problems == 0 ? '\nThe catalog agrees.' : '\n$problems to look at.',
  );
  exit(problems == 0 ? 0 : 1);
}

int _byFirst((String, String) a, (String, String) b) {
  final c = a.$1.compareTo(b.$1);
  return c != 0 ? c : a.$2.compareTo(b.$2);
}

/// The class code a recording of a [kind] car carries.
String _classCode(CarClassKind? kind) => switch (kind) {
  CarClassKind.hypercar => 'Hyper',
  CarClassKind.lmp2 => 'LMP2',
  CarClassKind.lmp3 => 'LMP3',
  CarClassKind.lmgte => 'GTE',
  CarClassKind.lmgt3 => 'GT3',
  _ => '',
};
