// Layering rules that the analyzer can't express on its own (map stage
// proposal §14.3).
//
// The chart core is shared by every screen that draws a trace or a map; it
// must stay generic. Features depend on it, never the reverse: a feature that
// wants the stage to draw something supplies a layer through its contracts.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the chart core never imports a feature', () {
    final offenders = <String>[];
    final files = Directory('lib/widgets/charting')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.startsWith('import ') && line.contains('features/')) {
          offenders.add('${file.path}:${i + 1}: $line');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
