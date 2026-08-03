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

/// One entry per feature in SPEC.md §8 (Session Overview/§8.2 has no route
/// of its own yet — it's reached from a session in the library, Phase 1).
const appNavDestinations = [
  NavDestinationSpec(
    path: '/sessions',
    label: 'Sessions',
    icon: Icons.folder_open_outlined,
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
        children: [
          _SideNav(selectedIndex: selectedIndex),
          const VerticalDivider(width: 1),
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
      child: ColoredBox(
        color: scheme.surfaceContainerLow,
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
                        child: Container(
                          height: 48,
                          decoration: ShapeDecoration(
                            shape: AppRadii.squircle(AppRadii.md),
                            color: selected
                                ? scheme.primaryContainer
                                : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            destination.icon,
                            color: selected
                                ? scheme.onPrimaryContainer
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

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, AppColors.wineDeep],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'P',
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
