/// A circuit's published outline, fitted to a lap (map stage proposal §3.4,
/// D6): the source for layouts the library hardly knows.
///
/// The TUM racetrack database gives each circuit's centreline as a closed
/// loop of points in metres, in a frame of its own, with the track's width
/// either side. A recording's GPS frame is another local frame (SPEC
/// §8.5.1), so the two are matched by shape: the lap's centre path is
/// paired with the loop by distance along it, at every start and in both
/// directions, and the similarity (rotation, scale, shift, mirror) that
/// fits best is refined by matching each point to its nearest on the loop.
/// It is then fitted again on only the points within 3 m of the loop, so a
/// corner rebuilt since the survey doesn't pull the rest.
///
/// What the lap takes from the survey is its widths, at the points within
/// 5 m of its centreline, hung off the lap's own centre path: the game
/// says where the road is, the survey how wide. A rebuilt corner gets no
/// edges from it. The fit is kept only when it is close (≤ 1.5 m rms
/// where it fits), needs no real rescaling (within 1 %) and matches at
/// least 80 % of the lap: a circuit with a corner or two rebuilt keeps the
/// rest of its survey, a layout the survey isn't of draws nothing.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../../../widgets/charting/charting.dart';
import 'outline_pool.dart';

/// D6's gate.
const publicFitMaxRms = 1.5;
const publicFitMaxScaleError = 0.01;

/// A point of the lap matches the survey within this many metres of its
/// centreline: wider than the survey's own scatter (its centrelines are
/// smoothed, and not quite mid-road), narrower than a road.
const publicFitInlierMetres = 3.0;

/// A point takes the survey's widths when it is within this many metres of
/// its centreline: the same road, the survey's line a little off it. More
/// than this, the corner has been rebuilt since (Barcelona's Turn 10 in
/// 2021 misses by 20 m, its old final chicane by 35 m).
const publicMatchMetres = 5.0;

/// The share of the lap that must match.
const publicFitMinShare = 0.8;

/// A closed centreline with the track's width either side, resampled every
/// metre along it.
class Centreline {
  Centreline._(this._xs, this._ys, this._right, this._left);

  /// From the TUM format: `# x_m,y_m,w_tr_right_m,w_tr_left_m`, one point
  /// a line, the loop closing from the last back to the first. Right and
  /// left are of travel in the order the points run, in a frame with y up.
  ///
  /// Throws [FormatException] for anything with fewer than ten points.
  factory Centreline.fromCsv(String csv) {
    final rows = <List<double>>[];
    for (final line in csv.split('\n')) {
      final text = line.trim();
      if (text.isEmpty || text.startsWith('#')) continue;
      final cells = text.split(',').map(double.parse).toList();
      if (cells.length != 4) throw FormatException('not 4 columns', text);
      rows.add(cells);
    }
    if (rows.length < 10) throw const FormatException('too few points');
    // Distance along the loop at each point, the closing leg included.
    final along = Float64List(rows.length + 1);
    for (var i = 1; i <= rows.length; i++) {
      final a = rows[i - 1];
      final b = rows[i % rows.length];
      along[i] =
          along[i - 1] +
          math.sqrt(math.pow(b[0] - a[0], 2) + math.pow(b[1] - a[1], 2));
    }
    final n = along.last.floor();
    final xs = Float64List(n);
    final ys = Float64List(n);
    final right = Float64List(n);
    final left = Float64List(n);
    var seg = 0;
    for (var k = 0; k < n; k++) {
      while (along[seg + 1] < k) {
        seg++;
      }
      final a = rows[seg];
      final b = rows[(seg + 1) % rows.length];
      final span = along[seg + 1] - along[seg];
      final f = span == 0 ? 0.0 : (k - along[seg]) / span;
      double mix(int c) => a[c] + (b[c] - a[c]) * f;
      xs[k] = mix(0);
      ys[k] = mix(1);
      right[k] = mix(2);
      left[k] = mix(3);
    }
    return Centreline._(xs, ys, right, left);
  }

  final Float64List _xs;
  final Float64List _ys;
  final Float64List _right;
  final Float64List _left;

  /// Metres round the loop, and points on it.
  int get length => _xs.length;

  int _wrap(int i) => i % length;

  Offset at(int i) => Offset(_xs[_wrap(i)], _ys[_wrap(i)]);

  /// The loop's direction at [i], a unit vector.
  Offset _tangent(int i) {
    final d = at(i + 1) - at(i - 1);
    return d / d.distance;
  }

  /// The track's width left and right of the loop at [i], in metres.
  (double left, double right) widthsAt(int i) =>
      (_left[_wrap(i)], _right[_wrap(i)]);

  /// The two edges at [i], as points in the loop's frame.
  (Offset left, Offset right) edgesAt(int i) {
    final t = _tangent(i);
    // y up: right of travel is (t.dy, −t.dx).
    final toRight = Offset(t.dy, -t.dx);
    return (
      at(i) - toRight * _left[_wrap(i)],
      at(i) + toRight * _right[_wrap(i)],
    );
  }

