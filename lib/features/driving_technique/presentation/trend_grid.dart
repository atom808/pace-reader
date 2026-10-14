/// Per-lap trends (SPEC.md §8.13.7): one small `PerLapTrendChart` per
/// measure, lap time first. Tapping a lap in any of them shows it on the
/// whole screen, as in-screen state rather than `ChartSync`.
library;

import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/fl_chart_theme/per_lap_trend_chart.dart';
import '../application/technique_providers.dart';
import '../domain/lap_technique.dart';
import 'technique_text.dart';
import 'technique_widgets.dart';

class TrendGrid extends StatelessWidget {
  const TrendGrid({
    super.key,
    required this.overview,
    required this.lap,
    required this.onSelectLap,
  });

  final TechniqueOverview overview;
  final LapTechnique lap;

  /// Called with a `Lap.index`.
  final ValueChanged<int> onSelectLap;

  @override
  Widget build(BuildContext context) {
    final ordered = overview.ordered;
    final byNumber = {
      for (final t in ordered) t.lap.displayNumber: t.lap.index,
    };
    final measures = [
      for (final m in TechniqueMeasure.values)
        if (m != TechniqueMeasure.abs || overview.session.hasAbs)
          if (ordered.any((t) => m.of(t) != null)) m,
    ];
    void tap(int number) {
      final index = byNumber[number];
      if (index != null) onSelectLap(index);
    }

    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Lap by lap',
            caption: ordered.length < 2
                ? 'One racing lap: no trend to draw'
                : '${ordered.length} racing laps · tap one to show it',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              const gap = 18.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: width,
                    child: _Trend(
                      title: 'Lap time',
                      note: 'The lap the others are read against.',
                      color: Theme.of(context).colorScheme.onSurface,
                      glyph: null,
                      points: [
                        for (final t in ordered)
                          PerLapTrendPoint(
                            lapNumber: t.lap.displayNumber,
                            value: t.lapTime,
                          ),
                      ],
                      format: formatLapTime,
                      highlightLap: lap.lap.displayNumber,
                      onLapTap: tap,
                    ),
                  ),
                  for (final m in measures)
                    SizedBox(
                      width: width,
                      child: _Trend(
                        title: '${m.label}, ${m.unit}',
                        note: sessionCorrelation(
                          overview.correlation(m),
                          ordered.length,
                        ),
                        color: measureColor(context, m),
                        glyph: MeasureGlyph(measure: m, size: 8),
                        pace: m.goesWithPace,
                        points: [
                          for (final t in ordered)
                            PerLapTrendPoint(
                              lapNumber: t.lap.displayNumber,
                              value: m.of(t),
                            ),
                        ],
                        format: (v) => '${m.format(v)} ${m.unit}',
                        highlightLap: lap.lap.displayNumber,
                        onLapTap: tap,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Trend extends StatelessWidget {
  const _Trend({
    required this.title,
    required this.note,
    required this.color,
    required this.glyph,
    required this.points,
    required this.format,
    required this.highlightLap,
    required this.onLapTap,
    this.pace = false,
  });

  final String title;
  final String? note;
  final Color color;
  final Widget? glyph;
  final bool pace;
  final List<PerLapTrendPoint> points;
  final String Function(double) format;
  final int highlightLap;
  final ValueChanged<int> onLapTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (glyph != null) ...[glyph!, const SizedBox(width: 7)],
            Flexible(
              child: Text(
                title,
                style: theme.textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (pace) ...[const SizedBox(width: 8), const PaceTag()],
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 6),
        PerLapTrendChart(
          points: points,
          color: color,
          formatValue: format,
          highlightLap: highlightLap,
          height: 132,
          onLapTap: onLapTap,
        ),
      ],
    );
  }
}

/// The trends' skeleton: bars, the shape of what is coming.
class TrendGridSkeleton extends StatelessWidget {
  const TrendGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) => SquircleCard(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 18; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Skeleton(height: 40.0 + (i * 37 % 60)),
            ),
          ),
      ],
    ),
  );
}
