import 'package:flutter/material.dart';

/// Brand and channel color tokens (SPEC.md §9.7.1).
///
/// The brand seed feeds [ColorScheme.fromSeed]; channel colors are kept
/// deliberately outside the purple family so a delta trace never reads as
/// brand chrome.
abstract final class AppColors {
  static const seed = Color(0xFF9B3F6B);
  static const wineDeep = Color(0xFF5A2145);

  static const channelThrottle = Color(0xFF4FD897);
  static const channelBrake = Color(0xFFF16456);
  static const channelSpeed = Color(0xFF38C6D9);
  static const channelRpm = Color(0xFFE7A83E);
  static const channelDelta = Color(0xFF5C8FE6);
}

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
  });

  final Color throttle;
  final Color brake;
  final Color speed;
  final Color rpm;
  final Color delta;

  static const dark = ChannelColors(
    throttle: AppColors.channelThrottle,
    brake: AppColors.channelBrake,
    speed: AppColors.channelSpeed,
    rpm: AppColors.channelRpm,
    delta: AppColors.channelDelta,
  );

  @override
  ChannelColors copyWith({
    Color? throttle,
    Color? brake,
    Color? speed,
    Color? rpm,
    Color? delta,
  }) {
    return ChannelColors(
      throttle: throttle ?? this.throttle,
      brake: brake ?? this.brake,
      speed: speed ?? this.speed,
      rpm: rpm ?? this.rpm,
      delta: delta ?? this.delta,
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
    );
  }
}
