/// One racing lap's technique, and the measures the screen shows of it
/// (SPEC.md §8.13.3, §8.13.4).
library;

import 'dart:math' as math;

import '../../../data/models/models.dart';
import '../data/technique_reads.dart';
import 'countersteer.dart';
import 'pedal_spans.dart';
import 'shifts.dart';

/// Everything measured on one racing lap.
class LapTechnique {
  const LapTechnique({
    required this.lap,
    required this.pedals,
    this.spans = SpanBreakdown.empty,
    this.tcEpisodes = 0,
    this.absEpisodes = 0,
    this.gg,
    this.upshifts = 0,
    this.downshifts = 0,
    this.countersteer = const [],
  });

  final Lap lap;
  final PedalTotals pedals;
  final SpanBreakdown spans;

  /// TC and ABS episodes, pulses merged at 0.25 s.
  final int tcEpisodes;
  final int absEpisodes;
  final GgLap? gg;
  final int upshifts;
  final int downshifts;
  final List<CountersteerEpisode> countersteer;

  double get lapTime => lap.lapTimeSeconds!;
}

/// A shift on a racing lap, with what the query read around it.
class Upshift {
  const Upshift({required this.lap, required this.shift, this.read, this.band});

  /// `Lap.index`.
  final int lap;
  final Shift shift;
  final UpshiftRead? read;

  /// Null without a limiter or an RPM.
  final ShiftBand? band;

  /// Graded only at full throttle: a part-throttle shift's da says nothing
  /// about the shift point.
  bool get atFullThrottle => (read?.pedal ?? 0) >= 98;
}

/// A per-lap measure the screen shows as a card and a trend.
enum TechniqueMeasure {
  fullThrottle(
    label: 'Full throttle',
    unit: '%',
    subtitle: 'Pedal flat out (98 % or more)',
    goesWithPace: true,
  ),
  braking(
    label: 'Braking',
    unit: '%',
    subtitle: 'Brake pedal pressed',
    goesWithPace: true,
  ),
  gripUsed(
    label: 'Grip used',
    unit: '%',
    subtitle: "How close to the session's limit the car ran when loaded",
    goesWithPace: true,
  ),
  trail(
    label: 'Trail braking',
    unit: '%',
    subtitle: 'Braking with the wheel turned into the corner',
  ),
  overlap(
    label: 'Pedal overlap',
    unit: '%',
    subtitle: 'Both pedals pressed at once',
  ),
  coasting(label: 'Coasting', unit: '%', subtitle: 'Neither pedal touched'),
  tc(label: 'Traction control', unit: 's', subtitle: 'TC cutting power'),
  abs(label: 'ABS', unit: 's', subtitle: 'ABS releasing the brakes'),
  sustainedPeak(
    label: 'Sustained peak',
    unit: 'G',
    subtitle: 'Most G held for 0.3 s',
  );

  const TechniqueMeasure({
    required this.label,
    required this.unit,
    required this.subtitle,
    this.goesWithPace = false,
  });

  final String label;
  final String unit;

  /// One plain line under the number.
  final String subtitle;

  /// One of the three measures that went with lap time in every race
  /// measured (§8.13.4). The others describe the lap, not its speed.
  final bool goesWithPace;

  /// The measure on [t], in [unit]; null where the lap has no value.
  double? of(LapTechnique t) {
    final p = t.pedals;
    return switch (this) {
      fullThrottle => 100 * p.share(p.fullThrottle),
      braking => 100 * p.share(p.braking),
      gripUsed => t.gg?.utilisation == null ? null : 100 * t.gg!.utilisation!,
      trail => p.trailShare == null ? null : 100 * p.trailShare!,
      overlap => 100 * p.share(p.overlap),
      coasting => 100 * p.share(p.coast),
      tc => p.seconds(p.tc),
      abs => p.seconds(p.abs),
      sustainedPeak => t.gg?.sustainedPeak,
    };
  }

  /// Decimals the value is shown with.
  int get decimals => switch (this) {
    tc || abs => 2,
    sustainedPeak => 2,
    overlap => 2,
    _ => 1,
  };

  String format(double value) => value.toStringAsFixed(decimals);
}

/// The median of [values]; null when empty.
double? medianOf(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return null;
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Spearman's rank correlation of paired values; null under five pairs or
/// when either side is constant.
double? spearman(List<double> a, List<double> b) {
  final n = a.length;
  if (n != b.length || n < 5) return null;
  final ra = _ranks(a);
  final rb = _ranks(b);
  final ma = ra.reduce((x, y) => x + y) / n;
  final mb = rb.reduce((x, y) => x + y) / n;
  var sab = 0.0;
  var saa = 0.0;
  var sbb = 0.0;
  for (var i = 0; i < n; i++) {
    sab += (ra[i] - ma) * (rb[i] - mb);
    saa += (ra[i] - ma) * (ra[i] - ma);
    sbb += (rb[i] - mb) * (rb[i] - mb);
  }
  if (saa == 0 || sbb == 0) return null;
  return sab / math.sqrt(saa * sbb);
}

/// Ranks from 1, ties sharing their mean rank.
List<double> _ranks(List<double> v) {
  final order = List.generate(v.length, (i) => i)
    ..sort((x, y) => v[x].compareTo(v[y]));
  final ranks = List<double>.filled(v.length, 0);
  var i = 0;
  while (i < order.length) {
    var j = i;
    while (j + 1 < order.length && v[order[j + 1]] == v[order[i]]) {
      j++;
    }
    final rank = (i + j) / 2 + 1;
    for (var k = i; k <= j; k++) {
      ranks[order[k]] = rank;
    }
    i = j + 1;
  }
  return ranks;
}
