// Shared scaffolding for Compare's tests (comparison proposal §10, step 3).
//
// Not a test itself (no `_test` suffix). It serves the two real 5 Hz Sebring
// fixture laps — lap 2 (index 1, 1:04.497) and lap 4 (index 3, 1:04.030) —
// from as many "files" as a test needs, each a path of its own. Two paths are
// two files to every gate, which is how a plain `flutter test`, with no
// DuckDB, fires the cross-file checks: copies offset in `Lap Dist`, shifted
// in time, or claiming a longer lap.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_speed.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/driver_comparison/application/compare_laps.dart';
import 'package:pace_reader/features/lap_analysis/application/lap_incidents.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/features/session_library/application/session_library.dart';
import 'package:pace_reader/features/session_library/data/library_entry.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

export '../fixtures/sebring_course.dart';

import '../fixtures/sample_sessions.dart';
import '../fixtures/sebring_course.dart';
import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

/// The recording's first lap, which neither fixture lap is: Compare never
/// selects it, and it never re-anchors.
Lap sebringLap0() => const Lap(
  index: 0,
  startSeconds: 23.5975,
  endSeconds: sebringLapStartSeconds,
  lapTimeSeconds: 71.24098205566406,
  sectors: SectorTimes(),
);

/// One "file" serving the fixture laps.
class CompareFile {
  CompareFile(
    this.path, {
    this.metadata = sebringMetadata,
    CourseFacts course = sebringCourse,
    this.distanceOffset = 0,
    this.stationOffset = 0,
    this.timeShift = 0,
    this.clockGaps = const [],
    this.withoutSplits = false,
    this.contact = true,
    this.stalledLap,
    this.northMetres = 0,
    this.sideways,
    this.trackEdgeShift = 0,
    this.withoutPathLateral = false,
  }) : course = _shiftedCourse(
         course,
         distanceOffset + stationOffset,
         timeShift,
       );

  final String path;
  final SessionMetadata metadata;
  final CourseFacts course;

  /// Metres added to every `Lap Dist` sample and to both sector stations: a
  /// recording whose distance origin sits further along the lap. Its timing
  /// line, derived from the wrap length, does not move with it — so the
  /// delta check catches the shift at the line.
  final double distanceOffset;

  /// Metres added to both sector stations, with the game's S1 and S1+S2
  /// moved by the time the lap took over them: the same `Lap Dist`, but
  /// sector lines crossed further on — what an angled timing line does to a
  /// different racing line (Road Atlanta's S1, up to 4 m late at 4 m left).
  /// Only the alignment gate can see it.
  final double stationOffset;

  /// Seconds added to every timestamp: the same laps, recorded later.
  final double timeShift;

  final List<ClockGap> clockGaps;

  /// Lap 2 with its S1 and S2 splits as the game writes an untimed split:
  /// 0.0, read as null.
  final bool withoutSplits;

  /// Whether lap 2 keeps the fixture's contact (see [incidents]).
  final bool contact;

  /// A lap whose Ground Speed sits at 5 km/h for 2 s mid-lap, as the
  /// detector reads it: a stall.
  final int? stalledLap;

  /// Metres added northward to every GPS sample: the whole course drawn
  /// somewhere else, which moves its reconstructed centre path with it.
  final double northMetres;

  /// `(from, to, metres)`: GPS displaced that far to the right of the car's
  /// heading wherever `Lap Dist` is in [from, to) — a course that keeps its
  /// length but bends differently over one stretch (comparison proposal §4,
  /// D2).
  final (double, double, double)? sideways;

  /// Metres added to the magnitude of every `Track Edge` sample: edges a
  /// game update moved.
  final double trackEdgeShift;

  /// A recording without `Path Lateral`, so its centre line cannot be
  /// rebuilt.
  final bool withoutPathLateral;

  TelemetrySource get source => TelemetrySource.path(path);

  List<Lap> get laps => [
    _shiftLap(sebringLap0()),
    _shiftLap(_lap1(sebringLap())),
    _shiftLap(_lap3(sebringLap3())),
  ];

