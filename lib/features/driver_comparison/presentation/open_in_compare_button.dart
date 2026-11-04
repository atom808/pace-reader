/// Trace's way into Compare (comparison proposal §4 Defaults, §9).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../lap_focus/lap_focus.dart';
import '../../lap_focus/lap_focus_link.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../application/comparison_workspace.dart';
import '../application/compare_focus.dart';

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
    this.compact = false,
  });

  final TelemetrySource source;
  final Lap? displayed;

  /// The icon alone, for a narrow window's app bar.
  final bool compact;

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
    return LapFocusLink(
      target: compareFocusTarget,
      label: 'Open in Compare',
      compact: compact,
      tooltip: firstLap
          ? "A recording's first lap can't be compared: its Lap event is "
                'not where the lap starts.'
          : reference == null
          ? 'Compare this lap against a lap from any recording of this course'
          : 'Compare this lap against its reference, here or from any '
                'recording of this course',
      focus: displayed == null || firstLap
          ? null
          : LapFocus(
              source: source,
              lap: displayed.index,
              // A first-lap reference is dropped, not carried.
              reference: laps.isNotEmpty && laps.first.index == reference
                  ? null
                  : reference,
            ),
    );
  }
}
