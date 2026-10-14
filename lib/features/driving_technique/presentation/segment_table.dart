/// The segment table (SPEC.md §8.13.5, §8.13.7): the timed measures per
/// segment for the selected lap against the session median, each segment
/// opening onto its corners, and — with a lens on — each segment's change.
///
/// Every time figure here is per segment, never per corner: segments tile
/// the lap, so their times add up to it, and corners do not.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driver_comparison/domain/segments.dart';
import '../application/technique_providers.dart';
import '../data/technique_reads.dart';
import '../domain/conditions_lens.dart';
import '../domain/geometric_corners.dart';
import '../domain/lap_technique.dart';
import 'technique_widgets.dart';

/// Column widths, so header and rows line up.
abstract final class _W {
  static const name = 124.0;
  static const time = 64.0;
  static const delta = 68.0;
  static const speed = 62.0;
  static const value = 55.0;
  static const lens = 156.0;
}

class SegmentTable extends ConsumerWidget {
  const SegmentTable({super.key, required this.source, required this.lap});

  final TelemetrySource source;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(techniqueCourseProvider(source));
    final placement = ref.watch(techniquePlacementProvider(source));
    final focus = ref.watch(techniqueFocusStateProvider(source));
    final session = ref.watch(techniqueSessionProvider(source)).value;
    final lens = ref.watch(techniqueLensResultProvider(source));
    final hasAbs = session?.hasAbs ?? false;

    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Segment by segment',
            caption: 'Lap ${lap.lap.displayNumber} against the session median',
          ),
          AnimatedSize(
            duration: AppMotion.reduced(context)
                ? const Duration(milliseconds: 1)
                : AppDurations.medium,
            curve: AppCurves.entrance,
            alignment: Alignment.topCenter,
            child: lens == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _LensSummary(result: lens),
                  ),
          ),
          switch ((course, placement)) {
            (AsyncData(value: final c), AsyncData(value: final p)) =>
              c.table == null
                  ? AbsenceNote(c.unavailable ?? 'No segments for this course.')
                  : _Table(
                      source: source,
                      course: c,
                      placement: p,
                      lap: lap,
                      focus: focus,
                      hasAbs: hasAbs,
                      lens: lens,
                    ),
            (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
              AbsenceNote('Segments could not be read: $error'),
            _ => const _LoadingRows(),
          },
        ],
      ),
    );
  }
}

class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < 6; i++)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Skeleton(height: 22),
        ),
    ],
  );
}

class _Table extends ConsumerWidget {
  const _Table({
    required this.source,
    required this.course,
    required this.placement,
    required this.lap,
    required this.focus,
    required this.hasAbs,
    required this.lens,
  });

  final TelemetrySource source;
  final TechniqueCourse course;
  final TechniquePlacement? placement;
  final LapTechnique lap;
  final TechniqueFocus focus;
  final bool hasAbs;
  final LensResult? lens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segments = course.segments;
    final times = course.segmentTimes[lap.lap.index];
    final maxLens = lens == null
        ? 0.0
        : lens!.segments
              .map((s) => (s.time.change ?? 0).abs())
              .fold(0.0, (a, b) => a > b ? a : b);
    final notifier = ref.read(techniqueFocusStateProvider(source).notifier);

