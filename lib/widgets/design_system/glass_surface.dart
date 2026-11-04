import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import 'color_tokens.dart';
import 'effects_quality.dart';
import 'gradient_border.dart';
import 'radius_tokens.dart';

/// The selective glass wrapper (SPEC.md §9.7.3) — backdrop blur + tint +
/// border. For chrome: the top bar, modals, the session card, floating
/// panels, and the map stage's dock, HUD and play bar.
///
/// Over the map stage the surfaces are [grouped]: inside one
/// [BackdropGroup] they share a single read of the backdrop per frame
/// rather than one each (map stage proposal §7.2). Grouped surfaces must not
/// overlap; a popover above them takes its own, ungrouped glass.
///
/// Under Performance mode ([EffectsQuality]) nothing is blurred: the tint
/// alone, denser, so the surface still reads as a surface.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.xl,
    this.blurSigma = 20,
    this.grouped = false,
    this.tint = 0.62,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blurSigma;

  /// Shares the enclosing [BackdropGroup]'s backdrop.
  final bool grouped;

  /// The tint's opacity over the blur. Raised to at least 0.85 when nothing
  /// is blurred.
  final double tint;

  /// Saturation ×1.15, brightness ×0.85: what makes blurred colour behind
  /// glass read as glass rather than as fog.
  static const _vibrancy = <double>[
    0.9417, 0.0896, 0.0187, 0, 0, //
    0.0263, 1.0080, 0.0157, 0, 0, //
    0.0263, 0.0896, 0.9341, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blurs = EffectsQuality.blurs(context);
    final alpha = blurs ? tint : (tint < 0.85 ? 0.85 : tint);
    // The clip takes the plain token shape and the decoration takes the
    // gradient one: a [ShapeBorderClipper] only ever needs the outer path,
    // and clipping to the bordered shape would cut the stroke in half along
    // its own outline.
    final surface = DecoratedBox(
      decoration: ShapeDecoration(
        shape: GradientSquircleBorder(radius: radius),
        // Glass takes the wine→iris journey as a *tint* rather than a fill:
        // what is behind it has to stay readable through it, so both stops
        // are the ramp's own tones at partial alpha instead of the saturated
        // [AppGradients.brand] pair.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.surfaceContainerHigh.withValues(alpha: alpha),
            AppColors.surfaceLow.withValues(alpha: alpha * 0.8),
          ],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
    final Widget body;
    if (!blurs) {
      body = surface;
    } else if (!grouped) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: surface,
      );
    } else {
      // The stage's chrome: bounded to the surface, so the blur never
      // samples, nor spends time on, what lies outside it; and vibrant, so
      // the line's colours read through it. A LayoutBuilder only here, where
      // the box is always a fixed panel: elsewhere glass may sit in a
      // parent that asks for intrinsic sizes.
      body = LayoutBuilder(
        builder: (context, box) => BackdropFilter.grouped(
          filter: ImageFilter.compose(
            outer: const ColorFilter.matrix(_vibrancy),
            inner: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
              bounds: Offset.zero & box.biggest,
            ),
          ),
          child: surface,
        ),
      );
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppRadii.squircle(radius)),
      child: body,
    );
  }
}
