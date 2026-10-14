import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../data/models/corner.dart';
import '../../data/reference/tyre_compound.dart';
import '../design_system/design_system.dart';

/// How much room a [CompoundBadge] has.
enum CompoundBadgeSize {
  /// 16 px: inside a chip or a line of text.
  small(16, 7.5),

  /// 20 px: beside a value in a setup row or a corner cell.
  regular(20, 9.5),

  /// 32 px: beside a headline figure.
  large(32, 15);

  const CompoundBadgeSize(this.diameter, this.fontSize);

  final double diameter;
  final double fontSize;
}

/// A tyre compound as Le Mans Ultimate marks it: a tyre seen side-on, its
/// sidewall band and letter in the compound's colour.
///
/// - **Named** (Soft, Medium, Hard, Wet): the game's colour, from the setup
///   or from the file's index read through the game's order.
/// - **Used set** ("70% Medium" in the setup): the same badge, with the
///   tread left beside it. The band stays whole: a part ring would read as a
///   different compound.
/// - **Unnamed index**: a dashed neutral band round the file's number, so it
///   never passes for a Soft's white.
///
/// The tooltip says where the name came from. A change of compound rolls
/// the old tyre out and the new one in, a quarter turn each, so a tyre
/// change shows where the reader is looking.
class CompoundBadge extends StatelessWidget {
  const CompoundBadge({
    super.key,
    required this.mark,
    this.size = CompoundBadgeSize.regular,
    this.showTread = true,
    this.where,
    this.tooltip = true,
  });

  final CompoundMark mark;
  final CompoundBadgeSize size;

  /// The axle or corner it stands for, read out first: "Front", "Rear left".
  final String? where;

  /// Whether a used set's tread left shows beside it.
  final bool showTread;

