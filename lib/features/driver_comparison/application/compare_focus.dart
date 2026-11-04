/// Compare as a [LapFocusTarget] (map stage proposal §6.4): the lap as Base,
/// its reference as Target.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/repositories/lap_ref.dart';
import '../../lap_focus/lap_focus.dart';
import 'comparison_workspace.dart';

class CompareFocusTarget implements LapFocusTarget {
  const CompareFocusTarget();

  @override
  String get route => '/driver-comparison';

  @override
  String get label => 'Compare';

  @override
  IconData get icon => Icons.compare_arrows;

  @override
  void apply(WidgetRef ref, LapFocus focus) {
    final reference = focus.reference;
    ref
        .read(comparisonWorkspaceProvider.notifier)
        .start(
          LapRef(focus.source, focus.lap),
          reference == null ? null : LapRef(focus.source, reference),
        );
  }
}

const compareFocusTarget = CompareFocusTarget();
