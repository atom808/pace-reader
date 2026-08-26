/// The track map widget (SPEC.md §8.5).
///
/// Lives in the chart core rather than in `features/track_map/` because §9.5
/// puts it there deliberately: the map shares one cursor and one axis with
/// the trace panels, so it is part of the synced system, and both the Track
/// Map screen and the Telemetry Trace screen render this same widget rather
/// than each growing their own.
library;

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../design_system/design_system.dart';
import 'painters/chart_painting.dart';
import 'painters/track_map_painter.dart';
import 'sync/chart_sync.dart';
import 'track_path.dart';
import 'value_ramp.dart';

class TrackMapView extends ConsumerWidget {
  const TrackMapView({
    super.key,
    required this.path,
    required this.color,
    this.markers = const [],
    this.formatValue,
    this.showLegend = true,
    this.strokeWidth = 4,
  });

  final TrackPath path;

  /// The colouring channel's identity colour; the ramp is derived from it so
  /// a map coloured by brake stays red throughout and varies only in
  /// lightness (see [ValueRamp]).
  final Color color;

  /// `(point index, label)` — the start/finish line and sector boundaries.
  final List<(int, String)> markers;

  final String Function(double)? formatValue;
  final bool showLegend;
  final double strokeWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(chartSyncProvider);
    final palette = ChartPalette.of(context, series: color);
    final ramp = ValueRamp(color);
    final cursorIndex =
        sync.cursor == null ? null : path.nearestIndex(sync.cursor!);

    // Sized to the circuit's own proportions rather than to whatever box it
    // is given. The projection already refuses to stretch (see [TrackFit]),
    // so a taller box only adds empty space above and below the map — and
    // pushes the scale bar, which paints at the bottom of the box, away from
    // the thing it measures.
    final aspect = path.projection.boundsMetres;
    final aspectRatio = aspect.height <= 0
        ? 1.0
        : (aspect.width / aspect.height).clamp(0.4, 3.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: TrackMapPainter(
                        path: path,
                        ramp: ramp,
                        palette: palette,
                        cursorIndex: cursorIndex,
                        markers: markers,
                        strokeWidth: strokeWidth,
                      ),
                    ),
                    CustomPaint(
                      painter: TrackScalePainter(path: path, palette: palette),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showLegend && path.hasColouring) ...[
          const SizedBox(height: 10),
          _RampLegend(
            ramp: ramp,
            path: path,
            format: formatValue ?? (v) => v.toStringAsFixed(0),
          ),
        ],
      ],
    );
  }
}

/// The magnitude legend.
///
/// Present because colour is carrying a quantity here, and a sequential
/// encoding without a scale is a picture rather than a reading — the reader
/// can see that one part of the lap is brighter, and not what that is worth.
class _RampLegend extends StatelessWidget {
  const _RampLegend({
    required this.ramp,
    required this.path,
    required this.format,
  });

  final ValueRamp ramp;
  final TrackPath path;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = path.valueUnit.isEmpty
        ? path.valueLabel
        : '${path.valueLabel} (${path.valueUnit})';
    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        Text(format(path.valueRange.min), style: _numeral(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 8,
            decoration: ShapeDecoration(
              shape: AppRadii.squircle(4),
              gradient: LinearGradient(colors: ramp.stops(count: 7)),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(format(path.valueRange.max), style: _numeral(context)),
      ],
    );
  }

  TextStyle _numeral(BuildContext context) => AppTextStyles.numeral.copyWith(
        fontSize: 11,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}
