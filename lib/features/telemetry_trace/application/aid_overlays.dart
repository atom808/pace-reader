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

/// What [chart]'s lap offers each overlay: the cut needs the pedal and the
/// engine throttle both, TC and lock-ups need the file to record them, ABS
/// needs the car to have it.
class LapAidOverlays {
  LapAidOverlays._({
    required this.cut,
    required this.tc,
    required this.abs,
    required this.lockups,
    required this.aids,
  });

  /// Builds every overlay [chart] and [aids] can supply, shown or not, so a
  /// toggle switches a layer rather than rebuilding it.
  factory LapAidOverlays.of(LapChart chart, LapAids? aids) {
    final delivered = deliveredThrottle(chart);
    return LapAidOverlays._(
      cut: delivered == null ? null : CutOverlay(delivered),
      tc: switch (aids?.tc) {
        final tc? => pulseOverlay(chart, tc, label: 'TC'),
        null => null,
      },
      abs: switch (aids?.abs) {
        final abs? when aids!.absFitted => pulseOverlay(
          chart,
          abs,
          label: 'ABS',
        ),
        _ => null,
      },
      lockups: switch (aids?.lockups) {
        final locks? => lockOverlay(chart, locks),
        null => null,
      },
      aids: aids,
    );
  }

  final CutOverlay? cut;
  final PulseOverlay? tc;
  final PulseOverlay? abs;
  final MarkOverlay? lockups;

  /// The lap's aids; null while they are read.
  final LapAids? aids;

  /// Whether the lap can show [aid] at all. TC and lock-ups are offered
  /// while the aids are read, so their chips do not pop in late; ABS only
  /// once the car is known to have it, so a Hypercar's never pops out.
  bool offers(TraceAid aid) => switch (aid) {
    TraceAid.cut => cut != null,
    TraceAid.tc => aids == null || tc != null,
    TraceAid.abs => abs != null,
    TraceAid.lockups => aids == null || lockups != null,
  };

  TraceOverlay? _overlay(TraceAid aid) => switch (aid) {
    TraceAid.cut => cut,
    TraceAid.tc => tc,
    TraceAid.abs => abs,
    TraceAid.lockups => lockups,
  };

  /// [chart] with the overlays in [shown] on their panels, in
  /// [TraceAid]'s order: a mark is drawn over the dots.
  LapChart decorate(LapChart chart, Set<TraceAid> shown) {
    List<TraceOverlay> on(ChannelRole panel) => [
      for (final aid in TraceAid.values)
        if (aid.panel == panel && shown.contains(aid)) ?_overlay(aid),
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

/// Each lock-up marked where its wheel was slowest, named by the wheel and
/// its speed against the car's ("FR 33 %").
MarkOverlay lockOverlay(LapChart chart, List<WheelLock> locks) {
  final at = <double>[];
  final texts = <String>[];
  final starts = <double>[];
  final ends = <double>[];
  for (final lock in locks) {
    final x = chart.domainOf(lock.atSeconds);
    final a = chart.domainOf(lock.startSeconds);
    final b = chart.domainOf(lock.endSeconds);
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
  );
}

/// "FR 33 %": the wheel, and its speed against the car's.
String lockText(WheelLock lock) =>
    '${lock.corner.short} ${(lock.ratio * 100).round()} %';

/// [aid]'s pulses and episodes on [chart]'s axis. A pulse is placed by its
/// middle; on a Distance axis the lap lacks, there is nothing to place.
PulseOverlay pulseOverlay(
  LapChart chart,
  AidPulses aid, {
  required String label,
}) {
  final pulses = <double>[];
  for (var i = 0; i < aid.pulseCount; i++) {
    final at = chart.domainOf((aid.starts[i] + aid.ends[i]) / 2);
    if (at != null) pulses.add(at);
  }
  final starts = <double>[];
  final ends = <double>[];
  for (final e in aid.episodes) {
    final a = chart.domainOf(e.startSeconds);
    final b = chart.domainOf(e.endSeconds);
    if (a == null || b == null) continue;
    starts.add(a);
    ends.add(b);
  }
  return PulseOverlay(
    label: label,
    pulses: Float64List.fromList(pulses),
    episodeStarts: Float64List.fromList(starts),
    episodeEnds: Float64List.fromList(ends),
  );
}
