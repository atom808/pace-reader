/// What Compare's controls do to the workspace and to Open now (comparison
/// proposal §3, §9).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../session_library/application/open_sessions.dart';
import '../../session_library/application/session_import.dart';
import '../application/comparison_workspace.dart';
import '../domain/comparison_set.dart';

/// Makes [lap] the [role] lap of the comparison whose Base is [base].
///
/// A lap in a file that is not open opens the file first — *behind* the
/// current session (`SessionImport.open(makeCurrent: false)`), so the file
/// has Open now as its one owner and every other screen keeps showing what
/// it showed. Returns false, after saying why, when the file would not open.
///
/// Opening the file rebuilds the lists the caller sits in, so the calling
/// widget is often gone by the time it finishes: everything after the open
/// goes through the [ProviderContainer], looked up from [context] before it.
Future<bool> chooseCompareLap(
  BuildContext context, {
  required ComparisonRole role,
  required LapRef base,
  required LapRef lap,
}) async {
  final container = ProviderScope.containerOf(context, listen: false);
  if (!container.read(openSessionsProvider).contains(lap.source)) {
    final opened = await _openBehind(context, container, lap.source);
    if (!opened) return false;
  }
  final workspace = container.read(comparisonWorkspaceProvider.notifier);
  switch (role) {
    case ComparisonRole.base:
      final current = container.read(comparisonWorkspaceProvider);
      if (current == null) {
        workspace.start(lap);
      } else {
        workspace.setBase(lap);
      }
    case ComparisonRole.target:
      workspace.setTarget(base, lap);
  }
  return true;
}

/// Reopens a compared file that was closed, behind the current session.
Future<void> reopenCompareFile(BuildContext context, TelemetrySource source) =>
    _openBehind(
      context,
      ProviderScope.containerOf(context, listen: false),
      source,
    );

/// Opens [source] behind the current session; false, after a snackbar
/// saying why, when it would not open. Nothing after the await touches
/// [context], whose widget the open may have unmounted.
Future<bool> _openBehind(
  BuildContext context,
  ProviderContainer container,
  TelemetrySource source,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final import = container.read(sessionImportProvider.notifier);
  await import.open(source, makeCurrent: false);
  final outcome = container.read(sessionImportProvider);
  if (outcome is! SessionImportFailure) return true;
  import.dismissError();
  if (messenger != null && messenger.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }
  return false;
}

/// Clears [lap]'s place in the comparison and closes its file — offered only
/// when nothing else uses the file: not the other lap, not the current
/// session.
Future<void> clearAndCloseCompareFile(
  WidgetRef ref, {
  required ComparisonSet set,
  required ComparisonRole role,
}) async {
  final workspace = ref.read(comparisonWorkspaceProvider.notifier);
  final lap = role == ComparisonRole.base ? set.base : set.target!;
  if (role == ComparisonRole.target) {
    workspace.setTarget(set.base, null);
  } else {
    final target = set.target;
    if (target == null) {
      workspace.clear();
    } else {
      workspace.start(target);
    }
  }
  await ref.read(openSessionsProvider.notifier).close(lap.source);
}

/// Whether the ⋯ menu may offer "Clear and close file" for [role]'s lap.
bool canCloseCompareFile(
  WidgetRef ref, {
  required ComparisonSet set,
  required ComparisonRole role,
}) {
  final lap = role == ComparisonRole.base ? set.base : set.target;
  if (lap == null) return false;
  final other = role == ComparisonRole.base ? set.target : set.base;
  return other?.source != lap.source &&
      ref.read(currentSessionProvider) != lap.source;
}
