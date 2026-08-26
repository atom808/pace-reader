/// Time-aligned, decimated channel reads (SPEC.md §9.2, §9.5).
library;

import 'dart:typed_data';

import '../../core/errors.dart';
import '../duckdb/channel_queries.dart';
import '../duckdb/event_queries.dart';
import '../duckdb/telemetry_database.dart';
import '../duckdb/time_axis.dart';
import '../models/models.dart';

/// Channel data, already time-aligned and already reduced to render scale.
///
/// Feature code asks for "this channel over this window" and gets points it
/// can draw. It never learns a channel's native rate, that channel tables have
/// no timestamp column, or which of the two time-axis derivations its channel
/// needed — that knowledge stops here (§9.2).
class TelemetryRepository {
  TelemetryRepository(this._exec, this._catalog);

  final TelemetryQueryExecutor _exec;
  final TelemetryCatalog _catalog;

  ChannelDescriptor _requireChannel(String name) {
    final channel = _catalog.channel(name);
    if (channel == null) {
      throw SchemaMismatchException(
        'This session has no "$name" channel.',
        detail: 'channel not in channelsList',
      );
    }
    return channel;
  }

  /// Resolves a time window to a channel's row range.
  ///
  /// A lookup against the master clock rather than `(t - origin) * frequency`,
  /// because the arithmetic version is blind to recording discontinuities and
  /// would name the wrong rows after one — silently.
  Future<({int start, int endExclusive})?> resolveRowRange(
    ChannelDescriptor channel, {
    required double startSeconds,
    required double endSeconds,
  }) async {
    final row = await _exec.firstRow(channelRowRangeSql(
      channel,
      _catalog.masterRowCount,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    ));
    if (row == null || row[0] == null || row[1] == null) return null;
    final start = (row[0] as num).toInt();
    final end = (row[1] as num).toInt();
    return end > start ? (start: start, endExclusive: end) : null;
  }

  /// Decimated series for one channel over [window].
  ///
  /// Returns one [TraceSeries] per value column, so a per-corner channel
  /// yields four parallel series from a single scan. Empty when the window
  /// falls outside the recording — which is a normal result, not an error: a
  /// lap-scoped window on a channel that stopped recording early lands here.
  Future<List<TraceSeries>> readTrace(
    String channelName, {
    required TraceWindow window,
  }) async {
    final channel = _requireChannel(channelName);
    final range = await resolveRowRange(
      channel,
      startSeconds: window.startSeconds,
      endSeconds: window.endSeconds,
    );
    if (range == null) return const [];

    final columns = channel.valueColumns;
    final rows = await _exec.rows(decimateSql(
      channel,
      _catalog.masterRowCount,
      rowStart: range.start,
      rowEndExclusive: range.endExclusive,
      buckets: window.buckets,
      columns: columns,
    ));

    final count = rows.length;
    final times = Float64List(count);
    final lows = [for (var _ in columns) Float64List(count)];
    final highs = [for (var _ in columns) Float64List(count)];

    for (var r = 0; r < count; r++) {
      final row = rows[r];
      times[r] = (row[1] as num).toDouble();
      for (var c = 0; c < columns.length; c++) {
        // Layout: bucket, t, lo_0, hi_0, lo_1, hi_1, ...
        lows[c][r] = (row[2 + c * 2] as num).toDouble();
        highs[c][r] = (row[3 + c * 2] as num).toDouble();
      }
    }

    return [
      for (var c = 0; c < columns.length; c++)
        TraceSeries(
          channelName: channel.name,
          unit: channel.unit,
          frequencyHz: channel.frequencyHz,
          valueColumn: columns[c],
          times: times,
          lows: lows[c],
          highs: highs[c],
        ),
    ];
  }

