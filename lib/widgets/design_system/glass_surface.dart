import 'dart:ui';

import 'package:flutter/material.dart';

import 'radius_tokens.dart';

/// The selective glass wrapper (SPEC.md §9.7.3) — backdrop blur + tint +
/// border. Reserved for static or infrequently-redrawn chrome (top bar,
/// modals, the session card, floating panels); deliberately never used on
/// the live trace charts or track map, which redraw every frame during
/// scrubbing and sit directly on the §9.5 performance-critical path.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.xl,
    this.blurSigma = 20,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = AppRadii.squircle(radius);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: shape,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
