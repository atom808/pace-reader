/// Time-aligned, decimated channel reads (SPEC.md §9.2, §9.5).
library;

import 'dart:typed_data';

import '../../core/errors.dart';
import '../duckdb/channel_queries.dart';
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
    final event = _catalog.event(eventName);
    if (event == null) {
      throw SchemaMismatchException(
        'This session has no "$eventName" event.',
        detail: 'event not in eventsList',
      );
    }
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
