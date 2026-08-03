import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'motion_tokens.dart';

/// Shared [CustomTransitionPage] builder (SPEC.md §9.7.4) — "Cupertino-like"
/// is adopted as an easing/feel (smooth deceleration slide+fade), not the
/// literal iOS edge-swipe-to-dismiss gesture, which doesn't map to
/// desktop/web. Applied once here rather than per-route.
CustomTransitionPage<T> appPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppDurations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppCurves.entrance);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
