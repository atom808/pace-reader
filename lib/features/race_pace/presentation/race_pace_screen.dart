import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/fl_chart_theme/per_lap_bar_chart.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/race_pace.dart';
import 'gap_format.dart';
import 'gap_session_chart.dart';

/// Race Pace & Gaps (SPEC.md §8.9).
///
/// Leads with five numbers, then the picture that explains them, then the
/// per-lap evidence, then the table that holds every value any of it drew — so
/// nothing here is readable only by hovering.
///
/// The one thing the screen has to be careful about is what "gap" it is
/// showing. `Time Behind Next` is a time offset to *whichever car is one place
/// ahead*, and that car changes: three times in the first lap of the Race
/// sample, each a step of 0.57 to 2.07 s that is somebody else being ahead now
/// and not the gap moving. Everything here that adds gaps up — the net figure,
/// each lap's bar — leaves those steps out, says so, and lists them.
class RacePaceScreen extends ConsumerWidget {
  const RacePaceScreen({super.key});

  static const _title = 'Race pace & gaps';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: _title,
        subject: 'the pace and gaps of a race',
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(_title)),
      body: AsyncValueView<RacePaceReport>(
        value: ref.watch(racePaceReportProvider(source)),
        loading: (_) => const _Loading(),
        data: (context, report) => switch (report.session) {
          final session? => _Report(session: session),
          null => _Unavailable(report: report),
        },
      ),
    );
  }
}

/// A section that rises into place: fades in and lifts 12 px, each one a beat
/// after the one above it, on [AppCurves.entrance].
///
/// One controller per section, its delay expressed as the leading part of its
/// own duration rather than a timer — so nothing is left pending when a test
/// stops pumping, and a reduced-motion setting is a single `value = 1`.
class _Enter extends HookWidget {
  const _Enter({required this.index, required this.child});

  final int index;
  final Widget child;

  static const _stagger = Duration(milliseconds: 70);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final total = AppDurations.slow + _stagger * index;
    final controller = useAnimationController(duration: total);
    useEffect(() {
      if (reduceMotion) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
      return null;
    }, [reduceMotion]);

    final delay = _stagger.inMilliseconds * index / total.inMilliseconds;
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay, 1, curve: AppCurves.entrance),
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

class _Report extends HookWidget {
  const _Report({required this.session});

  final GapSession session;

  @override
  Widget build(BuildContext context) {
    final cursor = useValueNotifier<double?>(null);
    final highlighted = useValueNotifier<int?>(null);
    final channels = ChannelColors.resolve(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Enter(index: 0, child: _Headline(session: session)),
        const SizedBox(height: 20),
        _Enter(
          index: 1,
          child: _GapCard(
            session: session,
            color: channels.delta,
            cursor: cursor,
            highlighted: highlighted,
          ),
        ),
        const SizedBox(height: 20),
        _Enter(
          index: 2,
          // Side by side where the window allows, since reading a lap's bar
          // against the change list beside it is the comparison the pair is
          // for; stacked below that, when the bars would be too narrow for
          // twenty laps.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bars = _PerLapCard(session: session, color: channels.delta);
              final changes = _ChangesCard(
                session: session,
                cursor: cursor,
                highlighted: highlighted,
              );
              if (constraints.maxWidth < 1000) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [bars, const SizedBox(height: 16), changes],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: bars),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: changes),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _Enter(index: 3, child: _LapTable(session: session)),
      ],
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.session});

  final GapSession session;

  @override
  Widget build(BuildContext context) {
    final closest = session.closestApproach;
    final changes = session.changes;
    final counted = session.countedLaps.length;
    final net = session.netGained;
    final origin = session.originSeconds;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        StatTile(
          label: 'Gap at the start',
          value: formatGap(session.startGap),
          caption: switch (session.heldAtStart) {
            final held? =>
              'first reading, unchanged for ${formatHeldDuration(held.durationSeconds)}',
            null => 'first reading',
          },
        ),
        StatTile(
          label: 'Gap at the end',
          value: formatGap(session.endGap),
          caption: switch (session.heldAtEnd) {
            final held? =>
              'last reading, unchanged for the last ${formatHeldDuration(held.durationSeconds)}',
            null => 'last reading',
          },
        ),
        StatTile(
          label: 'Net against the car ahead',
          value: formatGap(net),
          caption: '${net < 0 ? 'lost' : 'gained'} over '
              '${counted == 1 ? '1 lap' : '$counted laps'}'
              '${changes.isEmpty ? '' : ', not counting the ${changes.length} '
                  '${changes.length == 1 ? 'change' : 'changes'} of car ahead'}',
          emphasised: true,
        ),
        StatTile(
          label: 'Closest approach',
          value: formatGap(closest?.gap),
          caption: closest == null
              ? 'no reading'
              : 'at ${formatSessionClock(closest.atSeconds, origin: origin)}'
                  '${session.lapAt(closest.atSeconds) == null ? '' : ' · lap ${session.lapAt(closest.atSeconds)!.displayNumber}'}',
        ),
        StatTile(
          label: 'Car ahead changed',
          value: changes.isEmpty ? '0' : '${changes.length}×',
          caption: _changesCaption(changes),
        ),
      ],
    );
  }

  static String _changesCaption(List<CarAheadChange> changes) {
    if (changes.isEmpty) {
      return 'no step of ${carAheadChangeThreshold.toStringAsFixed(1)} s '
          'or more';
    }
    final closedFirst = changes.where((c) => c.closedInFirst()).toList();
    if (closedFirst.length == changes.length) {
      final worst = changes.map((c) => c.closedTo).reduce((a, b) => a > b ? a : b);
      return 'each right after closing to within ${worst.toStringAsFixed(2)} s';
    }
    return '${closedFirst.length} of ${changes.length} right after closing '
        'to within 0.5 s';
  }
}

