/// Tyres and brakes, per corner and per lap (SPEC.md §8.6).
///
/// Everything here is arithmetic over per-lap aggregates the repository
/// computes in SQL — one multi-column `lapStatsSql` scan per channel, all four
/// corners at once (`TelemetryRepository.readLapStatsByColumn`) — so the
/// derivations are plain functions a `flutter test` reaches without a DuckDB
/// connection, the same split the fuel view makes.
///
/// ## Why the per-lap mean is the summary
///
/// Race tyre temperatures move only 1.3–2.6 °C within a lap and the zone
/// temperatures lag the lateral load by 2–2.8 s (§15.5 findings) — they are a
/// slow tread temperature, not a surface flash reading — so lap-to-lap drift
/// is the signal and a lap's mean is its honest one-number summary. Its min
/// and max come along as the band a trend chart draws around it.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../fuel_energy_strategy/application/fuel_energy.dart';
import 'tyre_setup.dart';

part 'tire_brake_report.g.dart';

const tyrePressureChannelName = 'TyresPressure';
const treadLeftChannelName = 'TyresTempLeft';
const treadCentreChannelName = 'TyresTempCentre';
const treadRightChannelName = 'TyresTempRight';
const carcassChannelName = 'TyresCarcassTemp';
const rimChannelName = 'TyresRimTemp';
const tyreWearChannelName = 'Tyres Wear';
const brakeTempChannelName = 'Brakes Temp';

const brakeBiasEventName = 'Brake Bias Rear';
const brakeMigrationEventName = 'Brake Migration';
const tyreCompoundEventName = 'TyresCompound';

/// What the trend charts can show, one at a time.
///
/// One metric at a time is §9.7.1's one-channel-per-frame rule applied to the
/// small multiples: the four corners of *one* quantity share a y-scale and can
/// be compared honestly; two quantities in one frame would need a second axis
/// or a second colour, and invite reading a correlation off the overlap.
enum TyreMetric {
  pressure('Pressure', 'kPa'),
  tread('Tread temp', '°C'),
  carcass('Carcass', '°C'),
  wear('Wear', '%'),
  brake('Brake temp', '°C');

  const TyreMetric(this.label, this.unit);

  final String label;

  /// Display unit. The catalog writes temperatures as `C`.
  final String unit;
}

/// A channel the view does not draw, and why — stated on screen rather than
/// left as a missing chart (§5.4: a flat line reads as data).
class HiddenChannel {
  const HiddenChannel(this.name, this.reason);

  final String name;
  final String reason;

  @override
  String toString() => '$name: $reason';
}

/// One per-corner channel summarised per lap, all four corners.
class CornerSeries {
  CornerSeries({
    required this.channelName,
    required Map<Corner, List<LapChannelStats>> byCorner,
  }) : _byCorner = {
          for (final MapEntry(key: corner, value: stats) in byCorner.entries)
            corner: {for (final s in stats) s.lapIndex: s},
        };

  final String channelName;
  final Map<Corner, Map<int, LapChannelStats>> _byCorner;

  LapChannelStats? at(Corner corner, int lapIndex) =>
      _byCorner[corner]?[lapIndex];

  Iterable<LapChannelStats> of(Corner corner) =>
      _byCorner[corner]?.values ?? const [];

  bool get isEmpty => Corner.values.every((corner) => of(corner).isEmpty);

  /// One value across the whole session on [corner] — every lap's minimum and
  /// maximum equal to the first lap's.
  bool isFlat(Corner corner) {
    final stats = of(corner);
    if (stats.isEmpty) return true;
    final value = stats.first.min;
    return stats.every((s) => s.min == value && s.max == value);
  }

  bool get isFlatEverywhere => Corner.values.every(isFlat);
}

/// A tyre's tread temperatures over one lap, as inner / centre / outer.
///
/// Built only through [TreadSeries.at], which resolves the car-frame
/// `TyresTempLeft`/`Right` edges to inner and outer via [Corner.innerEdge] —
/// no screen decides that for itself.
class TreadTemps {
  const TreadTemps({
    required this.inner,
    required this.centre,
    required this.outer,
  });

  final LapChannelStats inner;
  final LapChannelStats centre;
  final LapChannelStats outer;

  /// The three zones' lap means, averaged: the tyre's one tread figure.
  double get mean => (inner.mean + centre.mean + outer.mean) / 3;

