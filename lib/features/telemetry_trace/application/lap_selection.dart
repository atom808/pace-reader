/// Which lap the synced views are showing (SPEC.md §8.4, §8.5).
///
/// App state rather than a route parameter, for the same reason the open
/// session is (§9.4/§14): the trace panels and the track map are one system
/// looking at one lap, and both screens have to agree on which without one
/// of them owning it.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';

part 'lap_selection.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// The user's explicit choice, or null for "no choice yet".
///
/// Kept as a nullable index rather than defaulting to a number, so
/// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
/// picked, choose well" — which are different, and only one of them should
/// land a user on the garage lap.
///
/// Keyed by session rather than global: lap 7 of one recording has nothing to
/// do with lap 7 of another, so a per-session key makes switching files land
/// on each one's own best lap instead of needing a reset that somebody has to
/// remember to call.
@Riverpod(keepAlive: true)
class SelectedLapIndex extends _$SelectedLapIndex {
  @override
  int? build(TelemetrySource source) => null;

  void select(int index) => state = index;

  void clear() => state = null;
}

/// The lap actually rendered.
///
/// Defaults to the session's best lap rather than the first: lap 0 is the
/// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
/// trace is a pit exit rather than a lap of the circuit. The best lap is both
/// the most interesting default and the one a user comparing against anything
/// else will want as their reference.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<Lap?> displayedLap(Ref ref, TelemetrySource source) async {
  final laps = await ref.watch(lapsProvider(source).future);
  if (laps.isEmpty) return null;

  final selected = ref.watch(selectedLapIndexProvider(source));
  if (selected != null) {
    for (final lap in laps) {
      if (lap.index == selected) return lap;
    }
  }

  // Best, then any lap the recording actually closed, then whatever exists —
  // a practice session that never set a valid time still has telemetry worth
  // looking at.
  return laps.bestLap ??
      laps.firstWhere(
        (lap) => lap.endSeconds != null,
        orElse: () => laps.first,
      );
}
