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

/// What the map lights for one pair: a phase's stretches, or the straights
/// whose loss was carried from the corner before. One at a time.
class GapPhaseFocusState {
  const GapPhaseFocusState({this.set, this.phase, this.carried = false});

  final ComparisonSet? set;
  final GapPhase? phase;

  /// The carried straights are lit, in place of any phase.
  final bool carried;

  /// [phase] if it belongs to [of]: another pair starts with none lit.
  GapPhase? forSet(ComparisonSet of) => set == of ? phase : null;

  /// Whether [of]'s carried straights are lit.
  bool carriedFor(ComparisonSet of) => set == of && carried;

  /// The stretches lit on [split], and the phase whose colour they take:
  /// none for the carried straights, which take the accent so they stand
  /// apart from the throttle colouring they run over. Null when nothing of
  /// [of]'s is lit.
  ({List<GapStretch> stretches, GapPhase? phase})? litOn(
    ComparisonSet of,
    GapSplit? split,
  ) {
    if (split == null) return null;
    if (carriedFor(of)) {
      return (
        stretches: split.straights?.carriedStretches ?? const [],
        phase: null,
      );
    }
    final lit = forSet(of);
    return lit == null
        ? null
        : (stretches: split.stretches[lit] ?? const [], phase: lit);
  }
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

  /// Lights [set]'s carried straights, or turns them off when they are lit.
  void toggleCarried(ComparisonSet set) => state = state.carriedFor(set)
      ? GapPhaseFocusState(set: set)
      : GapPhaseFocusState(set: set, carried: true);
}
