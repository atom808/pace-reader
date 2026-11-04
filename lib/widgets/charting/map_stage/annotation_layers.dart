/// What a screen adds on top of the stage's line (map stage proposal §10:
/// "its segment labels become a StageLayer"): a second lap dotted, a stretch
/// cased, numbered stretches, stated findings, segment bands and corner
/// chevrons. Each is a [StageLayer] a host passes in; none is special to
/// [MapStage].
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../painters/chart_painting.dart';
import '../track_path.dart';
import 'path_kinematics.dart';
import 'stage_contracts.dart';

/// A number beside the line at a station: a segment (comparison proposal
/// §6), the worst one ringed.
@immutable
class TrackLabel {
  const TrackLabel({
    required this.station,
    required this.text,
    this.ringed = false,
    this.lift = 0,
  });

  /// `Lap Dist` metres.
  final double station;
  final String text;

  /// Drawn in ink with a heavier ring: the one the eye should find first.
  final bool ringed;

  /// 0..1: how far the disc is lifted toward ink, a hover easing in and out
  /// (Driving Technique's segments).
  final double lift;

  @override
  bool operator ==(Object other) =>
      other is TrackLabel &&
      other.station == station &&
      other.text == text &&
      other.ringed == ringed &&
      other.lift == lift;

  @override
  int get hashCode => Object.hash(station, text, ringed, lift);
}

/// What a [TrackMark] marks.
enum TrackMarkShape {
  /// Where the brake went on.
  diamond,

  /// The slowest point of a corner.
  dot,

  /// A contact with something.
  contact,

  /// A ring round a point: a caught slide.
  ring,
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
    this.margin = 7,
  });

  final TrackPath path;
  final double from;
  final double to;
  final Color colour;

  /// The line's width; the casing is wider by [margin], split either side.
  final double width;

  /// 0 lays the stretch over the line at its own width: Suspension's
  /// selected site, lifted along the road.
  final double margin;

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
        ..strokeWidth = width + margin
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
      old.width != width ||
      old.margin != margin;
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
        TrackMarkShape.ring =>
          Path()..addOval(Rect.fromCircle(center: at, radius: 6.5)),
      };
      // A ring is only its outline: what it circles stays readable.
      final ring = mark.shape == TrackMarkShape.ring;
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring ? 4.5 : 4
          ..strokeJoin = StrokeJoin.round
          ..color = surface,
      );
      if (!ring) {
        canvas.drawPath(shape, Paint()..color = mark.hollow ? surface : ink);
      }
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring ? 1.8 : 1.6
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
        ..drawCircle(
          disc,
          radius,
          Paint()..color = Color.lerp(palette.surface, ink, label.lift)!,
        )
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
            color: Color.lerp(
              label.ringed ? ink : palette.axisText,
              palette.surface,
              label.lift,
            ),
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

/// One stretch of the lap as a band under the line: a segment, "where the
/// time goes" (SPEC §8.13.8).
@immutable
class TrackBand {
  const TrackBand({
    required this.from,
    required this.to,
    required this.alternate,
    this.lift = 0,
  });

  /// `Lap Dist` metres, [from] inclusive, [to] exclusive.
  final double from;
  final double to;

  /// Takes the second of the two neutral tones, so neighbours read apart
  /// by shade and never by hue.
  final bool alternate;

  /// 0..1: how far the band is lifted, a hover easing in and out.
  final double lift;

  @override
  bool operator ==(Object other) =>
      other is TrackBand &&
      other.from == from &&
      other.to == to &&
      other.alternate == alternate &&
      other.lift == lift;

  @override
  int get hashCode => Object.hash(from, to, alternate, lift);
}

/// The lap cut into [bands] in two alternating tones of ink, a lifted band
/// darker, wider and glowing. Drawn under the line.
class TrackBandLayer implements StageLayer {
  const TrackBandLayer({
    required this.path,
    required this.bands,
    required this.ink,
  });

  final TrackPath path;
  final List<TrackBand> bands;
  final Color ink;

