/// What the map stage draws, one [StageLayer] each (map stage proposal §3,
/// §10): the line, the sector marks, the cars, the probe, the scale.
///
/// Every layer paints through the [StageView]'s camera each frame, culled to
/// what is on screen; P0.2 measured a whole lap at 160 Hz well inside the
/// budget this way, so nothing is cached in pixels.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, listEquals;
import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../painters/chart_painting.dart';
import '../track_path.dart';
import 'camera.dart';
import 'stage_contracts.dart';

/// Paints [layers] through [camera], repainting whenever it moves.
class StagePainter extends CustomPainter {
  StagePainter({required this.camera, required this.layers})
    : super(repaint: camera);

  final ValueListenable<MapCamera> camera;
  final List<StageLayer> layers;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final view = StageView(camera: camera.value, size: size);
    for (final layer in layers) {
      layer.paint(canvas, view);
    }
  }

  @override
  bool shouldRepaint(StagePainter old) {
    if (old.camera != camera || old.layers.length != layers.length) {
      return true;
    }
    for (var i = 0; i < layers.length; i++) {
      final was = old.layers[i];
      final now = layers[i];
      if (was.runtimeType != now.runtimeType || now.shouldRepaint(was)) {
        return true;
      }
    }
    return false;
  }
}

/// The driven line, coloured by a [LineColouring], over an unlit casing so
/// it reads as a closed loop where the colouring is darkest.
class TrackLineLayer implements StageLayer {
  const TrackLineLayer({
    required this.path,
    required this.colouring,
    required this.casing,
    this.width = 4,
    this.drawn = 1,
    this.opacity = 1,
  });

  final TrackPath path;
  final LineColouring colouring;
  final Color casing;

  /// The ink's opacity, 0–1: below 1 only while a change of colouring
  /// cross-fades (map stage proposal §3.3), when the outgoing line is drawn
  /// over the incoming one without its casing.
  final double opacity;

  /// In pixels, whatever the zoom: the line is a reading, not the tarmac.
  final double width;

  /// How much of the lap the coloured line has drawn, from the start/finish
  /// line: the pen stroke the screen opens with (map stage proposal §8).
  /// The casing is always whole, so the circuit is there before the ink.
  final double drawn;

  @override
  void paint(Canvas canvas, StageView view) {
    final points = path.projection.points;
    if (points.length < 2) return;
    final inked = drawn.clamp(0.0, 1.0) * (points.length - 1);
    final visible = view.visibleMetres.inflate(
      (width + 3) / view.pixelsPerMetre,
    );

    final casingPath = Path();
    final byColour = <Color, Path>{};
    Color? lastColour;
    var joined = false;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (!Rect.fromPoints(a, b).overlaps(visible) &&
          !visible.contains(a) &&
          !visible.contains(b)) {
        joined = false;
        continue;
      }
      final pa = view.toScreen(a);
      final pb = view.toScreen(b);
      if (!joined) casingPath.moveTo(pa.dx, pa.dy);
      casingPath.lineTo(pb.dx, pb.dy);

      if (i >= inked) {
        joined = true;
        lastColour = null;
        continue;
      }
      final end = i + 1 > inked ? Offset.lerp(pa, pb, inked - i)! : pb;
      final colour = colouring.colourAt(i);
      final stroke = byColour.putIfAbsent(colour, Path.new);
      // A run of one colour is one subpath, so its joins are mitred and an
      // alpha colour never darkens where two of its segments overlap.
      if (!joined || colour != lastColour) stroke.moveTo(pa.dx, pa.dy);
      stroke.lineTo(end.dx, end.dy);
      lastColour = colour;
      joined = true;
    }

    if (opacity >= 1) {
      canvas.drawPath(
        casingPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = casing,
      );
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    for (final MapEntry(key: colour, value: stroke) in byColour.entries) {
      canvas.drawPath(
        stroke,
        paint..color = colour.withValues(alpha: colour.a * opacity),
      );
    }
  }

  @override
  bool shouldRepaint(TrackLineLayer old) =>
      !identical(old.path, path) ||
      old.colouring != colouring ||
      old.casing != casing ||
      old.width != width ||
      old.drawn != drawn ||
      old.opacity != opacity;
}

