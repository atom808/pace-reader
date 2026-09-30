import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/car_setup.dart';
import 'setup_section_card.dart';

/// The height the pinned toolbar occupies: two rows of controls (48 + 34), the
/// card's padding, and a gap above and below so scrolled content never touches
/// it. Measured, not rounded up: a taller box leaves a dead band under the
/// chips inside the card.
const setupToolbarExtent = 136.0;

/// Below this width of the card's interior the section chips drop their icons
/// and tighten, so all nine still fit at the ~1000 px window the layout is
/// asked to work at (measured: 1115 px of chips with icons, 917 without).
const _compactChipsBelow = 1040.0;

/// The sticky search-and-navigate bar (SPEC.md §8.10): a search box, the two
/// toggles, and one chip per section.
///
/// A 172-key blob is navigated two ways and both are one control away at any
/// scroll position: by *name* (the search box narrows every section at once)
/// and by *place* (a chip jumps to a section and opens it if it was closed).
/// The chip for whichever section is under the bar is lit as the page scrolls.
class SetupToolbar extends StatelessWidget {
  const SetupToolbar({
    super.key,
    required this.setup,
    required this.view,
    required this.filter,
    required this.controller,
    required this.focusNode,
    required this.active,
    required this.onQuery,
    required this.onFilter,
    required this.onSection,
  });

  final CarSetup setup;
  final SetupView view;
  final SetupFilter filter;
  final TextEditingController controller;
  final FocusNode focusNode;

  /// The section under the bar, for the lit chip.
  final ValueListenable<SetupSectionId?> active;

  final ValueChanged<String> onQuery;
  final ValueChanged<SetupFilter> onFilter;
  final ValueChanged<SetupSectionId> onSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return ColoredBox(
      // Opaque, so rows scrolling underneath do not show through the gap
      // around the card.
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
        child: SquircleCard(
          radius: AppRadii.md,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 380),
                      child: CallbackShortcuts(
                        // Esc empties the box without leaving it, the way a
                        // search field in every desktop app does.
                        bindings: {
                          const SingleActivator(LogicalKeyboardKey.escape): () {
                            controller.clear();
                            onQuery('');
                          },
                        },
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onChanged: onQuery,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search, size: 18),
                            hintText: 'Search settings — camber, soft, kPa…',
                            suffixIcon: filter.query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    iconSize: 16,
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      controller.clear();
                                      onQuery('');
                                      focusNode.requestFocus();
                                    },
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilterChip(
                    label: Text('Show N/A · ${setup.notApplicableCount}'),
                    selected: filter.showNotApplicable,
                    showCheckmark: false,
                    avatar: Icon(
                      filter.showNotApplicable
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_outlined,
                      size: 16,
                    ),
                    tooltip:
                        'Settings the game marks N/A: the car has no such '
                        'adjustment',
                    onSelected: (on) =>
                        onFilter(filter.copyWith(showNotApplicable: on)),
                  ),
                  if (setup.hasLockedSettings) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('Adjustable only · ${setup.adjustableCount}'),
                      selected: filter.adjustableOnly,
                      showCheckmark: false,
                      avatar: const Icon(Icons.tune_rounded, size: 16),
                      tooltip:
                          'Hide what this session locks — the settings a '
                          'fixed-setup race leaves you free to change',
                      onSelected: (on) =>
                          onFilter(filter.copyWith(adjustableOnly: on)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${view.shown} of ${view.total}',
                    style: AppTextStyles.numeral.copyWith(
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < _compactChipsBelow;
                  return SizedBox(
                    height: 34,
                    child: ScrollConfiguration(
                      // Whatever is still too wide scrolls — and a mouse can
                      // drag it, since a wheel only scrolls vertically.
                      behavior: ScrollConfiguration.of(context).copyWith(
                        scrollbars: false,
                        dragDevices: PointerDeviceKind.values.toSet(),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ValueListenableBuilder<SetupSectionId?>(
                          valueListenable: active,
                          builder: (context, current, _) => Row(
                            children: [
                              for (final section in setup.sections) ...[
                                _NavChip(
                                  id: section.id,
                                  count: view.section(section.id)?.count,
                                  active: current == section.id,
                                  compact: compact,
                                  onTap: () => onSection(section.id),
                                ),
                                SizedBox(width: compact ? 6 : 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.id,
    required this.count,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final SetupSectionId id;

  /// Icon-less and tighter, for a narrow bar.
  final bool compact;

  /// Settings in this section under the current filter; null when the filter
  /// leaves none, which dims the chip and stops it navigating to nothing.
  final int? count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = count != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: '${id.title}${count == null ? '' : ', $count settings'}',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: AppRadii.squircle(AppRadii.sm),
            child: AnimatedContainer(
              duration: reduceMotion ? Duration.zero : AppDurations.fast,
              curve: AppCurves.standard,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: 6,
              ),
              decoration: ShapeDecoration(
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  side: BorderSide(
                    color: active ? scheme.secondary : scheme.outlineVariant,
                  ),
                ),
                color: active
                    ? scheme.secondary.withValues(alpha: 0.16)
                    : AppColors.surfaceMid,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) ...[
                    Icon(
                      sectionIcon(id),
                      size: 15,
                      color: active
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(id.shortTitle, style: theme.textTheme.labelLarge),
                  if (count != null) ...[
                    const SizedBox(width: 7),
                    Text(
                      '$count',
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pins [SetupToolbar] under the app bar while the sections scroll beneath it.
class SetupToolbarDelegate extends SliverPersistentHeaderDelegate {
  SetupToolbarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => setupToolbarExtent;

  @override
  double get maxExtent => setupToolbarExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(height: setupToolbarExtent, child: child);

  @override
  bool shouldRebuild(SetupToolbarDelegate oldDelegate) =>
      oldDelegate.child != child;
}
