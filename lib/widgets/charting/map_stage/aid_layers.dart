/// The driver aids on the map (driver-aids proposal §2.4): where TC and ABS
/// acted, as dots along the line, and where a wheel locked, as a mark on it.
/// The same marks the trace panels use, so the map and the panels read as
/// one key.
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../track_path.dart';
import 'stage_contracts.dart';

/// Dots along [episodes] of [path], over the line, and a disc at each of
/// [locks].
class AidTrackLayer implements StageLayer {
  const AidTrackLayer({
    required this.path,
    required this.episodes,
    required this.locks,
    required this.ink,
    required this.halo,
    required this.lockFill,
  });

  final TrackPath path;

  /// `(start, end)` in the path's domain: every episode of every aid shown.
  final List<(double, double)> episodes;

  /// Each lock-up's position, in the path's domain.
  final List<double> locks;

  final Color ink;
  final Color halo;

  /// The brake's colour, as on the panel's mark.
  final Color lockFill;

  /// The least gap between two dots on screen.
  static const spacing = 5.0;

  @override
  void paint(Canvas canvas, StageView view) {
    final area = (Offset.zero & view.size).inflate(8);
    final points = path.projection.points;
    final haloPaint = Paint()..color = halo;
    final dot = Paint()..color = ink;
    for (final (start, end) in episodes) {
      final first = _lowerBound(path.xs, start);
      final last = _lowerBound(path.xs, end).clamp(0, points.length - 1);
      Offset? previous;
      // One dot at the episode's start, then one every [spacing] pixels of
      // line, so a short intervention is one dot and a long one a bead.
      for (var i = first.clamp(0, points.length - 1); i <= last; i++) {
        final at = view.toScreen(points[i]);
        if (previous != null && (at - previous).distance < spacing) continue;
        previous = at;
        if (!area.contains(at)) continue;
        canvas.drawCircle(at, 2.6, haloPaint);
        canvas.drawCircle(at, 1.7, dot);
      }
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = ink;
    final fill = Paint()..color = lockFill;
    for (final x in locks) {
      final i = path.nearestIndex(x);
      if (i < 0) continue;
      final at = view.toScreen(points[i]);
      if (!area.contains(at)) continue;
      canvas.drawCircle(at, 6, haloPaint);
      canvas.drawCircle(at, 5, fill);
      canvas.drawCircle(at, 5, ring);
    }
  }

  static int _lowerBound(List<double> xs, double value) {
    var low = 0;
    var high = xs.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (xs[mid] < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  @override
  bool shouldRepaint(AidTrackLayer old) =>
      !identical(old.path, path) ||
      !listEquals(old.episodes, episodes) ||
      !listEquals(old.locks, locks) ||
      old.ink != ink ||
      old.halo != halo ||
      old.lockFill != lockFill;
}

/// The key to [AidTrackLayer]: each aid shown with its count on this lap.
class AidLegend extends StatelessWidget {
  const AidLegend({
    super.key,
    required this.counts,
    required this.locks,
    required this.lockFill,
  });

  /// `(label, episodes)` per aid shown: "TC · 8".
  final List<(String, int)> counts;

  /// Lock-ups on this lap; no key for none.
  final int locks;
  final Color lockFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget key(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (label, n) in counts)
          if (n > 0)
            key(
              CustomPaint(size: const Size(18, 6), painter: _DotsSwatch(ink)),
              '$label · $n',
            ),
        if (locks > 0)
          key(
            Container(
              width: 10,
              height: 10,
              decoration: ShapeDecoration(
                shape: CircleBorder(side: BorderSide(color: ink, width: 1.5)),
                color: lockFill,
              ),
            ),
            locks == 1 ? 'Lock-up' : 'Lock-ups · $locks',
          ),
      ],
    );
  }
}

class _DotsSwatch extends CustomPainter {
  const _DotsSwatch(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = colour;
    final y = size.height / 2;
    for (var x = 2.0; x < size.width; x += 5) {
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsSwatch old) => old.colour != colour;
}
