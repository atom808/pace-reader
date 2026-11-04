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
        if (footer) ...[const SizedBox(height: 8), LapAxisFooter(chart: chart)],
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

/// The map beside the panels, on the same playhead and probe.
///
/// Present here rather than only on its own screen because §9.7 asks for
/// desktop-class multi-pane layouts specifically so trace and map can be read
/// together — and because a shared playhead is only visibly shared when both
/// things it drives are on screen at once.
class LapTrackMapPane extends StatelessWidget {
  const LapTrackMapPane({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Track map', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Expanded(child: LapMapStage(chart: chart, strokeWidth: 3)),
        ],
      ),
    );
  }
}

/// How a lap's map stage colours its line.
enum LapLineColour {
  /// What the feet were doing: the stage's default (map stage proposal D7).
  pedals,

  /// The track map channel's magnitude, on its own hue (§8.5).
  channel,
}

/// How a lap's line is coloured, and the key that explains it: the one place
/// a [LapChart] becomes a [LineColouring], for the inset map and the stage.
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
    final hue = channels.of(chart.trackColorRole);
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

/// A lap on the map stage in a frame, with its legend under it: the map
/// beside the panels where the window is too narrow for the full stage.
class LapMapStage extends StatelessWidget {
  const LapMapStage({
    super.key,
    required this.chart,
    this.colour = LapLineColour.pedals,
    this.strokeWidth = 4,
    this.formatValue,
  });

  final LapChart chart;
  final LapLineColour colour;
  final double strokeWidth;

  /// The ramp legend's numerals, under [LapLineColour.channel].
  final String Function(double)? formatValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = LapLineStyle.of(
      context,
      chart,
      colour: colour,
      formatValue: formatValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              shape: AppRadii.squircle(AppRadii.md),
            ),
            child: ClipPath(
              clipper: ShapeBorderClipper(
                shape: AppRadii.squircle(AppRadii.md),
              ),
              child: MapStage(
                path: chart.trackPath!,
                colouring: style.colouring,
                markers: chart.trackMarkers,
                alignment: chart.comparison == null ? null : chart.alignment,
                strokeWidth: strokeWidth,
              ),
            ),
          ),
        ),
        if (style.legend case final legend?) ...[
          const SizedBox(height: 10),
          legend,
        ],
      ],
    );
  }
}
