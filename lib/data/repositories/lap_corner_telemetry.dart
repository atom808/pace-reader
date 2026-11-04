/// One lap's per-corner channels — tyres and brakes — read when a dock tab
/// first needs them (map stage proposal §6.1, §10).
///
/// Separate from `lapTelemetry` on purpose: the Inputs tab is what most laps
/// are opened for, and seven four-column channels would double what every
/// lap reads for a tab that may never be opened. Disposed with the tab.
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channels.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'providers.dart';

/// The per-corner channels the Tyres and Brakes tabs draw.
const cornerChannelNames = [
  Channels.tyresPressure,
  Channels.tyresTempLeft,
  Channels.tyresTempCentre,
  Channels.tyresTempRight,
  Channels.tyresCarcassTemp,
  Channels.tyresRimTemp,
  Channels.brakesTemp,
];

/// One lap of the per-corner channels, each split into its four corners.
class LapCornerTelemetry {
  const LapCornerTelemetry({
    required this.channels,
    this.brakeBiasRear,
    this.flat = const {},
  });

  /// Channel name → corner → series. A channel the file lacks, or one that
  /// holds one value all lap on every corner, has no entry.
  final Map<String, Map<Corner, TraceSeries>> channels;

  /// `Brake Bias Rear` over the lap: the rear share, written on change.
  final StepSeries? brakeBiasRear;

  /// Channels the file carries but that never moved this lap — an all-zero
  /// `TyresRimTemp`, say — so they are said to be absent, not drawn flat.
  final Set<String> flat;

  Map<Corner, TraceSeries>? operator [](String channel) => channels[channel];

  static const empty = LapCornerTelemetry(channels: {});
}

Duration? _neverRetry(int retryCount, Object error) => null;

final lapCornerTelemetryProvider = FutureProvider.autoDispose
    .family<LapCornerTelemetry, (TelemetrySource, int)>(
      (ref, key) => _read(ref, key.$1, key.$2),
      retry: _neverRetry,
    );

Future<LapCornerTelemetry> _read(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final lap = laps.where((l) => l.index == lapIndex).firstOrNull;
  if (lap == null) return LapCornerTelemetry.empty;
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  // The same window `lapTelemetry` reads, so a corner's trace and the
  // Inputs panels share their first and last sample.
  final start = lap.startSeconds;
  final end = math.max(lap.endSeconds ?? catalog.endSeconds, start + 1);
  final window = TraceWindow.forLap(startSeconds: start, endSeconds: end);

  final channels = <String, Map<Corner, TraceSeries>>{};
  final flat = <String>{};
  for (final name in cornerChannelNames) {
    if (!catalog.hasChannel(name)) continue;
    final series = await telemetry.readTrace(name, window: window);
    final byCorner = <Corner, TraceSeries>{};
    for (final corner in Corner.values) {
      final s = series.where((s) => s.valueColumn == corner.valueColumn);
      if (s.isNotEmpty) byCorner[corner] = s.first;
    }
    if (byCorner.length != Corner.values.length) continue;
    if (byCorner.values.every((s) => s.isDegenerate)) {
      flat.add(name);
      continue;
    }
    channels[name] = byCorner;
  }

  return LapCornerTelemetry(
    channels: channels,
    flat: flat,
    brakeBiasRear: catalog.hasEvent(Events.brakeBiasRear)
        ? await telemetry.readEventWindow(
            Events.brakeBiasRear,
            startSeconds: start,
            endSeconds: end,
          )
        : null,
  );
}
