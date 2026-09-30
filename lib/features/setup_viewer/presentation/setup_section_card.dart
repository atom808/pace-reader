import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/car_setup.dart';
import 'gear_panel.dart';
import 'setting_widgets.dart';

/// One glyph per section, shared by the card header and the navigation chip so
/// the two read as the same thing.
IconData sectionIcon(SetupSectionId id) => switch (id) {
  SetupSectionId.aero => Icons.air_rounded,
  SetupSectionId.brakes => Icons.album_outlined,
  SetupSectionId.suspension => Icons.height_rounded,
  SetupSectionId.alignment => Icons.straighten_rounded,
  SetupSectionId.tyres => Icons.tire_repair_outlined,
  SetupSectionId.differential => Icons.call_split_rounded,
  SetupSectionId.gearing => Icons.settings_suggest_outlined,
  SetupSectionId.electronics => Icons.memory_rounded,
  SetupSectionId.engine => Icons.local_gas_station_outlined,
  SetupSectionId.other => Icons.more_horiz_rounded,
};

/// A collapsible section of the setup (SPEC.md §8.10): a header that is the
/// whole toggle, and a body that opens and closes on [AppDurations.medium].
///
/// Sections open by default and are closed by the reader, not the other way
/// round — a 172-key setup is a document to scan and search, and hiding it
/// behind ten closed cards would make every first look ten clicks.
class SetupSectionCard extends StatelessWidget {
  const SetupSectionCard({
    super.key,
    required this.section,
    required this.expanded,
    required this.onToggle,
    required this.style,
    this.gears,
  });

  final SetupSection section;
  final bool expanded;
  final VoidCallback onToggle;
  final RowStyle style;

  /// The gear graph, drawn at the top of Gearing.
  final GearGraph? gears;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SquircleCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            section: section,
            expanded: expanded,
            onToggle: onToggle,
          ),
          _Collapsible(
            expanded: expanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(
                  height: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: _SectionBody(
                    section: section,
                    style: style,
                    gears: gears,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.expanded,
    required this.onToggle,
  });

  final SetupSection section;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final count = section.count;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // A transparent Material of its own, so the ink lands *above* the card's
    // gradient fill rather than behind it — an InkWell under a decorated box
    // paints its highlight on the scaffold's layer, which the card then covers.
    return Material(
      type: MaterialType.transparency,
      child: Semantics(
        button: true,
        expanded: expanded,
        label:
            '${section.id.title}, $count ${count == 1 ? 'setting' : 'settings'}',
        excludeSemantics: true,
        onTap: onToggle,
        child: InkWell(
          onTap: onToggle,
          customBorder: ContinuousRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(AppRadii.lg),
              bottom: Radius.circular(expanded ? 0 : AppRadii.lg),
            ),
          ),
          hoverColor: scheme.onSurface.withValues(alpha: 0.04),
          focusColor: scheme.onSurface.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: AppRadii.squircle(12),
                    gradient: AppGradients.brandMuted,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      sectionIcon(section.id),
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    section.id.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$count ${count == 1 ? 'setting' : 'settings'}',
                  style: AppTextStyles.numeral.copyWith(
                    fontSize: 12,
                    color: muted,
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: reduceMotion ? Duration.zero : AppDurations.medium,
                  curve: AppCurves.entrance,
                  child: Icon(Icons.expand_more_rounded, color: muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens and closes its child on [AppDurations.medium]: the height eases via
/// [AppCurves.entrance] while the content fades, and the child is dropped from
/// the tree once fully closed, so a closed section costs nothing.
///
/// A row of the section leaving mid-search is a separate motion — the inner
/// [AnimatedSize] — so filtering and collapsing each animate on their own
/// terms and never fight over the same height.
class _Collapsible extends HookWidget {
  const _Collapsible({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final controller = useAnimationController(
      duration: AppDurations.medium,
      initialValue: expanded ? 1 : 0,
    );
    useEffect(() {
      if (reduceMotion) {
        controller.value = expanded ? 1 : 0;
      } else if (expanded) {
        controller.forward();
      } else {
        controller.reverse();
      }
      return null;
    }, [expanded, reduceMotion]);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isDismissed) {
          return const SizedBox(width: double.infinity);
        }
        final t = AppCurves.entrance.transform(controller.value);
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: Opacity(
              opacity: Curves.easeOut.transform(controller.value),
              // Not an AnimatedSize with a zero duration under reduced
              // motion: its controller then finishes inside its own layout
              // pass, which the framework asserts against.
              child: reduceMotion
                  ? child
                  : AnimatedSize(
                      duration: AppDurations.medium,
                      curve: AppCurves.entrance,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.section,
    required this.style,
    required this.gears,
  });

  final SetupSection section;
  final RowStyle style;
  final GearGraph? gears;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final singles = section.singles;
    final groups = section.wheelGroups;
    final showGears = section.id == SetupSectionId.gearing && gears != null;
    final both = singles.isNotEmpty && groups.isNotEmpty;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: muted,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Two columns of rows only where each keeps a readable name beside a
        // value, a track and the marks; below that, one column.
        final rowColumns = width >= 900 ? 2 : 1;
        final groupColumns = width >= 900 ? 3 : (width >= 600 ? 2 : 1);

        double share(int columns, double gap) =>
            (width - gap * (columns - 1)) / columns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showGears) ...[
              GearPanel(graph: gears!),
              if (singles.isNotEmpty || groups.isNotEmpty)
                const SizedBox(height: 18),
            ],
            if (singles.isNotEmpty) ...[
              if (both) heading('Whole car'),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  for (final setting in singles)
                    SizedBox(
                      key: ValueKey(setting.key),
                      width: share(rowColumns, 8),
                      child: SettingRow(setting: setting, style: style),
                    ),
                ],
              ),
            ],
            if (both) const SizedBox(height: 16),
            if (groups.isNotEmpty) ...[
              if (both) heading('Per wheel'),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final group in groups)
                    SizedBox(
                      key: ValueKey('WM_${group.id}'),
                      width: share(groupColumns, _gap),
                      child: WheelGroupCard(group: group, style: style),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
