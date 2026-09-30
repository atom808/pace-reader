import 'package:material_ui/material_ui.dart';

import 'color_tokens.dart';
import 'gradient_border.dart';
import 'motion_tokens.dart';
import 'radius_tokens.dart';

/// Desktop/web hover-and-press micro-interaction wrapper (SPEC.md §9.7.6):
/// a subtle scale shift, reused by session-library cards, lap rows, nav slots,
/// etc. No-ops gracefully where there's no pointer (touch).
///
/// It is also the app's one tappable primitive, so it carries everything a
/// tappable has to (§10, "keyboard navigation on desktop/web"):
///
/// - **A pointer that says so.** [SystemMouseCursors.click] when [onTap] is set
///   — a card that does something should not look like a card that doesn't.
/// - **A place in the tab order**, and Enter / Space to activate it, through
///   Flutter's own [ActivateIntent] rather than a hand-rolled key handler, so
///   the platform's shortcut table decides which keys those are (Space
///   activates on every desktop platform, Enter on all of them too).
/// - **A visible focus ring, for the keyboard only.** §9.7.2: "a focused field
///   is the edge lighting up" — so the ring is [GradientSquircleBorder] in
///   [AppGradients.hairlineStrong], the same light every other emphasised edge
///   in the app is drawn with. It shows for *focus highlight*, which is the
///   framework's word for "focus that arrived by keyboard": a mouse click never
///   requests focus here, so clicking a card doesn't leave a ring behind it.
/// - **Button semantics**, so a screen reader announces a card that navigates
///   as a button rather than as a group of text.
///
/// Reduced motion (§9.7.4) collapses the scale and the ring's fade to zero
/// duration: the hover/press/focus *state* still changes, it just doesn't
/// travel.
class Hoverable extends StatefulWidget {
  const Hoverable({
    super.key,
    required this.child,
    this.onTap,
    this.radius = AppRadii.lg,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  });

  final Widget child;

  /// Null makes this inert: no click cursor, no focus stop, no activation, and
  /// no button semantics.
  final VoidCallback? onTap;

  /// The corner radius of the child's squircle, so the focus ring can follow
  /// it. Defaults to [AppRadii.lg], which is what [SquircleCard] draws; pass
  /// the child's own token when it isn't.
  final double radius;

  /// Read out by assistive technology in place of (or, for a child with its
  /// own text, alongside) whatever the child says — for icon-only controls
  /// such as the nav rail's slots, where the child says nothing at all.
  final String? semanticLabel;

  final bool autofocus;
  final FocusNode? focusNode;

  /// How far outside the child the focus ring sits.
  ///
  /// Offset rather than flush because the thing it rings usually has an edge of
  /// its own — a card's hairline, the selected nav slot's lit border — in the
  /// very gradient the ring is drawn with. Laid over that edge the ring is only
  /// a slightly stronger version of it, and the focused card cannot be told
  /// from the selected one; a gap makes it a second object around the first.
  static const ringGap = 3.0;

  /// Heavier than the 1.25 px hairline of the edge it surrounds, for the same
  /// reason.
  static const ringWidth = 2.0;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _keyboardFocused = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : (_hovered ? 1.01 : 1.0);
    final motion = AppMotion.duration(context, AppDurations.fast);

    return Semantics(
      button: _enabled,
      enabled: _enabled ? true : null,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: _enabled,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        mouseCursor:
            _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (show) {
          if (_keyboardFocused != show) setState(() => _keyboardFocused = show);
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            // Only when there is something to press: a tap-down handler on
            // its own is enough for a `GestureDetector` to announce a tap
            // action to assistive technology, which would make an inert card
            // claim to be pressable.
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapCancel:
                _enabled ? () => setState(() => _pressed = false) : null,
            onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
            child: AnimatedScale(
              scale: scale,
              duration: motion,
              curve: AppCurves.standard,
              // Passthrough so the child is laid out under exactly the
              // constraints it was given before the ring existed: a loose
              // fit would let a child that fills its parent shrink to its
              // content, and every card in the app would change size.
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.none,
                children: [
                  widget.child,
                  Positioned(
                    left: -Hoverable.ringGap,
                    top: -Hoverable.ringGap,
                    right: -Hoverable.ringGap,
                    bottom: -Hoverable.ringGap,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        key: const ValueKey('hoverable-focus-ring'),
                        opacity: _keyboardFocused ? 1 : 0,
                        duration: motion,
                        curve: AppCurves.standard,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: GradientSquircleBorder(
                              radius: widget.radius + Hoverable.ringGap,
                              gradient: AppGradients.hairlineStrong,
                              width: Hoverable.ringWidth,
                            ),
                          ),
                        ),
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
}
