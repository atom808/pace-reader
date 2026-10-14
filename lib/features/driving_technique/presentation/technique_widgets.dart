/// Small pieces the technique screen is built from (SPEC.md §8.13.8).
library;

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../domain/lap_technique.dart';

/// How long a number takes to roll to its new value when the lap changes.
const rollDuration = Duration(milliseconds: 250);

/// The colour a measure wears: its channel's identity (§8.13.8). Braking and
/// ABS brake red, throttle and TC throttle green; the G measures, which no
/// channel owns, the steering neutral.
Color measureColor(BuildContext context, TechniqueMeasure measure) {
  final c = ChannelColors.resolve(context);
  return switch (measure) {
    TechniqueMeasure.fullThrottle || TechniqueMeasure.tc => c.throttle,
    TechniqueMeasure.braking ||
    TechniqueMeasure.abs ||
    TechniqueMeasure.trail ||
    TechniqueMeasure.overlap => c.brake,
    TechniqueMeasure.coasting ||
    TechniqueMeasure.gripUsed ||
    TechniqueMeasure.sustainedPeak => c.steering,
  };
}

/// A number that rolls to its new value (§8.13.8 "Type and numbers"):
/// tabular figures keep the column still while it does. Under reduced motion
/// it simply changes.
class RollingNumber extends StatelessWidget {
  const RollingNumber({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.unit,
    this.unitStyle,
    this.signed = false,
  });

  final double? value;
  final String Function(double) format;
  final TextStyle style;
  final String? unit;
  final TextStyle? unitStyle;

  /// Prefix a + to positive values.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) {
      return Text('—', style: AppTextStyles.numeral.merge(style));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: AppMotion.duration(context, rollDuration),
      curve: AppCurves.entrance,
      builder: (context, shown, _) {
        final text = format(shown);
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: signed && shown > 0 ? '+$text' : text,
                style: AppTextStyles.numeral.merge(style),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.numeral.merge(unitStyle),
                ),
            ],
          ),
          maxLines: 1,
        );
      },
    );
  }
}

/// A heading with a quieter line beside it.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.caption, this.trailing});

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (caption != null)
                  Text(
                    caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// "goes with pace": the three measures that moved with lap time in every
/// race measured say so (§8.13.7).
class PaceTag extends StatelessWidget {
  const PaceTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppTooltip(
      message:
          'One of the three measures that went with lap time in every race '
          'measured. The others describe the lap, not its speed.',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(8),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.07),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: Text(
            'goes with pace',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A measure's identity dot. Overlap, both pedals at once, is half throttle
/// and half brake.
class MeasureGlyph extends StatelessWidget {
  const MeasureGlyph({super.key, required this.measure, this.size = 9});

  final TechniqueMeasure measure;
  final double size;

  @override
  Widget build(BuildContext context) {
    final channels = ChannelColors.resolve(context);
    final split = measure == TechniqueMeasure.overlap;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: split ? null : measureColor(context, measure),
          gradient: split
              ? LinearGradient(
                  colors: [channels.throttle, channels.brake],
                  stops: const [0.5, 0.5],
                )
              : null,
        ),
      ),
    );
  }
}

/// Anchors a glass popover to [trigger] (§9.7.3: popovers are glass).
///
/// An [OverlayPortal] like the session switcher's, for its reasons: the
/// popover stays inside the tree, so the theme and the providers reach it,
/// and it arrives on [AppCurves.entrance] — a fade and a settle from 96 % —
/// rather than on a stock menu's curve. A tap outside or Escape closes it.
class GlassPopoverAnchor extends HookWidget {
  const GlassPopoverAnchor({
    super.key,
    required this.trigger,
    required this.popover,
    this.width = 320,
    this.alignRight = true,
  });

  /// The control, given a callback that opens or closes the popover.
  final Widget Function(BuildContext context, VoidCallback toggle) trigger;

  /// The popover's content, given a callback that closes it.
  final Widget Function(BuildContext context, VoidCallback close) popover;
  final double width;

  /// Whether the popover's right edge lines up with the trigger's.
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final portal = useOverlayPortalController();
    final link = useMemoized(LayerLink.new);
    final group = useMemoized(Object.new);
    final controller = useAnimationController(
      duration: AppMotion.duration(context, AppDurations.medium),
      reverseDuration: AppMotion.duration(context, AppDurations.fast),
    );
    final curved = useMemoized(
      () => CurvedAnimation(
        parent: controller,
        curve: AppCurves.entrance,
        reverseCurve: AppCurves.standard,
      ),
      [controller],
    );
    useEffect(() => curved.dispose, [curved]);

    Future<void> hide() async {
      if (!portal.isShowing) return;
      await controller.reverse();
      if (context.mounted && controller.status == AnimationStatus.dismissed) {
        portal.hide();
      }
    }

    void toggle() {
      if (portal.isShowing && controller.status != AnimationStatus.reverse) {
        hide();
      } else {
        portal.show();
        controller.forward();
      }
    }

    final anchor = alignRight ? Alignment.topRight : Alignment.topLeft;
    final body = TapRegion(
      groupId: group,
      onTapOutside: (_) => hide(),
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (_) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            targetAnchor: alignRight
                ? Alignment.bottomRight
                : Alignment.bottomLeft,
            followerAnchor: anchor,
            offset: Offset(alignRight ? 8 : -8, 6),
            child: TapRegion(
              groupId: group,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): hide,
                },
                child: FadeTransition(
                  opacity: curved,
                  child: ScaleTransition(
                    alignment: anchor,
                    scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                    child: SizedBox(
                      width: width,
                      child: GlassSurface(
                        radius: AppRadii.lg,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: popover(context, hide),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: link,
          child: trigger(context, toggle),
        ),
      ),
    );
    // A node of the portal's own, for the reason AppTooltip has one: the
    // cards this sits in hold tooltips too, and an anchor sharing their node
    // is dropped — the popover, once open, then breaks the Windows
    // accessibility tree.
    return Semantics(container: true, child: body);
  }
}

/// An ⓘ that opens the definition behind a number, in plain words
/// (§8.13.7).
class InfoPopoverButton extends StatelessWidget {
  const InfoPopoverButton({
    super.key,
    required this.title,
    required this.paragraphs,
    this.footer,
    this.width = 320,
  });

  final String title;
  final List<String> paragraphs;

  /// Quieter lines under the paragraphs.
  final List<String>? footer;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return GlassPopoverAnchor(
      width: width,
      trigger: (context, toggle) => IconButton(
        tooltip: 'What is this?',
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        icon: Icon(Icons.info_outline, color: muted),
        onPressed: toggle,
      ),
      popover: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final p in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(p, style: theme.textTheme.bodySmall),
            ),
          for (final line in footer ?? const <String>[])
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// A sentence in place of a chart that has nothing to draw (§8.13.8:
/// "errors and absences are sentences").
class AbsenceNote extends StatelessWidget {
  const AbsenceNote(this.text, {super.key, this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
