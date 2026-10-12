/// One lap, shaped for the synced chart core (SPEC.md §8.4, §8.5, §9.5).
///
/// ## Why the track map reads this too
///
/// §9.5 does not treat the trace panels and the track map as two features
/// that happen to overlap — it puts them in **one** synced system, sharing a
/// cursor, an axis and a viewport. So they share this view model as well, and
/// `features/track_map/` imports it rather than assembling a second one that
/// could disagree with the first about which lap, which axis, or where a
/// sector boundary falls.
///
/// The expensive half — opening the file, resolving row ranges, decimating —
/// is in `data/repositories/lap_telemetry.dart` and shared at that level per
/// §9.1. What is left here is projection onto the current axis, which is
/// pure, cheap, and re-run whenever the axis changes.
library;

// `select` is an extension on ProviderListenable and lives in the core
// package rather than in the annotations, so it is imported by name — see the
// `chartSyncProvider.select` call below for why watching the whole sync state
// here would defeat the painters' repaint checks.
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../data/repositories/lap_telemetry.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/color_tokens.dart';

part 'lap_chart.g.dart';

/// One panel of the stack: what to draw, what to call it, and how to read it.
class TracePanelSpec {
  const TracePanelSpec({
    required this.title,
    required this.unit,
    required this.role,
    required this.series,
    required this.decimals,
  });

  final String title;
  final String unit;
  final ChannelRole role;
  final PanelSeries series;

  /// Decimal places for the cursor readout and the value axis. Fixed per
  /// channel rather than derived from the range, so a value doesn't change
  /// width — and so the axis doesn't renumber — as the user zooms (§9.7.7).
  final int decimals;
}

/// What comparing against a reference lap produced (§8.3, §8.4) — including,
/// when it produced less than a full comparison, why.
class LapComparison {
  const LapComparison({
    required this.target,
    required this.reference,
    required this.overlaid,
    required this.timeShift,
    required this.check,
    this.alignment = StationAlignment.sharedFile,
    this.referenceAxis,
    this.delta,
    this.note,
  });

  /// Which lap, of which file, was compared against — the same file on
  /// Trace, any file of the same course on Compare (comparison proposal §4).
  final LapRef target;

  /// The lap compared against.
  final Lap reference;

  /// Seconds added to the reference's own clock to place it on this lap's,
  /// so both start at their own line crossing — each lap's start re-anchored
  /// on the game's splits where it recorded them ([LapAnchor]). The Time
  /// axis draws with it; the Distance axis needs none, since both laps share
  /// the circuit's metres.
  final double timeShift;

  /// Both laps' starts, and whether the delta agrees with the game's splits
  /// at the three timing lines.
  final DeltaCheck check;

  /// How far the two files' sector lines sit apart — nothing to measure for
  /// two laps of one file.
  final StationAlignment alignment;

  /// True when the reference's traces are drawn over this lap's panels.
  final bool overlaid;

  /// The reference's own `Lap Dist` against its clock, when it has one —
  /// what its segment times are read from (comparison proposal §5).
  final DistanceAxis? referenceAxis;

  /// The time delta — present only when both laps have a usable distance
  /// axis, since it compares them at the same point of the circuit.
  final LapDelta? delta;

  /// Why part of the comparison is missing, written for the user; null when
  /// nothing is.
  final String? note;

  /// [lap]'s `Lap Time` minus the reference's: the game's own figure for the
  /// number the delta trace ends at, so the headline never depends on the
  /// trace resolution. Null unless both laps were timed.
  double? lapTimeDifference(Lap lap) =>
      lap.lapTimeSeconds == null || reference.lapTimeSeconds == null
          ? null
          : lap.lapTimeSeconds! - reference.lapTimeSeconds!;
}

/// A lap projected onto the current axis, ready to hand to painters.
class LapChart {
  const LapChart({
    required this.telemetry,
    required this.axis,
    required this.bounds,
    required this.panels,
    required this.distanceAxis,
    required this.distanceAvailable,
    required this.traceMarkers,
    required this.trackPath,
    required this.trackMarkers,
    required this.trackColorRole,
    this.comparison,
  });

