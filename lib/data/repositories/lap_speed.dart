/// One lap's Ground Speed and `Lap Dist` at the recording's own rate, for
/// the segment detector (comparison proposal §5).
///
/// Separate from `lapTelemetry`, which reads a lap for drawing: five channels
/// decimated to the screen, plus gear and position. The detector needs two
/// channels of every clean lap of a file, undecimated — the rate probe 0c
/// measured its thresholds at — and only once per course, so this is read,
/// used and dropped rather than kept.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_telemetry.dart';
import 'providers.dart';

part 'lap_speed.g.dart';

const groundSpeedChannelName = 'Ground Speed';

class LapSpeed {
  const LapSpeed({required this.lap, this.speed, this.lapDistance});

  final Lap lap;

  /// Null when the file has no such channel, or nothing in this lap.
  final TraceSeries? speed;
  final TraceSeries? lapDistance;
}

Duration? _neverRetry(int retryCount, Object error) => null;

/// [lapIndex]'s speed and distance, read at full resolution.
///
/// Not kept alive: the segment table it feeds is, and holds plain numbers.
@Riverpod(retry: _neverRetry)
Future<LapSpeed> lapSpeed(Ref ref, TelemetrySource source, int lapIndex) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final lap = laps.firstWhere(
    (l) => l.index == lapIndex,
    orElse: () => throw StateError('This session has no lap $lapIndex.'),
  );
  final end = lap.endSeconds;
  // An open lap is never a clean one, so nothing is read for it.
  if (end == null) return LapSpeed(lap: lap);

  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  Future<TraceSeries?> full(String name) async {
    if (!catalog.hasChannel(name)) return null;
    final series = await telemetry.readFullResolution(
      name,
      startSeconds: lap.startSeconds,
      endSeconds: end,
      // One lap of a 100 Hz channel, whatever its length: the cap exists to
      // stop a whole-session read reaching Dart undecimated, and a lap is
      // the unit the detector was measured on.
      maxSamples: ((end - lap.startSeconds) * 110).ceil() + 1000,
    );
    return series.length == 1 ? series.single : null;
  }

  return LapSpeed(
    lap: lap,
    speed: await full(groundSpeedChannelName),
    lapDistance: await full(lapDistanceChannelName),
  );
}
