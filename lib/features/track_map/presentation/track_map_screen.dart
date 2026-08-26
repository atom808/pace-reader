import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
// One-way, deliberate: §9.5 makes the track map and the trace panels a single
// synced system, so they share one lap selection, one axis and one view model
// rather than each building its own (see `lap_view_controls.dart`).
import '../../telemetry_trace/application/lap_chart.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../../telemetry_trace/presentation/lap_view_controls.dart';
import '../../telemetry_trace/presentation/telemetry_trace_screen.dart';

/// Track Map (SPEC.md §8.5).
///
/// The circuit drawn from `GPS Latitude`/`GPS Longitude`, coloured by a
/// selected channel, with the same scrub cursor the trace panels use. The
/// coordinates are a local frame rather than a geographic one — see
/// [TrackProjection] — so this is a shape of the circuit, never a map of
/// where it is.
class TrackMapScreen extends ConsumerWidget {
  const TrackMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Track map',
        subject: 'the track map',
      );
    }
    return _TrackMapScaffold(source: source);
  }
}

class _TrackMapScaffold extends ConsumerWidget {
  const _TrackMapScaffold({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    watchLapChanges(ref, source);
    final lap = ref.watch(displayedLapProvider(source));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track map'),
        actions: [
          LapPicker(source: source, selected: lap.value),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<Lap?>(
        value: lap,
        data: (context, lap) => lap == null
            ? const _NoLaps()
            : _LapMap(source: source, lapIndex: lap.index),
      ),
    );
  }
}

class _LapMap extends ConsumerWidget {
  const _LapMap({required this.source, required this.lapIndex});

  final TelemetrySource source;
  final int lapIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<LapChart>(
      value: ref.watch(lapChartProvider(source, lapIndex)),
      data: (context, chart) =>
          chart.hasTrackMap ? _MapBody(chart: chart) : const _NoPosition(),
    );
  }
}

class _MapBody extends ConsumerWidget {
  const _MapBody({required this.chart});

  final LapChart chart;

  /// Below this the trace strip alongside the map leaves neither enough room.
  static const _traceStripBreakpoint = 1080.0;
  static const _traceStripWidth = 380.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ChannelColors.resolve(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final showTraces = constraints.maxWidth >= _traceStripBreakpoint &&
            chart.panels.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A Wrap rather than a Row: the summary and two segmented
            // controls need more than a 900 px window can give them, and
            // dropping the controls to a second line beats clipping one of
            // them off the right edge.
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
                      const _ColourChannelPicker(),
                      const SizedBox(width: 12),
                      AxisToggle(chart: chart),
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
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: TrackMapView(
                        path: chart.trackPath!,
                        color: channels.of(chart.trackColorRole),
                        markers: chart.trackMarkers,
                        formatValue: (value) => value.toStringAsFixed(0),
                        strokeWidth: 5,
                      ),
                    ),
                  ),
                  if (showTraces) ...[
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: _traceStripWidth,
                      child: _TraceStrip(chart: chart),
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

/// Which channel colours the map (§8.5 names speed, throttle and brake).
class _ColourChannelPicker extends ConsumerWidget {
  const _ColourChannelPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(trackMapChannelProvider);
    return SegmentedButton<String>(
      segments: [
        for (final name in trackMapChannelChoices)
          ButtonSegment(value: name, label: Text(_shortLabel(name))),
      ],
      selected: {selected},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
      ),
      onSelectionChanged: (selection) =>
          ref.read(trackMapChannelProvider.notifier).select(selection.first),
    );
  }

  static String _shortLabel(String channelName) => switch (channelName) {
        'Ground Speed' => 'Speed',
        'Throttle Pos' => 'Throttle',
        'Brake Pos' => 'Brake',
        _ => channelName,
      };
}

/// A few trace panels beside the map, on the same cursor.
///
/// The map answers "where", the traces answer "what the car was doing there",
/// and the shared cursor is what joins them — which only reads as shared when
/// both are visible at once (§9.7's multi-pane reasoning).
class _TraceStrip extends StatelessWidget {
  const _TraceStrip({required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelColors.resolve(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (var i = 0; i < chart.panels.length; i++)
          TracePanel(
            key: ValueKey('strip-${chart.panels[i].title}'),
            series: chart.panels[i].series,
            bounds: chart.bounds,
            color: channels.of(chart.panels[i].role),
            title: chart.panels[i].title,
            unit: chart.panels[i].unit,
            markers: chart.traceMarkers,
            height: 76,
            valueTickCount: 2,
            showDomainReadout: i == chart.panels.length - 1,
            formatValue: valueFormatter(chart.panels[i]),
            formatDomain: (domain) => formatDomain(chart, domain),
          ),
      ],
    );
  }
}

class _NoLaps extends StatelessWidget {
  const _NoLaps();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'This session recorded no laps to map.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}

class _NoPosition extends StatelessWidget {
  const _NoPosition();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 44, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No position data for this lap',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The map is drawn from the recording’s GPS Latitude and GPS '
              'Longitude channels, and this lap has no samples from them.',
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
