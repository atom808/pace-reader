/// Formatting for telemetry numerals (SPEC.md §9.7.7).
///
/// Every value here is rendered in JetBrains Mono with tabular figures, so the
/// formats are built to hold their column width: fixed decimal places, and a
/// leading sign on deltas so a positive and a negative value occupy the same
/// space. A lap table where the digits shift as values update is exactly what
/// §9.7.7 bundled a tabular-figure typeface to avoid.
library;

/// A lap time as `m:ss.mmm` (e.g. `1:04.497`).
///
/// Minutes are not zero-padded — `1:04.497`, not `01:04.497` — since a lap
/// over ten minutes is rare enough that padding every lap to match would cost
/// a column of whitespace on every row. Hours are folded into minutes rather
/// than given their own field: a single *lap* never runs to an hour, and a
/// value that did would be a bug worth seeing as `73:12.004` rather than
/// quietly reformatted.
String formatLapTime(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '—';
  final negative = seconds < 0;
  final total = seconds.abs();
  final minutes = total ~/ 60;
  final remainder = total - minutes * 60;
  final text = '$minutes:${remainder.toStringAsFixed(3).padLeft(6, '0')}';
  return negative ? '-$text' : text;
}

/// A sector time as plain seconds (e.g. `23.347`).
///
/// Sectors run well under a minute on any real circuit, so minutes would be a
/// permanently-zero field. A sector that did exceed a minute falls back to the
/// lap format rather than rendering a misleading `84.213`.
String formatSectorTime(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '—';
  return seconds.abs() >= 60 ? formatLapTime(seconds) : seconds.toStringAsFixed(3);
}

/// A signed delta (e.g. `+0.467`, `-1.204`).
///
/// Always signed, including zero as `+0.000`: an unsigned zero next to signed
/// neighbours breaks the column, and "exactly the reference lap" is worth
/// showing as a value rather than as a blank.
String formatDelta(double seconds) {
  if (seconds.isNaN || seconds.isInfinite) return '—';
  final sign = seconds < 0 ? '-' : '+';
  final magnitude = seconds.abs();
  return magnitude >= 60
      ? '$sign${formatLapTime(magnitude)}'
      : '$sign${magnitude.toStringAsFixed(3)}';
}

/// A session duration as `m:ss` or `h:mm:ss`.
///
/// Hours appear only when there are any, so a 22-minute practice session reads
/// `22:20` while a 6-hour stint reads `6:00:00` — endurance sessions genuinely
/// reach both scales (§4).
String formatSessionDuration(double seconds) {
  if (seconds.isNaN || seconds.isInfinite || seconds < 0) return '—';
  final total = seconds.round();
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final secs = total % 60;
  final ss = secs.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$ss';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
}

/// Renders a nullable time, falling back to an em dash.
///
/// Null is the norm here rather than an edge case — untimed out-laps,
/// invalidated laps, and sectors the game wrote as `0.0` (§8.3.1) — so every
/// call site would otherwise repeat the same null branch.
String formatOptionalLapTime(double? seconds) =>
    seconds == null ? '—' : formatLapTime(seconds);

String formatOptionalSectorTime(double? seconds) =>
    seconds == null ? '—' : formatSectorTime(seconds);

/// A raw event value, as §8.12's log shows it.
///
/// Faithful rather than friendly: `true`/`false` stay as they were recorded
/// instead of becoming "on"/"off", because the point of that view is seeing
/// what the game wrote. The only liberty taken is on doubles, and it is a
/// correction rather than a prettification — every FLOAT column in these files
/// is 32-bit, so widening it to a Dart double appends noise past the seventh
/// significant digit. `Brake Bias Rear` is stored as 0.4875 and arrives as
/// 0.48750001192092896; printing that in full would present rounding error as
/// precision.
String formatEventValue(Object? value) {
  if (value == null) return '—';
  if (value is bool) return value ? 'true' : 'false';
  if (value is int) return '$value';
  if (value is! double) return '$value';
  if (value.isNaN || value.isInfinite) return '—';
  final text = value.toStringAsPrecision(7);
  if (!text.contains('.') || text.contains('e')) return text;
  final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
  return trimmed.endsWith('.')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;
}

/// An elapsed-seconds timestamp for a log row, as `m:ss.mmm` on the session
/// clock.
///
/// The file's own `ts` is elapsed seconds from an arbitrary per-file origin
/// (§5.2 — 23.60/34.57/381.09 s across the samples), so the raw number means
/// nothing to a reader. [origin] is subtracted to make it time-since-recording
/// started, which is the only reading of it that transfers between files.
String formatSessionTime(double seconds, {required double origin}) =>
    formatLapTime(seconds - origin);
