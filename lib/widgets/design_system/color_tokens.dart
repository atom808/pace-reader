import 'package:flutter/material.dart';

/// Brand and channel color tokens (SPEC.md §9.7.1).
///
/// The brand seed feeds [ColorScheme.fromSeed]; channel colors are kept
/// deliberately outside the purple family so a delta trace never reads as
/// brand chrome.
///
/// ## These are identity colors, and they are not a categorical palette
///
/// Run through a standard categorical-palette check against this theme's
/// dark surface, the set passes chroma, adjacent-pair colour-vision
/// separation (worst 11.2 ΔE, target 8), and 3:1 contrast — but the
/// *all-pairs* separation floor fails on speed↔throttle at 12.0 ΔE, below the
/// 15 a reader with full colour vision needs to tell two co-plotted series
/// apart. That is a real limit and worth naming rather than discovering
/// later: it is safe here **because §9.5 stacks one channel per panel**, each
/// directly labelled with its own swatch, name and unit, so no two of these
/// colours ever share a plot frame. The day two channels are drawn in one
/// frame — a per-corner tire panel, an overlay — that pair has to be
/// re-stepped or given a second encoding first.
abstract final class AppColors {
  static const seed = Color(0xFF9B3F6B);
  static const wineDeep = Color(0xFF5A2145);

  static const channelThrottle = Color(0xFF4FD897);
  static const channelBrake = Color(0xFFF16456);
  static const channelSpeed = Color(0xFF38C6D9);
  static const channelRpm = Color(0xFFE7A83E);
  static const channelDelta = Color(0xFF5C8FE6);

  /// Steering is a **bipolar** signal — the fixture's `Steering Pos` runs
  /// -23.8 to +51.3 — so it gets a neutral rather than a hue. That is the
  /// conventional encoding for a signal whose interesting value is its
  /// deviation from centre, and it keeps the five saturated channel colours
  /// meaning "a performance channel".
  static const channelSteering = Color(0xFFB5AAB0);

  /// Gear is the one *event*-sourced trace in the default stack (§5.1), drawn
  /// as held steps rather than a filled trace, and chartreuse is the widest
  /// gap left in the hue circle once throttle/brake/speed/RPM/delta are
  /// placed and the purple family is reserved for brand chrome (§9.7.1).
  static const channelGear = Color(0xFFC7D94F);
}

/// The signal a colour identifies, rather than a specific colour.
///
/// Feature code names a role and the theme resolves it, so a channel's
/// identity survives a palette change and nothing outside this file has to
/// hold a [Color] constant for a telemetry signal.
enum ChannelRole { speed, throttle, brake, steering, rpm, gear, delta }

/// Theme extension exposing the channel color palette (§9.7.1, §9.7.6)
/// alongside the standard Material [ColorScheme] — channel colors encode
/// signal type, not driver identity, so they live outside [ColorScheme].
@immutable
class ChannelColors extends ThemeExtension<ChannelColors> {
  const ChannelColors({
    required this.throttle,
    required this.brake,
    required this.speed,
    required this.rpm,
    required this.delta,
    required this.steering,
    required this.gear,
  });

  final Color throttle;
  final Color brake;
  final Color speed;
  final Color rpm;
  final Color delta;
  final Color steering;
  final Color gear;

  static const dark = ChannelColors(
    throttle: AppColors.channelThrottle,
    brake: AppColors.channelBrake,
    speed: AppColors.channelSpeed,
    rpm: AppColors.channelRpm,
    delta: AppColors.channelDelta,
    steering: AppColors.channelSteering,
    gear: AppColors.channelGear,
  );

  /// The colour for [role].
  Color of(ChannelRole role) => switch (role) {
        ChannelRole.speed => speed,
        ChannelRole.throttle => throttle,
        ChannelRole.brake => brake,
        ChannelRole.steering => steering,
        ChannelRole.rpm => rpm,
        ChannelRole.gear => gear,
        ChannelRole.delta => delta,
      };

  /// Resolves the palette from the ambient theme, falling back to the dark
  /// set so a widget rendered outside [AppTheme] still draws in the right
  /// colours rather than crashing on a missing extension.
  static ChannelColors resolve(BuildContext context) =>
      Theme.of(context).extension<ChannelColors>() ?? dark;

  @override
  ChannelColors copyWith({
    Color? throttle,
    Color? brake,
    Color? speed,
    Color? rpm,
    Color? delta,
    Color? steering,
    Color? gear,
  }) {
    return ChannelColors(
      throttle: throttle ?? this.throttle,
      brake: brake ?? this.brake,
      speed: speed ?? this.speed,
      rpm: rpm ?? this.rpm,
      delta: delta ?? this.delta,
      steering: steering ?? this.steering,
      gear: gear ?? this.gear,
    );
  }

  @override
  ChannelColors lerp(ThemeExtension<ChannelColors>? other, double t) {
    if (other is! ChannelColors) return this;
    return ChannelColors(
      throttle: Color.lerp(throttle, other.throttle, t)!,
      brake: Color.lerp(brake, other.brake, t)!,
      speed: Color.lerp(speed, other.speed, t)!,
      rpm: Color.lerp(rpm, other.rpm, t)!,
      delta: Color.lerp(delta, other.delta, t)!,
      steering: Color.lerp(steering, other.steering, t)!,
      gear: Color.lerp(gear, other.gear, t)!,
    );
  }
}
