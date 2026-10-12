/// Segment tables, one per course, detected once and kept for the run
/// (comparison proposal §5 "Frozen, not per comparison", §9 Providers).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../data/repositories/lap_speed.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../lap_analysis/application/lap_incidents.dart';
import '../domain/comparison_set.dart';
import '../domain/segment_losses.dart';
import '../domain/segments.dart';
import 'compare_source_guard.dart';
import 'comparison_chart.dart';

part 'segment_tables.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// Every course's table, held in memory for the run (persisted from step 10).
///
/// Written only by [ensure], so nothing that merely reads a table — a new
/// Target, a Swap, the canonical lap's file closing — can recompute it:
/// "Seg 3" keeps meaning the same metres whichever lap is Base.
@Riverpod(keepAlive: true)
class SegmentTableStore extends _$SegmentTableStore {
  @override
  Map<TrackKey, SegmentTable> build() => const {};

  /// Freezes [detected] as its course's table, unless the course already
  /// has one that fits its lap length: that one is kept and returned.
  SegmentTable ensure(SegmentTable detected) {
    final held = state[detected.key];
    if (held != null && held.fits(detected.wrapLength)) return held;
    state = {...state, detected.key: detected};
    return detected;
  }
}

/// [key]'s table, if one was detected — read from the store and nothing else.
@riverpod
SegmentTable? segmentTable(Ref ref, TrackKey key) =>
    ref.watch(segmentTableStoreProvider.select((tables) => tables[key]));

