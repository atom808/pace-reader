/// How much the interface spends on effects (map stage proposal §7.4).
///
/// Set once, at the app's root, from the Performance mode setting; read by
/// whatever draws an effect — [GlassSurface], the map stage's entrance — so
/// no widget looks the setting up for itself and the design system never
/// imports a feature.
library;

import 'package:material_ui/material_ui.dart';

enum EffectsLevel {
  /// Backdrop blur, the pen-stroke entrance: the designed look.
  full,

  /// Performance mode: glass becomes a denser tint with nothing blurred
  /// behind it, and the map appears rather than drawing itself.
  performance,
}

class EffectsQuality extends InheritedWidget {
  const EffectsQuality({super.key, required this.level, required super.child});

  final EffectsLevel level;

  /// The level in force; [EffectsLevel.full] outside any [EffectsQuality].
  static EffectsLevel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EffectsQuality>()?.level ??
      EffectsLevel.full;

  /// Whether backdrop blur is wanted here.
  static bool blurs(BuildContext context) => of(context) == EffectsLevel.full;

  @override
  bool updateShouldNotify(EffectsQuality oldWidget) => oldWidget.level != level;
}
