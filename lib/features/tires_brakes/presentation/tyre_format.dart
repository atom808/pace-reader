/// Number formats for the tyres & brakes view (SPEC.md §8.6).
///
/// One place, so a pressure reads with the same decimals on a card, in a
/// tooltip and in the table.
library;

import '../application/tire_brake_report.dart';

/// Decimals per metric, each chosen against what actually moves:
///
/// - pressure and tyre temperatures to 0.1 — a stint's lap-to-lap drift is
///   0.1–1 kPa / °C (the Sebring FL tyre holds 176.9–177.3 kPa over its last
///   eight complete laps), so whole numbers would hide the trend the chart
///   shows;
/// - wear to 0.01 % — a lap takes 0.23–0.51 % on the Sebring GT3, so one
///   decimal would print most laps as the same number;
/// - brake temperature to whole degrees — a disc swings 362–513 °C between
///   its coolest and hottest reading inside a lap (Sebring Race, every corner,
///   laps 1–19), so a tenth of a degree is noise.
int decimalsFor(TyreMetric metric) => switch (metric) {
      TyreMetric.pressure || TyreMetric.tread || TyreMetric.carcass => 1,
      TyreMetric.wear => 2,
      TyreMetric.brake => 0,
    };

String formatMetric(TyreMetric metric, double value) =>
    value.toStringAsFixed(decimalsFor(metric));

String formatWithUnit(TyreMetric metric, double? value) => value == null
    ? '—'
    : '${formatMetric(metric, value)} ${metric.unit}';

/// A signed difference, with a real minus sign: `+37.6`, `−0.47`.
String formatSigned(double value, int decimals) {
  final text = value.abs().toStringAsFixed(decimals);
  if (double.parse(text) == 0) return text;
  return value < 0 ? '−$text' : '+$text';
}
