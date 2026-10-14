/// The segment navigator (comparison proposal §3, §5 "Opening behaviour"):
/// where Base lost time to the Target, one stretch of the lap at a time.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/presentation/library_formatting.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import '../application/comparison_focus.dart';
import '../application/segment_tables.dart';
import '../domain/comparison_set.dart';
import '../domain/segment_losses.dart';
import '../domain/segments.dart';
import 'suggestion_list.dart';

/// What the navigator's controls and the keyboard do (§3 Keyboard): step
/// through the walk, zoom onto a stretch, and back to the whole lap.
class SegmentActions {
  const SegmentActions(
    this.ref, {
    required this.set,
    required this.chart,
    required this.segments,
  });

  final WidgetRef ref;
  final ComparisonSet set;
  final LapChart chart;
  final ComparisonSegments segments;

  SegmentFocusState get _focus => ref.read(segmentFocusProvider).forSet(set);

  SegmentFocus get _notifier => ref.read(segmentFocusProvider.notifier);

  StretchComparison? get _comparison => segments.inMode(_focus.mode);

  /// Selects [stop] and zooms onto it — what a click on its cell does.
  void select(WalkStop stop) {
    _notifier.select(set, stop, zoomed: !stop.recap);
    stop.recap ? _wholeLap() : _show(stop);
  }

  /// → and ←: the next or previous stop in the chosen order. While zoomed,
  /// the zoom moves with it.
  void step({required bool forward}) {
    final comparison = _comparison;
    if (comparison == null) return;
    final focus = _focus;
    jump(
      stepAlong(
        comparison.walk(focus.order),
        focus.stopIn(comparison),
        forward: forward,
      ),
    );
  }

  /// Selects [stop] as → would: while zoomed, the zoom moves with it. The
  /// Why card's links go through here.
  void jump(WalkStop stop) {
    final focus = _focus;
    _notifier.select(set, stop, zoomed: focus.zoomed && !stop.recap);
    if (!focus.zoomed) return;
    stop.recap ? _wholeLap() : _show(stop);
  }

  /// Enter: zoom onto the selected stretch.
  void zoom() {
    final comparison = _comparison;
    if (comparison == null) return;
    final stop = _focus.stopIn(comparison);
    if (stop == null || stop.recap) return;
    _notifier.select(set, stop, zoomed: true);
    _show(stop);
  }

  /// `0` or Esc: the whole lap, the selection kept.
  void wholeLap() {
    _notifier.setZoomed(set, false);
    _wholeLap();
  }

  void _wholeLap() => ref.read(chartSyncProvider.notifier).resetViewport();

  /// The stretch's metres plus 20 m either side; on the Time axis, Base's
  /// first reach of each end ± 0.5 s (§5).
  void _show(WalkStop stop) {
    final segment = stop.stretch?.segment;
    if (segment == null || segment.start.isNaN || segment.end.isNaN) return;
    final ChartViewport window;
    if (chart.axis == TraceAxis.distance) {
      window = ChartViewport(segment.start - 20, segment.end + 20);
    } else {
      final clock = segments.baseClock;
      final axis = chart.distanceAxis;
      double? at(double station) =>
          clock?.at(station) ?? axis?.firstReachTime(station);
      final from = at(segment.start);
      final to = at(segment.end);
      if (from == null || to == null || to <= from) return;
      window = ChartViewport(from - 0.5, to + 0.5);
    }
    ref
        .read(chartSyncProvider.notifier)
        .showWindow(window, bounds: chart.bounds);
  }
}

/// "Race · 7 Jul · Lap 4": the canonical lap as the caption names it.
String canonicalLabel(CanonicalLap lap) {
  final at = parseRecordingTime(lap.recording.recordingTime);
  return '${lap.sessionType} · '
      '${at == null ? lap.recording.recordingTime : formatRecordedDate(at)} · '
      'Lap ${lap.lapNumber}';
}

class SegmentNavigator extends ConsumerWidget {
  const SegmentNavigator({
    super.key,
    required this.set,
    required this.chart,
    required this.segments,
  });