  /// The point of the loop nearest [p], searched [window] metres either
  /// side of [near].
  int nearest(Offset p, int near, int window) {
    var best = near;
    var bestD = double.infinity;
    for (var k = near - window; k <= near + window; k++) {
      final d = (at(k) - p).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = k;
      }
    }
    return _wrap(best);
  }

  /// The signed distance from [p] to the loop, measured on the normal at
  /// [i]: what the nearest point leaves over.
  double offsetFrom(Offset p, int i) {
    final t = _tangent(i);
    final d = p - at(i);
    return d.dx * t.dy - d.dy * t.dx;
  }
}

/// A similarity in the plane, as complex arithmetic: `p ↦ s·R·m(p) + t`,
/// where m mirrors y when [mirror] is set. [rotation] carries the scale.
class _Similarity {
  const _Similarity(this.rotation, this.shift, {required this.mirror});

  final Offset rotation; // (re, im): scale · (cos θ, sin θ)
  final Offset shift;
  final bool mirror;

  double get scale => rotation.distance;

  Offset apply(Offset p) {
    final x = p.dx;
    final y = mirror ? -p.dy : p.dy;
    return Offset(
      rotation.dx * x - rotation.dy * y + shift.dx,
      rotation.dx * y + rotation.dy * x + shift.dy,
    );
  }

  Offset invert(Offset q) {
    final d = q - shift;
    final s2 = rotation.distanceSquared;
    final x = (rotation.dx * d.dx + rotation.dy * d.dy) / s2;
    final y = (rotation.dx * d.dy - rotation.dy * d.dx) / s2;
    return Offset(x, mirror ? -y : y);
  }
}

/// The least-squares similarity taking [from] onto [to], and its rms.
({_Similarity fit, double rms}) _procrustes(
  List<Offset> from,
  List<Offset> to, {
  required bool mirror,
}) {
  final n = from.length;
  var ca = Offset.zero;
  var cb = Offset.zero;
  for (var i = 0; i < n; i++) {
    final a = from[i];
    ca += mirror ? Offset(a.dx, -a.dy) : a;
    cb += to[i];
  }
  ca /= n.toDouble();
  cb /= n.toDouble();
  var re = 0.0;
  var im = 0.0;
  var ssa = 0.0;
  var ssb = 0.0;
  for (var i = 0; i < n; i++) {
    final raw = from[i];
    final a = (mirror ? Offset(raw.dx, -raw.dy) : raw) - ca;
    final b = to[i] - cb;
    // conj(a)·b
    re += a.dx * b.dx + a.dy * b.dy;
    im += a.dx * b.dy - a.dy * b.dx;
    ssa += a.distanceSquared;
    ssb += b.distanceSquared;
  }
  if (ssa == 0) {
    return (
      fit: const _Similarity(Offset(1, 0), Offset.zero, mirror: false),
      rms: double.infinity,
    );
  }
  final rotation = Offset(re / ssa, im / ssa);
  final residual = math.max(0.0, ssb - (re * re + im * im) / ssa);
  // t = cb − s·R·ca
  final turned = Offset(
    rotation.dx * ca.dx - rotation.dy * ca.dy,
    rotation.dx * ca.dy + rotation.dy * ca.dx,
  );
  return (
    fit: _Similarity(rotation, cb - turned, mirror: mirror),
    rms: math.sqrt(residual / n),
  );
}

/// How well a centreline fits a lap, and the outline it gives the lap.
class CentrelineFit {
  const CentrelineFit({
    required this.rms,
    required this.scale,
    required this.share,
    required this.outline,
  });

  /// Metres between the lap's centre path and the loop, after the fit,
  /// over the points that match it.
  final double rms;

  /// What the fit had to stretch the lap by; 1 is none.
  final double scale;

  /// The share of the lap's points that match the loop: the rest are where
  /// the circuit has changed since its survey, and have no edges from it.
  final double share;

  /// Edges only where the loop matches the lap.
  final TrackOutline outline;

  /// D6's gate, with most of the lap matching: a few hundred metres
  /// rebuilt is the same circuit, a different shape is not.
  bool get passes =>
      rms <= publicFitMaxRms &&
      (scale - 1).abs() <= publicFitMaxScaleError &&
      share >= publicFitMinShare;
}

