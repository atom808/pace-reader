import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../widgets/design_system/design_system.dart';
import 'session_switcher.dart';
import 'shell_actions.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.path,
    required this.label,
    required this.icon,
    this.ready = true,
  });

  final String path;
  final String label;
  final IconData icon;

  /// False while the destination's screen is still a
  /// `FeaturePlaceholderScreen`. The rail dims such a slot and says so in its
  /// tooltip ("— coming soon"), so a click that lands on a placeholder is one
  /// the user was warned about rather than one that looks like a broken link.
  ///
  /// Hand-maintained, which is how it goes stale the day a screen is built and
  /// nobody flips the flag: `test/app/app_shell_test.dart` therefore asserts
  /// that every destination marked *not* ready really is a placeholder, so the
  /// build that replaces a placeholder fails until this is set back to true.
  final bool ready;
}

/// One entry per feature in SPEC.md §8.
const appNavDestinations = [
  NavDestinationSpec(
    path: '/sessions',
    label: 'Sessions',
    icon: Icons.folder_open_outlined,
  ),
  NavDestinationSpec(
    path: '/overview',
    label: 'Overview',
    icon: Icons.dashboard_outlined,
  ),
  NavDestinationSpec(path: '/laps', label: 'Laps', icon: Icons.timer_outlined),
  NavDestinationSpec(path: '/trace', label: 'Trace', icon: Icons.show_chart),
  NavDestinationSpec(
    path: '/track-map',
    label: 'Track map',
    icon: Icons.map_outlined,
  ),
  NavDestinationSpec(
    path: '/tires-brakes',
    label: 'Tires & brakes',
    icon: Icons.donut_large_outlined,
  ),
  NavDestinationSpec(
    path: '/fuel-energy',
    label: 'Fuel & energy',
    icon: Icons.local_gas_station_outlined,
  ),
  NavDestinationSpec(
    path: '/driver-comparison',
    label: 'Compare',
    icon: Icons.compare_arrows_outlined,
  ),
  NavDestinationSpec(
    path: '/race-pace',
    label: 'Race pace',
    icon: Icons.speed_outlined,
  ),
  NavDestinationSpec(
    path: '/setup',
    label: 'Setup',
    icon: Icons.build_outlined,
  ),
  NavDestinationSpec(
    path: '/events',
    label: 'Events',
    icon: Icons.list_alt_outlined,
  ),
  NavDestinationSpec(
    path: '/driving-technique',
    label: 'Technique',
    icon: Icons.insights_outlined,
  ),
  NavDestinationSpec(
    path: '/car-behavior',
    label: 'Car behavior',
    icon: Icons.directions_car_outlined,
    ready: false,
  ),
  NavDestinationSpec(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    ready: false,
  ),
];

