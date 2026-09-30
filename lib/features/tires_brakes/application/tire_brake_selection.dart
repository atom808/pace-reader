/// What the tyres & brakes view is looking at (SPEC.md §8.6).
///
/// App state rather than widget state, like the trace view's lap choice: it
/// survives navigating away and back, and a widget test can set it without
/// driving the controls.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import 'tire_brake_report.dart';

part 'tire_brake_selection.g.dart';

/// The lap the corner cards show — the user's choice, or null for
/// [TireBrakeReport.defaultLap].
///
/// Nullable rather than defaulting to a number for the reason
/// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
/// are different, and only one of them should land on the garage lap. Keyed
/// by session, since lap 7 of one file has nothing to do with lap 7 of
/// another.
@Riverpod(keepAlive: true)
class TyreLapSelection extends _$TyreLapSelection {
  @override
  int? build(TelemetrySource source) => null;

  void select(int lapIndex) => state = lapIndex;

  void clear() => state = null;
}

/// The quantity the four trend charts and the table show.
@Riverpod(keepAlive: true)
class TyreMetricSelection extends _$TyreMetricSelection {
  @override
  TyreMetric build(TelemetrySource source) => TyreMetric.pressure;

  void select(TyreMetric metric) => state = metric;
}
