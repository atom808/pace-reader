/// What every dock tab beyond Inputs is made of (map stage proposal §6.1):
/// its panels in a list that arrives in a stagger, the four corners laid out
/// like the car, a quiet placeholder while the tab's channels are read, and
/// a line that says what is missing and why.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/stage_view.dart';

/// [children] down the dock, each arriving after the one above.
class DockTabList extends StatelessWidget {
  const DockTabList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 12),
        StaggeredEntrance(index: i, child: children[i]),
      ],
    ],
  );
}

/// The four corners, following the one the pointer last rested on.
class CornerPanelGrid extends ConsumerWidget {
  const CornerPanelGrid({super.key, required this.cell});

  final List<Widget> Function(Corner corner) cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CornerGrid(
      lit: ref.watch(cornerFocusProvider),
      onHover: ref.read(cornerFocusProvider.notifier).select,
      cell: (context, corner) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 2),
            child: Text(
              corner.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...cell(corner),
        ],
      ),
    );
  }
}

class DockTabLoading extends StatelessWidget {
  const DockTabLoading({super.key});

  // A list that never scrolls, not a column: the dock passes through every
  // height on its way open, and a placeholder has nothing to overflow for.
  @override
  Widget build(BuildContext context) => ListView(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
    children: const [
      Align(
        alignment: Alignment.centerLeft,
        child: Skeleton(height: 28, width: 220),
      ),
      SizedBox(height: 14),
      Skeleton(height: 150),
      SizedBox(height: 10),
      Skeleton(height: 150),
    ],
  );
}

/// [message], then which of the file's channels never moved this lap — so a
/// missing panel is said, not left as a gap (§5.4).
Widget dockTabNote(
  BuildContext context,
  String? message,
  Set<String> flat, {
  String? why,
}) {
  final theme = Theme.of(context);
  final names = flat.toList()..sort();
  return Text(
    [
      ?message,
      if (names.isNotEmpty)
        'Not drawn, as they never moved this lap: ${names.join(', ')}.',
      if (names.isNotEmpty) ?why,
    ].join(' '),
    style: theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
