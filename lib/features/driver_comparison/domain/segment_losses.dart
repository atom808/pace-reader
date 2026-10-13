/// Where Base lost time to the Target, segment by segment (comparison
/// proposal §5 "Loss", "Opening behaviour", "Inside a segment").
library;

import 'dart:math' as math;

import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import 'segments.dart';

/// A loss smaller than this reads "≈0", is not ranked and gets no bar.
///
/// With re-anchored starts, boundary times are within p95 1.7–3.0 ms and
/// exceed 15 ms in 0.003% of pairs; without them, the first and last
/// segments would need 0.03 s.
const segmentNoiseFloor = 0.02;

/// A turning point is stated only when both of its legs reach this.
const swingFloor = 0.05;

/// The worst segment leads the next by less than this: both are tagged
/// rather than one crowned. It happens in 24.6% of library pairs, and the
/// winner then survives the choice of canonical lap only 32–60% of the time.
const nearTieMargin = 0.05;

/// One lap's clock along the course: when it reached each station.
class LapClock {
  const LapClock({
    required this.axis,
    required this.startSeconds,
    required this.endSeconds,
    required this.wrapLength,
    this.endFromLineCrossing = false,
  });

  /// The lap's own `Lap Dist` against its session seconds.
  final DistanceAxis axis;

  /// t(0): the lap's start, re-anchored on its splits where it recorded them
  /// (§4, [LapAnchor]).
  final double startSeconds;

  /// t(L): the start plus the game's `Lap Time` — or, for an untimed flying
  /// lap, the next `Lap` event, good to ±0.02 s.
  final double endSeconds;

  final double wrapLength;

  /// True when [endSeconds] is a line crossing rather than the game's time.
  final bool endFromLineCrossing;

  /// When the lap first reached [station], in session seconds.
  ///
  /// The *first* moment: a car stopped on a boundary has its stop charged to
  /// the segment it stopped in, not the one before (§5 "Spins"). Between the
  /// line and the first sample, and between the last sample and the closing
  /// line, the lap is taken at the pace it held across the gap.
  double at(double station) {
    if (station <= 0) return startSeconds;
    if (station >= wrapLength) return endSeconds;
    final d = axis.distances;
    final t = axis.times;
    if (d.isEmpty) return startSeconds;
    if (station < d.first) {
      return d.first <= 0
          ? t.first
          : startSeconds + (t.first - startSeconds) * station / d.first;
    }
    final reached = axis.firstReachTime(station);
    if (reached != null) return reached;
    final last = d.last;
    return t.last +
        (endSeconds - t.last) * (station - last) / (wrapLength - last);
  }

  /// Seconds from the lap's start to [station].
  double elapsed(double station) => at(station) - startSeconds;
}

/// Where the running delta turned inside a segment.
class TurningPoint {
  const TurningPoint({
    required this.station,
    required this.first,
    required this.second,
  });

  /// `Lap Dist` of the turn.
  final double station;

  /// The segment-relative delta from the segment's start to the turn:
  /// negative when Base gained.
  final double first;

  /// From the turn to the segment's end.
  final double second;

  /// Shown only when both legs are at least [swingFloor]: 17–28% of all
  /// segments on the library, so a common line, not an edge case.
  bool get stated => first.abs() >= swingFloor && second.abs() >= swingFloor;

  double get larger => math.max(first.abs(), second.abs());
}

/// Base against the Target over one stretch of the lap.
class StretchLoss {
  const StretchLoss({
    required this.segment,
    required this.baseSeconds,
    required this.targetSeconds,
    this.turn,
  });

  final Segment segment;

  /// How long each lap took across it; null where it cannot be said — a
  /// sector the game did not time.
  final double? baseSeconds;
  final double? targetSeconds;

  final TurningPoint? turn;

  /// Base's time less the Target's: positive when Base lost time.
  double? get loss => baseSeconds == null || targetSeconds == null
      ? null
      : baseSeconds! - targetSeconds!;

  bool get measured => loss != null;

  /// Within the noise floor: "≈0".
  bool get level => loss != null && loss!.abs() < segmentNoiseFloor;

  /// Level overall, but with a swing worth a look: a net of ≈0 can hide a
  /// gain on entry and a loss on exit (§5 "What Most lost visits"; 4.7–7.8%
  /// of all segments on the library).
  bool get levelButSwinging =>
      level && turn != null && turn!.larger >= swingFloor;
}

