/// Closing a file Compare is using asks first (comparison proposal §9, "File
/// ownership").
///
/// Derived from the workspace, so there is no second registry of who uses a
/// file to drift out of step with it: the set names its files.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/comparison_workspace.dart';
import '../domain/comparison_set.dart';

/// Which lap of the chosen comparison [source] holds, Base first; null when
/// Compare is not using it.
ComparisonRole? compareRoleOf(ComparisonSet? set, TelemetrySource source) {
  if (set == null) return null;
  if (set.base.source == source) return ComparisonRole.base;
  if (set.target?.source == source) return ComparisonRole.target;
  return null;
}

/// Closes [source] from Open now, asking first when Compare uses it.
///
/// Closing the Target's file clears the Target, which the dialog says. Base
/// is not cleared: Compare shows that its file was closed and offers to
/// reopen it, or to make the Target the base — dropping the comparison
/// silently would lose the user's place.
Future<void> closeSessionChecked(
  BuildContext context,
  WidgetRef ref,
  TelemetrySource source,
) async {
  final set = ref.read(comparisonWorkspaceProvider);
  final role = compareRoleOf(set, source);
  if (role != null) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close the ${role.label}\'s file?'),
        content: Text(switch (role) {
          ComparisonRole.target =>
            'The Target uses this file. Closing it clears the Target.',
          ComparisonRole.base =>
            "Compare's Base uses this file. Closing it leaves Compare "
                'without a Base until the file is reopened.',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (role == ComparisonRole.target) {
      ref.read(comparisonWorkspaceProvider.notifier).clearTarget();
    }
  }
  await ref.read(openSessionsProvider.notifier).close(source);
}
