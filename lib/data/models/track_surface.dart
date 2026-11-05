/// What the wheels were on: `SurfaceTypes` decoded (SPEC.md §5, decoded
/// 2026-11-04 from a filmed Le Mans lap), and a lap's kerb and off-track
/// stretches built from it (map stage P9d).
library;

import 'step_series.dart';

/// `SurfaceTypes` codes, one per wheel.
abstract final class SurfaceCode {
  static const track = 0;
  static const grass = 2;
  static const gravel = 4;
  static const kerb = 5;
  static const paint = 6;

  /// 2–4 samples a file at Le Mans and Barcelona; treated as track.
  static const unknown = 30;

  /// A kerb's red and white alternate between 5 and 6 every 10–30 ms, so
  /// both are the kerb; a painted run-off reads 6 as well.
  static bool isKerb(int? code) => code == kerb || code == paint;
  static bool isOffTrack(int? code) => code == grass || code == gravel;
}

/// Off the asphalt, by how far.
enum TrackSurface {
  kerb('Kerb'),
  offTrack('Off track');

  const TrackSurface(this.label);

  final String label;
}

/// A stretch of a lap with a wheel off the asphalt, in the recording's
/// seconds.
class SurfaceStretch {
  const SurfaceStretch(this.surface, this.startSeconds, this.endSeconds);

  /// The furthest any wheel went: off track over kerb.
  final TrackSurface surface;
  final double startSeconds;
  final double endSeconds;

  @override
  bool operator ==(Object other) =>
      other is SurfaceStretch &&
      other.surface == surface &&
      other.startSeconds == startSeconds &&
      other.endSeconds == endSeconds;

  @override
  int get hashCode => Object.hash(surface, startSeconds, endSeconds);

  @override
  String toString() =>
      'SurfaceStretch(${surface.name}, $startSeconds–$endSeconds)';
}

/// Two stretches of one surface closer than this are one: a wheel skipping
/// along a kerb's ridges leaves it for a few samples at a time.
const surfaceJoinSeconds = 0.25;

/// The stretches of `[start, end]` where any of [wheels] was on a kerb or off
/// the track, in order, each the furthest any wheel went.
///
/// [wheels] are `SurfaceTypes`' four columns over the window, each with its
/// value at [start] (a step series reaching back before the window).
List<SurfaceStretch> surfaceStretches(
  List<StepSeries> wheels, {
  required double start,
  required double end,
}) {
  final changes = <double>{
    start,
    for (final w in wheels)
      for (final t in w.times)
        if (t > start && t < end) t,
  }.toList()..sort();

  TrackSurface? at(double t) {
    var kerb = false;
    for (final w in wheels) {
      final code = w.valueAt(t)?.round();
      if (SurfaceCode.isOffTrack(code)) return TrackSurface.offTrack;
      if (SurfaceCode.isKerb(code)) kerb = true;
    }
    return kerb ? TrackSurface.kerb : null;
  }

  final out = <SurfaceStretch>[];
  for (var i = 0; i < changes.length; i++) {
    final surface = at(changes[i]);
    if (surface == null) continue;
    final from = changes[i];
    final to = i + 1 < changes.length ? changes[i + 1] : end;
    final last = out.isEmpty ? null : out.last;
    if (last != null &&
        last.surface == surface &&
        from - last.endSeconds < surfaceJoinSeconds) {
      out[out.length - 1] = SurfaceStretch(surface, last.startSeconds, to);
    } else {
      out.add(SurfaceStretch(surface, from, to));
    }
  }
  return out;
}
