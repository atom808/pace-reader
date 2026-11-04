/// Trace as a [LapFocusTarget] (map stage proposal §6.4): a lap opens on the
/// stage with the car at the point another screen pointed at and the traces
/// framed on its stretch.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/charting/charting.dart';
import '../../lap_focus/lap_focus.dart';
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
  }
}

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
LapFocus stageFocus(
  TelemetrySource source,
  LapChart chart,
  ChartSyncState sync,
) {
  final playhead = sync.playhead;
  return LapFocus(
    source: source,
    lap: chart.lap.index,
    station: playhead == null ? null : stationAt(chart, playhead),
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