  final ComparisonSet set;
  final LapChart chart;
  final ComparisonSegments segments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focus = ref.watch(segmentFocusProvider).forSet(set);
    final notifier = ref.read(segmentFocusProvider.notifier);
    final actions = SegmentActions(
      ref,
      set: set,
      chart: chart,
      segments: segments,
    );
    final comparison = segments.inMode(focus.mode);
    final walk = comparison?.walk(focus.order);
    final stop = comparison == null ? null : focus.stopIn(comparison);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final difference = chart.comparison?.lapTimeDifference(chart.lap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SegmentedButton<SegmentMode>(
              segments: [
                for (final mode in SegmentMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {focus.mode},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
              ),
              onSelectionChanged: (selection) {
                notifier.setMode(selection.first);
                actions.wholeLap();
              },
            ),
            const SizedBox(width: 8),
            DropdownButton<SegmentOrder>(
              value: focus.order,
              isDense: true,
              style: theme.textTheme.bodyMedium,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              items: [
                for (final order in SegmentOrder.values)
                  DropdownMenuItem(value: order, child: Text(order.label)),
              ],
              onChanged: (order) {
                if (order != null) notifier.setOrder(order);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Previous (← or [)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left),
              onPressed: comparison == null
                  ? null
                  : () => actions.step(forward: false),
            ),
            Expanded(
              child: Text(
                comparison == null || walk == null
                    ? (segments.unavailable ?? '')
                    : _caption(comparison, walk, stop),
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Next (→ or ])',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right),
              onPressed: comparison == null
                  ? null
                  : () => actions.step(forward: true),
            ),
            if (difference != null) ...[
              const SizedBox(width: 8),
              AppTooltip(
                message: "The game's lap times, Base − Target",
                child: Text(
                  'Lap ${formatDelta(difference)} s',
                  style: AppTextStyles.numeral.copyWith(fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (comparison != null)
          _Strip(
            comparison: comparison,
            selected: stop,
            visited: {
              for (final s in walk!)
                if (s.stretch case final stretch?
                    when comparison.levelButNotable(stretch))
                  s.number,
            },
            onSelect: actions.select,
          ),
        if (comparison != null && focus.mode == SegmentMode.segments)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_tableCaption(segments.table!), style: muted),
          ),
        if (comparison != null && !comparison.loses) ...[
          const SizedBox(height: 8),
          _LevelEverywhere(set: set),
        ],
      ],
    );
  }

  /// "Seg 3 · 705–1158 m · Base +0.298 s vs Target · most lost, 1 of 4".
  String _caption(
    StretchComparison comparison,
    List<WalkStop> walk,
    WalkStop? stop,
  ) {
    final stretches = walk.where((s) => !s.recap).toList();
    if (stop == null) {
      return 'Base loses nowhere: choose a stretch, or step with →.';
    }
    if (stop.recap) {
      return 'Recap · Base ${formatDelta(comparison.total)} s vs Target over '
          'the lap';
    }
    final stretch = stop.stretch!;
    final segment = stretch.segment;
    final where = segment.start.isNaN || segment.end.isNaN
        ? segment.name
        : '${segment.name} · ${segment.start.toStringAsFixed(0)}–'
              '${segment.end.toStringAsFixed(0)} m';
    final position = stretches.indexOf(stop);
    final ties = comparison.nearTies;
    final tags = [
      if (identical(comparison.worst, stretch) ||
          comparison.worst?.segment == segment)
        ties.isEmpty
            ? 'most lost'
            : '${ties.map((s) => s.segment.name).join(' ≈ ')}, within '
                  '${nearTieMargin.toStringAsFixed(2)} s'
      else if (ties.any((s) => s.segment == segment))
        'near tie for most lost',
      if (comparison.levelButNotable(stretch)) 'level overall, but…',
      if (position >= 0) '${position + 1} of ${stretches.length}',
    ];
    return [
      where,
      'Base ${lossText(comparison, stretch)} vs Target',
      if (tags.isNotEmpty) tags.join(', '),
    ].join(' · ');
  }

  String _tableCaption(SegmentTable table) {
    final unstable =
        table.corners.where((c) => c.unstable).length +
        table.unstableDropped.length;
    return 'Segments cut from ${canonicalLabel(table.canonical)}, corners at '
        '${table.threshold.toStringAsFixed(0)} km/h'
        '${unstable == 0 ? '' : ' · $unstable unstable corner${unstable == 1 ? '' : 's'}'}';
  }
}

/// A stretch's loss as the caption and the Why card state it: signed, "≈0"
/// under the floor, "—" where a split is missing, and "≈" when the lap's
/// end is a line crossing.
String lossText(StretchComparison comparison, StretchLoss stretch) {
  final loss = stretch.loss;
  if (loss == null) return '—';
  if (stretch.level) return '≈0 s';
  final last = comparison.stretches.last == stretch;
  return last && comparison.endFromLineCrossing
      ? '≈ ${formatDelta(loss)} s (from line crossings, ±0.02 s)'
      : '${formatDelta(loss)} s';
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.comparison,
    required this.selected,
    required this.visited,
    required this.onSelect,
  });

