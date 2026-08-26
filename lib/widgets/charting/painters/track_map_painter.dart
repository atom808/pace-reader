/// The 2D track map (SPEC.md §8.5, §9.5).
///
/// A painter rather than a chart library, for the reason §9.5 draws the whole
/// hybrid boundary on: the map shares one scrub cursor and one axis with the
/// trace panels, and that cross-panel behaviour is precisely what a
/// general-purpose chart library isn't built around.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../projection.dart';
import '../track_path.dart';
import '../value_ramp.dart';
import 'chart_painting.dart';

class TrackMapPainter extends CustomPainter {
  const TrackMapPainter({
    required this.path,
    required this.ramp,
    required this.palette,
    this.cursorIndex,
    this.markers = const [],
    this.strokeWidth = 4.0,
  });

  final TrackPath path;
  final ValueRamp ramp;
  final ChartPalette palette;

  /// Point the shared cursor is over, or null when the pointer is away.
  final int? cursorIndex;

  /// `(point index, label)` — sector boundaries and the start/finish line.
  final List<(int, String)> markers;

  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final fit = path.projection.fitInto(Offset.zero & size, padding: 18);
    final points = [
      for (final metres in path.projection.points) fit.toPixels(metres),
    ];

    // An unlit under-stroke so the circuit still reads as a closed loop where
    // the colouring value is at its darkest — the pit straight of a lap
    // coloured by brake pressure is otherwise nearly invisible.
    final base = Path()..addPolygon(points, false);
    canvas.drawPath(
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = palette.grid.withValues(alpha: 0.5),
    );

    // One segment per sample pair. At 10 Hz a lap is a few hundred segments,
    // which is well inside a frame budget and avoids the banding a
    // coarser run-length grouping would introduce at speed transitions.
    final span = path.valueRange.span;
    final segment = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      final mid = (path.values[i] + path.values[i - 1]) / 2;
      final t = span == 0 ? 0.5 : (mid - path.valueRange.min) / span;
      segment.color = path.hasColouring ? ramp.at(t) : palette.series;
      canvas.drawLine(points[i - 1], points[i], segment);
    }

    for (final (index, label) in markers) {
      if (index < 0 || index >= points.length) continue;
      _paintMarker(canvas, points, index, label);
    }

    final cursor = cursorIndex;
    if (cursor != null && cursor >= 0 && cursor < points.length) {
      final at = points[cursor];
      canvas.drawCircle(at, 7, Paint()..color = palette.surface);
      canvas.drawCircle(at, 5, Paint()..color = palette.cursor);
    }
  }

  /// A tick across the track, plus its label.
  ///
  /// Perpendicular to the local direction of travel rather than vertical, so
  /// a sector boundary reads as a line across the circuit wherever on it the
  /// boundary happens to fall.
  void _paintMarker(
    Canvas canvas,
    List<Offset> points,
    int index,
    String label,
  ) {
    final before = points[math.max(index - 1, 0)];
    final after = points[math.min(index + 1, points.length - 1)];
    var direction = after - before;
    if (direction.distance < 1e-6) direction = const Offset(1, 0);
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final at = points[index];
    const half = 9.0;

    canvas.drawLine(
      at - normal * half,
      at + normal * half,
      Paint()
        ..color = palette.axisText
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    if (label.isEmpty) return;
    paintText(
      canvas,
      label,
      palette.labelStyle,
      at + normal * (half + 3) - const Offset(6, 7),
    );
  }

  @override
  bool shouldRepaint(TrackMapPainter old) =>
      !identical(old.path, path) ||
      old.cursorIndex != cursorIndex ||
      old.markers != markers ||
      old.palette.series != palette.series;
}

/// Scale reference for the map, in metres.
///
/// Worth drawing because the projection's metric frame is real (see
/// [TrackProjection]) even though its coordinates are not geographic — the
/// bar says how big the circuit is, which is the one absolute fact the map
/// can honestly report.
class TrackScalePainter extends CustomPainter {
  const TrackScalePainter({required this.path, required this.palette});

  final TrackPath path;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final fit = path.projection.fitInto(Offset.zero & size, padding: 18);
    if (fit.scale <= 0) return;

    // Longest round distance that fits in a quarter of the panel.
    const candidates = [50.0, 100.0, 200.0, 250.0, 500.0, 1000.0];
    var metres = candidates.first;
    for (final candidate in candidates) {
      if (candidate * fit.scale <= size.width / 4) metres = candidate;
    }
    final length = metres * fit.scale;
    final y = size.height - 12;
    final paint = Paint()
      ..color = palette.axisText.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(12, y), Offset(12 + length, y), paint);
    canvas.drawLine(Offset(12, y - 3), Offset(12, y + 3), paint);
    canvas.drawLine(
        Offset(12 + length, y - 3), Offset(12 + length, y + 3), paint);
    paintText(canvas, '${metres.toStringAsFixed(0)} m', palette.labelStyle,
        Offset(12, y - 17));
  }

  @override
  bool shouldRepaint(TrackScalePainter old) => !identical(old.path, path);
}
