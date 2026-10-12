/// The lap cut into segments (comparison proposal §5): where the corners are,
/// where one segment hands over to the next, and which lap decided both.
///
/// Pure: everything here takes plain arrays, so the detector runs in a plain
/// `flutter test` on the 5 Hz fixtures exactly as it runs in the app on a
/// native read.
///
/// ## What a segment is
///
/// A braking zone, a corner and the straight after it. Corners are the
/// canonical lap's speed minima that stand out by at least a threshold
/// (their topographic prominence); boundaries are its top speed between two
/// consecutive corners. On Sebring's canonical lap a boundary lands within
/// 4 m of the next brake point, so an exit-speed loss lands on the corner
/// that caused it.
///
/// ## Why one table per course, frozen
///
/// Re-detected per comparison, "Seg 3" would mean different metres each time
/// the Target changed: across the user's library, re-picking the canonical
/// lap moves boundaries by p95 13–97 m and per-segment losses by p95
/// 0.02–0.15 s. So the table is detected once per (TrackName, TrackLayout),
/// from one canonical lap, and kept.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';

/// One course, as segment tables are keyed: a layout variant never borrows
/// another's table (§4 "Nothing keyed by course crosses between variants").
class TrackKey {
  const TrackKey(this.trackName, this.trackLayout);

  factory TrackKey.of(SessionMetadata metadata) =>
      TrackKey(metadata.trackName, metadata.trackLayout);

  final String trackName;
  final String trackLayout;

  @override
  bool operator ==(Object other) =>
      other is TrackKey &&
      other.trackName == trackName &&
      other.trackLayout == trackLayout;

  @override
  int get hashCode => Object.hash(trackName, trackLayout);

  @override
  String toString() => 'TrackKey($trackName — $trackLayout)';
}

/// A lap's Ground Speed against its own `Lap Dist`.
class SpeedProfile {
  /// Parallel arrays, in the order the lap drove them.
  SpeedProfile(this.times, this.distances, this.speeds)
    : assert(
        times.length == distances.length && distances.length == speeds.length,
        'columns must be parallel',
      );

  /// [speed] placed on [axis]: each sample at the distance the lap had
  /// reached at that instant, interpolated between the `Lap Dist` samples
  /// either side — the two channels share one master clock, so this is a
  /// resample, not an alignment. Samples before the first `Lap Dist` sample
  /// or after the last have no distance and are left out.
  ///
  /// The low of each bucket, so a decimated read — laps over 60 s — still
  /// holds every corner's true minimum; at full resolution low and high are
  /// the same sample.
  factory SpeedProfile.of({
    required TraceSeries speed,
    required DistanceAxis axis,
  }) {
    final times = <double>[];
    final distances = <double>[];
    final speeds = <double>[];
    if (axis.times.isNotEmpty) {
      final from = axis.times.first;
      final to = axis.times.last;
      for (var i = 0; i < speed.length; i++) {
        final t = speed.times[i];
        if (t < from || t > to) continue;
        times.add(t);
        distances.add(axis.distanceAt(t));
        speeds.add(speed.lows[i]);
      }
    }
    return SpeedProfile(
      Float64List.fromList(times),
      Float64List.fromList(distances),
      Float64List.fromList(speeds),
    );
  }

  /// Session seconds of each sample.
  final Float64List times;

  /// `Lap Dist` at each sample, in metres.
  final Float64List distances;

  /// Ground Speed at each sample, in km/h.
  final Float64List speeds;

  int get length => speeds.length;
}

/// A local minimum of a lap's speed.
class SpeedMinimum {
  const SpeedMinimum({
    required this.station,
    required this.speed,
    required this.prominence,
  });

  /// `Lap Dist` of the minimum, in metres.
  final double station;

  /// km/h at the minimum.
  final double speed;

  /// How far the speed rises, at least, before any slower point either way
  /// round the lap: the lower of the two highest speeds between this
  /// minimum and the nearest slower sample on each side, less this one. The
  /// slowest point of the lap has no slower sample and measures to the lap's
  /// top speed.
  final double prominence;

  @override
  String toString() =>
      'SpeedMinimum(${station.toStringAsFixed(0)} m, '
      '${speed.toStringAsFixed(1)} km/h, '
      'prominence ${prominence.toStringAsFixed(1)})';
}

