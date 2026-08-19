import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'hooks.dart';
import 'radius_tokens.dart';

/// Squircle-shaped shimmer loading placeholder (SPEC.md §9.7.4). Built
/// in-house rather than the `shimmer` package, since it needs to clip to
/// our squircle shape tokens specifically, not a generic box. Respects
/// the platform's reduced-motion setting.
///
/// A [HookWidget] over [useShimmer] rather than a `StatefulWidget` with a
/// `TickerProviderStateMixin`: that boilerplate is the exact case §9.3/§9.7.5
/// adopted `flutter_hooks` for, so this is where the boundary gets honoured
/// rather than described.
class Skeleton extends HookWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = AppRadii.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final controller = useShimmer();
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.onSurface.withValues(alpha: 0.06);

    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppRadii.squircle(radius)),
      child: SizedBox(
        width: width,
        height: height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                gradient: LinearGradient(
                  begin: Alignment(-1 - controller.value * 2, 0),
                  end: Alignment(1 - controller.value * 2, 0),
                  colors: [base, highlight, base],
                  stops: const [0.3, 0.5, 0.7],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
