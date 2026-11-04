/// Stacked trace panels that share the height they are given (map stage P9a):
/// as in the reference apps, the panels fill the dock rather than sitting at
/// a fixed height above empty space, and scroll only once the dock is too
/// short for each to stay readable.
library;

import 'package:material_ui/material_ui.dart';

import 'map_stage/corner_grid.dart';

/// One row of a [TraceStack].
class TraceStackRow {
  /// A row of [weight] panels' worth of the height the panels share.
  const TraceStackRow.panels(this.child, {int this.weight = 1})
    : perCell = null;

  /// A [CornerGrid] holding [perCell] panels in each corner: two rows of
  /// corners side by side, four when the grid is too narrow for that.
  const TraceStackRow.corners(this.child, {required int this.perCell})
    : weight = null;

  /// A row at its own height: a chip bar, a note.
  const TraceStackRow.fixed(this.child) : weight = 0, perCell = null;

  final Widget child;

  /// Panels' worth of height; null for a grid of corners.
  final int? weight;

  /// Panels in each corner of a grid; null for any other row.
  final int? perCell;

  /// The same row around [other]: wrapped in an entrance, say.
  TraceStackRow withChild(Widget other) => switch ((weight, perCell)) {
    (_, final n?) => TraceStackRow.corners(other, perCell: n),
    (final w?, _) when w > 0 => TraceStackRow.panels(other, weight: w),
    _ => TraceStackRow.fixed(other),
  };

  /// How many panels' worth of height the row takes at [width]; 0 for a row
  /// at its own height.
  int weightAt(double width) => switch (perCell) {
    final n? => (width >= CornerGrid.twoColumnsWidth ? 2 : 4) * n,
    null => weight!,
  };
}

class TraceStack extends StatelessWidget {
  const TraceStack({
    super.key,
    required this.rows,
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 18),
    this.gap = 8,
    this.minPanel = 84,
    this.maxPanel = 260,
  });

  final List<TraceStackRow> rows;
  final EdgeInsets padding;
  final double gap;

  /// The shortest a panel gets before the stack scrolls instead: a chip and
  /// a trace still worth reading.
  final double minPanel;

  /// The tallest a panel gets: past it a trace stops reading better and a
  /// stack of two looks like a mistake.
  final double maxPanel;

  /// What a row at its own height is taken to need when deciding whether the
  /// panels fit. Only the decision uses it: the row is laid out at its real
  /// height, and the panels share what it leaves.
  static const fixedRowEstimate = 44.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth - padding.horizontal;
      final weights = [for (final r in rows) r.weightAt(width)];
      final panels = weights.fold(0, (a, b) => a + b);
      final fixed = weights.where((w) => w == 0).length;
      final chrome =
          padding.vertical +
          gap * (rows.length - 1).clamp(0, rows.length) +
          fixed * fixedRowEstimate;
      double heightFor(double share) => chrome + share * panels;

      final double height;
      if (panels == 0) {
        height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : heightFor(0);
      } else if (!constraints.hasBoundedHeight) {
        height = heightFor(_unboundedPanel);
      } else {
        final share = (constraints.maxHeight - chrome) / panels;
        height = share < minPanel
            ? heightFor(minPanel)
            : share > maxPanel
            ? heightFor(maxPanel)
            : constraints.maxHeight;
      }

      final column = Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              if (weights[i] == 0)
                rows[i].child
              else
                Expanded(flex: weights[i], child: rows[i].child),
            ],
          ],
        ),
      );
      return SingleChildScrollView(
        child: SizedBox(height: height, child: column),
      );
    },
  );
}

/// The panel share a stack uses where nothing bounds its height.
const _unboundedPanel = 120.0;