  /// Whether it explains itself on hover. Off inside something whose own
  /// tooltip already does, such as a Compare chip: two tooltips on one spot
  /// compete for it.
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final tread = showTread ? mark.treadLeft : null;
    final badge = Semantics(
      label: where == null
          ? compoundSemantics(mark)
          : '$where: ${compoundSemantics(mark)}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Roll(
              identity: (mark.kind, mark.name, mark.index),
              child: _Tyre(mark: mark, size: size),
            ),
            if (tread != null) ...[
              SizedBox(width: size.diameter * 0.25),
              Text(
                '${_trim(tread)} %',
                style: AppTextStyles.numeral.copyWith(
                  fontSize: size.fontSize + 2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return tooltip
        ? AppTooltip(message: compoundTooltip(mark), child: badge)
        : badge;
  }
}

/// A car's four corners (FL, FR, RL, RR) the way the game marks them: one
/// badge when all four match, otherwise four dots in the wheels' places,
/// each in its compound's colour, whatever the split (front and rear, left
/// and right, or one wheel apart).
///
/// The dots carry no letters, as in the game, so a name beside them
/// ([showName]) spells the set out: "F Soft, R Medium". A change between one
/// compound and a mixed set cross-fades; between two mixed sets each dot
/// fades to its new colour.
///
/// A list that is not four corners and does not match falls back to a badge
/// per axle or corner, each with its micro-label.
class CompoundBadges extends StatelessWidget {
  const CompoundBadges({
    super.key,
    required this.marks,
    this.size = CompoundBadgeSize.small,
    this.showName = false,
    this.showTread = false,
    this.tooltip = true,
  });

  /// FL, FR, RL, RR.
  final List<CompoundMark> marks;
  final CompoundBadgeSize size;

  /// Whether the badge is followed by the compound's name, or by the mixed
  /// set's: "Medium", "F Soft, R Medium".
  final bool showName;

  /// Whether a single badge shows a used set's tread. The dots never do.
  final bool showTread;

  /// [CompoundBadge.tooltip].
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    if (marks.isEmpty) return const SizedBox.shrink();
    final first = marks.first;
    final uniform = marks.every((m) => m == first);
    if (!uniform && marks.length != Corner.values.length) {
      return _Grouped(
        marks: marks,
        size: size,
        showTread: showTread,
        tooltip: tooltip,
      );
    }
    final badge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Swap(
          mixed: !uniform,
          child: uniform
              ? CompoundBadge(
                  mark: first,
                  size: size,
                  showTread: showTread,
                  tooltip: false,
                )
              : _MixedTyres(marks: marks, size: size),
        ),
        if (showName) ...[
          SizedBox(width: size.diameter * 0.35),
          Flexible(
            child: ExcludeSemantics(
              child: Text(
                uniform ? first.label : describeCompounds(marks),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
    // Outside the cross-fade, so the anchor never sits under a fade to zero.
    return tooltip
        ? AppTooltip(message: compoundsTooltip(marks), child: badge)
        : badge;
  }
}

/// [CompoundBadges] for a list that is not four corners: a badge per group,
/// each after its axle or corner.
class _Grouped extends StatelessWidget {
  const _Grouped({
    required this.marks,
    required this.size,
    required this.showTread,
    required this.tooltip,
  });

  final List<CompoundMark> marks;
  final CompoundBadgeSize size;
  final bool showTread;
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final micro = AppTextStyles.numeral.copyWith(
      fontSize: size.fontSize + 1.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (axle, mark)) in axleGroups(marks).indexed) ...[
          if (i > 0) SizedBox(width: size.diameter * 0.4),
          if (axle != null) ...[
            ExcludeSemantics(child: Text(axle, style: micro)),
            SizedBox(width: size.diameter * 0.2),
          ],
          CompoundBadge(
            mark: mark,
            size: size,
            showTread: showTread,
            where: _where(axle),
            tooltip: tooltip,
          ),
        ],
      ],
    );
  }
}

/// What a [CompoundBadge]'s tooltip says: the compound, and where its name
/// came from.
String compoundTooltip(CompoundMark mark) {
  final used = mark.treadLeft == null
      ? ''
      : '\nA used set, with ${_trim(mark.treadLeft!)} % of its tread left.';
  final reason = mark.reason == null ? '' : '\n${mark.reason}';
  return switch (mark) {
    CompoundMark(naming: CompoundNaming.unnamed) =>
      'Compound ${mark.index}, as the file numbers it.$reason',
    CompoundMark(kind: null) =>
      '"${mark.name}", as the setup names it. Pace Reader has no colour for '
          'this compound yet.$used',
    CompoundMark(index: null) =>
      '${mark.label}, as the setup names it: the compound this car left the '
          'garage on.$used',
    _ => '${mark.label}: the file\'s compound ${mark.index}.$reason$used',
  };
}

/// What a [CompoundBadges]' tooltip says: one badge's own, or how a mixed
/// set's dots read and each group's compound.
String compoundsTooltip(List<CompoundMark> marks) {
  final groups = axleGroups(marks);
  if (groups.length == 1) return compoundTooltip(groups.single.$2);
  return [
    'Mixed tyres, marked as the game marks them: a dot per wheel, seen from '
        'above with the nose up, so the fronts are on top.',
    for (final (axle, mark) in groups)
      '${_where(axle) ?? axle}: ${compoundTooltip(mark)}',
  ].join('\n\n');
}

/// What a screen reader hears for a car's four corners: "Soft tyres", or
/// "Mixed tyres: front Soft, rear Medium".
String compoundsSemantics(List<CompoundMark> marks) {
  final groups = axleGroups(marks);
  if (groups.length == 1) return compoundSemantics(groups.single.$2);
  final parts = [
    for (final (axle, mark) in groups)
      [
        ?_where(axle)?.toLowerCase(),
        mark.isNamed ? mark.label : 'compound ${mark.index}, not named',
      ].join(' '),
  ];
  return 'Mixed tyres: ${parts.join(', ')}';
}

/// "Front" for F, "Front left" for FL.
String? _where(String? axle) => switch (axle) {
  null => null,
  'F' => 'Front',
  'R' => 'Rear',
  _ => Corner.values.where((c) => c.short == axle).firstOrNull?.label,
};

/// What a screen reader hears for [mark].
String compoundSemantics(CompoundMark mark) => switch (mark) {
  CompoundMark(naming: CompoundNaming.unnamed) =>
    'Tyre compound ${mark.index}, not named',
  _ when mark.treadLeft != null =>
    '${mark.label} tyres, used, ${_trim(mark.treadLeft!)} percent tread',
  _ => '${mark.label} tyres',
};

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// The compound's colour; null where there is none to show.
Color? compoundColor(CompoundKind? kind) => switch (kind) {
  CompoundKind.soft => CompoundColors.soft,
  CompoundKind.medium => CompoundColors.medium,
  CompoundKind.hard => CompoundColors.hard,
  CompoundKind.wet => CompoundColors.wet,
  null => null,
};

class _Tyre extends StatelessWidget {
  const _Tyre({required this.mark, required this.size});