  /// The coolest and hottest reading of any zone in the lap.
  double get min => [inner.min, centre.min, outer.min].reduce(_min);
  double get max => [inner.max, centre.max, outer.max].reduce(_max);

  /// Inner minus outer: positive when the camber is loading the inside edge,
  /// which is every corner of every flying lap in the three samples.
  double get spread => inner.mean - outer.mean;
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;

/// The three tread-zone channels, read together.
class TreadSeries {
  const TreadSeries({
    required this.left,
    required this.centre,
    required this.right,
  });

  final CornerSeries left;
  final CornerSeries centre;
  final CornerSeries right;

  CornerSeries _edge(CarSide side) => side == CarSide.left ? left : right;

  TreadTemps? at(Corner corner, int lapIndex) {
    final inner = _edge(corner.innerEdge).at(corner, lapIndex);
    final middle = centre.at(corner, lapIndex);
    final outer = _edge(corner.outerEdge).at(corner, lapIndex);
    if (inner == null || middle == null || outer == null) return null;
    return TreadTemps(inner: inner, centre: middle, outer: outer);
  }
}

/// A driver-adjustable setting as the event table recorded it (§5.1): one row
/// per change, and usually one row for the whole session.
class RecordedSetting {
  RecordedSetting(StepSeries series)
      : initial = series.values.first,
        changes = series.length - 1,
        min = series.values.reduce(_min),
        max = series.values.reduce(_max);

  final double initial;

  /// How many times the value changed after the first row.
  final int changes;

  final double min;
  final double max;

  bool get isConstant => changes == 0;
}

/// One lap of one corner, on one metric — a trend chart's point and a table
/// cell.
class MetricLap {
  const MetricLap({
    required this.lap,
    required this.value,
    this.low,
    this.high,
    this.exclusion,
  });

  final Lap lap;

  /// The lap's mean — or, for wear, what the lap used. Null when the lap
  /// holds no samples.
  final double? value;

  /// The lap's lowest and highest reading, where the metric has a range.
  final double? low;
  final double? high;

  /// Why the lap is drawn grey; null for a representative lap.
  final UsageExclusion? exclusion;

  bool get muted => exclusion != null;
}

/// How a lap's exclusion reads on this screen.
///
/// Shares the fuel view's vocabulary, with the one word that means something
/// else here: a tyre whose wear level *rises* across a lap was changed, not
/// refilled.
String exclusionLabel(UsageExclusion exclusion) => switch (exclusion) {
      UsageExclusion.refilled => 'tyres changed',
      _ => exclusion.label,
    };

/// Everything one corner card shows for one lap.
class CornerSnapshot {
  const CornerSnapshot({
    required this.corner,
    this.pressure,
    this.coldPressure,
    this.tread,
    this.carcass,
    this.rim,
    this.wear,
    this.brake,
  });

  final Corner corner;
  final LapChannelStats? pressure;
  final SetupValue? coldPressure;
  final TreadTemps? tread;
  final LapChannelStats? carcass;
  final LapChannelStats? rim;
  final LapUsage? wear;
  final LapChannelStats? brake;

  /// Hot minus cold: how much the tyre gained over its set pressure.
  double? get pressureGain => switch ((pressure, coldPressure?.number)) {
        (final hot?, final cold?) => hot.mean - cold,
        _ => null,
      };

  /// The wear level at the end of the lap — the next lap's first reading, or
  /// this lap's last when no later lap has one.
  double? get wearLeft => switch ((wear?.levelAtStart, wear?.used)) {
        (final start?, final used?) => start - used,
        _ => null,
      };
}

/// Everything the tyres & brakes view shows for one session.
class TireBrakeReport {
  const TireBrakeReport({
    required this.laps,
    required this.setup,
    this.pitVisits = const [],
    this.pressure,
    this.tread,
    this.carcass,
    this.rim,
    this.wear,
    this.brakes,
    this.brakeBiasRear,
    this.brakeMigration,
    this.compoundChanges = 0,
    this.hidden = const [],
  });

  final List<Lap> laps;
  final TyreSetup setup;
  final List<PitVisit> pitVisits;

  /// `TyresPressure`, kPa, 10 Hz.
  final CornerSeries? pressure;