/// A soft band under the stretch of the line the traces are zoomed to (map
/// stage proposal §8, "Trace zoom"): the window is a place on the track.
class WindowCasingLayer implements StageLayer {
  const WindowCasingLayer({
    required this.path,
    required this.start,
    required this.end,
    required this.colour,
    required this.width,
    this.opacity = 1,
  });

  final TrackPath path;

  /// The window, in the path's domain.
  final double start;
  final double end;
  final Color colour;

  /// The line's width; the band is wider by a margin either side.
  final double width;

  /// 0–1, as the band fades in and out.
  final double opacity;

  @override
  void paint(Canvas canvas, StageView view) {
    if (opacity <= 0) return;
    final points = path.projection.points;
    final xs = path.xs;
    final band = Path();
    var joined = false;
    for (var i = 0; i < points.length; i++) {
      if (xs[i] < start || xs[i] > end) {
        joined = false;
        continue;
      }
      final p = view.toScreen(points[i]);
      if (joined) {
        band.lineTo(p.dx, p.dy);
      } else {
        band.moveTo(p.dx, p.dy);
        joined = true;
      }
    }
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour.withValues(alpha: colour.a * opacity),
    );
  }

  @override
  bool shouldRepaint(WindowCasingLayer old) =>
      !identical(old.path, path) ||
      old.start != start ||
      old.end != end ||
      old.colour != colour ||
      old.width != width ||
      old.opacity != opacity;
}

/// Ticks across the line at the start/finish and the sector boundaries.
class TrackMarkerLayer implements StageLayer {
  const TrackMarkerLayer({
    required this.path,
    required this.markers,
    required this.palette,
  });

  final TrackPath path;

  /// `(point index, label)`.
  final List<(int, String)> markers;
  final ChartPalette palette;

  @override
  void paint(Canvas canvas, StageView view) {
    final points = path.projection.points;
    final area = (Offset.zero & view.size).inflate(24);
    for (final (index, label) in markers) {
      if (index < 0 || index >= points.length) continue;
      final at = view.toScreen(points[index]);
      if (!area.contains(at)) continue;
      paintLineTick(
        canvas,
        palette,
        at: at,
        before: view.toScreen(points[math.max(index - 1, 0)]),
        after: view.toScreen(points[math.min(index + 1, points.length - 1)]),
        label: label,
      );
    }
  }

  @override
  bool shouldRepaint(TrackMarkerLayer old) =>
      !identical(old.path, path) ||
      old.markers != markers ||
      old.palette.axisText != palette.axisText;
}

/// A car on the line: Base's solid, a comparison's ghost hollow (§3.3.1).
class CarGlyph {
  const CarGlyph({
    required this.at,
    required this.heading,
    required this.colour,
    this.hollow = false,
    this.litWheel,
    this.wheelColour,
  });

  /// Where, in the map's metres.
  final Offset at;

  /// Unit vector of travel, in the map's metres.
  final Offset heading;
  final Color colour;
  final bool hollow;

  /// The corner the dock follows, lit on the car in [wheelColour] (map
  /// stage P9c, §6.3); null draws no wheels.
  final Corner? litWheel;
  final Color? wheelColour;

  @override
  bool operator ==(Object other) =>
      other is CarGlyph &&
      other.at == at &&
      other.heading == heading &&
      other.colour == colour &&
      other.hollow == hollow &&
      other.litWheel == litWheel &&
      other.wheelColour == wheelColour;

  @override
  int get hashCode =>
      Object.hash(at, heading, colour, hollow, litWheel, wheelColour);
}

/// The cars at the playhead, drawn ghost first so Base sits on top.
class CarLayer implements StageLayer {
  const CarLayer({required this.cars, required this.halo});

  final List<CarGlyph> cars;

  /// The outline that lifts a car off the line beneath it.
  final Color halo;

  /// A car is 5 m long at true scale, and never shorter than this on screen.
  static const minLength = 18.0;

