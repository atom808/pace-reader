/// Compare's one workspace (comparison proposal §3, §9).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../data/repositories/providers.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../domain/comparison_set.dart';

part 'comparison_workspace.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// The pair the user chose, or null for "not chosen yet".
///
/// Kept for the run and not persisted (open question 6). Null means Compare
/// follows the current session, with that session's displayed lap as Base
/// and no Target ([activeComparison]); the first explicit choice — a Target,
/// a Swap, "Open in Compare" — fixes the set, and from then on switching the
/// current session changes nothing here (§9: "Open in Trace is the only
/// action that makes a compared file current", and the reverse holds too).
@Riverpod(keepAlive: true)
class ComparisonWorkspace extends _$ComparisonWorkspace {
  @override
  ComparisonSet? build() => null;

  /// Starts a comparison of [base] against [target] — Trace's "Open in
  /// Compare", or a lap picked as Base.
  void start(LapRef base, [LapRef? target]) =>
      state = ComparisonSet(base).withTarget(target);

  /// Compares [base] (the set's Base, or the one Compare was following)
  /// against [target]; null clears the Target.
  void setTarget(LapRef base, LapRef? target) =>
      state = ComparisonSet(base).withTarget(target);

  /// Makes [base] the Base, keeping the Target unless it is the same lap.
  void setBase(LapRef base) =>
      state = ComparisonSet(base).withTarget(state?.target);

  /// Exchanges Base and Target. Base's clock is the axis, so the cursor and
  /// zoom start over — the screen's `SyncOwner` sees a new owner.
  void swap() {
    final set = state;
    if (set?.target == null) return;
    state = set!.swapped();
  }

  void clearTarget() {
    final set = state;
    if (set != null) state = set.withTarget(null);
  }

  /// Back to following the current session.
  void clear() => state = null;
}

/// The pair Compare shows: the user's choice, or else the current session's
/// displayed lap alone.
///
/// A recording's first lap is never a Compare lap (§4 Lap rules: its `Lap`
/// event is not a lap boundary), so a session showing it elsewhere opens
/// Compare on its best lap instead.
@Riverpod(retry: _neverRetry)
Future<ComparisonSet?> activeComparison(Ref ref) async {
  final chosen = ref.watch(comparisonWorkspaceProvider);
  if (chosen != null) return chosen;
  final current = ref.watch(currentSessionProvider);
  if (current == null) return null;
  final displayed = await ref.watch(displayedLapProvider(current).future);
  if (displayed == null) return null;
  final laps = await ref.watch(lapsProvider(current).future);
  final lap = isRecordingStart(laps, displayed)
      ? laps.bestLap ?? displayed
      : displayed;
  return ComparisonSet(LapRef(current, lap.index));
}

/// Whether [lap] is its recording's first: the first `Lap` event, whatever
/// its number — a recording that starts mid-session opens at a value above
/// zero, and its first lap is no more a lap than lap 0 is.
bool isRecordingStart(List<Lap> laps, Lap lap) =>
    laps.isNotEmpty && laps.first.index == lap.index;
