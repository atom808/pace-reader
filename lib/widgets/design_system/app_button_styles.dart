import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';

/// Centralized [ButtonStyle] factory (SPEC.md §9.7.6) so every button
/// variant shares one squircle shape + brand color mapping rather than each
/// call site picking its own.
abstract final class AppButtonStyles {
  /// The brand gradient in a button, matching the theme's own
  /// `filledButtonTheme` — the primary action looks the same whichever of
  /// the two a call site reaches for.
  static ButtonStyle primary(BuildContext context) {
    return ElevatedButton.styleFrom(
      shape: AppRadii.squircle(AppRadii.md),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ).copyWith(
      backgroundBuilder: (context, states, child) => DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(AppRadii.md),
          gradient: states.contains(WidgetState.disabled)
              ? AppGradients.brandMuted
              : AppGradients.brand,
        ),
        child: child,
      ),
    );
  }

  static ButtonStyle secondary(BuildContext context) {
    return OutlinedButton.styleFrom(
      shape: AppRadii.squircle(AppRadii.md),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );
  }
}