  @override
  void paint(Canvas canvas, StageView view) {
    final length = math.max(5 * view.pixelsPerMetre, minLength);
    final width = length * 0.44;
    for (final car in cars) {
      final at = view.toScreen(car.at);
      if (!(Offset.zero & view.size).inflate(length).contains(at)) continue;
      final shape = _shape(length, width);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(math.atan2(car.heading.dy, car.heading.dx));
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeJoin = StrokeJoin.round
          ..color = halo,
      );
      if (car.hollow) {
        canvas.drawPath(shape, Paint()..color = halo.withValues(alpha: 0.6));
        canvas.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = car.colour,
        );
      } else {
        canvas.drawPath(shape, Paint()..color = car.colour);
      }
      _paintWheels(canvas, car, length, width, halo: halo);
      canvas.restore();
    }
  }

  /// The car's wheels, when one is lit: four small tyres at the body's
  /// sides, the lit one in [CarGlyph.wheelColour] and the rest faint, so the
  /// corner the dock follows reads on the car itself.
  static void _paintWheels(
    Canvas canvas,
    CarGlyph car,
    double length,
    double width, {
    required Color halo,
  }) {
    final lit = car.litWheel;
    if (lit == null) return;
    final size = Size(length * 0.2, math.max(width * 0.24, 2.4));
    final axle = length * 0.28;
    for (final corner in Corner.values) {
      // The nose points along +x; on a y-down screen the car's left is -y.
      final centre = Offset(
        corner.isFront ? axle : -axle,
        (corner.isLeft ? -1 : 1) * (width / 2 - size.height * 0.2),
      );
      final tyre = RRect.fromRectAndRadius(
        Rect.fromCenter(center: centre, width: size.width, height: size.height),
        Radius.circular(size.height / 2),
      );
      final on = corner == lit;
      canvas.drawRRect(tyre.inflate(1), Paint()..color = halo);
      canvas.drawRRect(
        on ? tyre.inflate(0.6) : tyre,
        Paint()
          ..color = on
              ? car.wheelColour ?? car.colour
              : car.colour.withValues(alpha: 0.4),
      );
    }
  }

  /// A body with a pointed nose, pointing along +x, centred on the origin.
  static Path _shape(double length, double width) {
    final half = length / 2;
    final side = width / 2;
    final nose = half - side;
    return Path()
      ..moveTo(-half + 2, -side)
      ..lineTo(nose, -side)
      ..lineTo(half, 0)
      ..lineTo(nose, side)
      ..lineTo(-half + 2, side)
      ..quadraticBezierTo(-half, side, -half, side - 2)
      ..lineTo(-half, -side + 2)
      ..quadraticBezierTo(-half, -side, -half + 2, -side)
      ..close();
  }

  @override
  bool shouldRepaint(CarLayer old) =>
      old.halo != halo || !listEquals(old.cars, cars);
}

/// Where the pointer is reading, on the line: a faint ring that moves
/// nothing (§5).
class ProbeLayer implements StageLayer {
  const ProbeLayer({
    required this.at,
    required this.colour,
    required this.halo,
  });

  /// In the map's metres; null draws nothing.
  final Offset? at;
  final Color colour;
  final Color halo;

  @override
  void paint(Canvas canvas, StageView view) {
    final metres = at;
    if (metres == null) return;
    final p = view.toScreen(metres);
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = halo.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      p,
      6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(ProbeLayer old) =>
      old.at != at || old.colour != colour || old.halo != halo;
}

/// A round distance in the bottom-left corner: the one absolute fact a
/// local projection can report.
class ScaleBarLayer implements StageLayer {
  const ScaleBarLayer({
    required this.palette,
    this.inset = const Offset(12, 12),
  });

  final ChartPalette palette;

  /// From the bottom-left corner, in pixels.
  final Offset inset;

  static const _candidates = [
    5.0,
    10.0,
    20.0,
    50.0,
    100.0,
    200.0,
    250.0,
    500.0,
    1000.0,
    2000.0,
  ];

  /// The longest round distance at most [maxPixels] long.
  static double roundMetres(double pixelsPerMetre, double maxPixels) {
    var metres = _candidates.first;
    for (final candidate in _candidates) {
      if (candidate * pixelsPerMetre <= maxPixels) metres = candidate;
    }
    return metres;
  }