    final header = _HeaderRow(hasAbs: hasAbs, lensOn: lens != null);
    final rows = <Widget>[
      for (final (i, s) in segments.indexed)
        _SegmentRow(
          segment: s,
          index: i,
          time: times != null && i < times.length ? times[i] : null,
          median: course.medianTime(i),
          totals: placement?.segment(lap.lap.index, s.number),
          medianSlowest: placement?.segmentMedian(s.number, (t) => t.slowest),
          corners: course.cornersIn(s),
          placement: placement,
          lapIndex: lap.lap.index,
          hasAbs: hasAbs,
          active: focus.active?.segment == s.number,
          activeCorner: focus.active?.segment == s.number
              ? focus.active?.corner
              : null,
          expanded: focus.expanded.contains(s.number),
          lens: lens?.segments.elementAtOrNull(i),
          lensKey: lens?.option,
          lensMax: maxLens,
          slides: [
            for (final e in lap.countersteer)
              if (s.contains(e.station)) e.station,
          ],
          onHover: (corner) => notifier.hover(
            corner == null
                ? StretchRef.segment(s.number)
                : StretchRef.corner(s.number, corner),
          ),
          onExit: () => notifier.hover(null),
          onTap: () {
            notifier.toggleExpanded(s.number);
            notifier.select(StretchRef.segment(s.number));
          },
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, ...rows],
        );
        const natural =
            _W.name + _W.time + _W.delta + _W.speed + _W.value * 6 + 16;
        if (constraints.maxWidth >= natural + (lens == null ? 0 : _W.lens)) {
          return table;
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: natural + (lens == null ? 0 : _W.lens),
            child: table,
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.hasAbs, required this.lensOn});

  final bool hasAbs;
  final bool lensOn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.1,
    );
    Widget cell(String text, double width, {String? tip}) => SizedBox(
      width: width,
      child: AppTooltip(
        message: tip ?? '',
        child: Text(
          text,
          style: style,
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          Expanded(child: Text('SEGMENT', style: style)),
          cell('TIME', _W.time, tip: 'Segment time, s'),
          cell('VS MEDIAN', _W.delta, tip: 'Against the session median, s'),
          cell('SLOWEST', _W.speed, tip: 'Slowest Ground Speed, km/h'),
          cell('BRAKE', _W.value, tip: 'Seconds on the brake'),
          cell('TRAIL', _W.value, tip: 'Braking with the wheel turned, %'),
          cell('OVERLAP', _W.value, tip: 'Both pedals, s'),
          cell('COAST', _W.value, tip: 'Neither pedal, s'),
          cell('TC', _W.value, tip: 'Traction control, s'),
          if (hasAbs) cell('ABS', _W.value, tip: 'ABS, s'),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppDurations.medium),
            curve: AppCurves.entrance,
            width: lensOn ? _W.lens : 0,
            child: lensOn
                ? Text(
                    'LENS CHANGE',
                    style: style,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.segment,
    required this.index,
    required this.time,
    required this.median,
    required this.totals,
    required this.medianSlowest,
    required this.corners,
    required this.placement,
    required this.lapIndex,
    required this.hasAbs,
    required this.active,
    required this.activeCorner,
    required this.expanded,
    required this.lens,
    required this.lensKey,
    required this.lensMax,
    required this.slides,
    required this.onHover,
    required this.onExit,
    required this.onTap,
  });

  final Segment segment;
  final int index;
  final double? time;
  final double? median;
  final PedalTotals? totals;
  final double? medianSlowest;
  final List<GeoCorner> corners;
  final TechniquePlacement? placement;
  final int lapIndex;
  final bool hasAbs;
  final bool active;
  final int? activeCorner;
  final bool expanded;
  final SegmentLens? lens;
  final LensOption? lensKey;
  final double lensMax;
  final List<double> slides;
  final ValueChanged<int?> onHover;
  final VoidCallback onExit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final t = totals;
    final delta = time == null || median == null ? null : time! - median!;
    final trail = t?.trailShare;
    double? seconds(int Function(PedalTotals) count) {
      if (t == null) return null;
      return t.seconds(count(t));
    }

    final motion = AppMotion.duration(context, AppDurations.fast);
    TextStyle numeral([Color? color]) =>
        AppTextStyles.numeral.copyWith(fontSize: 12.5, color: color);
    Widget value(double? v, double width, int decimals, {Color? color}) =>
        SizedBox(
          width: width,
          child: Align(
            alignment: Alignment.centerRight,
            child: RollingNumber(
              value: v,
              format: (x) => x.toStringAsFixed(decimals),
              style: numeral(color),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => onHover(null),
          onExit: (_) => onExit(),
          child: Hoverable(
            radius: AppRadii.sm,
            onTap: onTap,
            semanticLabel:
                '${segment.name}, ${expanded ? 'hide' : 'show'} '
                'its corners',
            child: AnimatedContainer(
              duration: motion,
              curve: AppCurves.standard,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: ShapeDecoration(
                shape: AppRadii.squircle(AppRadii.sm),
                color: active
                    ? scheme.onSurface.withValues(alpha: 0.08)
                    : index.isOdd
                    ? scheme.onSurface.withValues(alpha: 0.025)
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        AnimatedRotation(
                          duration: AppMotion.duration(
                            context,
                            AppDurations.medium,
                          ),
                          curve: AppCurves.entrance,
                          turns: expanded ? 0.25 : 0,
                          child: Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: corners.isEmpty ? Colors.transparent : muted,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(segment.name, style: theme.textTheme.labelLarge),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            corners.isEmpty
                                ? ''
                                : '${corners.length} ${corners.length == 1 ? 'corner' : 'corners'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (slides.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          AppTooltip(
                            message: 'A caught slide in this segment',
                            child: Icon(
                              Icons.radio_button_unchecked,
                              size: 11,
                              color: ChannelColors.resolve(context).steering,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  value(time, _W.time, 3),
                  SizedBox(
                    width: _W.delta,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: RollingNumber(
                        value: delta,
                        signed: true,
                        format: (x) => x.toStringAsFixed(3),
                        style: numeral(
                          delta != null && delta.abs() < 0.02
                              ? muted
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  value(t?.slowest, _W.speed, 0),
                  value(seconds((t) => t.braking), _W.value, 2),
                  value(trail == null ? null : 100 * trail, _W.value, 0),
                  value(seconds((t) => t.overlap), _W.value, 2),
                  value(seconds((t) => t.coast), _W.value, 2),
                  value(seconds((t) => t.tc), _W.value, 2),
                  if (hasAbs) value(seconds((t) => t.abs), _W.value, 2),
                  _LensCell(effect: lens, key_: lensKey, max: lensMax),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          // Skipped rather than zeroed under reduced motion: Flutter 3.47
          // asserts on an AnimatedSize with a zero duration (§9.7.4).
          duration: AppMotion.reduced(context)
              ? const Duration(milliseconds: 1)
              : AppDurations.medium,
          curve: AppCurves.entrance,
          alignment: Alignment.topCenter,
          child: !expanded || corners.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(left: 26, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (k, c) in corners.indexed)
                        _CornerRow(
                          corner: c,
                          position: k + 1,
                          totals: placement?.corner(lapIndex, c.number),
                          g: placement?.cornerG(lapIndex, c.number),
                          hasAbs: hasAbs,
                          active: activeCorner == c.number,
                          slides: slides.where(c.contains).length,
                          onHover: () => onHover(c.number),
                          onExit: onExit,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// One corner: its local measures, never a time (§8.13.5).
class _CornerRow extends StatelessWidget {
  const _CornerRow({
    required this.corner,
    required this.position,
    required this.totals,
    required this.g,
    required this.hasAbs,
    required this.active,
    required this.slides,
    required this.onHover,
    required this.onExit,
  });

  final GeoCorner corner;
  final int position;
  final PedalTotals? totals;
  final GgStretch? g;
  final bool hasAbs;
  final bool active;
  final int slides;
  final VoidCallback onHover;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final t = totals;
    final facts = <(String, String)>[
      if (t?.slowest case final v?) ('slowest', '${v.toStringAsFixed(0)} km/h'),
      if (g?.peakLateral case final v?) ('peak', '${v.toStringAsFixed(2)} G'),
      if (g?.utilisation case final v?)
        ('grip used', '${(100 * v).toStringAsFixed(0)} %'),
      if (t?.steerAtApex case final v?)
        ('steer at apex', '${v.abs().toStringAsFixed(0)} %'),
      if (t != null && t.tc > 0)
        ('TC', '${t.seconds(t.tc).toStringAsFixed(2)} s'),
      if (t != null && hasAbs && t.abs > 0)
        ('ABS', '${t.seconds(t.abs).toStringAsFixed(2)} s'),
      if (slides > 0) ('caught slide', '$slides'),
    ];
    return MouseRegion(
      onEnter: (_) => onHover(),
      onExit: (_) => onExit(),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppDurations.fast),
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(AppRadii.sm),
          color: active ? scheme.onSurface.withValues(alpha: 0.07) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 190,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'corner $position · '),
                    TextSpan(
                      text:
                          '${corner.direction.letter}, '
                          '${corner.radius.toStringAsFixed(0)} m',
                      style: AppTextStyles.numeral.copyWith(fontSize: 12),
                    ),
                    TextSpan(
                      text: ' · ${corner.turnDegrees.toStringAsFixed(0)}°',
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 14,
                runSpacing: 2,
                children: [
                  for (final (k, v) in facts)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$k ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                          TextSpan(
                            text: v,
                            style: AppTextStyles.numeral.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One segment's lens change: a bar in the delta's cool blue growing from
/// the centre — right for time lost, left for time gained — muted when the
/// change is within lap-to-lap noise (§8.13.8 "Lens").
class _LensCell extends StatelessWidget {
  const _LensCell({
    required this.effect,
    required this.key_,
    required this.max,
  });

  final SegmentLens? effect;

  /// The option the bars belong to: a new one regrows them from zero.
  final LensOption? key_;
  final double max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = ChannelColors.resolve(context).delta;
    final e = effect;
    final change = e?.time.change;
    final noise = e?.time.withinNoise ?? true;
    final share = e?.timeShare;
    final fraction = change == null || max <= 0 ? 0.0 : change / max;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.medium),
      curve: AppCurves.entrance,
      width: key_ == null ? 0 : _W.lens,
      child: key_ == null
          ? null
          : AppTooltip(
              message: change == null
                  ? 'Not measurable for this segment.'
                  : noise
                  ? 'Within lap-to-lap noise (under two standard errors).'
                  : 'Change ${change >= 0 ? '+' : ''}${change.toStringAsFixed(3)} s '
                        '± ${e!.time.standardError!.toStringAsFixed(3)}',
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 12,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(key_),
                        tween: Tween(begin: 0, end: fraction),
                        duration: AppMotion.duration(
                          context,
                          const Duration(milliseconds: 300),
                        ),
                        curve: AppCurves.entrance,
                        builder: (context, f, _) => CustomPaint(
                          painter: _CentredBar(
                            fraction: f,
                            color: noise
                                ? theme.colorScheme.onSurfaceVariant.withValues(
                                    alpha: 0.35,
                                  )
                                : delta,
                            axis: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      change == null
                          ? '—'
                          : '${_signedChange(change)}'
                                '${share == null ? '' : ' ${(100 * share).abs().toStringAsFixed(0)}%'}',
                      textAlign: TextAlign.right,
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 11.5,
                        color: noise
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _CentredBar extends CustomPainter {
  _CentredBar({
    required this.fraction,
    required this.color,
    required this.axis,
  });

  final double fraction;
  final Color color;
  final Color axis;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.width / 2;
    canvas.drawLine(
      Offset(mid, 0),
      Offset(mid, size.height),
      Paint()
        ..color = axis
        ..strokeWidth = 1,
    );
    final w = mid * fraction.clamp(-1.0, 1.0);
    if (w == 0) return;
    final rect = Rect.fromLTRB(
      w > 0 ? mid : mid + w,
      2,
      w > 0 ? mid + w : mid,
      size.height - 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_CentredBar old) =>
      old.fraction != fraction || old.color != color;
}

/// What the lens compared, and how far to trust it (§8.13.6).
class _LensSummary extends StatelessWidget {
  const _LensSummary({required this.result});

  final LensResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final delta = ChannelColors.resolve(context).delta;
    final o = result.option;
    final lapEffect = result.lapTime;
    final ranked = result.rankedByShare;
    final lines = <String>[
      '${result.otherLaps} laps ${o.condition.format(o.other)} against '
          '${result.baselineLaps} ${o.condition.format(o.baseline)}, each '
          'group\'s slowest outliers left out.',
      result.adjusted
          ? 'The setting alternated, so each segment is compared after '
                'removing the lap-number trend (fuel burn, tyre wear).'
          : 'It changed once, so the laps either side are compared as they '
                'are: fuel and tyres changed with it, and could not be '
                'adjusted for.',
      if (result.changedTogether.isNotEmpty)
        'Changed with it: ${result.changedTogether.join(', ')}.'
      else
        'Nothing else in the file changed with it.',
      if (o.condition == LensCondition.compound)
        'A new compound comes with a pit stop and fresh tyres, so a loss '
            'across it is if anything understated.',
    ];
    final change = lapEffect.change;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.md),
        color: delta.withValues(alpha: 0.08),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.filter_center_focus, size: 16, color: delta),
                Text(o.label, style: theme.textTheme.labelLarge),
                if (change != null)
                  Text(
                    'lap ${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(2)} s'
                    '${lapEffect.withinNoise ? ' · within lap-to-lap noise' : ''}',
                    style: AppTextStyles.numeral.copyWith(
                      fontSize: 12,
                      color: lapEffect.withinNoise ? muted : null,
                    ),
                  ),
                if (ranked.isNotEmpty &&
                    !(result.segments[ranked.first].time.withinNoise))
                  Text(
                    'most lost in Seg ${ranked.first + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "+0.63", "−0.41", and "0.00" rather than "−0.00" for a change that rounds
/// to nothing.
String _signedChange(double change) {
  final text = change.abs().toStringAsFixed(2);
  if (text == '0.00') return text;
  return '${change > 0 ? '+' : '−'}$text';
}
