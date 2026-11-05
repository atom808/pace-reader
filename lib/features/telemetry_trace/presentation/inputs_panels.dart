/// The Inputs tab's panels with their driver-aid overlays and the chips that
/// switch them (driver-aids proposal §2).
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_aids.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../settings/application/app_settings.dart';
import '../application/aid_overlays.dart';
import '../application/lap_chart.dart';
import 'lap_view_panes.dart';

/// [chart] with the aid overlays switched on, from [source]'s lap and, where
/// one is overlaid, its reference lap: what Trace's Inputs tab and Compare's
/// stack both draw.
///
/// The aids are read after the lap whatever is shown: which chips a lap
/// offers depends on them (a car without ABS has no ABS chip), and a chip
/// switched off must still be there to switch back on. The overlays are
/// memoized on what they are built from, so their objects stay the same
/// across rebuilds and the panels' layers keep their paint.
({LapChart chart, LapAidOverlays overlays, Set<TraceAid> shown}) useLapAids(
  WidgetRef ref,
  TelemetrySource source,
  LapChart chart,
) {
  final shown = ref.watch(shownTraceAidsProvider);
  final aids = ref.watch(lapAidsProvider((source, chart.lap.index))).value;
  final target = chart.comparison;
  final referenceAids = target == null || !target.overlaid
      ? null
      : ref
            .watch(
              lapAidsProvider((target.target.source, target.target.lapIndex)),
            )
            .value;
  final overlays = useMemoized(
    () => LapAidOverlays.of(chart, aids, referenceAids: referenceAids),
    [chart, aids, referenceAids],
  );
  final decorated = useMemoized(() => overlays.decorate(chart, shown), [
    overlays,
    chart,
    shown,
  ]);
  return (chart: decorated, overlays: overlays, shown: shown);
}

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
    final (:chart, :overlays, :shown) = useLapAids(ref, source, this.chart);
    final reference = chart.comparison?.reference;
    return LapPanelStack(
      chart: chart,
      footer: footer,
      below: (panel) => AidChips.under(
        panel.role,
        overlays: overlays,
        shown: shown,
        referenceName: reference == null
            ? null
            : 'Lap ${reference.displayNumber}',
      ),
    );
  }
}

/// Under a panel: a chip for each overlay it can show, and what the lap's
/// aids did, in words.
class AidChips extends ConsumerWidget {
  const AidChips({
    super.key,
    required this.overlays,
    required this.shown,
    required this.panel,
    this.referenceName,
  });

  /// The chips for [panel], or null for a panel that has none.
  static AidChips? under(
    ChannelRole panel, {
    required LapAidOverlays overlays,
    required Set<TraceAid> shown,
    String? referenceName,
  }) => switch (panel) {
    ChannelRole.throttle || ChannelRole.brake => AidChips(
      overlays: overlays,
      shown: shown,
      panel: panel,
      referenceName: referenceName,
    ),
    _ => null,
  };

  final LapAidOverlays overlays;
  final Set<TraceAid> shown;
  final ChannelRole panel;

  /// What the words call the reference lap ("Lap 3", "the Target"); null
  /// without one.
  final String? referenceName;

  static String _tip(TraceAid aid) => switch (aid) {
    TraceAid.tc =>
      'Each traction-control pulse as a dot on the pedal line, hollow on the '
          'reference lap\'s. TC switches in 10–20 ms pulses; those under '
          '0.25 s apart are one intervention, as Driving Technique counts '
          'them.',
    TraceAid.cut =>
      'Hatched: throttle you asked for that the engine did not get. The line '
          'is your pedal; the edge below the hatching is what reached the '
          'engine. Most of it is TC (64–93 % of cuts fall inside a TC '
          'intervention), the rest the 40 ms cut on every upshift. Measured '
          'on your recordings, 678 files.',
    TraceAid.abs =>
      'Each ABS pulse as a dot on the brake line, hollow on the reference '
          'lap\'s. ABS does not show in the pedal: it releases brake force at '
          'the wheel, as much as half of it on the weakest one. GT3 cars '
          'only; on your recordings it fires at 100–157 km/h.',
    TraceAid.lockups =>
      'Where a wheel turned under 85 % of the car\'s speed for 30 ms or '
          'more, braking above 40 km/h: a locked wheel, or the car sliding '
          '(the file has no yaw rate to tell them apart). Marked where the '
          'wheel was slowest. Rare: 0–2 a session on 18 of your recordings, '
          'every class. Click a mark to put the car there.',
  };

  static IconData _icon(TraceAid aid) => switch (aid) {
    TraceAid.tc || TraceAid.abs => Icons.more_horiz,
    TraceAid.cut => Icons.texture,
    TraceAid.lockups => Icons.radio_button_checked,
  };

  static String _count(int n, String one) => '$n $one${n == 1 ? '' : 's'}';

  /// ", 11 on Lap 3": the reference lap's count beside this lap's, so the
  /// two read as a comparison.
  String _versus(AidPulses? reference) =>
      reference == null || referenceName == null
      ? ''
      : ', ${reference.episodeCount} on $referenceName';

  /// What the lap's aids on this panel did, as a sentence; null when none of
  /// them is shown.
  String? _words() {
    final aids = overlays.aids;
    final theirs = overlays.referenceAids;
    final parts = <String>[];
    switch (panel) {
      case ChannelRole.throttle when shown.contains(TraceAid.tc):
        final tc = aids?.tc;
        if (aids == null) {
          parts.add('Reading TC…');
        } else if (tc == null) {
          parts.add('This file records no TC.');
        } else {
          final n = tc.episodeCount;
          parts.add(
            '${n == 0 ? 'No TC interventions' : _count(n, 'TC intervention')} '
            'this lap${_versus(theirs?.tc)}.',
          );
        }
      case ChannelRole.brake:
        if (aids == null) return 'Reading the brakes…';
        final abs = aids.abs;
        if (!aids.absFitted) {
          parts.add('No ABS on this car.');
        } else if (shown.contains(TraceAid.abs) && abs != null) {
          final n = abs.episodeCount;
          parts.add(
            '${n == 0 ? 'No ABS interventions' : _count(n, 'ABS intervention')}'
            '${_versus(theirs?.absFitted ?? false ? theirs!.abs : null)}.',
          );
        }
        if (shown.contains(TraceAid.lockups)) {
          final locks = aids.lockups;
          if (locks == null) {
            parts.add('This file records no wheel speeds.');
          } else if (locks.isEmpty) {
            parts.add('No lock-ups.');
          } else if (locks.length == 1) {
            final lock = locks.single;
            parts.add(
              '1 lock-up: ${lockText(lock)} at '
              '${lock.speedKmh.round()} km/h.',
            );
          } else {
            parts.add('${_count(locks.length, 'lock-up')}.');
          }
          final theirLocks = theirs?.lockups;
          if (referenceName != null && (theirLocks?.isNotEmpty ?? false)) {
            parts.add(
              '$referenceName: ${_count(theirLocks!.length, 'lock-up')}.',
            );
          }
        }
      default:
    }
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final offered = [
      for (final aid in TraceAid.values)
        if (aid.panel == panel && overlays.offers(aid)) aid,
    ];
    final words = _words();
    if (offered.isEmpty && words == null) return const SizedBox.shrink();
    final settings = ref.read(appSettingsProvider.notifier);

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
                  _icon(aid),
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
