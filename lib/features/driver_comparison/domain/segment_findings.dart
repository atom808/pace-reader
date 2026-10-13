/// What the Why card states about each corner, Base against the Target
/// (comparison proposal §2, §5 "Findings and segments", §9
/// `segment_findings.dart`).
///
/// Every finding here carries the floor it was measured against on the
/// library (probes 0d and 0e: 558k pair-corners, native rate) and says
/// whether it clears it. One that does not is still reported, with its
/// reason, so the card can say *why* it is silent rather than look empty.
/// Nothing here is advice: "Target brakes 23 m later", never "brake later".
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import 'comparison_set.dart';
import 'segments.dart';

/// The pedal levels a brake onset is found at. It is stated only when all
/// three agree on its sign: 98.9% sign-stable over 558k pair-corners, where
/// the plain first crossing fell to 92.7% because of light pre-brakes.
const brakeOnsetThresholds = [2.0, 5.0, 10.0];

/// The level a corner's braking zone is found at, and the peak it needs to
/// count as braking for the corner rather than a dab (%).
const brakeZoneThreshold = 5.0;
const brakeZoneMinPeak = 15.0;

/// Pedal released for less than this inside a zone does not end it.
const brakeZoneGapSeconds = 1.0;

/// Brake onsets closer than this are not called (m): about one driver's own
/// median lap-to-lap variation (4.9 m), so a brake line is stated for about
/// half of pair-corners.
const brakeOnsetFloor = 5.0;

/// The slowest sample interval a brake onset is found on. The pedal is
/// recorded at 50 Hz; at 5 Hz an onset is off by up to 8 m, with sign flips
/// (§12 "Brake points from 5 Hz data").
const brakeMaxIntervalSeconds = 1 / 40;

/// Speeds are stated from this difference (km/h; sign-stable 98.9% for the
/// slowest point, 98.2% for the brake-on speed).
const speedFloor = 1.0;

/// The corner's window either side of the canonical apex, wide enough to
/// hold both apexes of a double apex. At ± 40 m, 3.2% of lap-corners hit the
/// window's edge.
const apexWindow = 60.0;

/// Two slowest points are on different apexes only when each lap has a hump
/// this high between them (km/h): 0.3–0.5% of pairs, mostly chicanes.
const apexHump = 2.0;

/// A downshift belongs to the corner whose window, from the previous apex to
/// this one, both moved on by this much, holds it (m).
const downshiftLead = 30.0;

/// Downshift stations closer than this are not called (m): consecutive laps
/// of one driver differ by p50 5.2 m.
const downshiftFloor = 5.0;

/// A channel placed on the lap: each sample's time, value and `Lap Dist`.
class PlacedSeries {
  PlacedSeries._(this.times, this.values, this.stations);

  /// [series]'s samples (their lows: at full resolution, the sample itself;
  /// decimated, the bucket's minimum) placed by [axis].
  factory PlacedSeries.of(TraceSeries series, DistanceAxis axis) {
    final n = series.length;
    final stations = Float64List(n);
    for (var i = 0; i < n; i++) {
      stations[i] = axis.distanceAt(series.times[i]);
    }
    return PlacedSeries._(series.times, series.lows, stations);
  }

  final Float64List times;
  final Float64List values;
  final Float64List stations;

  int get length => times.length;

  /// The median interval between samples, in seconds.
  double get medianInterval {
    if (length < 2) return double.infinity;
    final gaps = Float64List(length - 1);
    for (var i = 1; i < length; i++) {
      gaps[i - 1] = times[i] - times[i - 1];
    }
    gaps.sort();
    return gaps[gaps.length ~/ 2];
  }

  /// The value at [station], interpolated between the samples either side of
  /// its first reach; null off the lap's samples.
  double? valueAtStation(double station) {
    if (length == 0 || station < stations.first || station > stations.last) {
      return null;
    }
    final i = _firstAtOrAfter(stations, station);
    if (i == 0 || stations[i] == station) return values[i];
    final a = stations[i - 1];
    final b = stations[i];
    final f = b > a ? (station - a) / (b - a) : 0.0;
    return values[i - 1] + f * (values[i] - values[i - 1]);
  }

