/// How the stage's camera moves over time (map stage proposal §4).
///
/// [MapCamera] says where the camera is; this says how it gets where it is
/// going: a critically damped spring, so it glides into place and never
/// overshoots, and a low-pass on speed, so the speed-linked zoom breathes
/// rather than twitches. Plain Dart: the widget ticks it.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'camera.dart';

/// What the camera is doing.
enum CameraMode {
  /// Tracking the playhead's car (the default, D10).
  follow,

  /// Where the user put it: any drag, or a wheel outside Follow.
  free,

  /// The whole lap, or the trace window when the traces are zoomed.
  fit,
}

/// A critically damped spring from the current camera to a target one.
///
/// Centre and focus move in pixels' worth of metres; zoom moves in log
/// space, so zooming in 2× and out 2× take the same time.
class CameraRig {
  CameraRig({required MapCamera initial, this.omega = 14})
    : _current = initial,
      target = initial;

  /// Stiffness, in radians per second: ω ≈ 14 settles in about a third of a
  /// second.
  final double omega;

  /// Where the camera is heading; set it every frame, the spring follows.
  MapCamera target;

  MapCamera _current;
  Offset _centreVelocity = Offset.zero;
  Offset _focusVelocity = Offset.zero;
  double _zoomVelocity = 0;

  MapCamera get current => _current;

  /// Goes straight to [camera], dropping any motion: reduced motion, the
  /// first frame, or a gesture that has to track the pointer exactly.
  void jumpTo(MapCamera camera) {
    _current = camera;
    target = camera;
    _centreVelocity = Offset.zero;
    _focusVelocity = Offset.zero;
    _zoomVelocity = 0;
  }

  /// True once the camera is within a tenth of a pixel of its target and
  /// barely moving: the ticker can stop.
  bool get settled {
    final ppm = _current.pixelsPerMetre;
    final centrePixels = (target.centre - _current.centre).distance * ppm;
    final focusPixels = (target.focus - _current.focus).distance;
    final zoom =
        (math.log(target.pixelsPerMetre) - math.log(_current.pixelsPerMetre))
            .abs();
    return centrePixels < 0.1 &&
        focusPixels < 0.1 &&
        zoom < 1e-4 &&
        _centreVelocity.distance * ppm < 1 &&
        _focusVelocity.distance < 1 &&
        _zoomVelocity.abs() < 1e-3;
  }

  /// Advances [seconds]. Long frames are split into steps of at most 1/120 s
  /// so the spring stays stable however late a frame arrives.
  void step(double seconds) {
    var left = math.min(seconds, 0.25);
    while (left > 0) {
      final dt = math.min(left, 1 / 120);
      _stepOnce(dt);
      left -= dt;
    }
    if (settled) jumpTo(target);
  }

  void _stepOnce(double dt) {
    final k = omega * omega;
    final c = 2 * omega;

    final centreAccel =
        (target.centre - _current.centre) * k - _centreVelocity * c;
    _centreVelocity += centreAccel * dt;

    final focusAccel = (target.focus - _current.focus) * k - _focusVelocity * c;
    _focusVelocity += focusAccel * dt;

    final logNow = math.log(_current.pixelsPerMetre);
    final logTarget = math.log(target.pixelsPerMetre);
    final zoomAccel = (logTarget - logNow) * k - _zoomVelocity * c;
    _zoomVelocity += zoomAccel * dt;

    _current = MapCamera(
      centre: _current.centre + _centreVelocity * dt,
      focus: _current.focus + _focusVelocity * dt,
      pixelsPerMetre: math.exp(logNow + _zoomVelocity * dt),
    );
  }
}

/// A one-pole low-pass: what the speed-linked zoom reads instead of the raw
/// speed, so a kerb's wheelspin never reaches the camera (D11: τ ≈ 1.5 s).
class LowPass {
  LowPass({this.seconds = 1.5});

  final double seconds;
  double? _value;

  double? get value => _value;

  /// Folds [sample] in over [dt] seconds; the first sample is taken as is.
  double add(double sample, double dt) {
    final v = _value;
    if (v == null) return _value = sample;
    final a = 1 - math.exp(-math.max(dt, 0) / seconds);
    return _value = v + (sample - v) * a;
  }

  void reset() => _value = null;
}
