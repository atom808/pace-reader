/// What Driving Technique's queries return, as plain numbers (SPEC.md
/// §8.13.9).
library;

import 'dart:typed_data';

/// The pedal frame's counts over a lap, or over one stretch of one.
class PedalTotals {
  const PedalTotals({
    required this.samples,
    required this.hz,
    this.braking = 0,
    this.overlap = 0,
    this.coast = 0,
    this.fullThrottle = 0,
    this.trail = 0,
    this.tc = 0,
    this.abs = 0,
    this.coastMetres = 0,
    this.slowest,
    this.steerAtApex,
  });

  /// 50 Hz pedal samples; a racing lap holds 50 × its `Lap Time` of them to
  /// within 0.9 (§8.13.2).
  final int samples;

  /// The pedal frame's rate.
  final int hz;

  /// Samples with the brake applied (> 2 %).
  final int braking;

  /// Both pedals applied.
  final int overlap;

  /// Both pedals at exactly 0.
  final int coast;

  /// The pedal at ≥ 98 %.
  final int fullThrottle;

  /// Braking with |steer| ≥ 5 %.
  final int trail;

  /// TC or ABS flag on.
  final int tc;
  final int abs;

  /// `Lap Dist` covered while coasting, metres.
  final double coastMetres;

  /// The slowest Ground Speed, km/h.
  final double? slowest;

  /// `Steering Pos` at a corner's apex, % (+ right); null for a lap or
  /// segment.
  final double? steerAtApex;

  double seconds(int count) => count / hz;
  double share(int count) => samples == 0 ? 0 : count / samples;

  double get durationSeconds => seconds(samples);

  /// Braking with the wheel turned, as a share of braking.
  double? get trailShare => braking == 0 ? null : trail / braking;
}

/// The pedal frame's totals: per lap, and per lap and stretch.
class PedalReads {
  const PedalReads({
    required this.laps,
    this.segments = const {},
    this.corners = const {},
  });

  /// Keyed by `Lap.index`.
  final Map<int, PedalTotals> laps;

  /// Lap → stretch key → totals.
  final Map<int, Map<int, PedalTotals>> segments;
  final Map<int, Map<int, PedalTotals>> corners;
}

/// One lap's G-G summary.
class GgLap {
  const GgLap({
    required this.samples,
    this.sustainedPeak,
    this.utilisationSum = 0,
    this.utilisationSamples = 0,
  });

  final int samples;

  /// The lap's maximum of combined G's 0.3 s rolling minimum.
  final double? sustainedPeak;
  final double utilisationSum;
  final int utilisationSamples;

  /// The lap's mean of combined G ÷ E over samples at or above 0.5 G.
  double? get utilisation =>
      utilisationSamples == 0 ? null : utilisationSum / utilisationSamples;
}

/// One stretch of one lap in the G frame.
class GgStretch {
  const GgStretch({
    this.peakLateral,
    this.utilisationSum = 0,
    this.utilisationSamples = 0,
  });

  /// The largest |lateral G|.
  final double? peakLateral;
  final double utilisationSum;
  final int utilisationSamples;

  double? get utilisation =>
      utilisationSamples == 0 ? null : utilisationSum / utilisationSamples;
}

/// The session's direction limits in one speed band.
class GgLimits {
  const GgLimits({
    required this.braking,
    required this.traction,
    required this.lateral,
  });

  /// p99 of each, in G: braking (+), traction (accelerating), |lateral|.
  final double braking;
  final double traction;
  final double lateral;
}

/// The speed bands the envelope is drawn in (km/h).
enum SpeedBand {
  slow('under 150 km/h'),
  medium('150–200 km/h'),
  fast('200 km/h and over'),
  all('all speeds');

  const SpeedBand(this.label);

  final String label;
}

/// The G frame reduced over the session's racing laps.
class GgReads {
  const GgReads({
    required this.laps,
    required this.envelope,
    required this.density,
    required this.limits,
    this.e,
    this.segments = const {},
    this.corners = const {},
  });

  final Map<int, GgLap> laps;
  final Map<int, Map<int, GgStretch>> segments;
  final Map<int, Map<int, GgStretch>> corners;

  /// Per band, 36 bins of 10° (bin k covers k×10°−180° to (k+1)×10°−180° of
  /// atan2(braking, −lateral)): the p99 of combined G and the sample count.
  final Map<SpeedBand, Map<int, ({double g, int n})>> envelope;

  /// (cell x, cell y) → samples, cells of 0.05 G of (−lateral, braking).
  final Map<(int, int), int> density;
  final Map<SpeedBand, GgLimits> limits;

  /// The session's p99 of combined G: utilisation's denominator.
  final double? e;
}

/// One 10 Hz G-G point of a lap.
class GgPoint {
  const GgPoint({
    required this.station,
    required this.lateral,
    required this.longitudinal,
    this.speed,
    this.throttle,
    this.brake,
  });

  /// `Lap Dist`, m.
  final double station;

  /// + left.
  final double lateral;

  /// + braking.
  final double longitudinal;
  final double? speed;
  final double? throttle;
  final double? brake;
}

/// One lap's 10 Hz path and speed, for detecting segments and corners.
class LapProfileRead {
  const LapProfileRead({
    required this.lap,
    required this.times,
    required this.distances,
    required this.speeds,
    required this.latitudes,
    required this.longitudes,
  });

  final int lap;
  final Float64List times;
  final Float64List distances;

  /// The low of each 10 Hz row's ten Ground Speed samples.
  final Float64List speeds;
  final Float64List latitudes;
  final Float64List longitudes;
}
