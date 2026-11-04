/// The Tyres and Brakes dock tabs (map stage proposal §6.1): each corner of
/// the car in its place, on the same playhead and window as every other
/// panel.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/corner_chart.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
import 'dock_tab_parts.dart';
import 'lap_view_panes.dart';

/// Pressure over a temperature, per corner; a chip picks the temperature.
class TyresTab extends ConsumerWidget {
  const TyresTab({super.key, required this.source, required this.chart});

  final TelemetrySource source;
  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CornerTab(
    source: source,
    chart: chart,
    body: (corners) {
      if (!corners.hasTyres) {
        return [
          TraceStackRow.fixed(
            _note(context, 'This lap holds no tyre reading.', corners),
          ),
        ];
      }
      final available = corners.temperature.keys.toList();
      final chosen = ref.watch(tyreTempProvider);
      final temp = available.contains(chosen) ? chosen : available.firstOrNull;
      final channels = ChannelColors.resolve(context);
      return [
        if (available.length > 1 && temp != null)
          TraceStackRow.fixed(
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<TyreTemp>(
                key: const ValueKey('tyre-temp'),
                segments: [
                  for (final t in available)
                    ButtonSegment(
                      value: t,
                      label: Text(t.label),
                      tooltip: t.description,
                    ),
                ],
                selected: {temp},
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
                ),
                onSelectionChanged: (s) =>
                    ref.read(tyreTempProvider.notifier).select(s.first),
              ),
            ),
          ),
        TraceStackRow.corners(
          perCell: temp == null ? 1 : 2,
          CornerPanelGrid(
            cell: (corner) => [
              if (corners.pressure[corner] case final p?)
                lapTracePanel(chart, p, channels: channels),
              if (temp != null)
                if (corners.temperature[temp]?[corner] case final t?)
                  lapTracePanel(chart, t, channels: channels),
            ],
          ),
        ),
        if (corners.flat.isNotEmpty)
          TraceStackRow.fixed(_note(context, null, corners)),
      ];
    },
  );
}

/// Brake temperature per corner, then the pedal and the bias that put the
/// heat there.
class BrakesTab extends ConsumerWidget {
  const BrakesTab({super.key, required this.source, required this.chart});

  final TelemetrySource source;
  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CornerTab(
    source: source,
    chart: chart,
    body: (corners) {
      final channels = ChannelColors.resolve(context);
      final pedal = chart.panels
          .where((p) => p.role == ChannelRole.brake)
          .firstOrNull;
      final bias = corners.brakeBias;
      return [
        if (!corners.hasBrakes)
          TraceStackRow.fixed(
            _note(context, 'This lap holds no brake temperature.', corners),
          )
        else
          TraceStackRow.corners(
            perCell: 1,
            CornerPanelGrid(
              cell: (corner) => [
                if (corners.brakes[corner] case final b?)
                  lapTracePanel(chart, b, channels: channels),
              ],
            ),
          ),
        if (pedal != null)
          TraceStackRow.panels(
            lapTracePanel(
              chart,
              pedal,
              channels: channels,
              showDomainReadout: bias == null,
            ),
          ),
        if (bias != null)
          TraceStackRow.panels(
            lapTracePanel(
              chart,
              bias,
              channels: channels,
              showDomainReadout: true,
            ),
          ),
      ];
    },
  );
}

/// What both tabs share: the lap's corners read on first open, a quiet
/// placeholder until then, and the panels arriving in a stagger.
class _CornerTab extends ConsumerWidget {
  const _CornerTab({
    required this.source,
    required this.chart,
    required this.body,
  });

  final TelemetrySource source;
  final LapChart chart;
  final List<TraceStackRow> Function(CornerChart corners) body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<CornerChart>(
      value: ref.watch(lapCornerChartProvider(cornerChartKey(source, chart))),
      loading: (context) => const DockTabLoading(),
      data: (context, corners) => DockTabList(rows: body(corners)),
    );
  }
}

Widget _note(BuildContext context, String? message, CornerChart corners) =>
    dockTabNote(context, message, corners.flat);
