import 'package:material_ui/material_ui.dart';

import 'color_tokens.dart';
import 'squircle_card.dart';
import 'typography_tokens.dart';

/// One headline number with its label and a caption (SPEC.md §9.7.6) — the
/// Session Overview's stat row, and every other screen that leads with a few
/// figures rather than a chart.
///
/// A number that is the whole message is a tile, not a one-bar chart: the
/// figure *is* the visualisation, and drawing a bar for it only adds an axis
/// to read it off.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: SquircleCard(
        // At most one tile per screen is the number a driver came for — the
        // best lap on the Overview — and it gets the lit edge as well as the
        // brand-coloured numeral: the same "this one is the subject"
        // treatment the selected nav slot and a focused field get.
        border: emphasised ? AppGradients.hairlineStrong : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              value,
              // Tabular figures so these hold their width as values change
              // (§9.7.7) — the reason JetBrains Mono is bundled at all.
              style: AppTextStyles.numeral.copyWith(
                fontSize: 26,
                color: emphasised ? theme.colorScheme.primary : null,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(caption!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
