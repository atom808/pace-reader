/// The 2D track map (SPEC.md §8.5, §9.5).
///
/// A painter rather than a chart library, for the reason §9.5 draws the whole
/// hybrid boundary on: the map shares one scrub cursor and one axis with the
/// trace panels, and that cross-panel behaviour is precisely what a
/// general-purpose chart library isn't built around.
///
/// Two layers. [TrackMapPainter] draws what changes only with the lap, the
/// axis or the selection — the paths, the markers, the casing — and
/// [TrackCursorPainter] draws what moves with the pointer. A scrub repaints
/// the second alone: the fit and the projection never change under it
/// (comparison proposal §6).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../projection.dart';
import '../track_path.dart';
import '../value_ramp.dart';
import 'chart_painting.dart';

/// The fit every layer of one map shares: [view] when the map shows part of
/// the lap, or a stretch of two laps' combined extent, and [path]'s own
/// bounds otherwise.
TrackFit trackMapFit(TrackPath path, Rect? view, Size size) => TrackFit.of(
  view ?? path.projection.boundsMetres,
  Offset.zero & size,
  padding: 18,
);

/// A numbered stretch of the lap, labelled beside the path at [station]
/// (comparison proposal §6: the numbered segments, the worst one ringed).
class TrackLabel {
  const TrackLabel({
    required this.station,
    required this.text,
    this.ringed = false,
  });

  /// `Lap Dist` the label sits beside.
  final double station;
  final String text;

  /// Ringed in ink: the stretch Base loses most in.
  final bool ringed;

  @override
  bool operator ==(Object other) =>
      other is TrackLabel &&
      other.station == station &&
      other.text == text &&
      other.ringed == ringed;

  @override
  int get hashCode => Object.hash(station, text, ringed);
}

/// What a [TrackMark] marks.
enum TrackMarkShape {
  /// ◆ where a lap starts braking.
  diamond,

  /// • a lap's slowest point.
  dot,

  /// ✱ a recorded contact.
  contact,
}

/// A finding's place on the map (comparison proposal §6, §8): filled for
/// Base, hollow for the Target — where both laps share one frame at one
/// point of the lap, hollow means "Target".
class TrackMark {
  const TrackMark({required this.at, required this.shape, this.hollow = false});

  /// Where, in the projection's metres.
  final Offset at;
  final TrackMarkShape shape;
  final bool hollow;

  @override
  bool operator ==(Object other) =>
      other is TrackMark &&
      other.at == at &&
      other.shape == shape &&
      other.hollow == hollow;

  @override
  int get hashCode => Object.hash(at, shape, hollow);
}

class TrackMapPainter extends CustomPainter {
  const TrackMapPainter({
    required this.path,
    required this.ramp,
    required this.palette,
    this.markers = const [],
    this.strokeWidth = 4.0,
    this.reference,
    this.ink,
    this.view,
    this.overview,
    this.highlight,
    this.labels = const [],
    this.marks = const [],
  });

  final TrackPath path;
  final ValueRamp ramp;
  final ChartPalette palette;

  /// `(point index, label)` — sector boundaries and the start/finish line.
  final List<(int, String)> markers;

  final double strokeWidth;

  /// A second lap in [path]'s frame — Compare's Target — drawn dotted in
  /// [ink] over the first (comparison proposal §8: Base keeps the ramp, the
  /// Target is neutral ink in its pattern, never a hue).
  final TrackPath? reference;

  /// The ink: the Target's line, the casing and the ringed label.
  final Color? ink;

  /// What the map is fitted to, in metres; null for [path]'s own bounds.
  final Rect? view;

  /// The whole lap's extent. When [view] shows less, an inset keeps the
  /// whole lap in sight, with the part shown boxed.
  final Rect? overview;

  /// A stretch of `Lap Dist` cased in ink under the path: the selected
  /// segment.
  final (double, double)? highlight;

  final List<TrackLabel> labels;

  /// The selected stretch's findings, in [ink] over the paths.
  final List<TrackMark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final fit = trackMapFit(path, view, size);
    final points = [
      for (final metres in path.projection.points) fit.toPixels(metres),
    ];
    final ink = this.ink ?? palette.cursor;

    if (view != null) canvas.clipRect(Offset.zero & size);

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

