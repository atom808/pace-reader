import 'package:flutter/material.dart';

/// Corner-radius scale (SPEC.md §9.7.2). Every shape is a true continuous
/// squircle via [ContinuousRectangleBorder] — an actual iOS-style
/// continuous-curvature corner, not a circular-arc approximation — and
/// never large enough relative to a control's size to round into a pill.
abstract final class AppRadii {
  static const sm = 14.0;
  static const md = 20.0;
  static const lg = 28.0;
  static const xl = 34.0;

  static OutlinedBorder squircle(double radius) =>
      ContinuousRectangleBorder(borderRadius: BorderRadius.circular(radius));
}
