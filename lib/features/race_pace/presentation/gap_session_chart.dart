/// The gap to the car ahead over a whole session (SPEC.md §8.9).
///
/// A small custom-painted chart rather than `fl_chart`: it needs a min/max
/// envelope, lap boundaries, pit-lane shading and held-stretch dimming in one
/// frame, and none of those is a thing `fl_chart` draws. It borrows the chart
/// core's parts — the palette, the geometry, the tick generator, the cursor
/// with its floating readout — and none of its *sync*: nothing else scrubs
/// with it, so by §9.5's behavioural rule it stays standalone.
///
/// ## What is drawn, and why each mark is there
///
/// - **The envelope, then the line through it.** The trace is fetched
///   decimated (`sessionEnvelopeBuckets` min/max buckets) as §9.5 requires at
///   session scope, so each point is a span the gap covered rather than a
///   reading. Where it is smooth the band is a line's width; where it steps
///   inside one bucket the band thickens — the chart admitting there is detail
///   below its resolution instead of implying there was none.
/// - **Filled toward zero, one colour on both sides.** The baseline is "level
///   with the car ahead", and filling to the panel floor would paint 0.2 s
///   behind and 0.2 s ahead as different amounts of colour. Green for gained
///   and red for lost would borrow throttle's and brake's identities for a
///   meaning that is neither (§9.7.1), so the area is just the gap's own hue.
///   Up is closing, down is falling back.
/// - **Lap boundaries** as hairlines with the lap's number centred in its
///   span, thinned to every n-th when 150 of them would not fit — a skipped
///   label is cheaper than an unreadable strip.
/// - **Held stretches dimmed.** The reading is unchanged for 42.5 s on the grid
///   and 10.5 s after the flag in the Race sample; drawn at full strength they
///   read as a gap that held steady, which is not what happened.
/// - **A ring where the car ahead changed**, because the step there is a
///   different car, not the gap moving.
///
/// The cursor is its own layer above the trace, and the trace is in its own
/// [RepaintBoundary] — the arrangement §9.5 describes for the same reason: the
/// cursor moves at pointer rate, the trace only when the data does.
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/charting/painters/chart_painting.dart';
import '../../../widgets/charting/painters/cursor_painter.dart';
import '../../../widgets/charting/viewport.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/race_pace.dart';
import 'gap_format.dart';

/// Round steps of a clock rather than of decimal seconds: a tick at 300 s is
/// `5:00`, one at 250 s is `4:10`.
const _clockSteps = <double>[
  1, 2, 5, 10, 15, 30, 60, 120, 240, 300, 600, 900, 1800, 3600, 7200, //
  14400, 21600, 43200, 86400,
];

/// Tick times, in seconds from the recording's start, at a clock-friendly step
/// giving at most [target] intervals over [spanSeconds].
List<double> clockTicks(double spanSeconds, {int target = 6}) {
  if (spanSeconds <= 0) return const [0];
  final step = _clockSteps.firstWhere(
    (s) => spanSeconds / s <= target,
    orElse: () => _clockSteps.last,
  );
  return [for (var t = 0.0; t <= spanSeconds + 1e-9; t += step) t];
}

/// The value axis: the data and zero, padded.
///
/// Zero is always in frame — the line every reading is read against — so a
/// race spent entirely behind still shows where "level" is, and one spent
/// entirely ahead still shows how far from it.
ValueRange gapValueRange(TraceSeries envelope) {
  var low = 0.0;
  var high = 0.0;
  for (var i = 0; i < envelope.length; i++) {
    low = math.min(low, envelope.lows[i]);
    high = math.max(high, envelope.highs[i]);
  }
  return ValueRange(low, high).padded(fraction: 0.08, minimumPad: 0.5);
}

