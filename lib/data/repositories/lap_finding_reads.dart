/// One lap's brake pedal and Ground Speed at the recording's own rate, for
/// the Why card's findings (comparison proposal §9 `segment_findings.dart`).
///
/// `lapTelemetry` already holds both, decimated to 100 buckets a second and
/// capped at 6000 buckets: a 50 Hz pedal stays 1:1 only up to 120 s — the
/// Spa Qualify sample's lap 2 is already 122.7 s — and a 100 Hz speed only
/// up to 60 s. Reading them here, undecimated, keeps every sample whatever
/// the lap's length: an onset found between two buckets would move by a
/// bucket's metres.
///
/// Separate from `lapSpeed`, which the segment detector reads for every
/// clean lap of a file once per course; this is read for the two compared
/// laps, once per pair.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_speed.dart';
import 'providers.dart';

part 'lap_finding_reads.g.dart';

const brakePedalChannelName = 'Brake Pos';

class LapFindingReads {
  const LapFindingReads({required this.lap, this.brake, this.speed});

  final Lap lap;

  /// Null when the file has no such channel, or nothing in this lap.
  final TraceSeries? brake;
  final TraceSeries? speed;
}

Duration? _neverRetry(int retryCount, Object error) => null;

/// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
///
/// Not kept alive: the findings it feeds are re-derived only with the pair.
@Riverpod(retry: _neverRetry)
Future<LapFindingReads> lapFindingReads(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final lap = laps.firstWhere(
    (l) => l.index == lapIndex,
    orElse: () => throw StateError('This session has no lap $lapIndex.'),
  );
  final end = lap.endSeconds;
  // An open lap has no closing line, so no corner of it is compared.
  if (end == null) return LapFindingReads(lap: lap);

  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  Future<TraceSeries?> full(String name) async {
    if (!catalog.hasChannel(name)) return null;
    final series = await telemetry.readFullResolution(
      name,
      startSeconds: lap.startSeconds,
      endSeconds: end,
      // One lap, whatever its length, as `lapSpeed` reads it.
      maxSamples: ((end - lap.startSeconds) * 110).ceil() + 1000,
    );
    return series.length == 1 ? series.single : null;
  }

  return LapFindingReads(
    lap: lap,
    brake: await full(brakePedalChannelName),
    speed: await full(groundSpeedChannelName),
  );
}
