import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/duckdb/telemetry_database.dart';
import '../../widgets/design_system/design_system.dart';
import 'lap_focus.dart';

/// Where a destination lands a focus another screen sent it (map stage
/// proposal §6.4): once [ready] — its own data read — and showing the lap
/// the focus names, it takes the focus and hands it to [onArrival], once.
///
/// After the frame, so whatever the destination sets in its first frame (a
/// sync owner's claim, a default selection) is already in place and is not
/// what overwrites the focus.
///
/// A focus that carries [LapFocus.back] — a step aside from the stage — puts
/// a "Back to" notice at the top of the destination until it is used or
/// closed.
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
  LapFocusReturn? _back;

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
      if (focus == null) return;
      widget.onArrival(focus);
      setState(() => _back = focus.back);
    });
  }

  void _goBack(LapFocusReturn back) {
    setState(() => _back = null);
    openFocus(context, ref, back.target, back.focus);
  }

  @override
  Widget build(BuildContext context) {
    final back = _back;
    // Always the stack, so the screen under it keeps its state when the
    // notice comes and goes.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Align(
            alignment: Alignment.topCenter,
            child: GlassNoticeSlot(
              notice: back == null
                  ? null
                  : GlassNotice(
                      key: ValueKey(back),
                      icon: Icons.arrow_back,
                      message: 'Back to ${back.label}',
                      onTap: () => _goBack(back),
                      onDismiss: () => setState(() => _back = null),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
