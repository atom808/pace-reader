/// Which point of a lap's line the pointer is on (map stage proposal §5).
///
/// Plain Dart over `dart:ui`'s [Offset], in the map's metres, so it is built
/// once per path and never touches the camera: a caller converts the pointer
/// and its radius into metres and asks.
///
/// Two things make this more than "nearest vertex":
///
/// - **Segments, not vertices.** At 10 Hz a car at 300 km/h covers 8 m between
///   samples, so the nearest *vertex* can be 4 m from the pointer while the
///   line passes under it. The answer is a fractional index along the segment.
/// - **Continuity where the line passes itself.** A hairpin's two legs, a pit
///   lane beside the straight, or a bridge crossing put two stretches of the
///   lap within a few pixels. Among stretches nearly as close as the closest,
///   the one nearest [PathHitIndex.nearest]'s `near` index wins, so a drag
///   along one leg never jumps to the other.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// A hit on the line: [index] is fractional (segment `i` from `i` to `i + 1`),
/// [point] is where on the line, in metres, and [distance] how far the query
/// was from it.
class PathHit {
  const PathHit({
    required this.index,
    required this.point,
    required this.distance,
  });

  final double index;
  final Offset point;
  final double distance;

  @override
  String toString() =>
      'PathHit(${index.toStringAsFixed(2)}, ${distance.toStringAsFixed(2)} m)';
}

/// A uniform grid over a polyline's segments, so a hover costs the few
/// segments near the pointer rather than the whole lap.
class PathHitIndex {
  PathHitIndex(List<Offset> points, {this.cellMetres = 25})
    : _points = List.unmodifiable(points) {
    if (_points.length < 2) return;
    var bounds = Rect.fromPoints(_points.first, _points.first);
    for (final p in _points) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    _origin = bounds.topLeft;
    for (var i = 0; i < _points.length - 1; i++) {
      final a = _points[i], b = _points[i + 1];
      final x0 = _cell(math.min(a.dx, b.dx) - _origin.dx);
      final x1 = _cell(math.max(a.dx, b.dx) - _origin.dx);
      final y0 = _cell(math.min(a.dy, b.dy) - _origin.dy);
      final y1 = _cell(math.max(a.dy, b.dy) - _origin.dy);
      for (var x = x0; x <= x1; x++) {
        for (var y = y0; y <= y1; y++) {
          (_grid[_key(x, y)] ??= []).add(i);
        }
      }
    }
  }

  final double cellMetres;
  final List<Offset> _points;
  final _grid = <int, List<int>>{};
  Offset _origin = Offset.zero;

  int _cell(double metres) => (metres / cellMetres).floor();
  static int _key(int x, int y) => (x & 0xFFFF) << 16 | (y & 0xFFFF);

  int get length => _points.length;

  /// The line under [query] within [radius] metres, or null when none is.
  ///
  /// When more than one stretch of the lap lies within [tieMetres] of the
  /// closest, the one whose index is nearest [near] wins (continuity). With
  /// no [near], the closest wins outright.
  PathHit? nearest(
    Offset query, {
    required double radius,
    double? near,
    double tieMetres = 0,
  }) {
    if (_points.length < 2) return null;
    final local = query - _origin;
    final x0 = _cell(local.dx - radius), x1 = _cell(local.dx + radius);
    final y0 = _cell(local.dy - radius), y1 = _cell(local.dy + radius);
    final best = <int, PathHit>{};
    for (var x = x0; x <= x1; x++) {
      for (var y = y0; y <= y1; y++) {
        for (final i in _grid[_key(x, y)] ?? const <int>[]) {
          if (best.containsKey(i)) continue;
          final hit = _onSegment(i, query);
          if (hit.distance <= radius) best[i] = hit;
        }
      }
    }
    if (best.isEmpty) return null;

    // Stretches: runs of consecutive segment indices. Each run's closest
    // segment stands for it.
    final indices = best.keys.toList()..sort();
    final stretches = <PathHit>[];
    PathHit? current;
    var previous = -2;
    for (final i in indices) {
      final hit = best[i]!;
      if (i != previous + 1) {
        if (current != null) stretches.add(current);
        current = hit;
      } else if (hit.distance < current!.distance) {
        current = hit;
      }
      previous = i;
    }
    stretches.add(current!);

    stretches.sort((a, b) => a.distance.compareTo(b.distance));
    final closest = stretches.first;
    if (near == null || stretches.length == 1) return closest;
    final contenders =
        stretches
            .where((s) => s.distance <= closest.distance + tieMetres)
            .toList()
          ..sort(
            (a, b) => (a.index - near).abs().compareTo((b.index - near).abs()),
          );
    return contenders.first;
  }

  PathHit _onSegment(int i, Offset q) {
    final a = _points[i], b = _points[i + 1];
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = lengthSquared == 0
        ? 0.0
        : (((q.dx - a.dx) * ab.dx + (q.dy - a.dy) * ab.dy) / lengthSquared)
              .clamp(0.0, 1.0);
    final point = a + ab * t;
    return PathHit(index: i + t, point: point, distance: (q - point).distance);
  }
}
