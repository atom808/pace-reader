/// One lap's channels for a dock tab, read when the tab first needs them
/// (map stage proposal §6.1, §10).
///
/// Separate from `lapTelemetry` on purpose: the Inputs tab is what most laps
/// are opened for, and every other tab's channels would add to what each lap
/// reads for a tab that may never be opened. Disposed with the tab.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channels.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'providers.dart';
import 'telemetry_repository.dart';

/// The channels one dock tab reads together.
enum LapChannelSet {
  /// Ride height front and rear, each damper's travel, and the third
  /// elements' deflection (§6.1 tab 4).
  suspension([
    Channels.frontRideHeight,
    Channels.rearRideHeight,
    Channels.suspPos,
    Channels.front3rdDeflection,
    Channels.rear3rdDeflection,
  ]),

  /// The three G axes and the line across the track (§6.1 tab 5).
  dynamics([
    Channels.gForceLong,
    Channels.gForceLat,
    Channels.gForceVert,
    Channels.pathLateral,
  ]),

  /// The hybrid's charge and its flow, the virtual energy and the fuel
  /// (§6.1 tab 6).
  energy([
    Channels.soc,
    Channels.regenRate,
    Channels.virtualEnergy,
    Channels.fuelLevel,
  ]);

  const LapChannelSet(this.channels);

  final List<String> channels;
}

/// One lap of some channels: the one-value ones by name, the per-corner
/// ones split into their corners.
class LapChannels {
  const LapChannels({
    this.single = const {},
    this.corners = const {},
    this.flat = const {},
  });

  /// Channel name → series, for a channel with one value a sample.
  final Map<String, TraceSeries> single;

  /// Channel name → corner → series, for one with a value per wheel.
  final Map<String, Map<Corner, TraceSeries>> corners;

  /// Channels the file carries but that never moved this lap — an all-zero
  /// `SoC` in a car without a hybrid — so they are said to be absent, not
  /// drawn flat (§5.4).
  final Set<String> flat;

  bool get isEmpty => single.isEmpty && corners.isEmpty;

  static const empty = LapChannels();
}

/// The lap's window, as `lapTelemetry` reads it, so every tab's traces share
/// their first and last sample with the Inputs panels; null for a lap the
/// recording does not hold.
Future<({Lap lap, TraceWindow window, TelemetryRepository telemetry})?>
lapReadWindow(Ref ref, TelemetrySource source, int lapIndex) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final lap = laps.where((l) => l.index == lapIndex).firstOrNull;
  if (lap == null) return null;
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);
  final start = lap.startSeconds;
  final end = math.max(lap.endSeconds ?? catalog.endSeconds, start + 1);
  return (
    lap: lap,
    window: TraceWindow.forLap(startSeconds: start, endSeconds: end),
    telemetry: telemetry,
  );
}

/// [names] over [source]'s lap [lapIndex]: each channel the file carries,
/// as one series or four, the ones that never moved set aside.
Future<LapChannels> readLapChannels(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
  List<String> names,
) async {
  final at = await lapReadWindow(ref, source, lapIndex);
  if (at == null) return LapChannels.empty;
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final single = <String, TraceSeries>{};
  final corners = <String, Map<Corner, TraceSeries>>{};
  final flat = <String>{};
  for (final name in names) {
    if (!catalog.hasChannel(name)) continue;
    final series = await at.telemetry.readTrace(name, window: at.window);
    if (series.isEmpty) continue;
    if (series.every((s) => s.isDegenerate)) {
      flat.add(name);
      continue;
    }
    if (series.length == 1) {
      single[name] = series.single;
      continue;
    }
    final byCorner = <Corner, TraceSeries>{};
    for (final corner in Corner.values) {
      final s = series.where((s) => s.valueColumn == corner.valueColumn);
      if (s.isNotEmpty) byCorner[corner] = s.first;
    }
    if (byCorner.length == Corner.values.length) corners[name] = byCorner;
  }
  return LapChannels(single: single, corners: corners, flat: flat);
}

Duration? _neverRetry(int retryCount, Object error) => null;

/// [LapChannelSet]'s channels over one lap: `(source, Lap.index, set)`.
final lapChannelsProvider = FutureProvider.autoDispose
    .family<LapChannels, (TelemetrySource, int, LapChannelSet)>(
      (ref, key) => readLapChannels(ref, key.$1, key.$2, key.$3.channels),
      retry: _neverRetry,
    );
