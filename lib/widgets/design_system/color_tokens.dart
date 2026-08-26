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
/// dark surface — `#191114` when the check was run, since darkened to
/// [AppColors.surfaceBase]; the separation legs are measured between the
/// channel colours themselves and so are unaffected, and the contrast leg
/// only improves as the surface goes darker — the set passes chroma,
/// adjacent-pair colour-vision separation (worst 11.2 ΔE, target 8), and
/// 3:1 contrast — but the
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

  /// The one accent that is not the brand.
  ///
  /// A single seed makes a coherent palette and a monotonous one: every
  /// surface, border and emphasis ends up a tint of the same wine, and the
  /// eye stops finding the emphasis. Iris is a second identity, chosen
  /// under two constraints rather than for variety:
  ///
  /// - It stays inside **the purple family §9.7.1 reserves for brand
  ///   chrome**, so a second accent cannot collide with a channel identity
  ///   colour by construction — the reservation is what makes it safe to add
  ///   one at all.
  /// - It lands on a domain convention worth having: purple is the fastest
  ///   sector on every timing screen in motorsport, which is the role
  ///   `tertiary` already plays in the lap table (§8.3).
  static const accentSeed = Color(0xFF7C5CFF);
  static const irisDeep = Color(0xFF3A2A8C);

  /// The surface ramp, held as explicit values rather than left to
  /// [ColorScheme.fromSeed]'s tonal steps.
  ///
  /// The generated dark ramp starts at `#191114` and its containers sit
  /// within a few percent of it — legible, but the containers never read as
  /// *objects* on a background, which is the whole visual proposition of a
  /// panelled telemetry tool. The base drops to under half the generated
  /// one's luminance, and the §9.5 charts get a darker field to draw a
  /// saturated trace on.
  ///
  /// Worth being straight about what the ramp does and doesn't buy: the
  /// card-to-background *contrast ratio* is about what it was before, since
  /// the container tones came down with the base. Fill alone was never going
  /// to make a card read as an object at this end of the scale — a few
  /// percent of luminance is a few percent either way. What the darker base
  /// buys is room for the other two mechanisms to work: the gradient edge and
  /// the drop shadow in [SquircleCard], both of which need somewhere dark to
  /// land.
  ///
  /// The tint travels with the ramp on purpose: the base keeps the wine cast
  /// the brand starts from, the raised containers lean a few points toward
  /// iris, so depth and the two-accent story are the same gesture.
  static const surfaceBase = Color(0xFF0B0709);
  static const surfaceLowest = Color(0xFF0E0A0D);
  static const surfaceLow = Color(0xFF151017);
  static const surfaceMid = Color(0xFF1B141E);
  static const surfaceHigh = Color(0xFF221A26);
  static const surfaceHighest = Color(0xFF2B2230);

  /// Divider/outline tones. Kept lighter than the ramp they sit on so a
  /// hairline still reads on the darker base (§9.7.2).
  static const outline = Color(0xFF6B5C6F);
  static const outlineVariant = Color(0xFF3B3040);

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

/// Chrome gradients (SPEC.md §9.7.1).
///
/// One direction and one journey, everywhere: top-left to bottom-right,
/// **wine to iris**. That single rule is what keeps a gradient from reading
/// as decoration — every gradient in the app is the same light falling the
/// same way across a different shape, so a border, a badge and a button all
/// look lit by one source instead of each having a mood.
///
/// Gradients are chrome only. Nothing in [AppGradients] is ever used on a
/// trace, a track map or a value ramp: colour there carries channel identity
/// (§9.7.1) or magnitude (`value_ramp.dart`), and a gradient laid over either
/// makes the same value read as two different ones depending on where it
/// falls in the frame.
abstract final class AppGradients {
  static const _begin = Alignment.topLeft;
  static const _end = Alignment.bottomRight;

  /// Filled brand chrome: the app mark, the selected navigation slot, the
  /// primary action, the session-type badge.
  static const brand = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xFFA8446F), Color(0xFF6A4BE0)],
  );

  /// The same journey at container weight — a tint body text still sits on.
  /// Both ends are the palette's own deep tones rather than a second pair of
  /// literals, so [brand] and [brandMuted] cannot drift apart.
  static const brandMuted = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [AppColors.wineDeep, AppColors.irisDeep],
  );

  /// The hairline every container is drawn with (§9.7.2).
  ///
  /// It fades out toward the bottom-right rather than ringing the shape
  /// evenly: a border of constant weight reads as an outline, one that
  /// brightens on the lit edge reads as an edge, and the card's interior
  /// wash ([surfaceCard]) is lit from the same side.
  static const hairline = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0x8CD2739E), Color(0x5C9070FF), Color(0x1FBFAECB)],
    stops: [0.0, 0.5, 1.0],
  );

  /// [hairline] for anything that is hovered, focused, selected or otherwise
  /// currently the subject — same gradient, more of it.
  static const hairlineStrong = LinearGradient(
    begin: _begin,
    end: _end,
    colors: [Color(0xE6EE8FB6), Color(0xB39E7CFF), Color(0x4DC9B9D4)],
    stops: [0.0, 0.5, 1.0],
  );

  /// A container's interior: lit at the top, settling into the base tone.
  /// Vertical rather than diagonal — a diagonal wash across a wide card
  /// leaves one corner visibly darker than the text sitting next to it.
  static const surfaceCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.surfaceHigh, AppColors.surfaceLow],
  );

  /// The rail's outer edge — the same journey turned vertical, since what it
  /// separates is far taller than it is wide. It is the app's one full-height
  /// rule, and running it as a gradient is what keeps it from reading as a
  /// window chrome divider.
  static const railEdge = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x99D2739E), Color(0x669070FF), Color(0x33BFAECB)],
    stops: [0.0, 0.45, 1.0],
  );

  /// The navigation rail, which is tall and narrow enough for the vertical
  /// wash to be the whole effect.
  ///
  /// It settles on [AppColors.surfaceLowest] rather than the base the content
  /// area is painted in: landing on the same value would make the rail
  /// dissolve into the page at the bottom of a tall window, which is exactly
  /// where the separation is least obvious anyway.
  static const rail = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1020), AppColors.surfaceLowest],
  );
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