  /// `TyresTempLeft/Centre/Right`, °C, 100 Hz.
  final TreadSeries? tread;

  /// `TyresCarcassTemp`, °C, 5 Hz.
  final CornerSeries? carcass;

  /// `TyresRimTemp`, °C, 50 Hz.
  ///
  /// Shown on the cards and not charted: it is the wheel, not the tyre, and
  /// trails the carcass by 1.3–9.5 °C on every lap of the Race sample.
  final CornerSeries? rim;

  /// `Tyres Wear` per corner, % remaining (100 new), differenced lap to lap
  /// exactly as the fuel view differences fuel — see [ResourceUsage.derive].
  final Map<Corner, ResourceUsage>? wear;

  /// `Brakes Temp`, °C, 50 Hz.
  final CornerSeries? brakes;

  /// `Brake Bias Rear`: the rear share of brake force, e.g. 0.4875.
  final RecordedSetting? brakeBiasRear;

  /// `Brake Migration`: negative is forward — the Spa sample's −0.025 is its
  /// setup's `2.5% F`.
  final RecordedSetting? brakeMigration;

  /// Changes the `TyresCompound` event recorded on any corner after its first
  /// row. Its values are an index the setup does not decode (0 on every
  /// corner of all three samples, whose setups say Medium, Soft and Medium at
  /// setup indices 3, 1 and 1), so only *whether* it changed is used.
  final int compoundChanges;

  /// Channels the view leaves out, with the reason it says so.
  final List<HiddenChannel> hidden;

  /// The lap the corner cards open on: the last complete lap, since the
  /// state a stint *ends* in is what the next stint inherits. Falls back to
  /// the final lap when no lap is complete.
  Lap? get defaultLap {
    for (final lap in laps.reversed) {
      if (!lap.isOutLap && !lap.isOpenEnded) return lap;
    }
    return laps.isEmpty ? null : laps.last;
  }

  /// Why [lap] is drawn grey on a temperature, pressure or brake trend: the
  /// garage lap, the lap the recording cut off, and any lap with time in the
  /// pit lane — none describes a racing lap's tyres.
  UsageExclusion? exclusionOf(Lap lap) => lap.isOutLap
      ? UsageExclusion.outLap
      : lap.isOpenEnded
          ? UsageExclusion.incomplete
          : pitVisits.any((visit) => visit.overlaps(lap))
              ? UsageExclusion.pitLane
              : null;

  bool isAvailable(TyreMetric metric) => switch (metric) {
        TyreMetric.pressure => pressure != null,
        TyreMetric.tread => tread != null,
        TyreMetric.carcass => carcass != null,
        TyreMetric.wear => wear != null,
        TyreMetric.brake => brakes != null,
      };

  List<TyreMetric> get availableMetrics =>
      [for (final metric in TyreMetric.values) if (isAvailable(metric)) metric];

  /// [metric] on [corner], one entry per lap of the session — a lap with no
  /// data keeps its slot with a null value, so lap numbering never jumps.
  List<MetricLap> series(TyreMetric metric, Corner corner) {
    if (metric == TyreMetric.wear) {
      final usage = wear?[corner];
      if (usage == null) return const [];
      return [
        for (final lap in usage.laps)
          MetricLap(
            lap: lap.lap,
            // A tyre change is a large negative "use" that would flatten every
            // real bar; it keeps its slot, empty, and says why.
            value: lap.exclusion == UsageExclusion.refilled ? null : lap.used,
            exclusion: lap.exclusion,
          ),
      ];
    }
    MetricLap point(Lap lap, double? value, double? low, double? high) =>
        MetricLap(
          lap: lap,
          value: value,
          low: low,
          high: high,
          exclusion: value == null ? UsageExclusion.noData : exclusionOf(lap),
        );
    if (metric == TyreMetric.tread) {
      final series = tread;
      if (series == null) return const [];
      return [
        for (final lap in laps)
          if (series.at(corner, lap.index) case final t?)
            point(lap, t.mean, t.min, t.max)
          else
            point(lap, null, null, null),
      ];
    }
    final series = switch (metric) {
      TyreMetric.pressure => pressure,
      TyreMetric.carcass => carcass,
      TyreMetric.brake => brakes,
      _ => null,
    };
    if (series == null) return const [];
    return [
      for (final lap in laps)
        if (series.at(corner, lap.index) case final s?)
          point(lap, s.mean, s.min, s.max)
        else
          point(lap, null, null, null),
    ];
  }