  LapTelemetry telemetry(int index) => switch (index) {
    sebringLapIndex => _shiftTelemetry(sebringLapTelemetry(), _lap1),
    sebringLap3Index => _shiftTelemetry(sebringLap3Telemetry(), _lap3),
    _ => throw StateError('the fixture has no telemetry for lap $index'),
  };

  /// Ground Speed and `Lap Dist` of [index], as the segment detector reads
  /// them: the fixture's 5 Hz samples.
  LapSpeed speed(int index) {
    final lap = laps.firstWhere((l) => l.index == index);
    if (index != sebringLapIndex && index != sebringLap3Index) {
      return LapSpeed(lap: lap);
    }
    final t = telemetry(index);
    final speed = t.channels[groundSpeedChannelName]!;
    return LapSpeed(
      lap: lap,
      speed: index != stalledLap ? speed : _stalled(speed),
      lapDistance: t.lapDistance,
    );
  }

  static TraceSeries _stalled(TraceSeries speed) {
    final mid = speed.times[speed.length ~/ 2];
    final values = Float64List.fromList([
      for (var i = 0; i < speed.length; i++)
        (speed.times[i] - mid).abs() <= 1 ? 5.0 : speed.lows[i],
    ]);
    return TraceSeries(
      channelName: speed.channelName,
      unit: speed.unit,
      frequencyHz: speed.frequencyHz,
      valueColumn: speed.valueColumn,
      times: speed.times,
      lows: values,
      highs: values,
    );
  }

  /// The fixture's one recorded contact: lap 2 (index 1), at 213.8 s, 854 m
  /// into the lap. It makes that lap unclean, so never canonical.
  SessionIncidents get incidents => SessionIncidents(
    byLap: {
      if (contact)
        sebringLapIndex: LapIncidents(
          lapIndex: sebringLapIndex,
          impactSeconds: [sebringContactSeconds + timeShift],
        ),
    },
  );

  Lap _lap1(Lap lap) => _splits(_stationSplits(lap, sebringLapTelemetry()));

  Lap _lap3(Lap lap) => _stationSplits(lap, sebringLap3Telemetry());

  /// [lap]'s splits as the game would time sector lines [stationOffset]
  /// further on.
  Lap _stationSplits(Lap lap, LapTelemetry t) {
    if (stationOffset == 0) return lap;
    final axis = DistanceAxis.fromSeries(t.lapDistance!);
    double later(double station) =>
        axis.firstReachTime(station + stationOffset)! -
        axis.firstReachTime(station)!;
    final s1 = lap.sectors.sector1Seconds!;
    final s2 = s1 + lap.sectors.sector2Seconds!;
    return lap.copyWith(
      sectors: SectorTimes.fromCumulative(
        sector1: s1 + later(sebringCourse.sector1Station!),
        sector2Cumulative: s2 + later(sebringCourse.sector2Station!),
        lapTimeSeconds: lap.lapTimeSeconds,
      ),
    );
  }

  ComparableFile get comparable => ComparableFile(
    metadata: metadata,
    laps: laps,
    course: course,
    clockGaps: clockGaps,
  );

  Lap _splits(Lap lap) => !withoutSplits
      ? lap
      : lap.copyWith(
          sectors: SectorTimes.fromCumulative(
            sector1: 0.0,
            sector2Cumulative: 0.0,
            lapTimeSeconds: lap.lapTimeSeconds,
          ),
        );

  Lap _shiftLap(Lap lap) => lap.copyWith(
    startSeconds: lap.startSeconds + timeShift,
    endSeconds: lap.endSeconds == null ? null : lap.endSeconds! + timeShift,
  );

