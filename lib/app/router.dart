import 'package:go_router/go_router.dart';

import '../features/car_behavior/presentation/car_behavior_screen.dart';
import '../features/driver_comparison/presentation/driver_comparison_screen.dart';
import '../features/driving_technique/presentation/driving_technique_screen.dart';
import '../features/events_log/presentation/events_log_screen.dart';
import '../features/fuel_energy_strategy/presentation/fuel_energy_strategy_screen.dart';
import '../features/lap_analysis/presentation/lap_analysis_screen.dart';
import '../features/race_pace/presentation/race_pace_screen.dart';
import '../features/session_library/presentation/session_library_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/setup_viewer/presentation/setup_viewer_screen.dart';
import '../features/telemetry_trace/presentation/telemetry_trace_screen.dart';
import '../features/tires_brakes/presentation/tires_brakes_screen.dart';
import '../features/track_map/presentation/track_map_screen.dart';
import '../widgets/design_system/page_transitions.dart';
import 'app_shell.dart';

/// Routing skeleton (SPEC.md §9.4, §9.7.4) — every route shares the
/// [AppShell] chrome and the shared [appPage] transition. Session Overview
/// (§8.2) isn't routed standalone yet; Phase 1 reaches it from a session
/// selected in the library rather than via the side nav.
final appRouter = GoRouter(
  initialLocation: '/sessions',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/sessions',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const SessionLibraryScreen()),
        ),
        GoRoute(
          path: '/laps',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const LapAnalysisScreen()),
        ),
        GoRoute(
          path: '/trace',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const TelemetryTraceScreen()),
        ),
        GoRoute(
          path: '/track-map',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const TrackMapScreen()),
        ),
        GoRoute(
          path: '/tires-brakes',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const TiresBrakesScreen()),
        ),
        GoRoute(
          path: '/fuel-energy',
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: const FuelEnergyStrategyScreen(),
          ),
        ),
        GoRoute(
          path: '/driver-comparison',
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: const DriverComparisonScreen(),
          ),
        ),
        GoRoute(
          path: '/race-pace',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const RacePaceScreen()),
        ),
        GoRoute(
          path: '/setup',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const SetupViewerScreen()),
        ),
        GoRoute(
          path: '/events',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const EventsLogScreen()),
        ),
        GoRoute(
          path: '/driving-technique',
          pageBuilder: (context, state) => appPage(
            key: state.pageKey,
            child: const DrivingTechniqueScreen(),
          ),
        ),
        GoRoute(
          path: '/car-behavior',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const CarBehaviorScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              appPage(key: state.pageKey, child: const SettingsScreen()),
        ),
      ],
    ),
  ],
);
