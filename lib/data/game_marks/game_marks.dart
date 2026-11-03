/// The make and circuit logos Le Mans Ultimate ships, read from the player's
/// own install at runtime.
///
/// They are never copied into the repository or bundled: they are their
/// owners' trademarks and Studio 397's artwork, and reading the file the
/// player already has redistributes nothing. Without the game (another
/// platform, an install elsewhere, a test) there are simply no marks, and
/// every caller falls back to text and Pace Reader's own glyphs.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import 'ui_zip_reader.dart';

/// One logo's file, as the game ships it.
class GameMark {
  const GameMark({required this.bytes, required this.isRaster});

  final Uint8List bytes;

  /// A PNG, where the game's SVG only wraps a raster; an SVG otherwise.
  final bool isRaster;
}

class GameMarks {
  const GameMarks({this.makes = const {}, this.circuits = const {}});

  static const none = GameMarks();

  /// By the game's own make name (`Porsche`, `Aston Martin`).
  final Map<String, GameMark> makes;

  /// By the logo's file name without extension (`lemanswec`).
  final Map<String, GameMark> circuits;

  bool get isEmpty => makes.isEmpty && circuits.isEmpty;
}

const _brandDirectory = 'start/images/manufacturer/';
const _circuitDirectory = 'start/images/tracks/logos/';

/// The marks of the installed game; [GameMarks.none] when there is none.
/// Read once, off the UI isolate, the first time something asks.
final gameMarksProvider = FutureProvider<GameMarks>((ref) async {
  if (!Platform.isWindows || Platform.environment['FLUTTER_TEST'] == 'true') {
    return GameMarks.none;
  }
  try {
    return await Isolate.run(_readInstalledMarks);
  } on Object {
    return GameMarks.none;
  }
});

