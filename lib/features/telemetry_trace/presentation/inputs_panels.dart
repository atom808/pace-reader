/// The Inputs tab's panels with their driver-aid overlays and the chips that
/// switch them (driver-aids proposal §2).
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/lap_aids.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../settings/application/app_settings.dart';
import '../application/aid_overlays.dart';
import '../application/lap_chart.dart';
import 'lap_view_panes.dart';

/// [chart]'s Inputs panels, the overlays switched on laid over them.
class InputsPanelStack extends HookConsumerWidget {
  const InputsPanelStack({
    super.key,
    required this.source,
    required this.chart,
    this.footer = true,
  });

  final TelemetrySource source;
  final LapChart chart;
  final bool footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(shownTraceAidsProvider);
    // The pulses are read only while TC is on (D5); the cut is the lap's own
    // channels and needs no read.
    final aids = shown.contains(TraceAid.tc)
        ? ref.watch(lapAidsProvider((source, chart.lap.index))).value
        : null;
    // Memoized on what they are built from, so the overlay objects stay the
    // same across rebuilds and the panels' layers keep their paint.
    final overlays = useMemoized(() => LapAidOverlays.of(chart, aids), [
      chart,
      aids,
    ]);
    final decorated = useMemoized(() => overlays.decorate(chart, shown), [
      overlays,
      chart,
      shown,
    ]);
    return LapPanelStack(
      chart: decorated,
      footer: footer,
      below: (panel) => panel.role == ChannelRole.throttle
          ? _AidChips(overlays: overlays, shown: shown, panel: panel.role)
          : null,
    );
  }
}

/// Under a panel: a chip for each overlay it can show, and what the lap's
/// aids did, in words.
class _AidChips extends ConsumerWidget {
  const _AidChips({
    required this.overlays,
    required this.shown,
    required this.panel,
  });

  final LapAidOverlays overlays;
  final Set<TraceAid> shown;
  final ChannelRole panel;

  static String _tip(TraceAid aid) => switch (aid) {
    TraceAid.tc =>
      'Each traction-control pulse as a dot on the pedal line. TC switches '
          'in 10–20 ms pulses; those under 0.25 s apart are one intervention, '
          'as Driving Technique counts them.',
    TraceAid.cut =>
      'Hatched: throttle you asked for that the engine did not get. The line '
          'is your pedal; the edge below the hatching is what reached the '
          'engine. Most of it is TC (64–93 % of cuts fall inside a TC '
          'intervention), the rest the 40 ms cut on every upshift. Measured '
          'on your recordings, 678 files.',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offered = [
      for (final aid in TraceAid.values)
        if (aid.panel == panel && overlays.offers(aid)) aid,
    ];
    if (offered.isEmpty) return const SizedBox.shrink();
    final settings = ref.read(appSettingsProvider.notifier);

    final tc = overlays.aids?.tc;
    final String? words;
    if (!shown.contains(TraceAid.tc)) {
      words = null;
    } else if (overlays.aids == null) {
      words = 'Reading TC…';
    } else if (tc == null) {
      words = 'This file records no TC.';
    } else if (tc.episodeCount == 0) {
      words = 'TC did not act on this lap.';
    } else {
      final n = tc.episodeCount;
      words = '$n TC intervention${n == 1 ? '' : 's'} this lap.';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final aid in offered)
            AppTooltip(
              message: _tip(aid),
              child: FilterChip(
                label: Text(aid.label),
                showCheckmark: false,
                avatar: Icon(
                  aid == TraceAid.tc ? Icons.more_horiz : Icons.texture,
                  size: 14,
                  color: theme.colorScheme.onSurface,
                ),
                visualDensity: VisualDensity.compact,
                selected: shown.contains(aid),
                onSelected: (on) => settings.setTraceOverlay(aid.id, shown: on),
              ),
            ),
          if (words != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: FadeOnChange(
                value: words,
                duration: AppMotion.duration(context, AppDurations.medium),
                child: Text(
                  words,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
