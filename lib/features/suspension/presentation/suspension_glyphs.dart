/// Suspension's glyphs (suspension proposal §6): drawn on the iconography
/// plan's 24-unit grid with a 2-unit round stroke, so they sit beside
/// Material's outlined icons without looking borrowed. Every one is paired
/// with a label or an `AppTooltip` where it is used.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../domain/strikes.dart';

enum SuspensionGlyphKind {
  /// The screen itself: a spring around a damper body.
  coilover,

  /// A car side over the ground with a vertical arrow.
  rideHeight,

  /// A car side with a spark under the floor.
  strike,

  /// A stop block on a rod.
  packers,

  /// A road running ahead.
  straight,

  /// A pedal with its bar.
  braking,

  /// A curved arrow.
  corner,

  /// Braking into a corner: the pedal and the curve together.
  brakingCorner,

  /// A striped strip, ink and paper.
  kerb,

  /// Two lane edges with a dot between: where on the road.
  line,

  /// A U-shaped bar: the anti-roll bar.
  antiRollBar,

  /// A damper body with its rod.
  damper;

  static SuspensionGlyphKind ofPhase(StrikePhase phase) => switch (phase) {
    StrikePhase.straight => straight,
    StrikePhase.braking => braking,
    StrikePhase.corner => corner,
    StrikePhase.brakingCorner => brakingCorner,
  };
}

class SuspensionGlyph extends StatelessWidget {
  const SuspensionGlyph(
    this.kind, {
    super.key,
    this.size = 18,
    this.color,
    this.semanticLabel,
  });

  final SuspensionGlyphKind kind;
  final double size;

  /// Defaults to the ambient icon colour.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? Colors.white;
    final glyph = CustomPaint(
      size: Size.square(size),
      painter: SuspensionGlyphPainter(kind, ink),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(label: label, image: true, child: glyph);
  }
}

/// Paints one glyph into its box. Public so map and chart painters can draw
/// the same marks onto their canvases.
class SuspensionGlyphPainter extends CustomPainter {
  const SuspensionGlyphPainter(this.kind, this.color);

  final SuspensionGlyphKind kind;
  final Color color;

  /// Draws [kind] centred on [centre], [size] across.
  static void paintAt(
    Canvas canvas,
    SuspensionGlyphKind kind,
    Offset centre,
    double size,
    Color color,
  ) {
    canvas
      ..save()
      ..translate(centre.dx - size / 2, centre.dy - size / 2);
    SuspensionGlyphPainter(kind, color).paint(canvas, Size.square(size));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 24;
    canvas
      ..save()
      ..scale(u);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    switch (kind) {
      case SuspensionGlyphKind.coilover:
        _coilover(canvas, stroke);
      case SuspensionGlyphKind.rideHeight:
        _carSide(canvas, stroke, top: 4);
        canvas
          ..drawLine(const Offset(3, 21), const Offset(21, 21), stroke)
          ..drawLine(const Offset(12, 13.5), const Offset(12, 19), stroke);
        _arrowHead(canvas, stroke, const Offset(12, 13.5), up: true);
        _arrowHead(canvas, stroke, const Offset(12, 19), up: false);
      case SuspensionGlyphKind.strike:
        _carSide(canvas, stroke, top: 4);
        canvas.drawLine(const Offset(3, 20), const Offset(21, 20), stroke);
        // The spark: short rays out of where the floor meets the ground.
        for (final a in const [-2.4, -1.57, -0.74]) {
          final dir = Offset(math.cos(a), math.sin(a));
          canvas.drawLine(
            const Offset(12, 17.5) + dir * 1.6,
            const Offset(12, 17.5) + dir * 3.6,
            stroke..strokeWidth = 1.6,
          );
        }
        stroke.strokeWidth = 2;
        canvas.drawCircle(const Offset(12, 17.5), 1.1, fill);
      case SuspensionGlyphKind.packers:
        canvas
          ..drawLine(const Offset(12, 3), const Offset(12, 12), stroke)
          ..drawRRect(
            RRect.fromLTRBR(7.5, 12, 16.5, 17, const Radius.circular(1.5)),
            fill,
          )
          ..drawLine(const Offset(5, 21), const Offset(19, 21), stroke)
          ..drawLine(const Offset(12, 17), const Offset(12, 21), stroke);
      case SuspensionGlyphKind.straight:
        canvas
          ..drawLine(const Offset(6, 21), const Offset(9, 3), stroke)
          ..drawLine(const Offset(18, 21), const Offset(15, 3), stroke)
          ..drawLine(const Offset(12, 18), const Offset(12, 8), stroke);
        _arrowHead(canvas, stroke, const Offset(12, 8), up: true);
      case SuspensionGlyphKind.braking:
        _pedal(canvas, stroke, fill, const Offset(0, 0));
      case SuspensionGlyphKind.corner:
        _curve(canvas, stroke, const Offset(0, 0), 1);
      case SuspensionGlyphKind.brakingCorner:
        canvas
          ..save()
          ..translate(-3, 2)
          ..scale(0.72);
        _pedal(canvas, stroke..strokeWidth = 2.6, fill, const Offset(0, 0));
        canvas.restore();
        canvas
          ..save()
          ..translate(9, -1)
          ..scale(0.62);
        _curve(canvas, stroke..strokeWidth = 3, const Offset(0, 0), 1);
        canvas.restore();
      case SuspensionGlyphKind.kerb:
        final strip = RRect.fromLTRBR(3, 8, 21, 16, const Radius.circular(2));
        canvas.drawRRect(strip, stroke);
        canvas
          ..save()
          ..clipRRect(strip);
        for (var x = 3.0; x < 21; x += 6) {
          canvas.drawRect(Rect.fromLTWH(x, 8, 3, 8), fill);
        }
        canvas.restore();
      case SuspensionGlyphKind.line:
        canvas
          ..drawLine(const Offset(5, 3), const Offset(5, 21), stroke)
          ..drawLine(const Offset(19, 3), const Offset(19, 21), stroke);
        final dash = Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (var y = 4.0; y < 21; y += 5) {
          canvas.drawLine(Offset(12, y), Offset(12, y + 2), dash);
        }
        canvas.drawCircle(const Offset(15.5, 12), 2.4, fill);
      case SuspensionGlyphKind.antiRollBar:
        final bar = Path()
          ..moveTo(4, 5)
          ..lineTo(4, 15)
          ..quadraticBezierTo(4, 19, 8, 19)
          ..lineTo(16, 19)
          ..quadraticBezierTo(20, 19, 20, 15)
          ..lineTo(20, 5);
        canvas
          ..drawPath(bar, stroke)
          ..drawCircle(const Offset(4, 5), 1.6, fill)
          ..drawCircle(const Offset(20, 5), 1.6, fill);
      case SuspensionGlyphKind.damper:
        canvas
          ..drawLine(const Offset(12, 2.5), const Offset(12, 9), stroke)
          ..drawRRect(
            RRect.fromLTRBR(8, 9, 16, 20, const Radius.circular(2)),
            stroke,
          )
          ..drawLine(const Offset(9, 9), const Offset(15, 9), stroke)
          ..drawLine(const Offset(12, 20), const Offset(12, 22), stroke);
    }
    canvas.restore();
  }

