import 'package:flutter/material.dart';

import 'motion_tokens.dart';

/// Desktop/web hover-and-press micro-interaction wrapper (SPEC.md §9.7.6):
/// a subtle scale shift, reused by session-library cards, lap rows, etc.
/// No-ops gracefully where there's no pointer (touch).
class Hoverable extends StatefulWidget {
  const Hoverable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.98 : (_hovered ? 1.01 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale,
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          child: widget.child,
        ),
      ),
    );
  }
}