/// The orders → and ← walk in.
enum SegmentOrder {
  mostLost('Most lost'),
  trackOrder('Track order'),
  mostGained('Most gained');

  const SegmentOrder(this.label);

  final String label;
}

/// Segments, or the game's three sectors (§5 "Sectors mode").
enum SegmentMode {
  segments('Segments'),
  sectors('Sectors');

  const SegmentMode(this.label);

  final String label;
}

/// One step of the walk: a stretch, or the recap that ends it.
class WalkStop {
  const WalkStop(this.stretch) : recap = false;
  const WalkStop.recap() : stretch = null, recap = true;

  final StretchLoss? stretch;
  final bool recap;

  int? get number => stretch?.segment.number;

  @override
  bool operator ==(Object other) =>
      other is WalkStop && other.recap == recap && other.number == number;

  @override
  int get hashCode => Object.hash(recap, number);
}

/// Base against the Target over every stretch of one table.
class StretchComparison {
  StretchComparison._(
    this.mode,
    this.stretches,
    this.endFromLineCrossing, {
    this.notable = const {},
  });

  /// Losses over [table]'s segments, from each lap's first reach of every
  /// boundary.
  ///
  /// The losses telescope: they sum to (t_Base(L) − t_Base(0)) −
  /// (t_Target(L) − t_Target(0)), the game's own lap-time difference, to
  /// rounding. Interior boundaries carry no anchor error, since a lap's t(0)
  /// cancels in a difference; the first and last segments carry what is left
  /// of it once re-anchored (p95 3 ms or less).
  ///
  /// [delta] is the Delta panel's trace, and the turning points are read off
  /// it, so the Why card never states a movement the trace does not draw.
  ///
  /// [notable] names the segments holding a stated finding (§5 "What Most
  /// lost visits"): level ones among them are visited too.
  factory StretchComparison.segments({
    required SegmentTable table,
    required LapClock base,
    required LapClock target,
    LapDelta? delta,
    Set<int> notable = const {},
  }) {
    final stretches = <StretchLoss>[];
    for (final segment in table.segments) {
      final baseSeconds = base.at(segment.end) - base.at(segment.start);
      final targetSeconds = target.at(segment.end) - target.at(segment.start);
      stretches.add(
        StretchLoss(
          segment: segment,
          baseSeconds: baseSeconds,
          targetSeconds: targetSeconds,
          turn: delta == null
              ? null
              : _turningPoint(
                  segment,
                  net: baseSeconds - targetSeconds,
                  startDelta:
                      base.elapsed(segment.start) -
                      target.elapsed(segment.start),
                  delta: delta,
                ),
        ),
      );
    }
    return StretchComparison._(
      SegmentMode.segments,
      stretches,
      base.endFromLineCrossing || target.endFromLineCrossing,
      notable: notable,
    );
  }

  /// The game's three sectors, from its own splits, which are exact (§5
  /// "Sectors mode"): a split the game wrote as 0.0 leaves its sector
  /// unmeasured, never 0. [stations] are Base's sector-line stations and its
  /// lap length, where a sector's zoom goes.
  factory StretchComparison.sectors({
    required Lap base,
    required Lap target,
    required ({double? sector1, double? sector2, double? length}) stations,
  }) {
    final b = base.sectors.all;
    final t = target.sectors.all;
    final edges = [0.0, stations.sector1, stations.sector2, stations.length];
    return StretchComparison._(SegmentMode.sectors, [
      for (var k = 0; k < 3; k++)
        StretchLoss(
          segment: Segment(
            number: k + 1,
            label: 'S${k + 1}',
            start: edges[k] ?? double.nan,
            end: edges[k + 1] ?? double.nan,
          ),
          baseSeconds: b[k],
          targetSeconds: t[k],
        ),
    ], false);
  }

  final SegmentMode mode;
  final List<StretchLoss> stretches;

  /// True when a lap's end is a line crossing, not the game's time: the last
  /// stretch and the total then read "≈ … (from line crossings, ±0.02 s)".
  final bool endFromLineCrossing;

  /// Segment numbers holding a stated finding: a brake point, a downshift, a
  /// lowest gear that differs, or a contact.
  final Set<int> notable;