  static void _coilover(Canvas canvas, Paint stroke) {
    // Mounts top and bottom, the damper body down the middle, the spring
    // wound around it.
    canvas
      ..drawLine(const Offset(8, 2.5), const Offset(16, 2.5), stroke)
      ..drawLine(const Offset(8, 21.5), const Offset(16, 21.5), stroke)
      ..drawLine(const Offset(12, 2.5), const Offset(12, 21.5), stroke);
    final spring = Path()..moveTo(7, 5.5);
    const turns = 5;
    for (var i = 0; i < turns; i++) {
      final y = 5.5 + i * 2.6;
      spring
        ..lineTo(17, y + 1.3)
        ..lineTo(7, y + 2.6);
    }
    canvas.drawPath(spring, stroke..strokeWidth = 1.7);
    stroke.strokeWidth = 2;
  }

  static void _carSide(Canvas canvas, Paint stroke, {required double top}) {
    final body = Path()
      ..moveTo(2.5, top + 10)
      ..lineTo(2.5, top + 7)
      ..quadraticBezierTo(3, top + 5, 6, top + 4.5)
      ..lineTo(9, top + 1.5)
      ..lineTo(15.5, top + 1.5)
      ..lineTo(19, top + 4.5)
      ..quadraticBezierTo(21.5, top + 5, 21.5, top + 7.5)
      ..lineTo(21.5, top + 10)
      ..close();
    canvas
      ..drawPath(body, stroke)
      ..drawCircle(Offset(7, top + 10), 2, stroke)
      ..drawCircle(Offset(17, top + 10), 2, stroke);
  }

  static void _pedal(Canvas canvas, Paint stroke, Paint fill, Offset at) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..drawLine(const Offset(14, 3), const Offset(10.5, 15), stroke)
      ..drawRRect(
        RRect.fromLTRBR(6, 13, 16, 18.5, const Radius.circular(2)),
        fill,
      )
      ..drawLine(const Offset(4, 21.5), const Offset(20, 21.5), stroke)
      ..restore();
  }

  static void _curve(Canvas canvas, Paint stroke, Offset at, double s) {
    final arc = Path()
      ..moveTo(6, 21)
      ..lineTo(6, 14)
      ..quadraticBezierTo(6, 6, 15, 6);
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..drawPath(arc, stroke)
      ..drawLine(const Offset(15, 6), const Offset(11.5, 2.5), stroke)
      ..drawLine(const Offset(15, 6), const Offset(11.5, 9.5), stroke)
      ..restore();
  }

  static void _arrowHead(
    Canvas canvas,
    Paint stroke,
    Offset tip, {
    required bool up,
  }) {
    final d = up ? 2.8 : -2.8;
    canvas
      ..drawLine(tip, tip + Offset(-2.6, d), stroke)
      ..drawLine(tip, tip + Offset(2.6, d), stroke);
  }

  @override
  bool shouldRepaint(SuspensionGlyphPainter old) =>
      old.kind != kind || old.color != color;
}