/// [line] fitted to a lap whose centre path is [centres] at `Lap Dist`
/// [stations]; null when too little of the lap is known to try.
CentrelineFit? fitCentreline(
  Centreline line, {
  required List<({Offset centre, Offset toRight})?> centres,
  required Float64List stations,
  double binMetres = 2,
}) {
  final known = <int>[
    for (var i = 0; i < centres.length; i++)
      if (centres[i] != null && stations[i].isFinite) i,
  ];
  if (known.length < 50) return null;
  // Distance along the lap's own centre path, which the loop is paired by.
  final along = Float64List(known.length);
  for (var k = 1; k < known.length; k++) {
    along[k] =
        along[k - 1] +
        (centres[known[k]]!.centre - centres[known[k - 1]]!.centre).distance;
  }
  if (along.last < line.length * 0.5) return null;

  // 1. Every start round the loop, both ways, on a sample of the lap.
  const sample = 120;
  final picks = [
    for (var j = 0; j < sample; j++) (j * (known.length - 1)) ~/ (sample - 1),
  ];
  final from = [for (final k in picks) centres[known[k]]!.centre];
  ({_Similarity fit, double rms, int start, int way})? best;
  for (final way in const [1, -1]) {
    for (var start = 0; start < line.length; start += 4) {
      final to = [
        for (final k in picks) line.at(start + way * along[k].round()),
      ];
      for (final mirror in const [false, true]) {
        final f = _procrustes(from, to, mirror: mirror);
        if (best == null || f.rms < best.rms) {
          best = (fit: f.fit, rms: f.rms, start: start, way: way);
        }
      }
    }
  }
  final start = best!.start;
  final way = best.way;
  var fit = best.fit;

  // 2. Each point to its nearest on the loop, refit, a few times over.
  final points = [for (final i in known) centres[i]!.centre];
  final matched = List<int>.generate(
    points.length,
    (k) => start + way * along[k].round(),
  );
  for (var round = 0; round < 6; round++) {
    for (var k = 0; k < points.length; k++) {
      matched[k] = line.nearest(fit.apply(points[k]), matched[k], 40);
    }
    fit = _procrustes(points, [
      for (final j in matched) line.at(j),
    ], mirror: fit.mirror).fit;
  }

  // 3. Again on only the points that match. A circuit changed since its
  //    survey misses in one stretch (Barcelona dropped its final chicane in
  //    2023; the survey is from 2019), and that stretch must neither pull
  //    the rest of the fit nor be drawn.
  double missAt(int k) {
    final mapped = fit.apply(points[k]);
    matched[k] = line.nearest(mapped, matched[k], 10);
    return line.offsetFrom(mapped, matched[k]).abs() / fit.scale;
  }

  var misses = [for (var k = 0; k < points.length; k++) missAt(k)];
  for (var round = 0; round < 4; round++) {
    final keep = [
      for (var k = 0; k < points.length; k++)
        if (misses[k] <= publicFitInlierMetres) k,
    ];
    if (keep.length < 50) break;
    fit = _procrustes(
      [for (final k in keep) points[k]],
      [for (final k in keep) line.at(matched[k])],
      mirror: fit.mirror,
    ).fit;
    misses = [for (var k = 0; k < points.length; k++) missAt(k)];
  }

  // 4. The loop's widths where it matches, hung off the lap's own centre
  //    path. The survey says how wide the road is; where it is comes from
  //    the game, as for the library's outline and the envelope, so a
  //    survey centreline a few metres off (they are smoothed) moves no
  //    edge.
  var squares = 0.0;
  var fitted = 0;
  var used = 0;
  final maxStation = known.map((i) => stations[i]).reduce(math.max);
  final bins = (maxStation / binMetres).floor() + 1;
  final sumLeft = Float64List(bins);
  final sumRight = Float64List(bins);
  final count = Int32List(bins);
  for (var k = 0; k < points.length; k++) {
    final miss = misses[k];
    if (miss <= publicFitInlierMetres) {
      squares += miss * miss;
      fitted++;
    }
    if (miss > publicMatchMetres) continue;
    used++;
    final at = centres[known[k]]!;
    final j = matched[k];
    final (l, r) = line.edgesAt(j);
    // Which of the survey's sides is the lap's right is read off where its
    // edges land in the lap's frame, not from either frame's conventions.
    double across(Offset edge) {
      final d = fit.invert(edge) - at.centre;
      return d.dx * at.toRight.dx + d.dy * at.toRight.dy;
    }

    final (wl, wr) = line.widthsAt(j);
    final same = across(r) > across(l);
    final station = stations[known[k]];
    if (station < 0) continue;
    final bin = (station / binMetres).floor();
    sumLeft[bin] -= (same ? wl : wr) / fit.scale;
    sumRight[bin] += (same ? wr : wl) / fit.scale;
    count[bin]++;
  }
  Float64List mean(Float64List sum) => Float64List.fromList([
    for (var b = 0; b < bins; b++)
      count[b] == 0 ? double.nan : sum[b] / count[b],
  ]);
  final gap = (outlineGapMetres / binMetres).round();
  return CentrelineFit(
    rms: fitted == 0 ? double.infinity : math.sqrt(squares / fitted),
    scale: fit.scale,
    share: used / points.length,
    outline: TrackOutline(
      binMetres: binMetres,
      left: fillGaps(mean(sumLeft), gap),
      right: fillGaps(mean(sumRight), gap),
    ),
  );
}
