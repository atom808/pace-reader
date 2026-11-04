import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/track_outline/domain/outline_pool.dart';

Float64List _nan(int n) => Float64List(n)..fillRange(0, n, double.nan);

void main() {
  group('fillGaps', () {
    test('fills a short run straight across, from both sides', () {
      final values = _nan(5)
        ..[0] = 0
        ..[4] = 4;
      expect(fillGaps(values, 3), [0, 1, 2, 3, 4]);
    });

    test('leaves a run longer than the limit, and runs at either end', () {
      final values = _nan(8)
        ..[1] = 1
        ..[6] = 6;
      final filled = fillGaps(values, 3);
      expect(filled[0].isNaN, isTrue, reason: 'nothing known before it');
      expect(filled[7].isNaN, isTrue, reason: 'nothing known after it');
      expect(filled.sublist(2, 6).every((v) => v.isNaN), isTrue);
    });

    test('leaves the input as it was', () {
      final values = _nan(3)
        ..[0] = 0
        ..[2] = 2;
      fillGaps(values, 5);
      expect(values[1].isNaN, isTrue);
    });
  });

  group('OutlinePool', () {
    test('each side is the mean over the recordings that saw it', () {
      final pool = OutlinePool()
        ..add([
          (bin: 0, left: -4.0, right: null),
          (bin: 1, left: -6.0, right: 5.0),
        ])
        ..add([
          (bin: 0, left: null, right: 6.0),
          (bin: 1, left: -8.0, right: null),
        ]);
      final outline = pool.outline();
      expect(pool.recordings, 2);
      expect(outline.edgesAt(0), (-4.0, 6.0));
      expect(outline.edgesAt(3.9), (-7.0, 5.0));
    });

    test('a station nobody saw is filled up to 20 m, no further', () {
      final pool = OutlinePool(binMetres: 2)
        ..add([
          (bin: 0, left: -5.0, right: 5.0),
          (bin: 10, left: -7.0, right: 7.0), // 9 unseen between: filled
          (bin: 25, left: -5.0, right: 5.0), // 14 unseen: left open
        ]);
      final outline = pool.outline();
      expect(outline.edgesAt(11)!.$1, closeTo(-6, 1e-9));
      expect(outline.edgesAt(40), isNull);
    });

    test('a recording counts though it saw nothing', () {
      final pool = OutlinePool()..add(const []);
      expect(pool.recordings, 1);
      expect(pool.outline().length, 0);
    });

    test('survives a trip through JSON', () {
      final pool = OutlinePool()
        ..add([(bin: 2, left: -3.5, right: 4.5)])
        ..add([(bin: 2, left: -4.5, right: null)]);
      final back = OutlinePool.fromJson(jsonDecode(jsonEncode(pool.toJson())))!;
      expect(back.recordings, 2);
      expect(back.outline().edgesAt(5), (-4.0, 4.5));
      // And keeps pooling from where it was.
      back.add([(bin: 2, left: null, right: 6.5)]);
      expect(back.outline().edgesAt(5), (-4.0, 5.5));
    });

    test('anything else read as a pool is none', () {
      expect(OutlinePool.fromJson(null), isNull);
      expect(OutlinePool.fromJson({'binMetres': 2}), isNull);
      expect(
        OutlinePool.fromJson({
          'binMetres': 2,
          'recordings': 1,
          'sumLeft': [1],
          'countLeft': [1, 2],
          'sumRight': [1],
          'countRight': [1],
        }),
        isNull,
      );
    });
  });

  test('the envelope is widened by half a car and gap-filled', () {
    final outline = envelopeOutline([
      (bin: 0, left: -3.0, right: 2.0),
      (bin: 2, left: -5.0, right: 4.0),
      (bin: 3, left: null, right: 1.0), // one side only: no envelope
    ], binMetres: 2);
    expect(outline.edgesAt(0), (-4.0, 3.0));
    expect(outline.edgesAt(3), (-5.0, 4.0)); // filled between 0 and 2
    expect(outline.edgesAt(6), isNull);
  });
}
