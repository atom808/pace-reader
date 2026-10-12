/// The panes of the synced lap view (SPEC.md §8.4, §8.5, §9.5): the panel
/// stack, its axis footer and the map beside it.
///
/// Shared by Trace and Compare (comparison proposal §3), which draw one lap
/// against another the same way: Compare's left column *is* Trace's stack,
/// fed a chart whose reference may come from another file.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/lap_chart.dart';

class LapPanelStack extends StatelessWidget {
  const LapPanelStack({super.key, required this.chart, this.below});

  final LapChart chart;

  /// A row to show under a panel — a toggle that belongs to it, or why a
  /// panel that would follow it is missing — or null for none.
  final Widget? Function(TracePanelSpec panel)? below;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelColors.resolve(context);
    final panels = chart.panels;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        for (var i = 0; i < panels.length; i++) ...[
          TracePanel(
            key: ValueKey(panels[i].title),
            series: panels[i].series,
            bounds: chart.bounds,
            color: channels.of(panels[i].role),
            title: panels[i].title,
            unit: panels[i].unit,
            markers: chart.traceMarkers,
            // The bottom panel alone carries the domain readout, so the
            // cursor answers "where in the lap" once rather than six times.
            showDomainReadout: i == panels.length - 1,
            formatValue: valueFormatter(panels[i]),
            formatDomain: (domain) => formatDomain(chart, domain),
          ),
          ?below?.call(panels[i]),
        ],
        const SizedBox(height: 8),
        LapAxisFooter(chart: chart),
      ],
    );
  }
}

/// Formats a channel value for its axis and cursor readout.
String Function(double) valueFormatter(TracePanelSpec panel) {
  // Signed, always: "0.214" next to a zero line reads as neither gained nor
  // lost until the reader works out which side of it the trace is on.
  if (panel.role == ChannelRole.delta) return formatDelta;
  if (panel.role == ChannelRole.line) {
    // Metres either side of Base, or of the centre path: signed for the same
    // reason as the delta.
    return (value) {
      final text = value.toStringAsFixed(panel.decimals);
      if (double.parse(text) == 0) return 0.0.toStringAsFixed(panel.decimals);
      return value > 0 ? '+$text' : text;
    };
  }
  if (panel.role == ChannelRole.gear) {
    // Neutral is recorded as gear 0 (§5.1's `Gear` event is a TINYINT from 0),
    // and "0" would read as a gear the car doesn't have.
    return (value) => value <= 0 ? 'N' : value.toStringAsFixed(0);
  }
  return (value) => value.toStringAsFixed(panel.decimals);
}

/// Formats a domain position for the cursor readout and the axis footer.
///
/// Time is shown relative to the lap start rather than as the file's own
/// elapsed seconds: the recording clock starts when telemetry was armed and
/// sits at 23.6 s / 34.6 s / 381.1 s across the three samples (§5.2), so an
/// absolute value tells the user nothing about where they are in the lap.
String formatDomain(LapChart chart, double domain) => switch (chart.axis) {
  TraceAxis.distance => '${domain.toStringAsFixed(0)} m',
  TraceAxis.time => formatSectorTime(domain - chart.telemetry.startSeconds),
};

class LapAxisFooter extends ConsumerWidget {
  const LapAxisFooter({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final viewport = sync.visible(chart.bounds);
    final zoom = viewport.zoomFactorWithin(chart.bounds);

    return Row(
      children: [
        Text(formatDomain(chart, viewport.start), style: _style(theme)),
        const Spacer(),
        Text(
          zoom > 1.02
              ? '${chart.axis.label} · ${zoom.toStringAsFixed(1)}× — '
                    'scroll to zoom, drag to pan, double-click to fit'
              : '${chart.axis.label} · scroll to zoom, drag to pan',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(formatDomain(chart, viewport.end), style: _style(theme)),
      ],
    );
  }

  TextStyle _style(ThemeData theme) => AppTextStyles.numeral.copyWith(
    fontSize: 11,
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// The map beside the panels, sharing their cursor.
///
/// Present here rather than only on its own screen because §9.7 asks for
/// desktop-class multi-pane layouts specifically so trace and map can be read
/// together — and because a shared cursor is only visibly shared when both
/// things it drives are on screen at once.
class LapTrackMapPane extends ConsumerWidget {
  const LapTrackMapPane({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ChannelColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Track map', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Expanded(
            child: TrackMapView(
              path: chart.trackPath!,
              color: channels.of(chart.trackColorRole),
              markers: chart.trackMarkers,
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }
}
