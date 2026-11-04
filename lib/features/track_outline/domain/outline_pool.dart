/// A layout's track edges pooled over every recording of it (map stage
/// proposal §3.4, D6 as settled by P0.1).
///
/// One recording knows the edge on the car's side, and only where the car
/// went; a layout's recordings together know both edges nearly everywhere
/// once there are twenty or so. Each recording adds its median edge per
/// station; the pool keeps a sum and a count, so a new recording is added
/// without reading the others again.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../widgets/charting/charting.dart';

/// One station's edges as one recording saw them: metres from the centre
/// path, [left] below zero and [right] above, null where not seen.
typedef EdgeBin = ({int bin, double? left, double? right});

/// How far a side is filled across stations nobody saw: P0.1's 20 m.
const outlineGapMetres = 20.0;

/// Below this share of the lap with both edges known, a layout's outline
/// gives way to the session's envelope (D6).
const outlineMinCoverage = 0.5;

/// The envelope's stations: a session has a few laps, not a library's
/// hundreds, and at 10 Hz one lap leaves a sample every 4 m or so at speed;
/// 10 m stations see two or three a lap.
const envelopeBinMetres = 10.0;

class OutlinePool {
  OutlinePool({this.binMetres = 2});

  final double binMetres;
  final _sumLeft = <double>[];
  final _countLeft = <int>[];
  final _sumRight = <double>[];
  final _countRight = <int>[];

  /// Recordings added.
  int recordings = 0;

  bool get isEmpty => recordings == 0;

  void _grow(int bin) {
    while (_sumLeft.length <= bin) {
      _sumLeft.add(0);
      _countLeft.add(0);
      _sumRight.add(0);
      _countRight.add(0);
    }
  }

  /// One recording's stations.
  void add(Iterable<EdgeBin> bins) {
    for (final (:bin, :left, :right) in bins) {
      if (bin < 0) continue;
      _grow(bin);
      if (left != null && left.isFinite) {
        _sumLeft[bin] += left;
        _countLeft[bin]++;
      }
      if (right != null && right.isFinite) {
        _sumRight[bin] += right;
        _countRight[bin]++;
      }
    }
    recordings++;
  }

  /// The mean edge per station over the recordings that saw it, gaps of up
  /// to [outlineGapMetres] filled.
  TrackOutline outline() {
    Float64List mean(List<double> sum, List<int> count) =>
        Float64List.fromList([
          for (var b = 0; b < sum.length; b++)
            count[b] == 0 ? double.nan : sum[b] / count[b],
        ]);
    final gap = (outlineGapMetres / binMetres).round();
    return TrackOutline(
      binMetres: binMetres,
      left: fillGaps(mean(_sumLeft, _countLeft), gap),
      right: fillGaps(mean(_sumRight, _countRight), gap),
    );
  }

  Map<String, Object?> toJson() => {
    'binMetres': binMetres,
    'recordings': recordings,
    'sumLeft': _sumLeft,
    'countLeft': _countLeft,
    'sumRight': _sumRight,
    'countRight': _countRight,
  };

  /// Null for anything that isn't a pool this version wrote.
  static OutlinePool? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      final pool = OutlinePool(
        binMetres: (json['binMetres']! as num).toDouble(),
      )..recordings = json['recordings']! as int;
      List<T> list<T>(String key, T Function(num) f) => [
        for (final v in json[key]! as List) f(v as num),
      ];
      final sumLeft = list('sumLeft', (v) => v.toDouble());
      final countLeft = list('countLeft', (v) => v.toInt());
      final sumRight = list('sumRight', (v) => v.toDouble());
      final countRight = list('countRight', (v) => v.toInt());
      final n = sumLeft.length;
      if (countLeft.length != n ||
          sumRight.length != n ||
          countRight.length != n) {
        return null;
      }
      pool
        .._sumLeft.addAll(sumLeft)
        .._countLeft.addAll(countLeft)
        .._sumRight.addAll(sumRight)
        .._countRight.addAll(countRight);
      return pool;
    } on Object {
      return null;
    }
  }
}

/// [values] with each run of NaN no longer than [maxBins] filled straight
/// across from the known value either side; longer runs, and runs at either
/// end, stay NaN.
Float64List fillGaps(Float64List values, int maxBins) {
  final out = Float64List.fromList(values);
  final n = values.length;
  var i = 0;
  while (i < n) {
    if (!values[i].isNaN) {
      i++;
      continue;
    }
    final start = i;
    while (i < n && values[i].isNaN) {
      i++;
    }
    final before = start - 1;
    final after = i;
    if (before < 0 || after >= n || after - before - 1 > maxBins) continue;
    final a = values[before];
    final b = values[after];
    for (var k = start; k < after; k++) {
      out[k] = a + (b - a) * (k - before) / (after - before);
    }
  }
  return out;
}

/// The session's envelope as an outline: how far either side its laps
/// went, widened by [carHalfWidth] since `Path Lateral` is the car's
/// centre, gaps filled as a pooled outline's are.
TrackOutline envelopeOutline(
  List<EdgeBin> bins, {
  double binMetres = envelopeBinMetres,
  double carHalfWidth = 1,
}) {
  final n = bins.fold(0, (m, b) => math.max(m, b.bin + 1));
  final left = Float64List(n)..fillRange(0, n, double.nan);
  final right = Float64List(n)..fillRange(0, n, double.nan);
  for (final (:bin, left: l, right: r) in bins) {
    if (bin < 0 || l == null || r == null) continue;
    left[bin] = math.min(l, 0) - carHalfWidth;
    right[bin] = math.max(r, 0) + carHalfWidth;
  }
  final gap = (outlineGapMetres / binMetres).round();
  return TrackOutline(
    binMetres: binMetres,
    left: fillGaps(left, gap),
    right: fillGaps(right, gap),
  );
}
