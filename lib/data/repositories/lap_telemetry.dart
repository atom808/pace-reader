/// Everything one lap's views read, fetched once (SPEC.md §8.4, §8.5, §9.1).
///
/// Shared rather than per-feature for the reason §9.1 gives about
/// repositories generally: the trace panels and the track map are one synced
/// system (§9.5) reading the same lap, and two features fetching it
/// separately would drift — and would open the same file's channels twice
/// for one screen that shows both.
///
/// Everything here is a `data/models` type. The conversion into plots,
/// projections and paths belongs to the presentation side, so this layer
/// stays something a repository test can construct.
library;

import 'dart:math' as math;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'providers.dart';

part 'lap_telemetry.g.dart';

/// Channels the single-lap trace stack plots, in stack order (§8.4).
///
/// A feature-level choice of *what to show*, which is a different thing from
/// hardcoding the catalog: every name is looked up in `channelsList` at read
/// time and silently skipped when absent, so a future LMU version that
/// renames one loses a panel rather than failing the screen (§9.2, §10).
const traceChannelNames = [
  'Ground Speed',
  'Throttle Pos',
  'Brake Pos',
  'Steering Pos',
  'Engine RPM',
];

/// Gear is an **event**, not a channel (§5.1) — it is recorded once per
/// shift, not at a fixed rate — which is why it is read and drawn
/// differently from everything in [traceChannelNames].
const gearEventName = 'Gear';

/// Position channels for the track map (§8.5). Both are 10 Hz and ride the
/// same master grid, so sample `i` of one is the same instant as sample `i`
/// of the other.
const latitudeChannelName = 'GPS Latitude';
const longitudeChannelName = 'GPS Longitude';

/// The distance axis (§8.4's Distance/Time toggle) and the ground truth the
/// track-map projection is checked against.
const lapDistanceChannelName = 'Lap Dist';

/// One lap's telemetry, time-aligned and reduced to render scale.
class LapTelemetry {
  const LapTelemetry({
    required this.lap,
    required this.startSeconds,
    required this.endSeconds,
    required this.channels,
    required this.gear,
    required this.lapDistance,
    required this.latitude,
    required this.longitude,
    required this.sectorBoundaries,
  });

  final Lap lap;

  /// The window actually read. Not simply the lap's own boundaries: the final
  /// lap of a recording has no closing boundary (§5.2), so it is read to the
  /// end of the master clock instead of not at all.
  final double startSeconds;
  final double endSeconds;

  /// False when the recording holds nothing for this lap.
  ///
  /// Not hypothetical: in the checked-in fixture the `Lap` event opening lap 4
  /// sits at 388.9200 s while `GPS Time`'s last sample is 388.9175 s, so the
  /// lap opens 2.5 ms *after* the channels stop. A recording stopped on a
  /// start/finish crossing produces exactly this, and it has to render as an
  /// empty lap rather than as a crash or an inverted axis.
  bool get hasTelemetry => channels.isNotEmpty;

  /// Decimated series by channel name, missing an entry for any channel this
  /// file doesn't carry.
  final Map<String, TraceSeries> channels;

  final StepSeries? gear;
  final TraceSeries? lapDistance;
  final TraceSeries? latitude;
  final TraceSeries? longitude;

  /// `(seconds, sector number)` crossings inside this lap. Sector 1's
  /// crossing is the lap boundary itself, so in practice these are the S2 and
  /// S3 entries — the two lines worth drawing across the map.
  final List<(double, int)> sectorBoundaries;

  bool get hasPosition =>
      latitude != null &&
      longitude != null &&
      latitude!.isNotEmpty &&
      latitude!.length == longitude!.length;

  bool get hasDistance => lapDistance != null && lapDistance!.length >= 2;

  double get durationSeconds => endSeconds - startSeconds;
}

/// See `providers.dart`: every failure this layer produces is deterministic,
/// so retrying one on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

/// Reads one lap, in one place, for every view that shows it.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<LapTelemetry> lapTelemetry(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final lap = laps.firstWhere(
    (l) => l.index == lapIndex,
    orElse: () => throw StateError('This session has no lap $lapIndex.'),
  );

  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);
  final lapRepository = await ref.watch(lapRepositoryProvider(source).future);

  final start = lap.startSeconds;
  // An open final lap still has telemetry; it just has no closing boundary,
  // so the recording's own end stands in for one.
  //
  // Clamped to a nominal second because that substitute can land *before* the
  // lap's own start: a recording stopped on a start/finish crossing writes the
  // `Lap` event for a lap whose channels never begin, which is exactly what
  // the checked-in fixture's lap 4 is. The reads below then all come back
  // empty — the honest answer — while the window itself stays non-empty, so
  // nothing downstream has to defend against an inverted axis.
  final end = math.max(lap.endSeconds ?? catalog.endSeconds, start + 1);
  final window = TraceWindow.forLap(startSeconds: start, endSeconds: end);

  final channels = <String, TraceSeries>{};
  for (final name in traceChannelNames) {
    if (!catalog.hasChannel(name)) continue;
    final series = await telemetry.readTrace(name, window: window);
    // A per-corner channel would yield four series; nothing in the default
    // stack is one, and taking the first would silently plot only the
    // front-left, so the whole channel is skipped instead.
    if (series.length == 1) channels[name] = series.single;
  }

  Future<TraceSeries?> full(String name) async {
    if (!catalog.hasChannel(name)) return null;
    final series = await telemetry.readFullResolution(
      name,
      startSeconds: start,
      endSeconds: end,
    );
    return series.length == 1 ? series.single : null;
  }

  return LapTelemetry(
    lap: lap,
    startSeconds: start,
    endSeconds: end,
    channels: channels,
    gear: catalog.hasEvent(gearEventName)
        ? await telemetry.readEventWindow(
            gearEventName,
            startSeconds: start,
            endSeconds: end,
          )
        : null,
    // Full resolution rather than decimated: these three are 10 Hz, so a lap
    // is a few hundred samples — decimating them would cost a bucketing pass
    // to remove points a painter can draw directly, and the distance axis in
    // particular is a lookup table where every sample is a knot.
    lapDistance: await full(lapDistanceChannelName),
    latitude: await full(latitudeChannelName),
    longitude: await full(longitudeChannelName),
    sectorBoundaries: [
      for (final crossing in await lapRepository.readSectorTransitions())
        if (crossing.$1 > start && crossing.$1 < end) crossing,
    ],
  );
}