/// [profile]'s speed minima whose prominence is at least [minProminence],
/// in track order.
///
/// The lap is treated as a loop: the stretch before the line joins the
/// stretch after it, so a corner near the line is measured against the
/// speeds on both sides of it rather than against a cliff at the edge of the
/// array. A minimum is a sample strictly below the one before it and not
/// above the one after — scipy's rule, which counts a flat-bottomed minimum
/// once, at its first sample. This is the definition probe 0c measured on
/// 85 recordings of 11 layouts.
List<SpeedMinimum> speedMinima(
  SpeedProfile profile, {
  double minProminence = 0,
}) {
  final v = profile.speeds;
  final n = v.length;
  if (n < 3) return const [];
  var top = v[0];
  for (final x in v) {
    if (x > top) top = x;
  }
  final out = <SpeedMinimum>[];
  for (var i = 0; i < n; i++) {
    final here = v[i];
    if (!(here < v[(i - 1 + n) % n] && here <= v[(i + 1) % n])) continue;
    final prominence =
        math.min(_riseBefore(v, i, -1, top), _riseBefore(v, i, 1, top)) - here;
    if (prominence < minProminence) continue;
    out.add(
      SpeedMinimum(
        station: profile.distances[i],
        speed: here,
        prominence: prominence,
      ),
    );
  }
  out.sort((a, b) => a.station.compareTo(b.station));
  return out;
}

/// The highest speed met walking from sample [i] in [direction] (−1 or +1),
/// round the lap, before reaching a sample slower than it; [top] when there
/// is none.
double _riseBefore(Float64List v, int i, int direction, double top) {
  final n = v.length;
  final here = v[i];
  var high = here;
  for (var k = 1; k < n; k++) {
    final x = v[((i + direction * k) % n + n) % n];
    if (x < here) return high;
    if (x > high) high = x;
  }
  return top;
}

/// The prominence a speed minimum needs to count as a corner.
///
/// 20 km/h by default: no threshold reproduces the canonical lap's corner set
/// on every layout of the library, and 20 is where mean table stability peaks
/// (75.5%, against 63.5% at 15). The overrides are the layouts where another
/// value measured better on at least six candidate laps (probe 0c). Layouts
/// with 0–5 timed laps in the library — Fuji, Monza, Road Atlanta, Long
/// Beach, Paul Ricard — use the default, unvalidated (§11, 0m).
double cornerThresholdFor(TrackKey key) =>
    _thresholdOverrides['${key.trackName}\n${key.trackLayout}'] ??
    SegmentDetector.defaultThreshold;

/// Keyed `TrackName\nTrackLayout`: a const map needs keys with primitive
/// equality.
const _thresholdOverrides = <String, double>{
  'Autódromo José Carlos Pace\nAutódromo José Carlos Pace': 15,
  'Autodromo Enzo e Dino Ferrari\nAutodromo Enzo e Dino Ferrari': 15,
  'Circuit de Barcelona\nCircuit de Barcelona': 15,
  'Circuit of the Americas\nCircuit of the Americas': 30,
};

/// A corner of the segment table.
class TrackCorner {
  const TrackCorner({
    required this.station,
    required this.speed,
    required this.prominence,
    this.unstable = false,
  });

  /// The canonical lap's apex: its speed minimum, in `Lap Dist` metres.
  final double station;

  /// The canonical lap's speed there, in km/h.
  final double speed;

  /// The minimum's prominence on the canonical lap, in km/h.
  final double prominence;

  /// Whether other clean laps disagree about this corner often enough that
  /// the table could as well have been cut without it (or, for a minimum
  /// the canonical lap dropped, with it) — see [CornerStability].
  final bool unstable;

  TrackCorner withUnstable(bool value) => TrackCorner(
    station: station,
    speed: speed,
    prominence: prominence,
    unstable: value,
  );
}

/// Corners and boundaries found on one lap.
class DetectedSegments {
  const DetectedSegments({
    required this.corners,
    required this.boundaries,
    required this.minima,
  });

  /// The minima that cleared the threshold, in track order.
  final List<TrackCorner> corners;

  /// Where one segment hands over to the next, in track order.
  final List<double> boundaries;

  /// Every minimum of at least [SegmentDetector.candidateProminence], kept
  /// for the stability check.
  final List<SpeedMinimum> minima;
}

