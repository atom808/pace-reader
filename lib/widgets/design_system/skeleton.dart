import 'package:flutter/material.dart';

import 'radius_tokens.dart';

/// Squircle-shaped shimmer loading placeholder (SPEC.md §9.7.4). Built
/// in-house rather than the `shimmer` package, since it needs to clip to
/// our squircle shape tokens specifically, not a generic box. Respects
/// the platform's reduced-motion setting.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = AppRadii.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.onSurface.withValues(alpha: 0.06);

    return ClipPath(
      clipper: ShapeBorderClipper(shape: AppRadii.squircle(widget.radius)),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: base,
                gradient: LinearGradient(
                  begin: Alignment(-1 - _controller.value * 2, 0),
                  end: Alignment(1 - _controller.value * 2, 0),
                  colors: [base, highlight, base],
                  stops: const [0.3, 0.5, 0.7],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