/// Where a Steam install of Le Mans Ultimate might be: the default library,
/// then each library Steam lists.
List<String> candidateInstallFolders() {
  const game = r'steamapps\common\Le Mans Ultimate';
  const steam = r'C:\Program Files (x86)\Steam';
  final folders = <String>[p.join(steam, game)];
  try {
    final vdf = File(p.join(steam, r'steamapps\libraryfolders.vdf'));
    if (vdf.existsSync()) {
      for (final match
          in RegExp(r'"path"\s+"([^"]+)"').allMatches(vdf.readAsStringSync())) {
        folders.add(p.join(match[1]!.replaceAll(r'\\', r'\'), game));
      }
    }
  } on Object {
    // An unreadable library list only narrows the search.
  }
  return folders;
}

Future<GameMarks> _readInstalledMarks() async {
  for (final folder in candidateInstallFolders()) {
    final zip = File(p.join(folder, 'Bin', 'UI.zip'));
    if (!zip.existsSync()) continue;
    final marks = await readMarksFrom(zip.path);
    if (!marks.isEmpty) return marks;
  }
  return GameMarks.none;
}

/// The make and circuit logos in the zip at [path].
Future<GameMarks> readMarksFrom(String path) async {
  final reader = await ZipReader.open(path);
  if (reader == null) return GameMarks.none;
  try {
    final names = reader.names.toList();
    final nameSet = names.toSet();
    final makes = <String, GameMark>{};
    final circuits = <String, GameMark>{};

    for (final name in names) {
      if (name.startsWith(_brandDirectory) && name.endsWith('.svg')) {
        final make = name.substring(
          _brandDirectory.length + 'Brand='.length,
          name.length - '.svg'.length,
        );
        // The "Dark" variants are black, for light surfaces; this UI is dark.
        if (!name.contains('Brand=') ||
            make.endsWith(' Dark') ||
            make == 'Default') {
          continue;
        }
        // A make whose SVG only wraps a raster has a PNG beside it, which is
        // both lighter and certain to draw.
        final png = name.replaceFirst(RegExp(r'\.svg$'), '.png');
        final mark = nameSet.contains(png)
            ? await _mark(reader, png, raster: true)
            : await _mark(reader, name, raster: false);
        if (mark != null) makes[make] = mark;
      } else if (name.startsWith(_circuitDirectory) && name.endsWith('.svg')) {
        final file = name.substring(
          _circuitDirectory.length,
          name.length - '.svg'.length,
        );
        if (file.startsWith('Circuit=')) continue;
        final mark = await _mark(reader, name, raster: false);
        if (mark != null) circuits[file] = mark;
      }
    }
    return GameMarks(makes: makes, circuits: circuits);
  } finally {
    await reader.close();
  }
}

Future<GameMark?> _mark(
  ZipReader reader,
  String name, {
  required bool raster,
}) async {
  final bytes = await reader.read(name);
  if (bytes == null || bytes.isEmpty) return null;
  if (raster) return GameMark(bytes: bytes, isRaster: true);
  final svg = cleanGameSvg(utf8.decode(bytes, allowMalformed: true));
  return svg == null
      ? null
      : GameMark(bytes: Uint8List.fromList(utf8.encode(svg)), isRaster: false);
}

/// [svg] made safe and parseable, or null when it is not an SVG we will draw.
///
/// The game's files are trusted no further than a file on disk: anything with
/// a script or a reference to somewhere else is refused rather than handed to
/// the renderer. And `interlagoswec.svg` lacks the namespace every parser
/// requires, so it is added.
String? cleanGameSvg(String svg) {
  final lower = svg.toLowerCase();
  if (!lower.contains('<svg')) return null;
  if (lower.contains('<script')) return null;
  if (RegExp(r'''href\s*=\s*["']https?:''').hasMatch(lower)) return null;
  final root = RegExp(r'<svg\b[^>]*>', caseSensitive: false).firstMatch(svg);
  if (root == null) return null;
  final inlined = _inlineClassStyles(svg);
  if (root[0]!.contains('xmlns=')) return inlined;
  return inlined.replaceFirst(
    RegExp(r'<svg\b', caseSensitive: false),
    '<svg xmlns="http://www.w3.org/2000/svg"',
  );
}

/// [svg] with its `<style>` class rules copied onto the elements that use
/// them.
///
/// The renderer ignores `<style>`, and Illustrator exports colour almost
/// every circuit logo through one (`.st0{fill:#FFFFFF;}`), so without this
/// Le Mans, Spa, Monza and Fuji draw in black on a black card. Only the
/// plain `.class` selectors Illustrator writes are understood; the rules go
/// first in each element's `style`, so the element's own inline style still
/// wins, as it would in a browser.
String _inlineClassStyles(String svg) {
  final styleBlock = RegExp(
    r'<style\b[^>]*>([\s\S]*?)</style>',
    caseSensitive: false,
  );
  final rulesByClass = <String, String>{};
  for (final block in styleBlock.allMatches(svg)) {
    for (final rule in RegExp(r'([^{}]+)\{([^}]*)\}').allMatches(block[1]!)) {
      final declarations = rule[2]!.trim();
      for (final selector in rule[1]!.split(',')) {
        final name = selector.trim();
        if (!RegExp(r'^\.[\w-]+$').hasMatch(name)) continue;
        final key = name.substring(1);
        rulesByClass[key] = [
          ?rulesByClass[key],
          declarations,
        ].map((d) => d.endsWith(';') ? d : '$d;').join();
      }
    }
  }
  if (rulesByClass.isEmpty) return svg;

  final withoutStyle = svg.replaceAll(styleBlock, '');
  return withoutStyle.replaceAllMapped(
    RegExp(r'<([\w:-]+)(\s[^<>]*?)?(/?)>'),
    (tag) {
      final attributes = tag[2] ?? '';
      final classes = RegExp(r'''\sclass\s*=\s*["']([^"']*)["']''')
          .firstMatch(attributes);
      if (classes == null) return tag[0]!;
      final declarations = classes[1]!
          .split(RegExp(r'\s+'))
          .map((c) => rulesByClass[c])
          .nonNulls
          .join();
      if (declarations.isEmpty) return tag[0]!;
      final style = RegExp(r'''\sstyle\s*=\s*(["'])([^"']*)\1''')
          .firstMatch(attributes);
      final merged = style == null
          ? '$attributes style="$declarations"'
          : attributes.replaceRange(
              style.start,
              style.end,
              ' style="$declarations${style[2]}"',
            );
      return '<${tag[1]}$merged${tag[3]}>';
    },
  );
}