  final LapTelemetry telemetry;

  /// The axis actually used, which is not always the one requested — see
  /// [distanceAvailable].
  final TraceAxis axis;

  /// Full extent of the lap on [axis]; the viewport is clamped inside it.
  final ChartViewport bounds;

  final List<TracePanelSpec> panels;

  final DistanceAxis? distanceAxis;

  /// False when this lap has no usable distance axis — the garage lap, where
  /// `Lap Dist` runs backwards while the car manoeuvres in the pits. The UI
  /// disables the toggle and says why rather than drawing a folded chart.
  final bool distanceAvailable;

  /// Sector boundaries in [axis] units, for the vertical markers.
  final List<(double, String)> traceMarkers;

  final TrackPath? trackPath;

  /// Sector boundaries and the start/finish line, as point indices into
  /// [trackPath].
  final List<(int, String)> trackMarkers;

  final ChannelRole trackColorRole;

  /// The comparison against a reference lap, or null when none is chosen.
  final LapComparison? comparison;

  Lap get lap => telemetry.lap;
  bool get hasTrackMap => trackPath != null && trackPath!.length > 1;
}

/// Which channel colours the track map (§8.5).
@Riverpod(keepAlive: true)
class TrackMapChannel extends _$TrackMapChannel {
  @override
  String build() => 'Ground Speed';

  void select(String channelName) => state = channelName;
}

/// Display metadata for the channels the stack knows how to plot.
///
/// A lookup rather than a field on `ChannelDescriptor`, because none of it
/// comes from the file: the catalog supplies a name, a unit and a rate, and
/// "call this Throttle, colour it green, show it to the nearest whole
/// percent" is a presentation decision about a signal the file only names.
const _channelDisplay = <String, (String, ChannelRole, int)>{
  'Ground Speed': ('Speed', ChannelRole.speed, 0),
  'Throttle Pos': ('Throttle', ChannelRole.throttle, 0),
  'Brake Pos': ('Brake', ChannelRole.brake, 0),
  'Steering Pos': ('Steering', ChannelRole.steering, 1),
  'Engine RPM': ('Engine RPM', ChannelRole.rpm, 0),
};

/// Channels offered as the track map's colouring (§8.5 names these three).
const trackMapChannelChoices = ['Ground Speed', 'Throttle Pos', 'Brake Pos'];

Duration? _neverRetry(int retryCount, Object error) => null;

/// [lapIndex] projected for the synced views, compared against
/// [referenceIndex] when there is one (§8.4).
///
/// Not kept alive, unlike the lap reads it projects: those are the expensive
/// half and stay cached per lap, while this is a pass over a few thousand
/// points. Keeping every lap × reference pair a user has ever looked at would
/// grow without bound, and rebuilding one costs less than a frame.
@Riverpod(retry: _neverRetry)
Future<LapChart> lapChart(
  Ref ref,
  TelemetrySource source,
  int lapIndex,
  int? referenceIndex,
) => buildComparisonChart(
  ref,
  base: LapRef(source, lapIndex),
  target: referenceIndex == null ? null : LapRef(source, referenceIndex),
);

