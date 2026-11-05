/// The Suspension, Dynamics and Energy dock tabs' panels (map stage
/// proposal §6.1 tabs 4–6): one lap's channels for each, on the same axis,
/// playhead and window as the Inputs tab, with the reference lap dotted
/// under each.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/channels.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_channels.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/color_tokens.dart';
import '../../suspension/domain/sites.dart';
import '../../suspension/domain/strikes.dart';
import 'lap_chart.dart';

/// How one channel is drawn: what its panel is called, its colour, its
/// decimals, and the unit it is shown in when not the file's.
class _Shown {
  const _Shown(
    this.title,
    this.role,
    this.decimals, {
    this.unit,
    this.scale = 1,
    this.peaks,
    this.minRise = 0,
  });

  final String title;
  final ChannelRole role;
  final int decimals;
  final String? unit;

  /// What the file's value is multiplied by to read in [unit].
  final double scale;

  /// Which way its peaks worth clicking point (P9b); null for none.
  final PeakKind? peaks;

  /// The least a peak must rise, in [unit].
  final double minRise;
}

/// Every channel the three tabs draw. The roles reuse the palette rather
/// than add to it: the chassis in the neutral steering grey, the line and
/// lateral G signed in the line's slate, longitudinal G in speed's cyan, and
/// the energy channels in their own colours (§9.7.1).
const _shown = <String, _Shown>{
  // The chassis's peaks are marked for clicking (P9b): a ride height's
  // lowest points, where the car came nearest the ground, and the dampers'
  // and third elements' deepest travel.
  Channels.frontRideHeight: _Shown(
    'Front ride height',
    ChannelRole.steering,
    1,
    unit: 'mm',
    scale: 1000,
    peaks: PeakKind.lows,
    minRise: 3,
  ),
  Channels.rearRideHeight: _Shown(
    'Rear ride height',
    ChannelRole.steering,
    1,
    unit: 'mm',
    scale: 1000,
    peaks: PeakKind.lows,
    minRise: 3,
  ),
  Channels.suspPos: _Shown(
    'Damper',
    ChannelRole.steering,
    1,
    unit: 'mm',
    scale: 1000,
    peaks: PeakKind.highs,
    minRise: 2,
  ),
  Channels.front3rdDeflection: _Shown(
    'Front 3rd element',
    ChannelRole.steering,
    1,
    unit: 'mm',
    scale: 1000,
    peaks: PeakKind.highs,
    minRise: 1,
  ),
  Channels.rear3rdDeflection: _Shown(
    'Rear 3rd element',
    ChannelRole.steering,
    1,
    unit: 'mm',
    scale: 1000,
    peaks: PeakKind.highs,
    minRise: 1,
  ),
  // The file's `G Force Long` is the lateral axis (`Channels`).
  Channels.gForceLong: _Shown('Lateral G', ChannelRole.line, 2, unit: 'g'),
  Channels.gForceLat: _Shown('Longitudinal G', ChannelRole.speed, 2, unit: 'g'),
  Channels.gForceVert: _Shown('Vertical G', ChannelRole.steering, 2, unit: 'g'),
  Channels.pathLateral: _Shown('Line', ChannelRole.line, 1, unit: 'm'),
  Channels.soc: _Shown('State of charge', ChannelRole.charge, 1),
  // Labelled kW by the file, written in watts.
  // Above zero under braking, below it while the hybrid deploys.
  Channels.regenRate: _Shown(
    'Regen / deploy',
    ChannelRole.charge,
    0,
    unit: 'kW',
    scale: 0.001,
  ),
  Channels.virtualEnergy: _Shown('Virtual energy', ChannelRole.energy, 1),
  Channels.fuelLevel: _Shown('Fuel', ChannelRole.fuel, 2),
};

/// The name a panel of [channel] goes by, for a note that a channel never
/// moved.
String channelTitle(String channel) => _shown[channel]?.title ?? channel;

/// One row of a tab: a channel's panel, or a per-corner channel's four.
sealed class ChannelTabRow {
  const ChannelTabRow();
}

class PanelRow extends ChannelTabRow {
  const PanelRow(this.panel);

  final TracePanelSpec panel;
}

class CornerRow extends ChannelTabRow {
  const CornerRow(this.panels);

  final Map<Corner, TracePanelSpec> panels;
}

/// One tab's panels for one lap.
class ChannelTabChart {
  const ChannelTabChart({required this.rows, this.flat = const {}});

  /// In the tab's order.
  final List<ChannelTabRow> rows;

  /// The panel titles of channels the file carries that never moved this
  /// lap.
  final Set<String> flat;

