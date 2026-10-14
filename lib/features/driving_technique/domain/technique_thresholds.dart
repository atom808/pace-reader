/// Every threshold Driving Technique uses, each with the measurement that set
/// it (SPEC.md §8.13.1, §8.13.3).
///
/// Named here rather than inlined in the queries, as `segment_findings.dart`
/// does for Compare: a number that decides what a lap is credited with should
/// be findable, and should say where it came from.
library;

abstract final class TechniqueThresholds {
  /// A pedal counts as applied above this (%). Values in (0, 2] are
  /// transits: a median of one 20 ms sample between off and on.
  static const applied = 2.0;

  /// Full throttle is the pedal at or above this (%), not exactly 100: late in
  /// long races the pedal stops reaching 100.0 (Imola's 127-lap GT3 race
  /// spends 50–60 % of its flat-out time at 99–<100 from lap 102). Thresholds
  /// of 98 and 99 differ by under one point everywhere.
  static const fullThrottle = 98.0;

  /// The wheel counts as turned at or above this |Steering Pos| (%). On
  /// straights |steer| has p99 1.2–3.5 %.
  static const turned = 5.0;

  /// `Steering Pos` stored as a fraction (−1 to +1) in every file recorded
  /// before April 2026. A session maximum at or under this is read ×100, so
  /// the newest recordings' percentage is the unit (§8.13.1). No timed lap
  /// sits between 1.0 and 30.
  static const steeringFractionMax = 1.0;

  /// TC and ABS switch in 10–20 ms pulses with 2.5–10 ms gaps. Pulses closer
  /// than this (s) are one episode.
  static const pulseMerge = 0.25;

  /// The sustained peak is the lap's maximum of combined G's rolling minimum
  /// over this many 10 Hz samples (0.3 s). Per-lap CV 2.6–8.4 %, against up
  /// to 68 % for the raw maximum, which kerbs and impacts own.
  static const sustainedSamples = 3;

  /// Grip utilisation averages combined G ÷ E over samples at or above this
  /// (G): straights would otherwise dilute it toward zero.
  static const utilisationFloor = 0.5;

  /// The envelope E, and each direction's limit, is this quantile of the
  /// session's racing samples.
  static const envelopeQuantile = 0.99;

  /// The envelope is drawn per speed band too (km/h): braking p99 is
  /// 1.32–1.86 G below 150 against 1.76–2.79 G above 200.
  static const speedBandEdges = [150.0, 200.0];

  /// The G-G density grid's cell (G). A session holds at most 5,720 cells.
  static const ggCell = 0.05;

  /// Countersteer: steering against the turn, |steer| ≥ [turned] with the
  /// sign of lateral G, |lateral G| ≥ this, above [countersteerSpeed], for at
  /// least [countersteerSamples] consecutive 10 Hz samples peaking at
  /// [countersteerPeak] % lock. Spa qualifying's lap 3 is the ground truth.
  static const countersteerLateralG = 0.5;
  static const countersteerSpeed = 60.0;
  static const countersteerSamples = 3;
  static const countersteerPeak = 20.0;

  /// Shift RPM is the maximum `Engine RPM` in this many seconds before the
  /// neutral row.
  static const shiftRpmWindow = 0.3;

  /// da compares Ground Speed's acceleration over this many seconds after the
  /// neutral row with the same span before it.
  static const shiftAccelerationWindow = 0.25;

  /// RPM within this of the limiter counts as on it, for limiter time before
  /// an upshift (the limiter holds RPM at L−100…L).
  static const limiterMargin = 100.0;

  /// Wet means `Minimum Path Wetness` at or above this (%) at some point of
  /// the lap. The library's values are 0, 5, 12.5, 40 and 60.
  static const wetFrom = 12.5;

  /// A lens group drops laps slower than this multiple of its own median:
  /// traffic and mistakes, which would otherwise own a group's mean.
  static const lensOutlier = 1.05;

  /// A lens needs at least this many laps either side.
  static const lensMinimumLaps = 3;

  /// A change under this many standard errors is drawn as noise.
  static const noiseStandardErrors = 2.0;
}
