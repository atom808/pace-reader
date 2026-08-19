import 'package:freezed_annotation/freezed_annotation.dart';

part 'telemetry_catalog.freezed.dart';

/// The master clock every channel's row grid is a decimation of (SPEC.md
/// §5.1/§5.2). Despite the name it is just the elapsed-seconds clock, and
/// it's the only channel carrying real timestamps.
const masterChannelName = 'GPS Time';

/// The master grid's rate. Every on-grid channel's frequency divides this
/// exactly, which is what makes the row→row mapping in `time_axis.dart` an
/// integer stride rather than an approximation.
const masterFrequencyHz = 100;

/// One row of `channelsList` (§5.1): a fixed-rate signal with **no timestamp
/// column** — row order is the sample sequence.
@freezed
abstract class ChannelDescriptor with _$ChannelDescriptor {
  const ChannelDescriptor._();

  const factory ChannelDescriptor({
    required String name,
    /// The **declared** rate from the catalog. Nominal, not exact: two
    /// channels declare 7 Hz and sample at ~7.0171 Hz (§5.2), so this is
    /// safe for display/labelling and unsafe for timing. Use
    /// [ridesMasterGrid] to decide which.
    required int frequencyHz,
    required String unit,
    /// 1 for a single-value channel, 4 for a per-corner one (`value1`..
    /// `value4`). Read from the table, not guessed from the name.
    required int valueColumnCount,
    /// Row count in this file — needed to derive timestamps, and to detect a
    /// channel whose declared frequency doesn't reproduce it.
    required int rowCount,
  }) = _ChannelDescriptor;

  bool get isPerCorner => valueColumnCount == 4;

  /// The `value`/`value1`..`valueN` column names, in order.
  List<String> get valueColumns => valueColumnCount == 1
      ? const ['value']
      : List.generate(valueColumnCount, (i) => 'value${i + 1}');

  /// Whether this channel is an exact integer decimation of the master grid
  /// — §5.1's identity `rowCount == ceil(masterRows * frequencyHz / 100)`.
  ///
  /// This is the single decision that picks a timing strategy: true means
  /// the declared frequency is trustworthy and row `i` sits at master row
  /// `i * masterStride` exactly; false means it isn't and timestamps have to
  /// be interpolated across the row-count ratio instead. Confirmed true for
  /// 54 of 56 channels in all three samples, false only for
  /// `Engine Oil Temp`/`Engine Water Temp`.
  bool ridesMasterGrid(int masterRows) =>
      masterFrequencyHz % frequencyHz == 0 &&
      rowCount == (masterRows * frequencyHz / masterFrequencyHz).ceil();

  /// Master rows per sample. Only meaningful when [ridesMasterGrid].
  int get masterStride => masterFrequencyHz ~/ frequencyHz;

  /// A channel carrying one distinct value across the whole session is
  /// degenerate and must not be plotted — §5.4/§8.7's guard that stops a GT3
  /// session rendering a flat zero line labelled "State of Charge".
  bool get isMaster => name == masterChannelName;
}

/// One row of `eventsList` (§5.1): sparse, with an explicit `ts` in elapsed
/// seconds and one row per *change*.
@freezed
abstract class EventDescriptor with _$EventDescriptor {
  const EventDescriptor._();

  const factory EventDescriptor({
    required String name,
    required String unit,
    required int valueColumnCount,
    required int rowCount,
  }) = _EventDescriptor;

  bool get isPerCorner => valueColumnCount == 4;

  List<String> get valueColumns => valueColumnCount == 1
      ? const ['value']
      : List.generate(valueColumnCount, (i) => 'value${i + 1}');

  /// "One row, never changed" is the *norm*, not a footnote: 21–25 of the 42
  /// event tables hold exactly one row in each sample (§5.1). Event-driven
  /// UI has to render this as a constant rather than an empty chart.
  bool get isConstant => rowCount <= 1;
}

/// The catalog, read from `channelsList`/`eventsList` at open time rather
/// than hardcoded (SPEC.md §9.2) so a future LMU version can add or remove
/// signals without breaking the app.
@freezed
abstract class TelemetryCatalog with _$TelemetryCatalog {
  const TelemetryCatalog._();

  const factory TelemetryCatalog({
    required List<ChannelDescriptor> channels,
    required List<EventDescriptor> events,
    /// `GPS Time`'s row count — the master grid's length, and the divisor in
    /// every channel's timestamp derivation.
    required int masterRowCount,
    /// The file's own t=0: `GPS Time`'s first value, which §5.2 confirms
    /// equals `MIN(ts)` of all 42 event tables to the bit. Per-file and
    /// wildly variable (381.09 / 34.57 / 23.60 s across the samples), so it
    /// is always read, never assumed.
    required double origin,
  }) = _TelemetryCatalog;

  ChannelDescriptor? channel(String name) {
    for (final c in channels) {
      if (c.name == name) return c;
    }
    return null;
  }

  EventDescriptor? event(String name) {
    for (final e in events) {
      if (e.name == name) return e;
    }
    return null;
  }

  bool hasChannel(String name) => channel(name) != null;
  bool hasEvent(String name) => event(name) != null;

  /// Channels whose declared frequency can't be trusted for timing (§5.2).
  /// Named rather than tolerated generically: a *third* one appearing in a
  /// future LMU version is worth surfacing, not silently absorbing.
  List<ChannelDescriptor> get offGridChannels =>
      channels.where((c) => !c.ridesMasterGrid(masterRowCount)).toList();
}
