/// How the car's pace sat in its class, from LMU's results file (results
/// proposal, R2): ranks on best and typical lap, and the class's middle half
/// to read the recording's laps against.
library;

import 'results_session.dart';

/// A lap that says something about pace: timed, with all three sectors (an
/// invalidated lap keeps its time and loses its sectors), and without a stop.
bool isPaceLap(ResultsLap lap) =>
    lap.lapSeconds != null && lap.hasAllSectors && !lap.pit;

/// The fewest other cars a band is drawn from. With fewer, a p25 and a p75
/// are two of a handful of laps and say more about those cars than about the
/// class, so the cars are listed instead.
///
/// Measured (proposal §4) on the 228 classes of 20 cars or more in the
/// user's 1,054 results files, by drawing n of their cars at random and
/// comparing that band's edges with the whole class's. From 5 cars an edge
/// is typically off by half the band's width (0.9 s) and one time in ten
/// by a full width; from 8 the typical error is a third (0.66 s), from 10 a
/// quarter. Race bands, lap by lap over 1,879 laps, behave the same. Eight
/// keeps the band on 824 of the 1,195 classes of 3 or more.
const fieldBandMinCars = 8;

/// [sorted]'s value at fraction [p] of the way through, interpolating
/// between neighbours. [sorted] must not be empty.
double quantile(List<double> sorted, double p) {
  if (sorted.length == 1) return sorted.first;
  final at = p * (sorted.length - 1);
  final low = at.floor();
  final high = at.ceil();
  return sorted[low] + (sorted[high] - sorted[low]) * (at - low);
}

/// One car's pace in the file.
class FieldCar {
  FieldCar(this.driver)
    : paceLaps = {
        for (final lap in driver.laps)
          if (isPaceLap(lap)) lap.number: lap.lapSeconds!,
      } {
    final times = paceLaps.values.toList()..sort();
    best = times.isEmpty ? null : times.first;
    typical = times.isEmpty ? null : quantile(times, 0.5);
  }

  final ResultsDriver driver;

  /// Pace-lap times by the file's 1-based lap number.
  final Map<int, double> paceLaps;

  /// The fastest pace lap. Null when the car set none.
  late final double? best;

  /// The median pace lap: what the car could do lap after lap, rather than
  /// once.
  late final double? typical;
}

/// The class's middle half, per lap number in a race or for the whole
/// session otherwise.
class FieldBand {
  const FieldBand.session(this.range, {required this.cars})
    : byLapNumber = const {};

  const FieldBand.perLap(this.byLapNumber, {required this.cars})
    : range = null;

  /// Practice and qualifying: cars run at different times, so one range,
  /// from the cars' typical laps.
  final (double, double)? range;

  /// A race: lap N's middle half among the cars that ran a pace lap N, so a
  /// safety car or a stint's fuel load moves the field with the car. Only
  /// lap numbers with [fieldBandMinCars] cars or more.
  final Map<int, (double, double)> byLapNumber;

  /// The other cars the band is drawn from.
  final int cars;

  bool get perLap => range == null;

  /// The band at lap [number] (1-based, as the file numbers laps).
  (double, double)? at(int number) => range ?? byLapNumber[number];
}

/// The car against its class.
class FieldPace {
  FieldPace._(this.kind, this.me, this.classCars);

  factory FieldPace.of(ResultsSession session, ResultsDriver car) {
    final cars = [
      for (final d in session.drivers)
        if (d.carClass == car.carClass) FieldCar(d),
    ];
    final me = cars.firstWhere((c) => c.driver.index == car.index);
    return FieldPace._(session.kind, me, [
      for (final c in cars)
        if (c.typical != null) c,
    ]..sort((a, b) => a.typical!.compareTo(b.typical!)));
  }

  final ResultsSessionKind kind;
  final FieldCar me;

  /// Every car in the class that set a pace lap, [me] included when it did,
  /// fastest typical lap first.
  final List<FieldCar> classCars;

  int get classSize => classCars.length;

  /// 1 plus the cars strictly faster; null when [me] set no pace lap.
  int? get bestRank => me.best == null
      ? null
      : 1 + classCars.where((c) => c.best! < me.best!).length;

  int? get typicalRank => me.typical == null
      ? null
      : 1 + classCars.where((c) => c.typical! < me.typical!).length;

  /// The other cars, or only those of [me]'s model.
  List<FieldCar> others({bool sameModel = false}) => [
    for (final c in classCars)
      if (c != me && (!sameModel || c.driver.carType == me.driver.carType)) c,
  ];

  /// The fastest pace lap among [others].
  FieldCar? fastestOther({bool sameModel = false}) {
    FieldCar? fastest;
    for (final c in others(sameModel: sameModel)) {
      if (fastest == null || c.best! < fastest.best!) fastest = c;
    }
    return fastest;
  }

  /// The class's middle half without [me]; null with fewer than
  /// [fieldBandMinCars] other cars.
  FieldBand? band({bool sameModel = false}) {
    final cars = others(sameModel: sameModel);
    if (cars.length < fieldBandMinCars) return null;
    if (kind != ResultsSessionKind.race) {
      final typical = [for (final c in cars) c.typical!]..sort();
      return FieldBand.session(
        (quantile(typical, 0.25), quantile(typical, 0.75)),
        cars: cars.length,
      );
    }
    final byNumber = <int, List<double>>{};
    for (final c in cars) {
      for (final MapEntry(:key, :value) in c.paceLaps.entries) {
        (byNumber[key] ??= []).add(value);
      }
    }
    final ranges = <int, (double, double)>{
      for (final MapEntry(:key, :value) in byNumber.entries)
        if (value.length >= fieldBandMinCars)
          key: (
            quantile(value..sort(), 0.25),
            quantile(value, 0.75),
          ),
    };
    return ranges.isEmpty ? null : FieldBand.perLap(ranges, cars: cars.length);
  }
}

/// `1st`, `2nd`, `3rd`, `11th`, `21st`.
String ordinal(int n) {
  final tens = n % 100;
  if (tens >= 11 && tens <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
