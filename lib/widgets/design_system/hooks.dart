import 'package:flutter/animation.dart';
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