/// Persistent desktop-class shell (SPEC.md §9.7: "lean into desktop-class
/// layout... rather than a phone-first responsive design") — a compact
/// icon rail built from our own squircle/hover primitives rather than the
/// stock [NavigationRail], since 13 destinations don't fit its label
/// layout cleanly.
///
/// The shell also owns the app-wide keyboard layer (§10): Cmd/Ctrl+O opens a
/// file and Cmd/Ctrl+1…9 jump to the first nine destinations. It lives here,
/// above every screen, rather than on each screen for the same reason the
/// rail does — it is chrome, and a shortcut that worked on six screens and not
/// on the seventh would be worse than none.
class AppShell extends HookConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = appNavDestinations.indexWhere(
      (d) => location.startsWith(d.path),
    );
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _indexForLocation(context);
    // Marks the rail's place in the focus tree without being a stop itself, so
    // its stops can be asked for by region (see the Tab actions below).
    final rail = useFocusNode(
      debugLabel: 'AppShell rail',
      canRequestFocus: false,
      skipTraversal: true,
    );
    return Shortcuts(
      shortcuts: shellShortcuts(defaultTargetPlatform),
      child: Actions(
        actions: {
          OpenFileIntent: CallbackAction<OpenFileIntent>(
            onInvoke: (_) => openFileFromShell(context, ref),
          ),
          GoToDestinationIntent: CallbackAction<GoToDestinationIntent>(
            onInvoke: (intent) {
              if (intent.index < appNavDestinations.length) {
                context.go(appNavDestinations[intent.index].path);
              }
              return null;
            },
          ),
          // Tab and Shift+Tab, as the framework does them, plus one case it
          // leaves dead: a page with nothing focusable on it. Focus starts in
          // the page's route scope, and Tab from a scope with no stops is a
          // no-op — it does not fall through to the rail — so on the Overview
          // (whose page has no controls) the rail was unreachable from the
          // keyboard except by the digit shortcuts. When the ordinary move has
          // nowhere to go, Tab goes to the rail's first stop and Shift+Tab to
          // its last.
          NextFocusIntent: CallbackAction<NextFocusIntent>(
            onInvoke: (_) =>
                (FocusManager.instance.primaryFocus?.nextFocus() ?? false) ||
                _focusRailEdge(rail, first: true),
          ),
          PreviousFocusIntent: CallbackAction<PreviousFocusIntent>(
            onInvoke: (_) =>
                (FocusManager.instance.primaryFocus?.previousFocus() ??
                    false) ||
                _focusRailEdge(rail, first: false),
          ),
        },
        // The pages are routes, and a route's focus scope is what holds
        // keyboard focus when nothing inside it has claimed it — so a key
        // press always starts at a node *below* the Shortcuts above, and the
        // table works from the first frame without the user having clicked
        // anything. (A scope of this widget's own would only add a second
        // thing for a page's autofocus to compete with.)
        //
        // The same scopes decide the Tab order, and it is not the rail's to
        // decide: focus starts inside the page's scope, so Tab walks the page
        // first and only then leaves for the rail, which is one contiguous run
        // — fourteen slots, then the session switcher. Measured, not assumed:
        // a `FocusTraversalGroup` per side, and an `OrderedTraversalPolicy`
        // over both, changed nothing here, because the page's controls are in
        // a nested scope that the shell's groups never see.
        child: Scaffold(
          body: Row(
            // Stretched rather than centred so the rail's edge is given the
            // full height to run down; a loose cross-axis constraint would
            // collapse a 1px-wide child to nothing.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Focus(
                focusNode: rail,
                includeSemantics: false,
                child: _SideNav(selectedIndex: selectedIndex),
              ),
              const _RailEdge(),
              Expanded(
                // A semantics boundary of its own around the page. Every page
                // is a route, and a route's modal barrier blocks the semantics
                // of whatever was painted before it in the same parent —
                // which, with the rail painted first and no boundary between
                // them, was the rail: measured with `debugDumpSemanticsTree`,
                // none of the fourteen slots (nor the app mark) reached the
                // semantics tree at all, so no label given to them could ever
                // have been read out.
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Focuses the first or last stop in the rail, and says whether there was one.
///
/// "First" and "last" are the top-most and bottom-most on screen, not the first
/// and last the focus tree lists. `traversalDescendants` is in the order the
/// nodes *attached*, and the rail's are not attached in the order they are
/// drawn: the destinations sit in a lazily built list, which builds during
/// layout, after the switcher pinned beneath it has already attached. Measured
/// on the Overview (no controls on the page): asking the tree for its first stop
/// returned the switcher, so Tab went switcher → page → switcher and the
/// fourteen slots could not be reached from the keyboard at all.
bool _focusRailEdge(FocusNode rail, {required bool first}) {
  final stops = rail.traversalDescendants.toList();
  if (stops.isEmpty) return false;
  stops.sort((a, b) {
    final byTop = a.rect.top.compareTo(b.rect.top);
    return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
  });
  (first ? stops.first : stops.last).requestFocus();
  return true;
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    return SizedBox(
      width: 84,
      child: DecoratedBox(
        // The rail is the one full-height surface in the app, which makes it
        // the only place a background gradient has room to be a gradient
        // rather than a band (§9.7.1). The content area beside it stays flat:
        // a wash behind a trace would make the same pixel value read as two
        // different ones at the top and bottom of a panel.
        decoration: const BoxDecoration(gradient: AppGradients.rail),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const _AppMark(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: appNavDestinations.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 14,
                    ),
                    child: _NavSlot(
                      destination: appNavDestinations[index],
                      selected: index == selectedIndex,
                      // Only the first nine have a key to press.
                      shortcut: index < shellDigitShortcutCount
                          ? shortcutLabel('${index + 1}', platform)
                          : null,
                    ),
                  );
                },
              ),
            ),
            // Pinned below the scrolling list, not part of it: which session
            // is on screen should not scroll away with the destinations.
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 16),
              child: SessionSwitcher(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSlot extends StatelessWidget {
  const _NavSlot({
    required this.destination,
    required this.selected,
    required this.shortcut,
  });

  final NavDestinationSpec destination;
  final bool selected;
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = destination.ready;

    // The tooltip carries what an icon cannot: the name, that the screen is
    // not built yet, and the key that gets there.
    final tooltip = [
      ready ? destination.label : '${destination.label} — coming soon',
      if (shortcut != null) '($shortcut)',
    ].join('  ');

    final iconColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    // The tooltip goes outermost, so that the node it brings (see AppTooltip)
    // is the slot's own — selected, named and tappable in one — rather than an
    // empty one inside it.
    return AppTooltip(
      message: tooltip,
      // The Hoverable's own semantics already name the slot; the tooltip's
      // would read the same words a second time.
      excludeFromSemantics: true,
      child: Semantics(
        selected: selected,
        child: Hoverable(
          radius: AppRadii.md,
          semanticLabel: ready
              ? destination.label
              : '${destination.label}, coming soon',
          onTap: () => context.go(destination.path),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppDurations.fast),
            curve: AppCurves.standard,
            height: 48,
            // Selection is the wine→iris fill plus the lit edge; everything
            // else is the shape with nothing in it. One selected slot in a
            // column of fourteen is exactly the job the brand gradient exists
            // for.
            decoration: ShapeDecoration(
              shape: selected
                  ? const GradientSquircleBorder(
                      radius: AppRadii.md,
                      gradient: AppGradients.hairlineStrong,
                    )
                  : AppRadii.squircle(AppRadii.md),
              gradient: selected ? AppGradients.brandMuted : null,
            ),
            alignment: Alignment.center,
            // Dimmed rather than disabled: the destination still opens (a
            // placeholder that says what is coming beats a dead click), it
            // just does not look as finished as its neighbours. The fill and
            // edge of a *selected* slot stay at full strength so the user can
            // always see where they are.
            child: Icon(
              destination.icon,
              color: ready ? iconColor : iconColor.withValues(alpha: 0.42),
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the stock [VerticalDivider] between the rail and the content:
/// same one-pixel job, drawn in the same light as every other edge.
class _RailEdge extends StatelessWidget {
  const _RailEdge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppGradients.railEdge),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    // Read out as the app's name, not as the letter it is drawn with.
    return Semantics(
      label: 'Pace Reader',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: 40,
        height: 40,
        decoration: const ShapeDecoration(
          shape: GradientSquircleBorder(
            radius: AppRadii.sm,
            gradient: AppGradients.hairlineStrong,
          ),
          // The mark is where the two-accent palette is stated outright —
          // every other gradient in the app is a quieter version of this one.
          gradient: AppGradients.brand,
        ),
        alignment: Alignment.center,
        child: const Text(
          'P',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
