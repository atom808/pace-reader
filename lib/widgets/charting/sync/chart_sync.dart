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
  });

  /// Distance or time (§8.4). Distance by default: it is the axis that makes
  /// two laps comparable, which is what a trace view is for.
  final TraceAxis axis;

  /// Visible window in the current axis's units, or null for the full extent.
  final ChartViewport? viewport;

  /// Scrub position in the current axis's units, or null when the pointer is
  /// away from every panel.
  final double? cursor;

  bool get isZoomed => viewport != null;

  /// The window to draw, given the extent the data actually covers.
  ChartViewport visible(ChartViewport bounds) =>
      viewport?.slidInside(bounds) ?? bounds;

  ChartSyncState copyWith({
    TraceAxis? axis,
    ChartViewport? viewport,
    double? cursor,
    bool clearViewport = false,
    bool clearCursor = false,
  }) =>
      ChartSyncState(
        axis: axis ?? this.axis,
        viewport: clearViewport ? null : (viewport ?? this.viewport),
        cursor: clearCursor ? null : (cursor ?? this.cursor),
      );
}

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different cursors,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one cursor moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
@Riverpod(keepAlive: true)
class ChartSync extends _$ChartSync {
  @override
  ChartSyncState build() => const ChartSyncState();

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
      state = ChartSyncState(axis: next);
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

  /// Clears everything but the axis choice. Called when the selected lap or
  /// session changes, where a cursor from the previous lap would be a
  /// position on a lap no longer shown.
  void resetForNewData() {
    state = ChartSyncState(axis: state.axis);
  }

  /// A converted window can come back reversed if the distance axis is
  /// descending; ordering it keeps [ChartViewport]'s non-empty invariant.
  static ChartViewport _orderedViewport(double a, double b) =>
      a < b ? ChartViewport(a, b) : ChartViewport(b, a == b ? a + 1 : a);
}
