/// What a screen adds on top of the stage's line (map stage proposal §10:
/// "its segment labels become a StageLayer"): a second lap dotted, a stretch
/// cased, numbered stretches and stated findings. Each is a [StageLayer] a
/// host passes as an overlay; none is special to [MapStage].
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../painters/chart_painting.dart';
import '../track_path.dart';
import 'stage_contracts.dart';

/// A number beside the line at a station: a segment (comparison proposal
/// §6), the worst one ringed.
@immutable
class TrackLabel {
  const TrackLabel({
    required this.station,
    required this.text,
    this.ringed = false,
  });

  /// `Lap Dist` metres.
  final double station;
  final String text;

  /// Drawn in ink with a heavier ring: the one the eye should find first.
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
  /// Where the brake went on.
  diamond,

  /// The slowest point of a corner.
  dot,

  /// A contact with something.
  contact,
}

/// One stated finding at a point of the map: Base's filled, the Target's
/// hollow.
@immutable
class TrackMark {
  const TrackMark({required this.at, required this.shape, this.hollow = false});

  /// In the projection's metres.
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

/// A second lap's line, dotted in ink: Compare's Target. Thin and
/// uncoloured, so the coloured line stays the one being read.
class ReferenceLineLayer implements StageLayer {
  const ReferenceLineLayer({
    required this.path,
    required this.colour,
    this.width = 1.8,
  });

  final TrackPath path;
  final Color colour;
  final double width;

  @override
  void paint(Canvas canvas, StageView view) {
    final points = path.projection.points;
    if (points.length < 2) return;
    final visible = view.visibleMetres.inflate(20 / view.pixelsPerMetre);
    // One dotted run per stretch on screen, so the dash phase never jumps
    // where the line leaves the view and comes back.
    final runs = <List<Offset>>[];
    List<Offset>? run;
    for (final metres in points) {
      if (!visible.contains(metres)) {
        run = null;
        continue;
      }
      run ??= (runs..add([])).last;
      run.add(view.toScreen(metres));
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = colour;
    for (final screen in runs) {
      if (screen.length < 2) continue;
      canvas.drawPath(dashedPolyline(screen, dash: 4, gap: 4), paint);
    }
  }

  @override
  bool shouldRepaint(ReferenceLineLayer old) =>
      !identical(old.path, path) || old.colour != colour || old.width != width;
}

/// The stretch [from]–[to] of `Lap Dist` cased under the line in ink: which
/// stretch is selected, without dimming the rest, since on this map
/// lightness is magnitude and a dimmed stretch would read as slow
/// (comparison proposal §6).
class StretchCasingLayer implements StageLayer {
  const StretchCasingLayer({
    required this.path,
    required this.from,
    required this.to,
    required this.colour,
    required this.width,
  });

  final TrackPath path;
  final double from;
  final double to;
  final Color colour;

  /// The line's width; the casing is wider by a margin either side.
  final double width;

  @override
  void paint(Canvas canvas, StageView view) {
    final stations = path.stations;
    if (stations == null) return;
    final points = path.projection.points;
    final start = path.positionAtStation(from);
    final end = path.positionAtStation(to);
    final inside = [
      if (start != null) view.toScreen(start),
      for (var i = 0; i < path.length; i++)
        if (stations[i] > from && stations[i] < to) view.toScreen(points[i]),
      if (end != null) view.toScreen(end),
    ];
    if (inside.length < 2) return;
    canvas.drawPath(
      Path()..addPolygon(inside, false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(StretchCasingLayer old) =>
      !identical(old.path, path) ||
      old.from != from ||
      old.to != to ||
      old.colour != colour ||
      old.width != width;
}

/// Stated findings as shapes: ink on a surface halo, so each reads over any
/// colour of the line.
class TrackMarkLayer implements StageLayer {
  const TrackMarkLayer({
    required this.marks,
    required this.ink,
    required this.surface,
  });

  final List<TrackMark> marks;
  final Color ink;
  final Color surface;

  @override
  void paint(Canvas canvas, StageView view) {
    final area = (Offset.zero & view.size).inflate(12);
    for (final mark in marks) {
      final at = view.toScreen(mark.at);
      if (!area.contains(at)) continue;
      final shape = switch (mark.shape) {
        TrackMarkShape.diamond =>
          Path()
            ..moveTo(at.dx, at.dy - 6.5)
            ..lineTo(at.dx + 6.5, at.dy)
            ..lineTo(at.dx, at.dy + 6.5)
            ..lineTo(at.dx - 6.5, at.dy)
            ..close(),
        TrackMarkShape.dot =>
          Path()..addOval(Rect.fromCircle(center: at, radius: 5)),
        TrackMarkShape.contact => _star(at, outer: 7.5, inner: 3.2),
      };
      canvas
        ..drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeJoin = StrokeJoin.round
            ..color = surface,
        )
        ..drawPath(shape, Paint()..color = mark.hollow ? surface : ink)
        ..drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = ink,
        );
    }
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

  @override
  bool shouldRepaint(TrackMarkLayer old) =>
      !listEquals(old.marks, marks) || old.ink != ink || old.surface != surface;
}

/// Numbers in discs beside the line, pushed away from the circuit's middle
/// so each sits outside the loop rather than across it, or inside where
/// outside would leave the screen.
class TrackLabelLayer implements StageLayer {
  const TrackLabelLayer({
    required this.path,
    required this.labels,
    required this.palette,
    required this.ink,
    this.radius = 9,
  });

  final TrackPath path;
  final List<TrackLabel> labels;
  final ChartPalette palette;
  final Color ink;
  final double radius;

  @override
  void paint(Canvas canvas, StageView view) {
    final area = Offset.zero & view.size;
    final centre = view.toScreen(path.projection.boundsMetres.center);
    for (final label in labels) {
      final at = path.positionAtStation(label.station);
      if (at == null) continue;
      final pixel = view.toScreen(at);
      if (!area.contains(pixel)) continue;
      final before = path.positionAtStation(label.station - 5) ?? at;
      final after = path.positionAtStation(label.station + 5) ?? at;
      var direction = view.toScreen(after) - view.toScreen(before);
      if (direction.distance < 1e-6) direction = const Offset(1, 0);
      final unit = direction / direction.distance;
      var normal = Offset(-unit.dy, unit.dx);
      final outward = pixel - centre;
      if (normal.dx * outward.dx + normal.dy * outward.dy < 0) normal = -normal;
      const gap = 13.0;
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
      canvas
        ..drawCircle(disc, radius, Paint()..color = palette.surface)
        ..drawCircle(
          disc,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = label.ringed ? 1.8 : 1
            ..color = label.ringed
                ? ink
                : palette.axisText.withValues(alpha: 0.6),
        );
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: palette.labelStyle.copyWith(
            fontSize: 10.5,
            color: label.ringed ? ink : palette.axisText,
            fontWeight: label.ringed ? FontWeight.w700 : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        disc - Offset(painter.width / 2, painter.height / 2),
      );
      painter.dispose();
    }
  }

  @override
  bool shouldRepaint(TrackLabelLayer old) =>
      !identical(old.path, path) ||
      !listEquals(old.labels, labels) ||
      old.ink != ink ||
      old.radius != radius ||
      old.palette.axisText != palette.axisText ||
      old.palette.surface != palette.surface;
}
