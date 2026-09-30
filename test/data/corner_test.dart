// The per-corner column order (SPEC.md §5.3, §15.5).

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';

void main() {
  test('value1..value4 are FL, FR, RL, RR', () {
    expect(Corner.values.map((c) => c.short), ['FL', 'FR', 'RL', 'RR']);
    expect(Corner.valueColumns, ['value1', 'value2', 'value3', 'value4']);
    for (final corner in Corner.values) {
      expect(Corner.ofColumn(corner.valueColumn), corner);
    }
    expect(Corner.ofColumn('value'), isNull);
  });

  test('front/rear and left/right', () {
    expect([for (final c in Corner.values) c.isFront],
        [true, true, false, false]);
    expect([for (final c in Corner.values) c.isLeft],
        [true, false, true, false]);
  });

  test('the inner tread edge faces the centreline on every wheel', () {
    // TyresTempLeft/Right are car-frame edges: inner is the right-hand edge
    // of a left wheel and the left-hand edge of a right wheel.
    expect(Corner.frontLeft.innerEdge, CarSide.right);
    expect(Corner.rearLeft.innerEdge, CarSide.right);
    expect(Corner.frontRight.innerEdge, CarSide.left);
    expect(Corner.rearRight.innerEdge, CarSide.left);
    for (final corner in Corner.values) {
      expect(corner.outerEdge, isNot(corner.innerEdge));
      expect(corner.outerEdge, corner.side,
          reason: 'the outer edge is on the side of the car the wheel is on');
    }
  });

  test('names its setup keys the way the setup does', () {
    expect(Corner.frontLeft.setupKey('PRESSURE'), 'WM_PRESSURE-W_FL');
    expect(Corner.rearRight.setupKey('BRAKEDISC'), 'WM_BRAKEDISC-W_RR');
  });
}
