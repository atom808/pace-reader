/// Which laps Driving Technique measures (SPEC.md §8.13.2).
library;

import '../../../data/models/models.dart';

/// Why a lap is not a racing lap.
enum NotRacing {
  recordingStart("the recording's first lap"),
  untimed('it has no lap time'),
  open('the recording ends during it'),
  pitLane('it spent time in the pit lane'),
  limiter('it ran on the pit speed limiter');

  const NotRacing(this.description);

  final String description;
}

/// Why [lap] is not a racing lap, or null when it is.
///
/// A racing lap is past the recording's first, timed, closed, and never in
/// the pit lane or on the speed limiter at any moment of it. *At any moment*
/// includes a state switched on before the lap began and still on: Imola's
/// Hypercar race switched `In Pits` and `Speed Limiter` on 60 s before lap 1
/// started and off 13.5 s into it, and a rule that looked only for rows
/// inside the lap counted that pit-exit lap as racing. The intervals are
/// therefore states with a start and an end — Compare's `pitLaneDuring`.
NotRacing? whyNotRacing(
  Lap lap, {
  required List<PitInterval> pitLane,
  required List<PitInterval> limiter,
}) {
  if (lap.isOutLap) return NotRacing.recordingStart;
  final end = lap.endSeconds;
  if (end == null) return NotRacing.open;
  if (lap.lapTimeSeconds == null) return NotRacing.untimed;
  bool during(List<PitInterval> states) =>
      states.any((s) => s.overlaps(lap.startSeconds, end));
  if (during(pitLane)) return NotRacing.pitLane;
  if (during(limiter)) return NotRacing.limiter;
  return null;
}

/// The racing laps of [laps], in order.
List<Lap> racingLaps(
  List<Lap> laps, {
  required List<PitInterval> pitLane,
  required List<PitInterval> limiter,
}) => [
  for (final lap in laps)
    if (whyNotRacing(lap, pitLane: pitLane, limiter: limiter) == null) lap,
];
