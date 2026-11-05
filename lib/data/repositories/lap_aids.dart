/// One lap's `TC` and `ABS` pulses for the trace's overlays (driver-aids
/// proposal §3).
///
/// Separate from `lapTelemetry`, like the dock tabs' channels: the overlays
/// are toggles, and a lap opened with them off reads nothing more than it
/// did before them.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channels.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_channels.dart';
import 'providers.dart';
import 'telemetry_repository.dart';

/// [source]'s lap's driver aids; [LapAids.none] for a lap the recording does
/// not hold.
///
/// `TC` is read from its event, or from its channel where a newer build
/// records it as one (SPEC.md §5.1); `ABS` is an event in every build. Each
/// is read a little past both ends of the lap ([AidPulses.readMargin]), so
/// an episode across the line merges as Driving Technique's does.
final lapAidsProvider = FutureProvider.autoDispose
    .family<LapAids, (TelemetrySource, int)>((ref, key) async {
      final (source, lapIndex) = key;
      final catalog = await ref.watch(telemetryCatalogProvider(source).future);
      final at = await lapReadWindow(ref, source, lapIndex);
      if (at == null) return LapAids.none;
      return readLapAids(
        at.telemetry,
        catalog,
        start: at.window.startSeconds,
        end: at.window.endSeconds,
      );
    }, retry: (_, _) => null);

/// The aids over `[start, end]`, each null where the file lacks it.
Future<LapAids> readLapAids(
  TelemetryRepository telemetry,
  TelemetryCatalog catalog, {
  required double start,
  required double end,
}) async {
  const margin = AidPulses.readMargin;

  Future<AidPulses?> read(String name) async {
    final List<(double, bool)> edges;
    if (catalog.hasEvent(name)) {
      final steps = await telemetry.readEventWindow(
        name,
        startSeconds: start - margin,
        endSeconds: end + margin,
      );
      edges = [
        for (var i = 0; i < steps.times.length; i++)
          (steps.times[i], steps.values[i] != 0),
      ];
    } else if (catalog.channel(name) case final channel?
        when channel.ridesMasterGrid(catalog.masterRowCount)) {
      edges = await telemetry.readChannelEdges(
        name,
        startSeconds: start - margin,
        endSeconds: end + margin,
      );
    } else {
      return null;
    }
    return AidPulses.fromEdges(name, edges, start: start, end: end);
  }

  return LapAids(tc: await read(Events.tc), abs: await read(Events.abs));
}
