import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import 'stage_fixture.dart';

void main() {
  final path = circleLap(radius: 200, speed: 50);
  final kinematics = PathKinematics.of(path);

  test('reads the speed off the path and its clock', () {
    // A chord over four 5 m steps of a 200 m circle is a hair short of the
    // arc: within half a percent of the 50 m/s driven.
    expect(kinematics.speedAt(40), closeTo(50, 0.25));
    expect(kinematics.maxSpeed, closeTo(50, 0.25));
  });

  test('heads along the circle, anticlockwise on screen', () {
    // At θ = 0 the car is due east of the centre heading north: up on
    // screen, where y grows south.
    final heading = kinematics.headingAt(0.5);
    expect(heading.dx, closeTo(0, 0.05));
    expect(heading.dy, lessThan(-0.99));
  });

  test('domain and fractional index are inverses', () {
    for (final x in [0.0, 12.5, 333.3, 1000.0]) {
      final i = indexAtDomain(path, x)!;
      expect(domainAtIndex(path, i), closeTo(x, 1e-9));
    }
    expect(indexAtDomain(path, -1), isNull);
    expect(indexAtStation(path, 250), closeTo(50, 1e-9));
  });

  test('a path without a clock has no speed, and the zoom holds still', () {
    final still = TrackPath(
      projection: path.projection,
      xs: path.xs,
      values: path.values,
      valueRange: path.valueRange,
      valueLabel: '',
      valueUnit: '',
    );
    final k = PathKinematics.of(still);
    expect(k.hasSpeed, isFalse);
    expect(k.speedFraction(30), 0.5);
  });
}
