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
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderListenableSelect;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_telemetry.dart';
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
    required this.reference,
    required this.overlaid,
    this.delta,
    this.note,
  });

  /// The lap compared against.
  final Lap reference;

  /// True when the reference's traces are drawn over this lap's panels.
  final bool overlaid;

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
) async {
  final telemetry =
      await ref.watch(lapTelemetryProvider(source, lapIndex).future);
  final reference = referenceIndex == null || referenceIndex == lapIndex
      ? null
      : await ref.watch(lapTelemetryProvider(source, referenceIndex).future);

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
  final bounds =
      axis == TraceAxis.distance ? distanceAxis!.bounds : timeWindow;

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
  final referenceByDistance = referenceAxis?.isUsable ?? false;
  final overlaid = reference != null &&
      reference.hasTelemetry &&
      (axis == TraceAxis.time || referenceByDistance);
  final timeShift =
      reference == null ? 0.0 : telemetry.startSeconds - reference.startSeconds;

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

  final delta =
      reference == null || distanceAxis == null || referenceAxis == null
      ? null
      : LapDelta.between(
          lap: distanceAxis,
          lapStartSeconds: telemetry.startSeconds,
          reference: referenceAxis,
          referenceStartSeconds: reference.startSeconds,
        );

  final panels = <TracePanelSpec>[
    // First, as in both reference apps (§7.1): the delta is the summary the
    // panels below it explain.
    if (delta != null)
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
            reference: reference.lap,
            overlaid: overlaid,
            delta: delta,
            note: _comparisonNote(
              reference: reference,
              axis: axis,
              lapByDistance: distanceAvailable,
              referenceByDistance: referenceByDistance,
              delta: delta,
            ),
          ),
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
  required LapDelta? delta,
}) {
  final name = 'Lap ${reference.lap.displayNumber}';
  if (!reference.hasTelemetry) {
    return '$name recorded no telemetry to compare against.';
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
  return null;
}
