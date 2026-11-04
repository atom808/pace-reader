import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/design_system/design_system.dart';
import 'lap_focus.dart';

/// The button every "show this lap there" link is: the target's glyph, a
/// label that says which lap, and Ctrl+Enter, which each linking screen binds
/// to the same [openFocus].
class LapFocusLink extends ConsumerWidget {
  const LapFocusLink({
    super.key,
    required this.target,
    required this.focus,
    this.label,
    this.tooltip,
    this.compact = false,
  }) : at = null;

  /// A link whose focus is read when it is pressed: one from a moving
  /// playhead, which a focus built at every rebuild would chase.
  const LapFocusLink.lazy({
    super.key,
    required this.target,
    required LapFocus Function() this.at,
    required String this.label,
    this.tooltip,
    this.compact = false,
  }) : focus = null;

  final LapFocusTarget target;

  /// Null disables the link: there is no lap to show yet.
  final LapFocus? focus;

  /// Builds the focus on press, in place of [focus].
  final LapFocus Function()? at;

  /// Defaults to "Lap n in Target", or "Open in Target" without a lap.
  final String? label;

  /// Defaults to the key that does the same.
  final String? tooltip;

  /// The glyph alone, the label moved into the tooltip: for a header that
  /// has no room for words.
  final bool compact;

  /// The default label for [focus] on [target].
  static String labelFor(LapFocusTarget target, LapFocus? focus) =>
      focus == null
      ? 'Open in ${target.label}'
      : 'Lap ${focus.lap + 1} in ${target.label}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focus = this.focus;
    final at = this.at ?? (focus == null ? null : () => focus);
    final text = label ?? labelFor(target, focus);
    final onPressed = at == null
        ? null
        : () => openFocus(context, ref, target, at());
    final icon = Icon(target.icon, size: 18);
    return AppTooltip(
      // The glyph alone has to say where it goes.
      message: tooltip ?? (compact ? '$text (Ctrl+Enter)' : 'Ctrl+Enter'),
      child: compact
          ? IconButton(onPressed: onPressed, icon: icon)
          : TextButton.icon(
              style: AppButtonStyles.secondary(context),
              onPressed: onPressed,
              icon: icon,
              label: Text(text),
            ),
    );
  }
}
