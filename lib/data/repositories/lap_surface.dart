/// One lap's kerb and off-track stretches (map stage P9d), from the
/// `SurfaceTypes` event's four wheels.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../channels.dart';
import '../duckdb/telemetry_database.dart';
import '../models/models.dart';
import 'lap_channels.dart';
import 'providers.dart';

/// [source]'s lap's stretches off the asphalt, in order; empty for a file
/// without `SurfaceTypes` as an event. A build that records it as a channel
/// (SPEC.md §5, 2026-10-13) has no timestamps to place it by, as Suspension
/// already finds.
final lapSurfaceProvider = FutureProvider.autoDispose
    .family<List<SurfaceStretch>, (TelemetrySource, int)>((ref, key) async {
      final (source, lapIndex) = key;
      final catalog = await ref.watch(telemetryCatalogProvider(source).future);
      if (!catalog.hasEvent(Events.surfaceTypes)) return const [];
      final at = await lapReadWindow(ref, source, lapIndex);
      if (at == null) return const [];
      final start = at.window.startSeconds;
      final end = at.window.endSeconds;
      return surfaceStretches(
        [
          for (final corner in Corner.values)
            await at.telemetry.readEventWindow(
              Events.surfaceTypes,
              startSeconds: start,
              endSeconds: end,
              valueColumn: corner.valueColumn,
            ),
        ],
        start: start,
        end: end,
      );
    }, retry: (_, _) => null);
