import 'package:material_ui/material_ui.dart';

import '../../data/reference/car_catalog.dart';
import '../../data/reference/car_class.dart';
import '../design_system/design_system.dart';
import 'class_chip.dart';

/// How much room a [CarLabel] has.
enum CarLabelSize {
  /// One line in a list row: class chip, then "Porsche 911 GT3 R · Iron
  /// Dames #85" and whatever the row adds.
  compact,

  /// Two lines in a card: the car's mark, the model, and beneath it the class
  /// chip and the entry.
  row,

  /// A page header's: the model as a headline beside a large mark.
  hero,
}

/// A recording's car, by its model.
///
/// The file names only the entry ("Iron Dames 2025 #85:LM"), so the model
/// comes from Pace Reader's catalog ([placeCar]); the entry follows it, as
/// the team and number that tell two of the same car apart. An entry the
/// catalog cannot place shows its own name, never a guess.
///
/// - **Hover** says how the model was placed, and the file's own name.
/// - **A screen reader** hears "Porsche 911 GT3 R, Iron Dames 2025, number
///   85", then the class chip.
/// - **A change of car** cross-fades the mark and text; the class chip
///   animates its own colours.
class CarLabel extends StatelessWidget {
  const CarLabel({
    super.key,
    required this.placement,
    this.size = CarLabelSize.compact,
    this.trailing = const [],
    this.showEntry = true,
    this.showClass = true,
    this.style,
  });

  /// [CarLabel] for the file's raw `CarName` and `CarClass`.
  CarLabel.of(
    String carName,
    String carClass, {
    Key? key,
    CarLabelSize size = CarLabelSize.compact,
    List<String> trailing = const [],
    bool showEntry = true,
    bool showClass = true,
    TextStyle? style,
  }) : this(
         key: key,
         placement: placeCar(carName, carClass),
         size: size,
         trailing: trailing,
         showEntry: showEntry,
         showClass: showClass,
         style: style,
       );

  final CarPlacement placement;
  final CarLabelSize size;

  /// More of the line, after the car: the driver, a best lap.
  final List<String> trailing;

  /// Whether the entry follows the model. Off where the row names the
  /// session's other facts instead.
  final bool showEntry;

  /// Whether the class chip leads. Off where the class is already shown.
  final bool showClass;

  /// The compact line's style; the theme's muted small text otherwise.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = placement;
    final spoken = [
      if (showEntry) p.spokenLabel else p.title,
      ...trailing,
    ].join(', ');
    final message = [p.reason, 'In the file: ${p.entry.raw}'].join('\n');
    final label = switch (size) {
      CarLabelSize.compact => _Compact(label: this),
      CarLabelSize.row => _Stacked(label: this, hero: false),
      CarLabelSize.hero => _Stacked(label: this, hero: true),
    };
    // One tooltip over the whole label: the class chip inside keeps its own,
    // and hovering it shows only that one.
    return AppTooltip(
      message: message,
      child: Semantics(container: true, label: spoken, child: label),
    );
  }
}

class _Compact extends StatelessWidget {
  const _Compact({required this.label});

