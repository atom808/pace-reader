/// Compare's map: both laps in one frame, the Target's ghost, and the Time
/// axis readout (comparison proposal §6).
///
/// The map draws; it never measures. Every number this file puts on screen —
/// the delta at Base's position, how far ahead the Target is — comes from
/// the two laps' own `Lap Dist` against their own clocks, never from the
/// map's metres and never from Δ × speed, which is 2.6% out at the median and
/// 25% at worst (§6).
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/formatting.dart';
import '../../../data/repositories/lap_telemetry.dart';
import '../../../widgets/charting/charting.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import '../domain/comparability.dart';

part 'compare_map.g.dart';

/// Whether the map shows the Target's ghost on the Time axis. Kept for the
/// run.
@Riverpod(keepAlive: true)
class GhostShown extends _$GhostShown {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

/// The Time axis readout at one moment of the lap (§6 "Footer readout").
class TimeReadout {
  const TimeReadout({required this.tau, this.delta, this.gap});

  /// Seconds since Base's own start: τ = t − Base's re-anchored start.
  final double tau;

  /// The delta at Base's position: `LapDelta.deltaAt` at Base's `Lap Dist`
  /// — the same "trailing" value the Delta trace draws there. Null off the
  /// two laps' shared stretch.
  final double? delta;

  /// The Target's `Lap Dist` at τ less Base's: + when the Target is ahead.
  /// Null when either lap is not on its lap at τ.
  final double? gap;

  /// "τ 0:20.310 · Δ +0.264 s at Base's position · Target 7.4 m ahead".
  String get text => [
    'τ ${formatLapTime(tau)}',
    if (delta case final delta?) "Δ ${formatDelta(delta)} s at Base's position",
    if (gap case final gap?) gapText(gap),
  ].join(' · ');

  /// "Target 7.4 m ahead", "Target 3.0 m behind", or "level" under 0.05 m.
  static String gapText(double gap) {
    final metres = gap.abs().toStringAsFixed(1);
    if (metres == '0.0') return 'Target level with Base';
    return gap > 0 ? 'Target $metres m ahead' : 'Target $metres m behind';
  }
}

/// Base and the Target on one map.
class CompareMap {
  const CompareMap({
    required this.base,
    required this.overview,
    required this.comparison,
    this.baseAxis,
    this.target,
    this.targetHidden,
    this.ghostWithheld,
  });

  /// Both laps in Base's frame (§6): Base's path from its chart — projected
  /// about its own centroid, which is the shared origin — and the Target's
  /// projected about the same point and placed on Base's clock.
  ///
  /// The Target's path is drawn only while the centre gate passes (§4). Past
  /// it, or without its channels, the Target is marked on Base's line at its
  /// own `Lap Dist`, and [targetHidden] says why.
  factory CompareMap.of({
    required LapChart chart,
    required LapTelemetry target,
    required LineCheck line,
  }) {
    final comparison = chart.comparison!;
    final base = chart.trackPath!;
    final drawn =
        line.withheld == null &&
        target.hasPosition &&
        target.latitude!.isNotEmpty;
    final targetPath = drawn
        ? TrackPath.build(
            latitude: target.latitude!,
            longitude: target.longitude!,
            axis: chart.axis,
            distanceAxis: comparison.referenceAxis,
            origin: base.projection.origin,
            timeShift: comparison.timeShift,
          )
        : null;
    final overview = targetPath == null || targetPath.isEmpty
        ? base.projection.boundsMetres
        : base.projection.boundsMetres.expandToInclude(
            targetPath.projection.boundsMetres,
          );

    final String? ghostWithheld;
    if (comparison.alignment.withholdsDistance) {
      ghostWithheld =
          "No ghost: the two files' sector lines sit "
          '${comparison.alignment.worstOffset!.abs().toStringAsFixed(1)} m '
          'apart, so neither lap can be placed by distance on the other.';
    } else if (targetPath == null &&
        !(comparison.referenceAxis?.isUsable ?? false)) {
      ghostWithheld =
          "No ghost: the Target's line is not drawn, and its lap distance "
          'cannot place it on Base\'s.';
    } else {
      ghostWithheld = null;
    }

    return CompareMap(
      base: base,
      overview: overview,
      comparison: comparison,
      baseAxis: chart.distanceAxis,
      target: targetPath,
      targetHidden: drawn
          ? null
          : "The Target's line is not drawn: ${line.withheld ?? 'its lap recorded no GPS'}. "
                "It is marked on Base's line at its own lap distance.",
      ghostWithheld: ghostWithheld,
    );
  }

