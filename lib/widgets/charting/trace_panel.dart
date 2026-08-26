/// One panel of the synced trace stack (SPEC.md §8.4, §9.5).
///
/// Every panel in a stack shares one [ChartSync] axis, window and cursor, so
/// hovering anywhere reads every channel at the same point of the lap and
/// zooming one zooms all of them. That is the behaviour §9.5 built a custom
/// core for rather than reaching for a chart library.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../design_system/design_system.dart';
import 'decimation.dart';
import 'painters/chart_painting.dart';
import 'painters/cursor_painter.dart';
import 'painters/trace_painter.dart';
import 'sync/chart_sync.dart';
import 'viewport.dart';

/// What a panel draws: a decimated channel, or a held event signal.
///
/// A union rather than two widgets because everything *around* the mark —
/// the gesture handling, the shared cursor, the header readout, the value
/// axis — is identical, and duplicating it is how two panels drift into
/// behaving differently.
sealed class PanelSeries {
  const PanelSeries();

  ValueRange get valueRange;
  ChartViewport? get domainBounds;
  double? valueAt(double domain);
  bool get isEmpty;
}

final class LineSeries extends PanelSeries {
  const LineSeries(this.plot);

  final TracePlot plot;

  @override
  ValueRange get valueRange => plot.valueRange;

  @override
  ChartViewport? get domainBounds => plot.domainBounds;

  @override
  double? valueAt(double domain) => plot.valueAt(domain);

  @override
  bool get isEmpty => plot.isEmpty;
}

final class StepSeriesPanel extends PanelSeries {
  const StepSeriesPanel(this.plot);

  final StepPlot plot;

  @override
  ValueRange get valueRange => plot.valueRange;

  @override
  ChartViewport? get domainBounds =>
      plot.length < 2 ? null : ChartViewport(plot.xs.first, plot.xs.last);

  @override
  double? valueAt(double domain) => plot.valueAt(domain);

  @override
  bool get isEmpty => plot.isEmpty;
}

/// A single stacked channel panel.
class TracePanel extends ConsumerWidget {
  const TracePanel({
    super.key,
    required this.series,
    required this.bounds,
    required this.color,
    required this.title,
    required this.formatValue,
    required this.formatDomain,
    this.unit = '',
    this.height = 104,
    this.showDomainReadout = false,
    this.markers = const [],
    this.valueTickCount = 4,
  });

  final PanelSeries series;

  /// Full extent of the loaded lap on the current axis. Passed in rather than
  /// held in [ChartSync] — see that file for why.
  final ChartViewport bounds;

  final Color color;
  final String title;
  final String unit;
  final double height;

  /// Only the bottom panel of a stack draws the domain readout, so the cursor
  /// says "where in the lap" once rather than five times.
  final bool showDomainReadout;

  final List<(double, String)> markers;
  final int valueTickCount;

  final String Function(double) formatValue;
  final String Function(double) formatDomain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(chartSyncProvider);
    final controller = ref.read(chartSyncProvider.notifier);
    final palette = ChartPalette.of(context, series: color);
    final viewport = sync.visible(bounds);