  LapTelemetry _shiftTelemetry(LapTelemetry t, Lap Function(Lap) laps) {
    TraceSeries? series(TraceSeries? s, {double add = 0}) => s == null
        ? null
        : TraceSeries(
            channelName: s.channelName,
            unit: s.unit,
            frequencyHz: s.frequencyHz,
            valueColumn: s.valueColumn,
            times: _plus(s.times, timeShift),
            lows: _plus(s.lows, add),
            highs: _plus(s.highs, add),
          );
    final gear = t.gear;
    final position = _position(t);
    return LapTelemetry(
      lap: _shiftLap(laps(t.lap)),
      startSeconds: t.startSeconds + timeShift,
      endSeconds: t.endSeconds + timeShift,
      channels: {
        for (final MapEntry(:key, :value) in t.channels.entries)
          key: series(value)!,
      },
      gear: gear == null
          ? null
          : StepSeries(
              eventName: gear.eventName,
              unit: gear.unit,
              times: _plus(gear.times, timeShift),
              values: gear.values,
            ),
      lapDistance: series(t.lapDistance, add: distanceOffset),
      latitude: _withValues(series(t.latitude), position?.$1),
      longitude: _withValues(series(t.longitude), position?.$2),
      pathLateral: withoutPathLateral ? null : series(t.pathLateral),
      trackEdge: _withValues(
        series(t.trackEdge),
        trackEdgeShift == 0
            ? null
            : Float64List.fromList([
                for (final v in t.trackEdge!.lows) v + v.sign * trackEdgeShift,
              ]),
      ),
      sectorBoundaries: [
        for (final (at, sector) in t.sectorBoundaries) (at + timeShift, sector),
      ],
    );
  }
}

extension on CompareFile {
  /// [t]'s GPS moved as [CompareFile.northMetres] and
  /// [CompareFile.sideways] say; null when it is left as recorded.
  (Float64List, Float64List)? _position(LapTelemetry t) {
    final latitude = t.latitude;
    final longitude = t.longitude;
    final distance = t.lapDistance;
    if (latitude == null || longitude == null || distance == null) return null;
    if (northMetres == 0 && sideways == null) return null;
    const perDegree = 111320.0;
    final lat = Float64List.fromList(latitude.lows);
    final lon = Float64List.fromList(longitude.lows);
    final lonScale = perDegree * math.cos(lat.first * math.pi / 180);
    for (var i = 0; i < lat.length; i++) {
      lat[i] += northMetres / perDegree;
    }
    if (sideways case (final from, final to, final metres)) {
      final n = lat.length;
      final east = [for (var i = 0; i < n; i++) longitude.lows[i] * lonScale];
      final north = [for (var i = 0; i < n; i++) latitude.lows[i] * perDegree];
      for (var i = 0; i < n; i++) {
        final d = distance.lows[i] + distanceOffset;
        if (d < from || d >= to) continue;
        final a = math.max(i - 1, 0);
        final b = math.min(i + 1, n - 1);
        final dx = east[b] - east[a];
        final dy = north[b] - north[a];
        final length = math.sqrt(dx * dx + dy * dy);
        if (length == 0) continue;
        // The right-hand normal: the heading turned a quarter clockwise.
        lon[i] += dy / length * metres / lonScale;
        lat[i] += -dx / length * metres / perDegree;
      }
    }
    return (lat, lon);
  }
}

TraceSeries? _withValues(TraceSeries? s, Float64List? values) =>
    s == null || values == null
    ? s
    : TraceSeries(
        channelName: s.channelName,
        unit: s.unit,
        frequencyHz: s.frequencyHz,
        valueColumn: s.valueColumn,
        times: s.times,
        lows: values,
        highs: values,
      );

CourseFacts _shiftedCourse(
  CourseFacts c,
  double metres,
  double seconds,
) => CourseFacts(
  wrapLength: c.wrapLength,
  wrapCount: c.wrapCount,
  sector1Station: c.sector1Station == null ? null : c.sector1Station! + metres,
  sector2Station: c.sector2Station == null ? null : c.sector2Station! + metres,
  pitLane: [
    for (final p in c.pitLane)
      PitInterval(
        p.startSeconds + seconds,
        p.endSeconds == null ? null : p.endSeconds! + seconds,
      ),
  ],
);

Float64List _plus(Float64List values, double add) =>
    add == 0 ? values : Float64List.fromList([for (final v in values) v + add]);

/// When the fixture recording's contact registered (`LastImpactMagnitude`).
const sebringContactSeconds = 213.8;

