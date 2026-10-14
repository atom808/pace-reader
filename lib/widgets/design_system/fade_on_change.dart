import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'motion_tokens.dart';

/// Cross-fades [child] whenever [value] changes: the [AnimatedSwitcher] to
/// reach for when what is shown can come back.
///
/// An [AnimatedSwitcher] whose child is keyed by the value itself breaks when
/// a value returns while it is still fading out. The switcher only drops the
/// *incoming* key from its fading-out children, so A → B → A → B inside one
/// duration leaves two copies of A in its stack, and the framework asserts
/// "Duplicate keys found" — stepping laps ← → ← → with key repeat, or
/// hovering two corners back and forth. Each change here gets a fresh
/// generation number as its key instead, so no two children ever share one.
///
/// [duration] is used as given: pass it through [AppMotion.duration] so
/// reduced motion swaps in place. [switchInCurve] and [transitionBuilder] are
/// the switcher's own.
class FadeOnChange extends HookWidget {
  const FadeOnChange({
    super.key,
    required this.value,
    required this.duration,
    required this.child,
    this.switchInCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
  });

  /// What [child] shows: a change cross-fades, the same value rebuilds in
  /// place.
  final Object? value;
  final Duration duration;
  final Widget child;
  final Curve switchInCurve;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  @override
  Widget build(BuildContext context) {
    final shown = useRef<Object?>(value);
    final generation = useRef(0);
    if (shown.value != value) {
      shown.value = value;
      generation.value++;
    }
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      transitionBuilder: transitionBuilder,
      child: KeyedSubtree(key: ValueKey(generation.value), child: child),
    );
  }
}
