/// The Inputs panels' driver-aid overlays (driver-aids proposal §2): which
/// are on, and what each lays over its panel.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/color_tokens.dart';
import '../../settings/application/app_settings.dart';
import 'lap_chart.dart';

/// An overlay the user can switch on and off, each remembered between runs.
enum TraceAid {
  /// TC's pulses as dots on the throttle pedal.
  tc('tc', 'TC', ChannelRole.throttle),

  /// The throttle the engine did not get, hatched under the pedal.
  cut('cut', 'Throttle cut', ChannelRole.throttle),

  /// ABS's pulses as dots on the brake pedal.
  abs('abs', 'ABS', ChannelRole.brake),

  /// Where a wheel locked, marked on the brake pedal.
  lockups('lockups', 'Lock-ups', ChannelRole.brake);

  const TraceAid(this.id, this.label, this.panel);

  /// What the setting stores.
  final String id;
  final String label;

  /// The panel it is drawn on.
  final ChannelRole panel;
}

/// The overlays switched on.
final shownTraceAidsProvider = Provider<Set<TraceAid>>((ref) {
  final hidden = ref.watch(
    appSettingsProvider.select((s) => s.hiddenTraceOverlays),
  );
  return {
    for (final aid in TraceAid.values)
      if (!hidden.contains(aid.id)) aid,
  };
});

/// One lap's overlays: what its aids lay over its panels, on the chart's
/// axis. Built for the chart's own lap and for its reference lap.
class _LapOverlays {
  const _LapOverlays({this.tc, this.abs, this.lockups});

  factory _LapOverlays.of(
    LapAids? aids,
    double? Function(double seconds) domainOf, {
    bool onReference = false,
  }) => _LapOverlays(
    tc: switch (aids?.tc) {
      final tc? => pulseOverlay(
        tc,
        domainOf,
        label: 'TC',
        onReference: onReference,
      ),
      null => null,
    },
    abs: switch (aids?.abs) {
      final abs? when aids!.absFitted => pulseOverlay(
        abs,
        domainOf,
        label: 'ABS',
        onReference: onReference,
      ),
      _ => null,
    },
    lockups: switch (aids?.lockups) {
      final locks? => lockOverlay(locks, domainOf, onReference: onReference),
      null => null,
    },
  );

  final PulseOverlay? tc;
  final PulseOverlay? abs;
  final MarkOverlay? lockups;
}

/// What [chart]'s lap offers each overlay: the cut needs the pedal and the
/// engine throttle both, TC and lock-ups need the file to record them, ABS
/// needs the car to have it. A reference lap overlaid on the chart has its
/// own aids drawn hollow on its line (driver-aids proposal §2.4).
class LapAidOverlays {
  LapAidOverlays._(
    this._own,
    this._reference, {
    required this.cut,
    required this.aids,
    required this.referenceAids,
  });

  /// Builds every overlay [chart], [aids] and [referenceAids] can supply,
  /// shown or not, so a toggle switches a layer rather than rebuilding it.
  factory LapAidOverlays.of(
    LapChart chart,
    LapAids? aids, {
    LapAids? referenceAids,
  }) {
    final delivered = deliveredThrottle(chart);
    final onReference = referenceDomainOf(chart);
    return LapAidOverlays._(
      _LapOverlays.of(aids, chart.domainOf),
      onReference == null
          ? const _LapOverlays()
          : _LapOverlays.of(referenceAids, onReference, onReference: true),
      cut: delivered == null ? null : CutOverlay(delivered),
      aids: aids,
      referenceAids: onReference == null ? null : referenceAids,
    );
  }

  final CutOverlay? cut;
  final _LapOverlays _own;
  final _LapOverlays _reference;

  PulseOverlay? get tc => _own.tc;
  PulseOverlay? get abs => _own.abs;
  MarkOverlay? get lockups => _own.lockups;

  /// The lap's aids; null while they are read.
  final LapAids? aids;

  /// The reference lap's, where one is overlaid and they have been read.
  final LapAids? referenceAids;

  /// Whether the lap can show [aid] at all. TC and lock-ups are offered
  /// while the aids are read, so their chips do not pop in late; ABS only
  /// once the car is known to have it, so a Hypercar's never pops out.
  bool offers(TraceAid aid) => switch (aid) {
    TraceAid.cut => cut != null,
    TraceAid.tc => aids == null || tc != null,
    TraceAid.abs => abs != null || _reference.abs != null,
    TraceAid.lockups => aids == null || lockups != null,
  };

