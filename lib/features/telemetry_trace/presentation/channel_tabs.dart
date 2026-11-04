/// The Suspension, Dynamics and Energy dock tabs (map stage proposal §6.1
/// tabs 4–6): one lap's channels down the dock, the dampers laid out like
/// the car, on the same playhead and window as every other panel.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/lap_channels.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../suspension/application/suspension_providers.dart';
import '../application/channel_tabs.dart';
import '../application/lap_chart.dart';
import 'dock_tab_parts.dart';
import 'lap_view_panes.dart';

/// [set]'s channels for [chart]'s lap, with the reference dotted under each.
///
/// On Suspension, every panel marks the lap's strikes, and the top one names
/// them. The marks come from the Suspension screen's read of the session and
/// appear once that read has finished.
class ChannelTab extends ConsumerWidget {
  const ChannelTab({
    super.key,
    required this.source,
    required this.chart,
    required this.set,
  });

  final TelemetrySource source;
  final LapChart chart;
  final LapChannelSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = set == LapChannelSet.suspension
        ? ref.watch(suspensionOverviewProvider(source)).value?.sites
        : null;
    // The top panel names the strikes; the ones under it only mark them.
    final named = [
      ...chart.traceMarkers,
      if (sites != null) ...strikeMarkers(chart, sites),
    ];
    final marked = [
      ...chart.traceMarkers,
      if (sites != null) ...strikeMarkers(chart, sites, named: false),
    ];
    return AsyncValueView<ChannelTabChart>(
      value: ref.watch(
        lapChannelTabProvider(channelTabKey(source, chart, set)),
      ),
      loading: (context) => const DockTabLoading(),
      data: (context, tab) {
        final channels = ChannelColors.resolve(context);
        final rows = tab.rows;
        // The bottom panel alone carries the domain readout, as on Inputs.
        final readout = rows.lastIndexWhere((r) => r is PanelRow);
        TracePanel panel(
          TracePanelSpec spec, {
          double height = 92,
          bool top = false,
          bool readout = false,
        }) => lapTracePanel(
          chart,
          spec,
          channels: channels,
          height: height,
          markers: top ? named : marked,
          showDomainReadout: readout,
        );
        return DockTabList(
          children: [
            if (tab.isEmpty)
              dockTabNote(context, _empty(set), tab.flat, why: _why(set))
            else ...[
              for (var i = 0; i < rows.length; i++)
                switch (rows[i]) {
                  PanelRow(panel: final spec) => panel(
                    spec,
                    top: i == 0,
                    readout: i == readout,
                  ),
                  CornerRow(panels: final byCorner) => CornerPanelGrid(
                    cell: (corner) => [
                      if (byCorner[corner] case final spec?)
                        panel(spec, height: 76, top: i == 0),
                    ],
                  ),
                },
              if (tab.flat.isNotEmpty)
                dockTabNote(context, null, tab.flat, why: _why(set)),
            ],
          ],
        );
      },
    );
  }
}

/// What a lap with none of [set]'s channels moving says instead.
String _empty(LapChannelSet set) => switch (set) {
  LapChannelSet.suspension =>
    'This lap holds no ride height or damper reading.',
  LapChannelSet.dynamics => 'This lap holds no G force reading.',
  LapChannelSet.energy => 'This lap holds no charge, energy or fuel reading.',
};

/// Why [set]'s channels might sit still, when the reason is the car's.
String? _why(LapChannelSet set) => switch (set) {
  LapChannelSet.energy =>
    'A car without a hybrid writes its charge and regen as zeros.',
  _ => null,
};
