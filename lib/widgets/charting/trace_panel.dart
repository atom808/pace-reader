/// One panel of the synced trace stack (SPEC.md §8.4, §9.5).
///
/// Every panel in a stack shares one [ChartSync] axis, window and cursor, so
/// hovering anywhere reads every channel at the same point of the lap and
/// zooming one zooms all of them. That is the behaviour §9.5 built a custom
/// core for rather than reaching for a chart library.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../design_system/design_system.dart';
import 'decimation.dart';
import 'painters/chart_painting.dart';
import 'painters/cursor_painter.dart';
import 'painters/trace_painter.dart';
import 'sync/chart_sync.dart';
import 'sync/sync_owner.dart';
import 'trace_overlays.dart';
import 'trace_peaks.dart';
import 'viewport.dart';

/// What a panel draws: a decimated channel, a held event signal, or a lap's
/// time delta against its reference.
///
/// A union rather than three widgets because everything *around* the mark —
/// the gesture handling, the shared cursor, the header readout, the value
/// axis — is identical, and duplicating it is how two panels drift into
/// behaving differently.
///
/// A channel and an event signal can each carry the same signal on a
/// reference lap (§8.4). It lives on the series rather than beside it on the
/// panel so the two are always the same kind — a gear trace can only be
/// compared with gear steps, never with a line.
sealed class PanelSeries {
  const PanelSeries();

  /// The extent to scale the panel to — the reference's included, so neither
  /// lap runs off the panel when the other set its range.
  ValueRange get valueRange;

  /// How low and high it goes inside [window]; null to keep [valueRange].
  ValueRange? rangeIn(ChartViewport window) => null;
  ChartViewport? get domainBounds;
  double? valueAt(double domain);

  /// The reference lap's value at [domain], or null when there is no
  /// reference or it does not reach [domain].
  double? referenceValueAt(double domain) => null;

  bool get hasReference => false;
  bool get isEmpty;
}

final class LineSeries extends PanelSeries {
  const LineSeries(this.plot, {this.reference});

  final TracePlot plot;
  final TracePlot? reference;

  @override
  ValueRange get valueRange => reference == null
      ? plot.valueRange
      : plot.valueRange.union(reference!.valueRange);

  @override
  ValueRange? rangeIn(ChartViewport window) {
    final own = plot.rangeIn(window);
    final theirs = reference?.rangeIn(window);
    if (own == null || theirs == null) return own ?? theirs;
    return own.union(theirs);
  }

  @override
  ChartViewport? get domainBounds => plot.domainBounds;

  @override
  double? valueAt(double domain) => plot.valueAt(domain);

  @override
  double? referenceValueAt(double domain) {
    final line = reference;
    // Outside its own extent a reference has no value, rather than the value
    // at its nearest end: laps differ in length on the time axis, and a
    // readout frozen on the reference's last sample would look like a number.
    if (line == null || line.length < 2) return null;
    if (domain < line.xs.first || domain > line.xs.last) return null;
    return line.valueAt(domain);
  }

  @override
  bool get hasReference => reference != null;

  @override
  bool get isEmpty => plot.isEmpty;
}

final class StepSeriesPanel extends PanelSeries {
  const StepSeriesPanel(this.plot, {this.reference});

  final StepPlot plot;
  final StepPlot? reference;

  @override
  ValueRange get valueRange => reference == null
      ? plot.valueRange
      : plot.valueRange.union(reference!.valueRange);

  @override
  ChartViewport? get domainBounds =>
      plot.length < 2 ? null : ChartViewport(plot.xs.first, plot.xs.last);

  @override
  double? valueAt(double domain) => plot.valueAt(domain);

  @override
  double? referenceValueAt(double domain) => reference?.valueAt(domain);

  @override
  bool get hasReference => reference != null;

  @override
  bool get isEmpty => plot.isEmpty;
}

