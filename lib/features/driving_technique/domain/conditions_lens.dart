/// The conditions lens (SPEC.md §8.13.6): how a change of grip, compound or
/// electronics moved each segment, within one session.
///
/// The session's racing laps are split by one condition, and each segment's
/// time, slowest speed and TC/ABS time are compared across the split. Three
/// rules keep the comparison honest, each from the library's natural
/// experiments:
///
/// - **Drift is removed where it can be.** When a setting alternates (TC cut
///   8 / 9 / 8 at Imola, mixture maps lap by lap), each measure is regressed
///   on lap number and the group together, and the group's coefficient is
///   the change (Frisch–Waugh): fuel burn and tyre wear ride on lap number.
///   When it changed once, the laps either side are compared as they are, and
///   the result says it could not adjust.
/// - **Noise is said.** A change under two standard errors is "within
///   lap-to-lap noise". That covers most of the TC-cut and every mixture-map
///   result measured.
/// - **What changed together is named.** In all four wet Daytona races the
///   compound, the TC level and the wetness changed on the same lap, so a
///   wet-against-dry contrast is "wet, as the driver ran it".
library;

import 'dart:math' as math;

import 'technique_thresholds.dart';

/// A condition the lens can split laps by. Each is read per lap as the value
/// in force at the lap's start; a lap where it changed is left out of that
/// lens.
enum LensCondition {
  wetness('Track wetness', 'wetness'),
  compound('Tyre compound', 'compound'),
  tcLevel('TC level', 'TC level'),
  tcCut('TC power cut', 'TC cut'),
  tcSlip('TC slip angle', 'TC slip'),
  absLevel('ABS level', 'ABS level'),
  brakeBias('Brake bias', 'brake bias'),
  brakeMigration('Brake migration', 'brake migration'),
  mixture('Fuel mixture map', 'mixture map');

  const LensCondition(this.title, this.short);

  final String title;

  /// Lower case, for "changed together" lists.
  final String short;

  /// [value] as the lens shows it. A compound stays an index: the file names
  /// none, and index 3 is the wet tyre only by inference (§15.20).
  String format(double value) => switch (this) {
    wetness => value >= 1 ? 'wet' : 'dry',
    compound => '${value.round()}',
    // `Brake Bias Rear` is the rear's share: 0.4875 is 48.8 % rear.
    brakeBias => '${(value * 100).toStringAsFixed(1)} % rear',
    _ => _trim(value),
  };

  /// A change from [from] to [to], in a sentence: "compound 0 → 3".
  String change(double from, double to) => this == wetness
      ? '${format(from)} → ${format(to)}'
      : '$short ${format(from)} → ${format(to)}';
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// One racing lap as the lens sees it.
class LensLap {
  const LensLap({
    required this.lap,
    required this.lapTime,
    required this.conditions,
    this.segmentTimes = const [],
    this.slowest = const [],
    this.tc = const [],
    this.abs = const [],
  });

  /// `Lap.index`: the lap-number trend runs on it.
  final int lap;
  final double lapTime;

  /// Each condition's value at the lap's start; absent, or null, where the
  /// file lacks it or it changed during the lap.
  final Map<LensCondition, double?> conditions;

  /// Per segment, in table order; null where the lap has no value there.
  final List<double?> segmentTimes;
  final List<double?> slowest;
  final List<double?> tc;
  final List<double?> abs;
}

/// One contrast the lens can draw: [other] against [baseline].
class LensOption {
  const LensOption({
    required this.condition,
    required this.baseline,
    required this.other,
    required this.baselineLaps,
    required this.otherLaps,
  });

  final LensCondition condition;

  /// The value most racing laps ran with.
  final double baseline;
  final double other;
  final int baselineLaps;
  final int otherLaps;

  String get label =>
      '${condition.title}: ${condition.format(baseline)} → '
      '${condition.format(other)}';

  @override
  bool operator ==(Object other) =>
      other is LensOption &&
      other.condition == condition &&
      other.baseline == baseline &&
      other.other == this.other;

