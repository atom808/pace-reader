/// The aids on the stage's map, shared by Trace and Compare (driver-aids
/// proposal §2.4).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_aids.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/aid_overlays.dart';
import '../application/lap_chart.dart';

/// Where the aids switched on acted on this lap (driver-aids proposal §2.4):
/// dots along the line and lock-up marks over it, and their key. Null with
/// none shown, none acting, or while they are read.
class StageAids {
  const StageAids._(this.layer, this.legend);

  static StageAids? of(
    BuildContext context,
    WidgetRef ref,
    TelemetrySource source,
    LapChart chart,
  ) {
    final path = chart.trackPath;
    final aids = ref.watch(lapAidsProvider((source, chart.lap.index))).value;
    if (path == null || aids == null) return null;
    final shown = ref.watch(shownTraceAidsProvider);
    final pulses = [
      if (shown.contains(TraceAid.tc)) ('TC', aids.tc),
      if (shown.contains(TraceAid.abs) && aids.absFitted) ('ABS', aids.abs),
    ];
    final episodes = [
      for (final (_, aid) in pulses)
        for (final e in aid?.episodes ?? const <AidEpisode>[])
          if ((chart.domainOf(e.startSeconds), chart.domainOf(e.endSeconds))
              case (final start?, final end?))
            (start, end),
    ];
    final locks = shown.contains(TraceAid.lockups)
        ? [
            for (final lock in aids.lockups ?? const <WheelLock>[])
              ?chart.domainOf(lock.atSeconds),
          ]
        : const <double>[];
    if (episodes.isEmpty && locks.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    final brake = ChannelColors.resolve(context).brake;
    return StageAids._(
      AidTrackLayer(
        path: path,
        episodes: episodes,
        locks: locks,
        ink: scheme.onSurface,
        halo: scheme.surface,
        lockFill: brake,
      ),
      AidLegend(
        counts: [
          for (final (label, aid) in pulses) (label, aid?.episodeCount ?? 0),
        ],
        locks: locks.length,
        lockFill: brake,
      ),
    );
  }

  final AidTrackLayer layer;
  final Widget legend;
}
