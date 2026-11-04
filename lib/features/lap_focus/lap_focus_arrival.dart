import 'dart:async';

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

/// A part of a destination a focus asked to be scrolled to, by the id its
/// [LapFocusReveal] carries; null once it has been.
final lapFocusRevealProvider =
    NotifierProvider<LapFocusRevealNotifier, String?>(
      LapFocusRevealNotifier.new,
    );

/// How long a reveal waits for its panel to be built: one a lazy list has
/// not laid out by then is left alone, rather than jumping into view
/// whenever the user later scrolls near it.
const revealPatience = Duration(seconds: 2);

class LapFocusRevealNotifier extends Notifier<String?> {
  Timer? _expiry;

  @override
  String? build() {
    ref.onDispose(() => _expiry?.cancel());
    return null;
  }

  /// Scrolls the [LapFocusReveal] with [id] into view, once, if it is built
  /// within [revealPatience].
  void reveal(String id) {
    state = id;
    _expiry?.cancel();
    _expiry = Timer(revealPatience, done);
  }

  void done() => state = null;
}

/// [child], scrolled into view when a focus asks for [id] (§6.4: Dynamics
/// lands on Technique's G-G panel, Energy on Fuel & Energy's lap table),
/// then lit once so the eye finds it.
class LapFocusReveal extends ConsumerStatefulWidget {
  const LapFocusReveal({
    super.key,
    required this.id,
    required this.child,
    this.alignment = 0.1,
  });

  final String id;

  /// Where in the viewport it comes to rest, 0 the top: lower on a screen
  /// whose header floats over its list.
  final double alignment;
  final Widget child;

  @override
  ConsumerState<LapFocusReveal> createState() => _LapFocusRevealState();
}

class _LapFocusRevealState extends ConsumerState<LapFocusReveal> {
  bool _lit = false;

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(lapFocusRevealProvider.notifier).done();
      await Scrollable.ensureVisible(
        context,
        alignment: widget.alignment,
        duration: AppMotion.duration(context, AppDurations.slow),
        curve: AppCurves.standard,
      );
      if (!mounted) return;
      setState(() => _lit = true);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _lit = false);
    });
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(lapFocusRevealProvider) == widget.id) _reveal();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lapFocusRevealProvider, (_, next) {
      if (next == widget.id) _reveal();
    });
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppDurations.slow),
      curve: AppCurves.standard,
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.md).copyWith(
          side: BorderSide(
            color: _lit ? scheme.primary : scheme.primary.withValues(alpha: 0),
            width: 2,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
