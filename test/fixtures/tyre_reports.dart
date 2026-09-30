// Tyres & brakes reports assembled from the generated per-lap fixtures
// (SPEC.md §8.6) — exactly what `tireBrakeReportProvider` builds from a real
// file, with the SQL already run: the per-corner series from
// `make_tyre_fixture.py`, the laps from the lap table, the setup blob and the
// recorded settings.
library;

import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/fuel_energy_strategy/application/fuel_energy.dart';
import 'package:pace_reader/features/tires_brakes/application/tire_brake_report.dart';
import 'package:pace_reader/features/tires_brakes/application/tyre_setup.dart';

import 'sebring_race_per_lap.dart';
import 'sebring_race_tyres.dart';
import 'spa_qualify_tyres.dart';

StepSeries _setting(String name, List<double> values) => StepSeries.fromRows(
      [for (var i = 0; i < values.length; i++) (i.toDouble(), values[i])],
      eventName: name,
    );

TireBrakeReport _report({
  required List<Lap> laps,
  required String setupJson,
  required List<PitVisit> pitVisits,
  required Map<Corner, List<LapChannelStats>> pressure,
  required Map<Corner, List<LapChannelStats>> left,
  required Map<Corner, List<LapChannelStats>> centre,
  required Map<Corner, List<LapChannelStats>> right,
  required Map<Corner, List<LapChannelStats>> carcass,
  required Map<Corner, List<LapChannelStats>> rim,
  required Map<Corner, List<LapChannelStats>> wear,
  required Map<Corner, List<LapChannelStats>> brakes,
  required List<double> brakeBiasRear,
  required List<double> brakeMigration,
}) {
  CornerSeries series(String name, Map<Corner, List<LapChannelStats>> data) =>
      CornerSeries(channelName: name, byCorner: data);
  return TireBrakeReport(
    laps: laps,
    setup: TyreSetup.fromJson(setupJson),
    pitVisits: pitVisits,
    pressure: series(tyrePressureChannelName, pressure),
    tread: TreadSeries(
      left: series(treadLeftChannelName, left),
      centre: series(treadCentreChannelName, centre),
      right: series(treadRightChannelName, right),
    ),
    carcass: series(carcassChannelName, carcass),
    rim: series(rimChannelName, rim),
    wear: {
      for (final corner in Corner.values)
        corner: ResourceUsage.derive(
          name: 'Wear ${corner.short}',
          unit: '%',
          laps: laps,
          stats: wear[corner]!,
          pitVisits: pitVisits,
        ),
    },
    brakes: series(brakeTempChannelName, brakes),
    brakeBiasRear:
        RecordedSetting(_setting(brakeBiasEventName, brakeBiasRear)),
    brakeMigration:
        RecordedSetting(_setting(brakeMigrationEventName, brakeMigration)),
  );
}

/// The full Sebring Race: 20 laps, GT3, no pit stop, clockwise.
TireBrakeReport sebringRaceTyreReport() => _report(
      laps: sebringRaceLaps(),
      setupJson: sebringRaceTyreSetupJson,
      // `In Pits` holds a single 0 row in this file: never went in.
      pitVisits: const [],
      pressure: sebringRacePressure(),
      left: sebringRaceTreadLeft(),
      centre: sebringRaceTreadCentre(),
      right: sebringRaceTreadRight(),
      carcass: sebringRaceCarcass(),
      rim: sebringRaceRim(),
      wear: sebringRaceWear(),
      brakes: sebringRaceBrakes(),
      brakeBiasRear: sebringRaceBrakeBiasRear,
      brakeMigration: sebringRaceBrakeMigration,
    );

/// Laps 0-4 of the Spa Hypercar Qualify, as `LapRepository` maps them: lap 0
/// leaves the garage (in the pit lane until 85.34 s), lap 1 is untimed, lap 3
/// is invalidated — the spin that takes 9.6% off the rear-right in one lap —
/// and lap 4 is cut off by the end of the recording.
List<Lap> spaQualifyLaps() {
  const raw = <(int, double, double?, double?)>[
    (0, 34.565, 206.38, null),
    (1, 206.38, 332.26, null),
    (2, 332.26, 455.0, 122.73663330078125),
    (3, 455.0, 586.42, null),
    (4, 586.42, null, null),
  ];
  return [
    for (final (index, start, end, time) in raw)
      Lap(
        index: index,
        startSeconds: start,
        endSeconds: end,
        lapTimeSeconds: time,
        sectors: const SectorTimes(),
      ),
  ];
}

/// The Spa Hypercar Qualify: tyres from ambient (18 °C) — the warm-up case.
TireBrakeReport spaQualifyTyreReport() => _report(
      laps: spaQualifyLaps(),
      setupJson: spaQualifyTyreSetupJson,
      pitVisits: const [
        PitVisit(
          enteredSeconds: 34.565,
          exitedSeconds: 85.34,
          fromRecordingStart: true,
        ),
      ],
      pressure: spaQualifyPressure(),
      left: spaQualifyTreadLeft(),
      centre: spaQualifyTreadCentre(),
      right: spaQualifyTreadRight(),
      carcass: spaQualifyCarcass(),
      rim: spaQualifyRim(),
      wear: spaQualifyWear(),
      brakes: spaQualifyBrakes(),
      brakeBiasRear: spaQualifyBrakeBiasRear,
      brakeMigration: spaQualifyBrakeMigration,
    );
