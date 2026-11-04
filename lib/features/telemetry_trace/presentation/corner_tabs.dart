/// The Tyres and Brakes dock tabs (map stage proposal §6.1): each corner of
/// the car in its place, on the same playhead and window as every other
/// panel.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/corner_chart.dart';
import '../application/lap_chart.dart';
import '../application/stage_view.dart';
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
        return [_note(context, 'This lap holds no tyre reading.', corners)];
      }
      final available = corners.temperature.keys.toList();
      final chosen = ref.watch(tyreTempProvider);
      final temp = available.contains(chosen) ? chosen : available.firstOrNull;
      final channels = ChannelColors.resolve(context);
      return [
        if (available.length > 1 && temp != null)
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
        _Grid(
          cell: (corner) => [
            if (corners.pressure[corner] case final p?)
              lapTracePanel(chart, p, channels: channels, height: 76),
            if (temp != null)
              if (corners.temperature[temp]?[corner] case final t?)
                lapTracePanel(chart, t, channels: channels, height: 76),
          ],
        ),
        if (corners.flat.isNotEmpty) _note(context, null, corners),
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
          _note(context, 'This lap holds no brake temperature.', corners)
        else
          _Grid(
            cell: (corner) => [
              if (corners.brakes[corner] case final b?)
                lapTracePanel(chart, b, channels: channels, height: 84),
            ],
          ),
        if (pedal != null)
          lapTracePanel(
            chart,
            pedal,
            channels: channels,
            showDomainReadout: bias == null,
          ),
        if (bias != null)
          lapTracePanel(
            chart,
            bias,
            channels: channels,
            height: 72,
            showDomainReadout: true,
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
  final List<Widget> Function(CornerChart corners) body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<CornerChart>(
      value: ref.watch(lapCornerChartProvider(cornerChartKey(source, chart))),
      loading: (context) => const _Loading(),
      data: (context, corners) {
        final children = body(corners);
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              StaggeredEntrance(index: i, child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// The four corners, following the one the pointer last rested on.
class _Grid extends ConsumerWidget {
  const _Grid({required this.cell});

  final List<Widget> Function(Corner corner) cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CornerGrid(
      lit: ref.watch(cornerFocusProvider),
      onHover: ref.read(cornerFocusProvider.notifier).select,
      cell: (context, corner) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Text(
              corner.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...cell(corner),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  // A list that never scrolls, not a column: the dock passes through every
  // height on its way open, and a placeholder has nothing to overflow for.
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    children: const [
      Align(
        alignment: Alignment.centerLeft,
        child: Skeleton(height: 28, width: 220),
      ),
      SizedBox(height: 14),
      Skeleton(height: 150),
      SizedBox(height: 10),
      Skeleton(height: 150),
    ],
  );
}

/// [message], then which of the file's channels never moved this lap — so a
/// missing panel is said, not left as a gap (§5.4).
Widget _note(BuildContext context, String? message, CornerChart corners) {
  final theme = Theme.of(context);
  final flat = corners.flat.toList()..sort();
  return Text(
    [
      ?message,
      if (flat.isNotEmpty)
        'Not drawn, as they never moved this lap: ${flat.join(', ')}.',
    ].join(' '),
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
