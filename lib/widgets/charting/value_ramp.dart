/// Encoding magnitude as colour (SPEC.md §8.5, §9.7.1).
///
/// A track map coloured by speed is asking colour to carry a *quantity*,
/// which is a different job from the channel colours in
/// `design_system/color_tokens.dart`: those carry *identity* — "this trace is
/// brake" — and are the same colour at every value. Identity colours live in
/// the design system; how a magnitude is encoded lives here with the charts
/// that encode it.
///
/// The rule the ramp follows is the standard one for sequential data: **one
/// hue, varying in lightness**, never a rainbow. A multi-hue speed ramp
/// (blue→green→yellow→red) implies category boundaries the data does not
/// have, and stops being readable at all under the common colour-vision
/// deficiencies. Holding the channel's own hue also keeps §9.7.1's "one
/// colour per channel type" true of the map: a map coloured by brake is red
/// throughout, and only its lightness moves.
///
/// Running the ramp dark→light with increasing value is specific to this
/// app's dark theme (§9.7): on a near-black surface, brighter reads as
/// "more", and the ramp's dark end recedes into the background exactly where
/// the value is lowest.
library;

import 'package:flutter/material.dart';

/// A single-hue lightness ramp anchored on a channel's identity colour.
class ValueRamp {
  ValueRamp(Color base)
      : _hue = HSLColor.fromColor(base).hue,
        _saturation = HSLColor.fromColor(base).saturation;

  final double _hue;
  final double _saturation;

  /// Lightness at the low end.
  ///
  /// Not lower: the theme's surface sits at about 0.08 lightness, and a ramp
  /// that reaches down to meet it would make the slowest part of the lap
  /// invisible rather than merely dim.
  static const _minLightness = 0.28;

  /// Lightness at the high end. Short of white so the ramp stays a hue rather
  /// than washing out to the same colour every channel would end at.
  static const _maxLightness = 0.84;

  /// The colour for a normalized value in `[0, 1]`.
  Color at(double t) {
    final clamped = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    return HSLColor.fromAHSL(
      1,
      _hue,
      _saturation,
      _minLightness + (_maxLightness - _minLightness) * clamped,
    ).toColor();
  }

  /// Evenly spaced stops, for a legend strip.
  List<Color> stops({int count = 5}) => [
        for (var i = 0; i < count; i++) at(count == 1 ? 1 : i / (count - 1)),
      ];
}
