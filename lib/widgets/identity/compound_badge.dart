import 'dart:math' as math;

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

/// A car's four corners as few badges as say it: one when all four match,
/// F and R when each axle does, otherwise one per corner.
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

  /// Whether a single badge (all four the same) is followed by its name.
  final bool showName;
  final bool showTread;

  /// [CompoundBadge.tooltip].
  final bool tooltip;

  @override
  Widget build(BuildContext context) {
    final groups = axleGroups(marks);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final micro = AppTextStyles.numeral.copyWith(
      fontSize: size.fontSize + 1.5,
      color: muted,
      fontWeight: FontWeight.w600,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, (axle, mark)) in groups.indexed) ...[
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
        if (showName && groups.length == 1) ...[
          SizedBox(width: size.diameter * 0.35),
          ExcludeSemantics(child: Text(groups.single.$2.label)),
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

/// What a screen reader hears for [mark].
/// "Front" for F, "Front left" for FL.
String? _where(String? axle) => switch (axle) {
  null => null,
  'F' => 'Front',
  'R' => 'Rear',
  _ => Corner.values.where((c) => c.short == axle).firstOrNull?.label,
};

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
