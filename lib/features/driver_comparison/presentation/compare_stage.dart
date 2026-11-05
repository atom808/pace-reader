/// Compare on the stage (map stage proposal §9; comparison proposal §6):
/// Base's line coloured by the pedals and the Target's dotted, the selected
/// stretch cased, the segments numbered and the findings marked on the
/// map; the chips in the HUD, the segment navigator across the foot of the
/// map, the traces in the dock, and Why · Sectors · Tyres in a drawer.
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import '../../telemetry_trace/presentation/lap_view_controls.dart';
import '../../telemetry_trace/presentation/lap_view_panes.dart';
import '../../telemetry_trace/presentation/stage_frame.dart';
import '../application/compare_gap.dart';
import '../application/compare_map.dart';
import '../application/comparison_chart.dart';
import '../application/comparison_focus.dart';
import '../application/segment_tables.dart';
import '../domain/gap_split.dart';
import '../domain/segment_losses.dart';
import 'compare_panels.dart';
import 'gap_split_card.dart';
import 'segment_navigator.dart';

/// The dock's tabs. On a wide window Why is the drawer beside the dock; on
/// a narrow one it is a tab of the sheet.
const compareTracesTab = TraceTab(
  id: 'compare-traces',
  label: 'Traces',
  icon: Icons.stacked_line_chart,
);
const compareWhyTab = TraceTab(
  id: 'compare-why',
  label: 'Why',
  icon: Icons.lightbulb_outline,
);

/// What the Distance axis says instead of a ghost (§6).
const distanceAxisGhost =
    'Both laps are at the same point on the Distance axis. Switch to Time '
    'to see the gap.';

class CompareStage extends HookConsumerWidget {
  const CompareStage({
    super.key,
    required this.view,
    required this.segments,
    required this.segmentsError,
    this.keys = const {},
  });

  /// With a chart that has a map.
  final ComparisonView view;

  /// Null without a Target, and while the first detection runs.
  final ComparisonSegments? segments;

  /// Why the segments could not be read, when they could not.
  final Object? segmentsError;

  /// The screen's keys, asked before the stage's own: Compare's ← and →
  /// step through segments rather than nudge the playhead.
  final Map<ShortcutActivator, VoidCallback> keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = view.chart!;
    final map = view.map;
    final comparison = chart.comparison;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final palette = ChartPalette.of(context, series: ink);
    final onTime = chart.axis == TraceAxis.time;
    final ghostShown = ref.watch(ghostShownProvider);
    final focus = ref.watch(segmentFocusProvider).forSet(view.set);
    final why = useState(true);
    final tab = useState(compareTracesTab);

    final segments = this.segments;
    final stretches = segments?.inMode(focus.mode);
    final stop = stretches == null ? null : focus.stopIn(stretches);
    final stretch = stop?.stretch?.segment;
    final highlight =
        stretch == null || stretch.start.isNaN || stretch.end.isNaN
        ? null
        : (stretch.start, stretch.end);

    // The gap split's chosen phase, or its carried straights, cased in the
    // phase's colour wherever they are.
    // The split is only watched once something is lit: until then the card
    // in the drawer is what asks for it.
    final gapFocus = ref.watch(gapPhaseFocusProvider);
    final lit =
        gapFocus.forSet(view.set) == null && !gapFocus.carriedFor(view.set)
        ? null
        : gapFocus.litOn(
            view.set,
            ref.watch(comparisonGapSplitProvider(view.set)).value,
          );
    final litStretches = lit?.stretches ?? const <GapStretch>[];
    final litColour = lit == null
        ? null
        // The accent needs more body than a pedal colour to read as apart
        // from the segment's grey casing.
        : gapLitColour(
            context,
            lit.phase,
          ).withValues(alpha: lit.phase == null ? 0.85 : 0.55);

    final findings = segments?.findings;
    final marks =
        map == null ||
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

    final ghost =
        map != null && onTime && ghostShown && map.ghostWithheld == null;
    final style = LapLineStyle.of(context, chart, colour: LapLineColour.pedals);
    final base = chart.trackPath!;

    /// Fit on a segment zoom: the stretch and, on the Time axis with the
    /// ghost shown, where the Target runs while Base drives it, unless that
    /// would zoom out too far (§6).
    Rect? frame(ChartViewport window) {
      if (map == null) return null;
      final double? from;
      final double? to;
      if (onTime) {
        from = map.baseStationAt(window.start);
        to = map.baseStationAt(window.end);
      } else {
        from = window.start;
        to = window.end;
      }
      if (from == null || to == null || to <= from) return null;
      return map.fitFor(
        from,
        to,
        window: ghost ? (from: window.start, to: window.end) : null,
      );
    }

    final drawer = comparison == null || !why.value
        ? null
        : CompareDetailTabs(view: view, segments: segments);

