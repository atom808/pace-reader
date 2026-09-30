/// Race pace and gaps, from `Time Behind Next` (SPEC.md §8.9).
///
/// Everything here is arithmetic over two reads the repository already does —
/// the channel's readings, and its per-lap aggregates — so the derivations are
/// plain functions a `flutter test` reaches without a DuckDB connection, the
/// same split the data layer and the fuel view make.
///
/// ## What the channel is, measured on all three samples
///
/// **A signed time offset to the car one place ahead.** Negative when that car
/// is ahead of you, so `-6.96` reads "6.96 s behind". Checked against an
/// independent ground truth rather than the name: over a lap on which the car
/// ahead does not change, the gap moves by *your* lap time minus *theirs*, so a
/// slower lap must push the reading more negative. Across the Race sample's 18
/// closed racing laps the change in gap regresses on lap duration at **-1.44 ±
/// 0.38 s per second (r = -0.68, permutation p = 0.0003)** on the per-lap
/// figures below, and -1.46 with the gap interpolated onto the line. The
/// opposite sign convention would give +1, and a channel measuring the car
/// *behind* would too — so this both fixes the sign and says the car is the one
/// ahead. (The slope is steeper than the -1 the arithmetic promises because the
/// car ahead's own lap times move too; one standard error from -1.)
///
/// **A timing-line gap, not distance over speed.** The median step between
/// readings is 0.014 s and the 99th percentile 0.113 s: it does not swing with
/// the car's speed through a corner, which a distance-over-speed figure would
/// by a factor of three.
///
/// **It does not care about lap boundaries.** Across the 19 `Lap` events after
/// the recording starts, no step within a second of one is larger than 0.067 s.
///
/// **It is held, not zero, when nothing is being timed.** In the Race sample
/// the first 86 readings (42.5 s) are all exactly -0.1879 — the car is standing
/// on the grid at 0 km/h — and the last 22 (10.5 s) are all exactly -6.9584,
/// starting 0.5 s after `Finish Status` goes to 1: the game stops updating it at
/// the chequered flag while the car keeps driving. Those stretches are real
/// readings of nothing changing, and the view says so rather than drawing them
/// as a gap that stayed put.
///
/// **A step of 0.57 s or more is the car ahead changing, not the gap moving.**
/// The Race sample has exactly three, all in the first lap — 122.5 s (+0.11 →
/// -0.46), 124.0 s (-0.06 → -0.71) and 165.0 s (-0.02 → -2.10) — and every one
/// is preceded by the gap closing to within 0.11 s. That is the signature of a
/// pass: you draw level, and the next car ahead is somebody further up the road.
/// The rest of the race is smooth. The largest step that is *not* a change is
/// 0.293 s (the scrap around 123 s), so the threshold ([carAheadChangeThreshold])
/// sits between the two populations rather than on either.
///
/// ## Why the view is race-only
///
/// The same channel in the other two samples is not a gap to anything you could
/// watch open or close. Qualify (Spa, 1,178 readings): 61 steps of 0.3 s or
/// more, 41 sign flips between consecutive readings, 8.1% of readings positive,
/// a 23.97 s step from -22.26 to +1.71. Practice (Interlagos, 655 readings): 68
/// such steps, 72.5% of readings beyond ±10 s, a range of -41.88 to +43.40 s and
/// a single-reading step of 80.64 s. Against three steps in the whole Race
/// sample. Why is an inference, not something the file says: outside a race
/// the game presumably ranks cars by best lap, which would make "the next
/// place" as often behind you on the road as ahead of it, and the reading a
/// signed offset to whoever that is. What the samples do establish is the
/// behaviour above — it flips sign, sits at zero, and jumps by tens of seconds
/// — and that is what the view's explanation rests on.
///
/// Exactly-zero readings are also confined to those two files (43 in Qualify, 18
/// in Practice, none in the Race): they are treated here as "no car being timed"
/// rather than as a gap of zero. That is an inference from where they occur —
/// the pit lane at the start of both files, and a 6.5 s stretch of the Practice
/// sample — not something the file states.
///
/// What the samples cannot say: what a pit stop does to the channel (the Race
/// sample never enters the pit lane; in the other two the reading is a mix of
/// exact zeros and -6.2..+0.1 s while `In Pits` is 1), and what a race *leader*
/// reads (no sample leads).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../fuel_energy_strategy/application/fuel_energy.dart'
    show PitVisit, inPitsEventName, pitVisitsFrom;

