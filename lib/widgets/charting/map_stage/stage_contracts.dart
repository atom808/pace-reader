/// The seams the map stage is built on (map stage proposal §10, §14).
///
/// The stage paints a list of [StageLayer]s through one camera, and colours
/// its line through one [LineColouring]: a new overlay or a new colouring is
/// a new class, never an edit to the stage (open/closed), and the stage
/// depends on these two interfaces rather than on any one of them.
library;

import 'dart:ui';

import 'camera.dart';

/// What a layer paints through: the camera and the screen it fills.
class StageView {
  const StageView({required this.camera, required this.size});

  final MapCamera camera;
  final Size size;

  /// The metres on screen, for culling.
  Rect get visibleMetres => camera.visibleMetres(size);

  Offset toScreen(Offset metres) => camera.toScreen(metres);

  double get pixelsPerMetre => camera.pixelsPerMetre;
}

/// One thing drawn on the map: the line, the markers, the cars, the probe.
///
/// Layers are immutable descriptions, rebuilt with the widget; the stage
/// repaints when the camera moves or any layer says it changed.
abstract interface class StageLayer {
  void paint(Canvas canvas, StageView view);

  /// Whether this layer draws differently from [old], a layer of the same
  /// type in the same slot.
  bool shouldRepaint(covariant StageLayer old);
}

/// What colour each stretch of the line is.
abstract interface class LineColouring {
  /// The colour of the segment from point [segment] to the next.
  Color colourAt(int segment);

  /// What the colours mean, for the legend: "Inputs", "Speed (km/h)".
  String get label;
}

/// A host's own reading of the line under the pointer, in place of the
/// shared probe and playhead: an inset map on a screen with no lap clock
/// (Driving Technique's segments, map stage proposal §9). Kept apart from
/// [StageLayer] so a passive overlay never stubs a hit test (§14.2).
abstract interface class StageHitTarget {
  /// The pointer is over the line at `Lap Dist` [station], or off it (null).
  void hover(double? station);

  /// A click on the line at [station], or off it (null).
  void tap(double? station);
}