/// The frame every chart on this screen sits in: a title, what the axis is,
/// the chart, and one line saying how to read it.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.unit,
    required this.caption,
    required this.child,
    this.trailing,
  });

  final String title;
  final String unit;
  final String caption;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text(unit,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted)),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 8),
          Text(caption,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

class _GapCard extends StatelessWidget {
  const _GapCard({
    required this.session,
    required this.color,
    required this.cursor,
    required this.highlighted,
  });

  final GapSession session;
  final Color color;
  final ValueNotifier<double?> cursor;
  final ValueNotifier<int?> highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return _ChartCard(
      title: 'Gap to the car ahead',
      unit: 's',
      trailing: Text(
        'Below zero you are behind it; a rising line is you closing on it.',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      // Says what was drawn from what — §9.5's no-silent-caps rule, applied to
      // decimation. The rings and the dimming are named where they occur.
      caption: 'Drawn from ${session.envelope.length} min/max buckets of '
          '${session.readings.length} readings.'
          '${session.changes.isEmpty ? '' : ' Rings mark where the car ahead changed.'}'
          '${session.heldAtStart == null && session.heldAtEnd == null ? '' : ' Dimmed stretches did not change at all.'}'
          '${session.pitVisits.isEmpty ? '' : ' Shaded bands are pit-lane visits.'}'
          ' Arrow keys read it.',
      child: GapSessionChart(
        session: session,
        color: color,
        cursor: cursor,
        highlightedChange: highlighted,
      ),
    );
  }
}

class _PerLapCard extends StatelessWidget {
  const _PerLapCard({required this.session, required this.color});

  final GapSession session;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final counted = session.countedLaps;
    final average = counted.isEmpty ? null : session.netGained / counted.length;
    return _ChartCard(
      title: 'Gained / lost per lap',
      unit: 's',
      caption: 'Up is time gained on the car ahead. Grey laps are left out of '
          'the net — hover one to see why.',
      child: PerLapBarChart(
        color: color,
        signed: true,
        formatValue: (value) => formatGap(value),
        reference: average,
        referenceLabel: average == null ? null : 'avg ${formatGap(average)}',
        bars: [
          for (final lap in session.laps)
            PerLapBar(
              lapNumber: lap.lap.displayNumber,
              value: lap.gained,
              muted: !lap.counted,
              note: lap.exclusion?.label ??
                  (lap.changes.isEmpty
                      ? null
                      : 'car ahead changed ${lap.changes.length}× — those '
                          'steps are not counted'),
            ),
        ],
      ),
    );
  }
}

/// The changes of car ahead, listed: what happened, when, and between which
/// readings. Hovering or focusing a row rings it on the gap chart; activating
/// it moves the chart's cursor there.
class _ChangesCard extends StatelessWidget {
  const _ChangesCard({
    required this.session,
    required this.cursor,
    required this.highlighted,
  });

  final GapSession session;
  final ValueNotifier<double?> cursor;
  final ValueNotifier<int?> highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final changes = session.changes;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Car ahead changed', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              Text('${changes.length}',
                  style: AppTextStyles.numeral
                      .copyWith(fontSize: 12, color: muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (changes.isEmpty)
            // Stated rather than left as an empty card: it is a normal result,
            // and the threshold behind it is worth naming.
            Text(
              'No reading stepped by ${carAheadChangeThreshold.toStringAsFixed(1)} s '
              'or more, so the gap was measured to one car throughout — or '
              'to cars too close together to tell apart.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 268),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: changes.length,
                itemBuilder: (context, i) => _ChangeRow(
                  index: i,
                  change: changes[i],
                  session: session,
                  cursor: cursor,
                  highlighted: highlighted,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A step this size is a different car being ahead, not the gap '
              'moving, and is left out of every figure above.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.index,
    required this.change,
    required this.session,
    required this.cursor,
    required this.highlighted,
  });

  final int index;
  final CarAheadChange change;
  final GapSession session;
  final ValueNotifier<double?> cursor;
  final ValueNotifier<int?> highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final lap = session.lapAt(change.timeSeconds);
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13);