part 'race_pace.g.dart';

const timeBehindNextChannelName = 'Time Behind Next';

/// A step between two consecutive readings at least this large is the car ahead
/// changing rather than the gap moving.
///
/// Chosen between two populations measured in the Race sample: the largest step
/// of ordinary racing is 0.293 s (two cars nose to tail, lap 1), the smallest
/// change is 0.572 s. 0.4 s is 0.11 above the first and 0.17 below the second.
/// A change smaller than that — two cars separated by under 0.4 s — cannot be
/// told from the gap moving, and this channel cannot show it.
const carAheadChangeThreshold = 0.4;

/// How many identical consecutive readings make a stretch *held*: 10, or 5 s.
/// A live gap never repeats a float to the last digit for that long — the
/// Race sample's longest run outside the two held stretches is 2.
const minHeldReadings = 10;

/// Buckets the session-scoped trace is fetched at.
///
/// §9.5 makes decimation load-bearing at session scope, and 1,000 is about a
/// pixel column per bucket on a desktop window. On the 22-minute Race sample
/// that is 2.7 readings a bucket; on a 24-hour file it would be 173, which is
/// why *drawing* uses this and *analysing* does not (see [racePaceReport]).
const sessionEnvelopeBuckets = 1000;

/// A reading of exactly 0.0 is not a gap: see the library comment.
bool isLiveGap(double value) => value != 0.0 && value.isFinite;