  final StretchComparison comparison;
  final WalkStop? selected;

  /// Level stretches the walk visits, tagged "…".
  final Set<int?> visited;

  final void Function(WalkStop) onSelect;

  @override
  Widget build(BuildContext context) {
    final measured = [
      for (final s in comparison.stretches)
        if (s.loss != null) s.loss!.abs(),
    ];
    final scale = measured.isEmpty
        ? 1.0
        : measured.reduce((a, b) => a > b ? a : b);
    final worst = comparison.worst;
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final stretch in comparison.stretches)
            Expanded(
              // Width ∝ metres, so the strip reads as the lap; sectors
              // without stations share it equally.
              flex: stretch.segment.length.isFinite
                  ? stretch.segment.length.round().clamp(1, 100000)
                  : 1,
              child: _Cell(
                stretch: stretch,
                scale: scale,
                selected: selected?.number == stretch.segment.number,
                worst: worst?.segment == stretch.segment,
                visited: visited.contains(stretch.segment.number),
                onTap: () => onSelect(WalkStop(stretch)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.stretch,
    required this.scale,
    required this.selected,
    required this.worst,
    required this.visited,
    required this.onTap,
  });

  final StretchLoss stretch;
  final double scale;
  final bool selected;
  final bool worst;
  final bool visited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loss = stretch.loss;
    final value = switch (loss) {
      null => '—',
      _ when stretch.level => visited ? '≈0 …' : '≈0',
      final l => '${l < 0 ? '-' : '+'}${l.abs().toStringAsFixed(2)}',
    };
    final name = stretch.segment.label ?? '${stretch.segment.number}';
    return Semantics(
      button: true,
      selected: selected,
      label: _semanticLabel(),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: selected
              ? scheme.surfaceContainerHigh
              : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            // The worst stretch is ringed in ink: not red, which is brake,
            // and not iris, which is "fastest" (§8).
            side: worst
                ? BorderSide(color: scheme.onSurface, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
              // Name over value, so a short segment — 251 m of a 3083 m lap
              // is 70 px at 1000 px wide — still shows its number whole.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: AppTextStyles.numeral.copyWith(
                            fontSize: 11,
                            color: stretch.level || loss == null
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (loss != null && !stretch.level)
                    SizedBox(
                      width: 5,
                      child: CustomPaint(
                        painter: _BarPainter(
                          fraction: scale <= 0 ? 0 : loss / scale,
                          color: ChannelColors.resolve(context)
                              .of(ChannelRole.delta),
                          axis: scheme.outlineVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Segment 3, Base lost 0.298 seconds to the Target, most lost".
  String _semanticLabel() {
    final segment = stretch.segment;
    final who = segment.label ?? 'Segment ${segment.number}';
    final loss = stretch.loss;
    final what = switch (loss) {
      null => 'not measured',
      _ when stretch.level => 'Base level with the Target',
      final l when l > 0 =>
        'Base lost ${l.toStringAsFixed(3)} seconds to the Target',
      final l => 'Base gained ${(-l).toStringAsFixed(3)} seconds on the Target',
    };
    return [who, what, if (worst) 'most lost'].join(', ');
  }
}

/// A signed mini-bar in delta blue: up when Base is behind (§8 Strip).
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fraction,
    required this.color,
    required this.axis,
  });

  final double fraction;
  final Color color;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    final height = (mid - 2) * fraction.clamp(-1.0, 1.0);
    canvas.drawRect(
      Rect.fromLTRB(
        0,
        mid - (height > 0 ? height : 0),
        size.width,
        mid - (height < 0 ? height : 0),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.color != color || old.axis != axis;
}

/// Base loses nowhere (§5 "Nothing to show"): said, with the suggestions
/// for a Target that would show something.
class _LevelEverywhere extends StatelessWidget {
  const _LevelEverywhere({required this.set});

  final ComparisonSet set;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Base is level with or ahead of the Target everywhere',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'No stretch loses ${segmentNoiseFloor.toStringAsFixed(2)} s or '
              'more. A faster Target shows where time is left:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            SuggestionList(set: set, dense: true),
          ],
        ),
      ),
    );
  }
}