    final cased = highlight == null ? null : _stretch(fit, highlight!);
    if (cased != null) {
      // Under the path, in ink: which stretch is selected, without dimming
      // the rest — on this map lightness is magnitude (§9.7.1), and a dimmed
      // stretch would read as slow (comparison proposal §6).
      canvas.drawPath(
        cased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = ink.withValues(alpha: 0.55),
      );
    }

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

    final reference = this.reference;
    if (reference != null && reference.length > 1) {
      canvas.drawPath(
        dashedPolyline(
          [
            for (final metres in reference.projection.points)
              fit.toPixels(metres),
          ],
          dash: 3,
          gap: 3,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..color = ink.withValues(alpha: 0.7),
      );
    }

    for (final (index, label) in markers) {
      if (index < 0 || index >= points.length) continue;
      _paintMarker(canvas, points, index, label);
    }

    for (final mark in marks) {
      _paintMark(canvas, fit.toPixels(mark.at), mark, ink);
    }

    final centre = fit.toPixels(path.projection.boundsMetres.center);
    for (final label in labels) {
      _paintLabel(
        canvas,
        fit,
        centre,
        Offset.zero & size,
        label,
        ink,
        radius: 8,
      );
    }

    final overview = this.overview;
    if (view != null && overview != null && view != overview) {
      _paintInset(canvas, size, overview, ink);
    }
  }