  bool get isEmpty => rows.isEmpty;
}

/// `(source, lap, reference, set)`, as the tab is shown.
typedef ChannelTabKey = (TelemetrySource, int, int?, LapChannelSet);

/// The key of [chart]'s [set]: the lap and the reference it shows.
ChannelTabKey channelTabKey(
  TelemetrySource source,
  LapChart chart,
  LapChannelSet set,
) => (source, chart.lap.index, chart.comparison?.reference.index, set);

final lapChannelTabProvider = FutureProvider.autoDispose
    .family<ChannelTabChart, ChannelTabKey>((ref, key) async {
      final (source, lapIndex, referenceIndex, set) = key;
      final chart = await ref.watch(
        lapChartProvider(source, lapIndex, referenceIndex).future,
      );
      final lap = await ref.watch(
        lapChannelsProvider((source, lapIndex, set)).future,
      );
      final comparison = chart.comparison;
      final reference = comparison != null && comparison.overlaid
          ? await ref.watch(
              lapChannelsProvider((
                comparison.target.source,
                comparison.reference.index,
                set,
              )).future,
            )
          : null;
      return buildChannelTab(chart, lap, set: set, reference: reference);
    }, retry: (_, _) => null);

/// [lap]'s channels of [set] on [chart]'s axis, with [reference]'s dotted
/// under them.
ChannelTabChart buildChannelTab(
  LapChart chart,
  LapChannels lap, {
  required LapChannelSet set,
  LapChannels? reference,
}) {
  final comparison = chart.comparison;

  TracePanelSpec panel(
    String channel,
    TraceSeries own,
    TraceSeries? theirs, {
    String? title,
  }) {
    final shown = _shown[channel];
    final name = title ?? shown?.title ?? channel;
    final series = _inUnit(own, shown);
    final ref = theirs == null || theirs.isEmpty || comparison == null
        ? null
        : TracePlot.fromSeries(
            _inUnit(theirs, shown),
            axis: chart.axis,
            distanceAxis: comparison.referenceAxis,
            label: name,
            timeShift: comparison.timeShift,
          );
    final spec = TracePanelSpec(
      title: name,
      unit: series.unit,
      role: shown?.role ?? ChannelRole.steering,
      decimals: shown?.decimals ?? 1,
      series: LineSeries(
        TracePlot.fromSeries(
          series,
          axis: chart.axis,
          distanceAxis: chart.distanceAxis,
          label: name,
        ),
        reference: ref,
      ),
    );
    return switch (shown?.peaks) {
      final kind? => spec.withPeaks(kind, minRise: shown!.minRise),
      null => spec,
    };
  }

  final rows = <ChannelTabRow>[];
  for (final channel in set.channels) {
    if (lap.single[channel] case final own?) {
      rows.add(PanelRow(panel(channel, own, reference?.single[channel])));
    } else if (lap.corners[channel] case final byCorner?) {
      rows.add(
        CornerRow({
          for (final MapEntry(key: corner, value: own) in byCorner.entries)
            corner: panel(channel, own, reference?.corners[channel]?[corner]),
        }),
      );
    }
  }
  return ChannelTabChart(
    rows: rows,
    flat: {for (final c in lap.flat) channelTitle(c)},
  );
}

/// [series] in [shown]'s unit.
TraceSeries _inUnit(TraceSeries series, _Shown? shown) {
  if (shown == null || (shown.unit == null && shown.scale == 1)) {
    return series;
  }
  Float64List scaled(Float64List values) => shown.scale == 1
      ? values
      : Float64List.fromList([for (final v in values) v * shown.scale]);
  return TraceSeries(
    channelName: series.channelName,
    unit: shown.unit ?? series.unit,
    frequencyHz: series.frequencyHz,
    valueColumn: series.valueColumn,
    times: series.times,
    lows: scaled(series.lows),
    highs: scaled(series.highs),
  );
}

/// Where [chart]'s lap struck the ground at each of [sites], as trace
/// markers: one per site the lap went under the floor at, at its lowest
/// point, named by the corner that went lowest (§6.1's strike sites).
///
/// [named] false leaves the names off, for the panels under the one that
/// carries them: the same name on every panel is noise.
List<(double, String)> strikeMarkers(
  LapChart chart,
  List<Site> sites, {
  bool named = true,
}) {
  final lap = chart.lap.index;
  return [
    for (final site in sites)
      if (site.lapLows[lap] case final low? when low.tier == StrikeTier.strike)
        if (chart.domainOf(low.seconds) case final at?)
          (at, named ? 'Strike ${low.corner.short}' : ''),
  ];
}
