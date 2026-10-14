/// Shifts, and where an upshift sits against the rev limiter (SPEC.md §8.13.1,
/// §8.13.3).
library;

/// One `Gear` event row.
class GearRow {
  const GearRow(this.seconds, this.gear);

  final double seconds;

  /// −1 reverse, 0 neutral, 1..n forward.
  final int gear;
}

/// A change of forward gear.
class Shift {
  const Shift({
    required this.seconds,
    required this.from,
    required this.to,
    this.neutral = true,
  });

  /// When the shift began: the neutral row's time, or the new gear's when no
  /// neutral row came between (never seen in 678 files, but not assumed).
  final double seconds;

  final int from;
  final int to;

  /// Whether a neutral row came between the two gears.
  final bool neutral;

  bool get isUp => to > from;

  @override
  String toString() => 'Shift($from→$to at $seconds)';
}

/// The forward-gear changes in [rows], in time order.
///
/// Every change in all 678 files goes old → 0 → new, with no direct
/// gear-to-gear row and no consecutive duplicate. So a shift is a change
/// between consecutive **non-zero** values, and counting raw value changes
/// would double the count. Reverse is not a forward gear: a change into or out
/// of it (pit-lane manoeuvring) is not a shift.
List<Shift> shiftsFrom(List<GearRow> rows) {
  final out = <Shift>[];
  int? previous;
  double? neutralAt;
  for (final row in rows) {
    if (row.gear == 0) {
      // The first neutral row after a gear is where the shift starts.
      neutralAt ??= row.seconds;
      continue;
    }
    final from = previous;
    if (from != null && row.gear != from && from >= 1 && row.gear >= 1) {
      out.add(
        Shift(
          seconds: neutralAt ?? row.seconds,
          from: from,
          to: row.gear,
          neutral: neutralAt != null,
        ),
      );
    }
    previous = row.gear;
    neutralAt = null;
  }
  return out;
}

/// Where an upshift's RPM sits against the limiter L (`VM_REV_LIMITER`).
///
/// The bands are the ones the library was graded in: da, Ground Speed's
/// acceleration over the 0.25 s after the neutral row minus the 0.25 s
/// before, at full throttle on racing laps (14,440 shifts on 13 files).
enum ShiftBand {
  atLimiter('At the limiter', 'within 20 rpm of it'),
  late('Late', '20–200 rpm before it'),
  early('Early', '200–500 rpm before it'),
  short('Short', '500–1,000 rpm before it'),
  wellBefore('Well before', 'over 1,000 rpm before it');

  const ShiftBand(this.label, this.range);

  final String label;

  /// Where the band sits, in words.
  final String range;

  /// The band an upshift at [rpm] falls in.
  static ShiftBand of(double rpm, double limiter) {
    final below = limiter - rpm;
    if (below <= 20) return atLimiter;
    if (below <= 200) return late;
    if (below <= 500) return early;
    if (below <= 1000) return short;
    return wellBefore;
  }

  /// The band's edges as rpm below L, nearest first; null where open.
  (double, double?) get belowLimiter => switch (this) {
    atLimiter => (0, 20),
    late => (20, 200),
    early => (200, 500),
    short => (500, 1000),
    wellBefore => (1000, null),
  };
}

/// The library's mean da per band (km/h per s), with the number of shifts,
/// for the shift panel's popover (SPEC.md §8.13.3). Null where the class was
/// not measured.
({double da, int n})? libraryAcceleration(String carClass, ShiftBand band) {
  final row = switch (_classKey(carClass)) {
    'GT3' => const [(0.10, 32), (0.03, 217), (-0.11, 139), (-1.07, 237)],
    'HYPER' => const [(0.66, 96), (-0.99, 695), (-1.39, 1031), (-1.36, 874)],
    'LMP2' => const [(2.58, 88), (-1.37, 400), (-2.22, 419), (-2.52, 300)],
    _ => null,
  };
  if (row == null || band == ShiftBand.wellBefore) return null;
  final (da, n) = row[band.index];
  return (da: da, n: n);
}

String _classKey(String carClass) {
  final c = carClass.toUpperCase();
  if (c.contains('GT3')) return 'GT3';
  if (c.contains('HYPER')) return 'HYPER';
  if (c.contains('LMP2')) return 'LMP2';
  return c;
}

/// One upshift as the query reads it: everything around its neutral row.
class UpshiftRead {
  const UpshiftRead({
    required this.seconds,
    this.rpm,
    this.accelerationChange,
    this.pedal,
    this.limiterSeconds = 0,
  });

  /// The neutral row's time: [Shift.seconds].
  final double seconds;

  /// The maximum `Engine RPM` in the 0.3 s before the neutral row.
  final double? rpm;

  /// da: Ground Speed's acceleration over the 0.25 s after the neutral row
  /// minus the 0.25 s before, in km/h per s.
  final double? accelerationChange;

  /// The pedal at the neutral row (%): da is graded at full throttle only.
  final double? pedal;

  /// Time within [TechniqueThresholds.limiterMargin] of the limiter in the
  /// second before the neutral row.
  final double limiterSeconds;
}