  final CarLabel label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = label.placement;
    final base =
        label.style ??
        theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    final rest = [
      if (label.showEntry && p.isPlaced) p.entryShortLabel,
      ...label.trailing,
    ];
    return Row(
      children: [
        if (label.showClass) ...[
          ClassChip(carClass: p.carClass, size: ClassChipSize.compact),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: ExcludeSemantics(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  // The model leads, a shade brighter: it is what the line
                  // is for.
                  TextSpan(
                    text: p.title,
                    style: TextStyle(
                      color: Color.lerp(
                        base.color,
                        theme.colorScheme.onSurface,
                        0.45,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  for (final part in rest) ...[
                    const TextSpan(text: ' · '),
                    ...numeralSpans(part, base),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _Stacked extends StatelessWidget {
  const _Stacked({required this.label, required this.hero});

  final CarLabel label;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = label.placement;
    final duration = AppMotion.duration(context, AppDurations.medium);
    final markHeight = hero ? 40.0 : 24.0;
    final titleStyle = hero
        ? theme.textTheme.headlineSmall
        : theme.textTheme.titleMedium;
    final entryStyle =
        (hero ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)!
            .copyWith(color: muted);
    final entry = [
      if (label.showEntry) p.isPlaced ? p.entryLabel : null,
      ...label.trailing,
    ].nonNulls.join(' · ');

    Widget fade(Widget child) => FadeOnChange(
      value: p.entry.raw,
      duration: duration,
      switchInCurve: AppCurves.standard,
      child: child,
    );

    return Row(
      children: [
        ExcludeSemantics(
          child: fade(CarMark(placement: p, height: markHeight)),
        ),
        SizedBox(width: hero ? 16 : 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: fade(
                  Text(
                    p.title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(height: hero ? 6 : 3),
              Row(
                children: [
                  if (label.showClass) ...[
                    ClassChip(
                      carClass: p.carClass,
                      size: hero
                          ? ClassChipSize.regular
                          : ClassChipSize.compact,
                    ),
                    SizedBox(width: hero ? 8 : 6),
                  ],
                  if (entry.isNotEmpty)
                    Flexible(
                      child: ExcludeSemantics(
                        child: fade(
                          Text.rich(
                            TextSpan(
                              style: entryStyle,
                              children: numeralSpans(entry, entryStyle),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// [text] with its numbers ("2025", "#85", a lap time) in the numeral face,
/// as the library's lines set them.
List<TextSpan> numeralSpans(String text, TextStyle base) {
  final numeral = AppTextStyles.numeral.copyWith(
    fontSize: base.fontSize,
    color: base.color,
    fontWeight: base.fontWeight,
    height: base.height,
  );
  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in RegExp(r'\d[\d.:,]*').allMatches(text)) {
    if (match.start > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    spans.add(TextSpan(text: match[0], style: numeral));
    cursor = match.end;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}

/// A car's mark: until the game's make logos are read (a later step), a
/// side view of its kind of car, a prototype or a GT, in Pace Reader's own
/// drawing. Twice as wide as [height], the box a make's logo will fill.
class CarMark extends StatelessWidget {
  const CarMark({super.key, required this.placement, this.height = 20});

  final CarPlacement placement;
  final double height;

  @override
  Widget build(BuildContext context) {
    final kind = placement.model?.kind ?? placement.carClass.kind;
    final prototype = switch (kind) {
      CarClassKind.hypercar || CarClassKind.lmp2 || CarClassKind.lmp3 => true,
      _ => false,
    };
    return SizedBox(
      width: height * 2,
      height: height,
      child: CustomPaint(
        painter: CarGlyphPainter(
          prototype: prototype,
          color: Theme.of(context).colorScheme.onSurfaceVariant
              .withValues(alpha: placement.isPlaced ? 0.75 : 0.4),
        ),
      ),
    );
  }
}

/// A car side-on, nose to the right, in a 2:1 box: a prototype (low, an
/// open canopy, a fin to a wing on endplates) or a GT (a roofline with its
/// side glass, a wing on a stalk). One flat shape with the wheels cut free,
/// so it reads on any surface at 20 px and 40.
class CarGlyphPainter extends CustomPainter {
  const CarGlyphPainter({required this.prototype, required this.color});

  final bool prototype;
  final Color color;

  /// The drawing's own units: 48 × 24.
  static const _w = 48.0;

  static const _wheelRadius = 3.9;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _w;
    canvas.save();
    canvas.translate(0, (size.height - _w / 2 * scale) / 2);
    canvas.scale(scale);
    final (shape, glass, wheels) = prototype ? _prototype() : _gt();
    final arches = Path();
    final tyres = Path();
    final hubs = Path();
    for (final centre in wheels) {
      arches.addOval(Rect.fromCircle(center: centre, radius: _wheelRadius + 1));
      tyres.addOval(Rect.fromCircle(center: centre, radius: _wheelRadius));
      hubs.addOval(
        Rect.fromCircle(center: centre, radius: _wheelRadius * 0.38),
      );
    }
    final body = Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, shape, arches),
      glass,
    );
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;
    canvas.drawPath(body, paint);
    canvas.drawPath(Path.combine(PathOperation.difference, tyres, hubs), paint);
    canvas.restore();
  }

  static Path _union(List<Path> paths) =>
      paths.reduce((a, b) => Path.combine(PathOperation.union, a, b));

  static (Path, Path, List<Offset>) _prototype() {
    final body = Path()
      ..moveTo(47.4, 18.0)
      ..cubicTo(47.0, 16.2, 45.6, 14.8, 43.2, 14.2)
      ..cubicTo(41.6, 12.0, 35.2, 11.6, 33.0, 13.0)
      ..lineTo(31.4, 13.2)
      ..cubicTo(29.6, 10.6, 27.0, 9.2, 23.6, 9.0)
      ..cubicTo(20.8, 8.9, 18.8, 9.6, 17.6, 10.6)
      ..lineTo(14.0, 11.4)
      ..cubicTo(12.6, 10.8, 7.6, 10.8, 5.6, 11.8)
      ..lineTo(1.2, 12.8)
      ..lineTo(1.2, 17.2)
      ..lineTo(2.6, 18.6)
      ..lineTo(46.4, 18.6)
      ..close();
    // The fin runs from the canopy to the wing.
    final fin = Path()
      ..moveTo(18.8, 10.2)
      ..lineTo(4.4, 7.8)
      ..lineTo(4.4, 11.4)
      ..close();
    final wing = Path()
      ..addRRect(
        RRect.fromLTRBR(0.4, 7.0, 9.6, 8.5, const Radius.circular(0.7)),
      )
      ..addRect(const Rect.fromLTRB(0.8, 7.8, 2.2, 13.2));
    final canopy = Path()
      ..moveTo(29.4, 12.6)
      ..cubicTo(28.2, 11.2, 26.4, 10.3, 24.0, 10.2)
      ..lineTo(21.0, 10.3)
      ..lineTo(19.8, 12.0)
      ..close();
    return (
      _union([body, fin, wing]),
      canopy,
      const [Offset(38.0, 17.6), Offset(10.4, 17.6)],
    );
  }

  static (Path, Path, List<Offset>) _gt() {
    final body = Path()
      ..moveTo(47.4, 17.4)
      ..cubicTo(47.4, 15.4, 46.6, 13.8, 44.0, 13.2)
      ..cubicTo(40.0, 12.2, 35.0, 11.9, 31.4, 11.6)
      ..cubicTo(28.8, 9.4, 25.6, 7.2, 22.0, 6.9)
      ..cubicTo(18.8, 6.7, 15.6, 7.2, 13.4, 8.6)
      ..cubicTo(11.0, 10.0, 7.4, 10.6, 3.4, 11.0)
      ..lineTo(1.4, 11.8)
      ..lineTo(1.2, 17.0)
      ..lineTo(2.6, 18.6)
      ..lineTo(46.0, 18.6)
      ..close();
    final wing = Path()
      ..addRRect(
        RRect.fromLTRBR(0.4, 6.4, 9.2, 7.8, const Radius.circular(0.7)),
      )
      ..addRect(const Rect.fromLTRB(5.4, 7.2, 6.6, 11.0));
    final glass = Path()
      ..moveTo(29.6, 11.4)
      ..cubicTo(27.6, 9.8, 25.4, 8.4, 22.4, 8.2)
      ..cubicTo(19.6, 8.0, 17.0, 8.5, 15.0, 9.6)
      ..lineTo(13.8, 11.0)
      ..close();
    return (
      _union([body, wing]),
      glass,
      const [Offset(38.2, 17.6), Offset(10.4, 17.6)],
    );
  }

  @override
  bool shouldRepaint(CarGlyphPainter old) =>
      old.prototype != prototype || old.color != color;
}
