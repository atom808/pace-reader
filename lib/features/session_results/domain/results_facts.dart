/// What a results file says about the session a recording was made in, as
/// lines for the Overview (results proposal, R4).
///
/// Each line is shown only when it says something: a multiplier at its
/// default, a single driver, a finish that was simply a finish, are left out
/// rather than written as "none".
library;

import '../../../data/reference/car_catalog.dart';
import '../../../data/reference/car_class.dart';
import 'field_pace.dart';
import 'results_session.dart';

/// One labelled line.
class ResultsFact {
  const ResultsFact(this.label, this.value, {this.detail, this.model});

  final String label;
  final String value;

  /// A longer explanation, for a tooltip.
  final String? detail;

  /// The car the line names, for its make's logo beside the value.
  final CarModel? model;

  @override
  bool operator ==(Object other) =>
      other is ResultsFact &&
      other.label == label &&
      other.value == value &&
      other.detail == detail &&
      other.model == model;

  @override
  int get hashCode => Object.hash(label, value, detail, model);

  @override
  String toString() => '$label: $value';
}

/// The lines for [car] in [session].
List<ResultsFact> resultsFactsOf(ResultsSession session, ResultsDriver car) {
  final classLabel = CarClass.parse(car.carClass).label;
  final inClass = [
    for (final d in session.drivers)
      if (d.carClass == car.carClass) d,
  ];
  return [
    ResultsFact('Session', switch (session.setting) {
      'Multiplayer' =>
        session.serverName.isEmpty
            ? 'Online'
            : 'Online · ${session.serverName}',
      'Race Weekend' => 'Offline race weekend',
      final other => other,
    }),
    if (session.trackEvent.isNotEmpty) ResultsFact('Event', session.trackEvent),
    if (session.kind == ResultsSessionKind.race)
      if (_raceLength(session) case final length?)
        ResultsFact('Race length', length),
    if (_rules(session) case final rules?)
      ResultsFact(
        'Rules',
        rules,
        detail:
            'The server\'s multipliers. Fuel use and tyre wear scale how fast '
            'they run out; damage scales how much a contact costs.',
      ),
    ?_result(session, car),
    ResultsFact(
      'Field',
      '${_plural(session.drivers.length, 'car')}'
          '${session.drivers.length == inClass.length ? '' : ' · ${inClass.length} $classLabel'}',
    ),
    ?_paceInClass(FieldPace.of(session, car)),
    if (session.kind == ResultsSessionKind.race || car.pitStops > 0)
      ResultsFact('Pit stops', '${car.pitStops}'),
    ResultsFact(
      'Car',
      [
        if (car.carType.isNotEmpty) car.carType,
        if (car.teamName.isNotEmpty) car.teamName,
        if (car.carNumber.isNotEmpty) '#${car.carNumber}',
      ].join(' · '),
      model: car.model,
    ),
    if (_drivers(car) case final drivers?) ResultsFact('Drivers', drivers),
    if (_aids(car) case final aids?)
      ResultsFact(
        'Aids',
        aids,
        detail:
            'As LMU\'s results list them for this car, by lap range. '
            'Traction control and ABS levels are in the recording itself.',
      ),
    if (session.gameVersion.isNotEmpty)
      ResultsFact('Game version', session.gameVersion),
  ];
}

String _plural(int n, String one) => '$n ${n == 1 ? one : '${one}s'}';

/// "best 1st of 21 · typical lap 3rd of 21": where the car's fastest and
/// median pace laps ranked among the class's. Absent for a car alone in its
/// class, or one that set no pace lap.
ResultsFact? _paceInClass(FieldPace pace) {
  final best = pace.bestRank;
  final typical = pace.typicalRank;
  if (best == null || typical == null || pace.classSize < 2) return null;
  final of = 'of ${pace.classSize}';
  return ResultsFact(
    'Pace in class',
    'best ${ordinal(best)} $of · typical lap ${ordinal(typical)} $of',
    detail:
        'Among the cars in this class that set a lap with all three sectors '
        'and no stop. The typical lap is the median of those laps: what a car '
        'did lap after lap rather than once. $bopNote',
  );
}

String? _raceLength(ResultsSession s) {
  if (s.raceLaps case final laps?) return _plural(laps, 'lap');
  final minutes = s.raceMinutes;
  if (minutes == null) return null;
  if (minutes >= 60 && minutes % 60 == 0) return '${minutes ~/ 60} h';
  return '$minutes min';
}

String? _rules(ResultsSession s) {
  String times(double v) =>
      v == v.roundToDouble() ? '×${v.round()}' : '×${v.toStringAsFixed(1)}';
  final parts = [
    if (s.fuelMultiplier case final f? when f != 1) 'Fuel use ${times(f)}',
    if (s.tyreMultiplier case final t? when t != 1) 'Tyre wear ${times(t)}',
    if (s.damagePercent case final d? when d != 100) 'Damage ${d.round()} %',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

ResultsFact? _result(ResultsSession s, ResultsDriver car) {
  final position = car.position;
  if (position == null) return null;
  String place(int? overall, int? inClass) =>
      inClass == null ? 'P$overall' : 'P$overall (P$inClass in class)';
  final status = switch (car.finishStatus) {
    '' || 'None' || 'Finished Normally' => null,
    final other => car.dnfReason == null ? other : '$other · ${car.dnfReason}',
  };
  if (s.kind == ResultsSessionKind.race) {
    final finish = place(position, car.classPosition);
    final grid = car.gridPosition;
    return ResultsFact(
      'Result',
      [
        grid == null
            ? 'Finished $finish'
            : 'Started ${place(grid, car.classGridPosition)} · '
                  'finished $finish',
        ?status,
      ].join(' · '),
    );
  }
  return ResultsFact(
    'Classified',
    [
      'P$position overall',
      if (car.classPosition case final c?) 'P$c in class',
      ?status,
    ].join(' · '),
    detail:
        'Outside a race the game ranks cars by their best lap, so this is '
        'where the best lap placed.',
  );
}

String? _drivers(ResultsDriver car) {
  final named = [
    for (final s in car.swaps)
      if (s.value != '???') s,
  ];
  if (named.map((s) => s.value).toSet().length < 2) return null;
  return [for (final s in named) 'laps ${s.startLap}–${s.endLap}: ${s.value}']
      .join(' · ');
}

String? _aids(ResultsDriver car) {
  String? words(String raw) {
    final parts = [
      for (final p in raw.split(','))
        if (p.trim() case final t
            when t.isNotEmpty && t != 'PlayerControl' && t != 'UnknownControl')
          _aidName(t),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  final known = [
    for (final s in car.aids)
      if (words(s.value) case final w?) (s, w),
  ];
  if (known.isEmpty) return null;
  if (known.length == 1) return known.single.$2;
  // `;` between stints, since ` · ` already separates the aids in one.
  return [for (final (s, w) in known) 'laps ${s.startLap}–${s.endLap}: $w']
      .join('; ');
}

/// The file's tokens, split into words: `AutoBlip` → `auto-blip`.
String _aidName(String token) => switch (token) {
  'AutoBlip' => 'auto-blip',
  'Clutch' => 'auto-clutch',
  'AutoShift' => 'auto-shift',
  'AutoPit' => 'auto-pit',
  // rFactor writes a level as `TC=3`.
  final t when t.contains('=') => t.replaceAll('=', ' '),
  _ =>
    token
        .replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (m) => '-${m[1]}')
        .toLowerCase(),
};
