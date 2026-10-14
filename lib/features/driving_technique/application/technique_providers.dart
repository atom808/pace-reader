/// Driving Technique's providers (SPEC.md §8.13.9), keyed by
/// [TelemetrySource] and loaded in the order the screen reads:
///
/// 1. [techniqueSessionProvider] — which laps are racing laps, the steering
///    unit, the car's limiter and ABS. Cheap.
/// 2. [techniqueOverviewProvider] — every per-lap measure, the G-G envelope
///    and grid, the shifts and the caught slides: the header, the cards, the
///    G-G, the shift panel and the trends.
/// 3. [techniqueCourseProvider] — the segment table (Compare's, from its
///    store, or detected here when the course has none), the corner table,
///    the map path and each lap's segment times.
/// 4. [techniquePlacementProvider] — the pedal and G frames totalled per
///    segment and corner.
/// 5. [techniqueLensProvider] — each lap's conditions and the lens options.
///
/// Each later one needs the earlier, and the screen shows each part as it
/// lands rather than waiting for the slowest: on Imola's 127-lap, 300 MB race
/// the overview's queries take about 2 s and the course another second.
library;

import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/technique_queries.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../../data/repositories/lap_speed.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../driver_comparison/application/lap_conditions.dart';
import '../../driver_comparison/application/segment_tables.dart';
import '../../driver_comparison/domain/lap_conditions.dart';
import '../../driver_comparison/domain/segments.dart';
import '../../lap_analysis/application/lap_incidents.dart';
import '../../setup_viewer/application/car_setup.dart';
import '../../setup_viewer/application/car_setup_provider.dart';
import '../data/technique_reads.dart';
import '../data/technique_repository.dart';
import '../domain/conditions_lens.dart';
import '../domain/corner_table.dart';
import '../domain/countersteer.dart';
import '../domain/geometric_corners.dart';
import '../domain/lap_technique.dart';
import '../domain/pedal_spans.dart';
import '../domain/racing_laps.dart';
import '../domain/segment_times.dart';
import '../domain/shifts.dart';
import '../domain/steering.dart';
import '../domain/technique_thresholds.dart';

part 'technique_providers.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// The repository for [source].
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniqueRepository> techniqueRepository(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return TechniqueRepository(session.database, session.catalog);
}

/// The facts every part of the screen starts from.
class TechniqueSession {
  const TechniqueSession({
    required this.metadata,
    required this.laps,
    required this.racing,
    required this.excluded,
    required this.steeringScale,
    required this.hasPedals,
    this.revLimiter,
    this.steerLock,
    this.hasAbs = false,
  });

  final SessionMetadata metadata;

  /// Every lap of the file.
  final List<Lap> laps;

  /// The racing laps (§8.13.2), in order.
  final List<Lap> racing;

  /// Why each other lap is not one.
  final Map<int, NotRacing> excluded;

  /// The factor putting `Steering Pos` in percent: 100 for a file from before
  /// April 2026, 1 after.
  final double steeringScale;

  /// False when the file lacks the pedal channels: nothing can be measured.
  final bool hasPedals;

  /// `VM_REV_LIMITER`, rpm.
  final double? revLimiter;
  final ({double wheel, double? frontWheels})? steerLock;

  /// Whether the setup has ABS: ABS appears only then (§8.13.7).
  final bool hasAbs;

  List<LapSpan> get spans => [
    for (final l in racing)
      (lap: l.index, start: l.startSeconds, end: l.endSeconds!),
  ];
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniqueSession> techniqueSession(
  Ref ref,
  TelemetrySource source,
) async {
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final laps = await ref.watch(lapsProvider(source).future);
  final course = await ref.watch(courseFactsProvider(source).future);
  final repo = await ref.watch(techniqueRepositoryProvider(source).future);
  final limiter = pitIntervalsFrom(await repo.readFlag(techniqueLimiterEvent));
  final excluded = <int, NotRacing>{};
  final racing = <Lap>[];
  for (final lap in laps) {
    final why = whyNotRacing(lap, pitLane: course.pitLane, limiter: limiter);
    if (why == null) {
      racing.add(lap);
    } else {
      excluded[lap.index] = why;
    }
  }
  CarSetup? setup;
  try {
    setup = await ref.watch(carSetupProvider(source).future);
  } on SetupFormatException {
    setup = null;
  }
  final hasPedals = repo.channels != null;
  return TechniqueSession(
    metadata: metadata,
    laps: laps,
    racing: hasPedals ? racing : const [],
    excluded: excluded,
    steeringScale: steeringScale(await repo.readSteeringMaxAbs()),
    hasPedals: hasPedals,
    revLimiter: setup?.revLimiter,
    steerLock: setup?.steerLock,
    hasAbs: setup?.hasAbs ?? false,
  );
}

/// Everything per lap, and the session's G-G.
class TechniqueOverview {
  const TechniqueOverview({
    required this.session,
    required this.laps,
    required this.upshifts,
    required this.countersteer,
    this.gg,
  });

