// The magnitude colour ramp (SPEC.md §8.5, §9.7.1).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/widgets/charting/value_ramp.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

void main() {
  group('ValueRamp', () {
    test('is monotonic in lightness, which is what makes it readable as a scale',
        () {
      // The one property a sequential ramp must have: a brighter part of the
      // lap is always a larger value. A rainbow ramp has no such ordering,
      // which is why §8.5's map does not use one.
      for (final base in [
        AppColors.channelSpeed,
        AppColors.channelBrake,
        AppColors.channelThrottle,
      ]) {
        final ramp = ValueRamp(base);
        var previous = -1.0;
        for (var i = 0; i <= 20; i++) {
          final luminance = ramp.at(i / 20).computeLuminance();
          expect(luminance, greaterThan(previous), reason: '$base at ${i / 20}');
          previous = luminance;
        }
      }
    });

    test('holds one hue end to end', () {
      // §9.7.1 keeps one colour per channel type; a map coloured by brake
      // stays red throughout and varies only in lightness.
      final ramp = ValueRamp(AppColors.channelBrake);
      final baseHue = HSLColor.fromColor(AppColors.channelBrake).hue;
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(HSLColor.fromColor(ramp.at(t)).hue, closeTo(baseHue, 0.5));
      }
    });

    test('stays clear of the surface at its dark end', () {
      // A ramp reaching down to the theme's near-black surface would make the
      // slowest part of the lap invisible rather than merely dim.
      final surface = AppTheme.dark().colorScheme.surface;
      final darkest = ValueRamp(AppColors.channelSpeed).at(0);
      expect(darkest.computeLuminance(),
          greaterThan(surface.computeLuminance() * 3));
    });

    test('clamps out-of-range and non-finite inputs', () {
      final ramp = ValueRamp(AppColors.channelSpeed);
      expect(ramp.at(-5), ramp.at(0));
      expect(ramp.at(9), ramp.at(1));
      expect(ramp.at(double.nan), ramp.at(0));
    });

    test('legend stops run dark to light', () {
      final stops = ValueRamp(AppColors.channelThrottle).stops(count: 5);
      expect(stops, hasLength(5));
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i].computeLuminance(),
            greaterThan(stops[i - 1].computeLuminance()));
      }
    });
  });
}