  /// The value at [seconds], interpolated in time; null off the samples.
  double? valueAt(double seconds) {
    if (length == 0 || seconds < times.first || seconds > times.last) {
      return null;
    }
    final i = _firstAtOrAfter(times, seconds);
    if (i == 0 || times[i] == seconds) return values[i];
    final a = times[i - 1];
    final b = times[i];
    final f = b > a ? (seconds - a) / (b - a) : 0.0;
    return values[i - 1] + f * (values[i] - values[i - 1]);
  }
}

int _firstAtOrAfter(Float64List xs, double x) {
  var low = 0;
  var high = xs.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (xs[mid] < x) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return math.min(low, xs.length - 1);
}

/// One lap as the findings read it.
class FindingLap {
  FindingLap({
    required this.axis,
    this.brake,
    this.speed,
    this.gear,
    this.impactSeconds = const [],
  });

  /// [axis] places every sample; [brake] is `Brake Pos` and [speed] Ground
  /// Speed, each at the recording's own rate.
  factory FindingLap.of({
    required DistanceAxis axis,
    TraceSeries? brake,
    TraceSeries? speed,
    StepSeries? gear,
    List<double> impactSeconds = const [],
  }) => FindingLap(
    axis: axis,
    brake: brake == null || brake.length < 2
        ? null
        : PlacedSeries.of(brake, axis),
    speed: speed == null || speed.length < 2
        ? null
        : PlacedSeries.of(speed, axis),
    gear: gear,
    impactSeconds: impactSeconds,
  );

  final DistanceAxis axis;
  final PlacedSeries? brake;
  final PlacedSeries? speed;
  final StepSeries? gear;
  final List<double> impactSeconds;

  /// Whether the pedal arrives at a rate an onset can be found on.
  bool get brakeAtRate =>
      brake != null && brake!.medianInterval <= brakeMaxIntervalSeconds;
}

/// Where one lap's main braking ramp for a corner begins.
class BrakeOnset {
  const BrakeOnset({
    required this.stations,
    required this.seconds,
    required this.peak,
  });

  /// The onset's `Lap Dist` at each of [brakeOnsetThresholds].
  final Map<double, double> stations;

  /// When it crossed [brakeZoneThreshold].
  final double seconds;

  /// The zone's highest pedal (%).
  final double peak;

  /// At [brakeZoneThreshold]: the station the card quotes.
  double get station => stations[brakeZoneThreshold]!;
}

/// [lap]'s main braking ramp for the corner whose zone starts in (from, to].
///
/// The zone is the stretch of pedal over [brakeZoneThreshold], with releases
/// under [brakeZoneGapSeconds] bridged; of the zones that start in the
/// window, the one with the highest peak, if it reaches [brakeZoneMinPeak].
/// The onset is the main ramp's, not the first touch: the last upward
/// crossing of each threshold before the pedal first reaches half the zone's
/// peak, at sub-sample `Lap Dist`. A light pre-brake therefore does not move
/// it.
BrakeOnset? mainRampOnset(
  PlacedSeries brake, {
  required double from,
  required double to,
}) {
  final b = brake.values;
  final t = brake.times;
  final s = brake.stations;
  final n = brake.length;
  if (n < 2) return null;

  // Zones over the threshold; one that starts within a gap of the lap's
  // first sample may be the previous corner's, and is never chosen.
  final zones = <(int, int, double, bool)>[];
  int? lastAbove;
  for (var k = 0; k < n; k++) {
    if (b[k] <= brakeZoneThreshold) continue;
    if (lastAbove != null &&
        t[k] - t[lastAbove] < brakeZoneGapSeconds &&
        zones.isNotEmpty) {
      final (i0, _, peak, valid) = zones.last;
      zones[zones.length - 1] = (
        i0,
        k,
        valid ? math.max(peak, b[k]) : peak,
        valid,
      );
    } else {
      final valid = lastAbove != null || t[k] - t[0] >= brakeZoneGapSeconds;
      zones.add((k, k, valid ? b[k] : -1, valid));
    }
    lastAbove = k;
  }
  (int, int, double, bool)? main;
  for (final zone in zones) {
    final (i0, _, peak, valid) = zone;
    if (!valid || s[i0] <= from || s[i0] > to) continue;
    if (main == null || peak > main.$3) main = zone;
  }
  if (main == null || main.$3 < brakeZoneMinPeak) return null;
  final (i0, i1, peak, _) = main;

  var half = i0;
  while (half < i1 && b[half] < 0.5 * peak) {
    half++;
  }
  final stations = <double, double>{};
  double? seconds;
  for (final threshold in brakeOnsetThresholds) {
    var k = half;
    while (k > 0 && b[k - 1] > threshold) {
      k--;
    }
    if (k == 0) return null;
    final rise = b[k] - b[k - 1];
    final f = rise > 0 ? ((threshold - b[k - 1]) / rise).clamp(0.0, 1.0) : 0.0;
    stations[threshold] = s[k - 1] + f * (s[k] - s[k - 1]);
    if (threshold == brakeZoneThreshold) {
      seconds = t[k - 1] + f * (t[k] - t[k - 1]);
    }
  }
  return BrakeOnset(stations: stations, seconds: seconds!, peak: peak);
}