/// No lap of either file can be the canonical lap.
class NoCleanLap implements Exception {
  const NoCleanLap(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A table detected for [set]'s course: the command [comparisonSegments]
/// issues when the course has none yet.
///
/// The canonical lap is the faster *clean* lap of Base and the Target; if
/// neither is clean, the fastest clean lap of their files (§5 "Canonical
/// lap"). Every other clean lap of the two files then votes on each corner's
/// stability. Reads Ground Speed for every lap that passes the cheap rules,
/// and only from files in Open now.
@Riverpod(retry: _neverRetry)
Future<SegmentTable> segmentDetection(Ref ref, ComparisonSet set) async {
  final target = set.target;
  if (target == null) throw StateError('Segments need a Target.');
  requireSourceOpen(ref, set.base.source, ComparisonRole.base);
  requireSourceOpen(ref, target.source, ComparisonRole.target);

  final baseMetadata = await ref.watch(
    sessionMetadataProvider(set.base.source).future,
  );
  final key = TrackKey.of(baseMetadata);

  final clean = <_CleanLap>[];
  for (final source in {set.base.source, target.source}) {
    clean.addAll(await _cleanLaps(ref, source));
  }
  final pair = [
    for (final lap in [set.base, target])
      ?clean.where((c) => c.ref == lap).firstOrNull,
  ];
  final pool = pair.isNotEmpty ? pair : clean;
  if (pool.isEmpty) {
    throw const NoCleanLap(
      'Neither file has a clean lap to find the corners on: every lap is '
      "untimed, the recording's first, or has contact, pit-lane time, a "
      'stop or an off-track jump.',
    );
  }
  final canonical = pool.reduce(
    (a, b) => b.lap.lapTimeSeconds! < a.lap.lapTimeSeconds! ? b : a,
  );
  final canonicalCourse = await ref.watch(
    courseFactsProvider(canonical.ref.source).future,
  );
  final wrapLength = canonicalCourse.wrapLength;
  if (wrapLength == null) {
    throw const NoCleanLap(
      "The canonical lap's file records no lap length to fit segments to.",
    );
  }
  final canonicalMetadata = canonical.ref.source == set.base.source
      ? baseMetadata
      : await ref.watch(sessionMetadataProvider(canonical.ref.source).future);

  final threshold = cornerThresholdFor(key);
  final detected = SegmentDetector(threshold: threshold)
      .detect(canonical.profile);
  final stability = CornerStability.measure(
    canonical: detected,
    others: [
      for (final c in clean)
        if (c != canonical)
          speedMinima(
            c.profile,
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
      recording: canonicalMetadata.recordingIdentity,
      sessionType: canonicalMetadata.sessionType.rawValue,
      lapIndex: canonical.lap.index,
      lapNumber: canonical.lap.displayNumber,
    ),
    threshold: threshold,
  );
}

class _CleanLap {
  const _CleanLap(this.ref, this.lap, this.profile);

  final LapRef ref;
  final Lap lap;
  final SpeedProfile profile;
}

/// [source]'s clean laps, each with its speed profile.
Future<List<_CleanLap>> _cleanLaps(Ref ref, TelemetrySource source) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final course = await ref.watch(courseFactsProvider(source).future);
  final incidents = await ref.watch(sessionIncidentsProvider(source).future);
  final first = laps.firstOrNull?.index;
  final out = <_CleanLap>[];
  for (final lap in laps) {
    final end = lap.endSeconds;
    final ruledOut = whyNotCleanBeforeReading(
      lap: lap,
      recordingStart: lap.index == first,
      impact: incidents.of(lap).hasImpact,
      pitLane: end != null && course.pitLaneDuring(lap.startSeconds, end),
    );
    if (ruledOut != null) continue;
    final read = await ref.watch(lapSpeedProvider(source, lap.index).future);
    final distance = read.lapDistance;
    final speed = read.speed;
    final axis = distance == null || distance.length < 2
        ? null
        : DistanceAxis.fromSeries(distance);
    final profile = axis == null || speed == null
        ? null
        : SpeedProfile.of(speed: speed, axis: axis);
    final reason = whyNotClean(
      lap: lap,
      recordingStart: false,
      impact: false,
      pitLane: false,
      axis: axis,
      speed: profile,
    );
    if (reason == null) {
      out.add(_CleanLap(LapRef(source, lap.index), lap, profile!));
    }
  }
  return out;
}

/// What the segment navigator and the Why card show for one comparison.
class ComparisonSegments {
  const ComparisonSegments({
    required this.sectors,
    this.table,
    this.segments,
    this.baseClock,
    this.unavailable,
  });

  /// The game's three sectors, from its splits: there whenever a Target is,
  /// even with the delta withheld (§4: "The sector table and the time-axis
  /// overlay remain").
  final StretchComparison sectors;

  /// The course's frozen table, once detected.
  final SegmentTable? table;

  /// Losses over [table]'s segments; null when the delta is withheld or no
  /// table could be detected.
  final StretchComparison? segments;

  /// Base's clock along the course, for zooming the Time axis onto a
  /// stretch.
  final LapClock? baseClock;

  /// Why there are no segments, for the user.
  final String? unavailable;

  StretchComparison? inMode(SegmentMode mode) =>
      mode == SegmentMode.segments ? segments : sectors;
}

/// [set]'s segment losses and sectors, or null without a Target or for a
/// pair the course gate refused.
///
/// Reads the course's table from the store. When the course has none yet,
/// or one cut for a different lap length, it detects one and issues
/// [SegmentTableStore.ensure]: the store then holds it for every later
/// comparison of the course, and this rebuilds from the store.
@Riverpod(retry: _neverRetry)
Future<ComparisonSegments?> comparisonSegments(
  Ref ref,
  ComparisonSet set,
) async {
  if (set.target == null) return null;
  final view = await ref.watch(comparisonChartProvider(set).future);
  final chart = view.chart;
  final comparison = chart?.comparison;
  if (chart == null || comparison == null) return null;

  final baseCourse = await ref.watch(
    courseFactsProvider(set.base.source).future,
  );
  final sectors = StretchComparison.sectors(
    base: chart.lap,
    target: comparison.reference,
    stations: (
      sector1: baseCourse.sector1Station,
      sector2: baseCourse.sector2Station,
      length: baseCourse.wrapLength,
    ),
  );

  final delta = comparison.delta;
  final baseAxis = chart.distanceAxis;
  final targetAxis = comparison.referenceAxis;
  final wrapLength = baseCourse.wrapLength;
  if (delta == null || baseAxis == null || targetAxis == null) {
    return ComparisonSegments(
      sectors: sectors,
      unavailable:
          'No segments: they are measured on the delta, and '
          '${comparison.note == null ? 'there is none' : 'it is withheld'}.',
    );
  }
  if (wrapLength == null) {
    return ComparisonSegments(
      sectors: sectors,
      unavailable: "No segments: Base's file records no lap length.",
    );
  }

  final key = TrackKey.of(view.base);
  var table = ref.watch(segmentTableProvider(key));
  if (table == null || !table.fits(wrapLength)) {
    try {
      final detected = await ref.watch(segmentDetectionProvider(set).future);
      table = ref.read(segmentTableStoreProvider.notifier).ensure(detected);
    } on NoCleanLap catch (e) {
      return ComparisonSegments(sectors: sectors, unavailable: e.message);
    }
  }

  final baseClock = _clock(
    chart.lap,
    baseAxis,
    comparison.check.base.startSeconds,
    table.wrapLength,
  );
  final targetClock = _clock(
    comparison.reference,
    targetAxis,
    comparison.check.target.startSeconds,
    table.wrapLength,
  );
  if (baseClock == null || targetClock == null) {
    return ComparisonSegments(
      sectors: sectors,
      table: table,
      unavailable:
          'No segments: a lap without a lap time or a closing line has no '
          'end to measure the last segment to.',
    );
  }
  return ComparisonSegments(
    sectors: sectors,
    table: table,
    baseClock: baseClock,
    segments: StretchComparison.segments(
      table: table,
      base: baseClock,
      target: targetClock,
      delta: delta,
    ),
  );
}

/// [lap]'s clock: from its (re-anchored) start to the start plus the game's
/// lap time, or, for an untimed lap, to its next `Lap` event.
LapClock? _clock(Lap lap, DistanceAxis axis, double start, double length) {
  final time = lap.lapTimeSeconds;
  final end = time != null ? start + time : lap.endSeconds;
  if (end == null) return null;
  return LapClock(
    axis: axis,
    startSeconds: start,
    endSeconds: end,
    wrapLength: length,
    endFromLineCrossing: time == null,
  );
}
