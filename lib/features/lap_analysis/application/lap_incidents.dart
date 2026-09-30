/// What happened on each lap that could explain its time (SPEC.md §8.3):
/// impacts, a yellow-flag state, a detached wheel.
///
/// Read from three event tables session-wide — they are sparse, one to three
/// rows in every sample — and cut into laps in Dart, so the derivation is
/// plain functions a `flutter test` reaches without a DuckDB connection.
///
/// ## What the samples actually contain, measured on all three
///
/// | Event | Practice | Qualify | Race |
/// |---|---|---|---|
/// | `LastImpactMagnitude` | 1 row, `false` | 1 row, `false` | 3 rows: `false`, `true` at 213.8 s, `false` at 508.1 s |
/// | `Yellow Flag State` | 1 row, 0 | 1 row, 0 | 1 row, 0 |
/// | `WheelsDetached` | 1 row, 0,0,0,0 | 1 row, 0,0,0,0 | 1 row, 0,0,0,0 |
///
/// So across 37.6 minutes of recording (5.5 + 9.8 + 22.3), **two impacts and
/// nothing else has ever been recorded**. The derivations for a yellow flag and a detached wheel are
/// written from what the tables *are*, and are exercised in tests on
/// constructed series; no real value has ever exercised them.
library;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';

part 'lap_incidents.g.dart';

/// See `providers.dart`: every failure this layer produces is deterministic,
/// so retrying one on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

const impactEventName = 'LastImpactMagnitude';
const yellowFlagEventName = 'Yellow Flag State';
const wheelsDetachedEventName = 'WheelsDetached';

/// A wheel position, from a per-corner event's `value1..value4`.
///
/// **A local mapping, deliberately.** §15.5 resolved the order as FL, FR, RL,
/// RR from three independent methods on the per-corner *channels*; a shared
/// corner model is being added to the data layer separately, and this should
/// give way to it when it lands. Checked here on a per-corner *event* too, so
/// the mapping is not carried over on faith. In `SurfaceTypes` (a row per
/// change), take the rows where three wheels agree on a surface and the odd
/// one out is `value1` or `value3`, against those where it is `value2` or
/// `value4`. The car's lateral G over those rows, averaged across each row's
/// span (`G Force Long` in the export, which swaps the two names; positive is
/// left), sits 0.58, 0.50 and 1.22 G further left in the first group
/// (Practice, Qualify, Race: 387 against 287, 850 against 982 and 1,571
/// against 1,852 rows). Kerbs are taken on the inside of a corner, and the
/// left pair is the inside pair when turning left. The sign is the same on all
/// three samples; the size is not, and depends on the circuit, so only the
/// sign is relied on.
enum WheelCorner {
  frontLeft('FL', 'front-left'),
  frontRight('FR', 'front-right'),
  rearLeft('RL', 'rear-left'),
  rearRight('RR', 'rear-right');

  const WheelCorner(this.abbreviation, this.description);

  final String abbreviation;
  final String description;
}

/// What one lap recorded.
@immutable
class LapIncidents {
  const LapIncidents({
    required this.lapIndex,
    this.impactSeconds = const [],
    this.yellowFlagCodes = const {},
    this.detachedWheels = const {},
    this.alreadyDetached = const {},
  });

  /// A lap on which nothing was recorded — what most laps are.
  const LapIncidents.none(this.lapIndex)
    : impactSeconds = const [],
      yellowFlagCodes = const {},
      detachedWheels = const {},
      alreadyDetached = const {};

  final int lapIndex;

  /// When each impact registered, in the file's elapsed seconds, ascending.
  ///
  /// Times rather than a bare count: the tooltip says how far into the lap it
  /// was, which is what lets a driver find it in the Trace view.
  final List<double> impactSeconds;

  /// The non-zero `Yellow Flag State` codes in force at any point of the lap,
  /// including one already in force when it began.
  ///
  /// Codes rather than a flag because 0 is the only value any sample has ever
  /// held: what the others mean is the game's to say, not something this app
  /// has verified, so the tooltip quotes the code instead of interpreting it.
  final Set<int> yellowFlagCodes;

