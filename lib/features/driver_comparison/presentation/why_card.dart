/// The Why card (comparison proposal §3, §5 "Inside a segment"): what
/// happened inside the selected stretch, worded as movement, and what was
/// measured at its corner — the brake point, the slowest point, the gears,
/// the line and any contact (§9 `segment_findings.dart`).
///
/// It never says "ahead by". Inside a segment the movement is relative to
/// the segment's start, and at the hairpin's turn the Delta panel reads
/// about −0.17 s while Base has *gained* 0.271 s since the segment began —
/// an absolute figure here would contradict the trace above it.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/comparison_chart.dart';
import '../application/comparison_focus.dart';
import '../application/segment_tables.dart';
import '../domain/comparison_set.dart';
import '../domain/lines.dart';
import '../domain/segment_findings.dart';
import '../domain/segment_losses.dart';
import '../domain/segments.dart';
import 'finding_text.dart';
import 'segment_navigator.dart';

class WhyCard extends ConsumerWidget {
  const WhyCard({
    super.key,
    required this.set,
    required this.segments,
    this.view,
  });

  final ComparisonSet set;
  final ComparisonSegments segments;

  /// The pair as drawn: what the line finding reads.
  final ComparisonView? view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final focus = ref.watch(segmentFocusProvider).forSet(set);
    final comparison = segments.inMode(focus.mode);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (comparison == null) {
      // The navigator above says why; this says what is left.
      return Text(
        'Nothing to explain segment by segment. Sectors still compare the '
        "game's own splits.",
        style: muted,
      );
    }
    final stop = focus.stopIn(comparison);
    final lines = <Widget>[];
    if (stop == null) {
      lines.add(
        Text(
          'Base is level with or ahead of the Target everywhere. Choose a '
          'stretch to see what happened in it.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    } else if (stop.recap) {
      lines.addAll(_recap(theme, comparison));
    } else {
      lines.addAll(_stretch(context, ref, comparison, stop.stretch!));
    }
    final table = segments.table;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...lines,
        if (focus.mode == SegmentMode.segments && table != null) ...[
          const SizedBox(height: 12),
          Text(
            'Segments are cut once per course, from '
            '${canonicalLabel(table.canonical)}, and kept: another Target '
            'or a Swap measures the same metres.',
            style: muted,
          ),
        ],
      ],
    );
  }

  List<Widget> _stretch(
    BuildContext context,
    WidgetRef ref,
    StretchComparison comparison,
    StretchLoss stretch,
  ) {
    final theme = Theme.of(context);
    final segment = stretch.segment;
    final loss = stretch.loss;
    final from = segment.start.toStringAsFixed(0);
    final to = segment.end.toStringAsFixed(0);
    final sectors = comparison.mode == SegmentMode.sectors;
    final body = theme.textTheme.bodyMedium;
    final turn = stretch.turn;
    final table = segments.table;
    final findings = sectors ? null : segments.findings;
    final corner = findings?.inSegment(segment.number);
    Widget line(String text, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: style ?? body),
    );
    return [
      Text(
        '${segment.name} · Base vs Target · '
        '${loss == null ? 'not timed' : 'net ${lossText(comparison, stretch)}'}',
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      if (loss == null)
        Text(
          'The game did not time this sector on '
          '${stretch.baseSeconds == null ? 'Base' : 'the Target'}, so it is '
          'not compared (a split written as 0.0 is never read as 0).',
          style: body,
        )
      else if (turn != null && turn.stated)
        Text(
          '${_moved(turn.first, capital: true)} from $from to '
          '${turn.station.toStringAsFixed(0)} m, then '
          '${_moved(turn.second)} to $to m '
          '(net ${formatDelta(loss)})',
          style: body,
        )
      else if (stretch.level)
        Text(
          'Level from $from to $to m: within '
          '${segmentNoiseFloor.toStringAsFixed(2)} s, which is as close as '
          'the timing can tell two laps apart.',
          style: body,
        )
      else
        Text(
          sectors
              ? '${_moved(loss, capital: true)} in ${segment.name}, by the '
                    "game's own splits."
              : '${_moved(loss, capital: true)} from $from to $to m.',
          style: body,
        ),
      if (corner != null) ...[
        line(brakeText(corner.brake)),
        if (brakeSpeedText(corner.brake) case final speeds?) line(speeds),
        line(slowestText(corner.slowest)),
        for (final text in gearText(corner.gear)) line(text),
      ],
      if (!sectors && table != null) ?_line(theme, table, segment, corner),
      for (final contact in findings?.contactsIn(segment.number) ?? const [])
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 6),
                child: Icon(
                  Icons.warning_amber_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Expanded(child: Text(contactText(contact), style: body)),
            ],
          ),
        ),
      for (final braking in findings?.brakingFrom(segment) ?? const [])
        ?_brakingFrom(context, ref, comparison, braking, segment),
      if (corner != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  throttleNotStated,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              AppTooltip(
                message: findingFloors.join('\n\n'),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    semanticLabel: 'What the card states, and from when',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      if (!sectors && segments.findingsUnavailable != null)
        line(segments.findingsUnavailable!, style: theme.textTheme.bodySmall),
      if (!sectors && segment.number == 1) ...[
        const SizedBox(height: 6),
        Text(
          "Starts at the line: carries the previous lap's exit.",
          style: theme.textTheme.bodySmall,
        ),
      ],
      if (!sectors && table != null && table.unstableIn(segment)) ...[
        const SizedBox(height: 6),
        Text(
          'A corner in this segment is unstable: on other clean laps it '
          'falls the other side of the '
          '${table.threshold.toStringAsFixed(0)} km/h threshold often '
          'enough that the table could as well have been cut differently.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    ];
  }

  /// The two lines at Base's slowest point of the segment's corner (§6):
  /// "Line at 815 m: Target 3.1 m further right, the inside of this
  /// right-hander". Stated only behind the centre-path gate.
  Widget? _line(
    ThemeData theme,
    SegmentTable table,
    Segment segment,
    CornerFindings? findings,
  ) {
    final line = view?.line;
    if (line == null) return null;
    final corner = table.corners
        .where((c) => segment.contains(c.station))
        .firstOrNull;
    if (corner == null) return null;
    final Text text;
    if (!line.shown) {
      text = Text(
        'Line not compared: ${line.withheld}.',
        style: theme.textTheme.bodySmall,
      );
    } else {
      final slowest = findings?.slowest;
      final station = slowest != null && slowest.stated
          ? slowest.base!.station
          : corner.station;
      final words = lineAt(line.base!, line.target!, station);
      if (words == null) return null;
      text = Text(
        'Line at ${toFive(station)} m: $words.',
        style: theme.textTheme.bodyMedium,
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 6), child: text);
  }

  /// "Braking for Seg 2 starts here: Base at 334 m", with a link to the
  /// segment its corner is listed on (§5 "Findings and segments").
  Widget? _brakingFrom(
    BuildContext context,
    WidgetRef ref,
    StretchComparison comparison,
    CornerFindings braking,
    Segment here,
  ) {
    final listed = comparison.byNumber(braking.segment);
    final chart = view?.chart;
    if (listed == null) return null;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              brakingFromText(braking, here, listed.segment.name),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (chart != null)
            TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => SegmentActions(
                ref,
                set: set,
                chart: chart,
                segments: segments,
              ).jump(WalkStop(listed)),
              child: Text('${listed.segment.name} ›'),
            ),
        ],
      ),
    );
  }

  List<Widget> _recap(ThemeData theme, StretchComparison comparison) {
    final lost = [
      for (final s in comparison.stretches)
        if (s.loss != null && !s.level && s.loss! > 0) s,
    ]..sort((a, b) => b.loss!.compareTo(a.loss!));
    final gained = [
      for (final s in comparison.stretches)
        if (s.loss != null && !s.level && s.loss! < 0) s,
    ]..sort((a, b) => a.loss!.compareTo(b.loss!));
    String list(List<StretchLoss> stretches) => stretches
        .map((s) => '${s.segment.name} ${formatDelta(s.loss!)}')
        .join(', ');
    return [
      Text(
        'Recap · Base ${formatDelta(comparison.total)} s vs Target',
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      Text(
        lost.isEmpty ? 'Lost nowhere.' : 'Lost: ${list(lost)}.',
        style: theme.textTheme.bodyMedium,
      ),
      Text(
        gained.isEmpty ? 'Gained nowhere.' : 'Gained: ${list(gained)}.',
        style: theme.textTheme.bodyMedium,
      ),
    ];
  }
}

/// "Gained 0.271 s" / "lost 0.569 s": movement, never a position.
String _moved(double seconds, {bool capital = false}) {
  final verb = seconds < 0 ? 'gained' : 'lost';
  final word = capital ? '${verb[0].toUpperCase()}${verb.substring(1)}' : verb;
  return '$word ${seconds.abs().toStringAsFixed(3)} s';
}
