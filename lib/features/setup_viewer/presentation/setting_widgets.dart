import 'package:material_ui/material_ui.dart';

import '../../../data/reference/tyre_compound.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/compound_badge.dart';
import '../application/car_setup.dart';

/// Which per-row markers the session needs, decided once per setup rather than
/// per row (§8.10).
///
/// A marker exists to tell rows apart, so it is only drawn where it can: the
/// "adjustable" mark when the session leaves some settings locked and some
/// free (the Race sample — 27 of 170; in Practice and Qualify every row is
/// free and a mark on all of them says nothing), and the "moved" pill when the
/// file records any change at all (5 of 510 settings, all in Qualify). Where
/// neither applies, [markerWidth] is zero and the rows do not reserve a column.
class RowStyle {
  const RowStyle({this.adjustableMarker = false, this.movedMarker = false});

  factory RowStyle.of(CarSetup setup) => RowStyle(
    adjustableMarker: setup.hasLockedSettings,
    movedMarker: setup.movedCount > 0,
  );

  final bool adjustableMarker;
  final bool movedMarker;

  /// Room for a `Δ −74` pill and the adjustable glyph, right-aligned.
  double get markerWidth => switch ((adjustableMarker, movedMarker)) {
    (false, false) => 0,
    (true, false) => 24,
    (false, true) => 52,
    (true, true) => 76,
  };
}

/// `−74` / `+3`, with a true minus sign so it lines up with the digits.
String signedSteps(int steps) => steps < 0 ? '−${-steps}' : '+$steps';

/// A setting's position within the game's list of options, as a slim track.
///
/// The position is the step index over `maxValue` — a *step*, not a physical
/// proportion (§8.10; see `car_setup.dart`): on brake bias the track is 23 of
/// 57 steps of 0.25 points, not "40% of the way to some maximum". It is a
/// second, glanceable reading beside the value the game prints, never the only
/// one, and the tooltip states the step.
///
/// The fill grows from empty when the row first appears (and slides between
/// positions if a value ever changes), on [AppCurves.entrance]; with the
/// platform's reduced-motion setting on it simply sits at its position.
class RangeTrack extends StatelessWidget {
  const RangeTrack({super.key, required this.setting, this.width = 88});

  final SetupSetting setting;

