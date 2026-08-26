import 'dart:ui' show ClipOp;

import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';

/// The text-field outline, in the app's own shape (SPEC.md §9.7.2).
///
/// §9.7.2 makes [ContinuousRectangleBorder] "the default shape for buttons,
/// **inputs**, and cards", but an [InputDecoration] will only take an
/// [InputBorder], and the only outlined one Material ships —
/// [OutlineInputBorder] — is a circular-arc [RRect]. So every text field in
/// the app was drawing a different corner from every button and card next to
/// it: the theme's `OutlineInputBorder(borderRadius: AppRadii.md)` matched the
/// token's *number* while drawing the wrong *curve*, and any field that
/// spelled out a bare `OutlineInputBorder()` — as the events filter did —
/// silently fell back to Material's 4px default and matched neither.
///
/// This is the same squircle the rest of the design system draws, wearing an
/// [InputBorder]'s interface, and it strokes with a [Gradient] so a field's
/// edge carries the same wine→iris light as a card's ([AppGradients]).
@immutable
class SquircleInputBorder extends InputBorder {
  const SquircleInputBorder({
    super.borderSide = const BorderSide(width: 1.25),
    this.radius = AppRadii.md,
    this.gradient = AppGradients.hairline,
  });

  final double radius;

  /// Stroked instead of [borderSide]'s colour when set. The side still
  /// carries the *width*, which is what [InputDecorator] animates between
  /// the enabled and focused borders.
  final Gradient? gradient;

  ShapeBorder get _shape => AppRadii.squircle(radius);

  /// True so [InputDecorator] lays the field out with room for the border on
  /// every side and floats a label into the top edge, rather than treating
  /// this as an underline.
  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect.deflate(borderSide.width),
          textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  SquircleInputBorder copyWith({
    BorderSide? borderSide,
    double? radius,
    Gradient? gradient,
  }) {
    return SquircleInputBorder(
      borderSide: borderSide ?? this.borderSide,
      radius: radius ?? this.radius,
      gradient: gradient ?? this.gradient,
    );
  }

  @override
  SquircleInputBorder scale(double t) => SquircleInputBorder(
        borderSide: borderSide.scale(t),
        radius: radius * t,
        gradient: gradient,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SquircleInputBorder) {
      return SquircleInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        radius: a.radius + (radius - a.radius) * t,
        gradient: Gradient.lerp(a.gradient, gradient, t) ?? gradient,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SquircleInputBorder) return b.lerpFrom(this, 1 - t);
    return super.lerpTo(b, t);
  }

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    if (borderSide.style == BorderStyle.none || rect.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderSide.width;
    if (gradient case final gradient?) {
      paint.shader = gradient.createShader(rect);
    } else {
      paint.color = borderSide.color;
    }
    final path = _shape.getOuterPath(
      rect.deflate(borderSide.width / 2),
      textDirection: textDirection,
    );

    // A floating label sits *in* the top edge, so the edge has to open for
    // it. [OutlineInputBorder] builds the gap into its path; a continuous
    // corner has no such seam to split on, so the gap is clipped out of the
    // top strip instead — the only place a label ever floats, and the only
    // place the difference is visible.
    if (gapStart == null || gapExtent <= 0 || gapPercentage <= 0) {
      canvas.drawPath(path, paint);
      return;
    }
    const padding = 4.0;
    final gap = Rect.fromLTWH(
      gapStart - padding,
      rect.top - borderSide.width,
      gapExtent * gapPercentage + padding * 2,
      borderSide.width * 3,
    );
    canvas
      ..save()
      ..clipRect(gap, clipOp: ClipOp.difference)
      ..drawPath(path, paint)
      ..restore();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SquircleInputBorder &&
          other.borderSide == borderSide &&
          other.radius == radius &&
          other.gradient == gradient);

  @override
  int get hashCode => Object.hash(borderSide, radius, gradient);
}