/// [base] projected for the synced views, compared against [target] when
/// there is one — a lap of the same file, as on Trace, or of another file of
/// the same course, as on Compare (comparison proposal §9).
///
/// One builder for both, so a pair of laps is drawn, shifted and measured the
/// same way whichever screen shows it. Nothing here assumes the two laps
/// share a file: each is read from its own source, and each is placed on
/// [base]'s axis by its own distance axis or its own clock.
Future<LapChart> buildComparisonChart(
  Ref ref, {
  required LapRef base,
  LapRef? target,
}) async {
  final telemetry = await ref.watch(
    lapTelemetryProvider(base.source, base.lapIndex).future,
  );
  final reference = target == null || target == base
      ? null
      : await ref.watch(
          lapTelemetryProvider(target.source, target.lapIndex).future,
        );

  // `select` deliberately: the axis and the colouring channel change rarely,
  // while the cursor changes on every pointer move. Watching the whole sync
  // state would rebuild every plot in the lap at pointer rate, and the
  // painters' identity checks — the thing that keeps a scrub off the
  // thousands of points below it — would never hit.
  final requestedAxis = ref.watch(chartSyncProvider.select((s) => s.axis));
  final trackChannel = ref.watch(trackMapChannelProvider);

  final distanceAxis = telemetry.hasDistance
      ? DistanceAxis.fromSeries(telemetry.lapDistance!)
      : null;
  final distanceAvailable = distanceAxis?.isUsable ?? false;
  final axis = requestedAxis == TraceAxis.distance && !distanceAvailable
      ? TraceAxis.time
      : requestedAxis;

  final timeWindow =
      ChartViewport(telemetry.startSeconds, telemetry.endSeconds);

  double toDomain(double seconds) => axis == TraceAxis.distance
      ? distanceAxis!.distanceAt(seconds)
      : seconds;

  // The reference is placed on this lap's axis the same two ways every panel
  // is: by its *own* distance axis, or by its own clock shifted so both laps
  // start at their own line crossing. The second always works; the first
  // needs the reference's lap distance to run forwards throughout.
  final referenceAxis = reference != null && reference.hasDistance
      ? DistanceAxis.fromSeries(reference.lapDistance!)
      : null;

  // Each lap's clock starts at its line crossing, re-anchored on the game's
  // splits where the lap recorded all three (comparison proposal §4, D1).
  // Only a comparison needs it, so a lap on its own reads nothing more.
  final baseFacts = reference == null ? null : await _anchorFacts(ref, base);
  final targetFacts =
      reference == null ? null : await _anchorFacts(ref, target!);
  final baseAnchor = reference == null
      ? LapAnchor.event(telemetry.startSeconds)
      : LapAnchor.measure(
          lap: telemetry.lap,
          axis: distanceAxis,
          course: baseFacts!.course,
          recordingStart: baseFacts.recordingStart,
        );
  final targetAnchor = reference == null
      ? null
      : LapAnchor.measure(
          lap: reference.lap,
          axis: referenceAxis,
          course: targetFacts!.course,
          recordingStart: targetFacts.recordingStart,
        );

  // Two files are one coordinate only if their sector lines agree; past
  // 5 m apart, nothing compared at equal distance means anything (§4).
  final alignment = reference == null || target!.source == base.source
      ? StationAlignment.sharedFile
      : StationAlignment.between(
          baseFacts!.course ?? CourseFacts.unknown,
          targetFacts!.course ?? CourseFacts.unknown,
        );
  final referenceByDistance =
      (referenceAxis?.isUsable ?? false) && !alignment.withholdsDistance;
  final overlaid = reference != null &&
      reference.hasTelemetry &&
      (axis == TraceAxis.time || referenceByDistance);
  final timeShift = targetAnchor == null
      ? 0.0
      : baseAnchor.startSeconds - targetAnchor.startSeconds;

  // On the Time axis a slower reference runs past this lap's end, since both
  // start at their own line crossing; the bounds cover both, or the last
  // stretch of the reference — where the lap was lost — would be cut off.
  // On the Distance axis both laps are on the circuit's metres and the delta
  // exists only where both reached, so the bounds stay this lap's: widening
  // them to the reference's first sample would shift every pixel for nothing.
  final bounds = switch (axis) {
    TraceAxis.distance => distanceAxis!.bounds,
    TraceAxis.time when overlaid => ChartViewport(
      math.min(timeWindow.start, reference.startSeconds + timeShift),
      math.max(timeWindow.end, reference.endSeconds + timeShift),
    ),
    TraceAxis.time => timeWindow,
  };

  TracePlot? referenceLine(String name, String label) {
    final series = overlaid ? reference.channels[name] : null;
    if (series == null || series.isEmpty) return null;
    return TracePlot.fromSeries(
      series,
      axis: axis,
      distanceAxis: referenceAxis,
      label: label,
      timeShift: timeShift,
    );
  }

  final delta = targetAnchor == null ||
          distanceAxis == null ||
          referenceAxis == null ||
          alignment.withholdsDistance
      ? null
      : LapDelta.between(
          lap: distanceAxis,
          lapStartSeconds: baseAnchor.startSeconds,
          reference: referenceAxis,
          referenceStartSeconds: targetAnchor.startSeconds,
        );
  final check = targetAnchor == null
      ? null
      : DeltaCheck.of(baseAnchor, targetAnchor);
  // A delta the game's own splits contradict is a wrong number on screen,
  // so it is not drawn; the note and Compare's check chip say by how much.
  final deltaShown = delta != null && check!.status != DeltaCheckStatus.failed;

  final panels = <TracePanelSpec>[
    // First, as in both reference apps (§7.1): the delta is the summary the
    // panels below it explain.
    if (deltaShown)
      TracePanelSpec(
        title: 'Delta',
        unit: 's',
        role: ChannelRole.delta,
        decimals: 3,
        series: DeltaSeriesPanel(delta.toPlot(axis)),
      ),
  ];
  for (final name in traceChannelNames) {
    final series = telemetry.channels[name];
    if (series == null || series.isEmpty) continue;
    final display = _channelDisplay[name];
    final label = display?.$1 ?? name;
    panels.add(TracePanelSpec(
      title: label,
      unit: series.unit,
      role: display?.$2 ?? ChannelRole.speed,
      decimals: display?.$3 ?? 0,
      series: LineSeries(
        TracePlot.fromSeries(
          series,
          axis: axis,
          distanceAxis: distanceAxis,
          label: label,
        ),
        reference: referenceLine(name, label),
      ),
    ));
  }

  final gear = telemetry.gear;
  if (gear != null && gear.isNotEmpty) {
    final referenceGear = overlaid ? reference.gear : null;
    panels.add(TracePanelSpec(
      title: 'Gear',
      unit: '',
      role: ChannelRole.gear,
      decimals: 0,
      series: StepSeriesPanel(
        StepPlot.fromSeries(
          gear,
          axis: axis,
          window: timeWindow,
          distanceAxis: distanceAxis,
          label: 'Gear',
        ),
        reference: referenceGear == null || referenceGear.isEmpty
            ? null
            : StepPlot.fromSeries(
                referenceGear,
                axis: axis,
                window: ChartViewport(
                  reference!.startSeconds,
                  reference.endSeconds,
                ),
                distanceAxis: referenceAxis,
                label: 'Gear',
                timeShift: timeShift,
              ),
      ),
    ));
  }

  final traceMarkers = [
    for (final (seconds, sector) in telemetry.sectorBoundaries)
      (toDomain(seconds), 'S$sector'),
  ];

  TrackPath? trackPath;
  final trackMarkers = <(int, String)>[];
  if (telemetry.hasPosition) {
    // The colouring series is built against the same axis as the panels, so
    // the map samples exactly what a panel would read at the same cursor.
    final colorSeries = telemetry.channels[trackChannel];
    trackPath = TrackPath.build(
      latitude: telemetry.latitude!,
      longitude: telemetry.longitude!,
      axis: axis,
      distanceAxis: distanceAxis,
      colorBy: colorSeries == null
          ? null
          : TracePlot.fromSeries(
              colorSeries,
              axis: axis,
              distanceAxis: distanceAxis,
              label: _channelDisplay[trackChannel]?.$1 ?? trackChannel,
            ),
    );
    trackMarkers.add((0, 'S/F'));
    for (final (domain, label) in traceMarkers) {
      trackMarkers.add((trackPath.nearestIndex(domain), label));
    }
  }

  return LapChart(
    telemetry: telemetry,
    axis: axis,
    bounds: bounds,
    panels: panels,
    distanceAxis: distanceAxis,
    distanceAvailable: distanceAvailable,
    traceMarkers: traceMarkers,
    trackPath: trackPath,
    trackMarkers: trackMarkers,
    trackColorRole: _channelDisplay[trackChannel]?.$2 ?? ChannelRole.speed,
    comparison: reference == null
        ? null
        : LapComparison(
            target: target!,
            reference: reference.lap,
            overlaid: overlaid,
            timeShift: timeShift,
            check: check!,
            alignment: alignment,
            referenceAxis: referenceAxis,
            delta: deltaShown ? delta : null,
            note: _comparisonNote(
              reference: reference,
              axis: axis,
              lapByDistance: distanceAvailable,
              referenceByDistance: referenceAxis?.isUsable ?? false,
              alignment: alignment,
              check: check,
              delta: delta,
            ),
          ),
  );
}

