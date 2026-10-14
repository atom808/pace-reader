import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/duckdb/telemetry_database.dart';
import '../data/models/models.dart';
import '../data/repositories/providers.dart';
import '../features/driver_comparison/presentation/compare_close_guard.dart';
import '../features/session_library/application/open_sessions.dart';
import '../features/session_library/application/session_import.dart';
import '../widgets/design_system/design_system.dart';
import '../widgets/identity/class_chip.dart';
import 'session_labels.dart';
import 'shell_actions.dart';

/// The rail's answer to "which session am I looking at, and what else is
/// open?" (SPEC.md §8.1, §9.7.6).
///
/// Every screen from §8.2 on reads `currentSessionProvider`, which is simply
/// the front of the open list — so the session on screen is state the whole
/// app agrees on, and until now the only place it was visible was a card on
/// the Sessions page. A trace of the wrong lap set is a classic way to spend
/// ten minutes; the badge at the foot of the rail says which recording every
/// panel is drawn from, from every screen.
///
/// **The trigger** is a rail slot holding a badge: the session-type code
/// (`P`/`Q`/`R`) on the brand gradient, with the short circuit name in the
/// tooltip and a count when more than one is open. With nothing open it is a
/// `+`, and says so.
///
/// **The popover** lists this run's open sessions — pick one to make it
/// current, close one with its `×` — and ends in "Open file…". It is glass
/// (§9.7.3 names "modals/popovers"), which is safe here for the reason the
/// rule exists: it is static chrome, drawn once, nowhere near a chart.
///
/// It is an [OverlayPortal] rather than a `MenuAnchor` or `showMenu` because
/// none of the stock menus animate on [AppCurves.entrance] or take the
/// [GlassSurface] look, and because a portal keeps the popover *inside* the
/// widget tree of the shell: the theme, the provider scope and the shell's
/// shortcuts all reach it, where a route pushed by `showMenu` would sit
/// outside them.
///
/// Keyboard: the trigger is a [Hoverable], so Tab reaches it and Enter/Space
/// open it; opening moves focus to the first row, arrow keys and Tab move
/// through the rows (inside their own [FocusScope], so focus cannot wander
/// back into the rail), Escape closes and hands focus back to the trigger.
class SessionSwitcher extends HookConsumerWidget {
  const SessionSwitcher({super.key});