  /// Wheels reported detached at any point of the lap, including one that was
  /// already off when the lap began.
  final Set<WheelCorner> detachedWheels;

  /// The subset of [detachedWheels] that was already off at the lap's start —
  /// the wheel that came off two laps ago and is still costing time.
  final Set<WheelCorner> alreadyDetached;

  int get impactCount => impactSeconds.length;
  bool get hasImpact => impactSeconds.isNotEmpty;
  bool get underYellow => yellowFlagCodes.isNotEmpty;
  bool get hasDetachedWheel => detachedWheels.isNotEmpty;

  bool get isEmpty => !hasImpact && !underYellow && !hasDetachedWheel;
}

/// Every lap's incidents for a session.
class SessionIncidents {
  const SessionIncidents({this.byLap = const {}, this.unavailable = const []});

  /// Keyed by `Lap.index`; holds only the laps that recorded something.
  final Map<int, LapIncidents> byLap;

  /// Event tables the recording does not have at all — a future LMU version
  /// could drop one — as opposed to having and finding nothing in them. The
  /// screen says which, because "no impacts" and "no impact data" are
  /// different statements about the session.
  final List<String> unavailable;

  LapIncidents of(Lap lap) => byLap[lap.index] ?? LapIncidents.none(lap.index);

  bool get isEmpty => byLap.isEmpty;

  /// The recording holds none of the three tables, so an empty result says
  /// nothing about the session.
  bool get hasNoEvents => unavailable.length == eventNames.length;

  /// The events read, in the order [unavailable] reports them.
  static const eventNames = [
    impactEventName,
    yellowFlagEventName,
    wheelsDetachedEventName,
  ];

  /// Registered impacts across the session.
  int get impactCount =>
      byLap.values.fold(0, (sum, lap) => sum + lap.impactCount);

  int get lapsWithImpact => byLap.values.where((l) => l.hasImpact).length;
  int get lapsUnderYellow => byLap.values.where((l) => l.underYellow).length;
  int get lapsWithDetachedWheel =>
      byLap.values.where((l) => l.hasDetachedWheel).length;

  /// Cuts the three event series into [laps].
  ///
  /// Any series may be null (the recording lacks the table) and is then named
  /// in [unavailable] by the caller.
  static SessionIncidents derive(
    List<Lap> laps, {
    StepSeries? impact,
    StepSeries? yellowFlag,
    List<StepSeries> wheelsDetached = const [],
    List<String> unavailable = const [],
  }) {
    final byLap = <int, LapIncidents>{};
    for (final lap in laps) {
      final start = lap.startSeconds;
      // The final lap has no closing boundary; anything after its start is on
      // it, as `LapPaceStatistics.lapAt` treats it.
      final end = lap.endSeconds ?? double.infinity;

      final detached = <WheelCorner>{};
      final carried = <WheelCorner>{};
      if (wheelsDetached.length == WheelCorner.values.length) {
        for (final corner in WheelCorner.values) {
          final series = wheelsDetached[corner.index];
          if (_valueAt(series, start) != 0) carried.add(corner);
          if (carried.contains(corner) ||
              _nonZeroCodesWithin(series, start, end).isNotEmpty) {
            detached.add(corner);
          }
        }
      }

      final incidents = LapIncidents(
        lapIndex: lap.index,
        impactSeconds: impact == null
            ? const []
            : _changesWithin(impact, start, end),
        yellowFlagCodes: yellowFlag == null
            ? const {}
            : _nonZeroCodesIn(yellowFlag, start, end),
        detachedWheels: detached,
        alreadyDetached: carried,
      );
      if (!incidents.isEmpty) byLap[lap.index] = incidents;
    }
    return SessionIncidents(byLap: byLap, unavailable: unavailable);
  }

