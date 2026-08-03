import 'package:flutter/material.dart';

import 'radius_tokens.dart';

/// Centralized [ButtonStyle] factory (SPEC.md §9.7.6) so every button
/// variant shares one squircle shape + brand color mapping rather than each
/// call site picking its own.
abstract final class AppButtonStyles {
  static ButtonStyle primary(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ElevatedButton.styleFrom(
      shape: AppRadii.squircle(AppRadii.md),
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );
  }

  static ButtonStyle secondary(BuildContext context) {
    return OutlinedButton.styleFrom(
      shape: AppRadii.squircle(AppRadii.md),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );
  }
}
