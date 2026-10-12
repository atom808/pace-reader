/// What a recording says about the course it was driven on (comparison
/// proposal §4): how long a lap of it is, where its sector lines sit, and
/// when the car was in the pit lane.
///
/// Read once per file, from the whole recording, because every one of these
/// is a property of the file rather than of a lap: one lap's own sector
/// crossing lands anywhere in a ±0.65 m band (the 0.02 s event grid times
/// the car's speed), while the median over a file's crossings is the same to
/// within 2.1 m in every recording of a layout across the user's library
/// (678 recordings, 17 layouts, probe 0a).
library;

/// One stay in the pit lane, from `In Pits` going true to it going false.
class PitInterval {
  const PitInterval(this.startSeconds, [this.endSeconds]);

  final double startSeconds;

  /// Null when the recording ends in the pit lane.
  final double? endSeconds;

  bool overlaps(double start, double end) =>
      startSeconds < end && (endSeconds == null || endSeconds! > start);

  @override
  bool operator ==(Object other) =>
      other is PitInterval &&
      other.startSeconds == startSeconds &&
      other.endSeconds == endSeconds;

  @override
  int get hashCode => Object.hash(startSeconds, endSeconds);

  @override
  String toString() => 'PitInterval($startSeconds, $endSeconds)';
}

/// One crossing of a sector line, as the reader found it: the sector the car
/// entered, when, and the `Lap Dist` interpolated at that moment.
typedef SectorCrossing = ({int sector, double seconds, double station});

class CourseFacts {
  const CourseFacts({
    this.wrapLength,
    this.wrapCount = 0,
    this.sector1Station,
    this.sector2Station,
    this.pitLane = const [],
  });

  /// Nothing known: a file without the channels these come from, or one that
  /// could not be read. Every check that needs a fact it lacks says so
  /// rather than passing.
  static const unknown = CourseFacts();

  /// Builds the facts from the reader's raw rows.
  ///
  /// [crossings] are every sector-line crossing the file recorded. Those
  /// made inside the pit lane are dropped — the pit lane bypasses the timing
  /// line on Sebring School, and the line the car crosses there is not the
  /// one the circuit's laps are timed at — and so is any crossing more than
  /// [stationOutlier] from the file's median, which is how the garage
  /// teleport at the start of a recording (`Lap Dist` jumping 0 → 2044 m in
  /// one 0.1 s sample) stays out of the median it would otherwise drag.
  factory CourseFacts.fromReads({
    required double? wrapLength,
    required int wrapCount,
    required List<SectorCrossing> crossings,
    required List<(double, bool)> inPits,
  }) {
    final pitLane = pitIntervalsFrom(inPits);
    bool onTrack(SectorCrossing c) =>
        !pitLane.any((p) => p.overlaps(c.seconds, c.seconds + 1e-9));
    double? station(int sector) => robustStation([
      for (final c in crossings)
        if (c.sector == sector && onTrack(c)) c.station,
    ]);
    return CourseFacts(
      wrapLength: wrapLength,
      wrapCount: wrapCount,
      // Entering sector 2 is crossing the S1 line; entering sector 3, the S2
      // line (`Current Sector` cycles 1 → 2 → 0, and 0 is sector 3).
      sector1Station: station(2),
      sector2Station: station(3),
      pitLane: pitLane,
    );
  }

  /// The length of one lap of the course: the file's median, over its
  /// `Lap Dist` wraps, of `Lap Dist` before the wrap plus the `Total Dist`
  /// covered across it minus `Lap Dist` after. A per-course constant — the
  /// same to 0.04 m in every recording of a layout — where a lap's last
  /// `Lap Dist` sample sits anywhere from 1.1 to 11.5 m short of it. Null
  /// when the file recorded no wrap (a recording shorter than a lap).
  final double? wrapLength;

  /// How many wraps [wrapLength] is the median of.
  final int wrapCount;

  /// The S1 and S2 timing lines, in `Lap Dist` metres: the file's median
  /// over its on-track crossings.
  final double? sector1Station;
  final double? sector2Station;

  /// Every stay in the pit lane, in order.
  final List<PitInterval> pitLane;

  /// How far before the `Lap Dist` wrap the game's timing line sits. Measured
  /// from the lap-start crossings of every layout in the library: −1.62 to
  /// −2.06 m (Sebring −1.75), so one constant serves them all to ±0.3 m —
  /// about 5 ms at the line, inside the 15 ms a lap's check allows.
  static const timingLineBeforeWrap = 1.8;

