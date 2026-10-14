/// The comparability strip (comparison proposal §3, §4): one chip per check
/// or difference, each opening its numbers.
library;

import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../domain/comparability.dart';

class ComparabilityStrip extends StatelessWidget {
  const ComparabilityStrip({super.key, required this.chips});

  final List<ComparabilityChip> chips;

  @override
  Widget build(BuildContext context) {
    // A Wrap: the strip is 28 px on a wide window and takes a second line on
    // a narrow one rather than clipping a chip off the edge.
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [for (final chip in chips) _Chip(chip: chip)],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final ComparabilityChip chip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Neutral throughout: only a failed delta check takes the error colour,
    // because only then is a number on screen wrong (§8 Chips).
    final (icon, color) = switch (chip.tone) {
      ChipTone.passed => (Icons.check, scheme.onSurfaceVariant),
      ChipTone.neutral => (null, scheme.onSurfaceVariant),
      ChipTone.warning => (Icons.warning_amber_outlined, scheme.onSurface),
      ChipTone.error => (Icons.error_outline, scheme.error),
    };
    return AppTooltip(
      message: chip.detail.join('\n'),
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        avatar: icon == null ? null : Icon(icon, size: 16, color: color),
        label: Text(
          chip.label,
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
        side: BorderSide(
          color: chip.tone == ChipTone.error
              ? scheme.error
              : scheme.outlineVariant,
        ),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(chip.label),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in chip.detail)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(line),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
