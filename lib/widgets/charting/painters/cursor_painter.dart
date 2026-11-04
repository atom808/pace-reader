/// The shared scrub cursor (SPEC.md §7.1, §9.5).
///
/// Its own painter, and its own layer above the trace, because it changes on
/// every pointer move while the trace under it changes only when the data or
/// the viewport does. Both reference apps put a floating value readout on the
/// cursor of every chart; keeping that readout in the painter anchors it to
/// the exact pixel rather than to a widget that would relayout as the digits
/// change width.
library;

import 'package:material_ui/material_ui.dart';

import 'chart_painting.dart';

class CursorPainter extends CustomPainter {
  const CursorPainter({
    required this.cursor,
    required this.geometry,
    required this.palette,
    this.probe,
    this.value,
    this.probeValue,
    this.referenceValue,
    this.readout,
  });

  /// The playhead, in domain units: a solid line and the series' dot. Null
  /// before anything has placed it.
  final double? cursor;

  /// The probe — where the pointer is reading — in domain units: a faint
  /// hairline that moves nothing (map stage proposal §5). Null when the
  /// pointer is elsewhere.
  final double? probe;

  final ChartGeometry geometry;
  final ChartPalette palette;

  /// The series value at the playhead, used to place its dot. Null for a
  /// panel with nothing to read there.
  final double? value;

  /// The series value at the probe, for its smaller dot.
  final double? probeValue;

  /// The reference lap's value where the panel is reading — the probe, else
  /// the playhead — drawn as a ring rather than a dot: hollow like its
  /// dotted line is broken, so the two marks pair with the two traces
  /// without a legend.
  final double? referenceValue;

  /// Preformatted readout of where the panel is reading, e.g. `1 234 m`.
  final String? readout;

  @override
  void paint(Canvas canvas, Size size) {
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    bool shows(double? at) => at != null && scaled.viewport.contains(at);

    final playhead = cursor;
    if (shows(playhead)) {
      final x = scaled.x(playhead!);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = palette.cursor
          ..strokeWidth = 1,
      );
      if (value != null) {
        // A surface-coloured ring around the dot so it stays legible where
        // it sits on top of the trace's own fill.
        final at = Offset(x, scaled.y(value!));
        canvas.drawCircle(at, 4.5, Paint()..color = palette.surface);
        canvas.drawCircle(at, 3, Paint()..color = palette.series);
      }
    }

    final hover = probe;
    if (shows(hover)) {
      final x = scaled.x(hover!);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = palette.cursor.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      if (probeValue != null) {
        final at = Offset(x, scaled.y(probeValue!));
        canvas.drawCircle(at, 3.5, Paint()..color = palette.surface);
        canvas.drawCircle(
          at,
          2.2,
          Paint()..color = palette.series.withValues(alpha: 0.8),
        );
      }
    }

    final reading = shows(hover) ? hover : (shows(playhead) ? playhead : null);
    if (reading == null) return;
    final x = scaled.x(reading);

    if (referenceValue != null) {
      final at = Offset(x, scaled.y(referenceValue!));
      canvas.drawCircle(at, 4, Paint()..color = palette.surface);
      canvas.drawCircle(
        at,
        3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = palette.reference,
      );
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

    // Flips to the left of the line near the right edge so the readout is
    // never clipped at the end of a lap — which is exactly where a user
    // reads a finish.
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
      old.probe != probe ||
      old.value != value ||
      old.probeValue != probeValue ||
      old.referenceValue != referenceValue ||
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

    final shown = [
      for (final m in markers)
        if (scaled.viewport.contains(m.$1)) m,
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final style =
        palette.labelStyle.copyWith(color: palette.axisText.withValues(alpha: 0.7));
    final lineHeight = (style.fontSize ?? 10) * 1.3;
    // Names sit along the foot of the panel, clear of the title chip in its
    // top left. Each line's right edge so far: a name that would print over
    // the one before it rises a line (a strike beside a sector line).
    final lineEnds = <double>[];
    for (final (position, label) in shown) {
      final x = scaled.x(position);
      // Dashed, so a sector boundary never reads as the scrub cursor.
      for (var y = 0.0; y < size.height; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 4).clamp(0, size.height)),
            paint);
      }
      if (label.isEmpty) continue;
      var line = 0;
      while (line < lineEnds.length && x + 3 < lineEnds[line] + 4) {
        line++;
      }
      final text =
          paintText(canvas, label, style,
              Offset(x + 3, size.height - 2 - (line + 1) * lineHeight));
      if (line == lineEnds.length) {
        lineEnds.add(x + 3 + text.width);
      } else {
        lineEnds[line] = x + 3 + text.width;
      }
    }
  }

  @override
  bool shouldRepaint(DomainMarkerPainter old) =>
      old.geometry != geometry || old.markers != markers;
}
