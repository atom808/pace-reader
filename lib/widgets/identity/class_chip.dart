import 'package:material_ui/material_ui.dart';

import '../../data/reference/car_class.dart';
import '../design_system/design_system.dart';

/// How much room a [ClassChip] has.
enum ClassChipSize {
  /// 16 px, short code (`HY`, `GT3`): the secondary line of a list row.
  compact(height: 16, fontSize: 9.5, padding: 4, radius: 8),

  /// 20 px, full name: a header line or a row of condition chips.
  regular(height: 20, fontSize: 10.5, padding: 6, radius: 10),

  /// 28 px, full name: beside Material chips in a page header.
  large(height: 28, fontSize: 12, padding: 10, radius: 12);

  const ClassChipSize({
    required this.height,
    required this.fontSize,
    required this.padding,
    required this.radius,
  });

  final double height;
  final double fontSize;
  final double padding;
  final double radius;
}

/// A car class as Le Mans Ultimate badges it: a block of the class's colour
/// with its name, the ELMS LMP2 marked by an orange corner.
///
/// Every screen that names a class shows this rather than the file's code,
/// so "Hyper" in the file reads as the same red HYPERCAR in the library, the
/// switcher, Overview, Compare, Setup and Technique.
///
/// - **Colour** is [ClassColors], the game's own.
/// - **The label** is white, as the game letters every class, wherever white
///   measures at least 3:1 on the fill: Hypercar 4.7:1, LMP2 8.1:1, LMP3
///   13.9:1 and LMGT3 3.9:1. LMGTE's orange is the exception: white measures
///   2.5:1 there, so it is lettered near-black.
/// - **The edge** is the fill lifted in lightness. LMP2 and LMP3 are dark
///   blocks on a near-black surface (2.5:1 and 1.4:1), and without it they
///   stop reading as objects. Every class gets one, so none looks different
///   in kind.
/// - **A change of class** animates the colours rather than snapping, the
///   way the session switcher's other contents cross-fade.
class ClassChip extends StatelessWidget {
  const ClassChip({
    super.key,
    required this.carClass,
    this.size = ClassChipSize.regular,
  });

  /// [ClassChip] for the file's raw `CarClass` value.
  ClassChip.raw(
    String raw, {
    Key? key,
    ClassChipSize size = ClassChipSize.regular,
  }) : this(key: key, carClass: CarClass.parse(raw), size: size);

  final CarClass carClass;
  final ClassChipSize size;