/// Finds corners and boundaries on a canonical lap.
class SegmentDetector {
  const SegmentDetector({this.threshold = defaultThreshold});

  static const defaultThreshold = 20.0;

  /// Bumped whenever detection changes what it finds, so a stored table
  /// knows it came from an older rule.
  static const version = 1;

  /// Minima under this are noise on every lap measured, and never matter
  /// to a corner's stability.
  static const candidateProminence = 2.0;

  final double threshold;

  DetectedSegments detect(SpeedProfile canonical) {
    final minima = speedMinima(canonical, minProminence: candidateProminence);
    final corners = [
      for (final m in minima)
        if (m.prominence >= threshold)
          TrackCorner(
            station: m.station,
            speed: m.speed,
            prominence: m.prominence,
          ),
    ];
    return DetectedSegments(
      corners: corners,
      boundaries: topSpeedBoundaries(canonical, [
        for (final c in corners) c.station,
      ]),
      minima: minima,
    );
  }
}

/// [profile]'s top speed between each pair of consecutive [apexes], plus one
/// between the line and the first apex.
///
/// That last boundary, the one between the last corner and the first, is
/// searched only **after the line**. Daytona's top-speed plateau (about
/// 323 km/h) crosses the line; searched across it, the boundary fell before
/// the line on 30 of 175 laps, and re-picking the canonical lap moved
/// per-segment losses by p95 0.54 s (max 1.32 s). After the line: p95
/// 0.15 s, max 0.38 s; Sebring, Le Mans and Interlagos are unchanged by it.
List<double> topSpeedBoundaries(SpeedProfile profile, List<double> apexes) {
  if (apexes.isEmpty) return const [];
  final sorted = [...apexes]..sort();
  double? fastestBetween(double from, double to) {
    var best = double.negativeInfinity;
    double? at;
    for (var i = 0; i < profile.length; i++) {
      final d = profile.distances[i];
      if (d > from && d < to && profile.speeds[i] > best) {
        best = profile.speeds[i];
        at = d;
      }
    }
    return at;
  }

  return [
    ?fastestBetween(0, sorted.first),
    for (var k = 0; k + 1 < sorted.length; k++)
      ?fastestBetween(sorted[k], sorted[k + 1]),
  ];
}

/// Which lap a table was cut from — named in the navigator's caption, since
/// a segment's size depends on it (§5: the worst segment survives the choice
/// of canonical lap in 76–93% of library pairs).
class CanonicalLap {
  const CanonicalLap({
    required this.recording,
    required this.sessionType,
    required this.lapIndex,
    required this.lapNumber,
  });

  final RecordingIdentity recording;

  /// "Race", "Practice": the file's `SessionType`.
  final String sessionType;

  final int lapIndex;

  /// What the user calls it: `Lap.displayNumber`.
  final int lapNumber;
}

/// One stretch of the lap between two boundaries.
class Segment {
  const Segment({
    required this.number,
    required this.start,
    required this.end,
    this.label,
  });

  /// 1..n in track order. Never a turn number: the game's layout measures
  /// 3083 m against 3219 m in the real world, and no detector stably finds
  /// the official turns (§5 Numbering).
  final int number;

  /// `Lap Dist` metres where it starts and ends.
  final double start;
  final double end;

  /// What to call it; "Seg n" unless given ("S1" in Sectors mode).
  final String? label;

  String get name => label ?? 'Seg $number';

  double get length => end - start;

  bool contains(double station) => station >= start && station < end;

  @override
  bool operator ==(Object other) =>
      other is Segment &&
      other.number == number &&
      other.start == start &&
      other.end == end &&
      other.label == label;

  @override
  int get hashCode => Object.hash(number, start, end, label);

  @override
  String toString() =>
      '$name ${start.toStringAsFixed(0)}–${end.toStringAsFixed(0)} m';
}

/// One course's segments, as plain numbers (§5 "What a segment table is").
class SegmentTable {
  const SegmentTable({
    required this.key,
    required this.wrapLength,
    required this.boundaries,
    required this.corners,
    required this.canonical,
    required this.threshold,
    this.unstableDropped = const [],
    this.detectorVersion = SegmentDetector.version,
  });

  final TrackKey key;