/// The first index whose time is at or after [seconds]; `times.length` if none.
int firstReadingAtOrAfter(Float64List times, double seconds) {
  var low = 0;
  var high = times.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (times[mid] < seconds) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// A moment the reference car changed: two consecutive readings [threshold]
/// or more apart.
class CarAheadChange {
  const CarAheadChange({
    required this.beforeSeconds,
    required this.timeSeconds,
    required this.before,
    required this.after,
  });

  /// When the last reading before the step was taken.
  final double beforeSeconds;

  /// When the first reading after it was — the moment the change is *seen*.
  final double timeSeconds;

  final double before;
  final double after;

  /// Signed: negative means the new car ahead is further up the road.
  double get step => after - before;

  /// How close the old car ahead had got, in seconds.
  double get closedTo => before.abs();

  /// Whether the gap had closed to within [nearSeconds] just before the change
  /// — how all three changes in the Race sample begin, and what a pass looks
  /// like from this channel.
  bool closedInFirst({double nearSeconds = 0.5}) => closedTo <= nearSeconds;
}

/// The changes of car ahead in [readings], in time order.
///
/// Steps touching an exactly-zero reading are skipped: 0.0 means no car was
/// being timed, so a step onto or off it is a car appearing or disappearing,
/// not one replacing another.
List<CarAheadChange> carAheadChangesIn(
  TraceSeries readings, {
  double threshold = carAheadChangeThreshold,
}) {
  final values = readings.lows;
  final changes = <CarAheadChange>[];
  for (var i = 0; i + 1 < values.length; i++) {
    final a = values[i];
    final b = values[i + 1];
    if (!isLiveGap(a) || !isLiveGap(b)) continue;
    if ((b - a).abs() >= threshold) {
      changes.add(CarAheadChange(
        beforeSeconds: readings.times[i],
        timeSeconds: readings.times[i + 1],
        before: a,
        after: b,
      ));
    }
  }
  return changes;
}

/// A stretch over which the reading did not change at all.
class HeldReadings {
  const HeldReadings({
    required this.fromSeconds,
    required this.toSeconds,
    required this.count,
    required this.value,
  });

  final double fromSeconds;
  final double toSeconds;
  final int count;
  final double value;

  double get durationSeconds => toSeconds - fromSeconds;
}

/// The run of identical readings the recording opens with, if it is long
/// enough to be held ([minHeldReadings]).
HeldReadings? heldReadingsAtStart(TraceSeries readings, {int min = minHeldReadings}) {
  final values = readings.lows;
  if (values.isEmpty) return null;
  var end = 0;
  while (end + 1 < values.length && values[end + 1] == values[0]) {
    end++;
  }
  final count = end + 1;
  if (count < min) return null;
  return HeldReadings(
    fromSeconds: readings.times[0],
    toSeconds: readings.times[end],
    count: count,
    value: values[0],
  );
}

/// The run of identical readings the recording ends with — after the chequered
/// flag, in the Race sample.
HeldReadings? heldReadingsAtEnd(TraceSeries readings, {int min = minHeldReadings}) {
  final values = readings.lows;
  if (values.isEmpty) return null;
  final last = values.length - 1;
  var start = last;
  while (start - 1 >= 0 && values[start - 1] == values[last]) {
    start--;
  }
  final count = last - start + 1;
  if (count < min) return null;
  return HeldReadings(
    fromSeconds: readings.times[start],
    toSeconds: readings.times[last],
    count: count,
    value: values[last],
  );
}

/// Why a lap's gained/lost figure is not counted toward the session's.
enum GapExclusion {
  /// The recording holds none of the channel's readings inside the lap.
  noData('no data'),

  /// Part of the lap was spent in the pit lane: the car ahead is a different
  /// car afterwards, and the channel's behaviour in the pits is one the
  /// samples cannot say (see the library comment).
  pitLane('pit lane'),

  /// The recording ended before the lap did.
  incomplete('incomplete'),

  /// The lap opens or closes on an exactly-zero reading: no car was timed.
  noCarAhead('no car ahead timed');

  const GapExclusion(this.label);

  final String label;
}

/// One lap's view of the gap.
class LapGap {
  const LapGap({
    required this.lap,
    required this.start,
    required this.end,
    required this.gained,
    required this.closest,
    required this.mean,
    required this.changes,
    this.exclusion,
  });

  final Lap lap;

  /// The reading at the lap's first sample, and at the next lap's first sample
  /// — or this lap's own last, when no later lap has any. Both are 2 Hz
  /// readings the game wrote, within 0.5 s of the line: at the 0.05 s/s the gap
  /// typically moves, that is 0.03 s of timing slack on a lap's figure.
  final double? start;
  final double? end;

  /// Seconds gained on the car ahead (positive) or lost (negative) over the
  /// lap: how far the reading moved, **less the steps where the car ahead
  /// changed**. Overtaking somebody is not losing 2 s to them, and lap 1 of the
  /// Race sample — three passes worth -3.30 s — would otherwise read as a lap
  /// lost.
  final double? gained;

  /// The reading with the smallest magnitude inside the lap, sign kept.
  final double? closest;

  /// The lap's mean reading, computed in SQL.
  final double? mean;

  /// The changes of car ahead inside the lap.
  final List<CarAheadChange> changes;

  /// Why [gained] is not counted; null when it is.
  final GapExclusion? exclusion;

  bool get counted => exclusion == null && gained != null;
}

/// Everything the race-pace view shows for one race.
class GapSession {
  const GapSession({
    required this.readings,
    required this.envelope,
    required this.laps,
    required this.changes,
    required this.pitVisits,
    required this.heldAtStart,
    required this.heldAtEnd,
    required this.originSeconds,
    required this.endSeconds,
  });

  /// Builds the session's figures.
  ///
  /// [readings] is every reading, [envelope] the same channel min/max-bucketed
  /// for drawing, [stats] the SQL per-lap aggregates.
  factory GapSession.derive({
    required TraceSeries readings,
    required TraceSeries envelope,
    required List<Lap> laps,
    required List<LapChannelStats> stats,
    required double originSeconds,
    required double endSeconds,
    List<PitVisit> pitVisits = const [],
  }) {
    final changes = carAheadChangesIn(readings);
    return GapSession(
      readings: readings,
      envelope: envelope,
      laps: lapGapsFrom(
        laps: laps,
        stats: stats,
        readings: readings,
        changes: changes,
        pitVisits: pitVisits,
      ),
      changes: changes,
      pitVisits: pitVisits,
      heldAtStart: heldReadingsAtStart(readings),
      heldAtEnd: heldReadingsAtEnd(readings),
      originSeconds: originSeconds,
      endSeconds: endSeconds,
    );
  }

  /// Every reading, as `readFullResolution` returns them: the analysis series.
  final TraceSeries readings;

  /// The same channel decimated for drawing — min/max per bucket, so a step
  /// inside one bucket shows as the envelope thickening rather than vanishing.
  final TraceSeries envelope;

  final List<LapGap> laps;
  final List<CarAheadChange> changes;
  final List<PitVisit> pitVisits;
  final HeldReadings? heldAtStart;
  final HeldReadings? heldAtEnd;

  /// The recording's own t=0 and its last master-clock time (§5.2).
  final double originSeconds;
  final double endSeconds;

  /// The first non-zero reading — the gap "at the start of the recording".
  double? get startGap => _firstLive?.$2;

  /// The last non-zero reading. In the Race sample it equals the value the
  /// channel froze at when the car took the flag.
  double? get endGap => _lastLive?.$2;

  (double, double)? get _firstLive {
    for (var i = 0; i < readings.length; i++) {
      if (isLiveGap(readings.lows[i])) {
        return (readings.times[i], readings.lows[i]);
      }
    }
    return null;
  }

  (double, double)? get _lastLive {
    for (var i = readings.length - 1; i >= 0; i--) {
      if (isLiveGap(readings.lows[i])) {
        return (readings.times[i], readings.lows[i]);
      }
    }
    return null;
  }

  List<LapGap> get countedLaps => [
        for (final lap in laps)
          if (lap.counted) lap,
      ];

  /// Seconds gained (+) or lost (-) on the cars ahead over every counted lap.
  double get netGained =>
      countedLaps.fold<double>(0, (sum, lap) => sum + lap.gained!);

  /// What the changes of car ahead were worth: the part of the raw movement
  /// between [startGap] and [endGap] that is somebody else being ahead now.
  double get changeSteps =>
      changes.fold<double>(0, (sum, change) => sum + change.step);

  /// The reading of smallest magnitude, with when it was taken.
  ({double gap, double atSeconds})? get closestApproach {
    double? best;
    var at = 0.0;
    for (var i = 0; i < readings.length; i++) {
      final value = readings.lows[i];
      if (!isLiveGap(value)) continue;
      if (best == null || value.abs() < best.abs()) {
        best = value;
        at = readings.times[i];
      }
    }
    return best == null ? null : (gap: best, atSeconds: at);
  }

  /// The lap [seconds] falls in: the last one that had started by then.
  Lap? lapAt(double seconds) {
    Lap? found;
    for (final gap in laps) {
      if (gap.lap.startSeconds <= seconds) {
        found = gap.lap;
      } else {
        break;
      }
    }
    return found;
  }

  /// The reading nearest [seconds], or null for an empty series.
  ({double seconds, double gap})? readingNear(double seconds) {
    final times = readings.times;
    if (times.isEmpty) return null;
    final after = firstReadingAtOrAfter(times, seconds);
    var index = after.clamp(0, times.length - 1);
    if (index > 0 &&
        (seconds - times[index - 1]).abs() < (times[index] - seconds).abs()) {
      index -= 1;
    }
    return (seconds: times[index], gap: readings.lows[index]);
  }
}

/// Per-lap gain and loss against the car ahead.
///
/// A lap's readings are those taken in `[lap.start, lap.end)`, which is exactly
/// the rule `lapStatsSql` uses to assign a sample to a lap — the first channel
/// row at or after the boundary — so [LapGap.start] agrees with the SQL's
/// `first` reading for reading, and the integration suite checks it does.
List<LapGap> lapGapsFrom({
  required List<Lap> laps,
  required List<LapChannelStats> stats,
  required TraceSeries readings,
  required List<CarAheadChange> changes,
  List<PitVisit> pitVisits = const [],
}) {
  final byLap = {for (final s in stats) s.lapIndex: s};
  final times = readings.times;
  final values = readings.lows;
  final out = <LapGap>[];

  for (var i = 0; i < laps.length; i++) {
    final lap = laps[i];
    final own = byLap[lap.index];
    final inLap = [
      for (final change in changes)
        if (change.beforeSeconds >= lap.startSeconds &&
            (lap.endSeconds == null || change.beforeSeconds < lap.endSeconds!))
          change,
    ];

    if (own == null) {
      out.add(LapGap(
        lap: lap,
        start: null,
        end: null,
        gained: null,
        closest: null,
        mean: null,
        changes: inLap,
        exclusion: GapExclusion.noData,
      ));
      continue;
    }

    final next = i + 1 < laps.length ? byLap[laps[i + 1].index] : null;
    final start = own.first;
    final end = next?.first ?? own.last;

    final from = firstReadingAtOrAfter(times, lap.startSeconds);
    final to = lap.endSeconds == null
        ? times.length
        : firstReadingAtOrAfter(times, lap.endSeconds!);
    double? closest;
    for (var k = from; k < to; k++) {
      if (!isLiveGap(values[k])) continue;
      if (closest == null || values[k].abs() < closest.abs()) {
        closest = values[k];
      }
    }

    final exclusion = lap.isOpenEnded
        ? GapExclusion.incomplete
        : pitVisits.any((visit) => visit.overlaps(lap))
            ? GapExclusion.pitLane
            : !isLiveGap(start) || !isLiveGap(end)
                ? GapExclusion.noCarAhead
                : null;

    out.add(LapGap(
      lap: lap,
      start: start,
      end: end,
      gained: end - start - inLap.fold<double>(0, (sum, c) => sum + c.step),
      closest: closest,
      mean: own.mean,
      changes: inLap,
      exclusion: exclusion,
    ));
  }
  return out;
}

/// Why there is no gap to show.
enum GapUnavailable {
  /// Not a race: see the library comment for the measurements behind this.
  notARace,

  /// The file carries no `Time Behind Next` channel.
  noChannel,

  /// The channel holds no reading that is not exactly zero.
  noCarAhead,
}

/// What the race-pace screen is given.
class RacePaceReport {
  const RacePaceReport({
    required this.sessionType,
    this.session,
    this.unavailable,
  }) : assert((session == null) != (unavailable == null),
            'exactly one of a session and a reason');

  final SessionType sessionType;
  final GapSession? session;
  final GapUnavailable? unavailable;
}

/// See `providers.dart`: every failure this layer produces is deterministic,
/// so retrying one on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

/// The race-pace report for one session.
///
/// **Two reads of the same channel, on purpose.** The trace drawn is fetched
/// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
/// session scope. The analysis is not: a change of car ahead is a single
/// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
/// bucket count — it cannot be seen, so every lap's figure would be quietly
/// contaminated by passes the bucketing had swallowed. The full series costs
/// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
/// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
/// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
/// *drawing* that many points, and nothing here does.
///
/// A session that is not a race returns before reading the channel at all.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<RacePaceReport> racePaceReport(
  Ref ref,
  TelemetrySource source,
) async {
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  if (metadata.sessionType != SessionType.race) {
    return RacePaceReport(
      sessionType: metadata.sessionType,
      unavailable: GapUnavailable.notARace,
    );
  }

  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final channel = catalog.channel(timeBehindNextChannelName);
  if (channel == null) {
    return RacePaceReport(
      sessionType: metadata.sessionType,
      unavailable: GapUnavailable.noChannel,
    );
  }

  final laps = await ref.watch(lapsProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  // One second past the last master-clock time: the window is half-open, and
  // the last reading sits at or after `endSeconds`.
  final endSeconds = catalog.endSeconds + 1;
  final envelope = await telemetry.readTrace(
    timeBehindNextChannelName,
    window: TraceWindow(
      startSeconds: catalog.origin,
      endSeconds: endSeconds,
      buckets: sessionEnvelopeBuckets,
    ),
  );
  final readings = await telemetry.readFullResolution(
    timeBehindNextChannelName,
    startSeconds: catalog.origin,
    endSeconds: endSeconds,
    maxSamples: math.max(channel.rowCount, 1),
  );
  if (readings.isEmpty ||
      envelope.isEmpty ||
      !readings.first.lows.any(isLiveGap)) {
    return RacePaceReport(
      sessionType: metadata.sessionType,
      unavailable: GapUnavailable.noCarAhead,
    );
  }

  final pitVisits = catalog.hasEvent(inPitsEventName)
      ? pitVisitsFrom(await telemetry.readEventWindow(
          inPitsEventName,
          startSeconds: catalog.origin,
          endSeconds: endSeconds,
        ))
      : const <PitVisit>[];

  return RacePaceReport(
    sessionType: metadata.sessionType,
    session: GapSession.derive(
      readings: readings.first,
      envelope: envelope.first,
      laps: laps,
      stats: await telemetry.readLapStats(timeBehindNextChannelName),
      originSeconds: catalog.origin,
      endSeconds: catalog.endSeconds,
      pitVisits: pitVisits,
    ),
  );
}