  final TechniqueSession session;

  /// Keyed by `Lap.index`, racing laps only.
  final Map<int, LapTechnique> laps;
  final GgReads? gg;

  /// Every upshift on a racing lap.
  final List<Upshift> upshifts;
  final List<CountersteerEpisode> countersteer;

  List<LapTechnique> get ordered => [
    for (final lap in session.racing) ?laps[lap.index],
  ];

  /// [measure]'s median over the racing laps.
  double? median(TechniqueMeasure measure) =>
      medianOf([for (final t in laps.values) ?measure.of(t)]);

  /// [measure]'s lowest and highest lap.
  ({double min, double max})? range(TechniqueMeasure measure) {
    final values = [for (final t in laps.values) ?measure.of(t)];
    if (values.isEmpty) return null;
    var lo = values.first;
    var hi = values.first;
    for (final v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    return (min: lo, max: hi);
  }

  /// [measure]'s Spearman correlation with lap time in this session.
  double? correlation(TechniqueMeasure measure) {
    final a = <double>[];
    final b = <double>[];
    for (final t in laps.values) {
      final v = measure.of(t);
      if (v == null) continue;
      a.add(v);
      b.add(t.lapTime);
    }
    return spearman(a, b);
  }

  /// The fastest racing lap.
  LapTechnique? get fastest => laps.values.isEmpty
      ? null
      : laps.values.reduce((a, b) => b.lapTime < a.lapTime ? b : a);
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniqueOverview> techniqueOverview(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  final repo = await ref.watch(techniqueRepositoryProvider(source).future);
  final spans = session.spans;
  if (spans.isEmpty) {
    return TechniqueOverview(
      session: session,
      laps: const {},
      upshifts: const [],
      countersteer: const [],
    );
  }
  final scale = session.steeringScale;
  final pedals = await repo.readPedalStats(spans, steeringScale: scale);
  final runs = await repo.readPedalRuns(spans, steeringScale: scale);
  final tcEpisodes = await repo.readAidEpisodes(techniqueTcEvent, spans);
  final absEpisodes = session.hasAbs
      ? await repo.readAidEpisodes(techniqueAbsEvent, spans)
      : const <int, int>{};
  final gg = await repo.readGg(spans);
  final shifts = shiftsFrom(await repo.readGearRows());
  final reads = {
    for (final r in await repo.readUpshifts(limiter: session.revLimiter))
      r.seconds: r,
  };
  final episodes = countersteerEpisodes(
    await repo.readCountersteerSamples(spans, steeringScale: scale),
  );

  int? lapOf(double seconds) {
    for (final l in session.racing) {
      if (seconds >= l.startSeconds && seconds < l.endSeconds!) return l.index;
    }
    return null;
  }

  final upshifts = <Upshift>[];
  final ups = <int, int>{};
  final downs = <int, int>{};
  for (final shift in shifts) {
    final lap = lapOf(shift.seconds);
    if (lap == null) continue;
    if (shift.isUp) {
      ups[lap] = (ups[lap] ?? 0) + 1;
      final read = reads[shift.seconds];
      final rpm = read?.rpm;
      final limiter = session.revLimiter;
      upshifts.add(
        Upshift(
          lap: lap,
          shift: shift,
          read: read,
          band: rpm == null || limiter == null
              ? null
              : ShiftBand.of(rpm, limiter),
        ),
      );
    } else {
      downs[lap] = (downs[lap] ?? 0) + 1;
    }
  }

  final laps = <int, LapTechnique>{};
  for (final lap in session.racing) {
    final totals = pedals.laps[lap.index];
    if (totals == null) continue;
    laps[lap.index] = LapTechnique(
      lap: lap,
      pedals: totals,
      spans: classifySpans(runs[lap.index] ?? const []),
      tcEpisodes: tcEpisodes[lap.index] ?? 0,
      absEpisodes: absEpisodes[lap.index] ?? 0,
      gg: gg?.laps[lap.index],
      upshifts: ups[lap.index] ?? 0,
      downshifts: downs[lap.index] ?? 0,
      countersteer: [
        for (final e in episodes)
          if (e.lap == lap.index) e,
      ],
    );
  }
  return TechniqueOverview(
    session: session,
    laps: laps,
    gg: gg,
    upshifts: upshifts,
    countersteer: episodes,
  );
}

/// Every course's corner table, held for the run next to Compare's segment
/// tables and written the same way: only by [ensure].
@Riverpod(keepAlive: true)
class CornerTableStore extends _$CornerTableStore {
  @override
  Map<TrackKey, CornerTable> build() => const {};

  CornerTable ensure(CornerTable detected) {
    final held = state[detected.key];
    if (held != null && held.fits(detected.wrapLength)) return held;
    state = {...state, detected.key: detected};
    return detected;
  }
}

/// The map's reference line: one lap's path, projected, with each point's
/// `Lap Dist`.
class TechniqueMapPath {
  const TechniqueMapPath({
    required this.points,
    required this.stations,
    required this.bounds,
  });

  /// Metres, north up (screen y down).
  final List<Offset> points;
  final Float64List stations;
  final Rect bounds;

  /// The point nearest [station].
  int indexAt(double station) {
    var lo = 0;
    var hi = stations.length - 1;
    if (hi < 0) return 0;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (stations[mid] < station) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// Where the lap is cut: segments and corners, and each lap's time per
/// segment.
class TechniqueCourse {
  const TechniqueCourse({
    this.table,
    this.corners,
    this.map,
    this.segmentTimes = const {},
    this.unavailable,
  });

  final SegmentTable? table;
  final CornerTable? corners;
  final TechniqueMapPath? map;

  /// Lap → its time in each segment, in table order.
  final Map<int, List<double>> segmentTimes;

  /// Why there are no segments, in a sentence.
  final String? unavailable;

  List<Segment> get segments => table?.segments ?? const [];

  /// [segment]'s corners, by apex.
  List<GeoCorner> cornersIn(Segment segment) =>
      corners?.inSegment(segment) ?? const [];

  /// The segment holding [corner]'s apex.
  Segment? segmentOf(GeoCorner corner) {
    for (final s in segments) {
      if (s.contains(corner.apex)) return s;
    }
    return null;
  }

  /// [segment]'s median time over the racing laps.
  double? medianTime(int segmentIndex) => medianOf([
    for (final times in segmentTimes.values)
      if (segmentIndex < times.length) times[segmentIndex],
  ]);
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniqueCourse> techniqueCourse(Ref ref, TelemetrySource source) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  if (session.racing.isEmpty) {
    return const TechniqueCourse(
      unavailable: 'No segments: the session has no racing lap to cut.',
    );
  }
  final course = await ref.watch(courseFactsProvider(source).future);
  final wrapLength = course.wrapLength;
  if (wrapLength == null) {
    return const TechniqueCourse(
      unavailable: 'No segments: the recording holds no lap length.',
    );
  }
  final repo = await ref.watch(techniqueRepositoryProvider(source).future);
  final profiles = {
    for (final p in await repo.readLapProfiles(session.spans)) p.lap: p,
  };
  if (profiles.isEmpty) {
    return const TechniqueCourse(
      unavailable:
          'No segments: the recording lacks the speed or position channels.',
    );
  }

  // Clean laps by Compare's rules, so the segment and corner tables agree
  // on which laps they come from (§8.13.9).
  final incidents = await ref.watch(sessionIncidentsProvider(source).future);
  final first = session.laps.firstOrNull?.index;
  final clean = <(Lap, LapProfileRead)>[];
  for (final lap in session.racing) {
    final profile = profiles[lap.index];
    if (profile == null) continue;
    final reason = whyNotClean(
      lap: lap,
      recordingStart: lap.index == first,
      impact: incidents.of(lap).hasImpact,
      pitLane: false,
      axis: _axisOf(profile),
      speed: _speedOf(profile),
    );
    if (reason == null) clean.add((lap, profile));
  }

  final key = TrackKey.of(session.metadata);
  // Read, not watched: issuing [SegmentTableStore.ensure] below would
  // otherwise rebuild this provider and read every profile again.
  var table = ref.read(segmentTableStoreProvider)[key];
  String? unavailable;
  if (table == null || !table.fits(wrapLength)) {
    if (clean.isEmpty) {
      unavailable =
          'No segments: no racing lap is clean enough to find the corners on '
          '(contact, a stop or an off-track jump on every one).';
      table = null;
    } else {
      final detected = await _detectSegments(
        ref,
        source,
        session,
        key,
        wrapLength,
        clean,
      );
      table = ref.read(segmentTableStoreProvider.notifier).ensure(detected);
    }
  }

  var corners = ref.read(cornerTableStoreProvider)[key];
  if ((corners == null || !corners.fits(wrapLength)) && clean.isNotEmpty) {
    final profile = medianCurvature([
      for (final (_, p) in clean)
        LapPathRead(
          lap: p.lap,
          distances: p.distances,
          latitudes: p.latitudes,
          longitudes: p.longitudes,
        ),
    ]);
    corners = ref
        .read(cornerTableStoreProvider.notifier)
        .ensure(
          CornerTable(
            key: key,
            wrapLength: wrapLength,
            corners: detectGeoCorners(profile),
            laps: profile.laps,
          ),
        );
  }

  final times = <int, List<double>>{};
  if (table != null) {
    final boundaries = [for (final s in table.segments.skip(1)) s.start];
    for (final lap in session.racing) {
      final p = profiles[lap.index];
      if (p == null) continue;
      final t = segmentTimes(
        times: p.times,
        distances: p.distances,
        boundaries: boundaries,
        lapStart: lap.startSeconds,
        lapTime: lap.lapTimeSeconds!,
      );
      if (t != null) times[lap.index] = t;
    }
  }

  // The map draws the fastest clean lap, or the fastest racing lap.
  final reference = clean.isNotEmpty
      ? clean
            .reduce(
              (a, b) => b.$1.lapTimeSeconds! < a.$1.lapTimeSeconds! ? b : a,
            )
            .$2
      : profiles.values.first;
  return TechniqueCourse(
    table: table,
    corners: corners,
    map: _mapPath(reference),
    segmentTimes: times,
    unavailable: unavailable,
  );
}

DistanceAxis _axisOf(LapProfileRead p) => DistanceAxis.fromSeries(
  TraceSeries(
    channelName: techniqueDistanceChannel,
    unit: 'm',
    frequencyHz: 10,
    valueColumn: 'value',
    times: p.times,
    lows: p.distances,
    highs: p.distances,
  ),
);

SpeedProfile _speedOf(LapProfileRead p) =>
    SpeedProfile(p.times, p.distances, p.speeds);

TechniqueMapPath? _mapPath(LapProfileRead p) {
  final projection = TrackProjection.fromCoordinates(p.latitudes, p.longitudes);
  if (projection.isEmpty) return null;
  return TechniqueMapPath(
    points: projection.points,
    stations: p.distances,
    bounds: projection.boundsMetres,
  );
}

/// A segment table cut from this session alone, when the course has none
/// yet: Compare's detector on the fastest clean lap, read at its own rate as
/// Compare reads it, with every other clean lap voting on each corner's
/// stability from its 10 Hz profile.
Future<SegmentTable> _detectSegments(
  Ref ref,
  TelemetrySource source,
  TechniqueSession session,
  TrackKey key,
  double wrapLength,
  List<(Lap, LapProfileRead)> clean,
) async {
  final (canonicalLap, canonicalProfile) = clean.reduce(
    (a, b) => b.$1.lapTimeSeconds! < a.$1.lapTimeSeconds! ? b : a,
  );
  var profile = _speedOf(canonicalProfile);
  final read = await ref.watch(
    lapSpeedProvider(source, canonicalLap.index).future,
  );
  final speed = read.speed;
  final distance = read.lapDistance;
  if (speed != null && distance != null && distance.length >= 2) {
    profile = SpeedProfile.of(
      speed: speed,
      axis: DistanceAxis.fromSeries(distance),
    );
  }
  final threshold = cornerThresholdFor(key);
  final detected = SegmentDetector(threshold: threshold).detect(profile);
  final stability = CornerStability.measure(
    canonical: detected,
    others: [
      for (final (lap, p) in clean)
        if (lap != canonicalLap)
          speedMinima(
            _speedOf(p),
            minProminence: SegmentDetector.candidateProminence,
          ),
    ],
    threshold: threshold,
    wrapLength: wrapLength,
  );
  return SegmentTable(
    key: key,
    wrapLength: wrapLength,
    boundaries: detected.boundaries,
    corners: stability.corners,
    unstableDropped: stability.dropped,
    canonical: CanonicalLap(
      recording: session.metadata.recordingIdentity,
      sessionType: session.metadata.sessionType.rawValue,
      lapIndex: canonicalLap.index,
      lapNumber: canonicalLap.displayNumber,
    ),
    threshold: threshold,
  );
}

/// The pedal and G frames totalled per segment and per corner.
class TechniquePlacement {
  const TechniquePlacement({required this.pedals, this.gg});

  final PedalReads pedals;
  final GgReads? gg;

  PedalTotals? segment(int lap, int number) => pedals.segments[lap]?[number];
  PedalTotals? corner(int lap, int number) => pedals.corners[lap]?[number];
  GgStretch? segmentG(int lap, int number) => gg?.segments[lap]?[number];
  GgStretch? cornerG(int lap, int number) => gg?.corners[lap]?[number];

  /// The median over the racing laps of [value] on segment [number].
  double? segmentMedian(
    int number,
    double? Function(PedalTotals totals) value,
  ) => medianOf([
    for (final laps in pedals.segments.values)
      if (laps[number] case final t?) ?value(t),
  ]);

  double? cornerMedian(int number, double? Function(PedalTotals) value) =>
      medianOf([
        for (final laps in pedals.corners.values)
          if (laps[number] case final t?) ?value(t),
      ]);
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniquePlacement?> techniquePlacement(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  final course = await ref.watch(techniqueCourseProvider(source).future);
  final table = course.table;
  if (table == null || session.racing.isEmpty) return null;
  final repo = await ref.watch(techniqueRepositoryProvider(source).future);
  final segments = [
    for (final s in table.segments)
      (key: s.number, start: s.start, end: s.end, apex: null),
  ];
  final corners = [
    for (final c in course.corners?.corners ?? const <GeoCorner>[])
      (key: c.number, start: c.start, end: c.end, apex: c.apex),
  ];
  final pedals = await repo.readPedalStats(
    session.spans,
    steeringScale: session.steeringScale,
    segments: segments,
    corners: corners,
  );
  final gg = await repo.readGg(
    session.spans,
    segments: segments,
    corners: corners,
  );
  return TechniquePlacement(pedals: pedals, gg: gg);
}

/// Each racing lap's conditions, and the contrasts the lens can draw.
class TechniqueLens {
  const TechniqueLens({
    required this.conditions,
    required this.laps,
    required this.options,
    this.compounds = const {},
  });

  /// Lap → its conditions, for the header's chips.
  final Map<int, LapConditions> conditions;

  /// The laps as the lens sees them.
  final List<LensLap> laps;
  final List<LensOption> options;

  /// Each compound lens value's mark ([compoundLensValue]), so the lens can
  /// badge a compound with the file's own reasons for its name.
  final Map<double, CompoundMark> compounds;
}

/// The event behind each lens condition, for the electronics.
const _settingConditions = {
  'TCLevel': LensCondition.tcLevel,
  'TCCut': LensCondition.tcCut,
  'TCSlipAngle': LensCondition.tcSlip,
  'ABSLevel': LensCondition.absLevel,
  'Brake Bias Rear': LensCondition.brakeBias,
  'Brake Migration': LensCondition.brakeMigration,
  'FuelMixtureMap': LensCondition.mixture,
};

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TechniqueLens> techniqueLens(Ref ref, TelemetrySource source) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  final all = await ref.watch(sessionConditionsProvider(source).future);
  final course = await ref.watch(techniqueCourseProvider(source).future);
  final placement = await ref.watch(techniquePlacementProvider(source).future);
  final segments = course.segments;

  final conditions = <int, LapConditions>{};
  final compounds = <double, CompoundMark>{};
  final laps = <LensLap>[];
  for (final lap in session.racing) {
    final c = all.of(lap);
    conditions[lap.index] = c;
    final values = <LensCondition, double?>{};
    final wet = c.wetness;
    if (wet != null) {
      final from = TechniqueThresholds.wetFrom;
      // A lap that crossed the line between dry and wet is neither.
      values[LensCondition.wetness] = wet.max < from
          ? 0
          : wet.min >= from
          ? 1
          : null;
    }
    final compound = c.compound;
    if (compound != null) {
      final counts = <int, int>{};
      for (final v in compound) {
        counts[v] = (counts[v] ?? 0) + 1;
      }
      final index = counts.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      final mark = c.compoundKey.mark(index);
      final value = compoundLensValue(mark);
      values[LensCondition.compound] = value;
      compounds[value] = mark;
    }
    for (final MapEntry(key: name, value: condition)
        in _settingConditions.entries) {
      final v = c.settings[name];
      if (v != null) {
        values[condition] = c.settingsChanged.contains(name) ? null : v;
      }
    }
    if (!session.hasAbs) values.remove(LensCondition.absLevel);
    laps.add(
      LensLap(
        lap: lap.index,
        lapTime: lap.lapTimeSeconds!,
        conditions: values,
        segmentTimes: course.segmentTimes[lap.index] ?? const [],
        slowest: [
          for (final s in segments)
            placement?.segment(lap.index, s.number)?.slowest,
        ],
        tc: [
          for (final s in segments)
            switch (placement?.segment(lap.index, s.number)) {
              final t? => t.seconds(t.tc),
              null => null,
            },
        ],
        abs: [
          for (final s in segments)
            switch (placement?.segment(lap.index, s.number)) {
              final t? when session.hasAbs => t.seconds(t.abs),
              _ => null,
            },
        ],
      ),
    );
  }
  return TechniqueLens(
    conditions: conditions,
    laps: laps,
    options: lensOptions(laps),
    compounds: compounds,
  );
}

/// One lap's G-G points, read when the lap is shown.
@Riverpod(retry: _neverRetry)
Future<List<GgPoint>> techniqueLapPoints(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  final lap = session.racing.where((l) => l.index == lapIndex).firstOrNull;
  if (lap == null) return const [];
  final repo = await ref.watch(techniqueRepositoryProvider(source).future);
  return repo.readLapGgPoints((
    lap: lap.index,
    start: lap.startSeconds,
    end: lap.endSeconds!,
  ));
}

/// What the screen is showing: a lap and, optionally, a lens.
class TechniqueSelection {
  const TechniqueSelection({this.lapIndex, this.lens});

  /// Null shows the fastest racing lap.
  final int? lapIndex;
  final LensOption? lens;
}

@Riverpod(keepAlive: true)
class TechniqueSelectionState extends _$TechniqueSelectionState {
  @override
  TechniqueSelection build(TelemetrySource source) =>
      const TechniqueSelection();

  void selectLap(int index) =>
      state = TechniqueSelection(lapIndex: index, lens: state.lens);

  void setLens(LensOption? lens) =>
      state = TechniqueSelection(lapIndex: state.lapIndex, lens: lens);
}

/// The lens result for [source]'s selected option, or null.
@riverpod
LensResult? techniqueLensResult(Ref ref, TelemetrySource source) {
  final option = ref.watch(
    techniqueSelectionStateProvider(source).select((s) => s.lens),
  );
  if (option == null) return null;
  final lens = ref.watch(techniqueLensProvider(source)).value;
  if (lens == null) return null;
  return measureLens(option, lens.laps);
}

/// A segment, or one corner of it, by number.
class StretchRef {
  const StretchRef.segment(this.segment) : corner = null;
  const StretchRef.corner(this.segment, int this.corner);

  /// `Segment.number`.
  final int segment;

  /// `GeoCorner.number`; null for the whole segment.
  final int? corner;

  @override
  bool operator ==(Object other) =>
      other is StretchRef && other.segment == segment && other.corner == corner;

  @override
  int get hashCode => Object.hash(segment, corner);
}

/// What the pointer or the keyboard is on, linking the map, the table and the
/// G-G (§8.13.8 "Linking").
class TechniqueFocus {
  const TechniqueFocus({this.hovered, this.selected, this.expanded = const {}});

  final StretchRef? hovered;
  final StretchRef? selected;

  /// The segments showing their corners.
  final Set<int> expanded;

  /// What the linked views emphasise: the hover, else the selection.
  StretchRef? get active => hovered ?? selected;
}

@riverpod
class TechniqueFocusState extends _$TechniqueFocusState {
  @override
  TechniqueFocus build(TelemetrySource source) => const TechniqueFocus();

  void hover(StretchRef? stretch) {
    if (stretch == state.hovered) return;
    state = TechniqueFocus(
      hovered: stretch,
      selected: state.selected,
      expanded: state.expanded,
    );
  }

  void select(StretchRef? stretch) => state = TechniqueFocus(
    hovered: state.hovered,
    selected: stretch,
    expanded: state.expanded,
  );

  void toggleExpanded(int segment) => state = TechniqueFocus(
    hovered: state.hovered,
    selected: state.selected,
    expanded: state.expanded.contains(segment)
        ? ({...state.expanded}..remove(segment))
        : {...state.expanded, segment},
  );
}
