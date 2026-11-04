/// The map stage's camera (map stage proposal §4).
///
/// Plain Dart over `dart:ui`'s geometry types: what the camera *is* (where it
/// looks, how close) and the arithmetic around it. How it moves over time —
/// the spring, the modes — is [CameraRig]'s, in `camera_rig.dart`.
///
/// The map's metres are the projection's: x east, y south (north up on
/// screen), as `TrackProjection` lays them out.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// Where the camera looks and how close: [centre] metres are drawn at
/// [focus] pixels, [pixelsPerMetre] apart.
class MapCamera {
  const MapCamera({
    required this.centre,
    required this.pixelsPerMetre,
    required this.focus,
  });

  final Offset centre;
  final double pixelsPerMetre;

  /// Where on screen [centre] sits: the middle of the *visible* map, which
  /// on the stage is left of the dock rather than the middle of the window.
  final Offset focus;

  Offset toScreen(Offset metres) => (metres - centre) * pixelsPerMetre + focus;

  Offset toMetres(Offset pixels) => (pixels - focus) / pixelsPerMetre + centre;

  /// The metres a [size] screen shows.
  Rect visibleMetres(Size size) => Rect.fromPoints(
    toMetres(Offset.zero),
    toMetres(size.bottomRight(Offset.zero)),
  );

  MapCamera copyWith({Offset? centre, double? pixelsPerMetre, Offset? focus}) =>
      MapCamera(
        centre: centre ?? this.centre,
        pixelsPerMetre: pixelsPerMetre ?? this.pixelsPerMetre,
        focus: focus ?? this.focus,
      );

  /// Zoomed by [factor] about [pixels], which keeps the metres under it
  /// (a wheel zooms where the pointer is).
  MapCamera zoomedAbout(Offset pixels, double factor) {
    final anchor = toMetres(pixels);
    final ppm = pixelsPerMetre * factor;
    return copyWith(
      pixelsPerMetre: ppm,
      centre: anchor - (pixels - focus) / ppm,
    );
  }

  /// Moved by a drag of [pixels]: the map follows the pointer.
  MapCamera pannedBy(Offset pixels) =>
      copyWith(centre: centre - pixels / pixelsPerMetre);

  /// The camera that shows all of [metres] inside [viewport], [padding]
  /// pixels clear of its edges, centred on it.
  static MapCamera fit(Rect metres, Rect viewport, {double padding = 24}) {
    final w = math.max(viewport.width - padding * 2, 1.0);
    final h = math.max(viewport.height - padding * 2, 1.0);
    final ppm = math.min(
      w / math.max(metres.width, 1e-6),
      h / math.max(metres.height, 1e-6),
    );
    return MapCamera(
      centre: metres.center,
      pixelsPerMetre: ppm,
      focus: viewport.center,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MapCamera &&
      other.centre == centre &&
      other.pixelsPerMetre == pixelsPerMetre &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(centre, pixelsPerMetre, focus);

  @override
  String toString() =>
      'MapCamera($centre, ${pixelsPerMetre.toStringAsFixed(3)} px/m)';
}

/// How far ahead of the car Follow looks: 0.6 s at the car's speed, but
/// never more than a quarter of the view, so a car at 330 km/h stays on
/// screen (proposal §4).
Offset lookAhead({
  required Offset heading,
  required double metresPerSecond,
  required double viewMetres,
}) {
  final length = heading.distance;
  if (length == 0 || metresPerSecond <= 0) return Offset.zero;
  final metres = math.min(0.6 * metresPerSecond, 0.25 * viewMetres);
  return heading / length * metres;
}

/// How much the speed-linked zoom breathes around the chosen zoom: ±12 %
/// (D11). Slow is closer.
const speedZoomSwing = 0.12;

/// The zoom multiplier for a speed at [fraction] of the lap's range
/// (0 = its slowest, 1 = its fastest): 1.12 at the slowest, 0.88 at the
/// fastest.
double speedZoomFactor(double fraction) =>
    1 + speedZoomSwing * (1 - 2 * fraction.clamp(0.0, 1.0));

/// The closest the camera may get: a 5 m car at a sixth of the view's
/// height (proposal §4).
double maxPixelsPerMetre(Size view) => math.max(view.height, 1) / 6 / 5;
