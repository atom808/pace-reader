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
  cut('cut', 'Throttle cut', ChannelRole.throttle);

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
/// engine throttle both, TC needs the file to record it.
class LapAidOverlays {
  LapAidOverlays._({required this.cut, required this.tc, required this.aids});

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
      aids: aids,
    );
  }

  final CutOverlay? cut;
  final PulseOverlay? tc;

  /// The lap's aids; null while they are read.
  final LapAids? aids;

  /// Whether the lap can show [aid] at all.
  bool offers(TraceAid aid) => switch (aid) {
    TraceAid.cut => cut != null,
    // Offered while the aids are read, so the chip does not pop in late.
    TraceAid.tc => aids == null || tc != null,
  };

  /// [chart] with the overlays in [shown] on their panels.
  LapChart decorate(LapChart chart, Set<TraceAid> shown) {
    final throttle = <TraceOverlay>[
      if (shown.contains(TraceAid.cut)) ?cut,
      if (shown.contains(TraceAid.tc)) ?tc,
    ];
    if (throttle.isEmpty) return chart;
    return chart.withPanels([
      for (final panel in chart.panels)
        panel.role == ChannelRole.throttle
            ? panel.withOverlays(throttle)
            : panel,
    ]);
  }
}

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
