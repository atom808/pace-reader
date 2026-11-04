/// One lap's per-corner channels — tyres and brakes — read when a dock tab
/// first needs them (map stage proposal §6.1, §10).
///
/// Separate from `lapTelemetry` on purpose: the Inputs tab is what most laps
/// are opened for, and seven four-column channels would double what every
/// lap reads for a tab that may never be opened. Disposed with the tab.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channels.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_channels.dart';
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
  final read = await readLapChannels(ref, source, lapIndex, cornerChannelNames);
  if (read.isEmpty && read.flat.isEmpty) return LapCornerTelemetry.empty;
  final at = (await lapReadWindow(ref, source, lapIndex))!;
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  return LapCornerTelemetry(
    channels: read.corners,
    flat: read.flat,
    brakeBiasRear: catalog.hasEvent(Events.brakeBiasRear)
        ? await at.telemetry.readEventWindow(
            Events.brakeBiasRear,
            startSeconds: at.window.startSeconds,
            endSeconds: at.window.endSeconds,
          )
        : null,
  );
}
