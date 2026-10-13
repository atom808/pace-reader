/// Compare's map pane and Time axis readout (comparison proposal §6).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/compare_map.dart';
import '../application/comparison_chart.dart';
import '../application/comparison_focus.dart';
import '../application/segment_tables.dart';
import '../domain/segment_losses.dart';

/// Base coloured by its channel, the Target dotted in ink, the selected
/// stretch cased, the segments numbered — and, on the Time axis, the
/// Target's ghost.
class CompareMapPane extends ConsumerWidget {
  const CompareMapPane({
    super.key,
    required this.view,
    required this.map,
    required this.segments,
  });

  final ComparisonView view;
  final CompareMap map;
  final ComparisonSegments? segments;

  /// What the Distance axis says instead of a ghost (§6).
  static const distanceAxisGhost =
      'Both laps are at the same point on the Distance axis. Switch to Time '
      'to see the gap.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chart = view.chart!;
    final channels = ChannelColors.resolve(context);
    final onTime = chart.axis == TraceAxis.time;
    final ghostShown = ref.watch(ghostShownProvider);
    final focus = ref.watch(segmentFocusProvider).forSet(view.set);

    final segments = this.segments;
    final comparison = segments?.inMode(focus.mode);
    final stop = comparison == null ? null : focus.stopIn(comparison);
    final stretch = stop?.stretch?.segment;
    final highlight =
        stretch == null || stretch.start.isNaN || stretch.end.isNaN
        ? null
        : (stretch.start, stretch.end);

    // Fitted once per selection: the cursor never reaches this build, so a
    // scrub cannot move the map (§6).
    Rect? fit;
    if (focus.zoomed && highlight != null) {
      final clock = segments?.baseClock;
      final axis = chart.distanceAxis;
      double? reach(double station) =>
          clock?.at(station) ?? axis?.firstReachTime(station);
      final from = reach(highlight.$1);
      final to = reach(highlight.$2);
      fit = map.fitFor(
        highlight.$1,
        highlight.$2,
        window: onTime && ghostShown && from != null && to != null
            ? (from: from, to: to)
            : null,
      );
    }

    final findings = segments?.findings;
    final marks =
        findings == null ||
            stretch == null ||
            focus.mode != SegmentMode.segments
        ? const <TrackMark>[]
        : map.marksFor(findings, stretch);

    final worst = segments?.segments?.worst?.segment.number;
    final labels = focus.mode == SegmentMode.segments
        ? [
            for (final s
                in segments?.segments?.stretches ?? const <StretchLoss>[])
              TrackLabel(
                station: (s.segment.start + s.segment.end) / 2,
                text: '${s.segment.number}',
                ringed: s.segment.number == worst,
              ),
          ]
        : const <TrackLabel>[];

    final ghost = onTime && ghostShown && map.ghostWithheld == null
        ? TrackGhost(
            at: map.ghostAt,
            describe: (cursor) {
              final gap = map.readoutAt(cursor).gap;
              return gap == null ? 'Target' : TimeReadout.gapText(gap);
            },
          )
        : null;

    final String toggleTip;
    if (!onTime) {
      toggleTip = distanceAxisGhost;
    } else if (map.ghostWithheld != null) {
      toggleTip = map.ghostWithheld!;
    } else {
      toggleTip = ghostShown
          ? "Hide the Target's ghost"
          : "Show where the Target is at the cursor's moment";
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Track map', style: theme.textTheme.labelMedium),
              ),
              Tooltip(
                message: toggleTip,
                child: FilterChip(
                  label: const Text('Ghost'),
                  avatar: Icon(
                    Icons.radio_button_unchecked,
                    size: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  selected: onTime && ghostShown && map.ghostWithheld == null,
                  onSelected: onTime && map.ghostWithheld == null
                      ? (_) => ref.read(ghostShownProvider.notifier).toggle()
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: TrackMapView(
              path: map.base,
              color: channels.of(chart.trackColorRole),
              markers: chart.trackMarkers,
              strokeWidth: 3,
              reference: map.target,
              frame: map.overview,
              view: fit,
              highlight: highlight,
              labels: labels,
              marks: marks,
              ghost: ghost,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            map.targetHidden ??
                'Target dotted. The map shows where; read line differences '
                    'off the Line panel.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Under the stack on the Time axis: τ, the delta at Base's position and how
/// far ahead the Target is, at the cursor (§6 "Footer readout").
class TimeReadoutBar extends ConsumerWidget {
  const TimeReadoutBar({super.key, required this.map});

  final CompareMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final cursor = sync.cursor;
    final text = cursor == null
        ? 'Time axis: point at the traces for the gap to the Target.'
        : map.readoutAt(cursor).text;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 8),
      child: Text(
        text,
        key: const ValueKey('time-readout'),
        style: cursor == null
            ? theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )
            : AppTextStyles.numeral.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
      ),
    );
  }
}
