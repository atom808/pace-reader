/// Trace's way into Compare (comparison proposal §4 Defaults, §9).
library;

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../application/comparison_workspace.dart';

/// Opens Compare on the lap Trace shows, with Trace's reference lap as the
/// Target: today's same-file comparison, from where it can move to another
/// file.
///
/// Disabled on a recording's first lap, which Compare never selects (§4 Lap
/// rules), and a first-lap reference is dropped rather than carried over.
class OpenInCompareButton extends ConsumerWidget {
  const OpenInCompareButton({
    super.key,
    required this.source,
    required this.displayed,
  });

  final TelemetrySource source;
  final Lap? displayed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laps = ref.watch(lapsProvider(source)).value ?? const <Lap>[];
    final displayed = this.displayed;
    final firstLap = displayed != null && isRecordingStart(laps, displayed);
    final reference = displayed == null
        ? null
        : comparedReferenceIndex(
            ref.watch(referenceLapIndexProvider(source)),
            displayed.index,
          );
    return AppTooltip(
      message: firstLap
          ? "A recording's first lap can't be compared: its Lap event is "
                'not where the lap starts.'
          : reference == null
          ? 'Compare this lap against a lap from any recording of this course'
          : 'Compare this lap against its reference, here or from any '
                'recording of this course',
      child: TextButton.icon(
        icon: const Icon(Icons.compare_arrows, size: 18),
        label: const Text('Open in Compare'),
        onPressed: displayed == null || firstLap
            ? null
            : () {
                final carried =
                    reference == null ||
                        (laps.isNotEmpty && laps.first.index == reference)
                    ? null
                    : LapRef(source, reference);
                ref
                    .read(comparisonWorkspaceProvider.notifier)
                    .start(LapRef(source, displayed.index), carried);
                context.go('/driver-comparison');
              },
      ),
    );
  }
}
