/// Each lap's conditions and setup, read for the comparability strip
/// (comparison proposal §7 "Lap-start chips", "Setup"; §9 `lap_conditions.dart`).
///
/// Apart from the chart: none of it is needed to draw a lap, so the strip
/// gains these chips once they are read, and a file that lacks a channel
/// loses only its line in the popover.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/reference/car_catalog.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../../data/repositories/providers.dart';
import '../../fuel_energy_strategy/application/fuel_energy.dart';
import '../../setup_viewer/application/car_setup.dart';
import '../../setup_viewer/application/car_setup_provider.dart';
import '../../tires_brakes/application/tire_brake_report.dart';
import '../../tires_brakes/application/tyre_setup.dart';
import '../domain/comparability.dart';
import '../domain/comparison_set.dart';
import '../domain/lap_conditions.dart';
import 'compare_source_guard.dart';

part 'lap_conditions.g.dart';

const trackTemperatureChannelName = 'Track Temperature';
const ambientTemperatureChannelName = 'Ambient Temperature';

/// The wetness the racing line holds, in %: 0, 5, 12.5, 40 or 60 in the
/// library.
const pathWetnessEventName = 'Minimum Path Wetness';

Duration? _neverRetry(int retryCount, Object error) => null;

/// [source]'s conditions, per lap.
///
/// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
/// two sparse event tables: a session's worth costs about as much as the
/// fuel view's own reads. Kept alive as that view's report is.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionConditions> sessionConditions(
  Ref ref,
  TelemetrySource source,
) async {
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  Future<Map<int, LapChannelStats>> stats(String name) async {
    if (!catalog.hasChannel(name)) return const {};
    return {for (final s in await telemetry.readLapStats(name)) s.lapIndex: s};
  }

  Future<StepSeries?> event(String name, {String? column}) async {
    if (!catalog.hasEvent(name)) return null;
    final series = await telemetry.readEventWindow(
      name,
      startSeconds: catalog.origin,
      endSeconds: catalog.endSeconds + 1,
      valueColumn: column,
    );
    return series.isEmpty ? null : series;
  }

  final wear = <Corner, Map<int, LapChannelStats>>{};
  if (catalog.channel(tyreWearChannelName)?.valueColumnCount ==
      Corner.values.length) {
    final byColumn = await telemetry.readLapStatsByColumn(
      tyreWearChannelName,
      valueColumns: Corner.valueColumns,
    );
    for (final corner in Corner.values) {
      wear[corner] = {
        for (final s in byColumn[corner.valueColumn]!) s.lapIndex: s,
      };
    }
  }

  List<StepSeries>? compound;
  if (catalog.event(tyreCompoundEventName)?.valueColumns.length ==
      Corner.values.length) {
    final series = [
      for (final corner in Corner.values)
        await event(tyreCompoundEventName, column: corner.valueColumn),
    ];
    if (series.every((s) => s != null)) {
      compound = [for (final s in series) s!];
    }
  }

  // The setup names the compound each corner started on; the series' first
  // rows say which index that is (SPEC §15.20).
  var compoundKey = CompoundKey.none;
  if (compound != null) {
    final metadata = await ref.watch(sessionMetadataProvider(source).future);
    compoundKey = TyreSetup.fromJson(metadata.carSetupJson).compoundKey({
      for (final (i, corner) in Corner.values.indexed)
        corner: compound[i].values.first.round(),
    });
  }

  return SessionConditions(
    fuel: await stats(fuelLevelChannelName),
    energy: await stats(virtualEnergyChannelName),
    wear: wear,
    wetness: await event(pathWetnessEventName),
    compound: compound,
    compoundKey: compoundKey,
    trackTemperature: await stats(trackTemperatureChannelName),
    ambientTemperature: await stats(ambientTemperatureChannelName),
    settings: {for (final name in settingEventNames) name: ?await event(name)},
  );
}

/// The strip's chips for [set]'s conditions and setups; empty without a
/// Target.
///
/// Reads each lap from its file's lap table rather than from the chart, so
/// switching axis or panels never re-derives these.
@Riverpod(retry: _neverRetry)
Future<List<ComparabilityChip>> comparisonConditions(
  Ref ref,
  ComparisonSet set,
) async {
  final target = set.target;
  if (target == null) return const [];
  requireSourceOpen(ref, set.base.source, ComparisonRole.base);
  requireSourceOpen(ref, target.source, ComparisonRole.target);

  Future<LapConditions?> conditions(TelemetrySource source, int index) async {
    final laps = await ref.watch(lapsProvider(source).future);
    final lap = laps.where((l) => l.index == index).firstOrNull;
    if (lap == null) return null;
    return (await ref.watch(sessionConditionsProvider(source).future)).of(lap);
  }

  Future<CarSetup?> setup(TelemetrySource source) async {
    try {
      return await ref.watch(carSetupProvider(source).future);
    } on SetupFormatException {
      return null;
    }
  }

  final base = await conditions(set.base.source, set.base.lapIndex);
  final other = await conditions(target.source, target.lapIndex);
  if (base == null || other == null) return const [];
  Future<CarPlacement> car(TelemetrySource source) async {
    final meta = await ref.watch(sessionMetadataProvider(source).future);
    return placeCar(meta.carName, meta.carClass);
  }

  // The same model in the same class: another entry's livery and number do
  // not change the car, so its setup and compound list compare.
  final sameCar = (await car(set.base.source))
      .sameCarAs(await car(target.source));
  return [
    ...conditionChips(base: base, target: other, sameCar: sameCar),
    if (sameCar)
      ?setupChip(await setup(set.base.source), await setup(target.source)),
  ];
}