  /// One y-range for all four corners of [metric], so the small multiples
  /// compare honestly: a scale per corner would stretch a 2 °C wobble on a
  /// cool tyre to the height of a 10 °C climb on a hot one.
  ///
  /// Spans every drawn lap, muted ones included — they are drawn, so the scale
  /// has to hold them. Wear per lap is an amount and starts at zero.
  ({double min, double max})? sharedRange(TyreMetric metric) {
    double? lo;
    double? hi;
    for (final corner in Corner.values) {
      for (final point in series(metric, corner)) {
        final low = point.low ?? point.value;
        final high = point.high ?? point.value;
        if (low != null) lo = lo == null ? low : _min(lo, low);
        if (high != null) hi = hi == null ? high : _max(hi, high);
      }
    }
    if (lo == null || hi == null) return null;
    return metric == TyreMetric.wear
        ? (min: 0, max: _max(hi, 0))
        : (min: lo, max: hi);
  }

  /// All four corners on [lap].
  Map<Corner, CornerSnapshot> snapshot(Lap lap) => {
        for (final corner in Corner.values)
          corner: CornerSnapshot(
            corner: corner,
            pressure: pressure?.at(corner, lap.index),
            coldPressure: setup.coldPressure[corner],
            tread: tread?.at(corner, lap.index),
            carcass: carcass?.at(corner, lap.index),
            rim: rim?.at(corner, lap.index),
            wear: _wearOn(corner, lap),
            brake: brakes?.at(corner, lap.index),
          ),
      };

  LapUsage? _wearOn(Corner corner, Lap lap) {
    for (final usage in wear?[corner]?.laps ?? const <LapUsage>[]) {
      if (usage.lap.index == lap.index) return usage;
    }
    return null;
  }

  /// The corner whose carcass ran hottest on [lap], when it clearly did.
  ///
  /// The carcass rather than the tread, because it is the slow, bulk
  /// temperature — the one that says which tyre is doing the most work,
  /// where a tread zone also carries the camber's inner-edge bias. "Clearly"
  /// is a lead of at least 0.5 °C over the next corner, so a garage lap at
  /// ambient does not crown a winner by a hundredth of a degree.
  Corner? hottestOn(Lap lap) => _leader(
        {
          for (final corner in Corner.values)
            corner: ?carcass?.at(corner, lap.index)?.mean,
        },
        margin: 0.5,
        highest: true,
      );

  /// The corner with the least tread left after [lap], when it clearly has —
  /// a lead of at least 0.1 percentage points.
  Corner? mostWornOn(Lap lap) {
    final corners = snapshot(lap);
    return _leader(
      {for (final corner in Corner.values) corner: ?corners[corner]!.wearLeft},
      margin: 0.1,
      highest: false,
    );
  }