  /// Timestamps of the changes in `[start, end)` — every row but the first.
  ///
  /// **A row is an impact; its value is not.** `LastImpactMagnitude` is a
  /// BOOLEAN despite the name (there is no magnitude to threshold, so this
  /// cannot tell a kerb tap from a crash), and its polarity carries no
  /// meaning. In the Race sample it reads `true` from 213.8 s to 508.1 s —
  /// five laps — and counting the *state* would blame laps 3, 4 and 5 for an
  /// impact on lap 2. The two rows are two impacts: the car's `Ground Speed`
  /// steps +3.5 km/h within 0.06 s at 213.8 s and +7.9 km/h within 0.06 s at
  /// 508.1 s — a shove from behind, since no car accelerates like that — and
  /// those are the two largest 0.06 s steps in the whole 22 minutes; the
  /// largest anywhere else is +2.05. The one that writes `false` is the
  /// harder shove, so `false` is not "a lighter one" or "cleared".
  ///
  /// The first row is the state when recording began, at the session origin
  /// (§5.2): not a change, and not attributable to any lap.
  ///
  /// Counts are a lower bound. No event table in any sample repeats a value in
  /// consecutive rows, so the file stores changes of the *stored* value only,
  /// and a second impact that leaves it unchanged would leave no row.
  static List<double> _changesWithin(
    StepSeries series,
    double start,
    double end,
  ) => [
    for (var i = 1; i < series.length; i++)
      if (series.times[i] >= start && series.times[i] < end) series.times[i],
  ];

  /// The value in force at [seconds], or 0 before the first row.
  static double _valueAt(StepSeries series, double seconds) =>
      series.valueAt(seconds) ?? 0;

  /// Non-zero codes in force at some point of `[start, end)`: the one already
  /// in force at [start], and any row inside the lap.
  static Set<int> _nonZeroCodesIn(
    StepSeries series,
    double start,
    double end,
  ) => {
    if (_valueAt(series, start) != 0) _valueAt(series, start).round(),
    ..._nonZeroCodesWithin(series, start, end),
  };

  /// Non-zero codes among the rows strictly inside `(start, end)`. A row *at*
  /// [start] is already what `valueAt(start)` returns.
  static Set<int> _nonZeroCodesWithin(
    StepSeries series,
    double start,
    double end,
  ) => {
    for (var i = 0; i < series.length; i++)
      if (series.times[i] > start &&
          series.times[i] < end &&
          series.values[i] != 0)
        series.values[i].round(),
  };
}

/// Incidents for every lap of [source] (§8.3).
///
/// Session-wide and small — three tables, one to three rows each in all three
/// samples — so it is one read shared by the table, the chart and the summary
/// rather than a query per lap.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionIncidents> sessionIncidents(
  Ref ref,
  TelemetrySource source,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);

  Future<StepSeries?> read(String name, {String? column}) async {
    if (!catalog.hasEvent(name)) return null;
    return telemetry.readEventWindow(
      name,
      startSeconds: catalog.origin,
      endSeconds: catalog.endSeconds + 1,
      valueColumn: column,
    );
  }

  final wheels = catalog.event(wheelsDetachedEventName);
  // Four columns is what makes them corners at all; a table of another shape
  // is reported missing rather than guessed at.
  final wheelColumns =
      wheels != null && wheels.valueColumnCount == WheelCorner.values.length
      ? wheels.valueColumns
      : null;

  final impact = await read(impactEventName);
  final yellow = await read(yellowFlagEventName);
  final wheelSeries = <StepSeries>[
    if (wheelColumns != null)
      for (final column in wheelColumns)
        (await read(wheelsDetachedEventName, column: column))!,
  ];

  return SessionIncidents.derive(
    laps,
    impact: impact,
    yellowFlag: yellow,
    wheelsDetached: wheelSeries,
    unavailable: [
      if (impact == null) impactEventName,
      if (yellow == null) yellowFlagEventName,
      if (wheelColumns == null) wheelsDetachedEventName,
    ],
  );
}
