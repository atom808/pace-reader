/// Race control's calls about one car, cut into the recording's laps
/// (results proposal, R3).
///
/// The results file's `et` is the recording's own clock (both checked
/// recordings agree with it to 0.01 s), so a call lands on a lap by its time
/// alone and can be placed on the map from the recording's distance.
library;

import '../../../data/models/models.dart';
import 'results_session.dart';

enum RaceControlKind {
  /// An excursion and what race control decided: from "No Further Action"
  /// to a lap invalidated or a penalty.
  trackLimits,

  /// A reported contact, with how hard and with what.
  contact,

  /// A penalty given or served.
  penalty,

  /// New damage reported (`reports new suspension damage`).
  damage,
}

/// How hard a contact was, against every contact of its kind in the user's
/// 1,054 results files (110,043 of them): below the median is light, from
/// the median to the 90th percentile firm, above it heavy.
enum ContactSize { light, firm, heavy }

/// The median and 90th percentile of the game's contact magnitude, per thing
/// hit. The unit is the game's; only these comparisons are made with it.
const contactPercentiles = <String, (double, double)>{
  'Immovable': (122.02, 3125.60),
  'another vehicle': (293.48, 1425.86),
  'Post': (68.33, 226.24),
  'Sign': (45.90, 294.65),
  'Wheel': (45.00, 321.87),
  'Cone': (40.06, 177.32),
  'Wing': (18.89, 100.71),
};

/// For anything not in [contactPercentiles]: all 110,043 together.
const contactPercentilesAll = (156.37, 1821.66);

ContactSize contactSizeOf(String target, double magnitude) {
  final key = target.startsWith('another vehicle') ? 'another vehicle' : target;
  final (median, p90) = contactPercentiles[key] ?? contactPercentilesAll;
  if (magnitude >= p90) return ContactSize.heavy;
  if (magnitude >= median) return ContactSize.firm;
  return ContactSize.light;
}

/// One call.
class RaceControlCall {
  const RaceControlCall({
    required this.kind,
    required this.elapsed,
    required this.text,
    this.contactTarget,
    this.otherCar,
    this.magnitude,
    this.reportedByOther = false,
  });

  final RaceControlKind kind;

  /// Session time, on the recording's clock.
  final double elapsed;

  /// Race control's words: the resolution of a track-limit call, a
  /// penalty's line, a damage report.
  final String text;

  /// For a contact: `Immovable`, `Wing`, `another vehicle`, ….
  final String? contactTarget;

  /// For a contact with another car: its driver, as the file names them.
  final String? otherCar;
  final double? magnitude;

  /// The other car reported this contact and this car did not.
  final bool reportedByOther;

  ContactSize? get size => magnitude == null || contactTarget == null
      ? null
      : contactSizeOf(contactTarget!, magnitude!);

  /// A lap invalidated, a penalty or a disqualification: something that
  /// cost the lap or the race, rather than a note.
  bool get isSanction => switch (kind) {
    RaceControlKind.penalty => true,
    RaceControlKind.trackLimits =>
      text.startsWith('Invalid') ||
          text.contains('Penalty') ||
          text == 'Disqualify',
    _ => false,
  };

  bool get isWarning => kind == RaceControlKind.trackLimits && text == 'Warning';

  /// How much the call matters: 2 for what cost the lap or the race (a
  /// sanction, a heavy contact, damage), 1 for a warning or a firm contact,
  /// 0 for a note (a "No Further Action", a light contact).
  int get severity => switch (kind) {
    RaceControlKind.penalty || RaceControlKind.damage => 2,
    RaceControlKind.contact => switch (size) {
      ContactSize.heavy => 2,
      ContactSize.firm => 1,
      _ => 0,
    },
    RaceControlKind.trackLimits =>
      isSanction
          ? 2
          : isWarning
          ? 1
          : 0,
  };

  /// The call as a sentence, without its time.
  String get sentence => switch (kind) {
    RaceControlKind.trackLimits => 'Track limits: $text',
    RaceControlKind.contact => [
      switch (size) {
        ContactSize.light => 'Light contact',
        ContactSize.firm => 'Firm contact',
        ContactSize.heavy => 'Heavy contact',
        null => 'Contact',
      },
      if (otherCar != null)
        reportedByOther ? 'from $otherCar' : 'with $otherCar'
      else if (contactTarget != null)
        'with ${_target(contactTarget!)}',
    ].join(' '),
    RaceControlKind.penalty => text,
    RaceControlKind.damage => _capitalised(text),
  };

  static String _target(String raw) => switch (raw) {
    'Immovable' => 'a wall or barrier',
    'Wing' => 'the wing',
    'Wheel' => 'a wheel',
    final other => 'a ${other.toLowerCase()}',
  };

