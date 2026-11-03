import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/game_marks/game_marks.dart';
import 'package:pace_reader/data/game_marks/ui_zip_reader.dart';
import 'package:pace_reader/data/reference/track_catalog.dart';

void main() {
  group('cleanGameSvg', () {
    test('copies Illustrator class rules onto the elements', () {
      const svg = '<svg xmlns="http://www.w3.org/2000/svg">'
          '<style type="text/css">.st0{fill:#FFFFFF;}\n.st1, .st2{opacity:0.5}'
          '</style><path class="st0" d="M0 0"/>'
          '<rect class="st1 st0" style="stroke:red"/></svg>';
      final clean = cleanGameSvg(svg)!;
      expect(clean, isNot(contains('<style')));
      expect(clean, contains('<path class="st0" d="M0 0" style="fill:#FFFFFF;"/>'));
      expect(
        clean,
        contains('style="opacity:0.5;fill:#FFFFFF;stroke:red"'),
      );
    });

    test('adds a missing namespace', () {
      expect(
        cleanGameSvg('<svg viewBox="0 0 1 1"></svg>'),
        startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox'),
      );
    });

    test('refuses scripts and remote references', () {
      expect(cleanGameSvg('<svg><script>x()</script></svg>'), isNull);
      expect(
        cleanGameSvg('<svg><image href="https://example.com/a.png"/></svg>'),
        isNull,
      );
      expect(cleanGameSvg('not an svg'), isNull);
    });
  });

  group('circuitLogoFor', () {
    test('maps the circuits the game has logos for', () {
      expect(circuitLogoFor('Circuit de la Sarthe'), 'lemanswec');
      expect(circuitLogoFor('Circuit de Spa-Francorchamps'), 'spawec');
      expect(circuitLogoFor('Autódromo José Carlos Pace'), 'interlagoswec');
      expect(circuitLogoFor('Sebring International Raceway'), 'sebringwec');
      expect(circuitLogoFor('Lusail International Circuit'), 'qatarwec');
      expect(circuitLogoFor('Algarve International Circuit'), 'portimaowec');
    });

    test('names the circuit, not the layout, except Silverstone ELMS', () {
      expect(
        circuitLogoFor('Sebring International Raceway', 'School Circuit'),
        'sebringwec',
      );
      expect(circuitLogoFor('Silverstone', 'Silverstone ELMS'),
          'silverstoneelms');
      expect(circuitLogoFor('Silverstone', 'Grand Prix'), 'silverstone');
    });

    test('never guesses', () {
      expect(circuitLogoFor('Nürburgring'), isNull);
      expect(circuitLogoFor('Spanish test track'), isNull);
    });
  });

  group('ZipReader', () {
    test('reads stored and deflated entries, normalising backslashes',
        () async {
      final dir = await Directory.systemTemp.createTemp('zip_reader_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/test.zip';
      await File(path).writeAsBytes(_zip({
        r'start\images\a.svg': ('<svg/>'.codeUnits, false),
        'b.txt': (List.filled(500, 0x61), true),
      }));

      final reader = (await ZipReader.open(path))!;
      addTearDown(reader.close);
      expect(reader.names, containsAll(['start/images/a.svg', 'b.txt']));
      expect(
        String.fromCharCodes((await reader.read('start/images/a.svg'))!),
        '<svg/>',
      );
      expect(await reader.read('b.txt'), List.filled(500, 0x61));
      expect(await reader.read('missing'), isNull);
    });

    test('is null for a file that is not a zip', () async {
      final dir = await Directory.systemTemp.createTemp('zip_reader_test');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/not.zip';
      await File(path).writeAsString('hello');
      expect(await ZipReader.open(path), isNull);
    });
  });
}

/// A minimal zip of [entries]: name → (bytes, deflate?).
List<int> _zip(Map<String, (List<int>, bool)> entries) {
  final out = <int>[];
  final central = <int>[];
  void u16(List<int> b, int v) => b.addAll([v & 0xff, v >> 8 & 0xff]);
  void u32(List<int> b, int v) =>
      b.addAll([v & 0xff, v >> 8 & 0xff, v >> 16 & 0xff, v >> 24 & 0xff]);

  for (final MapEntry(key: name, value: (data, deflate)) in entries.entries) {
    final body = deflate ? ZLibEncoder(raw: true).convert(data) : data;
    final offset = out.length;
    final nameBytes = name.codeUnits;
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, 0);
    u16(out, deflate ? 8 : 0);
    u32(out, 0); // time, date
    u32(out, 0); // crc, unchecked by the reader
    u32(out, body.length);
    u32(out, data.length);
    u16(out, nameBytes.length);
    u16(out, 0);
    out
      ..addAll(nameBytes)
      ..addAll(body);

    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0);
    u16(central, deflate ? 8 : 0);
    u32(central, 0);
    u32(central, 0);
    u32(central, body.length);
    u32(central, data.length);
    u16(central, nameBytes.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, offset);
    central.addAll(nameBytes);
  }
  final centralOffset = out.length;
  out.addAll(central);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, entries.length);
  u16(out, entries.length);
  u32(out, central.length);
  u32(out, centralOffset);
  u16(out, 0);
  return out;
}