  /// One finding: ink on a surface halo, so it reads over any ramp colour.
  void _paintMark(Canvas canvas, Offset at, TrackMark mark, Color ink) {
    final shape = switch (mark.shape) {
      TrackMarkShape.diamond =>
        Path()
          ..moveTo(at.dx, at.dy - 6)
          ..lineTo(at.dx + 6, at.dy)
          ..lineTo(at.dx, at.dy + 6)
          ..lineTo(at.dx - 6, at.dy)
          ..close(),
      TrackMarkShape.dot =>
        Path()..addOval(Rect.fromCircle(center: at, radius: 4.5)),
      TrackMarkShape.contact => _star(at, outer: 7, inner: 3),
    };
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round
        ..color = palette.surface,
    );
    canvas.drawPath(
      shape,
      Paint()..color = mark.hollow ? palette.surface : ink,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = ink,
    );
  }

  static Path _star(Offset at, {required double outer, required double inner}) {
    final star = Path();
    for (var k = 0; k < 12; k++) {
      final r = k.isEven ? outer : inner;
      final a = -math.pi / 2 + k * math.pi / 6;
      final p = at + Offset(math.cos(a), math.sin(a)) * r;
      k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    return star..close();
  }

  /// [stretch]'s part of the path in pixels, both ends interpolated.
  Path? _stretch(TrackFit fit, (double, double) stretch) {
    final stations = path.stations;
    if (stations == null) return null;
    final (from, to) = stretch;
    final points = path.projection.points;
    final start = path.positionAtStation(from);
    final end = path.positionAtStation(to);
    final inside = [
      if (start != null) fit.toPixels(start),
      for (var i = 0; i < path.length; i++)
        if (stations[i] > from && stations[i] < to) fit.toPixels(points[i]),
      if (end != null) fit.toPixels(end),
    ];
    if (inside.length < 2) return null;
    return Path()..addPolygon(inside, false);
  }

  /// A number in a disc beside the path, pushed away from the circuit's
  /// middle so it sits outside the loop rather than across it — or inside,
  /// where outside would leave [area].
  void _paintLabel(
    Canvas canvas,
    TrackFit fit,
    Offset centre,
    Rect area,
    TrackLabel label,
    Color ink, {
    required double radius,
    double gap = 12,
    double fontSize = 10,
  }) {
    final at = path.positionAtStation(label.station);
    if (at == null) return;
    final before = path.positionAtStation(label.station - 5) ?? at;
    final after = path.positionAtStation(label.station + 5) ?? at;
    var direction = fit.toPixels(after) - fit.toPixels(before);
    if (direction.distance < 1e-6) direction = const Offset(1, 0);
    final unit = direction / direction.distance;
    var normal = Offset(-unit.dy, unit.dx);
    final pixel = fit.toPixels(at);
    // A stretch off the fitted map is numbered in the inset, not pinned to
    // the edge nearest it.
    if (!area.contains(pixel)) return;
    final outward = pixel - centre;
    if (normal.dx * outward.dx + normal.dy * outward.dy < 0) normal = -normal;
    final room = area.deflate(radius + 1);
    var disc = pixel + normal * (gap + radius);
    if (!room.contains(disc)) {
      final inside = pixel - normal * (gap + radius);
      disc = room.contains(inside)
          ? inside
          : Offset(
              disc.dx.clamp(room.left, room.right),
              disc.dy.clamp(room.top, room.bottom),
            );
    }

    canvas.drawCircle(disc, radius, Paint()..color = palette.surface);
    canvas.drawCircle(
      disc,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = label.ringed ? 1.8 : 1
        ..color = label.ringed ? ink : palette.axisText.withValues(alpha: 0.6),
    );
    final style = palette.labelStyle.copyWith(
      fontSize: fontSize,
      color: label.ringed ? ink : palette.axisText,
      fontWeight: label.ringed ? FontWeight.w700 : null,
    );
    final painter = TextPainter(
      text: TextSpan(text: label.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, disc - Offset(painter.width / 2, painter.height / 2));
  }

  /// The whole lap, small, in the top-right corner, with the segments'
  /// numbers and the part the map shows boxed — the map at segment scale
  /// otherwise loses where on the lap it is.
  void _paintInset(Canvas canvas, Size size, Rect overview, Color ink) {
    final width = math.min(size.width * 0.36, 132.0);
    final aspect = overview.height <= 0
        ? 1.0
        : (overview.width / overview.height).clamp(0.6, 3.0);
    final height = width / aspect;
    final box = Rect.fromLTWH(size.width - width - 6, 6, width, height);
    final shape = RRect.fromRectAndRadius(box, const Radius.circular(6));
    canvas.drawRRect(
      shape,
      Paint()..color = palette.surface.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.grid,
    );

    final fit = TrackFit.of(overview, box, padding: 12);
    final points = [
      for (final metres in path.projection.points) fit.toPixels(metres),
    ];
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round
        ..color = palette.axisText.withValues(alpha: 0.7),
    );
    final cased = highlight == null ? null : _stretch(fit, highlight!);
    if (cased != null) {
      canvas.drawPath(
        cased,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = ink,
      );
    }
    final shown = view;
    if (shown != null) {
      canvas.drawRect(
        Rect.fromPoints(
          fit.toPixels(shown.topLeft),
          fit.toPixels(shown.bottomRight),
        ).intersect(box),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ink.withValues(alpha: 0.6),
      );
    }
    final centre = fit.toPixels(path.projection.boundsMetres.center);
    for (final label in labels) {
      _paintLabel(
        canvas,
        fit,
        centre,
        box,
        label,
        ink,
        radius: 5.5,
        gap: 4,
        fontSize: 7.5,
      );
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
      !identical(old.reference, reference) ||
      old.markers != markers ||
      old.palette.series != palette.series ||
      old.ink != ink ||
      old.view != view ||
      old.overview != overview ||
      old.highlight != highlight ||
      !listEquals(old.labels, labels) ||
      !listEquals(old.marks, marks);
}

/// What moves with the pointer: Base's mark, and the Target's ghost.
///
/// Fitted exactly as [TrackMapPainter] is, from the same inputs, so the
/// marks land on the paths beneath them.
class TrackCursorPainter extends CustomPainter {
  const TrackCursorPainter({
    required this.path,
    required this.palette,
    this.view,
    this.cursor,
    this.ghost,
    this.ghostColor,
    this.ghostLabel,
  });

  final TrackPath path;
  final ChartPalette palette;
  final Rect? view;

  /// Where the cursor puts Base, in metres; null when the pointer is away.
  final Offset? cursor;

  /// Where the cursor's moment puts the Target, in metres: a hollow ring,
  /// the Target's cursor mark (comparison proposal §6, §8).
  final Offset? ghost;
  final Color? ghostColor;

  /// Said at the map's edge, beside a chevron, when [ghost] is off it.
  final String? ghostLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final fit = trackMapFit(path, view, size);
    // At segment zoom either lap can be off the fitted map; neither mark is
    // drawn over whatever sits beside it.
    canvas.clipRect(Offset.zero & size);

    final ghost = this.ghost;
    if (ghost != null) {
      final at = fit.toPixels(ghost);
      final inside = (Offset.zero & size).deflate(6);
      final color = ghostColor ?? palette.cursor;
      if (inside.contains(at)) {
        canvas.drawCircle(at, 7, Paint()..color = palette.surface);
        canvas.drawCircle(
          at,
          5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      } else {
        _paintChevron(canvas, size, at, color);
      }
    }

    final cursor = this.cursor;
    if (cursor != null) {
      final at = fit.toPixels(cursor);
      canvas.drawCircle(at, 7, Paint()..color = palette.surface);
      canvas.drawCircle(at, 5, Paint()..color = palette.cursor);
    }
  }

  /// A chevron on the edge toward [target], which lies off the map, with
  /// [ghostLabel] beside it.
  void _paintChevron(Canvas canvas, Size size, Offset target, Color color) {
    final frame = (Offset.zero & size).deflate(12);
    final centre = frame.center;
    final direction = target - centre;
    if (direction.distance < 1e-6) return;
    // Where the ray from the middle toward the ghost leaves the frame.
    final sx = direction.dx == 0
        ? double.infinity
        : (frame.width / 2) / direction.dx.abs();
    final sy = direction.dy == 0
        ? double.infinity
        : (frame.height / 2) / direction.dy.abs();
    final edge = centre + direction * math.min(sx, sy);
    final unit = direction / direction.distance;
    final normal = Offset(-unit.dy, unit.dx);
    final chevron = Path()
      ..moveTo(
        (edge - unit * 7 + normal * 6).dx,
        (edge - unit * 7 + normal * 6).dy,
      )
      ..lineTo(edge.dx, edge.dy)
      ..lineTo(
        (edge - unit * 7 - normal * 6).dx,
        (edge - unit * 7 - normal * 6).dy,
      );
    canvas.drawPath(
      chevron,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final label = ghostLabel;
    if (label == null) return;
    final painter = TextPainter(
      text: TextSpan(text: label, style: palette.labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    // Just inward of the chevron, by the label's own extent along the
    // direction it points, and kept inside the map.
    final reach =
        unit.dx.abs() * painter.width / 2 + unit.dy.abs() * painter.height / 2;
    final anchor = edge - unit * (12 + reach);
    final topLeft = Offset(
      (anchor.dx - painter.width / 2).clamp(
        4.0,
        size.width - painter.width - 4,
      ),
      (anchor.dy - painter.height / 2).clamp(
        4.0,
        size.height - painter.height - 4,
      ),
    );
    final backing = (topLeft & Size(painter.width, painter.height)).inflate(3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(backing, const Radius.circular(4)),
      Paint()..color = palette.surface.withValues(alpha: 0.9),
    );
    painter.paint(canvas, topLeft);
  }

  @override
  bool shouldRepaint(TrackCursorPainter old) =>
      !identical(old.path, path) ||
      old.view != view ||
      old.cursor != cursor ||
      old.ghost != ghost ||
      old.ghostColor != ghostColor ||
      old.ghostLabel != ghostLabel;
}

/// Scale reference for the map, in metres.
///
/// Worth drawing because the projection's metric frame is real (see
/// [TrackProjection]) even though its coordinates are not geographic — the
/// bar says how big the circuit is, which is the one absolute fact the map
/// can honestly report.
class TrackScalePainter extends CustomPainter {
  const TrackScalePainter({
    required this.path,
    required this.palette,
    this.view,
  });

  final TrackPath path;
  final ChartPalette palette;

  /// The map's fit, as [TrackMapPainter.view]: at segment zoom the bar
  /// measures the zoomed map.
  final Rect? view;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final fit = trackMapFit(path, view, size);
    if (fit.scale <= 0) return;

    // Longest round distance that fits in a quarter of the panel.
    const candidates = [10.0, 20.0, 50.0, 100.0, 200.0, 250.0, 500.0, 1000.0];
    var metres = view == null ? 50.0 : candidates.first;
    for (final candidate in candidates) {
      if (view == null && candidate < 50) continue;
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
      Offset(12 + length, y - 3),
      Offset(12 + length, y + 3),
      paint,
    );
    paintText(
      canvas,
      '${metres.toStringAsFixed(0)} m',
      palette.labelStyle,
      Offset(12, y - 17),
    );
  }

  @override
  bool shouldRepaint(TrackScalePainter old) =>
      !identical(old.path, path) || old.view != view;
}