  static String _capitalised(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// The word beside a call's tick on the map.
String raceControlTickLabel(RaceControlCall call) => switch (call.kind) {
  RaceControlKind.trackLimits =>
    call.text.startsWith('Invalid') ? 'invalid' : 'limits',
  RaceControlKind.contact => 'contact',
  RaceControlKind.penalty => 'penalty',
  RaceControlKind.damage => 'damage',
};

final _contact = RegExp(r'reported contact \(([\d.]+)\) with (.+)$');
final _otherVehicle = RegExp(r'^another vehicle (.+?)\(\d+\)$');

/// Every call about [car] in [session], in time order.
///
/// A car-to-car contact is reported by both cars, a tenth of a second
/// apart. This car's own report is kept; the other car's is kept only when
/// this car reported nothing within half a second, and is marked
/// [RaceControlCall.reportedByOther].
List<RaceControlCall> raceControlFor(
  ResultsSession session,
  ResultsDriver car,
) {
  final mine = car.driverNames;
  bool isMine(String? name) => name != null && mine.contains(name);

  final own = <RaceControlCall>[];
  final fromOthers = <RaceControlCall>[];
  for (final e in session.events) {
    switch (e.kind) {
      case ResultsEventKind.trackLimits when isMine(e.driverName):
        own.add(
          RaceControlCall(
            kind: RaceControlKind.trackLimits,
            elapsed: e.elapsed,
            text: e.text,
          ),
        );
      case ResultsEventKind.incident:
        final m = _contact.firstMatch(e.text);
        if (m == null) continue;
        final magnitude = double.tryParse(m.group(1)!);
        final target = m.group(2)!;
        final other = _otherVehicle.firstMatch(target)?.group(1);
        if (isMine(e.driverName)) {
          own.add(
            RaceControlCall(
              kind: RaceControlKind.contact,
              elapsed: e.elapsed,
              text: e.text,
              contactTarget: other == null ? target : 'another vehicle',
              otherCar: other,
              magnitude: magnitude,
            ),
          );
        } else if (isMine(other)) {
          fromOthers.add(
            RaceControlCall(
              kind: RaceControlKind.contact,
              elapsed: e.elapsed,
              text: e.text,
              contactTarget: 'another vehicle',
              otherCar: e.driverName,
              magnitude: magnitude,
              reportedByOther: true,
            ),
          );
        }
      case ResultsEventKind.penalty
          when isMine(e.driverName) ||
              (e.driverName == null && mine.any((n) => e.text.startsWith('$n '))):
        own.add(
          RaceControlCall(
            kind: RaceControlKind.penalty,
            elapsed: e.elapsed,
            text: _penaltyText(e, mine),
          ),
        );
      case ResultsEventKind.sector
          when isMine(e.driverName) && e.text.contains('damage'):
        final cut = e.text.indexOf(') ');
        own.add(
          RaceControlCall(
            kind: RaceControlKind.damage,
            elapsed: e.elapsed,
            text: cut < 0 ? e.text : e.text.substring(cut + 2),
          ),
        );
      default:
        break;
    }
  }

  for (final theirs in fromOthers) {
    final echoed = own.any(
      (c) =>
          c.kind == RaceControlKind.contact &&
          c.otherCar == theirs.otherCar &&
          (c.elapsed - theirs.elapsed).abs() <= 0.5,
    );
    if (!echoed) own.add(theirs);
  }
  return own..sort((a, b) => a.elapsed.compareTo(b.elapsed));
}

/// `Drive Thru for Track Limits`, or `Served the Drive Thru`.
String _penaltyText(ResultsEvent e, Set<String> mine) {
  if (e.penalty != null) {
    return [
      'Penalty: ${e.penalty}',
      if (e.reason != null && e.reason!.isNotEmpty) 'for ${e.reason}',
    ].join(' ');
  }
  final served = RegExp(r'served (?:\w+ )?(.+?) penalty').firstMatch(e.text);
  return served == null
      ? e.text
      : 'Served the ${served.group(1)} penalty';
}

/// [calls] by the 0-based index of the lap each fell in. A call before the
/// first lap or after the last lap's start goes to the lap it is in, the
/// open last lap taking everything after its start.
Map<int, List<RaceControlCall>> raceControlByLap(
  List<RaceControlCall> calls,
  List<Lap> laps,
) {
  final byLap = <int, List<RaceControlCall>>{};
  for (final call in calls) {
    for (final lap in laps) {
      final end = lap.endSeconds ?? double.infinity;
      if (call.elapsed >= lap.startSeconds && call.elapsed < end) {
        (byLap[lap.index] ??= []).add(call);
        break;
      }
    }
  }
  return byLap;
}