  /// Full-resolution samples over a window, without decimation.
  ///
  /// For short windows on slow channels where every sample matters and there
  /// are few of them — the track-map path (`GPS Latitude`/`Longitude`, 10 Hz,
  /// ~640 samples per lap) above all. Guarded by [maxSamples] because the same
  /// call against a 100 Hz channel over a full session is exactly what §9.5
  /// forbids, and a guard that throws is better than one that quietly returns
  /// two million points.
  Future<List<TraceSeries>> readFullResolution(
    String channelName, {
    required double startSeconds,
    required double endSeconds,
    int maxSamples = 20000,
  }) async {
    final channel = _requireChannel(channelName);
    final range = await resolveRowRange(
      channel,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
    if (range == null) return const [];

    final span = range.endExclusive - range.start;
    if (span > maxSamples) {
      throw ArgumentError(
        'Refusing to read $span full-resolution samples of "$channelName" '
        '(limit $maxSamples). Use readTrace() — §9.5 requires decimation at '
        'this scale.',
      );
    }

    final columns = channel.valueColumns;
    final rows = await _exec.rows(timedChannelSql(
      channel,
      _catalog.masterRowCount,
      rowRange: range,
    ));

    final count = rows.length;
    final times = Float64List(count);
    final values = [for (var _ in columns) Float64List(count)];
    for (var r = 0; r < count; r++) {
      times[r] = (rows[r][0] as num).toDouble();
      for (var c = 0; c < columns.length; c++) {
        values[c][r] = (rows[r][1 + c] as num).toDouble();
      }
    }

    return [
      for (var c = 0; c < columns.length; c++)
        TraceSeries(
          channelName: channel.name,
          unit: channel.unit,
          frequencyHz: channel.frequencyHz,
          valueColumn: columns[c],
          times: times,
          // Full resolution: each point is its own min and max.
          lows: values[c],
          highs: values[c],
        ),
    ];
  }

  /// Whether a channel is a flat line in this session (§5.4, §8.7).
  ///
  /// Checked against content, never table presence: all three samples carry
  /// all three energy tables, so presence proves nothing about class — but
  /// `SoC` and `Regen Rate` are all-zero in the GT3 files, and plotting them
  /// there would render absence as data.
  Future<bool> isDegenerate(String channelName) async {
    final channel = _requireChannel(channelName);
    final value = await _exec.scalar(isDegenerateSql(channel));
    return value == true;
  }

  EventDescriptor _requireEvent(String name) {
    final event = _catalog.event(name);
    if (event == null) {
      throw SchemaMismatchException(
        'This session has no "$name" event.',
        detail: 'event not in eventsList',
      );
    }
    return event;
  }

  /// An event's changes over a window, as a step signal.
  ///
  /// Loaded in full rather than decimated — event tables are sparse enough
  /// that a whole race fits in low thousands of rows (§9.5) — and always
  /// including the last change *before* the window, because an event that
  /// never changed inside a window still has a value throughout it. Without
  /// that row, a lap where the driver held one gear renders as no gear at
  /// all; the fixture's lap 4 is exactly that case.
  Future<StepSeries> readEventWindow(
    String eventName, {
    required double startSeconds,
    required double endSeconds,
    String? valueColumn,
  }) async {
    final event = _requireEvent(eventName);
    final column = valueColumn ?? event.valueColumns.first;
    final rows = await _exec.rows(eventWindowSql(
      event,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
      columns: [column],
    ));
    return StepSeries.fromRows(
      [for (final row in rows) ((row[0] as num).toDouble(), row[1])],
      eventName: event.name,
      unit: event.unit,
    );
  }

  /// Default per-event row cap for [readEventLog].
  ///
  /// Sized from measurement, not taste: across the three real samples the
  /// busiest event table holds 7,212 rows for a full session (`SurfaceTypes`,
  /// Sebring Race, 22.5 min) and all 42 together hold 4,280–20,304. A 10,000
  /// cap therefore clips nothing that has actually been seen, while bounding
  /// the §5.5 endurance case — where the same table extrapolates into six
  /// figures on its own — to something a table widget can hold.
  static const defaultMaxRowsPerEvent = 10000;

  /// Every recorded change across every event table, in time order (§8.12).
  ///
  /// Reads each table separately rather than as one `UNION ALL`, which is the
  /// faster *and* the more faithful option: measured on the Sebring Race
  /// sample, 42 separate reads return all 20,304 rows in 62 ms against 144 ms
  /// for the union, and they preserve the values' types. A union has to cast
  /// its branches to one common type, and the tables are a mix of BOOLEAN,
  /// four unsigned integer widths, TINYINT and FLOAT — so the cast that makes
  /// them unionable is exactly the one that turns `false` into `0`.
  ///
  /// The cap is **per event**, not global. A global budget spent in catalog
  /// order would drop whole signals off the end of the alphabet while the
  /// busiest table at the front consumed it, producing a log that is missing
  /// entire events rather than the tail of a few — and missing without any
  /// clue as to which. Each table gets its own ceiling instead, and
  /// [EventLog.clipped] names the ones that hit it.
  Future<EventLog> readEventLog({
    double? startSeconds,
    double? endSeconds,
    Iterable<String>? names,
    int maxRowsPerEvent = defaultMaxRowsPerEvent,
  }) async {
    final events = names == null
        ? _catalog.events
        : [for (final name in names) _requireEvent(name)];

    final collected = <TelemetryEvent>[];
    final clipped = <String>[];
    for (final event in events) {
      final columns = event.valueColumns;
      // One row past the cap, so a full result is distinguishable from a
      // truncated one without a second COUNT(*) round trip.
      final rows = await _exec.rows(eventLogSql(
        event,
        startSeconds: startSeconds,
        endSeconds: endSeconds,
        columns: columns,
        limit: maxRowsPerEvent + 1,
      ));
      final overflowed = rows.length > maxRowsPerEvent;
      if (overflowed) clipped.add(event.name);
      final kept = overflowed ? rows.take(maxRowsPerEvent) : rows;
      for (final row in kept) {
        collected.add(TelemetryEvent(
          name: event.name,
          unit: event.unit,
          timeSeconds: (row[0] as num).toDouble(),
          values: row.sublist(1),
        ));
      }
    }

    // Sorted here rather than in SQL: the rows arrive as 42 already-ordered
    // runs, and merging them in Dart avoids asking DuckDB to union and re-sort
    // types it would have to flatten first.
    collected.sort((a, b) {
      final byTime = a.timeSeconds.compareTo(b.timeSeconds);
      return byTime != 0 ? byTime : a.name.compareTo(b.name);
    });
    return EventLog(events: collected, clipped: clipped);
  }

  /// An event's value as of every sample of a channel, over a row range.
  ///
  /// Uses `ASOF LEFT JOIN`; a null event value means "no value at or before
  /// this sample", which is information rather than an error to hide.
  Future<List<(double, double, Object?)>> readEventAsOfChannel(
    String channelName, {
    required String eventName,
    required double startSeconds,
    required double endSeconds,
  }) async {
    final channel = _requireChannel(channelName);
    final event = _requireEvent(eventName);
    final range = await resolveRowRange(
      channel,
      startSeconds: startSeconds,
      endSeconds: endSeconds,
    );
    if (range == null) return const [];

    return [
      for (final row in await _exec.rows(eventAsOfChannelSql(
        channel,
        _catalog.masterRowCount,
        event: event,
        rowRange: range,
      )))
        ((row[0] as num).toDouble(), (row[1] as num).toDouble(), row[2]),
    ];
  }
}
