/// The shared cursor and viewport every synced chart subscribes to
/// (SPEC.md §9.5, §9.7.6).
///
/// §9.7.6 names this a reusable *behaviour* rather than a rendering concern,
/// and it is written that way: this controller knows about an axis, a window
/// and a cursor, and nothing about telemetry, laps, or which providers supply
/// them. The feature screens own the data; this owns what the panels agree on
/// while looking at it.
///
/// ## Why the extent is not stored here
///
/// A viewport needs bounds to be clamped against, and those bounds come from
/// the lap currently loaded — which is data. Storing them here would mean
/// writing to this controller during a widget build every time the data
/// resolved, the classic way a Riverpod graph starts looping. Instead every
/// operation takes the bounds as an argument at the moment of the gesture,
/// and a null [ChartSyncState.viewport] means "the whole lap". Nothing has to
/// be pushed in when data arrives, so nothing can be pushed in at the wrong
/// time.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../decimation.dart';
import '../viewport.dart';

part 'chart_sync.g.dart';

/// What the synced panels and the track map agree on.
class ChartSyncState {
  const ChartSyncState({
    this.axis = TraceAxis.distance,
    this.viewport,
    this.cursor,
    this.owner,
  });

  /// Distance or time (§8.4). Distance by default: it is the axis that makes
  /// two laps comparable, which is what a trace view is for.
  final TraceAxis axis;

  /// Visible window in the current axis's units, or null for the full extent.
  final ChartViewport? viewport;

  /// Scrub position in the current axis's units, or null when the pointer is
  /// away from every panel.
  final double? cursor;

  /// Whose positions [viewport] and [cursor] are: the lap, or the
  /// comparison, the screen that last [ChartSync.claim]ed them is showing.
  ///
  /// The cursor and window are numbers on one lap's axis. With one session
  /// open, every synced screen showed the same lap and nobody needed to ask;
  /// with Compare, Trace can show one lap while Compare's Base is another, and
  /// a window of 700–1160 m on one is meaningless on the other's clock.
  final Object? owner;

  bool get isZoomed => viewport != null;

  /// The window to draw, given the extent the data actually covers.
  ChartViewport visible(ChartViewport bounds) =>
      viewport?.slidInside(bounds) ?? bounds;

  /// This state as a widget belonging to [viewer] should see it: unchanged
  /// when [viewer] owns it — or names no owner, as a widget outside any
  /// `SyncOwner` does — and otherwise the axis alone, with no window and no
  /// cursor, because those are positions on someone else's lap.
  ChartSyncState seenBy(Object? viewer) => viewer == null || viewer == owner
      ? this
      : ChartSyncState(axis: axis, owner: owner);

  ChartSyncState copyWith({
    TraceAxis? axis,
    ChartViewport? viewport,
    double? cursor,
    bool clearViewport = false,
    bool clearCursor = false,
  }) => ChartSyncState(
    axis: axis ?? this.axis,
    viewport: clearViewport ? null : (viewport ?? this.viewport),
    cursor: clearCursor ? null : (cursor ?? this.cursor),
    owner: owner,
  );
}

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different cursors,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one cursor moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
///
/// What Phase 3 does need is to know whose lap the cursor is on, so each
/// screen [claim]s the controller for what it shows (see `SyncOwner`), and a
/// screen that does not own it draws neither the cursor nor the window.
@Riverpod(keepAlive: true)
class ChartSync extends _$ChartSync {
  @override
  ChartSyncState build() => const ChartSyncState();

  /// Takes the cursor and viewport for [owner].
  ///
  /// A new owner starts from the whole lap with no cursor, keeping only the
  /// axis choice, because the old ones are positions on another lap. A claim
  /// by the current owner changes nothing, so Trace and the track map —
  /// which show the same lap and claim the same owner — keep the zoom and
  /// cursor across a navigation between them, as they always have.
  void claim(Object owner) {
    if (state.owner == owner) return;
    state = ChartSyncState(axis: state.axis, owner: owner);
  }

  /// Shows [window] — Compare's "zoom to this segment" (comparison proposal
  /// §5), where the window comes from data rather than from a gesture.
  ///
  /// Kept inside [bounds] the way every gesture is: a window that overhangs
  /// an edge slides back in, and one as wide as the lap or wider is simply
  /// the whole lap, which is the absence of a viewport.
  void showWindow(ChartViewport window, {required ChartViewport bounds}) {
    final next = window.slidInside(bounds);
    state = next == bounds
        ? state.copyWith(clearViewport: true)
        : state.copyWith(viewport: next);
  }

  /// Moves the scrub cursor. Null when the pointer leaves every panel.
  void setCursor(double? domain) {
    if (domain == null) {
      if (state.cursor == null) return;
      state = state.copyWith(clearCursor: true);
      return;
    }
    if (state.cursor == domain) return;
    state = state.copyWith(cursor: domain);
  }

  /// Switches axis, carrying the cursor and any zoom across.
  ///
  /// Conversion runs through [distanceAxis] rather than by rescaling
  /// proportionally: the car spends far longer in a corner than on a straight,
  /// so the same fraction of a lap's time and of its distance are different
  /// points on the circuit. Rescaling would move the cursor off whatever the
  /// user was looking at, in exactly the corners they were looking at it.
  ///
  /// Falls back to a clean reset when no usable distance axis exists (§5.2's
  /// garage lap), because there is then no correct conversion to make.
  void setAxis(TraceAxis next, {DistanceAxis? distanceAxis}) {
    if (next == state.axis) return;
    if (distanceAxis == null || !distanceAxis.isUsable) {
      state = ChartSyncState(axis: next, owner: state.owner);
      return;
    }

    double convert(double value) => next == TraceAxis.distance
        ? distanceAxis.distanceAt(value)
        : distanceAxis.timeAt(value);

    final window = state.viewport;
    state = ChartSyncState(
      axis: next,
      viewport: window == null
          ? null
          : _orderedViewport(convert(window.start), convert(window.end)),
      cursor: state.cursor == null ? null : convert(state.cursor!),
      owner: state.owner,
    );
  }

  /// Zooms about [focus] — the domain value under the pointer, which stays
  /// under it.
  void zoomAround(double focus, double factor, {required ChartViewport bounds}) {
    final current = state.visible(bounds);
    final next = current.zoomedAround(focus, factor, bounds: bounds);
    state = next == bounds
        ? state.copyWith(clearViewport: true)
        : state.copyWith(viewport: next);
  }

  void panBy(double delta, {required ChartViewport bounds}) {
    if (!state.isZoomed || delta == 0) return;
    state = state.copyWith(
      viewport: state.visible(bounds).pannedBy(delta, bounds: bounds),
    );
  }

  /// Back to the whole lap, cursor kept — zooming out is a framing change,
  /// not a change of what the user is inspecting.
  void resetViewport() {
    if (!state.isZoomed) return;
    state = state.copyWith(clearViewport: true);
  }

  /// Clears everything but the axis choice and the owner, for a change of
  /// data under the same owner. A change of lap or session is a new owner,
  /// and [claim] clears for it.
  void resetForNewData() {
    state = ChartSyncState(axis: state.axis, owner: state.owner);
  }

  /// A converted window can come back reversed if the distance axis is
  /// descending; ordering it keeps [ChartViewport]'s non-empty invariant.
  static ChartViewport _orderedViewport(double a, double b) =>
      a < b ? ChartViewport(a, b) : ChartViewport(b, a == b ? a + 1 : a);
}
