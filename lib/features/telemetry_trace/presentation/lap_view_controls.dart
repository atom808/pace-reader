/// Controls shared by the two screens of the synced lap view
/// (SPEC.md §8.4, §8.5, §9.5).
///
/// `features/track_map/` imports these, which is the one cross-feature
/// dependency in the app and a deliberate one: §9.5 makes the trace panels
/// and the track map a single synced system rather than two features that
/// overlap, so a second lap picker and a second axis toggle would be two
/// controls that could disagree about what the user is looking at. The
/// dependency runs one way only — track map depends on telemetry trace,
/// never the reverse.
library;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/lap_chart.dart';
import '../application/lap_selection.dart';

/// Drops the shared cursor and viewport when the lap under them changes.
///
/// Called from a screen's build via `ref.listen`, which fires after the
/// build rather than during it — the safe place to write to another provider.
/// Centralised here because a stale cursor is invisible rather than loud: it
/// stays a valid-looking position on a lap that is no longer shown.
void watchLapChanges(WidgetRef ref, TelemetrySource source) {
  ref.listen(displayedLapProvider(source), (previous, next) {
    if (previous?.value?.index == next.value?.index) return;
    ref.read(chartSyncProvider.notifier).resetForNewData();
  });
}

/// Picks the lap every synced view shows.
class LapPicker extends ConsumerWidget {
  const LapPicker({super.key, required this.source, required this.selected});

  final TelemetrySource source;
  final Lap? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laps = ref.watch(lapsProvider(source)).value ?? const <Lap>[];
    if (laps.isEmpty) return const SizedBox.shrink();

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: selected?.index,
        borderRadius: BorderRadius.circular(AppRadii.md),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        items: [
          for (final lap in laps)
            DropdownMenuItem(
              value: lap.index,
              child: _LapOption(lap: lap),
            ),
        ],
        // Only the selection is written here. Dropping the cursor and the
        // zoom is [watchLapChanges]' job, so it happens for *every* way the
        // lap can change — a different session, a session that finished
        // loading — and not only for this control.
        onChanged: (index) => index == null
            ? null
            : ref.read(selectedLapIndexProvider(source).notifier).select(index),
      ),
    );
  }
}

class _LapOption extends StatelessWidget {
  const _LapOption({required this.lap});

  final Lap lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // +1 for the same reason the lap table does it: the raw index is
        // 0-based and would read "Lap 0" (§5.2).
        Text('Lap ${lap.displayNumber}', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 10),
        Text(
          // The garage lap and the open final lap are listed, not hidden —
          // they carry telemetry worth looking at even though their times
          // aren't comparable (§14's lap-table reasoning applies here too).
          lap.isOutLap
              ? 'out lap'
              : lap.isOpenEnded
                  ? 'incomplete'
                  : formatOptionalLapTime(lap.lapTimeSeconds),
          style: AppTextStyles.numeral.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The Distance/Time toggle (§8.4).
class AxisToggle extends ConsumerWidget {
  const AxisToggle({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chartSyncProvider.notifier);
    final button = SegmentedButton<TraceAxis>(
      segments: [
        ButtonSegment(
          value: TraceAxis.distance,
          label: const Text('Distance'),
          enabled: chart.distanceAvailable,
        ),
        const ButtonSegment(value: TraceAxis.time, label: Text('Time')),
      ],
      selected: {chart.axis},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
      ),
      onSelectionChanged: (selection) => controller.setAxis(
        selection.first,
        distanceAxis: chart.distanceAxis,
      ),
    );

    if (chart.distanceAvailable) return button;
    // Saying *why* the axis is unavailable, rather than showing a control
    // that silently does nothing: on the garage lap `Lap Dist` runs backwards
    // while the car manoeuvres in the pits, and a distance axis there would
    // fold the trace back over itself.
    return Tooltip(
      message: 'This lap has no usable distance axis — lap distance runs '
          'backwards while the car manoeuvres in the pits.',
      child: button,
    );
  }
}

/// Returns the view to the whole lap. Disabled when already there, so the
/// control also reports whether a zoom is in effect.
class ZoomResetButton extends ConsumerWidget {
  const ZoomResetButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zoomed = ref.watch(chartSyncProvider.select((s) => s.isZoomed));
    return IconButton(
      tooltip: 'Fit the whole lap',
      icon: const Icon(Icons.fit_screen_outlined),
      onPressed: zoomed
          ? ref.read(chartSyncProvider.notifier).resetViewport
          : null,
    );
  }
}

/// One line of lap facts, so a view of a lap says which lap it is without the
/// user going back to the lap table.
class LapSummaryBar extends StatelessWidget {
  const LapSummaryBar({super.key, required this.chart});

  final LapChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lap = chart.lap;
    final sectors = lap.sectors.all;

    return Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Fact(
          label: 'Lap ${lap.displayNumber}',
          value: formatOptionalLapTime(lap.lapTimeSeconds),
          emphasised: true,
        ),
        for (var i = 0; i < 3; i++)
          _Fact(label: 'S${i + 1}', value: formatOptionalSectorTime(sectors[i])),
        if (chart.axis == TraceAxis.distance)
          _Fact(
            label: 'Length',
            value: '${chart.bounds.span.toStringAsFixed(0)} m',
          )
        else
          _Fact(
            label: 'Recorded',
            value: '${chart.bounds.span.toStringAsFixed(1)} s',
          ),
        Text(
          '${chart.panels.length} channels',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppTextStyles.numeral.copyWith(
            fontSize: emphasised ? 16 : 13,
            color: emphasised ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}
