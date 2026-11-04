/// A short notice on glass, floating over a screen: "Back to Trace",
/// "Playback is stuttering". One line, at most one action, and a way to
/// close it — never a dialog the user must answer.
library;

import 'package:material_ui/material_ui.dart';

import 'app_tooltip.dart';
import 'glass_surface.dart';
import 'motion_tokens.dart';
import 'radius_tokens.dart';

class GlassNotice extends StatelessWidget {
  const GlassNotice({
    super.key,
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
    this.onTap,
    required this.onDismiss,
  });

  final IconData icon;
  final String message;

  /// The button's label: "Turn on". Shown when [onAction] is set.
  final String? action;
  final VoidCallback? onAction;

  /// The whole notice as the action, for one whose message is the action:
  /// "Back to Trace · 1240 m".
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
        ),
      ],
    );
    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassSurface(
        radius: AppRadii.lg,
        tint: 0.7,
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: onTap == null
                  ? text
                  : InkWell(
                      onTap: onTap,
                      customBorder: AppRadii.squircle(AppRadii.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: text,
                      ),
                    ),
            ),
            if (onAction case final act?) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: act, child: Text(action ?? 'OK')),
            ],
            AppTooltip(
              message: 'Dismiss',
              child: IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides [notice] down into place and fades it, and back out when it goes
/// null; a cut under reduced motion.
class GlassNoticeSlot extends StatelessWidget {
  const GlassNoticeSlot({super.key, required this.notice});

  final Widget? notice;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, AppDurations.medium),
    switchInCurve: AppCurves.standard,
    switchOutCurve: AppCurves.standard,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, -0.4),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: notice ?? const SizedBox.shrink(),
  );
}
