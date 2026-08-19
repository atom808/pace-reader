import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'motion_tokens.dart';

/// Custom hook wrapping standardized animation timing (SPEC.md §9.7.5) so
/// screens reach for this instead of hand-rolling an [AnimationController]
/// with its own ad hoc duration/curve. Scoped narrowly to ephemeral,
/// widget-local animation lifecycle — see §9.3 for why this doesn't
/// replace Riverpod notifiers for domain/app state.
AnimationController useFadeInOnMount({Duration duration = AppDurations.medium}) {
  final controller = useAnimationController(duration: duration);
  useEffect(() {
    controller.forward();
    return null;
  }, const []);
  return controller;
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
