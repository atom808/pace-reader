// Turns Studio 397's BoP PDF for a patch into the app's table
// (lib/features/session_results/domain/bop_<version>.dart; PACE-FACTORS §5.6).
//
//   pdftotext -raw    LMU_BOP_1.4.3_Marked-up.pdf raw.txt
//   pdftotext -layout LMU_BOP_1.4.3_Marked-up.pdf layout.txt
//   dart tool/bop_from_pdf.dart raw.txt layout.txt 1.4.3 2026-10-06 1.4200 \
//     > lib/features/session_results/domain/bop_1_4_3.dart
//
// The last argument is the results files' `GameVersion` values the document
// was in force under. Rows come from the raw text, which keeps each car's
// figures on one line; each page's track group and layouts come from the
// layout text, whose header names them. The pages run Hypercar, LMGT3, then
// LMGTE/LMP2/LMP3 for each track group. A model the page does not list in
// full goes to stderr. Add the new document to `bopDocuments`, then
// `dart format` the output.
import 'dart:convert';
import 'dart:io';

const hyper = [
  'Alpine A424',
  'Aston Martin Valkyrie',
  'BMW M Hybrid V8',
  'Cadillac V-Series.R',
  'Ferrari 499P',
  'Genesis GMR-001',
  'Glickenhaus SCG 007',
  'Isotta Tipo 6',
  'Lamborghini SC63',
  '9x8 Evo',
  '9x8',
  'Porsche 963',
  'Toyota GR010',
  'Vanwall Vandervell 680',
];
const gt3 = [
  'Aston Martin Vantage AMR LMGT3',
  'BMW M4 LMGT3',
  'Corvette Z06 LMGT3.R',
  'Ferrari 296 LMGT3',
  'Ford Mustang LMGT3',
  'Lamborghini Huracan LMGT3 Evo2',
  'Lexus RC F LMGT3',
  'McLaren 720S LMGT3 Evo',
  'Mercedes AMG LMGT3',
  'Porsche 911 GT3 R',
];

final num = r'(-?\d+(?:\.\d+)?|-)(?: \(([+-]\d+(?:\.\d+)?)\))?';

String v((String, String?) x) {
  if (x.$1 == '-') return 'null';
  return x.$2 == null ? 'BopValue(${x.$1})' : 'BopValue(${x.$1}, ${x.$2})';
}

String d(String x) => x == '-' ? 'null' : x;

void main(List<String> args) {
  final raw = latin1.decode(File(args[0]).readAsBytesSync()).split('\f');
  final layout = latin1.decode(File(args[1]).readAsBytesSync()).split('\f');
  final out = StringBuffer();
  final layouts = <String, String>{};
  var count = 0;
  for (var p = 1; p <= raw.length; p++) {
    final isHyper = p % 3 == 2;
    final isGt3 = p % 3 == 0;
    if (!isHyper && !isGt3) continue;
    // The page header in layout mode: "Le Mans  <layouts or Dry Tyre…>  …Date".
    final head = layout[p - 1]
        .split('\n')
        .firstWhere((l) => l.contains('Date '), orElse: () => '');
    final parts = head
        .replaceAll(RegExp(r'Date.*'), '')
        .trim()
        .split(RegExp(r' {2,}'));
    if (parts.isEmpty || parts.first.isEmpty) continue;
    final group = parts.first;
    if (parts.length > 1 && parts[1].contains(',')) layouts[group] = parts[1];
    final text = raw[p - 1].replaceAll(RegExp(r'\s+'), ' ');
    final models = isHyper ? hyper : gt3;
    final n = isHyper ? 8 : 9;
    for (final m in models) {
      final re = RegExp(
        '(?:^| )${RegExp.escape(m)} ${List.filled(n, num).join(' ')}(?= |\$)',
      );
      final match = re.firstMatch(text);
      if (match == null) {
        stderr.writeln('missing: p$p $group $m');
        continue;
      }
      (String, String?) g(int i) =>
          (match.group(1 + 2 * i)!, match.group(2 + 2 * i));
      String cell(int i) =>
          g(i).$2 == null ? g(i).$1 : '${g(i).$1}(${g(i).$2})';
      count++;
      out.writeln(
        [
          group,
          isHyper ? 'H' : 'G',
          m,
          for (var i = 0; i < n; i++) cell(i),
        ].join('|'),
      );
    }
  }
  final date = args[3].split('-');
  final ident = 'bop${args[2].replaceAll('.', '_')}';
  stdout.writeln('''
// Generated from Studio 397's "LMU_BOP_${args[2]}_Marked-up.pdf" (dated
// ${args[3]}) with `pdftotext -raw`: $count rows, Hypercar (H) and LMGT3 (G).
// Regenerate from the PDF rather than edit by hand.
part of 'bop_documents.dart';

// ignore: constant_identifier_names
const $ident = BopDocument(
  version: '${args[2]}',
  year: ${int.parse(date[0])},
  month: ${int.parse(date[1])},
  day: ${int.parse(date[2])},
  gameVersions: {${args[4].split(',').map((g) => "'$g'").join(', ')}},
  layouts: {
${layouts.entries.map((e) => "    '${e.key}':\n        '${e.value}',").join('\n')}
  },
  table: \'\'\'
${out.toString().trimRight()}
\'\'\',
);''');
}
