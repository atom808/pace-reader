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

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<LapChart> lapChart(Ref ref, TelemetrySource source, int lapIndex) async {
  final telemetry =
      await ref.watch(lapTelemetryProvider(source, lapIndex).future);

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

  final panels = <TracePanelSpec>[];
  for (final name in traceChannelNames) {
    final series = telemetry.channels[name];
    if (series == null || series.isEmpty) continue;
    final display = _channelDisplay[name];
    panels.add(TracePanelSpec(
      title: display?.$1 ?? name,
      unit: series.unit,
      role: display?.$2 ?? ChannelRole.speed,
      decimals: display?.$3 ?? 0,
      series: LineSeries(TracePlot.fromSeries(
        series,
        axis: axis,
        distanceAxis: distanceAxis,
        label: display?.$1 ?? name,
      )),
    ));
  }

  final gear = telemetry.gear;
  if (gear != null && gear.isNotEmpty) {
    panels.add(TracePanelSpec(
      title: 'Gear',
      unit: '',
      role: ChannelRole.gear,
      decimals: 0,
      series: StepSeriesPanel(StepPlot.fromSeries(
        gear,
        axis: axis,
        window: timeWindow,
        distanceAxis: distanceAxis,
        label: 'Gear',
      )),
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
  );
}
