import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';

/// A continuous-squircle outline stroked with a [Gradient] (SPEC.md §9.7.2).
///
/// [ContinuousRectangleBorder] takes a [BorderSide], and a `BorderSide` takes
/// a single [Color] — so the shape tokens alone can draw a squircle *or* a
/// gradient edge, never both. This is the missing half: it borrows the token
/// shape for its geometry and does its own stroking, which keeps one
/// definition of "what a corner looks like" while letting the edge carry
/// [AppGradients]' wine→iris light.
///
/// It is a [ShapeBorder] rather than a decoration so it drops into everything
/// that already takes one — `ShapeDecoration.shape`, `Material.shape`,
/// `ShapeBorderClipper` — and so the same object both clips a container and
/// draws its edge.
@immutable
class GradientSquircleBorder extends ShapeBorder {
  const GradientSquircleBorder({
    this.radius = AppRadii.lg,
    this.gradient = AppGradients.hairline,
    this.width = 1.25,
  });

  final double radius;
  final Gradient gradient;
  final double width;

  ShapeBorder get _shape => AppRadii.squircle(radius);

  /// The stroke is inset, not overhanging, so a container's content box is
  /// the inside of the edge — the same contract [ContinuousRectangleBorder]
  /// has with a `BorderSide`.
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect.deflate(width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (width <= 0 || rect.isEmpty) return;
    // Stroked down the centre of a half-width-deflated path: a stroke centred
    // on the outer path would spill half its weight outside the shape, where
    // an antialiased clip then eats it and leaves the edge looking thinner on
    // the corners than on the straights.
    final path = _shape.getOuterPath(
      rect.deflate(width / 2),
      textDirection: textDirection,
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        // Shaded against the full rect rather than the deflated one so the
        // gradient's corner stops land on the corners.
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  ShapeBorder scale(double t) => GradientSquircleBorder(
        radius: radius * t,
        gradient: gradient,
        width: width * t,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is GradientSquircleBorder) {
      return GradientSquircleBorder(
        radius: a.radius + (radius - a.radius) * t,
        gradient: Gradient.lerp(a.gradient, gradient, t) ?? gradient,
        width: a.width + (width - a.width) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is GradientSquircleBorder) return b.lerpFrom(this, 1 - t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GradientSquircleBorder &&
          other.radius == radius &&
          other.gradient == gradient &&
          other.width == width);

  @override
  int get hashCode => Object.hash(radius, gradient, width);
}