  /// The course's lap length, from the canonical file's `Lap Dist` wraps
  /// (§4): the table's fingerprint. A file of the same key whose length
  /// differs by more than [fingerprintTolerance] gets its own detection.
  final double wrapLength;

  /// Interior boundaries, in track order.
  final List<double> boundaries;

  final List<TrackCorner> corners;

  /// Minima the canonical lap dropped (under the threshold) that other clean
  /// laps put over it often enough to matter.
  final List<SpeedMinimum> unstableDropped;

  final CanonicalLap canonical;

  /// The prominence a corner needed, in km/h.
  final double threshold;

  final int detectorVersion;

  /// A lap length off by more than this is another course, or a changed one
  /// (§5 "Frozen": a fingerprint from a lap's last `Lap Dist` sample would
  /// need 12 m; the wraps' median needs half a metre).
  static const fingerprintTolerance = 0.5;

  bool fits(double otherWrapLength) =>
      (otherWrapLength - wrapLength).abs() <= fingerprintTolerance;

  /// The segments, numbered in track order: from the line to the first
  /// boundary, between boundaries, and from the last boundary to the line.
  List<Segment> get segments {
    final edges = [
      0.0,
      for (final b in boundaries)
        if (b > 0 && b < wrapLength) b,
      wrapLength,
    ];
    return [
      for (var k = 0; k + 1 < edges.length; k++)
        Segment(number: k + 1, start: edges[k], end: edges[k + 1]),
    ];
  }

  /// Whether [segment] holds an unstable corner: one the table kept, or one
  /// it dropped (§5: noted on its neighbouring boundary).
  bool unstableIn(Segment segment) =>
      corners.any((c) => c.unstable && segment.contains(c.station)) ||
      unstableDropped.any((m) => segment.contains(m.station));
}

/// Why a lap cannot be the canonical lap (§5 "Canonical lap").
enum UncleanReason {
  untimed('it has no lap time'),
  recordingStart("it is the recording's first lap"),
  noDistance('it recorded no usable lap distance'),
  distanceBackwards('its lap distance runs backwards'),
  distanceJumps('its lap distance jumps forward (off track?)'),
  impact('it recorded contact'),
  pitLane('it spent time in the pit lane'),
  stall('the car stopped for 1 s or more');

  const UncleanReason(this.description);

  final String description;
}

/// A lap distance step faster than this is not driving: an off-track
/// excursion, or the garage teleport (§5: "a Lap Dist step over 20 m in
/// 0.1 s" caught 9 of 2,459 otherwise clean laps, all with |Path Lateral|
/// over 14 m).
const maxDistanceRate = 200.0;

/// Ground Speed under this for [stallSeconds] or more is a stall.
const stallSpeed = 10.0;
const stallSeconds = 1.0;

/// Why [lap] is not clean, or null when it is.
///
/// Clean means timed, not the recording's first lap, `Lap Dist` monotonic
/// with no forward jump, no impact row, no pit-lane time, and no stall. Each
/// rule removes a lap whose speed minima would put a corner where there is
/// none: two stall laps in the library pass every other rule and would each
/// add a fake corner (Sebring P 2026-07-07T03_21_49Z, Lap value 5, at 911 m).
UncleanReason? whyNotClean({
  required Lap lap,
  required bool recordingStart,
  required bool impact,
  required bool pitLane,
  required DistanceAxis? axis,
  required SpeedProfile? speed,
}) =>
    whyNotCleanBeforeReading(
      lap: lap,
      recordingStart: recordingStart,
      impact: impact,
      pitLane: pitLane,
    ) ??
    _telemetryReason(axis, speed);

/// The rules [whyNotClean] can apply from the lap list and the file's
/// events alone, so a lap they rule out costs no telemetry read.
UncleanReason? whyNotCleanBeforeReading({
  required Lap lap,
  required bool recordingStart,
  required bool impact,
  required bool pitLane,
}) {
  if (lap.lapTimeSeconds == null || lap.isOpenEnded) {
    return UncleanReason.untimed;
  }
  if (recordingStart) return UncleanReason.recordingStart;
  if (impact) return UncleanReason.impact;
  if (pitLane) return UncleanReason.pitLane;
  return null;
}