/// A lap's difference from its reference — the time delta (§8.4), or
/// Compare's line (comparison proposal §6) — drawn against a zero line
/// rather than the panel floor; see [DeltaTracePainter].
final class DeltaSeriesPanel extends PanelSeries {
  const DeltaSeriesPanel(this.plot, {this.floorBand});

  final TracePlot plot;

  /// Half the height of a band drawn around zero: differences inside it are
  /// not stated. Always on screen, so a flat trace still shows how close to
  /// the floor it runs.
  final double? floorBand;

  @override
  ValueRange get valueRange => switch (floorBand) {
    final band? => plot.valueRange.union(ValueRange(-band, band)),
    null => plot.valueRange,
  };

  @override
  ChartViewport? get domainBounds => plot.domainBounds;

  @override
  double? valueAt(double domain) {
    // Only the stretch both laps recorded has a delta (see `LapDelta`); past
    // it the honest readout is none, not the last value compared.
    if (plot.length < 2 || domain < plot.xs.first || domain > plot.xs.last) {
      return null;
    }
    // Interpolated, not the nearest sample: on the Time axis this is
    // exactly the delta at Base's `Lap Dist` (`LapDelta.deltaAt`), which
    // Compare's readout states beside it (comparison proposal §6) — the
    // samples sit at the same instants, and both are linear between them.
    return plot.interpolatedAt(domain);
  }

  @override
  bool get isEmpty => plot.isEmpty;
}

/// Several lines of one quantity in one panel: a tyre's inner, centre and
/// outer tread (map stage P9c). The first line is the one the cursor rides,
/// and the brightest; the others fade in order (see [tints]).
final class MultiLineSeries extends PanelSeries {
  const MultiLineSeries(this.lines) : assert(lines.length > 0);

  final List<TracePlot> lines;

  /// Each line's colour, from the panel's [base]: full strength first, each
  /// after it fainter, so the order reads without a legend of its own.
  static List<Color> tints(Color base, int count) => [
    for (var k = 0; k < count; k++)
      base.withValues(alpha: base.a * (1 - 0.3 * k).clamp(0.3, 1)),
  ];

  @override
  ValueRange get valueRange =>
      lines.map((l) => l.valueRange).reduce((a, b) => a.union(b));

  @override
  ValueRange? rangeIn(ChartViewport window) {
    ValueRange? out;
    for (final line in lines) {
      final r = line.rangeIn(window);
      if (r != null) out = out == null ? r : out.union(r);
    }
    return out;
  }

  @override
  ChartViewport? get domainBounds => lines.first.domainBounds;

  @override
  double? valueAt(double domain) => lines.first.valueAt(domain);

  /// Every line's value at [domain], in order.
  List<double?> valuesAt(double domain) => [
    for (final line in lines) line.isEmpty ? null : line.valueAt(domain),
  ];

