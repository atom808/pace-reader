/// `Steering Pos`'s unit (SPEC.md §8.13.1).
library;

import 'technique_thresholds.dart';

/// The factor that puts a file's `Steering Pos` in percent, from the
/// session's largest |value|.
///
/// All 154 scanned recordings from February and March 2026 store a fraction
/// (−1 to +1); every later one a percentage (−100 to +100). The newest
/// recordings define the unit and older files are converted to match, on the
/// data's own range: `metadata.Version` stays "1" across the change. No timed
/// lap is ambiguous — every file with one has a maximum either ≤ 1.0 (all 64
/// timed February–March files) or ≥ 30 (all 234 later ones).
///
/// A file with no steering samples reads as already in percent: there is
/// nothing to convert.
double steeringScale(double? sessionMaxAbs) =>
    sessionMaxAbs != null &&
        sessionMaxAbs > 0 &&
        sessionMaxAbs <= TechniqueThresholds.steeringFractionMax
    ? 100.0
    : 1.0;
