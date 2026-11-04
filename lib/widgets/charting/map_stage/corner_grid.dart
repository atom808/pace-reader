/// The four corners laid out like the car, nose up (map stage proposal
/// §6.1): FL FR over RL RR. Shared by every per-corner dock tab.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../design_system/design_system.dart';

/// [cell] for each corner, in the car's layout where there is room for two
/// columns, else one column in the same reading order. Given a height, the
/// corners share it; given none, each takes its own.
///
/// The [lit] corner sits on a faint wash — the one the map is coloured by,
/// or the one the pointer last rested on — and moving the pointer into a
/// corner reports it through [onHover], so a tab can follow it.
class CornerGrid extends StatelessWidget {
  const CornerGrid({
    super.key,
    required this.cell,
    this.lit,
    this.onHover,
    this.gap = 10,
    this.twoColumnsFrom = twoColumnsWidth,
  });

  final Widget Function(BuildContext context, Corner corner) cell;
  final Corner? lit;
  final ValueChanged<Corner>? onHover;
  final double gap;

  /// The narrowest width that still lays the corners out side by side.
  final double twoColumnsFrom;

  /// [twoColumnsFrom] unless a grid says otherwise.
  static const twoColumnsWidth = 380.0;

  static const _axles = [
    [Corner.frontLeft, Corner.frontRight],
    [Corner.rearLeft, Corner.rearRight],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = AppMotion.duration(context, AppDurations.medium);

    Widget corner(Corner c) => MouseRegion(
      onEnter: onHover == null ? null : (_) => onHover!(c),
      child: AnimatedContainer(
        duration: duration,
        curve: AppCurves.standard,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
        decoration: ShapeDecoration(
          color: c == lit
              ? theme.colorScheme.primary.withValues(alpha: 0.07)
              : theme.colorScheme.primary.withValues(alpha: 0),
          shape: AppRadii.squircle(AppRadii.md),
        ),
        child: cell(context, c),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final fill = constraints.hasBoundedHeight;
        Widget share(Widget child) => fill ? Expanded(child: child) : child;
        if (constraints.maxWidth < twoColumnsFrom) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in Corner.values) ...[
                share(corner(c)),
                if (c != Corner.values.last) SizedBox(height: gap),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final axle in _axles) ...[
              share(
                Row(
                  crossAxisAlignment: fill
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.start,
                  children: [
                    Expanded(child: corner(axle[0])),
                    SizedBox(width: gap),
                    Expanded(child: corner(axle[1])),
                  ],
                ),
              ),
              if (axle.first.isFront) SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}
