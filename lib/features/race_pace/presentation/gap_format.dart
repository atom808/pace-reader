/// Formatting for the race-pace view's numerals (SPEC.md §8.9, §9.7.7).
library;

/// A gap reading or a movement of one, signed and in seconds: `-6.96 s`,
/// `+0.42 s`.
///
/// Always signed, zero included, for the reason `formatDelta` gives: an
/// unsigned figure among signed neighbours breaks the column, and here the sign
/// is the message — negative is *behind the car ahead*, and on a movement,
/// negative is ground lost. Two decimals, since the channel is good to about
/// that and a lap gains or loses tenths; a third below a tenth of a second,
/// where the closest approach lives and two decimals would read `+0.00`.
String formatGap(double? seconds, {bool unit = true}) {
  if (seconds == null || seconds.isNaN || seconds.isInfinite) return '—';
  final magnitude = seconds.abs();
  final decimals = magnitude < 0.1 ? 3 : 2;
  // A value that rounds to nothing takes the sign of nothing — `-0.000` next
  // to `+0.000` would be the same number drawn two ways.
  final rounded = double.parse(magnitude.toStringAsFixed(decimals));
  final sign = rounded == 0 ? '+' : (seconds < 0 ? '-' : '+');
  final text = '$sign${magnitude.toStringAsFixed(decimals)}';
  return unit ? '$text s' : text;
}

/// An axis tick: as many decimals as its step needs and no unit, so `-8`, `-6`
/// on a step of 2, `-0.5` on a step of 0.5, and `-7.5` on a step of 2.5.
///
/// The decimals come from the step itself rather than its size. The tick
/// generator's steps are 1, 2, 2.5 or 5 times a power of ten, and deciding on
/// magnitude alone prints the 2.5 step's ticks at one decimal fewer than they
/// have — a gridline at -7.5 labelled `-8`, which is how this axis first drew
/// the Race sample.
String formatGapTick(double value, double step) {
  final decimals = tickDecimals(step);
  final folded = value.abs() < step * 1e-6 ? 0.0 : value;
  return folded.toStringAsFixed(decimals);
}

/// The fewest decimals (up to three) that print [step] exactly.
int tickDecimals(double step) {
  var scale = 1.0;
  for (var decimals = 0; decimals < 3; decimals++) {
    final scaled = step.abs() * scale;
    if ((scaled - scaled.roundToDouble()).abs() < 1e-6) return decimals;
    scale *= 10;
  }
  return 3;
}

/// How long a held stretch lasted, for a caption: `42.5 s`.
///
/// The space before the unit does not break, so a caption that wraps on this
/// figure takes it whole instead of leaving an orphaned `s` on the next line.
String formatHeldDuration(double seconds) =>
    '${seconds.toStringAsFixed(1)}\u00A0s';

/// A moment on the session clock to a tenth of a second — `2:02.5` — which is
/// as fine as a 2 Hz channel can say. (`formatSessionTime` gives milliseconds,
/// three digits of precision the readings do not have.)
String formatSessionClock(double seconds, {required double origin}) {
  final tenths = ((seconds - origin) * 10).round();
  final minutes = tenths ~/ 600;
  final rest = (tenths % 600) / 10;
  return '$minutes:${rest.toStringAsFixed(1).padLeft(4, '0')}';
}
