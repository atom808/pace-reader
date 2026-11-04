/// Fuel & Energy as a [LapFocusTarget] (map stage proposal §6.4): the
/// screen has no lap selection of its own, so a link highlights the lap's
/// row in the table, and a click on a row picks it the same way.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../lap_focus/lap_focus.dart';

part 'fuel_energy_focus.g.dart';

/// The lap highlighted in the table, as `Lap.index`; null for none.
@Riverpod(keepAlive: true)
class FuelEnergyLap extends _$FuelEnergyLap {
  @override
  int? build(TelemetrySource source) => null;

  void select(int? lap) => state = lap;
}

class FuelEnergyFocusTarget implements LapFocusTarget {
  const FuelEnergyFocusTarget();

  @override
  String get route => '/fuel-energy';

  @override
  String get label => 'Fuel & energy';

  @override
  IconData get icon => Icons.local_gas_station_outlined;

  @override
  void apply(WidgetRef ref, LapFocus focus) =>
      ref.read(fuelEnergyLapProvider(focus.source).notifier).select(focus.lap);
}

const fuelEnergyFocusTarget = FuelEnergyFocusTarget();

/// The selected row's id for `LapFocusReveal`: where a focus lands.
const fuelEnergyRowReveal = 'fuel-energy-row';