/// The chart's domain: from the recording's start to its last reading.
ChartViewport gapViewport(GapSession session) {
  final last = math.max(
    session.endSeconds,
    session.readings.isEmpty ? 0.0 : session.readings.times.last,
  );
  return ChartViewport(
    session.originSeconds,
    last > session.originSeconds ? last : session.originSeconds + 1,
  );
}

class GapSessionChart extends HookWidget {
  const GapSessionChart({
    super.key,
    required this.session,
    required this.color,
    required this.cursor,
    required this.highlightedChange,
    this.height = 300,
  });

  final GapSession session;

  /// The gap's identity colour ([ChannelColors.delta] — a time difference
  /// between two cars is the same kind of quantity as a lap delta).
  final Color color;

  /// The time the readout is anchored to, or null when nothing is. Owned by the
  /// screen so the list of car-ahead changes can move it as well as the pointer.
  final ValueNotifier<double?> cursor;

  /// Index into [GapSession.changes] to ring, when the list beside the chart is
  /// hovered or focused.
  final ValueNotifier<int?> highlightedChange;

  final double height;

  static const topStrip = 22.0;
  static const bottomStrip = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context, series: color);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final entrance = useAnimationController(duration: AppDurations.slow);
    useEffect(() {
      if (reduceMotion) {
        entrance.value = 1;
      } else {
        entrance.forward(from: 0);
      }
      return null;
    }, [reduceMotion, session]);

    final focus = useFocusNode(debugLabel: 'gap chart');
    final focused = useState(false);

    final viewport = gapViewport(session);
    final values = gapValueRange(session.envelope);
    final ticks = values.ticks(target: 4);
    final valueStep = ticks.length > 1 ? ticks[1] - ticks[0] : 1.0;

    KeyEventResult onKey(FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final readings = session.readings;
      if (readings.isEmpty) return KeyEventResult.ignored;
      final key = event.logicalKey;
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final now = cursor.value;
      final at = now == null
          ? null
          : firstReadingAtOrAfter(readings.times, now)
              .clamp(0, readings.length - 1);

      int? target;
      if (key == LogicalKeyboardKey.arrowRight) {
        target = at == null ? 0 : at + (shift ? 20 : 1);
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        target = at == null ? readings.length - 1 : at - (shift ? 20 : 1);
      } else if (key == LogicalKeyboardKey.home) {
        target = 0;
      } else if (key == LogicalKeyboardKey.end) {
        target = readings.length - 1;
      } else if (key == LogicalKeyboardKey.escape) {
        cursor.value = null;
        return KeyEventResult.handled;
      }
      if (target == null) return KeyEventResult.ignored;
      cursor.value = readings.times[target.clamp(0, readings.length - 1)];
      return KeyEventResult.handled;
    }

    return Semantics(
      container: true,
      label: 'Gap to the car ahead over the session, ${session.laps.length} '
          'laps. Use the left and right arrow keys to read it.',
      child: Focus(
        focusNode: focus,
        onKeyEvent: onKey,
        onFocusChange: (value) => focused.value = value,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.standard,
          // A ring while the chart has keyboard focus: the arrow keys move
          // its cursor, and a widget that responds to keys should say so.
          decoration: ShapeDecoration(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              side: BorderSide(
                color: focused.value
                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
          ),
          child: SizedBox(
            height: height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final plot = Size(width, height - topStrip - bottomStrip);
                final geometry = ChartGeometry(
                  viewport: viewport,
                  values: values,
                  size: plot,
                );

                double? snap(double dx) {
                  final near =
                      session.readingNear(geometry.domainAt(dx.clamp(0, width)));
                  return near?.seconds;
                }

                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: entrance,
                          builder: (context, _) => CustomPaint(
                            painter: GapChartPainter(
                              session: session,
                              geometry: geometry,
                              palette: palette,
                              valueTicks: ticks,
                              valueStep: valueStep,
                              timeTicks: clockTicks(
                                viewport.span,
                                target: math.max(3, width ~/ 120),
                              ),
                              progress:
                                  AppCurves.entrance.transform(entrance.value),
                              holdColor: theme.colorScheme.surface,
                              pitColor: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: topStrip,
                      height: plot.height,
                      child: IgnorePointer(
                        child: ValueListenableBuilder<int?>(
                          valueListenable: highlightedChange,
                          builder: (context, index, _) => CustomPaint(
                            painter: CarAheadHighlightPainter(
                              change: index == null ||
                                      index >= session.changes.length
                                  ? null
                                  : session.changes[index],
                              geometry: geometry,
                              color: theme.colorScheme.onSurface,
                              surface: theme.colorScheme.surface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: topStrip,
                      height: plot.height,
                      child: MouseRegion(
                        onHover: (event) =>
                            cursor.value = snap(event.localPosition.dx),
                        onExit: (_) => cursor.value = null,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            focus.requestFocus();
                            cursor.value = snap(details.localPosition.dx);
                          },
                          child: ValueListenableBuilder<double?>(
                            valueListenable: cursor,
                            builder: (context, at, _) {
                              final near =
                                  at == null ? null : session.readingNear(at);
                              return CustomPaint(
                                painter: CursorPainter(
                                  cursor: near?.seconds,
                                  geometry: geometry,
                                  palette: palette,
                                  value: near != null && isLiveGap(near.gap)
                                      ? near.gap
                                      : null,
                                  readout: near == null
                                      ? null
                                      : gapReadout(session, near.seconds),
                                ),
                                size: plot,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The floating readout for the reading at [seconds]: lap, session clock, gap.
///
/// Says when the reading is not a gap — `no car timed` for an exact zero,
/// `unchanged` inside a held stretch — because a readout that printed `-0.19 s`
/// at the 30-second mark would be stating something the file does not.
String gapReadout(GapSession session, double seconds) {
  final near = session.readingNear(seconds);
  if (near == null) return '';
  final lap = session.lapAt(near.seconds);
  // A run of zeros is already "no car timed"; calling it unchanged as well
  // would say the same thing twice.
  final live = isLiveGap(near.gap);
  final held = live &&
      (_inHold(session.heldAtStart, near.seconds) ||
          _inHold(session.heldAtEnd, near.seconds));
  final gap = live ? formatGap(near.gap) : 'no car timed';
  return [
    if (lap != null) 'Lap ${lap.displayNumber}',
    formatSessionClock(near.seconds, origin: session.originSeconds),
    gap,
    if (held) 'unchanged',
  ].join(' · ');
}

bool _inHold(HeldReadings? held, double seconds) =>
    held != null && seconds >= held.fromSeconds && seconds <= held.toSeconds;

/// Draws everything that is not the cursor.
class GapChartPainter extends CustomPainter {
  const GapChartPainter({
    required this.session,
    required this.geometry,
    required this.palette,
    required this.valueTicks,
    required this.valueStep,
    required this.timeTicks,
    required this.progress,
    required this.holdColor,
    required this.pitColor,
  });

  final GapSession session;

  /// Geometry of the *plot*, the area between the lap strip and the time axis.
  final ChartGeometry geometry;
  final ChartPalette palette;
  final List<double> valueTicks;
  final double valueStep;

  /// Seconds from the recording's start.
  final List<double> timeTicks;

  /// 0..1: how much of the data has drawn itself in, left to right.
  final double progress;

  final Color holdColor;
  final Color pitColor;

  double get _plotWidth => geometry.size.width;

  @override
  void paint(Canvas canvas, Size size) {
    _paintLapStrip(canvas);
    _paintTimeAxis(canvas, size);

    canvas.save();
    canvas.translate(0, GapSessionChart.topStrip);
    _paintPlot(canvas);
    canvas.restore();
  }

  void _paintPlot(Canvas canvas) {
    final plot = geometry.size;
    final zero = geometry.y(0);

    paintValueGrid(canvas, geometry, palette, ticks: [
      for (final tick in valueTicks)
        if (tick != 0) tick,
    ]);
    // "Level with the car ahead" is the line the chart is read against, so it
    // is heavier than the grid around it.
    canvas.drawLine(
      Offset(0, zero),
      Offset(plot.width, zero),
      Paint()
        ..color = palette.axisText.withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
    _paintLapLines(canvas, plot);
    _paintPitVisits(canvas, plot);

    // Everything below draws itself in from the left.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, plot.width * progress, plot.height));
    _paintEnvelope(canvas, plot, zero);
    _paintHeld(canvas, plot);
    _paintChangeMarkers(canvas);
    canvas.restore();

    paintValueLabels(
      canvas,
      geometry,
      palette,
      ticks: valueTicks,
      format: (value) => formatGapTick(value, valueStep),
    );
  }

  void _paintEnvelope(Canvas canvas, Size plot, double zero) {
    final e = session.envelope;
    if (e.length < 2) return;

    final mid = Path();
    final upper = Path();
    final lower = Path();
    for (var i = 0; i < e.length; i++) {
      final x = geometry.x(e.times[i]);
      final hy = geometry.y(e.highs[i]);
      final ly = geometry.y(e.lows[i]);
      final my = geometry.y((e.highs[i] + e.lows[i]) / 2);
      if (i == 0) {
        mid.moveTo(x, my);
        upper.moveTo(x, hy);
        lower.moveTo(x, ly);
      } else {
        mid.lineTo(x, my);
        upper.lineTo(x, hy);
        lower.lineTo(x, ly);
      }
    }
    final firstX = geometry.x(e.times.first);
    final lastX = geometry.x(e.times.last);

    // The area between the line and zero: the filled region *is* the time
    // gained or lost, on whichever side of level it falls.
    canvas.drawPath(
      Path.from(mid)
        ..lineTo(lastX, zero)
        ..lineTo(firstX, zero)
        ..close(),
      Paint()..color = palette.series.withValues(alpha: 0.2),
    );

    // The envelope as a closed band between its two edges.
    final band = Path.from(upper);
    for (var i = e.length - 1; i >= 0; i--) {
      band.lineTo(geometry.x(e.times[i]), geometry.y(e.lows[i]));
    }
    band.close();
    canvas.drawPath(band, Paint()..color = palette.series.withValues(alpha: 0.55));

    canvas.drawPath(
      mid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = palette.series,
    );
  }

  /// Dims the stretches the reading did not change over: laid over the trace
  /// in the card's own surface colour, so it reads as the line being *quiet*
  /// there rather than as a different mark.
  void _paintHeld(Canvas canvas, Size plot) {
    for (final held in [session.heldAtStart, session.heldAtEnd]) {
      if (held == null) continue;
      final left = geometry.x(held.fromSeconds).clamp(0.0, plot.width);
      final right = geometry.x(held.toSeconds).clamp(0.0, plot.width);
      if (right <= left) continue;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, plot.height),
        Paint()..color = holdColor.withValues(alpha: 0.55),
      );
    }
  }

  void _paintChangeMarkers(Canvas canvas) {
    for (final change in session.changes) {
      final at = Offset(
        geometry.x(change.timeSeconds),
        geometry.y(change.after),
      );
      canvas.drawCircle(at, 4.5, Paint()..color = holdColor);
      canvas.drawCircle(
        at,
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = palette.reference,
      );
    }
  }

  void _paintPitVisits(Canvas canvas, Size plot) {
    for (final visit in session.pitVisits) {
      final left = geometry.x(visit.enteredSeconds).clamp(0.0, plot.width);
      final right = geometry
          .x(visit.exitedSeconds ?? session.endSeconds)
          .clamp(0.0, plot.width);
      if (right <= left) continue;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, plot.height),
        Paint()..color = pitColor.withValues(alpha: 0.07),
      );
    }
  }

  /// Hairlines at each lap boundary, thinned to every n-th when there are too
  /// many to be lines rather than a hatch.
  void _paintLapLines(Canvas canvas, Size plot) {
    final every = _every(minPixels: 5);
    final paint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    for (var i = 0; i < session.laps.length; i += every) {
      final start = session.laps[i].lap.startSeconds;
      if (start <= geometry.viewport.start) continue;
      final x = geometry.x(start);
      canvas.drawLine(Offset(x, 0), Offset(x, plot.height), paint);
    }
  }

  /// The number of every lap, centred in its span, along the strip above the
  /// plot.
  void _paintLapStrip(Canvas canvas) {
    final every = _every(minPixels: 26);
    final style = palette.labelStyle;
    for (var i = 0; i < session.laps.length; i += every) {
      final lap = session.laps[i].lap;
      final left = geometry.x(math.max(lap.startSeconds, geometry.viewport.start));
      final right = geometry.x(
        math.min(lap.endSeconds ?? geometry.viewport.end, geometry.viewport.end),
      );
      final text = '${lap.displayNumber}';
      final measured = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      // A lap too narrow for its own number is skipped, not squeezed.
      if (right - left >= measured.width + 4) {
        measured.paint(
          canvas,
          Offset((left + right) / 2 - measured.width / 2, 4),
        );
      }
      measured.dispose();
    }
    paintText(
      canvas,
      'LAP',
      style.copyWith(fontSize: 9, letterSpacing: 0.8),
      const Offset(4, -1),
    );
  }

  void _paintTimeAxis(Canvas canvas, Size size) {
    final baseline = size.height - GapSessionChart.bottomStrip;
    final tick = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;
    final style = palette.labelStyle;
    for (final seconds in timeTicks) {
      final x = geometry.x(session.originSeconds + seconds);
      if (x < 0 || x > _plotWidth) continue;
      canvas.drawLine(Offset(x, baseline), Offset(x, baseline + 4), tick);
      final text = formatSessionDuration(seconds);
      final measured = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      // Kept inside the frame: the first label starts at the axis and the last
      // is pulled in rather than clipped.
      final left = (x - measured.width / 2).clamp(0.0, _plotWidth - measured.width);
      measured.paint(canvas, Offset(left, baseline + 7));
      measured.dispose();
    }
  }

  /// Every n-th lap so that laps stay at least [minPixels] apart, judged on
  /// their average width.
  int _every({required double minPixels}) {
    final laps = session.laps.length;
    if (laps == 0) return 1;
    final average = _plotWidth / laps;
    return math.max(1, (minPixels / math.max(average, 1)).ceil());
  }

  @override
  bool shouldRepaint(GapChartPainter old) =>
      !identical(old.session, session) ||
      old.geometry != geometry ||
      old.progress != progress ||
      old.palette.series != palette.series ||
      old.palette.grid != palette.grid ||
      old.holdColor != holdColor ||
      old.valueStep != valueStep;
}

/// Rings one change of car ahead and draws its moment as a dashed vertical —
/// how the list beside the chart points at what it lists. Public so a widget
/// test can see which change is ringed.
class CarAheadHighlightPainter extends CustomPainter {
  const CarAheadHighlightPainter({
    required this.change,
    required this.geometry,
    required this.color,
    required this.surface,
  });

  final CarAheadChange? change;
  final ChartGeometry geometry;
  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final change = this.change;
    if (change == null) return;
    final x = geometry.x(change.timeSeconds);
    canvas.drawPath(
      dashedPolyline([Offset(x, 0), Offset(x, size.height)], dash: 3, gap: 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.6),
    );
    // Both readings, so the step is visible as a span rather than only its end.
    for (final value in [change.before, change.after]) {
      final at = Offset(x, geometry.y(value));
      canvas.drawCircle(at, 6.5, Paint()..color = surface);
      canvas.drawCircle(
        at,
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(CarAheadHighlightPainter old) =>
      old.change != change || old.geometry != geometry || old.color != color;
}