  /// Level overall, but worth a stop: a swing inside it, or a stated
  /// finding. Tagged "level overall, but…".
  bool levelButNotable(StretchLoss stretch) =>
      stretch.levelButSwinging ||
      (stretch.level && notable.contains(stretch.segment.number));

  /// The sum of the measured losses.
  double get total => stretches.fold(0, (sum, s) => sum + (s.loss ?? 0));

  /// The stretch with the largest loss of at least [segmentNoiseFloor], or
  /// null when Base loses nowhere.
  StretchLoss? get worst {
    StretchLoss? worst;
    for (final s in stretches) {
      final loss = s.loss;
      if (loss == null || loss < segmentNoiseFloor) continue;
      if (worst == null || loss > worst.loss!) worst = s;
    }
    return worst;
  }

  /// The stretches tagged as a near tie for "most lost": the worst and every
  /// other loss within [nearTieMargin] of it. Empty when the worst leads
  /// clearly.
  List<StretchLoss> get nearTies {
    final top = worst;
    if (top == null) return const [];
    final close = [
      for (final s in stretches)
        if (s.loss != null &&
            s.loss! >= segmentNoiseFloor &&
            top.loss! - s.loss! < nearTieMargin)
          s,
    ];
    return close.length < 2 ? const [] : close;
  }

  /// Whether Base loses at least [segmentNoiseFloor] anywhere.
  bool get loses => worst != null;

  StretchLoss? byNumber(int number) =>
      stretches.where((s) => s.segment.number == number).firstOrNull;

  /// The stops → visits in [order], ending with the recap.
  ///
  /// Most lost: every loss of at least the floor, largest first; then the
  /// level stretches that swing by [swingFloor] or more inside or hold a
  /// stated finding, in track order, tagged "level overall, but…"; then the
  /// recap. Most gained is the same with the signs turned round. Track order
  /// visits everything.
  List<WalkStop> walk(SegmentOrder order) {
    final swinging = [
      for (final s in stretches)
        if (levelButNotable(s)) WalkStop(s),
    ];
    final ranked = switch (order) {
      SegmentOrder.trackOrder => [for (final s in stretches) WalkStop(s)],
      SegmentOrder.mostLost => [
        for (final s in [
          for (final s in stretches)
            if (s.loss != null && s.loss! >= segmentNoiseFloor) s,
        ]..sort((a, b) => b.loss!.compareTo(a.loss!)))
          WalkStop(s),
        ...swinging,
      ],
      SegmentOrder.mostGained => [
        for (final s in [
          for (final s in stretches)
            if (s.loss != null && s.loss! <= -segmentNoiseFloor) s,
        ]..sort((a, b) => a.loss!.compareTo(b.loss!)))
          WalkStop(s),
        ...swinging,
      ],
    };
    return [...ranked, const WalkStop.recap()];
  }
}

/// The turning point of [segment]'s running delta, read off [delta]'s own
/// samples inside it, or null when the trace has none there.
///
/// The extremum of the segment-relative running delta, Δ(d) − Δ(start):
/// its lowest point or its highest, whichever splits the segment into the
/// larger pair of opposite movements. "Gained 0.271 s from 705 to 794 m,
/// then lost 0.569 s to 1158 m" is the hairpin's lowest point; a segment
/// lost on entry and partly won back turns at its highest.
TurningPoint? _turningPoint(
  Segment segment, {
  required double net,
  required double startDelta,
  required LapDelta delta,
}) {
  int? low;
  int? high;
  for (var i = 0; i < delta.length; i++) {
    final d = delta.distances[i];
    if (d <= segment.start || d >= segment.end) continue;
    if (low == null || delta.deltas[i] < delta.deltas[low]) low = i;
    if (high == null || delta.deltas[i] > delta.deltas[high]) high = i;
  }
  if (low == null || high == null) return null;
  TurningPoint at(int i) {
    final first = delta.deltas[i] - startDelta;
    return TurningPoint(
      station: delta.distances[i],
      first: first,
      second: net - first,
    );
  }

  final down = at(low);
  final up = at(high);
  double smaller(TurningPoint p) => math.min(p.first.abs(), p.second.abs());
  return smaller(down) >= smaller(up) ? down : up;
}
