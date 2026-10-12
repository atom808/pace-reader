/// Base's and the Target's sectors (comparison proposal §2, §5 "Sectors
/// mode").
///
/// From the game's own splits, which are exact: S1 as written,
/// S2 = Last Sector2 − Last Sector1, S3 = Lap Time − Last Sector2. A split
/// the game wrote as 0.0 shows "—", never 0 (§8.3.1).
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';

class SectorTable extends StatelessWidget {
  const SectorTable({super.key, required this.base, required this.target});

  final Lap base;
  final Lap target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = [...base.sectors.all, base.lapTimeSeconds];
    final t = [...target.sectors.all, target.lapTimeSeconds];
    final header = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 12);

    // The faster of each column in iris (tertiary): "fastest", as in every
    // lap table of the app (§8).
    TextStyle cell(double? mine, double? theirs) =>
        mine != null && theirs != null && mine < theirs
        ? numeral.copyWith(color: scheme.tertiary)
        : numeral;

    // Each number sized to itself and kept apart from its neighbour: the
    // pane is 360 px, and "28.237" against "1:04.497" in equal flex columns
    // ran together.
    Widget number(String text, TextStyle? style) => Padding(
      padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
      child: Text(text, style: style, textAlign: TextAlign.right),
    );

    TableRow row(String label, List<double?> mine, List<double?> theirs) =>
        TableRow(
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            for (var i = 0; i < 4; i++)
              number(
                i == 3
                    ? formatOptionalLapTime(mine[i])
                    : formatOptionalSectorTime(mine[i]),
                cell(mine[i], theirs[i]),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Sectors', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(),
            1: IntrinsicColumnWidth(),
            2: IntrinsicColumnWidth(),
            3: IntrinsicColumnWidth(),
            4: IntrinsicColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                const SizedBox.shrink(),
                for (final label in const ['S1', 'S2', 'S3', 'Lap'])
                  number(label, header),
              ],
            ),
            row('Base', b, t),
            row('Target', t, b),
            TableRow(
              children: [
                Text('Base − Target', style: header),
                for (var i = 0; i < 4; i++)
                  number(
                    b[i] == null || t[i] == null
                        ? '—'
                        : formatDelta(b[i]! - t[i]!),
                    numeral.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