  final CompoundMark mark;
  final CompoundBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final colour = compoundColor(mark.kind);
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    final letter =
        mark.kind?.letter ??
        (mark.name?.isNotEmpty ?? false
            ? mark.name!.characters.first.toUpperCase()
            : '${mark.index ?? '?'}');
    return CustomPaint(
      painter: _TyrePainter(
        band: colour ?? AppColors.outline,
        dashed: colour == null,
      ),
      child: SizedBox.square(
        dimension: size.diameter,
        child: Center(
          child: Text(
            letter,
            maxLines: 1,
            softWrap: false,
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToFirstAscent: false,
              applyHeightToLastDescent: false,
            ),
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontSize: size.fontSize,
              fontWeight: FontWeight.w700,
              height: 1,
              color: colour ?? neutral,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rubber disc, shoulder hairline, and the sidewall band at 70–88 % of the
/// radius: whole for a compound, dashed for an index nothing names.
class _TyrePainter extends CustomPainter {
  _TyrePainter({required this.band, required this.dashed});

  final Color band;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(centre, r, Paint()..color = CompoundColors.rubber);
    canvas.drawCircle(
      centre,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = CompoundColors.shoulder,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18
      ..color = band;
    final ring = Rect.fromCircle(center: centre, radius: r * 0.79);
    if (!dashed) {
      canvas.drawOval(ring, paint);
      return;
    }
    const dashes = 8;
    const step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(ring, i * step + step * 0.2, step * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_TyrePainter old) =>
      old.band != band || old.dashed != dashed;
}

/// Swaps its child with a quarter-turn roll and a fade when [identity]
/// changes: the old tyre rolls on out, the new one rolls in. Instant under
/// reduced motion.
class _Roll extends StatelessWidget {
  const _Roll({required this.identity, required this.child});

  final Object identity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(identity);
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDurations.slow),
      switchInCurve: AppCurves.standard,
      switchOutCurve: AppCurves.standard,
      transitionBuilder: (child, animation) {
        // Both turn the same way, clockwise, as a wheel rolls: the new tyre
        // from a quarter turn back, the old one on to a quarter turn ahead
        // (its animation runs from 1 to 0).
        final incoming = child.key == current;
        return FadeTransition(
          opacity: animation,
          child: RotationTransition(
            turns: Tween<double>(
              begin: incoming ? -0.25 : 0.25,
              end: 0,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: current, child: child),
    );
  }
}

/// Cross-fades between a single badge and a mixed set's dots when [mixed]
/// flips; within either, the child animates its own changes (the roll, the
/// dots' colours). Instant under reduced motion.
class _Swap extends StatelessWidget {
  const _Swap({required this.mixed, required this.child});

  final bool mixed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDurations.medium),
      switchInCurve: AppCurves.standard,
      switchOutCurve: AppCurves.standard,
      child: KeyedSubtree(key: ValueKey(mixed), child: child),
    );
  }
}

/// One wheel's dot: its fill, and the ring of a corner with no colour.
typedef _Dot = ({Color fill, Color ring});

/// [mark]'s dot: the compound's colour, or a hollow neutral ring where the
/// file cannot name it or the game has no colour for its name. Never white,
/// which is the Soft's. The unused half of each is its own colour made
/// transparent, so a change fades rather than passing through black.
_Dot _dotOf(CompoundMark mark) {
  final colour = compoundColor(mark.kind);
  return colour == null
      ? (fill: AppColors.outline.withValues(alpha: 0), ring: AppColors.outline)
      : (fill: colour, ring: colour.withValues(alpha: 0));
}

/// A mixed set as the game marks it (`TyreMixedCompoundIndicator`): four
/// dots in the wheels' places, the fronts on top, each in its corner's
/// compound colour.
class _MixedTyres extends StatelessWidget {
  const _MixedTyres({required this.marks, required this.size});

  /// FL, FR, RL, RR.
  final List<CompoundMark> marks;
  final CompoundBadgeSize size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: compoundsSemantics(marks),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<List<_Dot>>(
          tween: _DotsTween(end: [for (final m in marks) _dotOf(m)]),
          duration: AppMotion.duration(context, AppDurations.medium),
          curve: AppCurves.standard,
          builder: (context, dots, _) => CustomPaint(
            painter: _DotsPainter(dots),
            child: SizedBox.square(dimension: size.diameter),
          ),
        ),
      ),
    );
  }
}

class _DotsTween extends Tween<List<_Dot>> {
  _DotsTween({super.end});

  @override
  List<_Dot> lerp(double t) => [
    for (var i = 0; i < end!.length; i++)
      i < begin!.length
          ? (
              fill: Color.lerp(begin![i].fill, end![i].fill, t)!,
              ring: Color.lerp(begin![i].ring, end![i].ring, t)!,
            )
          : end![i],
  ];
}

/// The game's icon on its 45-unit grid: dots of radius 9 centred 9 units in
/// from each edge, FL, FR, RL, RR.
class _DotsPainter extends CustomPainter {
  _DotsPainter(this.dots);

  final List<_Dot> dots;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final unit = side / 45;
    final origin = Offset((size.width - side) / 2, (size.height - side) / 2);
    final r = 9 * unit;
    final near = 9 * unit;
    final far = 36 * unit;
    final centres = [
      Offset(near, near),
      Offset(far, near),
      Offset(near, far),
      Offset(far, far),
    ];
    for (final (i, dot) in dots.take(centres.length).indexed) {
      final centre = origin + centres[i];
      if (dot.fill.a > 0) {
        canvas.drawCircle(centre, r, Paint()..color = dot.fill);
      }
      if (dot.ring.a > 0) {
        canvas.drawCircle(
          centre,
          r - 0.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = dot.ring,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => !listEquals(old.dots, dots);
}