  @override
  int get hashCode => Object.hash(condition, baseline, other);
}

/// Every contrast [laps] support: for each condition that changed, every
/// value with at least [TechniqueThresholds.lensMinimumLaps] laps against the
/// value most laps ran with.
List<LensOption> lensOptions(List<LensLap> laps) {
  final out = <LensOption>[];
  for (final condition in LensCondition.values) {
    final counts = <double, int>{};
    for (final lap in laps) {
      final v = lap.conditions[condition];
      if (v != null) counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.length < 2) continue;
    final ranked = counts.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
    final baseline = ranked.first;
    if (baseline.value < TechniqueThresholds.lensMinimumLaps) continue;
    for (final other in ranked.skip(1)) {
      if (other.value < TechniqueThresholds.lensMinimumLaps) continue;
      out.add(
        LensOption(
          condition: condition,
          baseline: baseline.key,
          other: other.key,
          baselineLaps: baseline.value,
          otherLaps: other.value,
        ),
      );
    }
  }
  return out;
}

/// A measured change, other minus baseline.
class LensEffect {
  const LensEffect(this.change, this.standardError);

  static const none = LensEffect(null, null);

  final double? change;
  final double? standardError;

  /// Under two standard errors, or not measurable at all.
  bool get withinNoise =>
      change == null ||
      standardError == null ||
      change!.abs() < TechniqueThresholds.noiseStandardErrors * standardError!;
}

/// One segment's changes.
class SegmentLens {
  const SegmentLens({
    required this.index,
    required this.time,
    required this.slowest,
    required this.tc,
    required this.abs,
    this.baselineTime,
  });

  /// Position in the segment table, from 0.
  final int index;
  final LensEffect time;
  final LensEffect slowest;
  final LensEffect tc;
  final LensEffect abs;

  /// The baseline group's mean segment time, for the change as a share.
  final double? baselineTime;

  double? get timeShare {
    final c = time.change;
    final b = baselineTime;
    return c == null || b == null || b <= 0 ? null : c / b;
  }
}

/// What the lens shows for one option.
class LensResult {
  const LensResult({
    required this.option,
    required this.adjusted,
    required this.changedTogether,
    required this.lapTime,
    required this.segments,
    required this.baselineLaps,
    required this.otherLaps,
  });

  final LensOption option;

  /// Whether the lap-number trend was removed (the setting alternated).
  final bool adjusted;

  /// The other conditions whose usual value differs between the groups, as
  /// "compound 0 → 3".
  final List<String> changedTogether;
  final LensEffect lapTime;
  final List<SegmentLens> segments;

  /// Laps used either side, after dropping each group's outliers.
  final int baselineLaps;
  final int otherLaps;

