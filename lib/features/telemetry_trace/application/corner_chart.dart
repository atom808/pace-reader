/// One lap's tyres and brakes, shaped for the Tyres and Brakes dock tabs
/// (map stage proposal §6.1): a panel per corner per quantity, on the same
/// axis, playhead and window as the Inputs tab, with the reference lap
/// dotted under each.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/channels.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_corner_telemetry.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/color_tokens.dart';
import 'lap_chart.dart';

/// Which tyre temperature the Tyres tab shows under each pressure.
enum TyreTemp {
  /// The tread's three zones averaged: the figure Tires & Brakes calls tread.
  surface('Surface', 'Tread surface: inner, centre and outer averaged'),
  carcass('Carcass', 'Carcass: the slow temperature under the tread'),
  rim('Rim', 'Rim: the wheel, heated mostly by the brake');

  const TyreTemp(this.label, this.description);

  final String label;
  final String description;

  /// The channel this shows, as `Channels` names it; the surface is built
  /// from the three tread zones and names the centre.
  String get channel => switch (this) {
    surface => Channels.tyresTempCentre,
    carcass => Channels.tyresCarcassTemp,
    rim => Channels.tyresRimTemp,
  };
}

/// What the map's line can be coloured by on these tabs, for one corner.
enum CornerQuantity {
  surface('Surface temp', Channels.tyresTempCentre),
  pressure('Pressure', Channels.tyresPressure),
  brake('Brake temp', Channels.brakesTemp);

  const CornerQuantity(this.label, this.channel);

  final String label;
  final String channel;
}

/// One lap's corners on the chart's axis.
class CornerChart {
  CornerChart({
    required this.pressure,
    required this.temperature,
    required this.brakes,
    required this.colouring,
    required this.trackPath,
    this.brakeBias,
    this.flat = const {},
  });

  /// Corner → its pressure panel; empty in a file without the channel.
  final Map<Corner, TracePanelSpec> pressure;

  /// The temperatures this lap has, each by corner.
  final Map<TyreTemp, Map<Corner, TracePanelSpec>> temperature;

  /// Corner → its brake temperature panel.
  final Map<Corner, TracePanelSpec> brakes;

  /// The front share of the brake bias, as the setup writes it.
  final TracePanelSpec? brakeBias;

  /// Channels the file carries that never moved this lap.
  final Set<String> flat;

  /// The plot the line is coloured from, by quantity and corner.
  final Map<CornerQuantity, Map<Corner, TracePlot>> colouring;

  /// The lap's line, which [colourPath] recolours.
  final TrackPath? trackPath;

  final _paths = <(CornerQuantity, Corner), TrackPath>{};

  bool get hasTyres => pressure.isNotEmpty || temperature.isNotEmpty;
  bool get hasBrakes => brakes.isNotEmpty;

  /// The line coloured by [quantity] at [corner], or null when the lap has
  /// no line or no such channel. Built once per choice, so the map's
  /// colouring keeps its identity across rebuilds.
  TrackPath? colourPath(CornerQuantity quantity, Corner corner) {
    final path = trackPath;
    final plot = colouring[quantity]?[corner];
    if (path == null || plot == null) return null;
    return _paths[(quantity, corner)] ??= path.recoloured(plot);
  }
}

/// `(source, lap, reference)`, as `lapChartProvider` is keyed.
typedef CornerChartKey = (TelemetrySource, int, int?);

/// The key of [chart]'s corners: the lap and the reference it shows.
CornerChartKey cornerChartKey(TelemetrySource source, LapChart chart) =>
    (source, chart.lap.index, chart.comparison?.reference.index);

final lapCornerChartProvider = FutureProvider.autoDispose
    .family<CornerChart, CornerChartKey>((ref, key) async {
      final (source, lapIndex, referenceIndex) = key;
      final chart = await ref.watch(
        lapChartProvider(source, lapIndex, referenceIndex).future,
      );
      final lap = await ref.watch(
        lapCornerTelemetryProvider((source, lapIndex)).future,
      );
      final comparison = chart.comparison;
      final reference = comparison != null && comparison.overlaid
          ? await ref.watch(
              lapCornerTelemetryProvider((
                comparison.target.source,
                comparison.reference.index,
              )).future,
            )
          : null;
      return buildCornerChart(chart, lap, reference: reference);
    }, retry: (_, _) => null);

