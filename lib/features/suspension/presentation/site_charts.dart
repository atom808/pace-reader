/// The site view's drawing (suspension proposal §4.4): the straightened road
/// ribbon, the distance-axis trace panels and the evidence scatters, each a
/// `CustomPainter` behind a repaint boundary.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../data/suspension_repository.dart';

/// Every lap's traces through a site, laid on one dense metre grid so laps
/// line up bin for bin: what makes the band, the morph between laps and the
/// shared cursor possible.
class SiteSeries {
  SiteSeries._(this.start, this.length, this._dense, this._surface);

  factory SiteSeries.of(List<SiteTrace> traces, double start, double end) {
    final s = start.floor();
    final n = math.max(end.ceil() - s + 1, 1);
    final dense = <int, Map<SiteChannel, Float64List>>{};
    final surfaces = <int, Float64List>{};
    for (final t in traces) {
      final lap = <SiteChannel, Float64List>{};
      for (final c in SiteChannel.values) {
        final out = Float64List(n)..fillRange(0, n, double.nan);
        final src = t.of(c);
        for (var i = 0; i < t.metres.length; i++) {
          final k = t.metres[i].round() - s;
          if (k >= 0 && k < n) out[k] = src[i];
        }
        lap[c] = out;
      }
      final surface = Float64List(n)..fillRange(0, n, double.nan);
      for (var i = 0; i < t.metres.length; i++) {
        final k = t.metres[i].round() - s;
        if (k >= 0 && k < n) surface[k] = t.surface[i].toDouble();
      }
      surfaces[t.lap] = surface;
      dense[t.lap] = lap;
    }
    return SiteSeries._(s, n, dense, surfaces);
  }

  /// The first bin's metre.
  final int start;
  final int length;
  final Map<int, Map<SiteChannel, Float64List>> _dense;
  final Map<int, Float64List> _surface;

  /// Per bin: 0 track, 1 kerb or paint, 2 off track; NaN without data.
  Float64List? surfaceOf(int lap) => _surface[lap];

  Iterable<int> get laps => _dense.keys;
  bool has(int lap) => _dense.containsKey(lap);

  Float64List? of(int lap, SiteChannel c) => _dense[lap]?[c];

  double metreAt(int i) => (start + i).toDouble();

  /// Per bin, the [lo] and [hi] quantiles across laps: the session band.
  (Float64List, Float64List) band(
    SiteChannel c, {
    double lo = 0.1,
    double hi = 0.9,
  }) {
    final a = Float64List(length)..fillRange(0, length, double.nan);
    final b = Float64List(length)..fillRange(0, length, double.nan);
    final values = <double>[];
    for (var i = 0; i < length; i++) {
      values.clear();
      for (final lap in _dense.values) {
        final v = lap[c]![i];
        if (!v.isNaN) values.add(v);
      }
      if (values.length < 3) continue;
      values.sort();
      double q(double p) => values[((values.length - 1) * p).round()];
      a[i] = q(lo);
      b[i] = q(hi);
    }
    return (a, b);
  }

  /// [c]'s range over every lap, padded.
  (double, double) range(SiteChannel c, {double pad = 0.08}) {
    var lo = double.infinity;
    var hi = double.negativeInfinity;
    for (final lap in _dense.values) {
      for (final v in lap[c]!) {
        if (v.isNaN) continue;
        if (v < lo) lo = v;
        if (v > hi) hi = v;
      }
    }
    if (!lo.isFinite) return (0, 1);
    if (hi - lo < 1e-9) return (lo - 1, hi + 1);
    final p = (hi - lo) * pad;
    return (lo - p, hi + p);
  }
}

/// [a] → [b] at [t], bin for bin; a bin missing on either side takes the
/// other's.
Float64List lerpSeries(Float64List? a, Float64List b, double t) {
  if (a == null || a.length != b.length || t >= 1) return b;
  final out = Float64List(b.length);
  for (var i = 0; i < b.length; i++) {
    final x = a[i];
    final y = b[i];
    out[i] = x.isNaN ? y : (y.isNaN ? x : x + (y - x) * t);
  }
  return out;
}

/// One line on a panel.
class PanelLine {
  const PanelLine(
    this.values, {
    required this.color,
    this.width = 1.6,
    this.dashed = false,
  });