  /// [aid]'s layers, this lap's and then the reference's.
  List<TraceOverlay> _overlays(TraceAid aid) => switch (aid) {
    TraceAid.cut => [?cut],
    TraceAid.tc => [?_reference.tc, ?_own.tc],
    TraceAid.abs => [?_reference.abs, ?_own.abs],
    TraceAid.lockups => [?_reference.lockups, ?_own.lockups],
  };

  /// [chart] with the overlays in [shown] on their panels, in
  /// [TraceAid]'s order, the reference's under this lap's: a mark is drawn
  /// over the dots, this lap's over the reference's.
  LapChart decorate(LapChart chart, Set<TraceAid> shown) {
    List<TraceOverlay> on(ChannelRole panel) => [
      for (final aid in TraceAid.values)
        if (aid.panel == panel && shown.contains(aid)) ..._overlays(aid),
    ];
    final throttle = on(ChannelRole.throttle);
    final brake = on(ChannelRole.brake);
    if (throttle.isEmpty && brake.isEmpty) return chart;
    return chart.withPanels([
      for (final panel in chart.panels)
        switch (panel.role) {
          ChannelRole.throttle when throttle.isNotEmpty => panel.withOverlays(
            throttle,
          ),
          ChannelRole.brake when brake.isNotEmpty => panel.withOverlays(brake),
          _ => panel,
        },
    ]);
  }
}

/// Where a moment of [chart]'s reference lap, in its own seconds, falls on
/// [chart]'s axis: on Time, its clock shifted to start at its own line
/// crossing as its traces are; on Distance, its own `Lap Dist`. Null when
/// no reference is overlaid.
double? Function(double seconds)? referenceDomainOf(LapChart chart) {
  final comparison = chart.comparison;
  if (comparison == null || !comparison.overlaid) return null;
  return switch (chart.axis) {
    TraceAxis.time => (seconds) => seconds + comparison.timeShift,
    TraceAxis.distance => (seconds) => LapAlignment.stationAt(
      comparison.referenceAxis,
      seconds,
    ),
  };
}

/// Each lock-up marked where its wheel was slowest, named by the wheel and
/// its speed against the car's ("FR 33 %").
MarkOverlay lockOverlay(
  List<WheelLock> locks,
  double? Function(double seconds) domainOf, {
  bool onReference = false,
}) {
  final at = <double>[];
  final texts = <String>[];
  final starts = <double>[];
  final ends = <double>[];
  for (final lock in locks) {
    final x = domainOf(lock.atSeconds);
    final a = domainOf(lock.startSeconds);
    final b = domainOf(lock.endSeconds);
    if (x == null || a == null || b == null) continue;
    at.add(x);
    texts.add(lockText(lock));
    starts.add(a);
    ends.add(b);
  }
  return MarkOverlay(
    label: 'LOCK',
    at: Float64List.fromList(at),
    texts: texts,
    starts: Float64List.fromList(starts),
    ends: Float64List.fromList(ends),
    onReference: onReference,
  );
}

/// "FR 33 %": the wheel, and its speed against the car's.
String lockText(WheelLock lock) =>
    '${lock.corner.short} ${(lock.ratio * 100).round()} %';

/// [aid]'s pulses and episodes placed by [domainOf]. A pulse is placed by
/// its middle; one [domainOf] cannot place (a Distance axis the lap lacks)
/// is left out.
PulseOverlay pulseOverlay(
  AidPulses aid,
  double? Function(double seconds) domainOf, {
  required String label,
  bool onReference = false,
}) {
  final pulses = <double>[];
  for (var i = 0; i < aid.pulseCount; i++) {
    final at = domainOf((aid.starts[i] + aid.ends[i]) / 2);
    if (at != null) pulses.add(at);
  }
  final starts = <double>[];
  final ends = <double>[];
  for (final e in aid.episodes) {
    final a = domainOf(e.startSeconds);
    final b = domainOf(e.endSeconds);
    if (a == null || b == null) continue;
    starts.add(a);
    ends.add(b);
  }
  return PulseOverlay(
    label: label,
    pulses: Float64List.fromList(pulses),
    episodeStarts: Float64List.fromList(starts),
    episodeEnds: Float64List.fromList(ends),
    onReference: onReference,
  );
}
