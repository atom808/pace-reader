/// Playing a lap back (map stage proposal §5.1, D8): the playhead driven by
/// the clock, the car on the map and every trace following it.
///
/// Two halves. [PlaybackController] is what the play bar shows and sets —
/// playing or not, the rate, the loop — and [advancePlayhead] is the pure
/// step a ticker calls each frame. The ticker itself lives in the widget
/// that plays (`PlaybackDriver`), so nothing ticks while no stage is on
/// screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'decimation.dart';
import 'viewport.dart';

/// What the play bar shows.
class PlaybackState {
  const PlaybackState({this.playing = false, this.rate = 1, this.loop = false});

  final bool playing;

  /// Lap time per second of wall time: ×0.25 to ×4.
  final double rate;

  /// Repeat the trace window rather than run on to the end of the lap.
  final bool loop;

  PlaybackState copyWith({bool? playing, double? rate, bool? loop}) =>
      PlaybackState(
        playing: playing ?? this.playing,
        rate: rate ?? this.rate,
        loop: loop ?? this.loop,
      );

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.playing == playing &&
      other.rate == rate &&
      other.loop == loop;

  @override
  int get hashCode => Object.hash(playing, rate, loop);
}

/// The rates the rate chip steps through, slow motion first: slow motion is
/// how a lock-up or a snap gets seen.
const playbackRates = [0.25, 0.5, 1.0, 2.0, 4.0];

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(
  PlaybackController.new,
);

class PlaybackController extends Notifier<PlaybackState> {
  @override
  PlaybackState build() => const PlaybackState();

  void play() => state = state.copyWith(playing: true);
  void pause() => state = state.copyWith(playing: false);

  /// Pauses, if the app around this controller is still there: for a stage
  /// being torn down, perhaps with everything else.
  void pauseIfMounted() {
    if (ref.mounted) pause();
  }

  void toggle() => state = state.copyWith(playing: !state.playing);
  void setLoop(bool loop) => state = state.copyWith(loop: loop);

  /// The rate chip: the next rate, round to the slowest after the fastest.
  void cycleRate() {
    final i = playbackRates.indexOf(state.rate);
    state = state.copyWith(rate: playbackRates[(i + 1) % playbackRates.length]);
  }

  /// One step along [playbackRates]: +1 faster, -1 slower.
  void stepRate(int direction) {
    final i = playbackRates.indexOf(state.rate);
    final next = (i < 0 ? 2 : i + direction).clamp(0, playbackRates.length - 1);
    state = state.copyWith(rate: playbackRates[next]);
  }
}

/// Where the playhead goes after [seconds] of wall time.
///
/// Advanced in **lap time** and converted back to [axis] through
/// [distanceAxis]: advancing in metres would drive the car at a constant
/// speed, while in time it brakes and accelerates as the real one did.
///
/// It runs inside [range] — the trace window when looping, the lap
/// otherwise. A playhead outside it, or none, starts at its beginning. At
/// the end it wraps when [loop], and otherwise stops there with `ended`.
({double playhead, bool ended}) advancePlayhead({
  required double? playhead,
  required double seconds,
  required double rate,
  required TraceAxis axis,
  required ChartViewport range,
  DistanceAxis? distanceAxis,
  bool loop = false,
}) {
  final at = playhead;
  if (at == null || at < range.start || at >= range.end) {
    return (playhead: range.start, ended: false);
  }
  final useDistance =
      axis == TraceAxis.distance && (distanceAxis?.isUsable ?? false);
  final step = seconds * rate;
  final next = useDistance
      ? distanceAxis!.distanceAt(distanceAxis.timeAt(at) + step)
      : at + step;
  // Past the end, or stuck — a distance axis that cannot move on from its
  // last sample — is the end, rather than a stall.
  if (next < range.end && next > at) return (playhead: next, ended: false);
  return loop
      ? (playhead: range.start, ended: false)
      : (playhead: range.end, ended: true);
}

/// The trace window that keeps [playhead] in view while playing: once it
/// passes 85 % of [window], the window slides on so it sits at 30 %. Null
/// when the window should stay — the whole lap, or the playhead still well
/// inside it.
ChartViewport? keepUpWindow({
  required ChartViewport window,
  required ChartViewport bounds,
  required double playhead,
}) {
  if (window.span >= bounds.span) return null;
  final fraction = window.normalize(playhead);
  if (fraction >= 0 && fraction <= 0.85) return null;
  final start = playhead - window.span * 0.3;
  final next = ChartViewport(start, start + window.span).slidInside(bounds);
  return next == window ? null : next;
}
