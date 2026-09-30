import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/value_ramp.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/tire_brake_report.dart';
import '../application/tire_brake_selection.dart';
import 'corner_card.dart';
import 'setup_card.dart';
import 'tyre_trends.dart';

/// Tires & Brakes (SPEC.md §8.6).
///
/// Two questions, in the order a driver asks them. **How were the tyres on
/// that lap?** — four corner cards in the car's own layout, nose up, each
/// printing its pressure against the cold setting, the tread across its
/// width, carcass, wear and brake. **How did they get there?** — one quantity
/// at a time across the whole stint, as four small multiples in the same
/// layout on one shared scale, and a table holding every value they draw.
///
/// The per-corner labels rest on §15.5's resolution (value1..4 = FL, FR, RL,
/// RR), which is written down once, in [Corner].
class TiresBrakesScreen extends ConsumerWidget {
  const TiresBrakesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Tires & brakes',
        subject: 'tyre and brake data',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Tires & brakes')),
      body: AsyncValueView<TireBrakeReport>(
        value: ref.watch(tireBrakeReportProvider(source)),
        loading: (context) => const _LoadingLayout(),
        data: (context, report) => _Report(source: source, report: report),
      ),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.source, required this.report});

  final TelemetrySource source;
  final TireBrakeReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (report.laps.isEmpty) {
      return _Notice(
        'This recording has no laps to summarise — its `Lap` table marks '
        'no lap start.',
        style: theme.textTheme.titleMedium,
      );
    }
    final available = report.availableMetrics;
    if (available.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Notice(
            'This recording carries none of the tyre or brake channels this '
            'view reads.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _HiddenChannels(hidden: report.hidden),
        ],
      );
    }

    final chosenIndex = ref.watch(tyreLapSelectionProvider(source));
    final lap = report.laps.firstWhere(
      (l) => l.index == chosenIndex,
      orElse: () => report.defaultLap!,
    );
    final chosenMetric = ref.watch(tyreMetricSelectionProvider(source));
    // A metric this file cannot draw falls back to the first it can, rather
    // than leaving the charts blank under a selected segment.
    final metric =
        available.contains(chosenMetric) ? chosenMetric : available.first;

    final laps = report.laps;
    final position = laps.indexOf(lap);
    void selectLap(Lap l) =>
        ref.read(tyreLapSelectionProvider(source).notifier).select(l.index);
    void step(int by) {
      final next = position + by;
      if (next >= 0 && next < laps.length) selectLap(laps[next]);
    }

    void selectMetric(TyreMetric m) {
      if (report.isAvailable(m)) {
        ref.read(tyreMetricSelectionProvider(source).notifier).select(m);
      }
    }

    final ramp = ValueRamp(ChannelColors.resolve(context).tyre);
    final rampRange = report.treadRampRange;
    final snapshot = report.snapshot(lap);
    final hottest = report.hottestOn(lap);
    final mostWorn = report.mostWornOn(lap);

    return CallbackShortcuts(
      // ←/→ step laps from anywhere on the screen: stepping is the one
      // action a driver repeats here, and reaching for the buttons each time
      // is what makes a comparison across laps tedious.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => step(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => step(1),
      },
      child: Focus(
        autofocus: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _LapStepper(
                  lap: lap,
                  status: _lapStatus(report, lap),
                  onPrevious: position > 0 ? () => step(-1) : null,
                  onNext: position < laps.length - 1 ? () => step(1) : null,
                  onReset: chosenIndex == null ||
                          chosenIndex == report.defaultLap?.index
                      ? null
                      : () => ref
                          .read(tyreLapSelectionProvider(source).notifier)
                          .clear(),
                ),
                if (rampRange != null)
                  TreadRampLegend(ramp: ramp, range: rampRange),
              ],
            ),
            if (report.hidden.isNotEmpty) ...[
              const SizedBox(height: 12),
              _HiddenChannels(hidden: report.hidden),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final cars = _CarLayout(
                  snapshot: snapshot,
                  ramp: ramp,
                  rampRange: rampRange,
                  metric: metric,
                  onSelectMetric: selectMetric,
                  hottest: hottest,
                  mostWorn: mostWorn,
                );
                final setup = TyreSetupCard(report: report);
                // Setup beside the car where the window allows: it is the
                // reference the cards are read against. Under ~1040 px it
                // moves below, since four cards squeezed to 300 px lose
                // their numbers before the setup loses anything.
                if (constraints.maxWidth >= 1040) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cars),
                      const SizedBox(width: 16),
                      SizedBox(width: 330, child: setup),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cars, const SizedBox(height: 16), setup],
                );
              },
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Across the stint', style: theme.textTheme.titleMedium),
                _MetricSelector(
                  report: report,
                  selected: metric,
                  onSelected: selectMetric,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${metricCaption(metric)} Grey laps — the garage lap, a lap '
              'the recording cut off, any with time in the pit lane — are '
              'drawn but left off the line.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            // A cross-fade between quantities, never a morph: animating a
            // pressure line into a temperature line would draw a motion
            // between two things that are not the same series.
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.medium,
              switchInCurve: AppCurves.entrance,
              child: KeyedSubtree(
                key: ValueKey(metric),
                child: CornerTrends(
                  report: report,
                  metric: metric,
                  selectedLap: lap,
                ),
              ),
            ),
            const SizedBox(height: 8),
            MetricTable(
              report: report,
              metric: metric,
              selectedLap: lap,
              onSelectLap: selectLap,
            ),
          ],
        ),
      ),
    );
  }
}

