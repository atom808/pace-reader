import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/car_setup.dart';
import 'setting_widgets.dart';

/// `gearGraph` as a shift diagram and a per-gear table (SPEC.md §8.10).
///
/// The diagram is one channel — engine rpm — against speed, drawn as a
/// sawtooth: each rising line is a gear, each drop is the upshift into the
/// next. One colour, because it is one quantity (§9.7.1), with the gear
/// numbers written on the lines rather than encoded as a hue. The dotted
/// verticals are the shifts and the dots are the rev limit each gear runs
/// into, which is the whole of what a gearing decision is made from: how far
/// apart the gears are, and how far the rpm falls at each shift.
///
/// The table beside it holds every number the diagram draws, so nothing is
/// readable only by hovering; hovering a table row lights its line, and
/// hovering the diagram lights its row.
///
/// Figures are the game's nominal ones — right in ratio and in the size of each
/// shift, a few percent low in absolute speed against what the car ran
/// (`car_setup.dart`) — so the caption says "nominal" rather than implying a
/// lap will reach them.
class GearPanel extends HookWidget {
  const GearPanel({super.key, required this.graph});

  final GearGraph graph;

  @override
  Widget build(BuildContext context) {
    final hovered = useValueNotifier<int?>(null);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 780;
        final diagram = _Diagram(graph: graph, hovered: hovered);
        final table = _GearTable(graph: graph, hovered: hovered);
        return DecoratedBox(
          decoration: ShapeDecoration(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            color: AppColors.surfaceLow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Shift diagram', style: theme.textTheme.titleSmall),
                    const SizedBox(width: 8),
                    Text(
                      'rpm against speed, one line per gear',
                      style: theme.textTheme.labelSmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: diagram),
                      const SizedBox(width: 24),
                      Expanded(flex: 9, child: table),
                    ],
                  )
                else ...[
                  diagram,
                  const SizedBox(height: 16),
                  table,
                ],
                const SizedBox(height: 10),
                Text(
                  'Nominal figures from the setup: the dotted drops are the '
                  'upshifts, the dots the rev limit each gear runs into.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _thousands(num value) {
  final digits = value.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

class _Diagram extends HookWidget {
  const _Diagram({required this.graph, required this.hovered});

  final GearGraph graph;
  final ValueNotifier<int?> hovered;

  static const _height = 250.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // The line is drawn in from the left when the section opens: the shape of
    // the sawtooth *is* the finding, and watching it draw shows the order the
    // gears come in. Not replayed on hover or resize.
    final draw = useAnimationController(
      duration: AppDurations.slow,
      initialValue: reduceMotion ? 1 : 0,
    );
    useEffect(() {
      if (reduceMotion) {
        draw.value = 1;
      } else {
        draw.forward();
      }
      return null;
    }, [reduceMotion]);

    final painter = _ShiftPainter(
      graph: graph,
      hovered: hovered,
      progress: draw,
      line: ChannelColors.resolve(context).rpm,
      ink: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      grid: scheme.outlineVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, _height);
        return MouseRegion(
          onHover: (event) =>
              hovered.value = painter.gearAt(event.localPosition, size),
          onExit: (_) => hovered.value = null,
          child: Semantics(
            label:
                'Shift diagram: engine rpm against speed for '
                '${graph.steps.length} gears',
            child: RepaintBoundary(
              child: CustomPaint(size: size, painter: painter),
            ),
          ),
        );
      },
    );
  }
}

class _ShiftPainter extends CustomPainter {
  _ShiftPainter({
    required this.graph,
    required this.hovered,
    required this.progress,
    required this.line,
    required this.ink,
    required this.muted,
    required this.grid,
  }) : super(repaint: Listenable.merge([hovered, progress]));

  final GearGraph graph;
  final ValueNotifier<int?> hovered;
  final Animation<double> progress;
  final Color line;
  final Color ink;
  final Color muted;
  final Color grid;

