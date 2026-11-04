/// The key to [PedalColouring]'s line: what each colour means, and that
/// depth is how far the pedal went (map stage proposal §3.3).
library;

import 'package:material_ui/material_ui.dart';

import 'line_colouring.dart';

class PedalLegend extends StatelessWidget {
  const PedalLegend({super.key, required this.colours});

  final PedalColours colours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget swatch(Color colour, String label, {bool deep = true}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: deep
                ? LinearGradient(
                    colors: [
                      colour.withValues(alpha: PedalColouring.depth(0.1)),
                      colour,
                    ],
                  )
                : null,
            color: deep ? null : colour,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        swatch(colours.brake, 'Brake'),
        swatch(colours.throttle, 'Throttle'),
        swatch(colours.coast, 'Coast', deep: false),
        Text('Deeper = more pedal', style: style),
      ],
    );
  }
}