/// Why a finding is not stated.
enum Withheld {
  dataRate('data rate'),
  noBraking('no braking zone'),
  belowFloor('within the floor'),
  thresholdsDisagree('the thresholds disagree'),
  notFound('not found in window'),
  noData('not recorded');

  const Withheld(this.label);

  final String label;
}

/// The two laps' brake points for one corner.
class BrakeFinding {
  const BrakeFinding({
    this.base,
    this.target,
    this.baseSpeed,
    this.targetSpeed,
    this.withheld,
    this.withheldFor,
  });

  final BrakeOnset? base;
  final BrakeOnset? target;

  /// Each lap's speed at its own onset (km/h).
  final double? baseSpeed;
  final double? targetSpeed;

  /// Why it is not stated; null when it is.
  final Withheld? withheld;

  /// The lap [withheld] is about, where it is about one.
  final ComparisonRole? withheldFor;

  bool get stated => withheld == null;

  /// Base's onset less the Target's at [threshold]: negative when the
  /// Target brakes later.
  double? differenceAt(double threshold) => base == null || target == null
      ? null
      : base!.stations[threshold]! - target!.stations[threshold]!;

  /// At [brakeZoneThreshold].
  double? get difference => differenceAt(brakeZoneThreshold);

  /// Whether the brake-on speeds differ by [speedFloor] or more.
  bool get speedStated =>
      baseSpeed != null &&
      targetSpeed != null &&
      (baseSpeed! - targetSpeed!).abs() >= speedFloor;

  static BrakeFinding measure(
    FindingLap base,
    FindingLap target, {
    required double from,
    required double to,
  }) {
    for (final (role, lap) in [
      (ComparisonRole.base, base),
      (ComparisonRole.target, target),
    ]) {
      if (lap.brake == null) {
        return BrakeFinding(withheld: Withheld.noData, withheldFor: role);
      }
      if (!lap.brakeAtRate) {
        return BrakeFinding(withheld: Withheld.dataRate, withheldFor: role);
      }
    }
    final b = mainRampOnset(base.brake!, from: from, to: to);
    final t = mainRampOnset(target.brake!, from: from, to: to);
    double? speedAt(FindingLap lap, BrakeOnset? onset) =>
        onset == null ? null : lap.speed?.valueAt(onset.seconds);
    final bSpeed = speedAt(base, b);
    final tSpeed = speedAt(target, t);
    if (b == null || t == null) {
      return BrakeFinding(
        base: b,
        target: t,
        baseSpeed: bSpeed,
        targetSpeed: tSpeed,
        withheld: Withheld.noBraking,
        withheldFor: b == null && t == null
            ? null
            : b == null
            ? ComparisonRole.base
            : ComparisonRole.target,
      );
    }
    final signs = {
      for (final threshold in brakeOnsetThresholds)
        (b.stations[threshold]! - t.stations[threshold]!).sign,
    };
    final difference = b.station - t.station;
    return BrakeFinding(
      base: b,
      target: t,
      baseSpeed: bSpeed,
      targetSpeed: tSpeed,
      withheld: signs.length != 1 || signs.single == 0
          ? Withheld.thresholdsDisagree
          : difference.abs() < brakeOnsetFloor
          ? Withheld.belowFloor
          : null,
    );
  }
}

