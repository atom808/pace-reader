/// Fuel, virtual energy and state of charge, per lap (SPEC.md §8.7).
///
/// Everything here is arithmetic over per-lap aggregates the repository
/// computes in SQL (`TelemetryRepository.readLapStats`), so the derivations
/// are plain functions a `flutter test` reaches without a DuckDB connection —
/// the same split the data layer makes.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';

part 'fuel_energy.g.dart';

const fuelLevelChannelName = 'Fuel Level';
const virtualEnergyChannelName = 'Virtual Energy';
const stateOfChargeChannelName = 'SoC';
const inPitsEventName = 'In Pits';

/// `metadata.CarClass` for the one class with a hybrid system (§5.4). The
/// state-of-charge view branches on this, as §8.7 requires — never on which
/// tables exist, since every file carries all of them.
const hypercarClass = 'Hyper';

/// A stretch the car spent in the pit lane, from `In Pits` (§8.7).
class PitVisit {
  const PitVisit({
    required this.enteredSeconds,
    required this.exitedSeconds,
    this.fromRecordingStart = false,
  });

  /// When the car entered the pit lane — or, with [fromRecordingStart], when
  /// the recording began with it already there, which is how every practice
  /// and qualifying file on hand starts.
  final double enteredSeconds;

  /// Null when the recording ended with the car still in the pit lane.
  final double? exitedSeconds;

  final bool fromRecordingStart;

  double? get durationSeconds =>
      exitedSeconds == null ? null : exitedSeconds! - enteredSeconds;

  /// Whether any part of the visit fell inside [lap].
  bool overlaps(Lap lap) {
    final lapEnd = lap.endSeconds ?? double.infinity;
    final visitEnd = exitedSeconds ?? double.infinity;
    return enteredSeconds < lapEnd && visitEnd > lap.startSeconds;
  }
}

/// Pit-lane visits from the `In Pits` step signal.
///
/// `In Pits` records changes only, so a session that never visited the pits
/// holds a single `0` row (the Race sample does) and yields no visits — the
/// normal case §8.7 says to render, not an error.
List<PitVisit> pitVisitsFrom(StepSeries inPits) {
  final visits = <PitVisit>[];
  double? enteredAt;
  var fromStart = false;
  for (var i = 0; i < inPits.length; i++) {
    final inside = inPits.values[i] >= 0.5;
    if (inside && enteredAt == null) {
      enteredAt = inPits.times[i];
      fromStart = i == 0;
    } else if (!inside && enteredAt != null) {
      visits.add(PitVisit(
        enteredSeconds: enteredAt,
        exitedSeconds: inPits.times[i],
        fromRecordingStart: fromStart,
      ));
      enteredAt = null;
    }
  }
  if (enteredAt != null) {
    visits.add(PitVisit(
      enteredSeconds: enteredAt,
      exitedSeconds: null,
      fromRecordingStart: fromStart,
    ));
  }
  return visits;
}

/// Why a lap is left out of the per-lap average — each for a reason that
/// makes its figure describe something other than a racing lap.
enum UsageExclusion {
  /// Starts in the garage: its figure includes the pit exit (§5.2).
  outLap('out lap'),

  /// Part of the lap was spent in the pit lane.
  pitLane('pit lane'),

  /// The recording ended before the lap did, so its figure is partial.
  incomplete('incomplete'),

  /// The level *rose* across the lap — the car was refuelled or recharged.
  refilled('refilled'),

  /// The recording holds no samples of the channel inside the lap.
  noData('no data');

  const UsageExclusion(this.label);

  final String label;
}

/// How much of one resource one lap used.
class LapUsage {
  const LapUsage({
    required this.lap,
    required this.used,
    required this.levelAtStart,
    this.exclusion,
  });

  final Lap lap;

  /// The level at this lap's first sample minus the level at the next lap's
  /// first sample — or at this lap's own last sample, when no later lap has
  /// any. Null when the lap holds no samples at all.
  final double? used;

  final double? levelAtStart;

  /// Why [used] is not counted in the average; null when it is.
  final UsageExclusion? exclusion;

  bool get representative => exclusion == null;
}

/// One consumable resource over a session — fuel, or virtual energy.
class ResourceUsage {
  const ResourceUsage({
    required this.name,
    required this.unit,
    required this.laps,
    required this.remaining,
  });