UncleanReason? _telemetryReason(DistanceAxis? axis, SpeedProfile? speed) {
  if (axis == null || axis.times.length < 2 || speed == null) {
    return UncleanReason.noDistance;
  }
  if (!axis.isMonotonic) return UncleanReason.distanceBackwards;
  for (var i = 1; i < axis.times.length; i++) {
    final dt = axis.times[i] - axis.times[i - 1];
    final step = axis.distances[i] - axis.distances[i - 1];
    if (dt > 0 && step / dt > maxDistanceRate) {
      return UncleanReason.distanceJumps;
    }
  }
  if (stalled(speed)) return UncleanReason.stall;
  return null;
}

/// Whether [speed] stays under [stallSpeed] for [stallSeconds] or more.
bool stalled(SpeedProfile speed) {
  double? slowSince;
  for (var i = 0; i < speed.length; i++) {
    if (speed.speeds[i] < stallSpeed) {
      slowSince ??= speed.times[i];
      if (speed.times[i] - slowSince >= stallSeconds) return true;
    } else {
      slowSince = null;
    }
  }
  return false;
}

/// Which corners other clean laps disagree about (§5 "Unstable corners").
///
/// Each other lap's minima are matched one-to-one to the canonical lap's,
/// nearest first and never further than [matchDistance] apart round the lap,
/// so the hairpin's two apexes 58 m apart match their own counterparts
/// rather than both claiming the deeper one. A kept corner whose match is
/// under the threshold — or missing — on [unstableShare] of the laps or more
/// is unstable; so is a dropped minimum whose match clears it that often.
class CornerStability {
  CornerStability._(this.corners, this.dropped);

  factory CornerStability.measure({
    required DetectedSegments canonical,
    required List<List<SpeedMinimum>> others,
    required double threshold,
    required double wrapLength,
  }) {
    if (others.isEmpty) {
      return CornerStability._(canonical.corners, const []);
    }
    final minima = canonical.minima;
    final over = List<int>.filled(minima.length, 0);
    for (final lap in others) {
      final matched = matchMinima(minima, lap, wrapLength);
      for (var i = 0; i < minima.length; i++) {
        final m = matched[i];
        if (m != null && m.prominence >= threshold) over[i]++;
      }
    }
    final n = others.length;
    bool kept(SpeedMinimum m) => m.prominence >= threshold;
    final unstable = <double>{};
    final dropped = <SpeedMinimum>[];
    for (var i = 0; i < minima.length; i++) {
      final m = minima[i];
      if (kept(m)) {
        if ((n - over[i]) / n >= unstableShare) unstable.add(m.station);
      } else if (m.prominence >= droppedFloor && over[i] / n >= unstableShare) {
        dropped.add(m);
      }
    }
    return CornerStability._([
      for (final c in canonical.corners)
        c.withUnstable(unstable.contains(c.station)),
    ], dropped);
  }

  /// The canonical lap's corners, flagged.
  final List<TrackCorner> corners;

  /// Dropped minima that other laps keep.
  final List<SpeedMinimum> dropped;

  /// Two minima further apart than this, round the lap, are not one corner.
  static const matchDistance = 80.0;

  /// The share of other laps disagreeing that makes a corner unstable.
  static const unstableShare = 0.25;

  /// A dropped minimum shallower than this is noise, not a candidate corner.
  static const droppedFloor = 5.0;
}

/// [lap]'s minimum matched to each of [canonical]'s, or null where none is
/// within [CornerStability.matchDistance]. Greedy, nearest pair first.
List<SpeedMinimum?> matchMinima(
  List<SpeedMinimum> canonical,
  List<SpeedMinimum> lap,
  double wrapLength,
) {
  double apart(double a, double b) {
    final x = (a - b).abs() % wrapLength;
    return math.min(x, wrapLength - x);
  }

  final pairs = <(int, int, double)>[
    for (var i = 0; i < canonical.length; i++)
      for (var j = 0; j < lap.length; j++)
        if (apart(canonical[i].station, lap[j].station) case final d
            when d <= CornerStability.matchDistance)
          (i, j, d),
  ]..sort((a, b) => a.$3.compareTo(b.$3));
  final out = List<SpeedMinimum?>.filled(canonical.length, null);
  final taken = <int>{};
  for (final (i, j, _) in pairs) {
    if (out[i] != null || taken.contains(j)) continue;
    out[i] = lap[j];
    taken.add(j);
  }
  return out;
}
