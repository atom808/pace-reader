// Value-axis label placement (SPEC.md §9.5) — the arithmetic behind
// `paintValueLabels`, checked without pixels.

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/painters/chart_painting.dart';

void main() {
  test('a label rests just above its line', () {
    final labels = layoutValueLabels([90, 50], height: 100);
    expect(labels.map((l) => (l.index, l.top)), [(0, 76.0), (1, 36.0)]);
  });

  test('the line at the very top takes its label below it', () {
    final labels = layoutValueLabels([4], height: 100);
    expect(labels.single.top, 6);
  });

  test('a flipped top label that would collide is the one given up', () {
    // The Speed panel that prompted this: 100/150/200/250 km/h on a 100 px
    // panel put "250" under its line and through "200" above its own.
    final labels = layoutValueLabels([95, 64, 33, 2], height: 100);
    expect(labels.map((l) => l.index), [0, 1, 2]);
  });

  test('with room to spare, the flipped label stays', () {
    final labels = layoutValueLabels([95, 50, 2], height: 100);
    expect(labels.map((l) => l.index), [0, 1, 2]);
  });

  test('lines outside the panel carry no label', () {
    expect(layoutValueLabels([-1, 101], height: 100), isEmpty);
  });
}