  /// Builds the per-lap usage of one channel.
  ///
  /// A lap counts toward [averagePerLap] only when its figure describes a
  /// racing lap: not the garage lap, no time in the pit lane, closed by the
  /// recording, and the level going *down*. An **invalidated** lap still
  /// counts — a track-limits penalty voids the time, not the fuel the car
  /// burnt driving it, and dropping those laps would bias the average toward
  /// the tidier ones (the Race sample invalidates two of nineteen).
  factory ResourceUsage.derive({
    required String name,
    required String unit,
    required List<Lap> laps,
    required List<LapChannelStats> stats,
    List<PitVisit> pitVisits = const [],
  }) {
    final byLap = {for (final s in stats) s.lapIndex: s};
    final usage = <LapUsage>[];
    for (var i = 0; i < laps.length; i++) {
      final lap = laps[i];
      final own = byLap[lap.index];
      if (own == null) {
        usage.add(LapUsage(
          lap: lap,
          used: null,
          levelAtStart: null,
          exclusion: UsageExclusion.noData,
        ));
        continue;
      }
      final next = i + 1 < laps.length ? byLap[laps[i + 1].index] : null;
      final used = own.first - (next?.first ?? own.last);
      usage.add(LapUsage(
        lap: lap,
        used: used,
        levelAtStart: own.first,
        exclusion: lap.isOutLap
            ? UsageExclusion.outLap
            : lap.isOpenEnded
                ? UsageExclusion.incomplete
                : pitVisits.any((visit) => visit.overlaps(lap))
                    ? UsageExclusion.pitLane
                    : used <= 0
                        ? UsageExclusion.refilled
                        : null,
      ));
    }
    return ResourceUsage(
      name: name,
      unit: unit,
      laps: usage,
      // The recording's final sample: stats arrive in lap order, and the last
      // lap holding samples holds the last one.
      remaining: stats.isEmpty ? null : stats.last.last,
    );
  }

  final String name;
  final String unit;
  final List<LapUsage> laps;

  /// The level at the end of the recording.
  final double? remaining;

  List<LapUsage> get representative =>
      [for (final lap in laps) if (lap.representative) lap];

  /// Mean of the representative laps, or null when there are none.
  double? get averagePerLap {
    final counted = representative;
    if (counted.isEmpty) return null;
    return counted.fold<double>(0, (sum, lap) => sum + lap.used!) /
        counted.length;
  }

  /// How many more laps [remaining] lasts at [averagePerLap] — the stint
  /// estimate §8.7 asks for.
  double? get lapsRemaining {
    final average = averagePerLap;
    final left = remaining;
    if (average == null || average <= 0 || left == null) return null;
    return left / average;
  }
}

/// Everything the fuel view shows for one session.
class FuelEnergyReport {
  const FuelEnergyReport({
    required this.carClass,
    required this.fuel,
    required this.energy,
    required this.stateOfCharge,
    required this.pitVisits,
  });

  final String carClass;

  /// Null when the file carries no usable fuel channel.
  final ResourceUsage? fuel;

  /// Null when the file carries no usable virtual-energy channel.
  final ResourceUsage? energy;

  /// Per-lap state of charge — Hypercar only, and only when it varies.
  final List<LapChannelStats>? stateOfCharge;

  final List<PitVisit> pitVisits;

  /// Whichever of fuel and virtual energy runs out first at its own average
  /// rate — the one that decides the stint. Null when neither can be
  /// estimated.
  ResourceUsage? get limiting {
    final candidates = [
      for (final resource in [fuel, energy])
        if (resource?.lapsRemaining != null) resource!,
    ];
    if (candidates.isEmpty) return null;
    return candidates.reduce(
        (a, b) => a.lapsRemaining! <= b.lapsRemaining! ? a : b);
  }
}

/// A channel that holds one value across the whole session is absent, not
/// empty (§5.4) — `SoC` in a GT3 file is 0.0 in every row.
bool _isFlat(List<LapChannelStats> stats) =>
    stats.every((s) => s.min == stats.first.min && s.max == stats.first.min);

/// See `providers.dart`: every failure this layer produces is deterministic,
/// so retrying one on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<FuelEnergyReport> fuelEnergyReport(
  Ref ref,
  TelemetrySource source,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  final pitVisits = catalog.hasEvent(inPitsEventName)
      ? pitVisitsFrom(await telemetry.readEventWindow(
          inPitsEventName,
          startSeconds: catalog.origin,
          endSeconds: catalog.endSeconds + 1,
        ))
      : const <PitVisit>[];

  Future<List<LapChannelStats>?> statsOf(String name) async {
    if (!catalog.hasChannel(name)) return null;
    final stats = await telemetry.readLapStats(name);
    return stats.isEmpty || _isFlat(stats) ? null : stats;
  }

  Future<ResourceUsage?> usageOf(String channelName, String name) async {
    final stats = await statsOf(channelName);
    if (stats == null) return null;
    return ResourceUsage.derive(
      name: name,
      unit: catalog.channel(channelName)!.unit,
      laps: laps,
      stats: stats,
      pitVisits: pitVisits,
    );
  }

  return FuelEnergyReport(
    carClass: metadata.carClass,
    fuel: await usageOf(fuelLevelChannelName, 'Fuel'),
    energy: await usageOf(virtualEnergyChannelName, 'Virtual energy'),
    stateOfCharge: metadata.carClass == hypercarClass
        ? await statsOf(stateOfChargeChannelName)
        : null,
    pitVisits: pitVisits,
  );
}
