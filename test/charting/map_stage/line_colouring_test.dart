import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import 'stage_fixture.dart';

const _colours = PedalColours(
  throttle: Color(0xFF00FF00),
  brake: Color(0xFFFF0000),
  coast: Color(0xFF808080),
);

PedalColouring _pedals(List<double> throttle, List<double> brake) =>
    PedalColouring(
      PedalSamples(
        throttle: Float64List.fromList(throttle),
        brake: Float64List.fromList(brake),
      ),
      _colours,
    );

void main() {
  group('PedalColouring', () {
    test('brake, throttle or coast, by what the feet were doing', () {
      final c = _pedals([1, 1, 0, 0, 0, 0], [0, 0, 0, 0, 1, 1]);
      expect(c.colourAt(0), _colours.throttle);
      expect(c.colourAt(2), _colours.coast);
      expect(c.colourAt(4), _colours.brake);
    });

    test('brake wins where both pedals are pressed', () {
      final c = _pedals([0.3, 0.3], [0.6, 0.6]);
      expect(c.colourAt(0).withValues(alpha: 1), _colours.brake);
    });

    test('a resting foot is not a pedal', () {
      final c = _pedals([0.04, 0.04], [0.02, 0.02]);
      expect(c.colourAt(0), _colours.coast);
    });

    test('depth comes in four steps, full travel fully opaque', () {
      expect(PedalColouring.depth(1), 1);
      expect(PedalColouring.depth(0.06), closeTo(0.4, 1e-12));
      final steps = {
        for (var a = 0.05; a <= 1; a += 0.01) PedalColouring.depth(a),
      };
      expect(steps.length, 4);
    });

    test('equal inputs make an equal colouring, so a rebuild does not '
        'repaint', () {
      final samples = PedalSamples(
        throttle: Float64List(3),
        brake: Float64List(3),
      );
      expect(
        PedalColouring(samples, _colours),
        PedalColouring(samples, _colours),
      );
    });
  });

  group('PedalSamples', () {
    test('reads percentages as fractions', () {
      final path = circleLap();
      final throttle = plotOf([0, 5000], [100, 100]);
      final brake = plotOf([0, 5000], [0, 0]);
      final samples = PedalSamples.sample(
        path,
        throttle: throttle,
        brake: brake,
      );
      expect(samples.throttle.every((v) => v == 1), isTrue);
      expect(samples.brake.every((v) => v == 0), isTrue);
    });

    test('a missing pedal reads as released', () {
      final samples = PedalSamples.sample(circleLap());
      expect(samples.throttle.every((v) => v == 0), isTrue);
    });
  });

  group('RampColouring', () {
    test('quantises to a dozen colours along the one hue', () {
      final base = circleLap();
      final n = base.length;
      final values = Float64List.fromList([for (var i = 0; i < n; i++) i / n]);
      final path = TrackPath(
        projection: base.projection,
        xs: base.xs,
        values: values,
        valueRange: const ValueRange(0, 1),
        valueLabel: 'Speed',
        valueUnit: 'km/h',
      );
      final ramp = ValueRamp(const Color(0xFF38C6D9));
      final c = RampColouring(path, ramp, fallback: const Color(0xFFFFFFFF));
      expect(c.label, 'Speed (km/h)');
      final colours = {for (var i = 0; i < n - 1; i++) c.colourAt(i)};
      expect(colours.length, 12);
      expect(c.colourAt(0), ramp.at(0));
    });

    test('a path with no values draws in the fallback', () {
      final c = RampColouring(
        circleLap(),
        ValueRamp(const Color(0xFF38C6D9)),
        fallback: const Color(0xFF123456),
      );
      expect(c.colourAt(5), const Color(0xFF123456));
    });
  });
}
