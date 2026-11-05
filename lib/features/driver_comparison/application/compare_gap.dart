/// The gap split's reads, and which phase the map lights (GO reference
/// proposal P3).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/lap_finding_reads.dart';
import '../domain/comparison_set.dart';
import '../domain/gap_split.dart';
import '../domain/segment_findings.dart';
import 'compare_source_guard.dart';
import 'comparison_chart.dart';
import 'segment_tables.dart';

part 'compare_gap.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// [set]'s gap, phase by phase; null without a Target, without segments
/// (the clocks come with them), or where the Target's pedals were not
/// recorded.
///
/// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
/// from the reads the findings already hold for the pair.
@Riverpod(retry: _neverRetry)
Future<GapSplit?> comparisonGapSplit(Ref ref, ComparisonSet set) async {
  final target = set.target;
  if (target == null) return null;
  requireSourceOpen(ref, target.source, ComparisonRole.target);
  final segments = await ref.watch(comparisonSegmentsProvider(set).future);
  final base = segments?.baseClock;
  final other = segments?.targetClock;
  if (base == null || other == null) return null;
  final view = await ref.watch(comparisonChartProvider(set).future);
  final axis = view.chart?.comparison?.referenceAxis;
  if (axis == null) return null;
  final reads = await ref.watch(
    lapFindingReadsProvider(target.source, target.lapIndex).future,
  );
  PlacedSeries? placed(TraceSeries? series) =>
      series == null || series.length < 2
      ? null
      : PlacedSeries.of(series, axis);
  return GapSplit.measure(
    base: base,
    target: other,
    throttle: placed(reads.throttle),
    brake: placed(reads.brake),
    regen: placed(reads.regen),
  );
}

/// The phase whose stretches the map lights, for one pair.
class GapPhaseFocusState {
  const GapPhaseFocusState({this.set, this.phase});

  final ComparisonSet? set;
  final GapPhase? phase;

  /// [phase] if it belongs to [of]: another pair starts with none lit.
  GapPhase? forSet(ComparisonSet of) => set == of ? phase : null;
}

@Riverpod(keepAlive: true)
class GapPhaseFocus extends _$GapPhaseFocus {
  @override
  GapPhaseFocusState build() => const GapPhaseFocusState();

  /// Lights [phase] for [set], or turns it off when it is already lit.
  void toggle(ComparisonSet set, GapPhase phase) =>
      state = state.forSet(set) == phase
      ? GapPhaseFocusState(set: set)
      : GapPhaseFocusState(set: set, phase: phase);
}