/// One lap's lowest speed in a corner's window.
class SlowestPoint {
  const SlowestPoint({
    required this.speed,
    required this.station,
    required this.seconds,
    required this.atEdge,
  });

  final double speed;
  final double station;
  final double seconds;

  /// On the window's edge: the lap's minimum lies outside it, so this is not
  /// the corner's slowest point (§9: "not found in window").
  final bool atEdge;
}

/// [speed]'s minimum over [from, to] metres.
SlowestPoint? slowestIn(
  PlacedSeries speed, {
  required double from,
  required double to,
}) {
  int? at;
  for (var i = 0; i < speed.length; i++) {
    final station = speed.stations[i];
    if (station < from || station > to) continue;
    if (at == null || speed.values[i] < speed.values[at]) at = i;
  }
  if (at == null) return null;
  final station = speed.stations[at];
  return SlowestPoint(
    speed: speed.values[at],
    station: station,
    seconds: speed.times[at],
    atEdge: station - from < 1 || to - station < 1,
  );
}

/// The two laps' slowest points in one corner.
class SlowestFinding {
  const SlowestFinding({
    this.base,
    this.target,
    this.differentApexes = false,
    this.withheld,
    this.withheldFor,
  });

  final SlowestPoint? base;
  final SlowestPoint? target;

  /// True only when each lap has a hump of [apexHump] between the two
  /// stations: the laps took different apexes of one corner, and comparing
  /// their speeds compares two places.
  final bool differentApexes;

  final Withheld? withheld;
  final ComparisonRole? withheldFor;

  bool get stated => withheld == null;

  /// Base's speed less the Target's (km/h).
  double? get difference =>
      base == null || target == null ? null : base!.speed - target!.speed;

  bool get speedsDiffer => (difference?.abs() ?? 0) >= speedFloor;

  static SlowestFinding measure(
    FindingLap base,
    FindingLap target, {
    required double apex,
  }) {
    final from = apex - apexWindow;
    final to = apex + apexWindow;
    for (final (role, lap) in [
      (ComparisonRole.base, base),
      (ComparisonRole.target, target),
    ]) {
      if (lap.speed == null) {
        return SlowestFinding(withheld: Withheld.noData, withheldFor: role);
      }
    }
    final b = slowestIn(base.speed!, from: from, to: to);
    final t = slowestIn(target.speed!, from: from, to: to);
    final edge = b == null || b.atEdge
        ? ComparisonRole.base
        : t == null || t.atEdge
        ? ComparisonRole.target
        : null;
    if (edge != null) {
      return SlowestFinding(
        base: b,
        target: t,
        withheld: Withheld.notFound,
        withheldFor: edge,
      );
    }
    return SlowestFinding(
      base: b,
      target: t,
      differentApexes:
          _hump(base.speed!, b!.station, t!.station) &&
          _hump(target.speed!, b.station, t.station),
    );
  }
}

/// Whether [speed] rises at least [apexHump] above both its values at [a]
/// and [b] somewhere between them.
bool _hump(PlacedSeries speed, double a, double b) {
  final lo = math.min(a, b);
  final hi = math.max(a, b);
  final va = speed.valueAtStation(a);
  final vb = speed.valueAtStation(b);
  if (va == null || vb == null) return false;
  var top = math.max(va, vb);
  for (var i = 0; i < speed.length; i++) {
    final s = speed.stations[i];
    if (s > lo && s < hi) top = math.max(top, speed.values[i]);
  }
  return top - va >= apexHump && top - vb >= apexHump;
}