  /// Wide enough for "Spa-Francorchamps Endurance" and its close button on
  /// one line at the theme's body size; a longer name ellipsises rather than
  /// growing the popover across the content.
  static const popoverWidth = 328.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openSessionsProvider);
    final current = ref.watch(currentSessionProvider);
    final importState = ref.watch(sessionImportProvider);

    final portal = useOverlayPortalController();
    final link = useMemoized(LayerLink.new);
    final tapGroup = useMemoized(Object.new);
    final triggerFocus = useFocusNode(debugLabel: 'SessionSwitcher trigger');
    final popoverScope = useMemoized(
      () => FocusScopeNode(debugLabel: 'SessionSwitcher popover'),
    );
    useEffect(() => popoverScope.dispose, [popoverScope]);
    final expanded = useState(false);
    final controller = useAnimationController(
      duration: AppMotion.duration(context, AppDurations.medium),
      // Leaving is quicker than arriving: the eye is already on what the
      // user picked, and a popover that lingers after the choice reads as lag.
      reverseDuration: AppMotion.duration(context, AppDurations.fast),
    );
    final curved = useMemoized(
      () => CurvedAnimation(
        parent: controller,
        curve: AppCurves.entrance,
        reverseCurve: AppCurves.standard,
      ),
      [controller],
    );
    useEffect(() => curved.dispose, [curved]);

    void show() {
      expanded.value = true;
      portal.show();
      controller.forward();
    }

    Future<void> hide({bool restoreFocus = false}) async {
      if (!portal.isShowing) return;
      // Handing focus back happens first, while the popover still holds it:
      // once the portal is hidden the focused row is gone and focus would
      // fall to the enclosing scope instead of the trigger that opened it.
      if (restoreFocus && popoverScope.hasFocus) triggerFocus.requestFocus();
      await controller.reverse();
      // A `show()` during the exit replaces the reverse with a forward, which
      // never completes this future — and if it somehow did, the status check
      // still keeps a re-opened popover from being hidden under the user.
      if (context.mounted && controller.status == AnimationStatus.dismissed) {
        portal.hide();
        expanded.value = false;
      }
    }

    final platform = defaultTargetPlatform;
    final busy = importState is SessionImportBusy;

    final body = TapRegion(
      groupId: tapGroup,
      onTapOutside: (_) => hide(),
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (overlayContext) => Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.bottomLeft,
            // Clear of the rail's own edge, which sits 14 px past the slot.
            offset: const Offset(22, 0),
            child: TapRegion(
              groupId: tapGroup,
              child: _PopoverEntrance(
                animation: curved,
                child: FocusScope(
                  node: popoverScope,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () =>
                          hide(restoreFocus: true),
                    },
                    child: _SwitcherPopover(
                      open: open,
                      current: current,
                      busy: busy,
                      platform: platform,
                      onSelect: (source) {
                        ref.read(openSessionsProvider.notifier).open(source);
                        hide(restoreFocus: true);
                      },
                      // Asks first when Compare uses the file (comparison
                      // proposal §9).
                      onClose: (source) =>
                          closeSessionChecked(context, ref, source),
                      onOpenFile: () {
                        hide(restoreFocus: true);
                        openFileFromShell(context, ref);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: CompositedTransformTarget(
          link: link,
          child: _Trigger(
            current: current,
            openCount: open.length,
            expanded: expanded.value,
            focusNode: triggerFocus,
            onTap: () {
              if (portal.isShowing &&
                  controller.status != AnimationStatus.reverse) {
                hide();
              } else {
                show();
              }
            },
          ),
        ),
      ),
    );
    // A node of the portal's own, for the reason every tooltip has one (see
    // AppTooltip): the popover's semantics hang under it.
    return Semantics(container: true, child: body);
  }
}

/// The badge slot at the foot of the rail. Same footprint as a nav slot, so
/// the column reads as one list whose last entry is the session.
class _Trigger extends ConsumerWidget {
  const _Trigger({
    required this.current,
    required this.openCount,
    required this.expanded,
    required this.focusNode,
    required this.onTap,
  });

  final TelemetrySource? current;
  final int openCount;
  final bool expanded;
  final FocusNode focusNode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = current;
    final metadata = source == null
        ? null
        : ref.watch(sessionMetadataProvider(source)).asData?.value;

    final String label;
    if (source == null) {
      label = 'No session open — click to open a file';
    } else if (metadata == null) {
      label = 'Opening session…';
    } else {
      final more = openCount > 1 ? '  ·  $openCount open' : '';
      label =
          '${shortCircuitTitle(metadata)} — ${metadata.sessionType.rawValue}$more';
    }

    // The tooltip goes outside the button, so that the node it brings (see
    // AppTooltip) is the button's own rather than an empty one inside it.
    return AppTooltip(
      // Out of the way while the popover is up: it says the same thing,
      // at length, next to it.
      message: expanded ? '' : label,
      excludeFromSemantics: true,
      child: Hoverable(
        radius: AppRadii.md,
        semanticLabel: 'Sessions: $label',
        focusNode: focusNode,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppDurations.fast),
          curve: AppCurves.standard,
          height: 48,
          // The lit edge is the language for "the subject right now" (§9.7.2)
          // — here, the slot whose popover is open.
          decoration: ShapeDecoration(
            shape: expanded
                ? const GradientSquircleBorder(
                    radius: AppRadii.md,
                    gradient: AppGradients.hairlineStrong,
                  )
                : AppRadii.squircle(AppRadii.md),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              FadeOnChange(
                value: source,
                duration: AppMotion.duration(context, AppDurations.medium),
                switchInCurve: AppCurves.entrance,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: source == null
                    ? const _EmptyBadge()
                    : _SessionBadge(source: source),
              ),
              if (openCount > 1)
                Positioned(
                  right: -6,
                  top: -6,
                  child: _CountPip(count: openCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many sessions are open, on the badge — the only sign from the rail that
/// there is more than one to switch to.
class _CountPip extends StatelessWidget {
  const _CountPip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: const GradientSquircleBorder(
          radius: 7,
          gradient: AppGradients.hairlineStrong,
          width: 1,
        ),
        color: AppColors.surfaceHighest,
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: AppTextStyles.numeral.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

const _badgeSize = 40.0;

/// What the trigger shows before there is a session: the shape, with a `+`.
class _EmptyBadge extends StatelessWidget {
  const _EmptyBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: ShapeDecoration(
        shape: GradientSquircleBorder(radius: AppRadii.sm),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.add, size: 20, color: scheme.onSurfaceVariant),
    );
  }
}

/// One session's type code on the brand gradient — a skeleton while its
/// metadata is read, and a plain marker if it cannot be.
class _SessionBadge extends ConsumerWidget {
  const _SessionBadge({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = ref.watch(sessionMetadataProvider(source));
    return SizedBox.square(
      dimension: _badgeSize,
      child: AsyncValueView<SessionMetadata>(
        value: metadata,
        loading: (_) => const Skeleton(height: _badgeSize, width: _badgeSize),
        error: (context, error, _) => Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        data: (context, meta) => _TypeBadge(type: meta.sessionType),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final SessionType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _badgeSize,
      height: _badgeSize,
      decoration: const ShapeDecoration(
        shape: GradientSquircleBorder(
          radius: AppRadii.sm,
          gradient: AppGradients.hairlineStrong,
        ),
        gradient: AppGradients.brand,
      ),
      alignment: Alignment.center,
      child: Text(
        type.filenameCode,
        style: AppTextStyles.numeral.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// Fade, a short slide out of the rail and a settle from 96%, all on
/// [AppCurves.entrance] — the popover arrives from the badge that summoned it
/// rather than appearing over the page. Scaled from its bottom-left corner
/// because that is the corner the badge is next to.
class _PopoverEntrance extends StatelessWidget {
  const _PopoverEntrance({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(-0.04, 0),
          end: Offset.zero,
        ).animate(animation),
        child: ScaleTransition(
          alignment: Alignment.bottomLeft,
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

class _SwitcherPopover extends StatelessWidget {
  const _SwitcherPopover({
    required this.open,
    required this.current,
    required this.busy,
    required this.platform,
    required this.onSelect,
    required this.onClose,
    required this.onOpenFile,
  });

  final List<TelemetrySource> open;
  final TelemetrySource? current;
  final bool busy;
  final TargetPlatform platform;
  final ValueChanged<TelemetrySource> onSelect;
  final ValueChanged<TelemetrySource> onClose;
  final VoidCallback onOpenFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Room for the shortest window this app is used at (~1000 px wide by
    // ~700 tall, §9.7) with the popover growing upward from the rail's foot;
    // more sessions than fit scroll rather than push the header off screen.
    final maxHeight = (MediaQuery.sizeOf(context).height - 48).clamp(
      200.0,
      520.0,
    );

    return Semantics(
      container: true,
      label: 'Open sessions',
      child: SizedBox(
        width: SessionSwitcher.popoverWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: GlassSurface(
            radius: AppRadii.lg,
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Open sessions',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${open.length}',
                        style: AppTextStyles.numeral.copyWith(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (open.isEmpty)
                  const _NoSessions()
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      // The Hoverable rows grow 1% and draw a ring 3 px
                      // outside themselves; the list must not clip either.
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      itemCount: open.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _SessionRow(
                        source: open[index],
                        isCurrent: open[index] == current,
                        autofocus: index == 0,
                        onSelect: () => onSelect(open[index]),
                        onClose: () => onClose(open[index]),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const _Divider(),
                const SizedBox(height: 8),
                _OpenFileRow(
                  busy: busy,
                  hint: shortcutLabel('O', platform),
                  autofocus: open.isEmpty,
                  onTap: onOpenFile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(gradient: AppGradients.hairline),
    ),
  );
}

/// Stated rather than blank (§9.7): what the list would have said, and the way
/// to fill it.
class _NoSessions extends StatelessWidget {
  const _NoSessions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Text(
        'No session is open. Open a Le Mans Ultimate .duckdb recording, or '
        'drop one onto the Sessions page.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({
    required this.source,
    required this.isCurrent,
    required this.autofocus,
    required this.onSelect,
    required this.onClose,
  });

  final TelemetrySource source;
  final bool isCurrent;
  final bool autofocus;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = ref.watch(sessionMetadataProvider(source));
    final title = metadata.asData?.value == null
        ? source.label
        : shortCircuitTitle(metadata.requireValue);

    return Hoverable(
      radius: AppRadii.md,
      autofocus: autofocus,
      semanticLabel: isCurrent ? '$title, current session' : title,
      onTap: onSelect,
      child: DecoratedBox(
        // The current session is the subject of the list: the same lit edge
        // and brand tint the selected nav slot wears.
        decoration: ShapeDecoration(
          shape: isCurrent
              ? const GradientSquircleBorder(
                  radius: AppRadii.md,
                  gradient: AppGradients.hairlineStrong,
                )
              : AppRadii.squircle(AppRadii.md),
          gradient: isCurrent ? AppGradients.brandMuted : null,
          // A faint fill on the rest, so every row reads as something to
          // press before the pointer has told it so.
          color: isCurrent ? null : _rowFill(scheme),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: AsyncValueView<SessionMetadata>(
            value: metadata,
            loading: (_) => const Row(
              children: [
                Skeleton(width: _badgeSize, height: _badgeSize),
                SizedBox(width: 12),
                Expanded(child: Skeleton(height: 20)),
              ],
            ),
            error: (context, error, _) => Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${source.label} could not be read',
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _CloseButton(onPressed: onClose),
              ],
            ),
            data: (context, meta) => Row(
              children: [
                _TypeBadge(type: meta.sessionType),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Current',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          ClassChip.raw(
                            meta.carClass,
                            size: ClassChipSize.compact,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${meta.sessionType.rawValue}  ·  '
                              '${meta.driverName}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _CloseButton(onPressed: onClose),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Close this session',
      icon: const Icon(Icons.close, size: 18),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class _OpenFileRow extends StatelessWidget {
  const _OpenFileRow({
    required this.busy,
    required this.hint,
    required this.autofocus,
    required this.onTap,
  });

  final bool busy;
  final String hint;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Hoverable(
      radius: AppRadii.md,
      autofocus: autofocus,
      semanticLabel: busy ? 'Opening a file' : 'Open file',
      // Inert while an import runs, as the library's own button is: a second
      // picker on top of the first is never what was meant.
      onTap: busy ? null : onTap,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(AppRadii.md),
          color: _rowFill(scheme),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 20,
                color: busy ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  busy ? 'Opening…' : 'Open file…',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: busy ? scheme.onSurfaceVariant : null,
                  ),
                ),
              ),
              Text(
                hint,
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _rowFill(ColorScheme scheme) =>
    scheme.surfaceContainerHigh.withValues(alpha: 0.55);