  /// The segment indices in order of time lost as a share, largest first.
  List<int> get rankedByShare {
    final known = [
      for (final s in segments)
        if (s.timeShare != null) s,
    ]..sort((a, b) => b.timeShare!.compareTo(a.timeShare!));
    return [for (final s in known) s.index];
  }
}

/// [option]'s contrast over [laps].
LensResult measureLens(LensOption option, List<LensLap> laps) {
  final grouped = <(LensLap, int)>[];
  for (final lap in laps) {
    final v = lap.conditions[option.condition];
    if (v == option.baseline) grouped.add((lap, 0));
    if (v == option.other) grouped.add((lap, 1));
  }
  // Each group's outliers go: a lap behind traffic or with a mistake would
  // otherwise own its group's mean.
  double groupMedian(int g) {
    final times = [
      for (final (lap, x) in grouped)
        if (x == g) lap.lapTime,
    ]..sort();
    if (times.isEmpty) return double.infinity;
    final mid = times.length ~/ 2;
    return times.length.isOdd ? times[mid] : (times[mid - 1] + times[mid]) / 2;
  }

  final limits = [
    groupMedian(0) * TechniqueThresholds.lensOutlier,
    groupMedian(1) * TechniqueThresholds.lensOutlier,
  ];
  final kept = [
    for (final (lap, x) in grouped)
      if (lap.lapTime <= limits[x]) (lap, x),
  ]..sort((a, b) => a.$1.lap.compareTo(b.$1.lap));

  var switches = 0;
  for (var i = 1; i < kept.length; i++) {
    if (kept[i].$2 != kept[i - 1].$2) switches++;
  }
  final adjusted = switches >= 2;

  LensEffect effect(double? Function(LensLap) y) {
    final points = [
      for (final (lap, x) in kept)
        if (y(lap) case final v?) (lap.lap.toDouble(), x.toDouble(), v),
    ];
    return adjusted ? _adjustedEffect(points) : _meanDifference(points);
  }

  final segmentCount = kept.isEmpty
      ? 0
      : kept.map((e) => e.$1.segmentTimes.length).reduce(math.max);
  double? at(List<double?> list, int i) => i < list.length ? list[i] : null;
  final segments = [
    for (var s = 0; s < segmentCount; s++)
      SegmentLens(
        index: s,
        time: effect((l) => at(l.segmentTimes, s)),
        slowest: effect((l) => at(l.slowest, s)),
        tc: effect((l) => at(l.tc, s)),
        abs: effect((l) => at(l.abs, s)),
        baselineTime: _mean([
          for (final (lap, x) in kept)
            if (x == 0) ?at(lap.segmentTimes, s),
        ]),
      ),
  ];

  return LensResult(
    option: option,
    adjusted: adjusted,
    changedTogether: _changedTogether(option, kept),
    lapTime: effect((l) => l.lapTime),
    segments: segments,
    baselineLaps: kept.where((e) => e.$2 == 0).length,
    otherLaps: kept.where((e) => e.$2 == 1).length,
  );
}

List<String> _changedTogether(LensOption option, List<(LensLap, int)> kept) {
  final out = <String>[];
  for (final condition in LensCondition.values) {
    if (condition == option.condition) continue;
    double? usual(int g) {
      final counts = <double, int>{};
      for (final (lap, x) in kept) {
        if (x != g) continue;
        final v = lap.conditions[condition];
        if (v != null) counts[v] = (counts[v] ?? 0) + 1;
      }
      if (counts.isEmpty) return null;
      return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }

    final a = usual(0);
    final b = usual(1);
    if (a != null && b != null && a != b) out.add(condition.change(a, b));
  }
  return out;
}

double? _mean(List<double> v) =>
    v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

/// Other minus baseline, with Welch's standard error.
LensEffect _meanDifference(List<(double, double, double)> points) {
  final a = [
    for (final (_, x, y) in points)
      if (x == 0) y,
  ];
  final b = [
    for (final (_, x, y) in points)
      if (x == 1) y,
  ];
  if (a.length < 2 || b.length < 2) return LensEffect.none;
  final ma = _mean(a)!;
  final mb = _mean(b)!;
  double variance(List<double> v, double m) =>
      v.fold(0.0, (s, e) => s + (e - m) * (e - m)) / (v.length - 1);
  final se = math.sqrt(variance(a, ma) / a.length + variance(b, mb) / b.length);
  return LensEffect(mb - ma, se);
}

/// The group's coefficient in y = a + b·lap + c·group, by least squares, with
/// its standard error.
LensEffect _adjustedEffect(List<(double, double, double)> points) {
  final n = points.length;
  if (n < 4) return LensEffect.none;
  // XᵀX and Xᵀy for columns (1, lap, group).
  final xtx = List.generate(3, (_) => List<double>.filled(3, 0));
  final xty = List<double>.filled(3, 0);
  for (final (lap, x, y) in points) {
    final row = [1.0, lap, x];
    for (var i = 0; i < 3; i++) {
      xty[i] += row[i] * y;
      for (var j = 0; j < 3; j++) {
        xtx[i][j] += row[i] * row[j];
      }
    }
  }
  final inverse = _invert3(xtx);
  if (inverse == null) return LensEffect.none;
  final beta = [
    for (var i = 0; i < 3; i++)
      inverse[i][0] * xty[0] + inverse[i][1] * xty[1] + inverse[i][2] * xty[2],
  ];
  var rss = 0.0;
  for (final (lap, x, y) in points) {
    final r = y - (beta[0] + beta[1] * lap + beta[2] * x);
    rss += r * r;
  }
  final variance = rss / (n - 3);
  final se = math.sqrt(math.max(0, variance * inverse[2][2]));
  return LensEffect(beta[2], se);
}

List<List<double>>? _invert3(List<List<double>> m) {
  final a = m[0][0], b = m[0][1], c = m[0][2];
  final d = m[1][0], e = m[1][1], f = m[1][2];
  final g = m[2][0], h = m[2][1], i = m[2][2];
  final det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
  if (det.abs() < 1e-12) return null;
  return [
    [(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det],
    [(f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det],
    [(d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det],
  ];
}
