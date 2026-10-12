/// Whose lap a synced subtree is showing (comparison proposal §9).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'chart_sync.dart';

/// Claims the shared [ChartSync] for [owner], and marks every synced widget
/// below as [owner]'s.
///
/// Trace and the track map own `LapRef(current session, displayed lap)`;
/// Compare owns its Base. One global controller stays right for all of them
/// (see [ChartSync]) as long as each screen says whose cursor it is drawing.
///
/// The claim runs on mount and again when [owner] changes — never on a
/// rebuild with the same owner — and after the frame, not during it. Writing
/// to a provider while widgets build is an error in Riverpod; and since a
/// route transition keeps the outgoing page mounted while it fades, a claim
/// on every rebuild would let the two pages take the cursor back and forth.
///
/// Until the claim lands, and whenever another screen holds the controller,
/// synced widgets below read the state through [ChartSyncState.seenBy] — the
/// whole lap, no cursor — and ignore the pointer, so no frame draws a window
/// on another lap's clock and no gesture writes one.
class SyncOwner extends ConsumerStatefulWidget {
  const SyncOwner({super.key, required this.owner, required this.child});

  final Object owner;
  final Widget child;

  /// The owner of the nearest enclosing [SyncOwner], or null outside one.
  static Object? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SyncOwnerScope>()?.owner;

  @override
  ConsumerState<SyncOwner> createState() => _SyncOwnerState();
}

class _SyncOwnerState extends ConsumerState<SyncOwner> {
  @override
  void initState() {
    super.initState();
    _claimAfterFrame();
  }

  @override
  void didUpdateWidget(SyncOwner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.owner != widget.owner) _claimAfterFrame();
  }

  void _claimAfterFrame() {
    final owner = widget.owner;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Superseded by a later owner, or a page that has gone: neither claims.
      if (!mounted || widget.owner != owner) return;
      ref.read(chartSyncProvider.notifier).claim(owner);
    });
  }

  @override
  Widget build(BuildContext context) =>
      _SyncOwnerScope(owner: widget.owner, child: widget.child);
}

class _SyncOwnerScope extends InheritedWidget {
  const _SyncOwnerScope({required this.owner, required super.child});

  final Object owner;

  @override
  bool updateShouldNotify(_SyncOwnerScope oldWidget) =>
      oldWidget.owner != owner;
}

/// The shared state as the synced widget at [context] should see it, and
/// whether that widget may write to it.
///
/// Outside any [SyncOwner] a widget sees and drives the state as it is, which
/// is how every synced widget behaved before owners existed.
({ChartSyncState state, bool owns}) watchChartSync(
  WidgetRef ref,
  BuildContext context,
) {
  final owner = SyncOwner.of(context);
  final state = ref.watch(chartSyncProvider);
  return (
    state: state.seenBy(owner),
    owns: owner == null || owner == state.owner,
  );
}