    // The frame chooses a side dock or a sheet by the same width.
    return LayoutBuilder(
      builder: (context, constraints) => StageFrame(
        chart: chart,
        source: view.set.base.source,
        keys: keys,
        map: StageMapSpec(
          colouring: style.colouring,
          alignment: ghost ? map.lapAlignment : null,
          reference: map?.target,
          extent: map?.overview,
          frameWindow: map == null ? null : frame,
          underlays: [
            if (litColour != null)
              for (final s in litStretches)
                StretchCasingLayer(
                  path: base,
                  from: s.from,
                  to: s.to,
                  colour: litColour,
                  width: 5,
                ),
            if (highlight != null)
              StretchCasingLayer(
                path: base,
                from: highlight.$1,
                to: highlight.$2,
                colour: ink.withValues(alpha: 0.5),
                width: 5,
              ),
          ],
          overlays: [
            TrackMarkLayer(marks: marks, ink: ink, surface: palette.surface),
            TrackLabelLayer(
              path: base,
              labels: labels,
              palette: palette,
              ink: ink,
            ),
          ],
        ),
        hud: _Hud(
          view: view,
          map: map,
          legend: style.legend,
          brief: constraints.maxWidth < StageFrame.sideDockBreakpoint,
        ),
        footer: comparison == null
            ? null
            : segments == null
            ? Text(
                segmentsError == null
                    ? 'Finding the corners…'
                    : 'No segments: $segmentsError',
                style: theme.textTheme.bodySmall,
              )
            : SegmentNavigator(set: view.set, chart: chart, segments: segments),
        drawer: drawer,
        dock: (side) {
          final tabs = [
            compareTracesTab,
            if (!side && comparison != null) compareWhyTab,
          ];
          return StageDockSpec(
            tabs: tabs,
            selected: tabs.contains(tab.value) ? tab.value : tabs.first,
            onSelect: (t) => tab.value = t,
            body: (t) => t == compareWhyTab
                ? CompareDetailTabs(view: view, segments: segments)
                : ComparePanelStack(view: view, footer: false),
            trailing: (width) => [
              if (side && comparison != null)
                AppTooltip(
                  message: why.value
                      ? 'Close Why, Sectors and Tyres'
                      : 'Why, Sectors and Tyres',
                  child: IconButton(
                    isSelected: why.value,
                    onPressed: () => why.value = !why.value,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    selectedIcon: Icon(
                      Icons.lightbulb,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The chips, the readings of both laps, the ghost and what the map shows.
class _Hud extends ConsumerWidget {
  const _Hud({
    required this.view,
    required this.map,
    required this.legend,
    required this.brief,
  });

  final ComparisonView view;
  final CompareMap? map;
  final Widget? legend;

  /// Over a sheet, where the map is short: the caption only when it says
  /// the Target's line is not drawn, which the map cannot show.
  final bool brief;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chart = view.chart!;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final map = this.map;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view.chips.isEmpty)
          Text(
            'Base alone: choose a Target to compare it against.',
            style: muted,
          )
        else
          CompareStrip(view: view, oneLine: true),
        if (chart.comparison?.note case final note?) ...[
          const SizedBox(height: 8),
          ComparisonNote(note: note),
        ],
        const SizedBox(height: 10),
        StageLiveChips(chart: chart),
        if (map != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: switch (map.targetHidden) {
                  final hidden? => Text(
                    hidden,
                    style: muted,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  null when brief => const SizedBox.shrink(),
                  null => Text(
                    'Target dotted. The map shows where; read line '
                    'differences off the Line panel.',
                    style: muted,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                },
              ),
              const SizedBox(width: 8),
              _GhostChip(chart: chart, map: map),
            ],
          ),
        ],
        if (legend case final legend?) ...[const SizedBox(height: 8), legend],
      ],
    );
  }
}

/// Shows or hides the Target's car on the Time axis; on the Distance axis
/// it says why there is none.
class _GhostChip extends ConsumerWidget {
  const _GhostChip({required this.chart, required this.map});

  final LapChart chart;
  final CompareMap map;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onTime = chart.axis == TraceAxis.time;
    final shown = ref.watch(ghostShownProvider);
    final withheld = map.ghostWithheld;
    final String tip;
    if (!onTime) {
      tip = distanceAxisGhost;
    } else if (withheld != null) {
      tip = withheld;
    } else {
      tip = shown
          ? "Hide the Target's ghost"
          : "Show where the Target is at the cursor's moment";
    }
    return AppTooltip(
      message: tip,
      child: FilterChip(
        label: const Text('Ghost'),
        avatar: Icon(
          Icons.radio_button_unchecked,
          size: 14,
          color: theme.colorScheme.onSurface,
        ),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selected: onTime && shown && withheld == null,
        onSelected: onTime && withheld == null
            ? (_) => ref.read(ghostShownProvider.notifier).toggle()
            : null,
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
    final cursor = sync.playhead;
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