/// What re-anchoring a lap of [lap]'s file needs: the file's course facts,
/// and whether [lap] is the recording's first.
///
/// Null facts where the file cannot supply them — a file without the
/// channels, or a test that serves laps without a file behind them. The lap
/// then keeps its `Lap` event, and the check says it could not run, rather
/// than the chart failing for want of a refinement.
Future<({CourseFacts? course, bool recordingStart})> _anchorFacts(
  Ref ref,
  LapRef lap,
) async {
  CourseFacts? course;
  int? firstIndex;
  try {
    course = await ref.watch(courseFactsProvider(lap.source).future);
  } on Object {
    course = null;
  }
  try {
    firstIndex =
        (await ref.watch(lapsProvider(lap.source).future)).firstOrNull?.index;
  } on Object {
    firstIndex = null;
  }
  return (
    course: course,
    // The recording's first `Lap` event, whatever its number: 308 library
    // recordings start mid-session at a value above 0 (§4 Lap rules).
    recordingStart:
        firstIndex == null ? lap.lapIndex == 0 : lap.lapIndex == firstIndex,
  );
}

/// Why a comparison came out partial, in the order a user would ask.
///
/// Every case names which lap is responsible, because "no delta" alone sends
/// a user looking at the wrong one.
String? _comparisonNote({
  required LapTelemetry reference,
  required TraceAxis axis,
  required bool lapByDistance,
  required bool referenceByDistance,
  required StationAlignment alignment,
  required DeltaCheck check,
  required LapDelta? delta,
}) {
  final name = 'Lap ${reference.lap.displayNumber}';
  if (!reference.hasTelemetry) {
    return '$name recorded no telemetry to compare against.';
  }
  if (alignment.withholdsDistance) {
    final offset = alignment.worstOffset!;
    return "The two files' sector lines sit ${offset.abs().toStringAsFixed(1)} m "
        'apart (S1 ${_metres(alignment.sector1Offset)}, '
        'S2 ${_metres(alignment.sector2Offset)}), so nothing is compared at '
        'equal distance: no delta, and the laps overlay on the time axis '
        'only.';
  }
  if (!referenceByDistance) {
    // Missing and running backwards are different facts about a lap, and
    // only one of them is what the pits do to a recording.
    final why = reference.hasDistance
        ? 'its lap distance runs backwards somewhere'
        : 'it recorded no lap distance';
    return axis == TraceAxis.distance
        ? '$name has no usable distance axis — $why — so it can only be '
            'compared on the time axis, and without a delta.'
        : '$name has no usable distance axis — $why — so it is compared by '
            'time only, without a delta.';
  }
  if (!lapByDistance) {
    return 'This lap has no usable distance axis, so $name is compared by time '
        'only, without a delta.';
  }
  if (delta == null) {
    return 'The two laps share no stretch of track, so there is no delta.';
  }
  if (check.status == DeltaCheckStatus.failed) {
    final lap = check.worstLap;
    final (what, by, limit) = lap != null && lap.abs() > DeltaCheck.perLapLimit
        ? ('a lap disagrees with its own splits', lap, DeltaCheck.perLapLimit)
        : (
            "the delta disagrees with the game's splits",
            check.worstPair!,
            check.pairBound,
          );
    return 'The delta is not drawn: $what by ${formatDelta(by)} s, more '
        'than the ${limit.toStringAsFixed(3)} s the timing allows.';
  }
  if (alignment.unchecked) {
    return "One of the files records no sector-line crossing, so the two "
        "files' distances cannot be checked against each other.";
  }
  if (!alignment.sameFile && !alignment.aligned) {
    return "The two files' sector lines sit "
        '${alignment.worstOffset!.abs().toStringAsFixed(1)} m apart: corner '
        'deltas may shift by that much.';
  }
  return null;
}

String _metres(double? offset) =>
    offset == null ? '—' : '${offset >= 0 ? '+' : ''}${offset.toStringAsFixed(1)} m';
