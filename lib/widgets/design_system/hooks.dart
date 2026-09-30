import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'motion_tokens.dart';

/// Custom hook wrapping standardized animation timing (SPEC.md §9.7.5) so
/// screens reach for this instead of hand-rolling an [AnimationController]
/// with its own ad hoc duration/curve. Scoped narrowly to ephemeral,
/// widget-local animation lifecycle — see §9.3 for why this doesn't
/// replace Riverpod notifiers for domain/app state.
///
/// Honours the platform's reduced-motion setting (§9.7.4) by landing on the
/// finished state at once — the widget shows up, it just doesn't travel — and
/// re-evaluates if that setting changes mid-session.
AnimationController useFadeInOnMount({Duration duration = AppDurations.medium}) {
  final controller = useAnimationController(duration: duration);
  final reducedMotion = AppMotion.reduced(useContext());
  useEffect(() {
    if (reducedMotion) {
      controller.value = 1.0;
    } else {
      // A no-op from a controller that has already finished, which is what
      // makes it safe to re-run when reduced motion is switched back off.
      controller.forward();
    }
    return null;
  }, [reducedMotion]);
  return controller;
}

/// The progress of one item in a staggered entrance (SPEC.md §9.7.4): 0 for
/// `index * stagger`, then 0→1 over [duration] on [AppCurves.entrance].
///
/// One controller per item rather than a timer that starts it late, and that
/// is the point of building the delay into the *curve* ([Interval]): a delayed
/// `controller.forward()` leaves no scheduled frame while it waits, so
/// `pumpAndSettle` would return before the item had started, and a golden of
/// the screen would capture the tiles half-arrived. With the delay inside the
/// controller's own duration the ticker is running from the first frame, the
/// tree settles only when the last item has landed, and the final frame is
/// the one the screen would have had with no animation at all.
///
/// Reduced motion collapses the whole thing to its end state
/// ([useFadeInOnMount]).
Animation<double> useStaggeredFadeIn({
  required int index,
  Duration stagger = AppDurations.stagger,
  Duration duration = AppDurations.slow,
}) {
  final delay = stagger * index;
  final total = delay + duration;
  final controller = useFadeInOnMount(duration: total);
  return useMemoized(
    () => CurveTween(
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1.0,
        curve: AppCurves.entrance,
      ),
    ).animate(controller),
    [controller, delay, duration],
  );
}

/// Drives the repeating shimmer sweep behind [Skeleton] (SPEC.md §9.7.5,
/// §9.7.6). Honours the platform's reduced-motion accessibility setting
/// (§9.7.4) by holding the controller still instead of repeating, and
/// re-evaluates if that setting changes mid-session.
AnimationController useShimmer({Duration period = AppDurations.shimmer}) {
  final controller = useAnimationController(duration: period);
  final reducedMotion = MediaQuery.disableAnimationsOf(useContext());
  useEffect(() {
    if (reducedMotion) {
      controller.stop();
    } else {
      controller.repeat();
    }
    return null;
  }, [reducedMotion]);
  return controller;
}