  @override
  void paint(Canvas canvas, StageView view) {
    final ppm = view.pixelsPerMetre;
    if (ppm <= 0) return;
    final metres = roundMetres(ppm, view.size.width / 4);
    final length = metres * ppm;
    final x = inset.dx;
    final y = view.size.height - inset.dy;
    final paint = Paint()
      ..color = palette.axisText.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(x, y), Offset(x + length, y), paint);
    canvas.drawLine(Offset(x, y - 3), Offset(x, y + 3), paint);
    canvas.drawLine(
      Offset(x + length, y - 3),
      Offset(x + length, y + 3),
      paint,
    );
    paintText(
      canvas,
      metres >= 1000
          ? '${(metres / 1000).toStringAsFixed(0)} km'
          : '${metres.toStringAsFixed(0)} m',
      palette.labelStyle,
      Offset(x, y - 17),
    );
  }

  @override
  bool shouldRepaint(ScaleBarLayer old) =>
      old.palette.axisText != palette.axisText || old.inset != inset;
}

/// Stretches of the line marked under it: where a lap ran over kerbs and off
/// the track (map stage P9d). A kerb is a striped casing, as the kerb is; off
/// the track a wider, solid one in the colour of the run-off.
class SurfaceLayer implements StageLayer {
  const SurfaceLayer({
    required this.path,
    required this.kerbs,
    required this.offTrack,
    required this.kerbColour,
    required this.offTrackColour,
    required this.width,
  });

  final TrackPath path;

  /// `(start, end)` in the path's domain.
  final List<(double, double)> kerbs;
  final List<(double, double)> offTrack;
  final Color kerbColour;
  final Color offTrackColour;

  /// The line's width; the casings are wider by a margin either side.
  final double width;

  @override
  void paint(Canvas canvas, StageView view) {
    for (final stretch in offTrack) {
      final points = _pointsOf(stretch, view);
      if (points.length < 2) continue;
      canvas.drawPath(
        Path()..addPolygon(points, false),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = offTrackColour,
      );
    }
    for (final stretch in kerbs) {
      final points = _pointsOf(stretch, view);
      if (points.length < 2) continue;
      canvas.drawPath(
        dashedPolyline(points, dash: 4, gap: 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 6
          ..strokeCap = StrokeCap.butt
          ..color = kerbColour,
      );
    }
  }

  /// [stretch]'s points on screen, one sample beyond either end so a stretch
  /// shorter than the samples' spacing still shows.
  List<Offset> _pointsOf((double, double) stretch, StageView view) {
    final (start, end) = stretch;
    final xs = path.xs;
    final points = path.projection.points;
    var first = _lowerBound(xs, start);
    var last = _lowerBound(xs, end);
    first = (first - 1).clamp(0, xs.length - 1);
    last = last.clamp(0, xs.length - 1);
    return [for (var i = first; i <= last; i++) view.toScreen(points[i])];
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
  bool shouldRepaint(SurfaceLayer old) =>
      !identical(old.path, path) ||
      !listEquals(old.kerbs, kerbs) ||
      !listEquals(old.offTrack, offTrack) ||
      old.kerbColour != kerbColour ||
      old.offTrackColour != offTrackColour ||
      old.width != width;
}

/// Two breaths of a ring around the car where a link lands (map stage P9e,
/// §6.4), so the eye finds it on a map it has not seen yet.
class ArrivalPulseLayer implements StageLayer {
  const ArrivalPulseLayer({
    required this.at,
    required this.progress,
    required this.colour,
  });

  /// In the map's metres.
  final Offset at;

  /// 0–1 through both breaths.
  final double progress;
  final Color colour;

  /// How far a breath's ring grows, in pixels from the car's centre.
  static const _from = 10.0;
  static const _to = 34.0;

  @override
  void paint(Canvas canvas, StageView view) {
    if (progress <= 0 || progress >= 1) return;
    final p = view.toScreen(at);
    // Each breath is half the run: the ring springs out and fades as it
    // goes, the fade on the clock rather than the spring, so it is seen at
    // full strength before it thins.
    final u = (progress * 2) % 1;
    final radius = _from + (_to - _from) * Curves.easeOutCubic.transform(u);
    final fade = 1 - Curves.easeIn.transform(u);
    canvas.drawCircle(
      p,
      radius,
      Paint()..color = colour.withValues(alpha: 0.18 * fade),
    );
    canvas.drawCircle(
      p,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = colour.withValues(alpha: 0.9 * fade),
    );
  }

  @override
  bool shouldRepaint(ArrivalPulseLayer old) =>
      old.at != at || old.progress != progress || old.colour != colour;
}
