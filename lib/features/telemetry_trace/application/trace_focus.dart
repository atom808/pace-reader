/// Trace as a [LapFocusTarget] (map stage proposal §6.4): a lap opens on the
/// stage with the car at the point another screen pointed at and the traces
/// framed on its stretch.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/channels.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../lap_focus/lap_focus.dart';
import 'corner_chart.dart';
import 'lap_chart.dart';
import 'lap_selection.dart';
import 'stage_view.dart';

class TraceFocusTarget implements LapFocusTarget {
  const TraceFocusTarget();

  @override
  String get route => '/trace';

  @override
  String get label => 'Trace';

  @override
  IconData get icon => Icons.show_chart;

  @override
  void apply(WidgetRef ref, LapFocus focus) {
    ref.read(selectedLapIndexProvider(focus.source).notifier).select(focus.lap);
    if (focus.reference case final reference?) {
      ref
          .read(referenceLapIndexProvider(focus.source).notifier)
          .select(reference);
    }
    if (focus.tab case final tab?) {
      ref.read(traceTabProvider.notifier).selectId(tab);
    }
    if (focus.corner case final corner?) {
      ref.read(cornerFocusProvider.notifier).select(corner);
    }
    if (tyreTempOf(focus.channel) case final temp?) {
      ref.read(tyreTempProvider.notifier).select(temp);
    }
    ref.read(stageArrivalProvider.notifier).arrive();
  }
}

/// The Tyres tab's temperature that shows [channel], or null for a channel
/// that is not a tyre temperature.
TyreTemp? tyreTempOf(String? channel) => switch (channel) {
  Channels.tyresTempLeft ||
  Channels.tyresTempCentre ||
  Channels.tyresTempRight => TyreTemp.surface,
  Channels.tyresCarcassTemp => TyreTemp.carcass,
  Channels.tyresRimTemp => TyreTemp.rim,
  _ => null,
};

const traceFocusTarget = TraceFocusTarget();

/// How much lap a point alone is framed with: a site's approach and exit,
/// about what a corner takes.
const pointFrameMetres = 300.0;

/// Where [focus] puts the playhead on [chart], and the window it frames, in
/// the chart's domain; both null when the lap has no usable distance axis to
/// turn metres into it.
({double? playhead, ChartViewport? window}) traceFraming(
  LapChart chart,
  LapFocus focus,
) {
  final axis = chart.distanceAxis;
  final point = focus.point;
  if (axis == null || !axis.isUsable || point == null) {
    return (playhead: null, window: null);
  }
  double domain(double station) => switch (chart.axis) {
    TraceAxis.distance => station,
    TraceAxis.time => axis.timeAt(station),
  };
  final stretch =
      focus.window ??
      (start: point - pointFrameMetres / 2, end: point + pointFrameMetres / 2);
  final a = domain(stretch.start);
  final b = domain(stretch.end);
  return (
    playhead: domain(focus.station ?? stretch.start),
    window: b > a ? ChartViewport(a, b) : null,
  );
}

/// [source]'s lap on [chart] as the stage is showing it: at the playhead,
/// or the whole lap without one.
///
/// From [tab], it carries the tab's id, and for a per-corner tab the
/// [corner] it follows and the [channel] it shows.
LapFocus stageFocus(
  TelemetrySource source,
  LapChart chart,
  ChartSyncState sync, {
  String? tab,
  Corner? corner,
  String? channel,
}) {
  final playhead = sync.playhead;
  return LapFocus(
    source: source,
    lap: chart.lap.index,
    station: playhead == null ? null : stationAt(chart, playhead),
    tab: tab,
    corner: corner,
    channel: channel,
  );
}

/// What the stage is showing, as a focus for the open tab's detail link:
/// the playhead, and on Tyres and Brakes the corner and the quantity.
LapFocus stageFocusFor(
  WidgetRef ref,
  TelemetrySource source,
  LapChart chart,
  TraceTab tab,
) {
  final perCorner = tab == tyresTab || tab == brakesTab;
  final sync = ref.read(chartSyncProvider);
  final focus = stageFocus(
    source,
    chart,
    sync,
    tab: tab.id,
    corner: perCorner ? ref.read(cornerFocusProvider) : null,
    channel: switch (tab.id) {
      'tyres' => ref.read(tyreTempProvider).channel,
      'brakes' => Channels.brakesTemp,
      // Lands on Technique's G-G panel.
      'dynamics' => Channels.gForceLong,
      _ => null,
    },
  );
  return LapFocus(
    source: focus.source,
    lap: focus.lap,
    station: focus.station,
    tab: focus.tab,
    corner: focus.corner,
    channel: focus.channel,
    back: stageReturn(chart, focus, sync.viewport),
  );
}

/// The way back to the stage from a detail screen: the same lap, tab and
/// playhead, and the trace window the user had zoomed to, or the whole lap.
LapFocusReturn stageReturn(
  LapChart chart,
  LapFocus focus,
  ChartViewport? viewport,
) {
  // Unzoomed, the whole lap: a bare station would land framed on 300 m.
  final shown = viewport ?? chart.bounds;
  final start = stationAt(chart, shown.start);
  final end = stationAt(chart, shown.end);
  final station = focus.station;
  return LapFocusReturn(
    target: traceFocusTarget,
    focus: LapFocus(
      source: focus.source,
      lap: focus.lap,
      reference: chart.comparison?.reference.index,
      station: station,
      window: start != null && end != null ? (start: start, end: end) : null,
      tab: focus.tab,
      corner: focus.corner,
      channel: focus.channel,
    ),
    label: station == null
        ? traceFocusTarget.label
        : '${traceFocusTarget.label} · ${station.round()} m',
  );
}

/// The `Lap Dist` metres at [domain] on [chart]; null when the lap has no
/// usable distance axis.
double? stationAt(LapChart chart, double domain) {
  final axis = chart.distanceAxis;
  if (axis == null || !axis.isUsable) return null;
  return switch (chart.axis) {
    TraceAxis.distance => domain,
    TraceAxis.time => axis.distanceAt(domain),
  };
}
