import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'hooks.dart';
import 'motion_tokens.dart';

/// One item of a staggered entrance (SPEC.md §9.7.4, §9.7.6): fades in while
/// rising [rise] logical pixels into place, starting `index * stagger` after
/// it mounts, on [AppCurves.entrance].
///
/// For a row or grid of peers that arrive together — the Session Overview's
/// stat tiles — where everything fading in at the same instant reads as a
/// flash and each tile arriving on its own beat reads as a sequence. Give each
/// child its position in the group as [index]; the delay is built into the
/// animation rather than scheduled ([useStaggeredFadeIn] has the reason), so
/// the finished layout is exactly the one with no wrapper at all.
///
/// The rise is a *paint* offset: layout never sees it, so a `Wrap` of these
/// does not reflow as they arrive and nothing the user might click moves under
/// the pointer between one frame and the next.
///
/// Honours reduced motion (§10): the child is simply there.
///
/// Once the item has landed the wrapper steps out of the tree and the child is
/// painted bare. Flutter's opacity render objects are repaint boundaries for
/// any alpha above zero — even a fully opaque one — so a finished
/// [FadeTransition] is not free: it leaves an offscreen layer behind, and the
/// Session Overview golden measured it at one pixel, one blue step, different
/// from the screen with no wrapper. Dropping it is what makes "the final frame
/// is exactly what the screen had before" true by construction rather than by
/// tolerance. A [GlobalKey] carries the child's state across that swap.
///
/// The item is in the semantics tree from its first frame, faded or not: the
/// fade is motion, not absence. Excluded while its opacity is zero — up to
/// `index * stagger`, over half a second deep in a page — a tooltip opened on
/// it in that time had no anchor in the tree, which breaks the Windows
/// accessibility bridge (see AppTooltip).
class StaggeredEntrance extends HookWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.stagger = AppDurations.stagger,
    this.duration = AppDurations.slow,
    this.rise = 8,
  });

  /// This item's position among its peers, from 0.
  final int index;
  final Widget child;

  /// Delay per index step.
  final Duration stagger;

  /// How long one item takes to arrive, once it has started.
  final Duration duration;

  /// Logical pixels the item travels upward while fading in.
  final double rise;

  @override
  Widget build(BuildContext context) {
    final progress = useStaggeredFadeIn(
      index: index,
      stagger: stagger,
      duration: duration,
    );
    final childKey = useMemoized(GlobalKey.new);
    return AnimatedBuilder(
      animation: progress,
      child: KeyedSubtree(key: childKey, child: child),
      builder: (context, child) {
        final t = progress.value;
        if (t >= 1) return child!;
        return FadeTransition(
          opacity: progress,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * rise),
            child: child,
          ),
        );
      },
    );
  }
}