    // Padded so a trace at full scale doesn't run along the panel edge, and
    // deliberately *not* snapped outward to round numbers: snapping a
    // -23.8..51.3 steering range out to -50..75 would leave the trace using
    // half the panel it was given. The gridlines land on round values
    // regardless — they are chosen inside this range rather than defining it.
    final values = series.isEmpty
        ? const ValueRange(0, 1)
        : series.valueRange.padded();
    final cursorValue =
        sync.cursor == null ? null : series.valueAt(sync.cursor!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: title,
            unit: unit,
            color: color,
            value: cursorValue == null ? null : formatValue(cursorValue),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, height);
                final geometry = ChartGeometry(
                  viewport: viewport,
                  values: values,
                  size: size,
                );
                return _PanelSurface(
                  geometry: geometry,
                  bounds: bounds,
                  controller: controller,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The trace redraws only when the data or the window
                      // changes; the cursor layer above it redraws at pointer
                      // rate. Separating them is what keeps a scrub off the
                      // thousands of points below.
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: _painterFor(geometry, palette, values),
                          size: size,
                        ),
                      ),
                      CustomPaint(
                        painter: DomainMarkerPainter(
                          markers: markers,
                          geometry: geometry,
                          palette: palette,
                        ),
                        size: size,
                      ),
                      CustomPaint(
                        painter: CursorPainter(
                          cursor: sync.cursor,
                          geometry: geometry,
                          palette: palette,
                          value: cursorValue,
                          readout: showDomainReadout && sync.cursor != null
                              ? formatDomain(sync.cursor!)
                              : null,
                        ),
                        size: size,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  CustomPainter _painterFor(
    ChartGeometry geometry,
    ChartPalette palette,
    ValueRange values,
  ) {
    final ticks = values.ticks(target: valueTickCount);
    // Domain gridlines are computed from the visible window rather than the
    // lap, so they stay round numbers as the user zooms instead of being
    // fixed lap fractions that drift off screen.
    final domainTicks =
        ValueRange(geometry.viewport.start, geometry.viewport.end)
            .ticks(target: 6);
    return switch (series) {
      LineSeries(:final plot) => TracePainter(
          plot: plot,
          geometry: geometry,
          palette: palette,
          valueTicks: ticks,
          domainTicks: domainTicks,
          formatValue: formatValue,
        ),
      StepSeriesPanel(:final plot) => StepTracePainter(
          plot: plot,
          geometry: geometry,
          palette: palette,
          valueTicks: ticks,
          domainTicks: domainTicks,
          formatValue: formatValue,
        ),
    };
  }
}

/// Pointer handling, shared by every panel.
///
/// Hover scrubs, scroll zooms about the pointer, drag pans. All three write
/// to [ChartSync] rather than to local state, which is what makes the gesture
/// affect the whole stack and the track map instead of only the panel it
/// started in.
class _PanelSurface extends StatelessWidget {
  const _PanelSurface({
    required this.geometry,
    required this.bounds,
    required this.controller,
    required this.child,
  });

  final ChartGeometry geometry;
  final ChartViewport bounds;
  final ChartSync controller;
  final Widget child;

  double _domainAt(Offset local) =>
      geometry.viewport.toDomain(local.dx, geometry.size.width);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      onHover: (event) => controller.setCursor(_domainAt(event.localPosition)),
      onExit: (_) => controller.setCursor(null),
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          // Exponential so each notch is the same proportional step whatever
          // the current zoom, and clamped so a trackpad fling can't jump
          // several decades in one event.
          final factor =
              (1 + event.scrollDelta.dy * 0.0016).clamp(0.75, 1.35).toDouble();
          controller.zoomAround(
            _domainAt(event.localPosition),
            factor,
            bounds: bounds,
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) =>
              controller.setCursor(_domainAt(details.localPosition)),
          onHorizontalDragUpdate: (details) => controller.panBy(
            // Negated: dragging the content right moves the window left.
            -details.delta.dx / geometry.size.width * geometry.viewport.span,
            bounds: bounds,
          ),
          onDoubleTap: controller.resetViewport,
          child: child,
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.unit,
    required this.color,
    this.value,
  });

  final String title;
  final String unit;
  final Color color;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        // A colour swatch carries the channel identity so the label itself
        // can stay in ordinary text ink — §9.7.1 keeps channel colour for the
        // mark, not for the words next to it.
        Container(
          width: 8,
          height: 8,
          decoration: ShapeDecoration(shape: const CircleBorder(), color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.labelMedium),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            unit,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const Spacer(),
        // Reserved width so the header doesn't reflow as the cursor moves
        // across values of different digit counts.
        SizedBox(
          width: 96,
          child: Text(
            value ?? '',
            textAlign: TextAlign.right,
            style: AppTextStyles.numeral.copyWith(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
