/// What each car in the class used, lap by lap, from LMU's results file
/// (results proposal, R6): fuel, energy and tread, and how long its stints
/// ran.
///
/// Shares, as the file holds them: of a full tank, of the energy allowance,
/// of new tread. The tread is the recording's own wear channel at each
/// lap's end, in 256ths (proposal §4); fuel and energy are written the same
/// way. Some servers leave all three out for every car, and then there is
/// nothing to show.
library;

import 'field_pace.dart';
import 'results_session.dart';

/// One car's use per lap, as medians over its pace laps, and its stints.
class CarResources {
  CarResources._({
    required this.car,
    required this.fuelPerLap,
    required this.energyPerLap,
    required this.treadPerLap,
    required this.stints,
  });

  factory CarResources.of(FieldCar car) {
    final laps = [...car.driver.laps]
      ..sort((a, b) => a.number.compareTo(b.number));
    final fuel = <double>[];
    final energy = <double>[];
    final tread = <double>[];
    ResultsLap? previous;
    for (final lap in laps) {
      if (isPaceLap(lap)) {
        if (lap.fuelUsedFraction case final f? when f > 0) fuel.add(f);
        if (lap.energyUsedFraction case final e? when e > 0) energy.add(e);
        // Against the lap before, unless a stop between could have fitted
        // new tyres: a lap's own wear is the change across it.
        final before = previous == null || previous.pit
            ? null
            : _treadOf(previous);
        final after = _treadOf(lap);
        if (before != null && after != null && before >= after) {
          tread.add(before - after);
        }
      }
      previous = lap;
    }
    double? median(List<double> xs) =>
        xs.isEmpty ? null : quantile(xs..sort(), 0.5);

    return CarResources._(
      car: car,
      fuelPerLap: median(fuel),
      energyPerLap: median(energy),
      treadPerLap: median(tread),
      stints: stintsOf(laps),
    );
  }

  final FieldCar car;

  /// Share of a full tank a pace lap used; null when the file has none.
  final double? fuelPerLap;

  /// Share of the energy allowance a pace lap used.
  final double? energyPerLap;

  /// Share of new tread a pace lap took off, the four tyres averaged.
  final double? treadPerLap;

  /// Laps in each stint, a stop closing one: `[12, 13, 9]`.
  final List<int> stints;

  static double? _treadOf(ResultsLap lap) {
    final corners = [
      lap.wearFrontLeft,
      lap.wearFrontRight,
      lap.wearRearLeft,
      lap.wearRearRight,
    ];
    if (corners.any((c) => c == null)) return null;
    return corners.fold<double>(0, (sum, c) => sum + c!) / 4;
  }
}

/// [laps] (in order) cut at each stop: a stint runs to and includes the lap
/// with `pit="1"`, and the last runs to the end.
List<int> stintsOf(List<ResultsLap> laps) {
  final stints = <int>[];
  var run = 0;
  for (final lap in laps) {
    run++;
    if (lap.pit) {
      stints.add(run);
      run = 0;
    }
  }
  if (run > 0) stints.add(run);
  return stints;
}

/// Whether the file holds fuel, energy or tread for any car in [pace].
bool hasResources(FieldPace pace) => pace.classCars.any(
  (c) => c.driver.laps.any(
    (l) =>
        l.fuelUsedFraction != null ||
        l.energyUsedFraction != null ||
        l.wearFrontLeft != null,
  ),
);
