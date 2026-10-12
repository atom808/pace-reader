/// Where on the track each lap ran, and whether two files' tracks are one
/// (comparison proposal §4 "Course" part 3 and "Centre path", §6 "Line
/// panel").
///
/// Everything here is measured at equal `Lap Dist`, the station along the
/// course's centre path. `Path Lateral` is the car's distance from that path,
/// + to the right; so each lap carries the path itself too, as
/// c = p − PL·n_right, which is how two files are shown to be one course.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../../../data/models/models.dart';
import '../../../data/repositories/lap_telemetry.dart';
import '../../../widgets/charting/charting.dart';

/// A flat frame in metres, x east and y north, shared by every lap it
/// projects (§6 "Map paths"): the game's GPS is one synthetic frame near
/// 60° N in every file of a layout, so one origin serves both files.
class LocalFrame {
  LocalFrame(this.originLatitude, this.originLongitude)
    : _longitudeScale =
          metresPerDegreeLatitude * math.cos(originLatitude * math.pi / 180);

  /// Centred on [lap]'s mean position; null without GPS.
  static LocalFrame? around(LapTelemetry lap) {
    final latitude = lap.latitude;
    final longitude = lap.longitude;
    if (latitude == null || longitude == null || latitude.isEmpty) return null;
    var lat = 0.0;
    var lon = 0.0;
    for (var i = 0; i < latitude.length; i++) {
      lat += latitude.lows[i];
      lon += longitude.lows[i];
    }
    return LocalFrame(lat / latitude.length, lon / latitude.length);
  }

  final double originLatitude;
  final double originLongitude;
  final double _longitudeScale;

  Offset project(double latitude, double longitude) => Offset(
    (longitude - originLongitude) * _longitudeScale,
    (latitude - originLatitude) * metresPerDegreeLatitude,
  );
}

/// Which way the course bends at a station.
enum TurnSide {
  left,
  right;

  String get label => name;
}

/// One lap's line: its samples where they can be compared — on track, and
/// with `Lap Dist` running forwards — and the course's centre path
/// reconstructed from them.
class LapLine {
  LapLine._({
    required this.times,
    required this.stations,
    required this.pathLateral,
    required this.trackEdge,
    required this.centreStations,
    required this.centreXs,
    required this.centreYs,
  });

  /// Two samples further apart than this along the lap have nothing between
  /// them to compare against: a pit-lane stay cut out, or a gap in the
  /// recording. At 10 Hz the fastest samples are 9 m apart, at the
  /// fixtures' 5 Hz 16 m.
  static const maxGap = 30.0;

  /// [lap]'s line in [frame], or null when it lacks `Lap Dist`, GPS or
  /// `Path Lateral`, or they are not sampled together.
  ///
  /// Samples inside [pitLane] are dropped: the pit lane is found only through
  /// `In Pits`, and Path Lateral there reaches 15 m while staying inside
  /// on-track ranges, so nothing else would catch it (§4 "Pit-lane laps").
  ///
  /// [heading], where it gives one, is the course's heading at a station,
  /// in place of the one this lap's own passes converge on: see [pair].
  static LapLine? of(
    LapTelemetry lap, {
    required LocalFrame frame,
    List<PitInterval> pitLane = const [],
    Offset? Function(double station)? heading,
  }) {
    final distance = lap.lapDistance;
    final latitude = lap.latitude;
    final longitude = lap.longitude;
    final lateral = lap.pathLateral;
    final edge = lap.trackEdge;
    if (distance == null ||
        latitude == null ||
        longitude == null ||
        lateral == null) {
      return null;
    }
    final n = distance.length;
    // All four are 10 Hz on one master grid, read over one window, so sample
    // i is one instant in each. Anything else is not this file's layout.
    if (n < 3 ||
        latitude.length != n ||
        longitude.length != n ||
        lateral.length != n ||
        (edge != null && edge.length != n)) {
      return null;
    }

    final times = <double>[];
    final stations = <double>[];
    final pl = <double>[];
    final te = <double>[];
    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final t = distance.times[i];
      final d = distance.lows[i];
      if (stations.isNotEmpty && d <= stations.last) continue;
      if (pitLane.any((p) => p.overlaps(t, t + 1e-9))) continue;
      times.add(t);
      stations.add(d);
      pl.add(lateral.lows[i]);
      if (edge != null) te.add(edge.lows[i]);
      points.add(frame.project(latitude.lows[i], longitude.lows[i]));
    }
    if (stations.length < 3) return null;

