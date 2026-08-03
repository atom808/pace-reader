import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'radius_tokens.dart';
import 'typography_tokens.dart';

/// Builds the app's single dark theme (SPEC.md §9.7 — dark by default is a
/// deliberate genre convention for a telemetry tool used in dim sim-rig
/// environments, matching both reference apps studied in §7).
abstract final class AppTheme {
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    );

    final squircleMd = AppRadii.squircle(AppRadii.md);
    final squircleLg = AppRadii.squircle(AppRadii.lg);
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: colorScheme.surface,
      extensions: const [ChannelColors.dark],
      cardTheme: CardThemeData(
        shape: squircleLg,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        filled: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      chipTheme: ChipThemeData(shape: AppRadii.squircle(AppRadii.sm)),
    );
  }
}
