/// The key under a map coloured by one quantity: its label, and the ramp
/// from its lowest to its highest value on the lap.
library;

import 'package:material_ui/material_ui.dart';

import '../design_system/design_system.dart';
import 'track_path.dart';
import 'value_ramp.dart';

/// The magnitude legend.
///
/// Present because colour is carrying a quantity here, and a sequential
/// encoding without a scale is a picture rather than a reading — the reader
/// can see that one part of the lap is brighter, and not what that is worth.
class RampLegend extends StatelessWidget {
  const RampLegend({
    super.key,
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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