    // Passes (§4 "Centre path"). The first takes the normal from the car's
    // own heading, which leans off the course's wherever the car is moving
    // across it; each later one takes it from the centre path the pass
    // before found, which converges on the course's heading. Two are not
    // enough where the car runs far from the centre through a tight turn:
    // 11 m wide of it at COTA's turn 1, the second pass still left 3.35 m.
    var centres = _centres(points, pl, (i) => _tangent(points, i));
    for (var pass = 1; pass < _passes; pass++) {
      final previous = _Polyline(stations, centres);
      centres = _centres(
        points,
        pl,
        (i) =>
            heading?.call(stations[i]) ??
            previous.tangentAt(stations[i], _tangentHalfWindow),
      );
    }

    // Off the track, `Lap Dist` is the game's projection of a car that is
    // nowhere near the centre path — it jumps where a car cuts across — so
    // a centre rebuilt from there is not the course's. Path Lateral runs
    // past the near edge by more than a car's width only off the track.
    final onTrack = [
      for (var i = 0; i < stations.length; i++)
        te.isEmpty || te[i] == 0 || pl[i].abs() <= te[i].abs() + offTrackMargin,
    ];
    return LapLine._(
      times: Float64List.fromList(times),
      stations: Float64List.fromList(stations),
      pathLateral: Float64List.fromList(pl),
      trackEdge: edge == null ? null : Float64List.fromList(te),
      centreStations: Float64List.fromList([
        for (var i = 0; i < stations.length; i++)
          if (onTrack[i]) stations[i],
      ]),
      centreXs: Float64List.fromList([
        for (var i = 0; i < centres.length; i++)
          if (onTrack[i]) centres[i].dx,
      ]),
      centreYs: Float64List.fromList([
        for (var i = 0; i < centres.length; i++)
          if (onTrack[i]) centres[i].dy,
      ]),
    );
  }

  /// [base] and [target], rebuilt on one set of normals.
  ///
  /// Each lap's own heading, however well its passes converge, leaves two
  /// laps' normals a few degrees apart in a tight turn, and far from the
  /// centre a few degrees are metres: 2.9 m between two laps of one course,
  /// both 11 m wide of the centre at COTA's turn 1. So, as the library probe
  /// took every lap's normal from one reference centre, both laps here take
  /// it, station by station, from the centre path of whichever ran nearer
  /// the centre there — the lap whose own heading was nearest the course's
  /// to begin with. Two laps of one course then differ only where they
  /// truly ran apart: 1.6 m at worst over 208 library pairs at Sebring and
  /// COTA.
  static (LapLine?, LapLine?) pair(
    LapTelemetry base,
    LapTelemetry target, {
    required LocalFrame frame,
    List<PitInterval> basePitLane = const [],
    List<PitInterval> targetPitLane = const [],
  }) {
    final a = of(base, frame: frame, pitLane: basePitLane);
    final b = of(target, frame: frame, pitLane: targetPitLane);
    if (a == null || b == null) return (a, b);
    Offset? heading(double station) {
      final pa = a.pathLateralAt(station);
      final pb = b.pathLateralAt(station);
      final nearer = pa == null
          ? b
          : pb == null || pa.abs() <= pb.abs()
          ? a
          : b;
      return nearer._centre.tangentAt(station, _tangentHalfWindow);
    }

    return (
      of(base, frame: frame, pitLane: basePitLane, heading: heading),
      of(target, frame: frame, pitLane: targetPitLane, heading: heading),
    );
  }

  /// How far past its edge a car's centre may be and still count as on the
  /// track: two wheels off, not four.
  static const offTrackMargin = 2.0;

  /// See [LapLine.of].
  static const _passes = 3;

  /// Metres either side over which the second pass takes the centre path's
  /// heading: wide enough to average out the GPS's 0.42 m latitude steps,
  /// narrow next to any corner's radius.
  static const _tangentHalfWindow = 5.0;

  static Offset _tangent(List<Offset> points, int i) {
    final a = points[math.max(i - 1, 0)];
    final b = points[math.min(i + 1, points.length - 1)];
    return b - a;
  }

  static List<Offset> _centres(
    List<Offset> points,
    List<double> lateral,
    Offset? Function(int) tangentAt,
  ) => [
    for (var i = 0; i < points.length; i++)
      switch (tangentAt(i)) {
        final t? when t.distance > 0 =>
          // The right-hand normal of a heading (x east, y north) is the
          // heading turned a quarter clockwise.
          points[i] - Offset(t.dy, -t.dx) / t.distance * lateral[i],
        _ => points[i],
      },
  ];

  /// Seconds on the lap's clock, `Lap Dist`, `Path Lateral` and, where the
  /// file has it, `Track Edge`, for every kept sample.
  final Float64List times;
  final Float64List stations;
  final Float64List pathLateral;
  final Float64List? trackEdge;

  /// The reconstructed centre path, metres in the frame it was built in, at
  /// the samples taken on the track.
  final Float64List centreStations;
  final Float64List centreXs;
  final Float64List centreYs;

  int get length => stations.length;

  late final _Polyline _centre = _Polyline(centreStations, [
    for (var i = 0; i < centreStations.length; i++)
      Offset(centreXs[i], centreYs[i]),
  ]);

  /// `Path Lateral` at [station], or null where the lap has no samples
  /// around it.
  double? pathLateralAt(double station) {
    final k = _bracket(stations, station);
    if (k == null) return null;
    final u = (station - stations[k]) / (stations[k + 1] - stations[k]);
    return pathLateral[k] + (pathLateral[k + 1] - pathLateral[k]) * u;
  }

  /// The centre path at [station].
  Offset? centreAt(double station) => _centre.at(station);

  /// Which way the centre path bends at [station], from the heading change
  /// over [halfWindow] metres either side; null on a straight or where the
  /// lap does not reach. The car's own path and its steering are no use
  /// here: the line through a corner is the very thing being compared, and
  /// steering flips sign under countersteer (§6).
  TurnSide? turnAt(double station, {double halfWindow = 25}) {
    final a = centreAt(station - halfWindow);
    final b = centreAt(station);
    final c = centreAt(station + halfWindow);
    if (a == null || b == null || c == null) return null;
    final h1 = math.atan2((b - a).dy, (b - a).dx);
    final h2 = math.atan2((c - b).dy, (c - b).dx);
    var turn = h2 - h1;
    while (turn > math.pi) {
      turn -= 2 * math.pi;
    }
    while (turn < -math.pi) {
      turn += 2 * math.pi;
    }
    final curvature = turn / halfWindow;
    if (curvature.abs() < 1 / straightRadius) return null;
    return curvature > 0 ? TurnSide.left : TurnSide.right;
  }

  /// A bend gentler than this radius is a straight, as far as "inside" goes.
  static const straightRadius = 1000.0;
}