/// Every lap read, as `(path, lap index)`, in order.
typedef LapReadLog = List<(String, int)>;

/// Serves [files] wherever the open-session providers would read them, and
/// logs each `lapTelemetry` read into [reads] and each segment-detector
/// speed read into [speedReads].
List<Override> compareFileOverrides(
  Iterable<CompareFile> files, {
  LapReadLog? reads,
  LapReadLog? speedReads,
}) => [
  for (final f in files) ...[
    sessionMetadataProvider(f.source).overrideWith((ref) async => f.metadata),
    lapsProvider(f.source).overrideWith((ref) async => f.laps),
    courseFactsProvider(f.source).overrideWith((ref) async => f.course),
    sessionClockGapsProvider(f.source).overrideWith((ref) async => f.clockGaps),
    for (final index in [sebringLapIndex, sebringLap3Index])
      lapTelemetryProvider(f.source, index).overrideWith((ref) async {
        reads?.add((f.path, index));
        return f.telemetry(index);
      }),
    for (final index in [sebringLapIndex, sebringLap3Index])
      lapSpeedProvider(f.source, index).overrideWith((ref) async {
        speedReads?.add((f.path, index));
        return f.speed(index);
      }),
    sessionIncidentsProvider(f.source).overrideWith((ref) async => f.incidents),
  ],
];

class FixedOpenSessions extends OpenSessions {
  FixedOpenSessions(this.initial);

  final List<TelemetrySource> initial;

  @override
  List<TelemetrySource> build() => initial;
}

class FixedLibrary extends SessionLibrary {
  FixedLibrary(this.entries);

  final List<LibraryEntry> entries;

  @override
  Future<List<LibraryEntry>> build() async => entries;
}

/// A brief reader serving [files] by path, logging each read into [log].
ComparableFactsReader briefReaderFor(
  Iterable<CompareFile> files, {
  List<String>? log,
}) {
  final byPath = {for (final f in files) f.source: f};
  return (source) async {
    log?.add((source as FileTelemetrySource).path);
    final file = byPath[source];
    if (file == null) throw StateError('no such file: $source');
    return file.comparable;
  };
}

/// Everything a Compare screen over [files] needs: the files served, Open
/// now holding [open] (the first is current), and [library] as the index.
List<Override> compareOverrides({
  required List<CompareFile> files,
  required List<CompareFile> open,
  List<LibraryEntry> library = const [],
  LapReadLog? reads,
  LapReadLog? speedReads,
  List<String>? briefReads,
}) => [
  openSessionsProvider.overrideWith(
    () => FixedOpenSessions([for (final f in open) f.source]),
  ),
  sessionLibraryProvider.overrideWith(() => FixedLibrary(library)),
  comparableFactsReaderProvider.overrideWithValue(
    briefReaderFor(files, log: briefReads),
  ),
  ...compareFileOverrides(open, reads: reads, speedReads: speedReads),
];

/// [container]'s value of [provider], waiting for it to resolve.
Future<T> readFuture<T>(
  ProviderContainer container,
  ProviderListenable<Future<T>> provider,
) async {
  final subscription = container.listen(provider, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

/// [file] as the library indexes it: its best lap is lap 4 (1:04.030).
LibraryEntry libraryEntryOf(CompareFile file) {
  final meta = file.metadata;
  return LibraryEntry(
    path: file.path,
    fileName: file.path.split('/').last,
    kind: LibrarySourceKind.file,
    sizeBytes: 1,
    modifiedMs: 1,
    trackName: meta.trackName,
    trackLayout: meta.trackLayout,
    carName: meta.carName,
    carClass: meta.carClass,
    sessionType: meta.sessionType,
    driverName: meta.driverName,
    recordingTime: meta.recordingTime,
    weather: meta.weatherConditions,
    formatVersion: meta.version,
    completedLaps: 3,
    timedLaps: 2,
    bestLapSeconds: sebringLap3TimeSeconds,
    bestLapIndex: sebringLap3Index,
    clockGapCount: file.clockGaps.length,
    importedAt: DateTime.utc(2026, 7, 7),
  );
}
