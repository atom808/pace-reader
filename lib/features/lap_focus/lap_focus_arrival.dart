import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/duckdb/telemetry_database.dart';
import 'lap_focus.dart';

/// Where a destination lands a focus another screen sent it (map stage
/// proposal §6.4): once [ready] — its own data read — and showing the lap
/// the focus names, it takes the focus and hands it to [onArrival], once.
///
/// After the frame, so whatever the destination sets in its first frame (a
/// sync owner's claim, a default selection) is already in place and is not
/// what overwrites the focus.
class LapFocusArrival extends ConsumerStatefulWidget {
  const LapFocusArrival({
    super.key,
    required this.target,
    required this.source,
    required this.lap,
    required this.onArrival,
    required this.child,
    this.ready = true,
  });

  final LapFocusTarget target;
  final TelemetrySource source;

  /// `Lap.index` on screen.
  final int lap;
  final bool ready;
  final void Function(LapFocus focus) onArrival;
  final Widget child;

  @override
  ConsumerState<LapFocusArrival> createState() => _LapFocusArrivalState();
}

class _LapFocusArrivalState extends ConsumerState<LapFocusArrival> {
  @override
  void initState() {
    super.initState();
    _landAfterFrame();
  }

  @override
  void didUpdateWidget(LapFocusArrival old) {
    super.didUpdateWidget(old);
    if (old.lap != widget.lap ||
        old.source != widget.source ||
        old.ready != widget.ready) {
      _landAfterFrame();
    }
  }

  void _landAfterFrame() {
    if (!widget.ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.ready) return;
      final focus = ref
          .read(pendingLapFocusProvider.notifier)
          .take(widget.target.route, widget.source, widget.lap);
      if (focus != null) widget.onArrival(focus);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
