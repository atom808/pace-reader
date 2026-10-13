/// How the Why card words each finding (comparison proposal §2, §3).
///
/// Movement and facts, never advice: "Target brakes 23 m later", never
/// "brake later". Speeds in whole km/h and stations to 5 m where the floor
/// says a finer figure would be noise; brake points to the metre, because
/// their floor is 5 m and the card quotes the difference.
library;

import '../domain/comparison_set.dart';
import '../domain/segment_findings.dart';
import '../domain/segments.dart';

/// "1st", "2nd", "3rd", "4th"…
String ordinalGear(int gear) {
  final teen = gear % 100 >= 11 && gear % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (gear % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$gear$suffix';
}

/// Stations are shown to 5 m: speed minima are flat, the stretch within
/// 1 km/h of one spanning a median 12 m.
String toFive(double station) => '${(station / 5).round() * 5}';

String _metres(double station) => station.toStringAsFixed(0);

String _kmh(double speed) => speed.toStringAsFixed(0);

String _who(ComparisonRole? role) => role?.label ?? 'Neither lap';

/// Why the card says nothing about throttle (probe 0e): no throttle pickup,
/// release or dab finding reaches 95% sign stability at any floor, so none is
/// stated in v1. The pedal stays a panel.
const throttleNotStated =
    'Throttle pickup, release and dabs: not stated, since each varies with '
    "the detector's threshold. Read them off the Throttle panel.";

/// The floors, for the card's information button.
const findingFloors = [
  "Brake points: the main ramp's onset at 2, 5 and 10% pedal, stated only "
      'when all three agree on which lap brakes later and the gap is 5 m or '
      'more. They need the pedal at its recorded 50 Hz.',
  'Speeds: from 1 km/h. Stations: to 5 m, because speed minima are flat '
      '(the stretch within 1 km/h of one spans a median 12 m).',
  "Slowest point: each lap's minimum within 60 m of the corner's apex; "
      '"different apexes" only across a hump of 2 km/h on both laps.',
  'Gears: the gear at the slowest point, exactly; a downshift station from '
      '5 m, and only when both laps make the same downshifts.',
  'Throttle pickup, release and dabs: never stated. Across thresholds, '
      'pickup agrees in sign at most 64% of the time.',
];

/// The brake line.
String brakeText(BrakeFinding f) {
  final base = f.base;
  final target = f.target;
  switch (f.withheld) {
    case null:
      final d = f.difference!;
      return 'Target brakes ${d.abs().toStringAsFixed(0)} m '
          '${d < 0 ? 'later' : 'earlier'} '
          '(${_metres(target!.station)} vs ${_metres(base!.station)} m).';
    case Withheld.dataRate:
      return 'Brake point not stated: data rate. An onset needs the pedal at '
          "its recorded 50 Hz, and ${_who(f.withheldFor)}'s arrives slower.";
    case Withheld.noData:
      return 'Brake point not stated: ${_who(f.withheldFor)} recorded no '
          'brake pedal.';
    case Withheld.noBraking:
      final who = f.withheldFor;
      return who == null
          ? 'No braking zone on either lap before this corner.'
          : 'Brake point not stated: ${who.label} does not brake for this '
                'corner (no pedal over ${brakeZoneMinPeak.toStringAsFixed(0)}%).';
    case Withheld.belowFloor:
      return 'Brake points within ${brakeOnsetFloor.toStringAsFixed(0)} m '
          '(Base ${_metres(base!.station)}, Target ${_metres(target!.station)} '
          'm): not called.';
    case Withheld.thresholdsDisagree:
      return 'Brake points not stated: the 2, 5 and 10% onsets disagree on '
          'which lap brakes later.';
    case Withheld.notFound:
      return 'Brake point not stated: not found.';
  }
}

/// km/h joined across its slash: the Why card is narrow, and a line may
/// otherwise break between "km/" and "h".
const kmh = 'km/\u2060h';

/// Each lap's speed at its own brake onset, when the brake line is stated.
String? brakeSpeedText(BrakeFinding f) {
  final b = f.baseSpeed;
  final t = f.targetSpeed;
  if (!f.stated || b == null || t == null) return null;
  return f.speedStated
      ? 'Speed at the brake point: Base ${_kmh(b)}, Target ${_kmh(t)} $kmh.'
      : 'Speed at the brake point: both ${_kmh(b)} $kmh.';
}

/// The slowest-point line.
String slowestText(SlowestFinding f) {
  switch (f.withheld) {
    case null:
      final b = f.base!;
      final t = f.target!;
      final where = toFive(b.station) == toFive(t.station)
          ? ''
          : f.differentApexes
          ? ' (different apexes)'
          : ' (same apex)';
      return f.speedsDiffer
          ? 'Slowest: Base ${_kmh(b.speed)} $kmh at ${toFive(b.station)} m, '
                'Target ${_kmh(t.speed)} $kmh at ${toFive(t.station)} m$where.'
          : 'Slowest: both ${_kmh(b.speed)} $kmh, Base at '
                '${toFive(b.station)} m, Target at ${toFive(t.station)} m'
                '$where.';
    case Withheld.notFound:
      return "Slowest point not found in the corner's window on "
          "${_who(f.withheldFor)}: its minimum lies over "
          '${apexWindow.toStringAsFixed(0)} m from the apex.';
    case Withheld.noData:
      return 'Slowest point not stated: ${_who(f.withheldFor)} recorded no '
          'Ground Speed.';
    case _:
      return 'Slowest point not stated.';
  }
}

String _sequence(List<Downshift> shifts) => shifts.isEmpty
    ? 'none'
    : [shifts.first.from, for (final s in shifts) s.to].join('→');

/// The gear lines: the lowest gear, then the downshifts.
List<String> gearText(GearFinding g) {
  final lines = <String>[];
  final b = g.baseLowest;
  final t = g.targetLowest;
  if (b != null && t != null) {
    lines.add(
      b == t
          ? 'Lowest gear: both ${ordinalGear(b)}.'
          : 'Lowest gear: Base ${ordinalGear(b)}, Target ${ordinalGear(t)}.',
    );
  }
  if (g.baseDownshifts.isEmpty && g.targetDownshifts.isEmpty) return lines;
  if (!g.sameDownshifts) {
    lines.add(
      'Downshifts differ (Base ${_sequence(g.baseDownshifts)}, Target '
      '${_sequence(g.targetDownshifts)}), so their stations are not compared.',
    );
    return lines;
  }
  final stated = g.statedDownshifts;
  if (stated.isEmpty) {
    lines.add(
      'Downshifts ${_sequence(g.baseDownshifts)} within '
      '${downshiftFloor.toStringAsFixed(0)} m of each other.',
    );
    return lines;
  }
  for (final (base, target) in stated) {
    final d = base.station - target.station;
    lines.add(
      'Downshift to ${ordinalGear(base.to)}: Target '
      '${d.abs().toStringAsFixed(0)} m ${d < 0 ? 'later' : 'earlier'} '
      '(${_metres(target.station)} vs ${_metres(base.station)} m).',
    );
  }
  return lines;
}

/// "Contact recorded at 854 m (Base)."
String contactText(ContactFinding c) =>
    'Contact recorded at ${_metres(c.station)} m (${c.role.label}).';

/// The flag on a stretch where a later corner's braking starts.
String brakingFromText(CornerFindings c, Segment here, String corner) {
  final starts = [
    for (final (role, onset) in [
      (ComparisonRole.base, c.brake.base),
      (ComparisonRole.target, c.brake.target),
    ])
      if (onset != null && here.contains(onset.station))
        '${role.label} at ${_metres(onset.station)} m',
  ];
  return 'Braking for $corner starts here: ${starts.join(', ')}.';
}