  /// A crossing further than this from the file's median is not a crossing
  /// of that line (§4: "crossings over 5 m from the file median dropped").
  static const stationOutlier = 5.0;

  /// Where the timing line sits in `Lap Dist`, or null without a length.
  double? get timingLineStation =>
      wrapLength == null ? null : wrapLength! - timingLineBeforeWrap;

  /// Whether the car spent any of [start]–[end] in the pit lane.
  bool pitLaneDuring(double start, double end) =>
      pitLane.any((p) => p.overlaps(start, end));

  @override
  bool operator ==(Object other) =>
      other is CourseFacts &&
      other.wrapLength == wrapLength &&
      other.wrapCount == wrapCount &&
      other.sector1Station == sector1Station &&
      other.sector2Station == sector2Station &&
      _sameList(other.pitLane, pitLane);

  @override
  int get hashCode => Object.hash(
    wrapLength,
    wrapCount,
    sector1Station,
    sector2Station,
    Object.hashAll(pitLane),
  );

  @override
  String toString() =>
      'CourseFacts(L $wrapLength from $wrapCount, S1 $sector1Station, '
      'S2 $sector2Station, ${pitLane.length} pit stays)';
}

/// The median of [stations] after dropping every value more than
/// [CourseFacts.stationOutlier] from a first median — or null when nothing
/// is left to take one of.
double? robustStation(List<double> stations) {
  final first = median(stations);
  if (first == null) return null;
  return median([
    for (final s in stations)
      if ((s - first).abs() <= CourseFacts.stationOutlier) s,
  ]);
}

/// The median of [values], the mean of the middle two for an even count.
double? median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Pit-lane stays from `In Pits` rows, `(seconds, in pits)` in time order.
///
/// The table is written on change, but a repeated value is tolerated: a stay
/// runs from the first true to the next false.
List<PitInterval> pitIntervalsFrom(List<(double, bool)> rows) {
  final out = <PitInterval>[];
  double? enteredAt;
  for (final (seconds, inPits) in rows) {
    if (inPits) {
      enteredAt ??= seconds;
    } else if (enteredAt != null) {
      out.add(PitInterval(enteredAt, seconds));
      enteredAt = null;
    }
  }
  if (enteredAt != null) out.add(PitInterval(enteredAt));
  return out;
}

/// How far two files' sector lines sit apart in `Lap Dist` (comparison
/// proposal §4, "Distance alignment").
///
/// Measured on the library, a file's median station differs from another
/// file's of the same layout by at most 2.10 m. So up to [alignedWithin] is
/// the same coordinate; up to [usableWithin] (never observed) the delta is
/// still drawn, with a warning that corner deltas may shift; beyond that,
/// everything compared at equal distance is withheld.
class StationAlignment {
  const StationAlignment._({
    required this.sameFile,
    this.sector1Offset,
    this.sector2Offset,
  });

  /// Two laps of one file share one `Lap Dist`, so there is nothing to
  /// measure.
  static const sharedFile = StationAlignment._(sameFile: true);

  /// [target]'s stations against [base]'s.
  factory StationAlignment.between(CourseFacts base, CourseFacts target) {
    double? offset(double? b, double? t) =>
        b == null || t == null ? null : t - b;
    return StationAlignment._(
      sameFile: false,
      sector1Offset: offset(base.sector1Station, target.sector1Station),
      sector2Offset: offset(base.sector2Station, target.sector2Station),
    );
  }

  static const alignedWithin = 2.5;
  static const usableWithin = 5.0;

  final bool sameFile;

  /// The Target's station minus Base's, in metres; null where either file
  /// has no crossing of that line.
  final double? sector1Offset;
  final double? sector2Offset;

  /// The larger of the two offsets, by size, or null when neither could be
  /// measured.
  double? get worstOffset {
    final known = [?sector1Offset, ?sector2Offset];
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a.abs() >= b.abs() ? a : b);
  }

  /// Measured, and within what the library shows for one course.
  bool get aligned =>
      sameFile || (worstOffset != null && worstOffset!.abs() <= alignedWithin);

  /// Too far apart for a comparison at equal distance to mean anything.
  bool get withholdsDistance =>
      !sameFile && worstOffset != null && worstOffset!.abs() > usableWithin;

  /// Nothing to measure it with: two files, but no station in one of them.
  bool get unchecked => !sameFile && worstOffset == null;
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