    void set(bool on) {
      if (on) {
        highlighted.value = index;
      } else if (highlighted.value == index) {
        highlighted.value = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: AppRadii.squircle(AppRadii.sm),
          onTap: () => cursor.value = change.timeSeconds,
          onHover: set,
          onFocusChange: set,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    shape: AppRadii.squircle(8),
                    color: scheme.surfaceContainerHighest,
                  ),
                  child: Text('${index + 1}',
                      style: AppTextStyles.numeral
                          .copyWith(fontSize: 11, color: muted)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${formatGap(change.before)}  →  ${formatGap(change.after)}',
                        style: numeral,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        change.closedInFirst()
                            ? 'closed to ${change.closedTo.toStringAsFixed(2)} s first'
                            : 'from ${change.closedTo.toStringAsFixed(2)} s',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  [
                    if (lap != null) 'lap ${lap.displayNumber}',
                    formatSessionClock(change.timeSeconds,
                        origin: session.originSeconds),
                  ].join(' · '),
                  style: AppTextStyles.numeral
                      .copyWith(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every value the charts draw, as a table — the view that needs no hover and
/// no colour to read.
class _LapTable extends StatelessWidget {
  const _LapTable({required this.session});

  final GapSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    DataCell numeral(String text, {required bool muted}) => DataCell(Text(
          text,
          style: AppTextStyles.numeral
              .copyWith(color: muted ? scheme.onSurfaceVariant : null),
        ));

    return SquircleCard(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingTextStyle: theme.textTheme.bodySmall,
              // Tighter than the default 56 so the eight columns fit a
              // 1000 px window without the note running off the card.
              columnSpacing: 32,
              columns: const [
                DataColumn(label: Text('Lap')),
                DataColumn(label: Text('Lap time'), numeric: true),
                DataColumn(label: Text('Gap at start'), numeric: true),
                DataColumn(label: Text('Gap at end'), numeric: true),
                DataColumn(label: Text('Gained / lost'), numeric: true),
                DataColumn(label: Text('Closest'), numeric: true),
                DataColumn(label: Text('Average'), numeric: true),
                DataColumn(label: Text('Note')),
              ],
              rows: [
                for (final gap in session.laps)
                  DataRow(
                    cells: [
                      numeral('${gap.lap.displayNumber}', muted: !gap.counted),
                      numeral(formatOptionalLapTime(gap.lap.lapTimeSeconds),
                          muted: !gap.counted),
                      numeral(formatGap(gap.start, unit: false),
                          muted: !gap.counted),
                      numeral(formatGap(gap.end, unit: false),
                          muted: !gap.counted),
                      numeral(formatGap(gap.gained, unit: false),
                          muted: !gap.counted),
                      numeral(formatGap(gap.closest, unit: false),
                          muted: !gap.counted),
                      numeral(formatGap(gap.mean, unit: false),
                          muted: !gap.counted),
                      DataCell(Text(
                        gap.exclusion?.label ??
                            (gap.changes.isEmpty
                                ? ''
                                : 'car ahead changed ${gap.changes.length}×'),
                      )),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when there is no gap to draw, saying *why* — three different reasons
/// that would each read as a blank screen if left unexplained.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.report});

  final RacePaceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final (icon, title, body) = switch (report.unavailable!) {
      GapUnavailable.notARace => (
          Icons.flag_outlined,
          'This view is for races',
          'This is ${_describe(report.sessionType)}. Outside a race, '
              '“Time Behind Next” is not a gap you can watch open and close: '
              'in practice and qualifying recordings it flips between '
              'positive and negative, sits at exactly zero for stretches and '
              'jumps by tens of seconds, which is not how the distance to '
              'the car ahead on the road behaves. Drawing it as one would '
              'mislead. Open a race recording to see the pace and gaps.',
        ),
      GapUnavailable.noChannel => (
          Icons.search_off_outlined,
          'No gap channel in this recording',
          'This race carries no “Time Behind Next” channel, which is what the '
              'gap to the car ahead is read from.',
        ),
      GapUnavailable.noCarAhead => (
          Icons.remove_road_outlined,
          'No car ahead was timed',
          'Every reading of “Time Behind Next” in this race is zero — the value '
              'the game writes when there is no car to time against.',
        ),
    };

    return _Enter(
      index: 0,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SquircleCard(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 40, color: muted),
                  const SizedBox(height: 16),
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _describe(SessionType type) => switch (type) {
        SessionType.practice => 'a practice session',
        SessionType.qualify => 'a qualifying session',
        SessionType.race => 'a race',
      };
}

/// The screen's own loading state: the shape of what is coming, so the page
/// does not reflow when it arrives.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (var i = 0; i < 5; i++)
              const Skeleton(width: 220, height: 108),
          ],
        ),
        const SizedBox(height: 20),
        const Skeleton(height: 372, radius: 28),
        const SizedBox(height: 20),
        const Skeleton(height: 280, radius: 28),
      ],
    );
  }
}