  static Corner? _leader(
    Map<Corner, double> values, {
    required double margin,
    required bool highest,
  }) {
    if (values.length < 2) return null;
    final ranked = values.entries.toList()
      ..sort((a, b) =>
          highest ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    final lead = (ranked[0].value - ranked[1].value).abs();
    return lead >= margin ? ranked[0].key : null;
  }

  /// The range the tread-temperature colour ramp spans: the lowest and
  /// highest zone mean of any corner on any lap.
  ///
  /// Session-wide rather than per lap, so stepping between laps shows real
  /// change — a per-lap range would repaint the hottest zone of every lap the
  /// same colour however cold that lap ran.
  ({double min, double max})? get treadRampRange {
    final series = tread;
    if (series == null) return null;
    double? lo;
    double? hi;
    for (final lap in laps) {
      for (final corner in Corner.values) {
        final t = series.at(corner, lap.index);
        if (t == null) continue;
        for (final zone in [t.inner, t.centre, t.outer]) {
          lo = lo == null ? zone.mean : _min(lo, zone.mean);
          hi = hi == null ? zone.mean : _max(hi, zone.mean);
        }
      }
    }
    return lo == null || hi == null ? null : (min: lo, max: hi);
  }
}

/// One tread-ramp range over several sessions' reports, so their cards
/// share a scale: Compare's Base and Target side by side (comparison
/// proposal §7). Each report's own range is session-wide; this is their
/// union, so neither card's colours depend on which lap the other shows.
({double min, double max})? sharedTreadRampRange(
    Iterable<TireBrakeReport> reports) {
  double? lo;
  double? hi;
  for (final report in reports) {
    final range = report.treadRampRange;
    if (range == null) continue;
    lo = lo == null ? range.min : _min(lo, range.min);
    hi = hi == null ? range.max : _max(hi, range.max);
  }
  return lo == null || hi == null ? null : (min: lo, max: hi);
}

/// See `providers.dart`: every failure this layer produces is deterministic,
/// so retrying one on a timer only repeats it.
Duration? _neverRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<TireBrakeReport> tireBrakeReport(
  Ref ref,
  TelemetrySource source,
) async {
  final laps = await ref.watch(lapsProvider(source).future);
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final catalog = await ref.watch(telemetryCatalogProvider(source).future);
  final telemetry = await ref.watch(telemetryRepositoryProvider(source).future);
  final hidden = <HiddenChannel>[];

  Future<CornerSeries?> read(String name) async {
    final channel = catalog.channel(name);
    if (channel == null) {
      hidden.add(HiddenChannel(name, 'not in this recording'));
      return null;
    }
    if (channel.valueColumnCount != Corner.values.length) {
      hidden.add(HiddenChannel(name, 'not recorded per corner in this file'));
      return null;
    }
    final byColumn = await telemetry.readLapStatsByColumn(
      name,
      valueColumns: Corner.valueColumns,
    );
    final series = CornerSeries(
      channelName: name,
      byCorner: {
        for (final corner in Corner.values)
          corner: byColumn[corner.valueColumn]!,
      },
    );
    if (series.isEmpty) {
      hidden.add(HiddenChannel(name, 'no samples inside any lap'));
      return null;
    }
    if (series.isFlatEverywhere) {
      hidden.add(HiddenChannel(
          name, 'one value all session on every corner — not drawn flat'));
      return null;
    }
    return series;
  }

  Future<RecordedSetting?> setting(String name, {String? column}) async {
    if (!catalog.hasEvent(name)) return null;
    final series = await telemetry.readEventWindow(
      name,
      startSeconds: catalog.origin,
      endSeconds: catalog.endSeconds + 1,
      valueColumn: column,
    );
    return series.length == 0 ? null : RecordedSetting(series);
  }

  final pitVisits = catalog.hasEvent(inPitsEventName)
      ? pitVisitsFrom(await telemetry.readEventWindow(
          inPitsEventName,
          startSeconds: catalog.origin,
          endSeconds: catalog.endSeconds + 1,
        ))
      : const <PitVisit>[];

  final pressure = await read(tyrePressureChannelName);
  final left = await read(treadLeftChannelName);
  final centre = await read(treadCentreChannelName);
  final right = await read(treadRightChannelName);
  final carcass = await read(carcassChannelName);
  final rim = await read(rimChannelName);
  final wearSeries = await read(tyreWearChannelName);
  final brakes = await read(brakeTempChannelName);

  var compoundChanges = 0;
  if (catalog.event(tyreCompoundEventName) case final event?) {
    for (final column in event.valueColumns) {
      compoundChanges +=
          (await setting(tyreCompoundEventName, column: column))?.changes ?? 0;
    }
  }

  return TireBrakeReport(
    laps: laps,
    setup: TyreSetup.fromJson(metadata.carSetupJson),
    pitVisits: pitVisits,
    pressure: pressure,
    // The inner/outer mapping needs all three zones; a file missing one edge
    // is stated in [hidden] rather than drawn as a two-zone tyre.
    tread: left != null && centre != null && right != null
        ? TreadSeries(left: left, centre: centre, right: right)
        : null,
    carcass: carcass,
    rim: rim,
    wear: wearSeries == null
        ? null
        : {
            for (final corner in Corner.values)
              corner: ResourceUsage.derive(
                name: 'Wear ${corner.short}',
                unit: '%',
                laps: laps,
                stats: wearSeries.of(corner).toList(),
                pitVisits: pitVisits,
              ),
          },
    brakes: brakes,
    brakeBiasRear: await setting(brakeBiasEventName),
    brakeMigration: await setting(brakeMigrationEventName),
    compoundChanges: compoundChanges,
    hidden: hidden,
  );
}
