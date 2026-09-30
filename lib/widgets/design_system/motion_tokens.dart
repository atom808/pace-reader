import 'package:flutter/widgets.dart';

/// Durations and easing curves (SPEC.md §9.7.4). [AppCurves.entrance]
/// approximates the "Cupertino-like" smooth-deceleration feel adopted for
/// route transitions and widget-state cross-fades — the easing/feel, not
/// the iOS edge-swipe-to-dismiss gesture, which doesn't map to desktop/web.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const medium = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);

  /// One full sweep of the skeleton shimmer. Lives here rather than inside
  /// [Skeleton] so §9.7.5's "animation timing is consistent app-wide rather
  /// than each screen picking its own" holds for the loading state too.
  static const shimmer = Duration(milliseconds: 1400);

  /// The gap between one item of a staggered entrance and the next
  /// ([StaggeredEntrance]). Long enough to read as a cascade, short enough
  /// that the last of five tiles has started before the first has finished
  /// arriving — 40 ms on a 360 ms rise is a ripple, not a queue.
  static const stagger = Duration(milliseconds: 40);
}

abstract final class AppCurves {
  /// Matches the design preview's cubic-bezier(.16, 1, .3, 1).
  static const entrance = Cubic(0.16, 1.0, 0.3, 1.0);
  static const standard = Curves.easeOutCubic;
}

/// The reduced-motion half of the motion tokens (SPEC.md §9.7.4, §10).
///
/// §9.7.4 says "all animation respects the platform's reduced-motion
/// setting", and Flutter reports that setting as
/// [MediaQuery.disableAnimationsOf] — on macOS/Windows/Linux the OS
/// "reduce motion" preference, on web `prefers-reduced-motion`. Nothing in the
/// framework's implicit animations reads it on its own: an [AnimatedContainer]
/// with a 120 ms duration takes 120 ms whatever the user asked for. So every
/// duration that comes from [AppDurations] goes through [duration], which is
/// the one place the setting is consulted for an implicit animation.
///
/// The answer is a zero [Duration] rather than "skip the widget": an implicit
/// animation with no time still lands on its end state, so state changes
/// (a card lit by hover, a nav slot selected, a cross-fade from skeleton to
/// data) keep meaning what they meant — they just stop *travelling*.
abstract final class AppMotion {
  /// True when the platform asks apps to stop animating.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [base], or [Duration.zero] under reduced motion.
  ///
  /// Reads the [MediaQuery] as a dependency, so a widget that builds with this
  /// re-evaluates if the setting changes while the app is running.
  static Duration duration(BuildContext context, Duration base) =>
      reduced(context) ? Duration.zero : base;
}
