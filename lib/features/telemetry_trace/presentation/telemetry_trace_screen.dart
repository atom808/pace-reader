import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/lap_chart.dart';
import '../application/lap_selection.dart';
import 'lap_view_controls.dart';

/// Telemetry Traces (SPEC.md §8.4).
///
/// Stacked single-channel panels sharing one axis, one viewport and one scrub
/// cursor with each other and with the track map beside them — the shape both
/// reference apps converge on (§7.1) and the reason §9.5 built a custom chart
/// core instead of reaching for a chart library.
///
/// One channel per panel, deliberately. Overlaying channels of different
/// units on one pair of axes is the single most common way a telemetry chart
/// misleads: two signals with unrelated scales share a baseline, and the
/// crossings a reader sees are artefacts of the scaling. Stacked panels
/// against a shared x-axis say the same thing without inventing any of it.
class TelemetryTraceScreen extends ConsumerWidget {
  const TelemetryTraceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Telemetry trace',
        subject: 'the trace view',
      );
    }
    return _TraceScaffold(source: source);
  }
}

class _TraceScaffold extends ConsumerWidget {
  const _TraceScaffold({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchLapChanges(ref, source);
    final lap = ref.watch(displayedLapProvider(source));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetry trace'),
        actions: [
          LapPicker(source: source, selected: lap.value),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<Lap?>(
        value: lap,
        data: (context, lap) => lap == null
            ? const _NoLaps()
            : _LapTrace(source: source, lapIndex: lap.index),
      ),
    );
  }
}

class _LapTrace extends ConsumerWidget {
  const _LapTrace({required this.source, required this.lapIndex});

  final TelemetrySource source;
  final int lapIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<LapChart>(
      value: ref.watch(lapChartProvider(source, lapIndex)),
      data: (context, chart) =>
          chart.panels.isEmpty ? const _NoChannels() : _TraceBody(chart: chart),
    );
  }
}

class _TraceBody extends StatelessWidget {
  const _TraceBody({required this.chart});

  final LapChart chart;

  /// Below this the side pane costs the panels more width than the map is
  /// worth; the map is a click away on its own screen either way.
  static const _sidePaneBreakpoint = 1080.0;
  static const _sidePaneWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidePane = constraints.maxWidth >= _sidePaneBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A Wrap rather than a Row: on a narrow window the summary and
            // the controls together exceed the width, and dropping the
            // controls to a second line beats clipping one off the edge.
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  LapSummaryBar(chart: chart),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AxisToggle(chart: chart),
                      const ZoomResetButton(),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _PanelStack(chart: chart)),
                  if (showSidePane && chart.hasTrackMap) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: _sidePaneWidth,
                      child: _TrackMapPane(chart: chart),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PanelStack extends StatelessWidget {
  const _PanelStack({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelColors.resolve(context);
    final panels = chart.panels;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      children: [
        for (var i = 0; i < panels.length; i++)
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
        const SizedBox(height: 8),
        _AxisFooter(chart: chart),
      ],
    );
  }
}

/// Formats a channel value for its axis and cursor readout.
String Function(double) valueFormatter(TracePanelSpec panel) {
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
      TraceAxis.time =>
        formatSectorTime(domain - chart.telemetry.startSeconds),
    };

class _AxisFooter extends ConsumerWidget {
  const _AxisFooter({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sync = ref.watch(chartSyncProvider);
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
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
class _TrackMapPane extends ConsumerWidget {
  const _TrackMapPane({required this.chart});

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

class _NoLaps extends StatelessWidget {
  const _NoLaps();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'This session recorded no laps to trace.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

class _NoChannels extends StatelessWidget {
  const _NoChannels();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No traceable channels in this lap',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The recording carries none of the channels this view plots, or '
              'none of them have samples inside this lap.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
