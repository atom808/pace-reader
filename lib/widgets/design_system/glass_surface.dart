import 'dart:ui';

import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'gradient_border.dart';
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
    // The clip takes the plain token shape and the decoration takes the
    // gradient one: a [ShapeBorderClipper] only ever needs the outer path,
    // and clipping to the bordered shape would cut the stroke in half along
    // its own outline.
    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppRadii.squircle(radius)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: GradientSquircleBorder(radius: radius),
            // Glass takes the wine→iris journey as a *tint* rather than a
            // fill: what is behind it has to stay readable through it, so
            // both stops are the ramp's own tones at partial alpha instead
            // of the saturated [AppGradients.brand] pair.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh.withValues(alpha: 0.62),
                AppColors.surfaceLow.withValues(alpha: 0.5),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
