/// The shared scrub cursor (SPEC.md §7.1, §9.5).
///
/// Its own painter, and its own layer above the trace, because it changes on
/// every pointer move while the trace under it changes only when the data or
/// the viewport does. Both reference apps put a floating value readout on the
/// cursor of every chart; keeping that readout in the painter anchors it to
/// the exact pixel rather than to a widget that would relayout as the digits
/// change width.
library;

import 'package:flutter/material.dart';

import 'chart_painting.dart';

class CursorPainter extends CustomPainter {
  const CursorPainter({
    required this.cursor,
    required this.geometry,
    required this.palette,
    this.value,
    this.readout,
  });

  /// Cursor position in domain units, or null when the pointer is away.
  final double? cursor;

  final ChartGeometry geometry;
  final ChartPalette palette;

  /// The series value under the cursor, used to place the dot. Null for a
  /// panel with nothing to read there.
  final double? value;

  /// Preformatted readout, e.g. `184.2 km/h`.
  final String? readout;

  @override
  void paint(Canvas canvas, Size size) {
    final at = cursor;
    if (at == null) return;
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    if (!scaled.viewport.contains(at)) return;

    final x = scaled.x(at);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = palette.cursor
        ..strokeWidth = 1,
    );

    if (value != null) {
      final y = scaled.y(value!);
      // A surface-coloured ring around the dot so it stays legible where it
      // sits on top of the trace's own fill.
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = palette.surface);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = palette.series);
    }

    final text = readout;
    if (text == null) return;

    final style = palette.labelStyle.copyWith(color: palette.axisText);
    final measure = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    const padding = 5.0;
    final width = measure.width + padding * 2;
    measure.dispose();

    // Flips to the left of the cursor near the right edge so the readout is
    // never clipped at the end of a lap — which is exactly where a user
    // scrubs to compare a finish.
    final left = x + 8 + width <= size.width ? x + 8 : x - 8 - width;
    final rect = Rect.fromLTWH(left, 4, width, style.fontSize! + padding * 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = palette.surface.withValues(alpha: 0.92),
    );
    paintText(canvas, text, style, rect.topLeft + const Offset(padding, padding));
  }

  @override
  bool shouldRepaint(CursorPainter old) =>
      old.cursor != cursor ||
      old.value != value ||
      old.readout != readout ||
      old.geometry != geometry ||
      old.palette.series != palette.series;
}

/// Vertical markers at fixed domain positions — sector boundaries on a trace
/// panel (SPEC.md §8.3, §8.5).
///
/// Drawn in the cursor layer rather than the trace layer only because both
/// are cheap overlays; they change with the lap, not with the pointer.
class DomainMarkerPainter extends CustomPainter {
  const DomainMarkerPainter({
    required this.markers,
    required this.geometry,
    required this.palette,
  });

  /// `(position, label)` in domain units.
  final List<(double, String)> markers;
  final ChartGeometry geometry;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (markers.isEmpty) return;
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    final paint = Paint()
      ..color = palette.axisText.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (final (position, label) in markers) {
      if (!scaled.viewport.contains(position)) continue;
      final x = scaled.x(position);
      // Dashed, so a sector boundary never reads as the scrub cursor.
      for (var y = 0.0; y < size.height; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, size.height)),
            paint);
      }
      if (label.isEmpty) continue;
      paintText(
        canvas,
        label,
        palette.labelStyle.copyWith(color: palette.axisText.withValues(alpha: 0.7)),
        Offset(x + 3, 2),
      );
    }
  }

  @override
  bool shouldRepaint(DomainMarkerPainter old) =>
      old.geometry != geometry || old.markers != markers;
}