  @override
  Widget build(BuildContext context) {
    final cls = carClass;
    final text = (size == ClassChipSize.compact ? cls.shortCode : cls.name)
        .toUpperCase();
    return AppTooltip(
      message: classTooltip(cls),
      child: Semantics(
        label: '${cls.label} class',
        child: ExcludeSemantics(
          child: _AnimatedClassBlock(
            palette: ClassPalette.of(context, cls),
            radius: size.radius,
            // Sized to its label, whatever room the parent offers: a
            // `Container(alignment:)` here grows to a Wrap's full width.
            child: SizedBox(
              height: size.height,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: size.padding),
                child: Center(
                  widthFactor: 1,
                  child: _ClassLabel(text: text, fontSize: size.fontSize),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The class colour alone, with its edge and ELMS corner: the leading mark
/// on a filter chip whose own label already names the class.
class ClassSwatch extends StatelessWidget {
  const ClassSwatch({super.key, required this.carClass, this.size = 12});

  final CarClass carClass;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: _AnimatedClassBlock(
        palette: ClassPalette.of(context, carClass),
        // Tighter corners and a longer leg than the chip's: at 12 px a
        // chip-shaped corner curves away exactly where the ELMS triangle sits.
        radius: size * 0.4,
        markerLeg: 0.55,
        child: SizedBox.square(dimension: size),
      ),
    );
  }
}

/// What a [ClassChip]'s tooltip says: the name, what the ELMS corner means,
/// and the file's own code, so the mapping is never hidden.
String classTooltip(CarClass cls) => switch (cls.kind) {
  CarClassKind.unknown =>
    'Car class "${cls.raw}", as the file names it. Pace Reader has no colour '
        'for it yet.',
  _ when cls.elms =>
    'LMP2 ELMS: the European Le Mans Series LMP2, run without the WEC '
        'restrictor. The orange corner marks it, as in the game.\n'
        'The file\'s CarClass is "${cls.raw}".',
  _ => '${cls.name}. The file\'s CarClass is "${cls.raw}".',
};

/// The colours a class is drawn in.
@immutable
class ClassPalette {
  const ClassPalette({
    required this.fill,
    required this.edge,
    required this.label,
    required this.marker,
  });

  /// The class's palette; neutral surface tones for a class with no colour.
  factory ClassPalette.of(BuildContext context, CarClass cls) {
    final fill = switch (cls.kind) {
      CarClassKind.hypercar => ClassColors.hypercar,
      CarClassKind.lmp2 => ClassColors.lmp2,
      CarClassKind.lmp3 => ClassColors.lmp3,
      CarClassKind.lmgte => ClassColors.lmgte,
      CarClassKind.lmgt3 => ClassColors.lmgt3,
      CarClassKind.unknown => null,
    };
    final marker = cls.elms
        ? ClassColors.lmp2ElmsMarker
        : ClassColors.lmp2ElmsMarker.withValues(alpha: 0);
    if (fill == null) {
      final scheme = Theme.of(context).colorScheme;
      return ClassPalette(
        fill: AppColors.surfaceHighest,
        edge: AppColors.outlineVariant,
        label: scheme.onSurfaceVariant,
        marker: marker,
      );
    }
    return ClassPalette(
      fill: fill,
      edge: liftedEdge(fill),
      label: labelOn(fill),
      marker: marker,
    );
  }

  final Color fill;
  final Color edge;
  final Color label;

  /// The ELMS corner; fully transparent on every other class, so a change
  /// between the two LMP2s fades the corner rather than popping it.
  final Color marker;

  /// White, the game's label colour, where it measures [minLabelContrast] or
  /// better on [fill]; [AppColors.surfaceBase] where it does not.
  static Color labelOn(Color fill) =>
      contrastRatio(Colors.white, fill) >= minLabelContrast
      ? Colors.white
      : AppColors.surfaceBase;

  /// 3:1, WCAG's floor for large text and for marks. The chip's name is
  /// small, but it is a known word on a colour that already says the class,
  /// so the game's white wins wherever it stays this readable.
  static const minLabelContrast = 3.0;

  /// [fill] lifted 18 points of HSL lightness, for a hairline edge that reads
  /// on a near-black surface whatever the fill.
  static Color liftedEdge(Color fill) {
    final hsl = HSLColor.fromColor(fill);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
  }

  static ClassPalette lerp(ClassPalette a, ClassPalette b, double t) =>
      ClassPalette(
        fill: Color.lerp(a.fill, b.fill, t)!,
        edge: Color.lerp(a.edge, b.edge, t)!,
        label: Color.lerp(a.label, b.label, t)!,
        marker: Color.lerp(a.marker, b.marker, t)!,
      );

  @override
  bool operator ==(Object other) =>
      other is ClassPalette &&
      other.fill == fill &&
      other.edge == edge &&
      other.label == label &&
      other.marker == marker;

  @override
  int get hashCode => Object.hash(fill, edge, label, marker);
}

/// WCAG 2 contrast ratio between two opaque colours.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _PaletteTween extends Tween<ClassPalette> {
  _PaletteTween({super.end});

  @override
  ClassPalette lerp(double t) => ClassPalette.lerp(begin!, end!, t);
}

/// The block every class mark is drawn on, its colours animated between
/// classes over [AppDurations.medium] (zero under reduced motion).
class _AnimatedClassBlock extends StatelessWidget {
  const _AnimatedClassBlock({
    required this.palette,
    required this.radius,
    required this.child,
    this.markerLeg = 0.38,
  });

  final ClassPalette palette;
  final double radius;
  final Widget child;

  /// The ELMS triangle's legs, as a fraction of the block's height. The game
  /// draws a 0.25 rem two-sided border on a badge about 1.3 rem tall: a
  /// little over a third.
  final double markerLeg;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<ClassPalette>(
      tween: _PaletteTween(end: palette),
      duration: AppMotion.duration(context, AppDurations.medium),
      curve: AppCurves.standard,
      child: child,
      builder: (context, p, child) => CustomPaint(
        painter: _ClassBlockPainter(
          palette: p,
          radius: radius,
          markerLeg: markerLeg,
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: p.label),
          child: child!,
        ),
      ),
    );
  }
}

class _ClassLabel extends StatelessWidget {
  const _ClassLabel({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      softWrap: false,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: TextStyle(
        fontFamily: AppFonts.ui,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1,
        letterSpacing: fontSize * 0.06,
      ),
    );
  }
}

/// Fill, ELMS corner (clipped to the squircle, so it follows the curve) and
/// a 1 px edge inside the outline.
class _ClassBlockPainter extends CustomPainter {
  _ClassBlockPainter({
    required this.palette,
    required this.radius,
    required this.markerLeg,
  });

  final ClassPalette palette;
  final double radius;
  final double markerLeg;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = AppRadii.squircle(radius);
    final outline = shape.getOuterPath(rect);
    canvas.drawPath(outline, Paint()..color = palette.fill);

    if (palette.marker.a > 0) {
      final leg = size.height * markerLeg;
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawPath(
        Path()
          ..moveTo(rect.right - leg, rect.top)
          ..lineTo(rect.right, rect.top)
          ..lineTo(rect.right, rect.top + leg)
          ..close(),
        Paint()..color = palette.marker,
      );
      canvas.restore();
    }

    canvas.drawPath(
      shape.getInnerPath(rect.deflate(0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = palette.edge,
    );
  }

  @override
  bool shouldRepaint(_ClassBlockPainter old) =>
      old.palette != palette ||
      old.radius != radius ||
      old.markerLeg != markerLeg;
}
