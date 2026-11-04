import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

List<double> _unwrap(List<double> raw) =>
    unwrapStations(Float64List.fromList(raw)).toList();

Matcher get _increasing => predicate<List<double>>((v) {
  for (var i = 1; i < v.length; i++) {
    if (v[i] <= v[i - 1]) return false;
  }
  return true;
}, 'strictly increasing');

void main() {
  test('a lap that runs forwards is left alone', () {
    expect(_unwrap([0, 10, 20, 30]), [0, 10, 20, 30]);
  });

  test("the last lap's tail before the line falls below zero", () {
    final out = _unwrap([990, 995, 1, 6, 400, 800, 990]);
    expect(out, _increasing);
    expect(out.sublist(2), [1, 6, 400, 800, 990]);
    expect(out.take(2), everyElement(lessThan(0)));
  });

  test("the next lap's start after the line runs past the length", () {
    final out = _unwrap([1, 6, 400, 800, 995, 2, 7]);
    expect(out, _increasing);
    expect(out.take(5), [1, 6, 400, 800, 995]);
    expect(out.skip(5), everyElement(greaterThan(995)));
  });

  test('both at once, and stations on the lap keep their values', () {
    final out = _unwrap([995, 2, 300, 600, 900, 998, 3]);
    expect(out, _increasing);
    expect(out.sublist(1, 6), [2, 300, 600, 900, 998]);
    expect(out.first, lessThan(0));
    expect(out.last, greaterThan(998));
  });
}
