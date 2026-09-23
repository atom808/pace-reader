/// Shared painting plumbing for the chart core (SPEC.md §9.5).
///
/// Painters have no [BuildContext], so everything they need from the theme is
/// resolved once per build into [ChartPalette] and handed in. That is not
/// only a plumbing convenience: it is what lets every painter here be
/// exercised in a plain `flutter test` against explicit colours, instead of
/// only inside a themed widget tree.
library;

import 'package:material_ui/material_ui.dart';

import '../../design_system/typography_tokens.dart';
import '../viewport.dart';

/// Theme-derived colours and type a chart painter needs.
class ChartPalette {
  const ChartPalette({
    required this.series,
    required this.reference,
    required this.grid,
    required this.axisText,
    required this.cursor,
    required this.surface,
    required this.labelStyle,
  });

  /// Resolves the palette from the ambient theme.
  ///
  /// [series] stays a parameter rather than being read from
  /// [ChannelColors]: which channel a panel plots is the feature's decision,
  /// and a painter that looked it up by name would need to know the channel
  /// catalog.
  factory ChartPalette.of(BuildContext context, {required Color series}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ChartPalette(
      series: series,
      // The same hue, lifted toward the ink colour: a reference lap is the
      // same channel (§9.7.1 — one colour per channel type, not per lap), and
      // it is drawn dotted *over* the primary's filled area, where the
      // primary's own colour would sink into its fill.
      reference: Color.lerp(series, scheme.onSurface, 0.35)!,
      // Recessive on purpose: gridlines orient the eye and must never compete
      // with the trace for it.
      grid: scheme.outlineVariant.withValues(alpha: 0.45),
      axisText: scheme.onSurfaceVariant,
      cursor: scheme.onSurface.withValues(alpha: 0.75),
      surface: scheme.surfaceContainerLow,
      // Axis numerals wear the tabular face for the same reason lap times do
      // (§9.7.7): the labels change as the viewport moves, and digits of
      // different widths make the axis jitter as they do.
      labelStyle: AppTextStyles.numeral.copyWith(
        fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  final Color series;

  /// A reference lap's line — see [ChartPalette.of].
  final Color reference;

  final Color grid;
  final Color axisText;
  final Color cursor;
  final Color surface;
  final TextStyle labelStyle;
}

/// Maps domain/value coordinates to pixels inside one panel.
///
/// A value type rather than a set of closures so painters can compare two of
/// them in `shouldRepaint` — the cheapest way to keep a cursor move from
/// redrawing a 6000-point trace.
class ChartGeometry {
  const ChartGeometry({
    required this.viewport,
    required this.values,
    required this.size,
  });

  final ChartViewport viewport;
  final ValueRange values;
  final Size size;

  double x(double domain) => viewport.toPixels(domain, size.width);

  /// Value axis, inverted: larger values sit higher on screen.
  double y(double value) => size.height * (1 - values.normalize(value));

  double domainAt(double pixels) => viewport.toDomain(pixels, size.width);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartGeometry &&
          other.viewport == viewport &&
          other.values == values &&
          other.size == size);

  @override
  int get hashCode => Object.hash(viewport, values, size);
}

/// Draws the value gridlines. Recessive, and always *under* the trace.
void paintValueGrid(
  Canvas canvas,
  ChartGeometry geometry,
  ChartPalette palette, {
  required List<double> ticks,
}) {
  final paint = Paint()
    ..color = palette.grid
    ..strokeWidth = 1;
  for (final tick in ticks) {
    final y = geometry.y(tick);
    if (y < 0 || y > geometry.size.height) continue;
    canvas.drawLine(Offset(0, y), Offset(geometry.size.width, y), paint);
  }
}

/// Draws the value-axis labels, **after** the trace rather than with the
/// gridlines.
///
/// Labels sit inside the plot against its left edge rather than in a reserved
/// gutter: with six stacked panels a gutter costs the same width six times
/// over, and a recessive label overlapping a trace is easier to read past
/// than a sixth of every panel being empty. Painting them last, over a halo
/// in the panel's own surface colour, is what keeps them readable where they
/// do overlap — drawn with the gridlines they end up *under* the trace, which
/// is where a filled area hides them.
void paintValueLabels(
  Canvas canvas,
  ChartGeometry geometry,
  ChartPalette palette, {
  required List<double> ticks,
  required String Function(double) format,
}) {
  final style = palette.labelStyle.copyWith(
    shadows: [
      Shadow(color: palette.surface, blurRadius: 3),
      Shadow(color: palette.surface, blurRadius: 3),
    ],
  );
  for (final tick in ticks) {
    final y = geometry.y(tick);
    if (y < 0 || y > geometry.size.height) continue;
    // Normally just above its line so the glyphs rest on it rather than run
    // through it — flipped below when the line is at the very top, where a
    // label drawn above the panel would land on the panel's own title.
    const labelHeight = 14.0;
    final labelY = y - labelHeight < 0 ? y + 2 : y - labelHeight;
    paintText(canvas, format(tick), style, Offset(4, labelY),
        maxWidth: geometry.size.width);
  }
}

/// Draws the domain gridlines shared by every panel in a synced stack.
void paintDomainGrid(
  Canvas canvas,
  ChartGeometry geometry,
  ChartPalette palette, {
  required List<double> ticks,
}) {
  final paint = Paint()
    ..color = palette.grid
    ..strokeWidth = 1;
  for (final tick in ticks) {
    final x = geometry.x(tick);
    if (x < 0 || x > geometry.size.width) continue;
    canvas.drawLine(Offset(x, 0), Offset(x, geometry.size.height), paint);
  }
}

/// A polyline through [points], broken into [dash]-long strokes separated by
/// [gap] — how a reference lap is drawn (§7.1, §9.7.1: a solid filled trace
/// for the lap being inspected, a dotted line for the one it is compared with).
///
/// Dashes are measured along the line rather than along x, so a steep stretch
/// — a brake application — is dotted as densely as a flat one. Spacing them by
/// x would draw every spike in the reference as one solid stroke, which is
/// exactly where the two laps most need telling apart.
Path dashedPolyline(List<Offset> points, {double dash = 2, double gap = 3}) {
  final path = Path();
  if (points.length < 2) return path;
  var drawing = true;
  var left = dash;
  var current = points.first;
  path.moveTo(current.dx, current.dy);
  void advanceTo(Offset point) {
    if (drawing) {
      path.lineTo(point.dx, point.dy);
    } else {
      path.moveTo(point.dx, point.dy);
    }
  }

  for (var i = 1; i < points.length; i++) {
    final next = points[i];
    var remaining = (next - current).distance;
    // Every dash or gap that ends inside this segment, then whatever of the
    // current one the segment's remainder covers.
    while (remaining >= left) {
      current = Offset.lerp(current, next, left / remaining)!;
      advanceTo(current);
      remaining -= left;
      drawing = !drawing;
      left = drawing ? dash : gap;
    }
    advanceTo(next);
    left -= remaining;
    current = next;
  }
  return path;
}

/// Lays out and paints a single line of text. Returns its size.
Size paintText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset at, {
  double maxWidth = double.infinity,
  TextAlign align = TextAlign.left,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
  )..layout(maxWidth: maxWidth);
  painter.paint(canvas, at);
  final size = painter.size;
  painter.dispose();
  return size;
}