/// One downshift: the station of the neutral that starts it.
class Downshift {
  const Downshift({
    required this.from,
    required this.to,
    required this.station,
  });

  final int from;
  final int to;
  final double station;
}

/// [lap]'s gear changes, each at the station where it began: the neutral
/// event that opens it when there is one (§9 "Gear": events sit on a 2.5 ms
/// grid). Neutral and reverse are not gears here.
List<(int, int, double)> _shifts(FindingLap lap) {
  final gear = lap.gear;
  if (gear == null) return const [];
  final out = <(int, int, double)>[];
  int? previous;
  for (var k = 0; k < gear.length; k++) {
    final g = gear.values[k].round();
    if (g <= 0) continue;
    if (previous != null && g != previous) {
      final opened = k > 0 && gear.values[k - 1].round() == 0
          ? gear.times[k - 1]
          : gear.times[k];
      out.add((previous, g, lap.axis.distanceAt(opened)));
    }
    previous = g;
  }
  return out;
}

/// The gear in force on [lap] at [seconds], neutral skipped.
int? gearAt(FindingLap lap, double seconds) {
  final gear = lap.gear;
  if (gear == null) return null;
  int? found;
  for (var k = 0; k < gear.length; k++) {
    if (gear.times[k] > seconds) break;
    final g = gear.values[k].round();
    if (g > 0) found = g;
  }
  return found;
}

/// The two laps' gears through one corner.
class GearFinding {
  const GearFinding({
    this.baseLowest,
    this.targetLowest,
    this.baseDownshifts = const [],
    this.targetDownshifts = const [],
  });

  /// The gear at each lap's slowest point: exact, and the same on 92% of
  /// consecutive-lap pairs.
  final int? baseLowest;
  final int? targetLowest;

  final List<Downshift> baseDownshifts;
  final List<Downshift> targetDownshifts;

  bool get lowestDiffers =>
      baseLowest != null && targetLowest != null && baseLowest != targetLowest;

  /// Both laps make the same downshifts, in order (90% of pair-corners).
  bool get sameDownshifts {
    if (baseDownshifts.length != targetDownshifts.length) return false;
    for (var i = 0; i < baseDownshifts.length; i++) {
      if (baseDownshifts[i].from != targetDownshifts[i].from ||
          baseDownshifts[i].to != targetDownshifts[i].to) {
        return false;
      }
    }
    return true;
  }

  /// The downshifts whose stations differ by [downshiftFloor] or more, as
  /// (Base's, the Target's); empty unless [sameDownshifts].
  List<(Downshift, Downshift)> get statedDownshifts => !sameDownshifts
      ? const []
      : [
          for (var i = 0; i < baseDownshifts.length; i++)
            if ((baseDownshifts[i].station - targetDownshifts[i].station)
                    .abs() >=
                downshiftFloor)
              (baseDownshifts[i], targetDownshifts[i]),
        ];

  static GearFinding measure(
    FindingLap base,
    FindingLap target, {
    required double previousApex,
    required double apex,
    SlowestFinding? slowest,
  }) {
    List<Downshift> downshifts(FindingLap lap) => [
      for (final (from, to, station) in _shifts(lap))
        if (to < from &&
            station > previousApex + downshiftLead &&
            station <= apex + downshiftLead)
          Downshift(from: from, to: to, station: station),
    ];
    final measured = slowest != null && slowest.stated;
    final b = measured ? slowest.base : null;
    final t = measured ? slowest.target : null;
    return GearFinding(
      baseLowest: b == null ? null : gearAt(base, b.seconds),
      targetLowest: t == null ? null : gearAt(target, t.seconds),
      baseDownshifts: downshifts(base),
      targetDownshifts: downshifts(target),
    );
  }
}

