import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'gradient_border.dart';
import 'radius_tokens.dart';

/// Base card applying the squircle shape + edge + fill + padding tokens
/// (SPEC.md §9.7.6), so every card in the app shares one shape source
/// instead of each screen picking its own.
///
/// A card is three things at once and all three come from the tokens: a
/// [AppGradients.surfaceCard] interior lit from the top, a
/// [GradientSquircleBorder] edge lit from the top-left, and a drop shadow
/// under it. On the near-black base of §9.7.1's surface ramp none of the
/// three is decoration — a flat container a few percent off the background
/// is legible but never reads as an object, and the panelled feel the whole
/// app is arranged around depends on the panels looking like panels.
class SquircleCard extends StatelessWidget {
  const SquircleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.lg,
    this.color,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// A flat fill instead of the standard interior wash — for the cards that
  /// carry a semantic colour (a notice, an error) rather than a surface.
  final Color? color;

  /// Overrides the edge, for a card that is currently the subject:
  /// [AppGradients.hairlineStrong].
  final Gradient? border;

  /// Cast well below the card rather than tight around it: a tight shadow on
  /// a near-black background reads as a smudge on the border, a wide soft one
  /// reads as height.
  static const _shadow = [
    BoxShadow(color: Color(0x8C000000), blurRadius: 28, offset: Offset(0, 10)),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: GradientSquircleBorder(
          radius: radius,
          gradient: border ?? AppGradients.hairline,
        ),
        color: color,
        gradient: color == null ? AppGradients.surfaceCard : null,
        shadows: _shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
