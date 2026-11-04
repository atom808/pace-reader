/// The road under the line (map stage proposal §3.1 step 1, §3.4): where the
/// track's edges are, in metres either side of its centre path, and the band
/// drawn between them.
///
/// The files carry no centre path. Each sample says how far the car was from
/// it (`Path Lateral`), so the centre is the driven line moved back by that,
/// across the direction of travel; the edges hang off the centre from there.
/// Where either edge is unknown at a station there is no band — a gap reads
/// as "not known", never as a narrow road.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Vertices, VertexMode;

import 'package:material_ui/material_ui.dart';

import '../track_path.dart';
import 'stage_contracts.dart';

/// The track's edges along the lap, in [binMetres] stations of `Lap Dist`
/// from zero: [left] in metres left of the centre path (zero or less),
/// [right] right of it (zero or more), NaN where not known.
@immutable
class TrackOutline {
  const TrackOutline({
    required this.binMetres,
    required this.left,
    required this.right,
  });

  final double binMetres;
  final Float64List left;
  final Float64List right;

  int get length => left.length;

  /// Both edges at `Lap Dist` [station]; null where either is not known.
  ///
  /// Each station's value belongs to its middle, and between two middles
  /// the edge runs straight, so a coarse outline bends rather than steps.
  /// Beside a station not known, its known neighbour's value holds.
  (double, double)? edgesAt(double station) {
    if (!station.isFinite) return null;
    final bin = (station / binMetres).floor();
    if (bin < 0 || bin >= length) return null;
    final here = _edges(bin);
    if (here == null) return null;
    final u = station / binMetres - 0.5;
    final from = u.floor();
    final a = _edges(from);
    final b = _edges(from + 1);
    if (a == null || b == null) return here;
    final f = u - from;
    return (a.$1 + (b.$1 - a.$1) * f, a.$2 + (b.$2 - a.$2) * f);
  }

  (double, double)? _edges(int bin) {
    if (bin < 0 || bin >= length) return null;
    final l = left[bin];
    final r = right[bin];
    return l.isNaN || r.isNaN ? null : (l, r);
  }
}

/// The share of points with both edges known.
double knownShare(List<Offset?> left, List<Offset?> right) {
  if (left.isEmpty) return 0;
  var known = 0;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != null && right[i] != null) known++;
  }
  return known / left.length;
}

/// The two edges of the road at each point of [path], in its metres; null
/// where the outline or [lateral] does not know.
///
/// [lateral] is `Path Lateral` at each of [path]'s points: metres from the
/// centre path, + to the right of travel, as [TrackOutline]'s edges are.
({List<Offset?> left, List<Offset?> right}) trackEdges(
  TrackPath path,
  Float64List lateral,
  TrackOutline outline,
) {
  final points = path.projection.points;
  final stations = path.stations;
  final n = points.length;
  final left = List<Offset?>.filled(n, null);
  final right = List<Offset?>.filled(n, null);
  if (stations == null || n < 2 || lateral.length != n) {
    return (left: left, right: right);
  }
  for (var i = 0; i < n; i++) {
    final edges = outline.edgesAt(stations[i]);
    final offset = lateral[i];
    if (edges == null || offset.isNaN) continue;
    final heading = points[math.min(i + 1, n - 1)] - points[math.max(i - 1, 0)];
    if (heading.distance == 0) continue;
    final h = heading / heading.distance;
    // y grows southward in the projection, so right of travel is
    // (−h.dy, h.dx).
    final toRight = Offset(-h.dy, h.dx);
    final centre = points[i] - toRight * offset;
    left[i] = centre + toRight * edges.$1;
    right[i] = centre + toRight * edges.$2;
  }
  return (left: left, right: right);
}

/// The road as a band between its two edges: a neutral fill, no edge
/// stroke, so it reads as ground under everything drawn on it (§3.1).
class TrackOutlineLayer implements StageLayer {
  const TrackOutlineLayer({
    required this.left,
    required this.right,
    required this.colour,
  });

  final List<Offset?> left;
  final List<Offset?> right;
  final Color colour;

  @override
  void paint(Canvas canvas, StageView view) {
    final visible = view.visibleMetres.inflate(40 / view.pixelsPerMetre);
    final triangles = <double>[];
    void corner(Offset metres) {
      final at = view.toScreen(metres);
      triangles
        ..add(at.dx)
        ..add(at.dy);
    }

    final n = left.length;
    // A lap ends a sample short of where it began: the band closes across
    // the line, or it shows a notch there. A lap that ends in the pits
    // ends far from its start and stays open.
    final closes =
        n > 2 && _near(left.last, left.first) && _near(right.last, right.first);
    for (var i = 0; i < (closes ? n : n - 1); i++) {
      final a = left[i];
      final b = right[i];
      final c = right[(i + 1) % n];
      final d = left[(i + 1) % n];
      if (a == null || b == null || c == null || d == null) continue;
      if (!visible.contains(a) && !visible.contains(c)) continue;
      for (final p in [a, b, c, a, c, d]) {
        corner(p);
      }
    }
    if (triangles.isEmpty) return;
    // Opaque triangles in a layer that carries the alpha: neighbours overlap
    // on the inside of a bend, and fold over where it is tight, which a
    // translucent fill per quad would show as seams and one path as holes.
    canvas
      ..saveLayer(
        Offset.zero & view.size,
        Paint()..color = Color.fromRGBO(0, 0, 0, colour.a),
      )
      ..drawVertices(
        Vertices.raw(VertexMode.triangles, Float32List.fromList(triangles)),
        BlendMode.srcOver,
        Paint()..color = colour.withValues(alpha: 1),
      )
      ..restore();
  }

  /// Close enough, in metres, to be one sample apart at racing speed.
  static const _closeWithin = 30.0;

  static bool _near(Offset? a, Offset? b) =>
      a != null && b != null && (a - b).distance <= _closeWithin;

  @override
  bool shouldRepaint(TrackOutlineLayer old) =>
      !identical(old.left, left) ||
      !identical(old.right, right) ||
      old.colour != colour;
}
