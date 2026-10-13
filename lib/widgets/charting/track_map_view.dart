/// The track map widget (SPEC.md §8.5).
///
/// Lives in the chart core rather than in `features/track_map/` because §9.5
/// puts it there deliberately: the map shares one cursor and one axis with
/// the trace panels, so it is part of the synced system, and both the Track
/// Map screen and the Telemetry Trace screen render this same widget rather
/// than each growing their own.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design_system/design_system.dart';
import 'painters/chart_painting.dart';
import 'painters/track_map_painter.dart';
import 'sync/sync_owner.dart';
import 'track_path.dart';
import 'value_ramp.dart';

/// A second lap's place on the map at a cursor position: Compare's ghost
/// (comparison proposal §6).
class TrackGhost {
  const TrackGhost({required this.at, this.describe});

  /// Where the second lap is, in the map's metres, when the cursor is at
  /// [cursor]; null where it has none.
  final Offset? Function(double cursor) at;

  /// What the map's edge says when the ghost is off it — "Target 34 m
  /// ahead".
  final String? Function(double cursor)? describe;
}

class TrackMapView extends ConsumerWidget {
  const TrackMapView({
    super.key,
    required this.path,
    required this.color,
    this.markers = const [],
    this.formatValue,
    this.showLegend = true,
    this.strokeWidth = 4,
    this.reference,
    this.frame,
    this.view,
    this.highlight,
    this.labels = const [],
    this.ghost,
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

  /// A second lap in [path]'s frame, drawn dotted in ink — see
  /// [TrackMapPainter.reference].
  final TrackPath? reference;

  /// The whole map's extent, in metres, which sizes the box; [path]'s own
  /// bounds when null. Compare passes both laps' combined bounds.
  final Rect? frame;

  /// What the box shows, in metres: a stretch of the lap; the whole [frame]
  /// when null.
  final Rect? view;

  /// A stretch of `Lap Dist` cased in ink.
  final (double, double)? highlight;

  final List<TrackLabel> labels;
  final TrackGhost? ghost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (state: sync, owns: _) = watchChartSync(ref, context);
    final palette = ChartPalette.of(context, series: color);
    final ramp = ValueRamp(color);
    final ink = Theme.of(context).colorScheme.onSurface;
    final cursor = sync.cursor;
    final cursorAt = cursor == null || path.isEmpty
        ? null
        : path.positionAt(cursor) ??
              path.projection.points[path.nearestIndex(cursor)];
    final ghostAt = cursor == null ? null : ghost?.at(cursor);
    final fitted = view ?? frame;

    // Sized to the circuit's own proportions rather than to whatever box it
    // is given. The projection already refuses to stretch (see [TrackFit]),
    // so a taller box only adds empty space above and below the map — and
    // pushes the scale bar, which paints at the bottom of the box, away from
    // the thing it measures.
    final aspect = frame ?? path.projection.boundsMetres;
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
                        markers: markers,
                        strokeWidth: strokeWidth,
                        reference: reference,
                        ink: ink,
                        view: fitted,
                        overview: frame,
                        highlight: highlight,
                        labels: labels,
                      ),
                    ),
                    CustomPaint(
                      painter: TrackScalePainter(
                        path: path,
                        palette: palette,
                        view: fitted,
                      ),
                    ),
                    CustomPaint(
                      painter: TrackCursorPainter(
                        path: path,
                        palette: palette,
                        view: fitted,
                        cursor: cursorAt,
                        ghost: ghostAt,
                        ghostColor: ink.withValues(alpha: 0.85),
                        ghostLabel: ghostAt == null
                            ? null
                            : ghost?.describe?.call(cursor!),
                      ),
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
