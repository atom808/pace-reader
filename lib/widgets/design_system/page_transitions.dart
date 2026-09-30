import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'motion_tokens.dart';

/// Shared [CustomTransitionPage] builder (SPEC.md §9.7.4) — "Cupertino-like"
/// is adopted as an easing/feel (smooth deceleration slide+fade), not the
/// literal iOS edge-swipe-to-dismiss gesture, which doesn't map to
/// desktop/web. Applied once here rather than per-route.
///
/// **Reduced motion (§10).** A [CustomTransitionPage]'s duration is fixed when
/// the page is constructed, and construction happens in the router's
/// `pageBuilder` — long before there is a route (and so a [MediaQuery] that
/// tracks the platform setting *live*) to ask. The transition's builder is the
/// one place that runs per frame with a current context, so that is where the
/// setting is read: under reduced motion the page is returned bare, with no
/// fade and no slide. The route's controller still ticks for
/// [AppDurations.medium], but nothing is being drawn from it — the incoming
/// page is opaque and already at full strength on its first frame, and the
/// outgoing one is simply covered.
CustomTransitionPage<T> appPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: AppDurations.medium,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (AppMotion.reduced(context)) return child;
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