  final Float64List values;
  final Color color;
  final double width;
  final bool dashed;
}

/// A horizontal reference: the floor, a ceiling, zero.
class PanelRule {
  const PanelRule(this.value, this.label, {this.dashed = true});

  final double value;
  final String label;
  final bool dashed;
}

Path _seriesPath(
  Float64List values,
  double Function(int) x,
  double Function(double) y,
) {
  final path = Path();
  var pen = false;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v.isNaN) {
      pen = false;
      continue;
    }
    final p = Offset(x(i), y(v));
    if (pen) {
      path.lineTo(p.dx, p.dy);
    } else {
      path.moveTo(p.dx, p.dy);
      pen = true;
    }
  }
  return path;
}

void drawDashed(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 4,
  double gap = 3,
}) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(
        metric.extractPath(d, math.min(d + dash, metric.length)),
        paint,
      );
      d += dash + gap;
    }
  }
}

/// One trace panel on the site's distance axis.
class TracePanelPainter extends CustomPainter {
  TracePanelPainter({
    required this.lines,
    required this.yMin,
    required this.yMax,
    required this.ink,
    required this.muted,
    this.band,
    this.bandColor,
    this.rules = const [],
    this.cursor,
    this.centre,
    this.invert = false,
  });

  final List<PanelLine> lines;
  final double yMin;
  final double yMax;
  final Color ink;
  final Color muted;
  final (Float64List, Float64List)? band;
  final Color? bandColor;
  final List<PanelRule> rules;

  /// Bin index of the shared cursor.
  final double? cursor;

  /// Bin index of the site's place.
  final double? centre;

  /// Draw larger values lower (none use it yet; kept for line panels).
  final bool invert;