  @override
  bool get isEmpty => lines.every((l) => l.isEmpty);
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
    this.height,
    this.showDomainReadout = false,
    this.markers = const [],
    this.valueTickCount = 4,
    this.fitToWindow = false,
    this.peaks = const [],
    this.overlays = const [],
  });

  final PanelSeries series;

  /// Full extent of the loaded lap on the current axis. Passed in rather than
  /// held in [ChartSync] — see that file for why.
  final ChartViewport bounds;

  final Color color;
  final String title;
  final String unit;

  /// The panel's whole height, chip and plot. Null takes the height the panel
  /// is given — a share of a [TraceStack] — or [defaultHeight] where it is
  /// given none, as in a plain list.
  final double? height;

  static const defaultHeight = 104.0;

  /// Only the bottom panel of a stack draws the domain readout, so the cursor
  /// says "where in the lap" once rather than five times.
  final bool showDomainReadout;

  final List<(double, String)> markers;
  final int valueTickCount;

  /// Scales the panel to what the window shows rather than the whole lap,
  /// so a zoomed trace fills its panel as in the reference apps. Off for a
  /// channel read against fixed marks: a pedal's 0–100 %, a gear.
  final bool fitToWindow;

  /// Marked on the trace with their values; a click on one puts the playhead
  /// exactly there, and with it the car on the map (P9b).
  final List<TracePeak> peaks;

  /// Laid over the line: a cut, an aid's pulses (driver-aids proposal §2).
  /// Drawn only on a panel that is a line.
  final List<TraceOverlay> overlays;

  final String Function(double) formatValue;
  final String Function(double) formatDomain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (state: sync, :owns) = watchChartSync(ref, context);
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
        : (fitToWindow
                  ? shownRange(series.valueRange, series.rangeIn(viewport))
                  : series.valueRange)
              .padded();
    // What the header and the readout read: the probe while the pointer is
    // over a panel or the map, the playhead otherwise (map stage proposal
    // §5).
    final reading = sync.probe ?? sync.playhead;
    final cursorValue = reading == null ? null : series.valueAt(reading);
    final referenceValue = reading == null
        ? null
        : series.referenceValueAt(reading);
    final playheadValue = sync.playhead == null
        ? null
        : series.valueAt(sync.playhead!);

    final theme = Theme.of(context);
    final chip = _PanelChip(
      title: title,
      unit: unit,
      color: color,
      value: cursorValue == null ? null : formatValue(cursorValue),
      values: switch (series) {
        final MultiLineSeries lines => [
          for (final (k, tint) in MultiLineSeries.tints(
            color,
            lines.lines.length,
          ).indexed)
            (
              tint,
              switch (reading == null ? null : lines.valuesAt(reading)[k]) {
                final v? => formatValue(v),
                null => '',
              },
            ),
        ],
        _ => null,
      },
      referenceValue: !series.hasReference
          ? null
          : referenceValue == null
          ? ''
          : formatValue(referenceValue),
      referenceColor: palette.reference,
      // The aid acting at the cursor, named beside the value.
      badges: reading == null || overlays.isEmpty
          ? const []
          : activeAidLabels(overlays, reading),
    );
    final line = switch (series) {
      LineSeries(:final plot) when overlays.isNotEmpty => plot,
      _ => null,
    };
    final shape = AppRadii.squircle(AppRadii.sm);

    return LayoutBuilder(
      builder: (context, constraints) {
        final panelHeight =
            height ??
            (constraints.hasBoundedHeight
                ? constraints.maxHeight
                : defaultHeight);
        final size = Size(constraints.maxWidth, panelHeight);
        final geometry = ChartGeometry(
          viewport: viewport,
          // A panel whose peaks are marked keeps its trace under the chip:
          // the highest peaks are the ones worth clicking (P9b).
          values: peaks.isEmpty ? values : _underChip(values, panelHeight),
          size: size,
        );
        // A panel on a lap that does not hold the cursor (see `SyncOwner`)
        // takes no gestures: they would write a window or cursor onto another
        // lap's clock.
        return SizedBox(
          height: panelHeight,
          // A card of its own, as in the reference apps: the eye tells the
          // panels apart by their edges rather than by gaps of empty dock.
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.38),
              shape: shape,
            ),
            child: ClipPath.shape(
              shape: shape,
              child: IgnorePointer(
                ignoring: !owns,
                child: _PanelSurface(
                  geometry: geometry,
                  bounds: bounds,
                  controller: controller,
                  peaks: peaks,
                  builder: (context, hovered) => Stack(
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
                      // Each overlay in a layer of its own, so toggling one
                      // neither redraws the trace nor the others; each fades
                      // in as it arrives (the pulses come after the lap).
                      if (line != null)
                        for (final overlay in overlays)
                          _FadeIn(
                            key: ValueKey(overlayKey(overlay)),
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: TraceOverlayPainter(
                                  overlay: overlay,
                                  line: line,
                                  geometry: geometry,
                                  palette: palette,
                                  ink: theme.colorScheme.onSurface,
                                ),
                                size: size,
                              ),
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
                          cursor: sync.playhead,
                          probe: sync.probe,
                          geometry: geometry,
                          palette: palette,
                          value: playheadValue,
                          probeValue: sync.probe == null ? null : cursorValue,
                          referenceValue: referenceValue,
                          readout: showDomainReadout && reading != null
                              ? formatDomain(reading)
                              : null,
                        ),
                        size: size,
                      ),
                      // Under the chip, which a peak near the top would
                      // otherwise write over (P9b).
                      if (peaks.isNotEmpty)
                        CustomPaint(
                          painter: PeakPainter(
                            peaks: peaks,
                            hovered: hovered,
                            geometry: geometry,
                            palette: palette,
                            format: formatValue,
                          ),
                          size: size,
                        ),
                      // Over the trace's top left, where the reference apps
                      // put it: the title costs no row of its own, so the
                      // trace gets the panel's whole height. The pointer
                      // passes through to the trace beneath.
                      Positioned(
                        left: 6,
                        top: 6,
                        right: 44,
                        child: IgnorePointer(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: chip,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
    final domainTicks = ValueRange(
      geometry.viewport.start,
      geometry.viewport.end,
    ).ticks(target: 6);
    return switch (series) {
      LineSeries(:final plot, :final reference) => TracePainter(
        plot: plot,
        reference: reference,
        geometry: geometry,
        palette: palette,
        valueTicks: ticks,
        domainTicks: domainTicks,
        formatValue: formatValue,
      ),
      StepSeriesPanel(:final plot, :final reference) => StepTracePainter(
        plot: plot,
        reference: reference,
        geometry: geometry,
        palette: palette,
        valueTicks: ticks,
        domainTicks: domainTicks,
        formatValue: formatValue,
      ),
      MultiLineSeries(:final lines) => MultiTracePainter(
        lines: lines,
        colours: MultiLineSeries.tints(color, lines.length),
        geometry: geometry,
        palette: palette,
        valueTicks: ticks,
        domainTicks: domainTicks,
        formatValue: formatValue,
      ),
      DeltaSeriesPanel(:final plot, :final floorBand) => DeltaTracePainter(
        plot: plot,
        floorBand: floorBand,
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
/// Hover probes, a click places the playhead, Ctrl+scroll zooms about the
/// pointer, Shift+scroll or drag pans; a bare scroll is left to the page.
/// Hover never moves the playhead: that is the play bar's and the click's
/// (map stage proposal §5). All of them write
/// to [ChartSync] rather than to local state, which is what makes the gesture
/// affect the whole stack and the track map instead of only the panel it
/// started in.
class _PanelSurface extends StatefulWidget {
  const _PanelSurface({
    required this.geometry,
    required this.bounds,
    required this.controller,
    required this.builder,
    this.peaks = const [],
  });

  final ChartGeometry geometry;
  final ChartViewport bounds;
  final ChartSync controller;

  /// The panel's layers, given the peak the pointer rests on.
  final Widget Function(BuildContext context, TracePeak? hovered) builder;

  /// The peaks a click near snaps the playhead to, and the pointer turns to
  /// a hand over.
  final List<TracePeak> peaks;

  @override
  State<_PanelSurface> createState() => _PanelSurfaceState();
}

class _PanelSurfaceState extends State<_PanelSurface> {
  /// Where the primary button went down, until it comes up: a click is a
  /// press that comes up where it went down.
  Offset? _down;

  /// The peak the pointer rests on, which shows a hand and its value.
  TracePeak? _hovered;

  ChartGeometry get geometry => widget.geometry;
  ChartViewport get bounds => widget.bounds;
  ChartSync get controller => widget.controller;

  double _domainAt(Offset local) =>
      geometry.viewport.toDomain(local.dx, geometry.size.width);

  TracePeak? _peakAt(Offset local) =>
      peakNear(widget.peaks, geometry, local, slop: peakHitSlop);

  /// Places the playhead the moment a click ends. Read off the raw pointer
  /// rather than a tap recogniser: with double-click (fit) in the arena, a
  /// recogniser would hold every click for the double-tap timeout first.
  void _pointerUp(PointerUpEvent event) {
    final down = _down;
    _down = null;
    if (down == null || (event.localPosition - down).distance > kTouchSlop) {
      return;
    }
    // On a peak, exactly on it (P9b): the car on the map goes to the peak,
    // not to wherever within a few pixels the click landed.
    controller.setPlayhead(
      _peakAt(event.localPosition)?.at ?? _domainAt(event.localPosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _hovered != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.precise,
      onHover: (event) {
        controller.setProbe(_domainAt(event.localPosition));
        final hovered = _peakAt(event.localPosition);
        if (hovered != _hovered) setState(() => _hovered = hovered);
      },
      onExit: (_) {
        controller.setProbe(null);
        if (_hovered != null) setState(() => _hovered = null);
      },
      child: Listener(
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;
          final keyboard = HardwareKeyboard.instance;
          final zoom = keyboard.isControlPressed || keyboard.isMetaPressed;
          final pan = keyboard.isShiftPressed;
          // A bare wheel is the page's: it falls through to the enclosing
          // scroll view. Only a modified wheel is claimed here, and claimed
          // through the resolver so the scroll view, which registers after
          // us, does not also move on the same event.
          if (!zoom && !pan) return;
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {
            if (zoom) {
              // Exponential so each notch is the same proportional step
              // whatever the current zoom, and clamped so a trackpad fling
              // can't jump several decades in one event.
              final factor = (1 + event.scrollDelta.dy * 0.0016)
                  .clamp(0.75, 1.35)
                  .toDouble();
              controller.zoomAround(
                _domainAt(event.localPosition),
                factor,
                bounds: bounds,
              );
            } else {
              // Shift turns the wheel sideways. Some platforms already swap
              // the axes for shift, so take whichever carries the motion.
              final dx = event.scrollDelta.dx != 0
                  ? event.scrollDelta.dx
                  : event.scrollDelta.dy;
              controller.panBy(
                dx / 600 * geometry.viewport.span,
                bounds: bounds,
              );
            }
          });
        },
        onPointerDown: (event) => _down = event.buttons == kPrimaryButton
            ? event.localPosition
            : null,
        onPointerUp: _pointerUp,
        onPointerCancel: (_) => _down = null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => controller.panBy(
            // Negated: dragging the content right moves the window left.
            -details.delta.dx / geometry.size.width * geometry.viewport.span,
            bounds: bounds,
          ),
          onDoubleTap: controller.resetViewport,
          child: widget.builder(context, _hovered),
        ),
      ),
    );
  }
}

/// The panel's name and its readings, in a chip over the trace's top left.
class _PanelChip extends StatelessWidget {
  const _PanelChip({
    required this.title,
    required this.unit,
    required this.color,
    required this.referenceColor,
    this.value,
    this.values,
    this.referenceValue,
    this.badges = const [],
  });

  /// The aids acting at the cursor (driver-aids proposal §2.3).
  final List<String> badges;

  final String title;
  final String unit;
  final Color color;
  final Color referenceColor;
  final String? value;

  /// A reading per line, each behind a swatch of its line's colour, in place
  /// of [value] on a panel of several lines.
  final List<(Color, String)>? values;

  /// The reference lap's value under the cursor. Null when the panel has no
  /// reference at all — the column is then not reserved — and empty when it
  /// has one that does not reach the cursor.
  final String? referenceValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 12);
    final name = Text(
      title,
      style: theme.textTheme.labelMedium,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    return DecoratedBox(
      // Opaque enough that the trace passing under it never runs through the
      // words.
      decoration: ShapeDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        shape: AppRadii.squircle(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
        child: _ShrinkIf(
          values != null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A colour swatch carries the channel identity so the label
              // itself can stay in ordinary text ink — §9.7.1 keeps channel
              // colour for the mark, not for the words next to it.
              // Several lines key their own readings instead.
              if (values == null) ...[_Swatch(color), const SizedBox(width: 6)],
              // The title gives way before the readings do: they hold their
              // width so they never reflow under the cursor. Beside several
              // readings the whole chip shrinks instead, below.
              if (values == null) Flexible(child: name) else name,
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(
                  unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // The reference's value behind a dotted key in its line's colour
              // — the mark carries which lap it is, and the number stays in
              // ink, as every other value on the panel does.
              if (referenceValue case final reference?) ...[
                const SizedBox(width: 10),
                if (reference.isNotEmpty) ...[
                  CustomPaint(
                    size: const Size(10, 8),
                    painter: _DottedKeyPainter(referenceColor),
                  ),
                  const SizedBox(width: 4),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 40),
                  child: Text(
                    reference,
                    textAlign: TextAlign.right,
                    style: numeral.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              // Each reading behind its line's swatch, tight enough for three
              // in a quarter of the dock.
              if (values case final lines?)
                for (final (tint, reading) in lines) ...[
                  const SizedBox(width: 7),
                  _Swatch(tint),
                  const SizedBox(width: 3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 15),
                    child: Text(
                      reading,
                      textAlign: TextAlign.right,
                      style: numeral.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ]
              else ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 44),
                  child: Text(
                    value ?? '',
                    textAlign: TextAlign.right,
                    style: numeral.copyWith(color: theme.colorScheme.onSurface),
                  ),
                ),
              ],
              // After everything else, so its coming and going moves
              // nothing that was already there.
              for (final badge in badges) ...[
                const SizedBox(width: 6),
                _AidBadge(badge),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// [child] fading in once, when it is first built.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.duration(context, AppDurations.medium),
    curve: AppCurves.standard,
    builder: (context, opacity, child) =>
        Opacity(opacity: opacity, child: child),
    child: child,
  );
}

/// An aid named in the chip while the cursor is inside one of its episodes:
/// ink on the panel, so it reads as a state of the car rather than a value.
class _AidBadge extends StatelessWidget {
  const _AidBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: scheme.onSurface,
        shape: AppRadii.squircle(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.surface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

/// [child] scaled down to fit when [shrink], as it is otherwise.
class _ShrinkIf extends StatelessWidget {
  const _ShrinkIf(this.shrink, {required this.child});

  final bool shrink;
  final Widget child;

  @override
  Widget build(BuildContext context) => shrink
      ? FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: child,
        )
      : child;
}

/// A three-dot key: the reference lap's dotted line, at legend size.
class _DottedKeyPainter extends CustomPainter {
  const _DottedKeyPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final y = size.height / 2;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(1 + i * (size.width - 2) / 2, y), 1, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedKeyPainter old) => old.color != color;
}

/// What a panel fitted to its window scales to: [visible], or a tenth of
/// [full] around it where it spans less — so a channel that barely moves in
/// the window does not blow its noise up to the panel's height.
ValueRange shownRange(ValueRange full, ValueRange? visible) {
  if (visible == null) return full;
  final least = full.span * 0.1;
  if (visible.span >= least) return visible;
  final mid = (visible.min + visible.max) / 2;
  return ValueRange(mid - least / 2, mid + least / 2);
}

/// How far down the panel the chip reaches: its inset and its height.
const _chipBand = 32.0;

/// [values] raised so its top lands [_chipBand] below a [height] panel's top.
/// A panel too short to spare it is left as it is.
ValueRange _underChip(ValueRange values, double height) {
  if (height < _chipBand * 3) return values;
  return ValueRange(
    values.min,
    values.max + values.span * _chipBand / (height - _chipBand),
  );
}

/// A line's colour, as a dot beside the words or the number it keys.
class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: ShapeDecoration(shape: const CircleBorder(), color: color),
  );
}
