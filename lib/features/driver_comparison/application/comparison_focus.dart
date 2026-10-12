/// Which stretch of the lap Compare is looking at (comparison proposal §5
/// "Opening behaviour", §9 `comparison_focus.dart`).
///
/// Separate from the chart and the losses: changing the order or the
/// selected segment re-derives nothing and never shows a loading state.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/comparison_set.dart';
import '../domain/segment_losses.dart';

part 'comparison_focus.g.dart';

class SegmentFocusState {
  const SegmentFocusState({
    this.mode = SegmentMode.segments,
    this.order = SegmentOrder.mostLost,
    this.set,
    this.selected,
    this.zoomed = false,
  });

  /// Segments or the game's sectors; kept for the run, across pairs.
  final SegmentMode mode;

  /// The order → walks in; kept for the run, across pairs.
  final SegmentOrder order;

  /// The pair [selected] and [zoomed] belong to. Another pair starts over:
  /// the worst stretch selected, the whole lap shown.
  final ComparisonSet? set;

  /// The chosen stop, or null for the opening choice — the worst stretch.
  final WalkStop? selected;

  /// Whether the stack is zoomed onto [selected] (Enter, or a click), so
  /// stepping to the next stop moves the zoom with it.
  final bool zoomed;

  /// The selection as [set] sees it: its own, or the opening one.
  SegmentFocusState forSet(ComparisonSet set) => this.set == set
      ? this
      : SegmentFocusState(mode: mode, order: order, set: set);

  /// [comparison]'s selected stop: the chosen one, or else the worst
  /// stretch — null when Base loses nowhere.
  WalkStop? stopIn(StretchComparison comparison) {
    final chosen = selected;
    if (chosen != null) {
      if (chosen.recap) return chosen;
      final stretch = comparison.byNumber(chosen.number!);
      if (stretch != null) return WalkStop(stretch);
    }
    final worst = comparison.worst;
    return worst == null ? null : WalkStop(worst);
  }
}

@Riverpod(keepAlive: true)
class SegmentFocus extends _$SegmentFocus {
  @override
  SegmentFocusState build() => const SegmentFocusState();

  void setMode(SegmentMode mode) =>
      state = SegmentFocusState(mode: mode, order: state.order);

  void setOrder(SegmentOrder order) => state = SegmentFocusState(
    mode: state.mode,
    order: order,
    set: state.set,
    selected: state.selected,
    zoomed: state.zoomed,
  );

  void select(ComparisonSet set, WalkStop stop, {bool? zoomed}) =>
      state = SegmentFocusState(
        mode: state.mode,
        order: state.order,
        set: set,
        selected: stop,
        zoomed: zoomed ?? state.forSet(set).zoomed,
      );

  void setZoomed(ComparisonSet set, bool zoomed) {
    final current = state.forSet(set);
    state = SegmentFocusState(
      mode: current.mode,
      order: current.order,
      set: set,
      selected: current.selected,
      zoomed: zoomed,
    );
  }
}

/// The stop after (or, with [forward] false, before) [current] in [walk].
///
/// A stop not on the walk — a gain selected while walking "Most lost" —
/// steps to the walk's first stop. The ends hold: past the recap there is
/// nothing, and before the first stop there is nothing either.
WalkStop stepAlong(
  List<WalkStop> walk,
  WalkStop? current, {
  required bool forward,
}) {
  final at = current == null ? -1 : walk.indexOf(current);
  if (at < 0) return walk.first;
  final next = forward ? at + 1 : at - 1;
  return walk[next.clamp(0, walk.length - 1)];
}
