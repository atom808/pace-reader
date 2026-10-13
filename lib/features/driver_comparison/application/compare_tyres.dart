/// The Tyres tab's reads: each lap's corners from its own file's tyres and
/// brakes report (comparison proposal §7 "Tyres this lap").
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../tires_brakes/application/tire_brake_report.dart';
import '../domain/comparison_set.dart';
import 'compare_source_guard.dart';

part 'compare_tyres.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// One lap's tyres: its file's report and the lap within it.
class LapTyres {
  const LapTyres({required this.report, required this.lap});

  final TireBrakeReport report;
  final Lap lap;

  Map<Corner, CornerSnapshot> get snapshot => report.snapshot(lap);
}

/// Base's and the Target's tyres, on one tread scale.
class CompareTyres {
  const CompareTyres({required this.base, required this.target});

  final LapTyres base;
  final LapTyres target;

  /// Both sessions' tread range, so a colour means one temperature on both
  /// cards.
  ({double min, double max})? get treadRange =>
      sharedTreadRampRange([base.report, target.report]);
}

/// [set]'s two laps' tyres; null without a Target.
@Riverpod(retry: _neverRetry)
Future<CompareTyres?> compareTyres(Ref ref, ComparisonSet set) async {
  final target = set.target;
  if (target == null) return null;
  requireSourceOpen(ref, set.base.source, ComparisonRole.base);
  requireSourceOpen(ref, target.source, ComparisonRole.target);

  Future<LapTyres> read(TelemetrySource source, int index) async {
    final laps = await ref.watch(lapsProvider(source).future);
    final lap = laps.firstWhere(
      (l) => l.index == index,
      orElse: () => throw StateError('This session has no lap $index.'),
    );
    return LapTyres(
      report: await ref.watch(tireBrakeReportProvider(source).future),
      lap: lap,
    );
  }

  return CompareTyres(
    base: await read(set.base.source, set.base.lapIndex),
    target: await read(target.source, target.lapIndex),
  );
}
