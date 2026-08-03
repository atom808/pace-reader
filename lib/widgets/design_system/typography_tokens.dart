import 'package:flutter/material.dart';

/// Two type roles, not one font for everything (SPEC.md §9.7.7): General
/// Sans for the UI voice (headings, buttons, navigation, body text), and
/// JetBrains Mono — with tabular figures — for every numeral. General Sans
/// itself doesn't support tabular figures, and digit-for-digit alignment on
/// ticking lap times/telemetry values is a real requirement here, not a
/// nice-to-have, so numerals are bundled on a typeface built for it rather
/// than left to inconsistent system-monospace availability per platform.
abstract final class AppFonts {
  static const ui = 'General Sans';
  static const numeral = 'JetBrains Mono';
}

abstract final class AppTextStyles {
  /// Lap times, telemetry values, stat cards, cursor readouts — anything
  /// numeric that should hold its column alignment as it updates.
  static const numeral = TextStyle(
    fontFamily: AppFonts.numeral,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
