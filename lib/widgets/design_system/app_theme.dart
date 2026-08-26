import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'gradient_border.dart';
import 'radius_tokens.dart';
import 'squircle_input_border.dart';
import 'typography_tokens.dart';

/// Builds the app's single dark theme (SPEC.md §9.7 — dark by default is a
/// deliberate genre convention for a telemetry tool used in dim sim-rig
/// environments, matching both reference apps studied in §7).
abstract final class AppTheme {
  static ThemeData dark() {
    final colorScheme = _scheme();

    final squircleMd = AppRadii.squircle(AppRadii.md);
    final buttonPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      fontFamily: AppFonts.ui,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      dividerColor: colorScheme.outlineVariant,
      extensions: const [ChannelColors.dark],
      appBarTheme: AppBarTheme(
        // The bar is part of the page rather than a slab on top of it:
        // §9.7.3's glass chrome does the layering, and an M3 surface tint
        // that lightens on scroll would fight the darker base the whole
        // surface ramp is built on.
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        shape: const GradientSquircleBorder(radius: AppRadii.lg),
        color: AppColors.surfaceHigh,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      // §9.7.2 names inputs alongside buttons and cards as squircle-shaped;
      // [SquircleInputBorder] is what finally makes that true of them. Both
      // states are the same gradient at different strengths, so focus reads
      // as the edge lighting up rather than as a different border.
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMid,
        border: SquircleInputBorder(),
        enabledBorder: SquircleInputBorder(),
        focusedBorder: SquircleInputBorder(
          borderSide: BorderSide(width: 1.6),
          gradient: AppGradients.hairlineStrong,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: squircleMd,
          padding: buttonPadding,
          // Transparent, with the fill handed to [backgroundBuilder], is the
          // supported way to put a gradient behind a Material button —
          // the builder's child is the button's ink and label, so a press
          // still ripples over the gradient rather than replacing it.
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
        ).copyWith(backgroundBuilder: _gradientFill(AppRadii.md)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: squircleMd, padding: buttonPadding),
      ),
      // A chip is too small for a gradient edge to resolve into anything but
      // noise, so it takes the flat token shape and a solid hairline — the
      // one place the gradient border is deliberately not used.
      chipTheme: ChipThemeData(
        shape: AppRadii.squircle(AppRadii.sm),
        backgroundColor: AppColors.surfaceMid,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.secondary,
        linearTrackColor: AppColors.surfaceMid,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          shape: const GradientSquircleBorder(radius: AppRadii.sm, width: 1),
          color: AppColors.surfaceHighest,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: TextStyle(color: colorScheme.onSurface, fontSize: 12),
      ),
    );
  }

  /// The two-seed scheme (§9.7.1).
  ///
  /// One seed still generates everything contrast-related — [AppColors.seed]
  /// keeps the wine primary and its contrast-safe text pairs. What it cannot
  /// do is give the app a second identity, so a second `fromSeed` run on
  /// [AppColors.accentSeed] is grafted onto the roles this app actually uses
  /// for "the accent that isn't the brand": `secondary` for chrome that must
  /// not read as the primary action, and `tertiary` for the fastest-sector
  /// highlight in the lap table, where purple is the domain's own convention.
  /// Both land on the same iris family on purpose — there is one accent, and
  /// two Material role slots that want it.
  ///
  /// The surface ramp is then replaced wholesale with [AppColors]' explicit
  /// values; see the note there for why the generated one isn't dark enough.
  static ColorScheme _scheme() {
    const brightness = Brightness.dark;
    final brand = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final accent = ColorScheme.fromSeed(
      seedColor: AppColors.accentSeed,
      brightness: brightness,
    );

    return brand.copyWith(
      secondary: accent.primary,
      onSecondary: accent.onPrimary,
      secondaryContainer: accent.primaryContainer,
      onSecondaryContainer: accent.onPrimaryContainer,
      tertiary: accent.primary,
      onTertiary: accent.onPrimary,
      tertiaryContainer: accent.primaryContainer,
      onTertiaryContainer: accent.onPrimaryContainer,
      surface: AppColors.surfaceBase,
      surfaceContainerLowest: AppColors.surfaceLowest,
      surfaceContainerLow: AppColors.surfaceLow,
      surfaceContainer: AppColors.surfaceMid,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainerHighest: AppColors.surfaceHighest,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    );
  }

  /// Paints [AppGradients.brand] behind a button's contents.
  static Widget Function(BuildContext, Set<WidgetState>, Widget?) _gradientFill(
    double radius,
  ) {
    return (context, states, child) {
      final disabled = states.contains(WidgetState.disabled);
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(radius),
          gradient: disabled ? AppGradients.brandMuted : AppGradients.brand,
        ),
        child: child,
      );
    };
  }
}
