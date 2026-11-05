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
  const LapPanelStack({
    super.key,
    required this.chart,
    this.below,
    this.footer = true,
  });

  final LapChart chart;

  /// A row to show under a panel — a toggle that belongs to it, or why a
  /// panel that would follow it is missing — or null for none.
  final Widget? Function(TracePanelSpec panel)? below;

  /// Ends the list with the axis footer. Off where the footer is pinned
  /// under the list instead, as on the stage's dock.
  final bool footer;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelColors.resolve(context);
    final panels = chart.panels;

    // The panels share the height they are given (P9a).
    return TraceStack(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      rows: [
        for (var i = 0; i < panels.length; i++) ...[
          TraceStackRow.panels(
            StaggeredEntrance(
              index: i,
              child: lapTracePanel(
                chart,
                panels[i],
                channels: channels,
                // The bottom panel alone carries the domain readout, so the
                // cursor answers "where in the lap" once rather than six
                // times.
                showDomainReadout: i == panels.length - 1,
              ),
            ),
          ),
          if (below?.call(panels[i]) case final row?)
            TraceStackRow.fixed(row),
        ],
        if (footer) TraceStackRow.fixed(LapAxisFooter(chart: chart)),
      ],
    );
  }
}

/// [panel] of [chart] as a [TracePanel]: on the chart's bounds, markers and
/// axis, in its role's colour. Every tab's panels are built here.
TracePanel lapTracePanel(
  LapChart chart,
  TracePanelSpec panel, {
  required ChannelColors channels,
  bool showDomainReadout = false,
  double? height,
  List<(double, String)>? markers,
  Key? key,
}) => TracePanel(
  key: key ?? ValueKey(panel.title),
  series: panel.series,
  bounds: chart.bounds,
  color: channels.of(panel.role),
  title: panel.title,
  unit: panel.unit,
  height: height,
  markers: markers ?? chart.traceMarkers,
  showDomainReadout: showDomainReadout,
  fitToWindow: !panel.fixedScale,
  peaks: panel.peaks,
  formatValue: valueFormatter(panel),
  formatDomain: (domain) => formatDomain(chart, domain),
);

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
        const SizedBox(width: 12),
        // The hint gives way first: in a narrow dock the window's ends are
        // the reading, the hint only a reminder.
        Expanded(
          child: Text(
            zoom > 1.02
                ? '${chart.axis.label} · ${zoom.toStringAsFixed(1)}× — '
                      'Ctrl+scroll to zoom, Shift+scroll or drag to pan, '
                      'double-click to fit'
                : '${chart.axis.label} · Ctrl+scroll to zoom, drag to pan',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(formatDomain(chart, viewport.end), style: _style(theme)),
      ],
    );
  }

  TextStyle _style(ThemeData theme) => AppTextStyles.numeral.copyWith(
    fontSize: 11,
    color: theme.colorScheme.onSurfaceVariant,
  );
}

/// How a lap's map stage colours its line.
enum LapLineColour {
  /// What the feet were doing: the stage's default (map stage proposal D7).
  pedals,

  /// The track map channel's magnitude, on its own hue (§8.5).
  channel,
}

/// How a lap's line is coloured, and the key that explains it: the one place
/// a [LapChart] becomes a [LineColouring], for the stages of Trace and Compare.
class LapLineStyle {
  const LapLineStyle._(this.colouring, this.legend);

  factory LapLineStyle.of(
    BuildContext context,
    LapChart chart, {
    LapLineColour colour = LapLineColour.pedals,
    String Function(double)? formatValue,
  }) {
    final theme = Theme.of(context);
    final channels = ChannelColors.resolve(context);
    final path = chart.trackPath!;
    final pedals = chart.trackPedals;
    if (colour == LapLineColour.pedals && pedals != null) {
      final colours = PedalColours(
        throttle: channels.throttle,
        brake: channels.brake,
        coast: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
      );
      return LapLineStyle._(
        PedalColouring(pedals, colours),
        PedalLegend(colours: colours),
      );
    }
    return LapLineStyle.ramp(
      context,
      path,
      role: chart.trackColorRole,
      formatValue: formatValue,
    );
  }

  /// [path]'s own values on [role]'s hue: a channel, or a corner's
  /// temperature or pressure on the Tyres and Brakes tabs.
  factory LapLineStyle.ramp(
    BuildContext context,
    TrackPath path, {
    required ChannelRole role,
    String Function(double)? formatValue,
  }) {
    final hue = ChannelColors.resolve(context).of(role);
    final ramp = ValueRamp(hue);
    return LapLineStyle._(
      RampColouring(path, ramp, fallback: hue),
      path.hasColouring
          ? RampLegend(
              ramp: ramp,
              path: path,
              format: formatValue ?? (v) => v.toStringAsFixed(0),
            )
          : null,
    );
  }

  final LineColouring colouring;

  /// What the colours mean; null when the line carries no reading.
  final Widget? legend;
}