/// [lap]'s corners on [chart]'s axis, with [reference]'s dotted under them.
CornerChart buildCornerChart(
  LapChart chart,
  LapCornerTelemetry lap, {
  LapCornerTelemetry? reference,
}) {
  final comparison = chart.comparison;

  TracePlot plot(TraceSeries series, String label) => TracePlot.fromSeries(
    series,
    axis: chart.axis,
    distanceAxis: chart.distanceAxis,
    label: label,
  );
  TracePlot? referencePlot(TraceSeries? series, String label) =>
      series == null || series.isEmpty || comparison == null
      ? null
      : TracePlot.fromSeries(
          series,
          axis: chart.axis,
          distanceAxis: comparison.referenceAxis,
          label: label,
          timeShift: comparison.timeShift,
        );

  Map<Corner, TraceSeries>? surface(LapCornerTelemetry from) => _surface(
    from[Channels.tyresTempLeft],
    from[Channels.tyresTempCentre],
    from[Channels.tyresTempRight],
  );

  Map<Corner, TraceSeries>? seriesOf(LapCornerTelemetry from, String name) =>
      name == Channels.tyresTempCentre ? surface(from) : from[name];

  /// [title] heads the panel, short enough for a quarter of the dock;
  /// [name] is the plot's, which the map's legend reads where nothing says
  /// what the panel is a part of.
  Map<Corner, TracePanelSpec> panels(
    String channel,
    String title, {
    String? name,
    required int decimals,
    required ChannelRole role,
  }) {
    final own = seriesOf(lap, channel);
    if (own == null) return const {};
    final theirs = reference == null ? null : seriesOf(reference, channel);
    return {
      for (final MapEntry(key: corner, value: raw) in own.entries)
        if (_displayed(raw) case final series)
          corner: TracePanelSpec(
            title: title,
            unit: series.unit,
            role: role,
            decimals: decimals,
            series: LineSeries(
              plot(series, name ?? title),
              reference: switch (theirs?[corner]) {
                final r? => referencePlot(_displayed(r), name ?? title),
                null => null,
              },
            ),
          ),
    };
  }

  final temperature = {
    for (final t in TyreTemp.values)
      if (panels(
            t.channel,
            t.label,
            name: '${t.label} temp',
            decimals: 1,
            role: ChannelRole.tyre,
          )
          case final byCorner when byCorner.isNotEmpty)
        t: byCorner,
  };

  final bias = lap.brakeBiasRear;
  final pressure = panels(
    Channels.tyresPressure,
    'Pressure',
    decimals: 1,
    role: ChannelRole.tyre,
  );
  final brakes = panels(
    Channels.brakesTemp,
    'Brake temp',
    decimals: 0,
    role: ChannelRole.brake,
  );

  Map<Corner, TracePlot> plots(Map<Corner, TracePanelSpec> from) => {
    for (final MapEntry(key: corner, value: panel) in from.entries)
      if (panel.series case LineSeries(:final plot)) corner: plot,
  };

  return CornerChart(
    pressure: pressure,
    temperature: temperature,
    brakes: brakes,
    flat: lap.flat,
    trackPath: chart.trackPath,
    colouring: {
      CornerQuantity.surface: plots(temperature[TyreTemp.surface] ?? const {}),
      CornerQuantity.pressure: plots(pressure),
      CornerQuantity.brake: plots(brakes),
    },
    brakeBias: bias == null || bias.isEmpty
        ? null
        : TracePanelSpec(
            title: 'Brake bias',
            unit: '% front',
            role: ChannelRole.brake,
            decimals: 1,
            series: StepSeriesPanel(
              StepPlot.fromSeries(
                _frontShare(bias),
                axis: chart.axis,
                window: ChartViewport(
                  chart.telemetry.startSeconds,
                  chart.telemetry.endSeconds,
                ),
                distanceAxis: chart.distanceAxis,
                label: 'Brake bias',
              ),
            ),
          ),
  );
}

/// [series] in the unit it is shown in: the catalog writes temperatures as
/// `C`, and the panels, the axis and the map's legend all say °C.
TraceSeries _displayed(TraceSeries series) => series.unit != 'C'
    ? series
    : TraceSeries(
        channelName: series.channelName,
        unit: '°C',
        frequencyHz: series.frequencyHz,
        valueColumn: series.valueColumn,
        times: series.times,
        lows: series.lows,
        highs: series.highs,
      );

/// `Brake Bias Rear` holds the rear share; the setup and Tires & Brakes show
/// the front's, as a percentage.
StepSeries _frontShare(StepSeries rear) => StepSeries(
  eventName: rear.eventName,
  unit: '%',
  times: rear.times,
  values: Float64List.fromList([for (final v in rear.values) (1 - v) * 100]),
);

/// The tread's three zones averaged per corner, sample by sample — the
/// surface figure Tires & Brakes reads as tread. Null unless all three are
/// there on one clock.
Map<Corner, TraceSeries>? _surface(
  Map<Corner, TraceSeries>? left,
  Map<Corner, TraceSeries>? centre,
  Map<Corner, TraceSeries>? right,
) {
  if (left == null || centre == null || right == null) return null;
  final out = <Corner, TraceSeries>{};
  for (final corner in Corner.values) {
    final l = left[corner];
    final c = centre[corner];
    final r = right[corner];
    if (l == null || c == null || r == null) return null;
    if (l.length != c.length || r.length != c.length) return null;
    final n = c.length;
    final lows = Float64List(n);
    final highs = Float64List(n);
    for (var i = 0; i < n; i++) {
      lows[i] = (l.lows[i] + c.lows[i] + r.lows[i]) / 3;
      highs[i] = (l.highs[i] + c.highs[i] + r.highs[i]) / 3;
    }
    out[corner] = TraceSeries(
      channelName: 'Tyre surface',
      unit: c.unit,
      frequencyHz: c.frequencyHz,
      valueColumn: c.valueColumn,
      times: c.times,
      lows: lows,
      highs: highs,
    );
  }
  return out;
}