  @override
  void paint(Canvas canvas, Size size) {
    final n = lines.isEmpty
        ? (band?.$1.length ?? 0)
        : lines.first.values.length;
    if (n < 2) return;
    double x(int i) => i / (n - 1) * size.width;
    double y(double v) {
      final f = (v - yMin) / (yMax - yMin);
      return (invert ? f : 1 - f) * size.height;
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // The site's place.
    if (centre case final c?) {
      final cx = c / (n - 1) * size.width;
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, size.height),
        Paint()
          ..color = muted.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
    }
    if (band case (final lo, final hi)) {
      final path = Path();
      var open = false;
      final top = <Offset>[];
      final bottom = <Offset>[];
      void flush() {
        if (top.length > 1) {
          path.moveTo(top.first.dx, top.first.dy);
          for (final p in top.skip(1)) {
            path.lineTo(p.dx, p.dy);
          }
          for (final p in bottom.reversed) {
            path.lineTo(p.dx, p.dy);
          }
          path.close();
        }
        top.clear();
        bottom.clear();
      }

      for (var i = 0; i < n; i++) {
        if (lo[i].isNaN || hi[i].isNaN) {
          if (open) flush();
          open = false;
          continue;
        }
        open = true;
        top.add(Offset(x(i), y(hi[i])));
        bottom.add(Offset(x(i), y(lo[i])));
      }
      flush();
      canvas.drawPath(
        path,
        Paint()..color = (bandColor ?? ink).withValues(alpha: 0.13),
      );
    }
    for (final r in rules) {
      final ry = y(r.value);
      if (ry < -1 || ry > size.height + 1) continue;
      final paint = Paint()
        ..color = muted.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      final path = Path()
        ..moveTo(0, ry)
        ..lineTo(size.width, ry);
      if (r.dashed) {
        drawDashed(canvas, path, paint, dash: 3, gap: 3);
      } else {
        canvas.drawPath(path, paint);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: r.label,
          style: TextStyle(fontSize: 9.5, color: muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width - tp.width - 2, ry - tp.height - 1));
    }
    for (final line in lines) {
      final path = _seriesPath(line.values, x, y);
      final paint = Paint()
        ..color = line.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      if (line.dashed) {
        drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    if (cursor case final c?) {
      final cx = c / (n - 1) * size.width;
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, size.height),
        Paint()
          ..color = ink.withValues(alpha: 0.55)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(TracePanelPainter old) => true;
}

/// One lap's line through the site, for the ribbon.
class RibbonLap {
  const RibbonLap({
    required this.lap,
    required this.line,
    required this.struck,
    this.lowIndex,
    this.lowDepth,
  });

  final int lap;

  /// `Path Lateral` per bin, m.
  final Float64List line;
  final bool struck;

  /// The bin of its lowest point at the site, and how deep, m.
  final double? lowIndex;
  final double? lowDepth;
}

/// The road ribbon (§4.4): the site's window straightened, distance along,
/// `Path Lateral` across with the lateral scale exaggerated, every lap a
/// line, each lap's lowest point a ✕ sized by depth.
class RibbonPainter extends CustomPainter {
  RibbonPainter({
    required this.laps,
    required this.selected,
    required this.cleanest,
    required this.raised,
    required this.lateralMin,
    required this.lateralMax,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.reveal,
    this.cursor,
    this.centre,
    this.floor,
  });

  final List<RibbonLap> laps;
  final int? selected;
  final int? cleanest;
  final int? raised;
  final double lateralMin;
  final double lateralMax;
  final Color ink;
  final Color muted;
  final Color accent;

  /// 0..1: the ribbon unrolls from its centre outward.
  final double reveal;
  final double? cursor;
  final double? centre;

  /// The Strike floor, m: ✕ marks under it are solid.
  final double? floor;

  @override
  void paint(Canvas canvas, Size size) {
    if (laps.isEmpty) return;
    final n = laps.first.line.length;
    if (n < 2) return;
    const top = 14.0;
    const bottom = 18.0;
    final h = size.height - top - bottom;
    double x(int i) => i / (n - 1) * size.width;
    double xf(double i) => i / (n - 1) * size.width;
    // + right of centre is drawn lower: the ribbon is seen from the driver's
    // seat looking along the lap, left at the top.
    double y(double v) =>
        top + (v - lateralMin) / (lateralMax - lateralMin) * h;

    canvas.save();
    final half = size.width / 2 * reveal;
    canvas.clipRect(
      Rect.fromLTRB(
        size.width / 2 - half,
        0,
        size.width / 2 + half,
        size.height,
      ),
    );
    // The road: a faint band with the centre line, when it is in view.
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        top - 4,
        size.width,
        top + h + 4,
        const Radius.circular(6),
      ),
      Paint()..color = ink.withValues(alpha: 0.035),
    );
    if (lateralMin < 0 && lateralMax > 0) {
      drawDashed(
        canvas,
        Path()
          ..moveTo(0, y(0))
          ..lineTo(size.width, y(0)),
        Paint()
          ..color = muted.withValues(alpha: 0.35)
          ..strokeWidth = 1,
        dash: 8,
        gap: 6,
      );
    }
    if (centre case final c?) {
      canvas.drawLine(
        Offset(xf(c), top - 4),
        Offset(xf(c), top + h + 4),
        Paint()
          ..color = muted.withValues(alpha: 0.2)
          ..strokeWidth = 1,
      );
    }
    // Clean laps faint, then struck laps in ink, then the cleanest and the
    // selected on top.
    final ordered = [...laps]
      ..sort((a, b) {
        int rank(RibbonLap l) => l.lap == selected
            ? 4
            : l.lap == raised
            ? 3
            : l.lap == cleanest
            ? 2
            : l.struck
            ? 1
            : 0;
        return rank(a).compareTo(rank(b));
      });
    for (final l in ordered) {
      final isSelected = l.lap == selected;
      final isRaised = l.lap == raised;
      final isCleanest = l.lap == cleanest;
      final color = isSelected
          ? accent
          : isRaised
          ? ink
          : isCleanest
          ? ink.withValues(alpha: 0.9)
          : l.struck
          ? ink.withValues(alpha: 0.42)
          : ink.withValues(alpha: 0.12);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected || isRaised ? 2.4 : (isCleanest ? 1.8 : 1.1)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;
      final path = _seriesPath(l.line, x, y);
      if (isCleanest && !isSelected) {
        drawDashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    // ✕ at each lap's lowest point.
    for (final l in ordered) {
      final i = l.lowIndex;
      final d = l.lowDepth;
      if (i == null || d == null) continue;
      final k = i.round().clamp(0, n - 1);
      final v = l.line[k];
      if (v.isNaN) continue;
      final p = Offset(xf(i), y(v));
      final under = floor != null && d < floor!;
      final r =
          (under ? 4.5 : 3.0) +
          (floor == null ? 0 : ((floor! - d) * 1000).clamp(0.0, 6.0) * 0.4);
      final isSelected = l.lap == selected;
      final paint = Paint()
        ..color = isSelected
            ? accent
            : ink.withValues(alpha: under ? 0.85 : 0.35)
        ..strokeWidth = isSelected ? 2.2 : 1.6
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(p + Offset(-r, -r), p + Offset(r, r), paint)
        ..drawLine(p + Offset(-r, r), p + Offset(r, -r), paint);
    }
    if (cursor case final c?) {
      canvas.drawLine(
        Offset(xf(c), 0),
        Offset(xf(c), size.height),
        Paint()
          ..color = ink.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    canvas.restore();
    // Side labels: which way is left.
    final style = TextStyle(fontSize: 9.5, color: muted);
    for (final (label, dy) in [('left', 0.0), ('right', size.height - 12)]) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, dy));
    }
  }

  @override
  bool shouldRepaint(RibbonPainter old) => true;
}

/// The evidence scatter (§4.4): each lap a point, depth up, the fit across.
class ScatterPainter extends CustomPainter {
  ScatterPainter({
    required this.points,
    required this.ink,
    required this.muted,
    required this.accent,
    this.slope,
    this.floor,
  });

  /// (x, depth mm, struck, selected).
  final List<(double, double, bool, bool)> points;
  final Color ink;
  final Color muted;
  final Color accent;

  /// mm per x unit.
  final double? slope;

  /// The Strike floor, mm.
  final double? floor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var x0 = points.first.$1;
    var x1 = x0;
    var y0 = points.first.$2;
    var y1 = y0;
    for (final p in points) {
      x0 = math.min(x0, p.$1);
      x1 = math.max(x1, p.$1);
      y0 = math.min(y0, p.$2);
      y1 = math.max(y1, p.$2);
    }
    if (floor case final f?) {
      y0 = math.min(y0, f);
      y1 = math.max(y1, f);
    }
    final px = (x1 - x0).abs() < 1e-9 ? 1.0 : (x1 - x0) * 0.08;
    final py = (y1 - y0).abs() < 1e-9 ? 1.0 : (y1 - y0) * 0.1;
    x0 -= px;
    x1 += px;
    y0 -= py;
    y1 += py;
    const pad = 6.0;
    double sx(double v) => pad + (v - x0) / (x1 - x0) * (size.width - pad * 2);
    double sy(double v) =>
        size.height - pad - (v - y0) / (y1 - y0) * (size.height - pad * 2);

    final frame = Paint()
      ..color = muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas
      ..drawLine(
        Offset(pad, size.height - pad),
        Offset(size.width - pad, size.height - pad),
        frame,
      )
      ..drawLine(Offset(pad, pad), Offset(pad, size.height - pad), frame);
    if (floor case final f?) {
      drawDashed(
        canvas,
        Path()
          ..moveTo(pad, sy(f))
          ..lineTo(size.width - pad, sy(f)),
        Paint()
          ..color = muted.withValues(alpha: 0.6)
          ..strokeWidth = 1,
        dash: 3,
        gap: 3,
      );
    }
    final m = slope;
    if (m != null) {
      var mx = 0.0;
      var my = 0.0;
      for (final p in points) {
        mx += p.$1;
        my += p.$2;
      }
      mx /= points.length;
      my /= points.length;
      final a = Offset(sx(x0), sy(my + m * (x0 - mx)));
      final b = Offset(sx(x1), sy(my + m * (x1 - mx)));
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = ink.withValues(alpha: 0.5)
          ..strokeWidth = 1.4,
      );
    }
    for (final (x, y, struck, selected) in points) {
      final c = Offset(sx(x), sy(y));
      if (selected) {
        canvas.drawCircle(c, 5, Paint()..color = accent);
      } else if (struck) {
        canvas.drawCircle(c, 3.4, Paint()..color = ink.withValues(alpha: 0.85));
      } else {
        canvas.drawCircle(
          c,
          3.2,
          Paint()
            ..color = ink.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ScatterPainter old) => true;
}