  @override
  void paint(Canvas canvas, StageView view) {
    final toneA = ink.withValues(alpha: 0.11);
    final toneB = ink.withValues(alpha: 0.30);
    final lifted = ink.withValues(alpha: 0.58);
    // Bands at rest first, then the lifted ones over them.
    final order = [...bands]..sort((a, b) => a.lift.compareTo(b.lift));
    for (final band in order) {
      final l = band.lift;
      for (final run in stationRuns(path, band.from, band.to, view)) {
        if (run.length < 2) continue;
        final line = Path()..addPolygon(run, false);
        if (l > 0) {
          canvas.drawPath(
            line,
            Paint()
              ..color = ink.withValues(alpha: 0.10 * l)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 22 * l
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
        }
        canvas.drawPath(
          line,
          Paint()
            ..color = Color.lerp(band.alternate ? toneB : toneA, lifted, l)!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9 + 5 * l
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TrackBandLayer old) =>
      !identical(old.path, path) ||
      !listEquals(old.bands, bands) ||
      old.ink != ink;
}

/// [path]'s stretch from `Lap Dist` [from] to [to] on screen, as runs of
/// consecutive points. Each run takes the next point after it, so bands
/// meet without a gap; a stretch the start/finish line splits is two runs,
/// never one joined straight across the infield.
List<List<Offset>> stationRuns(
  TrackPath path,
  double from,
  double to,
  StageView view,
) {
  final stations = path.stations;
  if (stations == null) return const [];
  final points = path.projection.points;
  final runs = <List<Offset>>[];
  List<Offset>? run;
  for (var i = 0; i < points.length; i++) {
    if (stations[i] >= from && stations[i] < to) {
      run ??= (runs..add([])).last;
      run.add(view.toScreen(points[i]));
    } else if (run != null) {
      run.add(view.toScreen(points[i]));
      run = null;
    }
  }
  return runs;
}

/// A corner: where its apex is and which way it turns.
@immutable
class TrackChevron {
  const TrackChevron({
    required this.apex,
    required this.leftHander,
    this.active = false,
  });

  /// `Lap Dist` metres.
  final double apex;
  final bool leftHander;

  /// Badged and heavier: the corner the screen is on.
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is TrackChevron &&
      other.apex == apex &&
      other.leftHander == leftHander &&
      other.active == active;

  @override
  int get hashCode => Object.hash(apex, leftHander, active);
}

/// Corners as chevrons on the inside of each apex, pointing the way of
/// travel: "what the road does", told from segments by shape (SPEC
/// §8.13.8).
class TrackChevronLayer implements StageLayer {
  const TrackChevronLayer({
    required this.path,
    required this.chevrons,
    required this.ink,
    required this.badge,
  });

  final TrackPath path;
  final List<TrackChevron> chevrons;
  final Color ink;

  /// The disc behind the active corner's chevron.
  final Color badge;

  @override
  void paint(Canvas canvas, StageView view) {
    final area = (Offset.zero & view.size).inflate(24);
    for (final c in chevrons) {
      final i = indexAtStation(path, c.apex);
      if (i == null) continue;
      final at = view.toScreen(positionAtIndex(path, i));
      if (!area.contains(at)) continue;
      final heading =
          view.toScreen(
            positionAtIndex(path, math.min(i + 1, path.length - 1)),
          ) -
          view.toScreen(positionAtIndex(path, math.max(i - 1, 0)));
      if (heading.distance == 0) continue;
      final h = heading / heading.distance;
      // Screen y grows down, so the left of travel is (h.dy, −h.dx).
      final left = Offset(h.dy, -h.dx);
      final inside = c.leftHander ? left : -left;
      final centre = at + inside * (c.active ? 17 : 15);
      final s = c.active ? 6.5 : 4.5;
      if (c.active) {
        canvas
          ..drawCircle(centre, 10, Paint()..color = badge)
          ..drawCircle(
            centre,
            10,
            Paint()
              ..color = ink.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
      }
      final back = centre - h * s;
      canvas.drawPath(
        Path()
          ..moveTo(back.dx + left.dx * s, back.dy + left.dy * s)
          ..lineTo(centre.dx + h.dx * s * 0.6, centre.dy + h.dy * s * 0.6)
          ..lineTo(back.dx - left.dx * s, back.dy - left.dy * s),
        Paint()
          ..color = c.active ? ink : ink.withValues(alpha: 0.72)
          ..style = PaintingStyle.stroke
          ..strokeWidth = c.active ? 2 : 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(TrackChevronLayer old) =>
      !identical(old.path, path) ||
      !listEquals(old.chevrons, chevrons) ||
      old.ink != ink ||
      old.badge != badge;
}
