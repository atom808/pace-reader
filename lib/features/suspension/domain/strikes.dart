/// Strikes: where a corner of the car reached the floor (suspension proposal
/// §5). Candidate samples come from `strikeSamplesSql`; this merges them,
/// says how deep each went, and labels it by phase and surface.
library;

import '../../../data/models/models.dart';
import 'suspension_thresholds.dart';

/// One 100 Hz sample with a corner under the Close ceiling.
class StrikeSample {
  const StrikeSample({
    required this.row,
    required this.seconds,
    required this.lap,
    required this.heights,
    this.speed,
    this.brake,
    this.station,
    this.line,
    this.lateralG,
    this.longitudinalG,
    this.verticalG,
    this.surfaces = const [null, null, null, null],
  });

  /// The master row.
  final int row;
  final double seconds;
  final int lap;

  /// FL, FR, RL, RR ride height, m.
  final List<double> heights;
  final double? speed;
  final double? brake;
  final double? station;

  /// `Path Lateral`, m: + right of the centre line, − left (§3.1: the grass
  /// 23–27 m left of centre read against an edge at −6 m).
  final double? line;

  /// + left.
  final double? lateralG;

  /// + slowing.
  final double? longitudinalG;
  final double? verticalG;

  /// `SurfaceTypes` per corner; null where the file has no such event.
  final List<int?> surfaces;

  /// The lowest corner and its height.
  (Corner, double) get lowest {
    var at = 0;
    for (var i = 1; i < 4; i++) {
      if (heights[i] < heights[at]) at = i;
    }
    return (Corner.values[at], heights[at]);
  }
}

/// How deep a strike went (D6).
enum StrikeTier {
  /// Under the floor: the headline.
  strike('Strike'),

  /// Within [closeBandMetres] above it: drawn fainter, left out of counts.
  close('Close');

  const StrikeTier(this.label);

  final String label;
}

/// When in the corner it happened (§5, D3).
enum StrikePhase {
  straight(
    'Straight',
    'Touched down with no brake and no cornering load: a bump, a crest, or '
        'the aero load at speed.',
  ),
  braking(
    'Braking',
    'Touched down under braking: the nose dives as the load moves forward.',
  ),
  corner(
    'Corner',
    'Touched down while cornering: the outside corners compress as the car '
        'rolls.',
  ),
  brakingCorner(
    'Braking into a corner',
    'Touched down braking and turning at once: dive and roll together load '
        'the outside front.',
  );

  const StrikePhase(this.label, this.meaning);

  final String label;

  /// One plain sentence, for subtitles and tooltips.
  final String meaning;

  /// Braking and braking-into-a-corner share the Braking card (§4.2).
  bool get isBraking => this == braking || this == brakingCorner;
}

/// What the wheels were on (§3.1).
enum StrikeSurface {
  track('Track'),
  kerb('Kerb'),
  offTrack('Off track');

  const StrikeSurface(this.label);

  final String label;
}

/// One merged strike.
class Strike {
  const Strike({
    required this.lap,
    required this.seconds,
    required this.row,
    required this.depth,
    required this.corner,
    required this.tier,
    required this.phase,
    required this.surface,
    required this.samples,
    this.station,
    this.line,
    this.speed,
    this.maxBrake,
    this.lateralG,
    this.longitudinalG,
    this.peakVerticalG,
  });

  final int lap;

  /// At the lowest point.
  final double seconds;
  final int row;

  /// The lowest ride height, m. Negative on track counts (§3, run H).
  final double depth;
  final Corner corner;
  final StrikeTier tier;
  final StrikePhase phase;
  final StrikeSurface surface;

  /// How many 100 Hz samples it spans.
  final int samples;

  /// `Lap Dist` at the lowest point, interpolated, m.
  final double? station;
  final double? line;
  final double? speed;
  final double? maxBrake;
  final double? lateralG;
  final double? longitudinalG;

  /// The largest |vertical G| during it, signed.
  final double? peakVerticalG;

  bool get isFront => corner.isFront;
  double get depthMm => depth * 1000;
}

/// The phase at a strike's lowest point (§5): braking on the pedal anywhere
/// in it or on deceleration at the lowest point, cornering on lateral G.
StrikePhase phaseOf({
  double? maxBrake,
  double? longitudinalG,
  double? lateralG,
}) {
  final braking =
      (maxBrake ?? 0) > brakingPedalPercent ||
      (longitudinalG ?? 0) > brakingDecelerationG;
  final cornering = (lateralG ?? 0).abs() > cornerLateralG;
  return switch ((braking, cornering)) {
    (true, true) => StrikePhase.brakingCorner,
    (true, false) => StrikePhase.braking,
    (false, true) => StrikePhase.corner,
    (false, false) => StrikePhase.straight,
  };
}

/// Off track if any wheel was on grass or gravel at any point, else kerb if
/// any was on a kerb or paint, else track (§3.1). A strike that touched a
/// kerb is a kerb strike even when its lowest sample was on asphalt.
StrikeSurface surfaceOf(Iterable<List<int?>> samples) {
  var kerb = false;
  for (final codes in samples) {
    for (final code in codes) {
      if (SurfaceCode.isOffTrack(code)) return StrikeSurface.offTrack;
      if (SurfaceCode.isKerb(code)) kerb = true;
    }
  }
  return kerb ? StrikeSurface.kerb : StrikeSurface.track;
}

/// Merges [samples] (in row order) into strikes: samples of one lap less
/// than [strikeMergeGapRows] apart are one.
///
/// A merged run that never goes under [strikeFloorMetres] is Close; one
/// that does is a Strike. Negative heights are kept: the BMW at Sebring reads
/// −6.6 to −10.5 mm on asphalt at one bump on three laps (§3), the deepest
/// strikes of the session, not a glitch. Off track they are kept too but
/// tagged, and sites leave them out.
List<Strike> mergeStrikes(List<StrikeSample> samples) {
  final out = <Strike>[];
  var start = 0;
  while (start < samples.length) {
    var end = start + 1;
    while (end < samples.length &&
        samples[end].lap == samples[start].lap &&
        samples[end].row - samples[end - 1].row < strikeMergeGapRows) {
      end++;
    }
    out.add(_strikeOf(samples.sublist(start, end)));
    start = end;
  }
  return out;
}

Strike _strikeOf(List<StrikeSample> run) {
  var low = run.first;
  var (corner, depth) = low.lowest;
  double? maxBrake;
  double? peakVertical;
  for (final s in run) {
    final (c, h) = s.lowest;
    if (h < depth) {
      low = s;
      corner = c;
      depth = h;
    }
    if (s.brake case final b?) {
      if (maxBrake == null || b > maxBrake) maxBrake = b;
    }
    if (s.verticalG case final g?) {
      if (peakVertical == null || g.abs() > peakVertical.abs()) {
        peakVertical = g;
      }
    }
  }
  return Strike(
    lap: low.lap,
    seconds: low.seconds,
    row: low.row,
    depth: depth,
    corner: corner,
    tier: depth < strikeFloorMetres ? StrikeTier.strike : StrikeTier.close,
    phase: phaseOf(
      maxBrake: maxBrake,
      longitudinalG: low.longitudinalG,
      lateralG: low.lateralG,
    ),
    surface: surfaceOf(run.map((s) => s.surfaces)),
    samples: run.length,
    station: low.station,
    line: low.line,
    speed: low.speed,
    maxBrake: maxBrake,
    lateralG: low.lateralG,
    longitudinalG: low.longitudinalG,
    peakVerticalG: peakVertical,
  );
}
