import 'package:flutter/material.dart';

import 'radius_tokens.dart';

/// Base card applying the squircle shape + elevation + padding tokens
/// (SPEC.md §9.7.6), so every card in the app shares one shape source
/// instead of each screen picking its own radius.
class SquircleCard extends StatelessWidget {
  const SquircleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppRadii.lg,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color ?? scheme.surfaceContainerHigh,
      shape: AppRadii.squircle(radius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}
