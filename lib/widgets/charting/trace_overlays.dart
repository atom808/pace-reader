/// What a feature lays over a panel's line (driver-aids proposal §2): the
/// throttle the engine did not get, and an aid's pulses as dots on the line.
///
/// Data, in the panel's domain units, rather than widgets: the panel paints
/// them in one layer between the trace and the cursor, which repaints only
/// when they or the window change — never at pointer rate.
library;

import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'decimation.dart';
import 'painters/chart_painting.dart';

sealed class TraceOverlay {
  const TraceOverlay();
}

/// Where the panel's line runs above [delivered]: the pedal above what
/// reached the engine, which is the throttle a cut took away. Hatched
/// between the two, with [delivered] drawn along the cut's floor.
final class CutOverlay extends TraceOverlay {
  const CutOverlay(this.delivered, {this.minGap = 0.5});

  final TracePlot delivered;

  /// Gaps up to this, in the panel's unit, are not a cut: the two channels
  /// differ by rounding on most samples (§8.13.1 counts a cut above 0.5).
  final double minGap;
}

/// An aid's pulses as dots on the panel's line, and its episodes, which name
/// it in the panel's readout while the cursor is inside one.
final class PulseOverlay extends TraceOverlay {
  const PulseOverlay({
    required this.label,
    required this.pulses,
    required this.episodeStarts,
    required this.episodeEnds,
  });

  /// `TC`, `ABS`: what the readout says inside an episode.
  final String label;

  /// Each pulse's middle, in domain units, in order.
  final Float64List pulses;

  /// Each episode's ends, in domain units, in order.
  final Float64List episodeStarts;
  final Float64List episodeEnds;

  /// Whether [domain] falls inside an episode.
  bool activeAt(double domain) {
    var lo = 0;
    var hi = episodeStarts.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (domain < episodeStarts[mid]) {
        hi = mid - 1;
      } else if (domain > episodeEnds[mid]) {
        lo = mid + 1;
      } else {
        return true;
      }
    }
    return false;
  }
}

/// The labels of [overlays]' aids active at [domain], in order.
List<String> activeAidLabels(List<TraceOverlay> overlays, double domain) => [
  for (final o in overlays)
    if (o is PulseOverlay && o.activeAt(domain)) o.label,
];

/// A stable name for [overlay]'s layer: its kind, and an aid's label.
String overlayKey(TraceOverlay overlay) => switch (overlay) {
  CutOverlay() => 'cut',
  PulseOverlay(:final label) => 'pulses:$label',
};

/// Paints [overlay] over [line], the panel's own trace.
///
/// One overlay a painter, compared by identity: the panel rebuilds at
/// pointer rate, and the overlay objects are what stay the same across it.
class TraceOverlayPainter extends CustomPainter {
  const TraceOverlayPainter({
    required this.overlay,
    required this.line,
    required this.geometry,
    required this.palette,
    required this.ink,
  });

  final TraceOverlay overlay;
  final TracePlot line;
  final ChartGeometry geometry;
  final ChartPalette palette;

  /// The dots' colour: ink, so a pulse reads on the line's own colour
  /// without a hue of its own (§9.7.1's wheel is full).
  final Color ink;

  /// The least gap between two dots' centres, in pixels: closer pulses are
  /// one dot, so a busy stretch at lap zoom is a bead along the line and a
  /// zoomed one parts into single pulses.
  static const dotSpacing = 4.0;
  static const dotRadius = 1.7;

  @override
  void paint(Canvas canvas, Size size) {
    if (line.length < 2) return;
    canvas.clipRect(Offset.zero & size);
    final scaled = ChartGeometry(
      viewport: geometry.viewport,
      values: geometry.values,
      size: size,
    );
    switch (overlay) {
      case final CutOverlay cut:
        _paintCut(canvas, scaled, cut);
      case final PulseOverlay pulses:
        _paintPulses(canvas, scaled, pulses);
    }
  }

  /// The visible run of [plot]'s indices, one point of overscan each side.
  static (int, int)? _visible(TracePlot plot, ChartGeometry g) {
    if (plot.length < 2) return null;
    final first = (plot.nearestIndex(g.viewport.start) - 1).clamp(
      0,
      plot.length - 1,
    );
    final last = (plot.nearestIndex(g.viewport.end) + 1).clamp(
      0,
      plot.length - 1,
    );
    return last > first ? (first, last) : null;
  }

  void _paintCut(Canvas canvas, ChartGeometry g, CutOverlay cut) {
    final range = _visible(line, g);
    if (range == null) return;
    final (first, last) = range;

    // Each run of samples with the line above what was delivered becomes
    // one polygon: along the line, then back along the delivered throttle.
    // The samples either side of a run close it at zero gap, so a cut
    // tapers in and out rather than starting as a wall.
    final area = Path();
    final floor = Path();
    final tops = <Offset>[];
    final bottoms = <Offset>[];
    void flush() {
      if (tops.length >= 2) {
        area.addPolygon([...tops, ...bottoms.reversed], true);
        floor.addPolygon(bottoms, false);
      }
      tops.clear();
      bottoms.clear();
    }

    Offset? openAt;
    for (var i = first; i <= last; i++) {
      final x = line.xs[i];
      final value = (line.lows[i] + line.highs[i]) / 2;
      final delivered = cut.delivered.interpolatedAt(x);
      final px = g.x(x);
      final top = Offset(px, g.y(value));
      if (delivered == null || value - delivered <= cut.minGap) {
        if (tops.isNotEmpty) {
          tops.add(top);
          bottoms.add(top);
          flush();
        }
        openAt = top;
        continue;
      }
      if (tops.isEmpty && openAt != null) {
        tops.add(openAt);
        bottoms.add(openAt);
      }
      tops.add(top);
      bottoms.add(Offset(px, g.y(delivered)));
    }
    flush();

    // The fill under the line is knocked back inside the cut, then hatched
    // in the line's colour: throttle asked for and not given.
    canvas.drawPath(
      area,
      Paint()..color = palette.surface.withValues(alpha: 0.7),
    );
    final bounds = area.getBounds();
    if (!bounds.isEmpty) {
      canvas.save();
      canvas.clipPath(area);
      final hatch = Paint()
        ..color = palette.series.withValues(alpha: 0.75)
        ..strokeWidth = 1;
      const step = 4.0;
      for (var x = bounds.left - bounds.height; x < bounds.right; x += step) {
        canvas.drawLine(
          Offset(x, bounds.bottom),
          Offset(x + bounds.height, bounds.top),
          hatch,
        );
      }
      canvas.restore();
    }
    canvas.drawPath(
      floor,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round
        ..color = palette.series,
    );
  }

  void _paintPulses(Canvas canvas, ChartGeometry g, PulseOverlay overlay) {
    final halo = Paint()..color = palette.surface;
    final dot = Paint()..color = ink;
    var lastX = double.negativeInfinity;
    for (final x in overlay.pulses) {
      if (!g.viewport.contains(x)) continue;
      final px = g.x(x);
      if (px - lastX < dotSpacing) continue;
      lastX = px;
      final value = line.interpolatedAt(x);
      if (value == null) continue;
      final at = Offset(px, g.y(value));
      canvas.drawCircle(at, dotRadius + 1, halo);
      canvas.drawCircle(at, dotRadius, dot);
    }
  }

  @override
  bool shouldRepaint(TraceOverlayPainter old) =>
      !identical(old.overlay, overlay) ||
      !identical(old.line, line) ||
      old.geometry != geometry ||
      old.palette.series != palette.series ||
      old.palette.surface != palette.surface ||
      old.ink != ink;
}