  /// Null to fill the available width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final fraction = setting.rangeFraction;
    if (fraction == null || !setting.hasRange) return SizedBox(width: width);
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AppTooltip(
      message:
          'Step ${setting.value} of ${setting.steps} '
          '(the first option is step 0)',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduceMotion ? fraction : 0, end: fraction),
        duration: reduceMotion ? Duration.zero : AppDurations.slow,
        curve: AppCurves.entrance,
        builder: (context, t, _) => CustomPaint(
          size: Size(width ?? double.infinity, 14),
          painter: _TrackPainter(
            fraction: t,
            track: scheme.surfaceContainerHighest,
            fill: scheme.secondary.withValues(alpha: 0.55),
            thumb: scheme.secondary,
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({
    required this.fraction,
    required this.track,
    required this.fill,
    required this.thumb,
  });

  final double fraction;
  final Color track;
  final Color fill;
  final Color thumb;

  static const _thickness = 4.0;
  static const _thumbRadius = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = _thumbRadius;
    final right = size.width - _thumbRadius;
    final line = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _thickness;

    canvas.drawLine(Offset(left, y), Offset(right, y), line..color = track);
    final x = left + (right - left) * fraction;
    if (x > left) {
      canvas.drawLine(Offset(left, y), Offset(x, y), line..color = fill);
    }
    canvas.drawCircle(Offset(x, y), _thumbRadius, Paint()..color = thumb);
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.fraction != fraction ||
      old.track != track ||
      old.fill != fill ||
      old.thumb != thumb;
}

/// The row's right-hand marks: the moved pill, then the adjustable glyph.
class SettingMarkers extends StatelessWidget {
  const SettingMarkers({super.key, required this.setting, required this.style});

  final SetupSetting setting;
  final RowStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scaled down, never overflowing: the column is sized for a `Δ −74` pill
    // in the real numeral font, and a wider count (or a platform that falls
    // back to another font) should shrink the marks rather than clip them.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (style.movedMarker && setting.isMoved)
            MovedPill(steps: setting.stepsMoved),
          if (style.adjustableMarker && setting.isFree) ...[
            const SizedBox(width: 6),
            AppTooltip(
              message: 'Adjustable in this session',
              child: Icon(
                Icons.tune_rounded,
                size: 15,
                color: scheme.secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `Δ −74` — the game's own change counter for a setting (`numChangesValue`),
/// as the number it is rather than an icon that would have to be hovered to be
/// understood. Only ever drawn for a non-zero count: zero is uninformative
/// (§8.10), so an unmarked row is "no recorded change", not "unchanged".
class MovedPill extends StatelessWidget {
  const MovedPill({super.key, required this.steps, this.compact = false});

  final int steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppTooltip(
      message:
          'The game counted a change of ${signedSteps(steps)} '
          'step${steps.abs() == 1 ? '' : 's'} on this setting',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(8),
          color: scheme.secondary.withValues(alpha: 0.16),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 6,
            vertical: 2,
          ),
          child: Text(
            'Δ ${signedSteps(steps)}',
            style: AppTextStyles.numeral.copyWith(
              fontSize: 11,
              color: scheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A hover-lit surface for a read-only row: there is nothing to press, so the
/// only feedback owed is "this is the row you are reading", a tint that eases
/// in on [AppDurations.fast].
class HoverRow extends StatefulWidget {
  const HoverRow({
    super.key,
    required this.child,
    this.radius = AppRadii.sm,
    this.active = false,
  });

  final Widget child;
  final double radius;

  /// Lit from elsewhere — the gear table row whose line the pointer is on.
  final bool active;

  @override
  State<HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lit = _hovered || widget.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDurations.fast,
        curve: AppCurves.standard,
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(widget.radius),
          color: lit
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
        child: widget.child,
      ),
    );
  }
}

/// One vehicle-level setting: name, value, range and marks on one line.
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.setting, required this.style});

  final SetupSetting setting;
  final RowStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    // N/A rows exist only when the reader asked for them; they read as
    // "nothing here" rather than as data.
    final quiet = setting.isNotApplicable;
    final valueColor = quiet || setting.isFixedByCar ? muted : scheme.onSurface;

    // One composed label for a screen reader — but not by `excludeSemantics`,
    // which would take the tooltips' anchors with the text, and a tooltip
    // without its anchor breaks the Windows accessibility tree once shown
    // (see AppTooltip). The visible text is excluded piece by piece instead,
    // so the row still reads as this label, with each tooltip a node of its
    // own beneath it: the key, the step, the marks.
    return Semantics(
      container: true,
      label: '${setting.label}, ${setting.display}',
      child: Opacity(
        opacity: quiet ? 0.55 : 1,
        child: HoverRow(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The raw key is what the game and community setups call
                      // it, so it is one hover away rather than on the row.
                      AppTooltip(
                        message: setting.key,
                        waitDuration: const Duration(milliseconds: 500),
                        child: ExcludeSemantics(
                          child: Text(
                            setting.label,
                            style: theme.textTheme.bodyMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (setting.caption != null)
                        ExcludeSemantics(
                          child: Text(
                            setting.caption!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: ExcludeSemantics(
                    child: Text(
                      setting.display.isEmpty ? '—' : setting.display,
                      textAlign: TextAlign.right,
                      maxLines: setting.isRaw ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 14,
                        color: valueColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 88,
                  child: setting.hasRange && !quiet
                      ? RangeTrack(setting: setting)
                      : null,
                ),
                if (style.markerWidth > 0) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: style.markerWidth,
                    child: SettingMarkers(setting: setting, style: style),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One per-wheel setting as a car layout, FL FR over RL RR (§8.10).
///
/// The corner names come from the JSON keys themselves (`WM_CAMBER-W_FL`), so
/// labelling them is safe — which telemetry's `value1..value4` was not until
/// §15.5 was closed, and the two are deliberately not conflated: nothing here
/// reads a telemetry channel.
class WheelGroupCard extends StatelessWidget {
  const WheelGroupCard({super.key, required this.group, required this.style});

  final WheelSettingGroup group;
  final RowStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final quiet = group.isNotApplicable;

    Widget cell(WheelCorner corner) => Expanded(
      child: _CornerCell(
        corner: corner,
        setting: group.corners[corner],
        style: style,
      ),
    );

    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: scheme.outlineVariant.withValues(alpha: 0.7),
    );

    return Semantics(
      container: true,
      label: group.label,
      child: Opacity(
        opacity: quiet ? 0.55 : 1,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            color: AppColors.surfaceLow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppTooltip(
                        message: 'WM_${group.id}',
                        waitDuration: const Duration(milliseconds: 500),
                        // The card's own label already names the group.
                        child: ExcludeSemantics(
                          child: Text(
                            group.label,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                    if (style.adjustableMarker &&
                        group.settings.every((s) => s.isFree))
                      AppTooltip(
                        message: 'Adjustable in this session',
                        child: Icon(
                          Icons.tune_rounded,
                          size: 15,
                          color: scheme.secondary,
                        ),
                      ),
                  ],
                ),
                if (group.settings
                        .map((s) => s.caption)
                        .whereType<String>()
                        .toSet()
                    case final captions when captions.length == 1)
                  Text(
                    captions.first,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(WheelCorner.fl),
                      divider,
                      cell(WheelCorner.fr),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(WheelCorner.rl),
                      divider,
                      cell(WheelCorner.rr),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerCell extends StatelessWidget {
  const _CornerCell({
    required this.corner,
    required this.setting,
    required this.style,
  });

  final WheelCorner corner;
  final SetupSetting? setting;
  final RowStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final setting = this.setting;

    final left = corner.isLeft;
    final quiet = setting == null || setting.isNotApplicable;
    final compound = setting != null && setting.key.startsWith('WM_COMPOUND-')
        ? CompoundMark.ofSetup(setting.display)
        : null;
    final valueColor = quiet || setting.isFixedByCar ? muted : scheme.onSurface;

    // Composed like a SettingRow's, and excluded piece by piece for the same
    // reason.
    return Semantics(
      container: true,
      label: '${corner.title}: ${setting?.display ?? 'not present'}',
      child: HoverRow(
        radius: 10,
        child: Padding(
          padding: EdgeInsets.fromLTRB(left ? 0 : 12, 8, left ? 12 : 0, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppTooltip(
                    message: corner.title,
                    // The label above already starts with it.
                    excludeFromSemantics: true,
                    child: ExcludeSemantics(
                      child: Text(
                        corner.code,
                        style: AppTextStyles.numeral.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (setting != null && style.movedMarker && setting.isMoved)
                    MovedPill(steps: setting.stepsMoved, compact: true),
                ],
              ),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Row(
                  children: [
                    // The cell's label already says the compound, and its
                    // own text is beside it, so the badge is a mark only.
                    if (compound != null) ...[
                      CompoundBadge(
                        mark: compound,
                        size: CompoundBadgeSize.small,
                        showTread: false,
                        tooltip: false,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        setting == null || setting.display.isEmpty
                            ? '—'
                            : setting.display,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.numeral.copyWith(
                          fontSize: 15,
                          color: valueColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // A compound's "range" is its place in the garage's list of tyre
              // sets, new and used: no scale to draw.
              if (setting != null &&
                  setting.hasRange &&
                  !quiet &&
                  compound == null) ...[
                const SizedBox(height: 5),
                RangeTrack(setting: setting, width: null),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
