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
/// The fit is kept only when it is close (≤ 1.5 m rms) and needs no real
/// rescaling (within 1 %): a layout the survey isn't of, or a survey of an
/// older layout, fails it and draws nothing from here.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../../../widgets/charting/charting.dart';
import 'outline_pool.dart';

/// D6's gate.
const publicFitMaxRms = 1.5;
const publicFitMaxScaleError = 0.01;

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
    required this.outline,
  });

  /// Metres between the lap's centre path and the loop, after the fit.
  final double rms;

  /// What the fit had to stretch the lap by; 1 is none.
  final double scale;
  final TrackOutline outline;

  /// D6's gate.
  bool get passes =>
      rms <= publicFitMaxRms && (scale - 1).abs() <= publicFitMaxScaleError;
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

  // 3. The loop's edges, carried back into the lap's frame, as metres
  //    either side of its centre path.
  var squares = 0.0;
  final maxStation = known.map((i) => stations[i]).reduce(math.max);
  final bins = (maxStation / binMetres).floor() + 1;
  final sumLeft = Float64List(bins);
  final sumRight = Float64List(bins);
  final count = Int32List(bins);
  for (var k = 0; k < points.length; k++) {
    final mapped = fit.apply(points[k]);
    final j = matched[k] = line.nearest(mapped, matched[k], 10);
    final miss = line.offsetFrom(mapped, j);
    squares += miss * miss;
    final at = centres[known[k]]!;
    final (l, r) = line.edgesAt(j);
    // Measured in the lap's frame, so which side is which is decided by
    // where the edges land, not by either frame's conventions.
    final a =
        (fit.invert(l) - at.centre).dx * at.toRight.dx +
        (fit.invert(l) - at.centre).dy * at.toRight.dy;
    final b =
        (fit.invert(r) - at.centre).dx * at.toRight.dx +
        (fit.invert(r) - at.centre).dy * at.toRight.dy;
    final station = stations[known[k]];
    if (station < 0) continue;
    final bin = (station / binMetres).floor();
    sumLeft[bin] += math.min(a, b);
    sumRight[bin] += math.max(a, b);
    count[bin]++;
  }
  Float64List mean(Float64List sum) => Float64List.fromList([
    for (var b = 0; b < bins; b++)
      count[b] == 0 ? double.nan : sum[b] / count[b],
  ]);
  final gap = (outlineGapMetres / binMetres).round();
  return CentrelineFit(
    rms: math.sqrt(squares / points.length) / fit.scale,
    scale: fit.scale,
    outline: TrackOutline(
      binMetres: binMetres,
      left: fillGaps(mean(sumLeft), gap),
      right: fillGaps(mean(sumRight), gap),
    ),
  );
}
