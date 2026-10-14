/// Overlap and coast spans, classified by what the pedals did either side
/// (SPEC.md §8.13.3).
library;

/// What the pedals are doing at one 50 Hz sample.
enum PedalState {
  /// Neither pedal touched at all: both exactly 0.
  coast,

  /// The throttle applied (> 2 %), the brake not.
  throttle,

  /// The brake applied, the throttle not.
  brake,

  /// Both applied.
  overlap,

  /// A pedal in (0, 2]: on its way somewhere, a median of one sample.
  transit,
}

/// A run of consecutive samples in one state, within one lap.
class PedalRun {
  const PedalRun(this.state, this.samples);

  final PedalState state;
  final int samples;
}

/// What an overlap span was.
enum OverlapKind {
  /// On the throttle, with the brake coming on before it lifts: the
  /// throttle-to-brake handover. 26–89 % of overlap time.
  entry('throttle-to-brake handover'),

  /// The brake still on as the throttle picks up. 5–39 %.
  exit('brake-to-throttle handover'),

  /// The brake touched while on the throttle, which stays on. 4–44 %.
  dab('brake dab on the throttle'),

  /// Anything else: a coast either side, or the lap's edge.
  other('other');

  const OverlapKind(this.description);

  final String description;
}

/// What a coast span was.
enum CoastKind {
  /// Throttle → coast → brake: the lift-and-coast shape. 40 % of coast time.
  liftAndCoast('lift before braking'),

  /// Brake → coast → throttle: between brake release and throttle, mid
  /// corner. 34 %.
  midCorner('between brake and throttle'),

  other('other');

  const CoastKind(this.description);

  final String description;
}

/// One lap's overlap and coast time by kind, in samples.
class SpanBreakdown {
  const SpanBreakdown({
    required this.overlap,
    required this.coast,
    required this.liftAndCoastSpans,
  });

  static const empty = SpanBreakdown(
    overlap: {},
    coast: {},
    liftAndCoastSpans: 0,
  );

  final Map<OverlapKind, int> overlap;
  final Map<CoastKind, int> coast;

  /// How many lift-and-coast spans the lap held.
  final int liftAndCoastSpans;

  int get overlapSamples => overlap.values.fold(0, (a, b) => a + b);
  int get coastSamples => coast.values.fold(0, (a, b) => a + b);

  /// The kind holding the most overlap time, or null without overlap.
  OverlapKind? get mainOverlap => _largest(overlap);
  CoastKind? get mainCoast => _largest(coast);

  static K? _largest<K>(Map<K, int> m) {
    K? best;
    var n = 0;
    for (final MapEntry(:key, :value) in m.entries) {
      if (value > n) {
        best = key;
        n = value;
      }
    }
    return best;
  }
}

/// Classifies each overlap and coast run in [runs] (one lap, in order) by the
/// nearest pedal state either side, looking through transits.
SpanBreakdown classifySpans(List<PedalRun> runs) {
  final overlap = <OverlapKind, int>{};
  final coast = <CoastKind, int>{};
  var lifts = 0;

  PedalState? neighbour(int i, int step) {
    for (var k = i + step; k >= 0 && k < runs.length; k += step) {
      if (runs[k].state != PedalState.transit) return runs[k].state;
    }
    return null;
  }

  for (var i = 0; i < runs.length; i++) {
    final run = runs[i];
    if (run.state != PedalState.overlap && run.state != PedalState.coast) {
      continue;
    }
    final before = neighbour(i, -1);
    final after = neighbour(i, 1);
    if (run.state == PedalState.overlap) {
      final kind = switch ((before, after)) {
        (PedalState.throttle, PedalState.brake) => OverlapKind.entry,
        (PedalState.brake, PedalState.throttle) => OverlapKind.exit,
        (PedalState.throttle, PedalState.throttle) => OverlapKind.dab,
        _ => OverlapKind.other,
      };
      overlap[kind] = (overlap[kind] ?? 0) + run.samples;
    } else {
      final kind = switch ((before, after)) {
        (PedalState.throttle, PedalState.brake) => CoastKind.liftAndCoast,
        (PedalState.brake, PedalState.throttle) => CoastKind.midCorner,
        _ => CoastKind.other,
      };
      if (kind == CoastKind.liftAndCoast) lifts++;
      coast[kind] = (coast[kind] ?? 0) + run.samples;
    }
  }
  return SpanBreakdown(
    overlap: overlap,
    coast: coast,
    liftAndCoastSpans: lifts,
  );
}
