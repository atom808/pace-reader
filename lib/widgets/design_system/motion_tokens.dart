import 'package:flutter/animation.dart';

/// Durations and easing curves (SPEC.md §9.7.4). [AppCurves.entrance]
/// approximates the "Cupertino-like" smooth-deceleration feel adopted for
/// route transitions and widget-state cross-fades — the easing/feel, not
/// the iOS edge-swipe-to-dismiss gesture, which doesn't map to desktop/web.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
}

abstract final class AppCurves {
  /// Matches the design preview's cubic-bezier(.16, 1, .3, 1).
  static const entrance = Cubic(0.16, 1.0, 0.3, 1.0);
  static const standard = Curves.easeOutCubic;
}