  static const _left = 48.0;
  static const _right = 14.0;
  static const _top = 26.0;
  static const _bottom = 30.0;

  late final double _speedMax = _ceil(
    graph.maxSpeed,
    _speedStep(graph.maxSpeed),
  );
  late final double _rpmMax = _ceil(graph.maxRpm, _rpmStep(graph.maxRpm));

  static double _speedStep(double max) => max > 260 ? 50 : 25;
  static double _rpmStep(double max) => max > 8000 ? 2000 : 1000;
  static double _ceil(double v, double step) => (v / step).ceil() * step;

  Rect _plot(Size size) => Rect.fromLTRB(
    _left,
    _top,
    math.max(_left + 40, size.width - _right),
    size.height - _bottom,
  );

  Offset _at(Rect plot, double speed, double rpm) => Offset(
    plot.left + speed / _speedMax * plot.width,
    plot.bottom - rpm / _rpmMax * plot.height,
  );

  /// The gear whose speed span holds [position], or null off the plot.
  int? gearAt(Offset position, Size size) {
    final plot = _plot(size);
    if (position.dx < plot.left - 4 ||
        position.dx > plot.right + 4 ||
        position.dy < plot.top - 8 ||
        position.dy > plot.bottom + 8) {
      return null;
    }
    final speed = (position.dx - plot.left) / plot.width * _speedMax;
    for (final step in graph.steps) {
      if (speed <= step.topSpeed) return step.gear;
    }
    return graph.steps.last.gear;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plot(size);
    _paintGrid(canvas, size, plot);

    // Wipe in from the left.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        0,
        0,
        plot.left +
            (plot.width + _right) *
                Curves.easeOutCubic.transform(progress.value),
        size.height,
      ),
    );

    final lit = hovered.value;
    final dash = Paint()
      ..color = line.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;
    for (final step in graph.steps) {
      final after = step.rpmAfterUpshift;
      if (after == null) continue;
      _dashedVertical(
        canvas,
        dash,
        _at(plot, step.topSpeed, step.upshiftRpm),
        _at(plot, step.topSpeed, after),
      );
    }

    for (final step in graph.steps) {
      final dim = lit != null && lit != step.gear;
      final from = _at(plot, step.entrySpeed, step.entryRpm);
      final to = _at(plot, step.topSpeed, step.upshiftRpm);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = line.withValues(alpha: dim ? 0.3 : 1)
          ..strokeWidth = lit == step.gear ? 4 : 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        to,
        lit == step.gear ? 4.5 : 3,
        Paint()..color = line.withValues(alpha: dim ? 0.3 : 1),
      );
      _label(
        canvas,
        '${step.gear}',
        Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2) +
            const Offset(-11, -14),
        color: dim ? muted.withValues(alpha: 0.6) : ink,
        size: lit == step.gear ? 13 : 11,
        weight: FontWeight.w600,
        center: true,
        middle: true,
      );
    }
    canvas.restore();

    _paintReadout(canvas, plot);
  }

  void _paintGrid(Canvas canvas, Size size, Rect plot) {
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final rpmStep = _rpmStep(graph.maxRpm);
    for (var rpm = 0.0; rpm <= _rpmMax + 1; rpm += rpmStep) {
      final y = _at(plot, 0, rpm).dy;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        _thousands(rpm),
        Offset(plot.left - 8, y),
        color: muted,
        size: 10,
        alignRight: true,
        middle: true,
      );
    }
    final speedStep = _speedStep(graph.maxSpeed);
    for (var speed = 0.0; speed <= _speedMax + 1; speed += speedStep) {
      final x = _at(plot, speed, 0).dx;
      canvas.drawLine(
        Offset(x, plot.bottom),
        Offset(x, plot.bottom + 4),
        gridPaint..color = grid,
      );
      _label(
        canvas,
        speed.round().toString(),
        Offset(x, plot.bottom + 7),
        color: muted,
        size: 10,
        center: true,
      );
    }
    _label(
      canvas,
      'rpm',
      Offset(plot.left - 8, plot.top - 16),
      color: muted,
      size: 10,
      alignRight: true,
      middle: true,
    );
    _label(
      canvas,
      graph.unit,
      Offset(plot.right, plot.bottom + 17),
      color: muted,
      size: 10,
      alignRight: true,
    );
  }

  void _paintReadout(Canvas canvas, Rect plot) {
    final gear = hovered.value;
    if (gear == null) return;
    final step = graph.steps.firstWhere((s) => s.gear == gear);
    final drop = step.rpmAfterUpshift == null
        ? 'top gear'
        : 'drops to ${_thousands(step.rpmAfterUpshift!)} rpm';
    _label(
      canvas,
      'Gear $gear · ${step.topSpeed.toStringAsFixed(1)} ${graph.unit} at '
      '${_thousands(step.upshiftRpm)} rpm · $drop',
      Offset(plot.left + 2, plot.top - 16),
      color: ink,
      size: 11,
      middle: true,
    );
  }

  void _dashedVertical(Canvas canvas, Paint paint, Offset a, Offset b) {
    const dash = 3.0;
    const gap = 3.0;
    var y = a.dy;
    while (y < b.dy) {
      canvas.drawLine(
        Offset(a.dx, y),
        Offset(a.dx, math.min(y + dash, b.dy)),
        paint,
      );
      y += dash + gap;
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    required Color color,
    required double size,
    FontWeight weight = FontWeight.w400,
    bool center = false,
    bool alignRight = false,
    bool middle = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTextStyles.numeral.copyWith(
          fontSize: size,
          color: color,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center
        ? at.dx - painter.width / 2
        : alignRight
        ? at.dx - painter.width
        : at.dx;
    final dy = middle ? at.dy - painter.height / 2 : at.dy;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ShiftPainter old) =>
      old.graph != graph ||
      old.line != line ||
      old.ink != ink ||
      old.muted != muted ||
      old.grid != grid;
}

class _GearTable extends StatelessWidget {
  const _GearTable({required this.graph, required this.hovered});

  final GearGraph graph;
  final ValueNotifier<int?> hovered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final head = theme.textTheme.bodySmall?.copyWith(color: muted);

    Widget cell(
      String text, {
      TextStyle? style,
      int flex = 3,
      TextAlign align = TextAlign.right,
    }) => Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: align),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              cell('Gear', style: head, flex: 2, align: TextAlign.left),
              cell('Top speed', style: head),
              cell('Upshift', style: head),
              cell('After shift', style: head),
              cell('Drop', style: head),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              cell('', flex: 2),
              cell(graph.unit, style: head?.copyWith(fontSize: 11)),
              cell('rpm', style: head?.copyWith(fontSize: 11)),
              cell('rpm', style: head?.copyWith(fontSize: 11)),
              cell('rpm', style: head?.copyWith(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: theme.colorScheme.outlineVariant),
        const SizedBox(height: 4),
        for (final step in graph.steps)
          ValueListenableBuilder<int?>(
            valueListenable: hovered,
            builder: (context, lit, _) => MouseRegion(
              onEnter: (_) => hovered.value = step.gear,
              onExit: (_) {
                if (hovered.value == step.gear) hovered.value = null;
              },
              child: HoverRow(
                active: lit == step.gear,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      cell(
                        '${step.gear}',
                        flex: 2,
                        align: TextAlign.left,
                        style: AppTextStyles.numeral.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      cell(step.topSpeed.toStringAsFixed(1), style: _num),
                      cell(_thousands(step.upshiftRpm), style: _num),
                      cell(
                        step.rpmAfterUpshift == null
                            ? '—'
                            : _thousands(step.rpmAfterUpshift!),
                        style: _num,
                      ),
                      cell(
                        step.rpmDrop == null ? '—' : _thousands(step.rpmDrop!),
                        style: _num,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static final _num = AppTextStyles.numeral.copyWith(fontSize: 13);
}