/// The index k with `xs[k] <= x <= xs[k + 1]`, when the two are no further
/// apart than [LapLine.maxGap]; null outside or across a gap.
int? _bracket(List<double> xs, double x) {
  if (xs.length < 2 || x < xs.first || x > xs.last) return null;
  var lo = 0;
  var hi = xs.length - 1;
  while (hi - lo > 1) {
    final mid = (lo + hi) >> 1;
    if (xs[mid] <= x) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return xs[hi] - xs[lo] > LapLine.maxGap ? null : lo;
}

class _Polyline {
  _Polyline(this.stations, this.points);

  final List<double> stations;
  final List<Offset> points;

  Offset? at(double station) {
    final k = _bracket(stations, station);
    if (k == null) return null;
    final u = (station - stations[k]) / (stations[k + 1] - stations[k]);
    return Offset.lerp(points[k], points[k + 1], u);
  }

  /// The heading at [station], as the chord across [halfWindow] metres
  /// either side, shortened at the ends of the line.
  Offset? tangentAt(double station, double halfWindow) {
    if (stations.length < 2) return null;
    final from = at(math.max(station - halfWindow, stations.first));
    final to = at(math.min(station + halfWindow, stations.last));
    if (from == null || to == null) return null;
    return to - from;
  }
}

/// How far apart two laps' centre paths run, compared every [binMetres] of
/// `Lap Dist` where both laps are on track (§4).
class CentreComparison {
  const CentreComparison({
    required this.bins,
    required this.rms,
    required this.max,
    required this.maxStation,
  });

  /// Compares [base] and [target], built in one [LocalFrame].
  ///
  /// Null when they share no stretch to compare.
  static CentreComparison? between(
    LapLine base,
    LapLine target, {
    double binMetres = 5,
  }) {
    final from = math.max(base.stations.first, target.stations.first);
    final to = math.min(base.stations.last, target.stations.last);
    var bins = 0;
    var sumSquares = 0.0;
    var worst = 0.0;
    var worstAt = 0.0;
    for (var k = (from / binMetres).floor(); ; k++) {
      final station = (k + 0.5) * binMetres;
      if (station > to) break;
      final a = base.centreAt(station);
      final b = target.centreAt(station);
      if (a == null || b == null) continue;
      final apart = (a - b).distance;
      bins++;
      sumSquares += apart * apart;
      if (apart > worst) {
        worst = apart;
        worstAt = station;
      }
    }
    if (bins == 0) return null;
    return CentreComparison(
      bins: bins,
      rms: math.sqrt(sumSquares / bins),
      max: worst,
      maxStation: worstAt,
    );
  }

  /// Course part 3 (D2): a centre path further than this from the other's
  /// anywhere is another course. 1.7× the worst same-course pair in the
  /// library (1.73 m, Le Mans).
  static const courseLimit = 3.0;

  /// The Line panel's gate: the library's worst same-course pair is
  /// 0.264 m rms, and a flipped `Path Lateral` sign gives 5.05 m or more.
  static const lineLimit = 0.5;

  final int bins;
  final double rms;
  final double max;

  /// Where [max] was found, in metres of `Lap Dist`.
  final double maxStation;

  bool get sameCourse => max <= courseLimit;
  bool get linesComparable => rms <= lineLimit;
}

/// Whether two laps found the same track edges where they ran on the same
/// side of the track: informational only, since a game update moves them
/// while the centre path and `Path Lateral` stay comparable (§4 "Track
/// Edge").
class TrackEdgeAgreement {
  const TrackEdgeAgreement({
    required this.matched,
    required this.equal,
    required this.differing,
  });

  /// Matches each of [base]'s samples to [target]'s nearest on the same
  /// side within [matchMetres] of `Lap Dist` (5 m bins proved unusable).
  /// Null when either lap lacks `Track Edge`, or no sample matched.
  static TrackEdgeAgreement? between(
    LapLine base,
    LapLine target, {
    double matchMetres = 0.5,
  }) {
    final a = base.trackEdge;
    final b = target.trackEdge;
    if (a == null || b == null) return null;
    final windows = <int, (int, int)>{};
    var matched = 0;
    var equal = 0;
    var j = 0;
    for (var i = 0; i < base.length; i++) {
      final station = base.stations[i];
      final edge = a[i];
      if (edge == 0) continue;
      while (j < target.length && target.stations[j] < station - matchMetres) {
        j++;
      }
      int? nearest;
      for (
        var k = j;
        k < target.length && target.stations[k] <= station + matchMetres;
        k++
      ) {
        if (b[k].sign != edge.sign) continue;
        if (nearest == null ||
            (target.stations[k] - station).abs() <
                (target.stations[nearest] - station).abs()) {
          nearest = k;
        }
      }
      if (nearest == null) continue;
      final same = (b[nearest] - edge).abs() <= _sameEdge;
      matched++;
      if (same) equal++;
      final w = (station / windowMetres).floor();
      final (m, e) = windows[w] ?? (0, 0);
      windows[w] = (m + 1, e + (same ? 1 : 0));
    }
    if (matched == 0) return null;

    // Where they differ, as stretches of whole windows.
    final differing = <(double, double)>[];
    final keys = windows.keys.toList()..sort();
    for (final w in keys) {
      final (m, e) = windows[w]!;
      if (m < 3 || e / m >= agreeingShare) continue;
      final from = w * windowMetres;
      if (differing.isNotEmpty && differing.last.$2 == from) {
        differing.last = (differing.last.$1, from + windowMetres);
      } else {
        differing.add((from, from + windowMetres));
      }
    }
    return TrackEdgeAgreement(
      matched: matched,
      equal: equal,
      differing: differing,
    );
  }

  /// `Track Edge` is written to the millimetre: one edge reads the same.
  static const _sameEdge = 0.0005;

  /// Within one recording, 93–99% of matched samples agree (min 88.9%).
  static const agreeingShare = 0.85;

  /// How finely [differing] is reported.
  static const windowMetres = 250.0;

  final int matched;
  final int equal;

  /// Stretches of `Lap Dist`, in [windowMetres] steps, where under
  /// [agreeingShare] of the samples agree.
  final List<(double, double)> differing;

  double get share => equal / matched;
  bool get agrees => share >= agreeingShare;

  /// "250–750 m, 2000–2250 m".
  String get differingText => [
    for (final (from, to) in differing)
      '${from.toStringAsFixed(0)}–${to.toStringAsFixed(0)} m',
  ].join(', ');
}

/// The Target's `Path Lateral` less Base's at Base's samples: + where the
/// Target ran further right (§6). Null where they share no stretch.
TraceSeries? pathLateralDifference(LapLine base, LapLine target) {
  final times = <double>[];
  final values = <double>[];
  for (var i = 0; i < base.length; i++) {
    final other = target.pathLateralAt(base.stations[i]);
    if (other == null) continue;
    times.add(base.times[i]);
    values.add(other - base.pathLateral[i]);
  }
  if (times.length < 2) return null;
  final v = Float64List.fromList(values);
  return TraceSeries(
    channelName: 'ΔPath Lateral',
    unit: 'm',
    frequencyHz: 10,
    valueColumn: 'value',
    times: Float64List.fromList(times),
    lows: v,
    highs: v,
  );
}

/// [lap]'s `Path Lateral` where it can be compared: on track, `Lap Dist`
/// running forwards.
TraceSeries pathLateralOf(LapLine lap) => TraceSeries(
  channelName: pathLateralChannelName,
  unit: 'm',
  frequencyHz: 10,
  valueColumn: 'value',
  times: lap.times,
  lows: lap.pathLateral,
  highs: lap.pathLateral,
);

/// The Line panel's floor: line differences under this are not stated.
/// `Path Lateral`'s own noise is p95 0.09 m.
const lineFloor = 0.5;

/// The two laps' lines at [station] in words, or null where either lap
/// does not reach it.
///
/// "Target 3.1 m further right, the inside of this right-hander".
String? lineAt(LapLine base, LapLine target, double station) {
  final a = base.pathLateralAt(station);
  final b = target.pathLateralAt(station);
  if (a == null || b == null) return null;
  final difference = b - a;
  if (difference.abs() < lineFloor) {
    return 'Target within ${lineFloor.toStringAsFixed(1)} m of Base';
  }
  final side = difference > 0 ? 'right' : 'left';
  final words = 'Target ${difference.abs().toStringAsFixed(1)} m further $side';
  final turn = base.turnAt(station);
  if (turn == null) return words;
  final inside = (turn == TurnSide.right) == (difference > 0);
  return '$words, the ${inside ? 'inside' : 'outside'} of this '
      '${turn.label}-hander';
}
