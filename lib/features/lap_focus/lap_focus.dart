/// One way to say "look at this lap, here" from any screen to any other
/// (map stage proposal §6.4).
///
/// Before this, each screen wrote its own "Open in Trace": select the lap,
/// go to `/trace`, and the destination opened at the lap's start — the
/// segment or the site the user was looking at was lost on the way. A
/// [LapFocus] carries where, and a [LapFocusTarget] knows how one screen
/// shows it; [openFocus] is the one place the two meet.
///
/// Where a destination needs data to land (Technique's segments, Trace's
/// distance axis), the focus waits in [pendingLapFocusProvider] until the
/// destination has it, and the destination takes it once.
library;

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/duckdb/telemetry_database.dart';
import '../../data/models/models.dart';
import '../session_library/application/open_sessions.dart';

/// A lap, and optionally where on it, in the circuit's own terms.
///
/// Positions are `Lap Dist` metres, never an axis value: the sender may be on
/// Time and the receiver on Distance, and only metres mean the same point on
/// both.
@immutable
class LapFocus {
  const LapFocus({
    required this.source,
    required this.lap,
    this.reference,
    this.station,
    this.window,
    this.tab,
    this.corner,
    this.channel,
  });

  final TelemetrySource source;

  /// `Lap.index`.
  final int lap;

  /// The lap of [source] to compare against, as `Lap.index`; null for none.
  final int? reference;

  /// The point to put the playhead on, in `Lap Dist` metres.
  final double? station;

  /// The stretch to frame, in `Lap Dist` metres: a segment, a corner.
  final ({double start, double end})? window;

  /// The Trace dock tab to open on (`TraceTab.id`); null keeps the user's.
  final String? tab;

  /// The wheel the sender was looking at.
  final Corner? corner;

  /// The quantity the sender was looking at, as `Channels` names it: what a
  /// destination with a metric of its own opens on.
  final String? channel;

  /// Where the focus points: [station], else the middle of [window].
  double? get point =>
      station ?? (window == null ? null : (window!.start + window!.end) / 2);

  @override
  bool operator ==(Object other) =>
      other is LapFocus &&
      other.source == source &&
      other.lap == lap &&
      other.reference == reference &&
      other.station == station &&
      other.window == window &&
      other.tab == tab &&
      other.corner == corner &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(
    source,
    lap,
    reference,
    station,
    window,
    tab,
    corner,
    channel,
  );
}

/// A screen a [LapFocus] can be shown on.
///
/// A new destination is a new target, never an edit to the screens that link
/// to it.
abstract interface class LapFocusTarget {
  /// Where [openFocus] goes.
  String get route;

  /// What a link names it: "Trace", "Technique".
  String get label;

  IconData get icon;

  /// The selection the destination reads on its first frame: the lap, the
  /// tab. Anything that needs the destination's data waits in
  /// [pendingLapFocusProvider] instead.
  void apply(WidgetRef ref, LapFocus focus);
}

/// A focus on its way to [route].
@immutable
class PendingLapFocus {
  const PendingLapFocus(this.route, this.focus, this.issued);

  final String route;
  final LapFocus focus;
  final DateTime issued;
}

final pendingLapFocusProvider =
    NotifierProvider<PendingLapFocusNotifier, PendingLapFocus?>(
      PendingLapFocusNotifier.new,
    );

class PendingLapFocusNotifier extends Notifier<PendingLapFocus?> {
  /// Longer than any destination takes to load its data; a focus nobody took
  /// by then would land on a later, unrelated visit.
  static const lifetime = Duration(seconds: 30);

  @override
  PendingLapFocus? build() => null;

  void hold(String route, LapFocus focus) =>
      state = PendingLapFocus(route, focus, DateTime.now());

  /// The focus waiting for [route] on [source]'s lap [lap], taken so it lands
  /// once; null when none is.
  ///
  /// One for another lap stays: the destination may still be drawing the lap
  /// it showed before the selection reached it.
  LapFocus? take(String route, TelemetrySource source, int lap) {
    final pending = state;
    if (pending == null || pending.route != route) return null;
    if (DateTime.now().difference(pending.issued) > lifetime) {
      state = null;
      return null;
    }
    final focus = pending.focus;
    if (focus.source != source || focus.lap != lap) return null;
    state = null;
    return focus;
  }
}

/// Shows [focus] on [target]: makes its session current, lets the target
/// select what it can now, holds the rest for the destination, and goes.
///
/// Making the session current is what Compare's link needs — its laps can be
/// from a file behind the current one — and changes nothing for every other
/// caller.
void openFocus(
  BuildContext context,
  WidgetRef ref,
  LapFocusTarget target,
  LapFocus focus,
) {
  if (ref.read(currentSessionProvider) != focus.source) {
    ref.read(openSessionsProvider.notifier).open(focus.source);
  }
  target.apply(ref, focus);
  ref.read(pendingLapFocusProvider.notifier).hold(target.route, focus);
  // Without a router — a widget test — there is nowhere to go.
  GoRouter.maybeOf(context)?.go(target.route);
}
