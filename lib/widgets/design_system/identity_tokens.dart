import 'package:material_ui/material_ui.dart';

/// Colours that identify things in the game rather than in a chart: car
/// classes and tyre compounds (docs/ICONOGRAPHY-PLAN-2026-10-14.md).
///
/// These are **Le Mans Ultimate's own values**, read from the game's UI
/// stylesheet (`Bin\UI.zip`, `start\assets\app-*.css`, 2026-10-14) rather than
/// sampled from a screenshot, so a class reads the same colour here as in
/// the game's timing screens.
///
/// They are a third identity system beside §9.7.1's brand and channel
/// colours, and the full hue wheel does not stop them, for the reason the
/// channels already live by: identity colours must separate only where they
/// share a frame. A class colour lives only in chrome, never inside a plot,
/// and always carries its name, so colour is never the only cue. Hypercar
/// sits near brake red and LMGT3 near throttle green; neither pair ever
/// shares a frame.
abstract final class ClassColors {
  /// `--hypercar-color`.
  static const hypercar = Color(0xFFE21E19);

  /// `--lmp2-color`, for both LMP2s.
  static const lmp2 = Color(0xFF005096);

  /// `--lmp2-elms-color`: the corner triangle that marks the European Le
  /// Mans Series' unrestricted LMP2 on an LMP2-blue badge.
  static const lmp2ElmsMarker = Color(0xFFE95B0C);

  /// `--lmp3-color`.
  static const lmp3 = Color(0xFF411C52);

  /// `--gte-color`.
  static const lmgte = Color(0xFFF08C00);

  /// `--gt3-color`.
  static const lmgt3 = Color(0xFF009639);
}

/// Tyre compounds in the game's colours (`--clr-tyre-soft` …, the same
/// stylesheet), for the band and letter of a compound badge.
///
/// Hard sits near brake red, Medium near the charge yellow and Wet near the
/// speed teal. That is fine by the same rule as [ClassColors]: a badge never
/// shares a plot frame with a channel, and it always carries its letter.
abstract final class CompoundColors {
  static const soft = Color(0xFFF3F4F8);
  static const medium = Color(0xFFFFE500);
  static const hard = Color(0xFFF80010);
  static const wet = Color(0xFF4ED1EF);

  /// The tyre's rubber: a neutral charcoal, a step above every surface so
  /// the disc reads as an object on a card, in a chip or on glass.
  static const rubber = Color(0xFF1A181D);

  /// The shoulder: the hairline round the disc.
  static const shoulder = Color(0xFF3D3942);
}
