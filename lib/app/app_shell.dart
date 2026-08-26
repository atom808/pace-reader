import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/design_system/design_system.dart';

class NavDestinationSpec {
  const NavDestinationSpec({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
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
  NavDestinationSpec(
    path: '/laps',
    label: 'Laps',
    icon: Icons.timer_outlined,
  ),
  NavDestinationSpec(
    path: '/trace',
    label: 'Trace',
    icon: Icons.show_chart,
  ),
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
    label: 'Comparison',
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
  ),
  NavDestinationSpec(
    path: '/settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
  ),
];

/// Persistent desktop-class shell (SPEC.md §9.7: "lean into desktop-class
/// layout... rather than a phone-first responsive design") — a compact
/// icon rail built from our own squircle/hover primitives rather than the
/// stock [NavigationRail], since 13 destinations don't fit its label
/// layout cleanly.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = appNavDestinations.indexWhere((d) => location.startsWith(d.path));
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _indexForLocation(context);
    return Scaffold(
      body: Row(
        // Stretched rather than centred so the rail's edge is given the full
        // height to run down; a loose cross-axis constraint would collapse a
        // 1px-wide child to nothing.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SideNav(selectedIndex: selectedIndex),
          const _RailEdge(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  final destination = appNavDestinations[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
                    child: Hoverable(
                      onTap: () => context.go(destination.path),
                      child: Tooltip(
                        message: destination.label,
                        child: AnimatedContainer(
                          duration: AppDurations.fast,
                          curve: AppCurves.standard,
                          height: 48,
                          // Selection is the wine→iris fill plus the lit
                          // edge; everything else is the shape with nothing
                          // in it. One selected slot in a column of fourteen
                          // is exactly the job the brand gradient exists for.
                          decoration: ShapeDecoration(
                            shape: selected
                                ? const GradientSquircleBorder(
                                    radius: AppRadii.md,
                                    gradient: AppGradients.hairlineStrong,
                                  )
                                : AppRadii.squircle(AppRadii.md),
                            gradient:
                                selected ? AppGradients.brandMuted : null,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            destination.icon,
                            color: selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
    return Container(
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
    );
  }
}