/// What the stepper says about the lap it is on.
String _lapStatus(TireBrakeReport report, Lap lap) {
  final base = lap.index == report.defaultLap?.index
      ? 'last complete lap'
      : null;
  final exclusion = report.exclusionOf(lap);
  final time = lap.lapTimeSeconds == null
      ? null
      : formatLapTime(lap.lapTimeSeconds!);
  return [
    ?base,
    if (exclusion != null) exclusionLabel(exclusion),
    ?time,
  ].join(' · ');
}

/// The four corners, nose up, with a quiet marker saying which way that is.
class _CarLayout extends StatelessWidget {
  const _CarLayout({
    required this.snapshot,
    required this.ramp,
    required this.rampRange,
    required this.metric,
    required this.onSelectMetric,
    required this.hottest,
    required this.mostWorn,
  });

  final Map<Corner, CornerSnapshot> snapshot;
  final ValueRamp ramp;
  final ({double min, double max})? rampRange;
  final TyreMetric metric;
  final ValueChanged<TyreMetric> onSelectMetric;
  final Corner? hottest;
  final Corner? mostWorn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget card(Corner corner) => CornerCard(
          snapshot: snapshot[corner]!,
          ramp: ramp,
          rampRange: rampRange,
          selectedMetric: metric,
          onSelectMetric: onSelectMetric,
          hottest: hottest == corner,
          mostWorn: mostWorn == corner,
        );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_arrow_up, size: 16, color: muted),
            const SizedBox(width: 2),
            Text('FRONT',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: muted, letterSpacing: 1.6)),
          ],
        ),
        const SizedBox(height: 6),
        for (final axle in [
          [Corner.frontLeft, Corner.frontRight],
          [Corner.rearLeft, Corner.rearRight],
        ]) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: card(axle[0])),
                const SizedBox(width: 12),
                Expanded(child: card(axle[1])),
              ],
            ),
          ),
          if (axle.first.isFront) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LapStepper extends StatelessWidget {
  const _LapStepper({
    required this.lap,
    required this.status,
    required this.onPrevious,
    required this.onNext,
    required this.onReset,
  });

  final Lap lap;
  final String status;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous lap (←)',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SizedBox(
          width: 72,
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDurations.fast,
            child: Text(
              'Lap ${lap.displayNumber}',
              key: ValueKey(lap.index),
              textAlign: TextAlign.center,
              style: AppTextStyles.numeral.copyWith(fontSize: 18),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next lap (→)',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
        const SizedBox(width: 8),
        Text(status,
            style: AppTextStyles.numeral.copyWith(fontSize: 13, color: muted)),
        if (onReset != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onReset,
            child: const Text('Back to last complete lap'),
          ),
        ],
      ],
    );
  }
}

class _MetricSelector extends StatelessWidget {
  const _MetricSelector({
    required this.report,
    required this.selected,
    required this.onSelected,
  });

  final TireBrakeReport report;
  final TyreMetric selected;
  final ValueChanged<TyreMetric> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TyreMetric>(
      segments: [
        for (final metric in TyreMetric.values)
          ButtonSegment(
            value: metric,
            label: Text(metric.label),
            enabled: report.isAvailable(metric),
            // A disabled segment says why rather than silently doing
            // nothing — the reason is in the note above as well.
            tooltip: report.isAvailable(metric)
                ? null
                : 'Not in this recording, or flat all session',
          ),
      ],
      selected: {selected},
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
      ),
      onSelectionChanged: (selection) => onSelected(selection.first),
    );
  }
}

/// The channels left out, and why — §5.4's "absent, not a flat line", said.
class _HiddenChannels extends StatelessWidget {
  const _HiddenChannels({required this.hidden});

  final List<HiddenChannel> hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SquircleCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_off_outlined, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Not shown', style: theme.textTheme.bodySmall),
                for (final channel in hidden)
                  Text('${channel.name} — ${channel.reason}',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, style: style),
      );
}

/// The screen's own shape while the report loads — four cards and four
/// charts where they will land, so the data arrives into place rather than
/// pushing a column of bars aside.
class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout();

  @override
  Widget build(BuildContext context) {
    Widget pair(double height) => Row(
          children: [
            Expanded(child: Skeleton(height: height)),
            const SizedBox(width: 12),
            Expanded(child: Skeleton(height: height)),
          ],
        );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const Skeleton(height: 36, width: 280),
        const SizedBox(height: 22),
        pair(210),
        const SizedBox(height: 12),
        pair(210),
        const SizedBox(height: 28),
        const Skeleton(height: 32, width: 520),
        const SizedBox(height: 16),
        pair(180),
        const SizedBox(height: 12),
        pair(180),
      ],
    );
  }
}