  final TrackPath base;

  /// The Target's path in Base's frame; null when it is not drawn.
  final TrackPath? target;

  /// Why [target] is null, for the map's caption.
  final String? targetHidden;

  /// Both paths' combined extent: what the whole-lap map is fitted to.
  final Rect overview;

  final LapComparison comparison;

  /// Base's `Lap Dist` against its clock.
  final DistanceAxis? baseAxis;

  /// Why there is no ghost even on the Time axis; null when there is one.
  final String? ghostWithheld;

  DistanceAxis? get _targetAxis => comparison.referenceAxis;

  /// Base's `Lap Dist` at [t], Base's session seconds; null off its lap.
  double? baseStationAt(double t) => _stationAt(baseAxis, t);

  /// The Target's `Lap Dist` at the same τ as Base's [t]; null off its lap.
  double? targetStationAt(double t) =>
      _stationAt(_targetAxis, t - comparison.timeShift);

  static double? _stationAt(DistanceAxis? axis, double seconds) {
    if (axis == null || !axis.isUsable) return null;
    if (seconds < axis.times.first || seconds > axis.times.last) return null;
    return axis.distanceAt(seconds);
  }

  /// Where the Target is at Base's [t], on the Time axis: on its own path,
  /// or, when that is not drawn, on Base's at its own `Lap Dist`.
  Offset? ghostAt(double t) {
    if (ghostWithheld != null) return null;
    final target = this.target;
    if (target != null) return target.positionAt(t);
    final station = targetStationAt(t);
    return station == null ? null : base.positionAtStation(station);
  }

  /// The readout at Base's [t] on the Time axis.
  TimeReadout readoutAt(double t) {
    final baseStation = baseStationAt(t);
    final targetStation = targetStationAt(t);
    return TimeReadout(
      tau: t - comparison.check.base.startSeconds,
      delta: baseStation == null
          ? null
          : comparison.delta?.deltaAt(baseStation),
      gap:
          baseStation == null ||
              targetStation == null ||
              comparison.alignment.withholdsDistance
          ? null
          : targetStation - baseStation,
    );
  }

  /// How much further than the stretch itself a segment fit may zoom out to
  /// keep the ghost in view; past it the map stays on the stretch and an
  /// edge chevron carries the gap (§6).
  static const ghostZoomOutLimit = 3.0;

  /// The margin a stretch is fitted with, as a share of its larger side
  /// (§6: "bounds +15%").
  static const fitMargin = 0.15;

  /// A stretch never fits tighter than this many metres across, or a short
  /// straight segment would fill the map with a few pixels of line.
  static const minimumFitMetres = 80.0;

  /// What the map is fitted to for the stretch [from]–[to] of `Lap Dist`:
  /// Base's path over it, plus where the ghost runs while Base drives it
  /// when [window] (Base's first reach of each end, in Base's seconds) is
  /// given — computed once per selection, so a scrub never moves the map.
  ///
  /// When including the ghost would zoom out more than [ghostZoomOutLimit]
  /// times, the fit stays on the stretch.
  Rect? fitFor(double from, double to, {({double from, double to})? window}) {
    final stretch = base.boundsBetweenStations(from, to);
    if (stretch == null) return null;
    var fit = stretch;
    if (window != null && ghostWithheld == null) {
      final ghost = _ghostBounds(window.from, window.to);
      if (ghost != null) {
        final both = stretch.expandToInclude(ghost);
        final growth = math.max(
          both.width / math.max(stretch.width, minimumFitMetres),
          both.height / math.max(stretch.height, minimumFitMetres),
        );
        if (growth <= ghostZoomOutLimit) fit = both;
      }
    }
    return _padded(fit);
  }

  /// Where the ghost runs between Base's [from] and [to] seconds.
  Rect? _ghostBounds(double from, double to) {
    final target = this.target;
    if (target != null) return target.boundsBetween(from, to);
    final first = targetStationAt(from);
    final last = targetStationAt(to);
    if (first == null || last == null) return null;
    return base.boundsBetweenStations(first, last);
  }

  static Rect _padded(Rect bounds) {
    final side = math.max(
      math.max(bounds.width, bounds.height),
      minimumFitMetres,
    );
    final margin = side * fitMargin / 2;
    final centre = bounds.center;
    final width = math.max(bounds.width, minimumFitMetres) + margin * 2;
    final height = math.max(bounds.height, minimumFitMetres) + margin * 2;
    return Rect.fromCenter(center: centre, width: width, height: height);
  }
}