/// Everything stated about one corner of the table.
class CornerFindings {
  const CornerFindings({
    required this.corner,
    required this.segment,
    required this.brake,
    required this.slowest,
    required this.gear,
  });

  final TrackCorner corner;

  /// The segment holding the corner's apex: where its findings are listed.
  final int segment;

  final BrakeFinding brake;
  final SlowestFinding slowest;
  final GearFinding gear;

  /// Whether a level segment holding this corner is worth a stop on the
  /// "Most lost" walk: a brake point, a downshift or a lowest gear that
  /// differs. The slowest point and the line describe every corner, so on
  /// their own they would send the walk through every level segment.
  bool get notable =>
      brake.stated || gear.lowestDiffers || gear.statedDownshifts.isNotEmpty;
}

/// A contact either lap recorded (`LastImpactMagnitude`), placed on the lap.
class ContactFinding {
  const ContactFinding({
    required this.role,
    required this.station,
    required this.segment,
  });

  final ComparisonRole role;
  final double station;

  /// The segment it happened in; null off the table's lap.
  final int? segment;
}

/// The findings for one pair over one segment table.
class ComparisonFindings {
  const ComparisonFindings({required this.corners, required this.contacts});

  /// Each corner's findings, measured on [base] and [target] over [table]'s
  /// corners. A corner's braking is looked for from the previous corner's
  /// apex (the line, for the first) to its own; its slowest point within
  /// [apexWindow] of its apex.
  factory ComparisonFindings.measure({
    required SegmentTable table,
    required FindingLap base,
    required FindingLap target,
  }) {
    final segments = table.segments;
    int? segmentOf(double station) =>
        segments.where((s) => s.contains(station)).firstOrNull?.number;
    final corners = [...table.corners]
      ..sort((a, b) => a.station.compareTo(b.station));
    final out = <CornerFindings>[];
    for (var c = 0; c < corners.length; c++) {
      final apex = corners[c].station;
      final previous = c == 0 ? 0.0 : corners[c - 1].station;
      final slowest = SlowestFinding.measure(base, target, apex: apex);
      out.add(
        CornerFindings(
          corner: corners[c],
          segment: segmentOf(apex) ?? segments.last.number,
          brake: BrakeFinding.measure(base, target, from: previous, to: apex),
          slowest: slowest,
          gear: GearFinding.measure(
            base,
            target,
            previousApex: previous,
            apex: apex,
            slowest: slowest,
          ),
        ),
      );
    }
    ContactFinding contact(ComparisonRole role, double station) =>
        ContactFinding(
          role: role,
          station: station,
          segment: segmentOf(station),
        );
    return ComparisonFindings(
      corners: out,
      contacts: [
        for (final (role, lap) in [
          (ComparisonRole.base, base),
          (ComparisonRole.target, target),
        ])
          for (final seconds in lap.impactSeconds)
            contact(role, lap.axis.distanceAt(seconds)),
      ],
    );
  }

  final List<CornerFindings> corners;
  final List<ContactFinding> contacts;

  /// The corner listed on segment [number], if it holds one.
  CornerFindings? inSegment(int number) =>
      corners.where((c) => c.segment == number).firstOrNull;

  List<ContactFinding> contactsIn(int number) => [
    for (final c in contacts)
      if (c.segment == number) c,
  ];

  /// Corners listed on another segment whose stated braking starts in
  /// [segment]: a Base that brakes earlier than the canonical lap starts
  /// braking in the previous segment, and the card there says so. An onset
  /// within the floor is not flagged: it states nothing to look for.
  List<CornerFindings> brakingFrom(Segment segment) => [
    for (final c in corners)
      if (c.segment != segment.number &&
          c.brake.stated &&
          [
            c.brake.base,
            c.brake.target,
          ].any((onset) => onset != null && segment.contains(onset.station)))
        c,
  ];

  /// The segments a level stretch is visited for (see
  /// [CornerFindings.notable]), and those holding a contact.
  Set<int> get notableSegments => {
    for (final c in corners)
      if (c.notable) c.segment,
    for (final c in contacts) ?c.segment,
  };
}
