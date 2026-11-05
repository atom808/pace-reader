/// The key to `SurfaceLayer`'s casings: where the lap ran over kerbs and off
/// the track (map stage P9d).
library;

import 'package:material_ui/material_ui.dart';

import '../painters/chart_painting.dart';

class SurfaceLegend extends StatelessWidget {
  const SurfaceLegend({
    super.key,
    required this.kerbColour,
    required this.offTrackColour,
    required this.kerbs,
    required this.offTrack,
  });

  final Color kerbColour;
  final Color offTrackColour;

  /// How many stretches of each the lap has; a key for none is left out.
  final int kerbs;
  final int offTrack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget key(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (kerbs > 0)
          key(
            CustomPaint(
              size: const Size(18, 6),
              painter: _KerbSwatch(kerbColour),
            ),
            kerbs == 1 ? 'Kerb' : 'Kerbs · $kerbs',
          ),
        if (offTrack > 0)
          key(
            Container(
              width: 18,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: offTrackColour,
              ),
            ),
            offTrack == 1 ? 'Off track' : 'Off track · $offTrack',
          ),
      ],
    );
  }
}

class _KerbSwatch extends CustomPainter {
  const _KerbSwatch(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawPath(
      dashedPolyline([Offset(0, y), Offset(size.width, y)], dash: 4, gap: 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_KerbSwatch old) => old.colour != colour;
}
