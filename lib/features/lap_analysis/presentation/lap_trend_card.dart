/// The lap-time trend chart and its key (SPEC.md §8.3).
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/fl_chart_theme/per_lap_bar_chart.dart';
import '../../driving_technique/presentation/technique_widgets.dart'
    show GlassPopoverAnchor;
import '../../session_results/application/linked_results.dart';
import '../../session_results/domain/field_pace.dart';
import '../../session_results/presentation/field_cars_list.dart';
import '../application/lap_incidents.dart';
import '../application/lap_trend.dart';
import 'incident_marks.dart';

/// Every lap's pace against the fastest, one bar per lap.
///
/// **Delta to the fastest lap, not lap time** — see [LapTrend] for the scale
/// argument. Three things follow from that and are drawn rather than left for
/// the caption to explain:
///
/// - The fastest lap has no height. It is marked in the tertiary, the
///   colour the lap table already uses for "fastest" (best sectors), by a flat
///   cap on the baseline and a glyph under its column.
/// - A lap the game did not time keeps its slot with no bar and a hollow dot,
///   whose tooltip gives the reason. A bar at zero would say "as fast as the
///   fastest", and a grey stub would say "a little slower"; neither is true.
/// - The dashed line is the **median** lap, labelled with its delta.
///
/// The chart is a view onto the lap table below it, and points at the same lap
/// the table does: hovering a column highlights its row and hovering a row
/// highlights its column, and tapping either loads the lap into the Trace.
class LapTrendCard extends HookWidget {
  const LapTrendCard({
    super.key,
    required this.trend,
    required this.incidents,
    this.raceControl,
    this.field,
    required this.selectedLapIndex,
    required this.hoveredLapIndex,
    required this.onSelect,
    required this.onHover,
    this.onOpenInTrace,
  });

  final LapTrend trend;

  /// Null while the events are still being read, or if they could not be:
  /// the chart is complete without them and shows no marks rather than
  /// waiting.
  final SessionIncidents? incidents;

  /// Race control's calls from LMU's results file; null when no file links.
  final SessionRaceControl? raceControl;

  /// The class's pace from LMU's results file, drawn as a band behind the
  /// bars; null when no file links.
  final SessionFieldPace? field;

  /// `Lap.index` of the lap the Trace is showing, if any.
  final int? selectedLapIndex;

  /// `Lap.index` of the lap the pointer is over in the *table*.
  final int? hoveredLapIndex;

  final ValueChanged<int> onSelect;

  /// The lap under the pointer in the chart, or null when it leaves.
  final ValueChanged<int?> onHover;

  /// Jumps to the Trace view. Null hides the button (nothing to open).
  final VoidCallback? onOpenInTrace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final channels = ChannelColors.resolve(context);
    final sameModel = useState(false);

    // A trend of one lap is one bar at zero: a result-shaped picture of
    // nothing, so it is said instead.
    if (trend.timedCount < 2) {
      return _Card(
        title: 'Pace against the fastest lap',
        unit: 's',
        child: Text(
          trend.timedCount == 0
              ? 'No lap in this session was timed, so there is no pace trend '
                    'to draw.'
              : 'Only one lap was timed, so there is nothing to compare it '
                    'with yet.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      );
    }

    final laps = trend.laps;
    final selected = laps.indexWhere((t) => t.lap.index == selectedLapIndex);
    final hovered = laps.indexWhere((t) => t.lap.index == hoveredLapIndex);
    final medianDelta = trend.medianDeltaSeconds;

    final bars = <PerLapBar>[];
    final kinds = <IncidentKind>{};
    var anyExcluded = false;
    for (final t in laps) {
      final lap = t.lap;
      final marks = incidentMarks(
        scheme,
        lap,
        incidents?.of(lap) ?? LapIncidents.none(lap.index),
        raceControl: raceControl?.of(lap) ?? const [],
      );
      kinds.addAll(marks.map((m) => m.kind));
      final exclusion = t.exclusion;
      anyExcluded |= exclusion != null;

      final labels = marks.map((m) => m.label).join(', ');
      bars.add(
        PerLapBar(
          lapNumber: lap.displayNumber,
          value: t.deltaSeconds,
          highlight: t.isFastest ? scheme.tertiary : null,
          note: exclusion != null
              ? '${exclusion.label}: ${exclusion.explanation}'
              : [
                  formatLapTime(lap.lapTimeSeconds!),
                  if (t.isFastest) 'fastest lap',
                  if (labels.isNotEmpty) labels,
                ].join('\n'),
          marks: [
            for (final m in marks)
              PerLapMark(icon: m.icon, color: m.color, tooltip: m.tooltip),
            if (t.isFastest)
              PerLapMark(
                icon: Icons.bolt,
                color: scheme.tertiary,
                tooltip:
                    'Lap ${lap.displayNumber} is the fastest lap: '
                    '${formatLapTime(lap.lapTimeSeconds!)}.',
              ),
            if (exclusion != null)
              PerLapMark(
                icon: Icons.circle_outlined,
                color: muted.withValues(alpha: 0.7),
                tooltip:
                    'Lap ${lap.displayNumber} is not compared — '
                    '${exclusion.label}.\n${exclusion.explanation}',
              ),
          ],
        ),
      );
    }

    final view = _FieldView.of(field, trend, sameModel: sameModel.value);

    return _Card(
      title: 'Pace against the fastest lap',
      unit: 's',
      trailing: onOpenInTrace == null
          ? null
          : TextButton.icon(
              onPressed: onOpenInTrace,
              icon: const Icon(Icons.show_chart, size: 18),
              label: const Text('Open in Trace'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PerLapBarChart(
            height: 240,
            color: channels.delta,
            animateIn: true,
            bars: bars,
            formatValue: formatDelta,
            reference: medianDelta,
            referenceLabel: medianDelta == null
                ? null
                : 'median ${formatDelta(medianDelta)}',
            selectedIndex: selected < 0 ? null : selected,
            hoveredIndex: hovered < 0 ? null : hovered,
            onBarTap: (i) => onSelect(laps[i].lap.index),
            onBarHover: (i) => onHover(i == null ? null : laps[i].lap.index),
            band: view?.band,
          ),
          if (view != null) ...[
            const SizedBox(height: 12),
            _FieldControls(
              view: view,
              sameModel: sameModel.value,
              onSameModel: (on) => sameModel.value = on,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _Key(
                icon: Icons.bolt,
                color: scheme.tertiary,
                text: 'fastest lap',
              ),
              if (kinds.contains(IncidentKind.impact))
                _Key(
                  icon: Icons.car_crash_outlined,
                  color: scheme.error,
                  text: 'impact',
                ),
              if (kinds.contains(IncidentKind.wheelDetached))
                _Key(
                  icon: Icons.tire_repair_outlined,
                  color: scheme.error,
                  text: 'wheel detached',
                ),
              if (kinds.contains(IncidentKind.yellowFlag))
                _Key(
                  icon: Icons.flag_outlined,
                  color: flagYellow,
                  text: 'yellow flag',
                ),
              // Race control's kinds carry their severity in their colour, so
              // the key names the shape only.
              for (final kind in const [
                IncidentKind.penalty,
                IncidentKind.contact,
                IncidentKind.damage,
                IncidentKind.trackLimits,
              ])
                if (kinds.contains(kind))
                  _Key(
                    icon: incidentKindKey(kind).icon,
                    color: muted,
                    text: incidentKindKey(kind).text,
                  ),
              if (anyExcluded)
                _Key(
                  icon: Icons.circle_outlined,
                  color: muted.withValues(alpha: 0.7),
                  text: 'not compared',
                ),
              if (view?.band != null) ...[
                _Key(
                  icon: Icons.square_rounded,
                  color: muted.withValues(alpha: 0.35),
                  text: view!.bandKey,
                ),
                if (view.band!.line != null)
                  _Key(
                    icon: Icons.horizontal_rule,
                    color: muted,
                    text: view.lineKey,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Each bar is how far a lap ran behind the fastest, so the fastest '
            'sits on the baseline. Click a lap to load it into the Trace.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.unit,
    required this.child,
    this.trailing,
  });

  final String title;
  final String unit;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Never shorter than the button it may hold, so the card does not
          // change height when the button appears.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Row(
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Text(
                  unit,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// What the trend card draws of the class's pace (results proposal, R2):
/// the band and its line as deltas to the session's fastest lap, and the
/// words for its key.
class _FieldView {
  _FieldView._({
    required this.pace,
    required this.band,
    required this.sameModel,
    required this.modelAvailable,
    required this.bandKey,
    required this.lineKey,
    required this.noBand,
  });

  static _FieldView? of(
    SessionFieldPace? field,
    LapTrend trend, {
    required bool sameModel,
  }) {
    final fastest = trend.fastest?.lapTimeSeconds;
    if (field == null || fastest == null) return null;
    final pace = field.pace;
    if (pace.others().isEmpty) return null;

    final classBand = pace.band();
    final modelBand = pace.band(sameModel: true);
    final model = sameModel && modelBand != null;

    List<(double, double)?> ranges(FieldBand b) => [
      for (final t in trend.laps)
        switch (b.at(field.numberOf(t.lap))) {
          (final low, final high) => (low - fastest, high - fastest),
          null => null,
        },
    ];
    double? line(bool model) => switch (pace.fastestOther(sameModel: model)) {
      final car? => car.best! - fastest,
      null => null,
    };
    // Both bands' reach, so turning "same model" on moves the band and not
    // the bars.
    final reach = <double>[
      for (final b in [?classBand, ?modelBand])
        for (final r in ranges(b))
          if (r != null) ...[r.$1, r.$2],
      if (classBand != null) ?line(false),
      if (modelBand != null) ?line(true),
    ];

    final shown = model ? modelBand : classBand;
    final others = pace.others(sameModel: model).length;
    final carType = pace.me.driver.carType;
    final lineAt = line(model);
    return _FieldView._(
      pace: pace,
      sameModel: model,
      modelAvailable: modelBand != null,
      band: shown == null
          ? null
          : PerLapBand(
              ranges: ranges(shown),
              line: lineAt,
              lineLabel: lineAt == null
                  ? null
                  : '${model ? 'best other $carType' : 'best other car'} '
                        '${formatDelta(lineAt)}',
              reach: reach,
            ),
      bandKey: [
        model ? 'middle half of $others other $carType' : 'class middle half',
        (shown?.perLap ?? false) ? 'lap by lap' : 'of typical laps',
        if (!model) '$others other cars',
      ].join(', '),
      lineKey: model
          ? 'best lap by another $carType'
          : 'best lap by another car in class',
      noBand: classBand == null
          ? '${_cars(pace.others().length)} in class set a lap with all '
                'three sectors and no stop: too few for a band, so they are '
                'listed instead.'
          : null,
    );
  }

  static String _cars(int n) =>
      n == 1 ? 'Only 1 other car' : 'Only $n other cars';

  final FieldPace pace;
  final PerLapBand? band;
  final bool sameModel;
  final bool modelAvailable;
  final String bandKey;
  final String lineKey;

  /// Why there is no band, when there is none.
  final String? noBand;
}

/// "Same model" and the list of the fastest cars, under the chart.
class _FieldControls extends StatelessWidget {
  const _FieldControls({
    required this.view,
    required this.sameModel,
    required this.onSameModel,
  });

  final _FieldView view;
  final bool sameModel;
  final ValueChanged<bool> onSameModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final pace = view.pace;
    final carType = pace.me.driver.carType;
    final modelOthers = pace.others(sameModel: true).length;

    final chip = FilterChip(
      label: Text('Same model: $carType'),
      selected: view.sameModel,
      showCheckmark: false,
      avatar: Icon(
        view.sameModel ? Icons.filter_alt : Icons.filter_alt_outlined,
        size: 16,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: view.modelAvailable ? onSameModel : null,
    );

    final List<FieldCar> listed;
    final String listLabel;
    if (view.noBand != null) {
      listed = pace.classCars;
      listLabel = 'Every car in class';
    } else if (view.sameModel) {
      listed = [
        for (final c in pace.classCars)
          if (c.driver.carType == carType) c,
      ];
      listLabel = 'Every $carType';
    } else {
      listed = pace.classCars.take(5).toList();
      listLabel = 'Top 5 in class';
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (view.noBand == null)
          view.modelAvailable
              ? AppTooltip(message: bopNote, child: chip)
              : AppTooltip(
                  message: modelOthers == 0
                      ? 'No other $carType in this class set a lap.'
                      : 'Only $modelOthers other $carType set a lap: too few '
                            'for a band of their own. They are in the list.',
                  child: chip,
                ),
        GlassPopoverAnchor(
          width: 520,
          alignRight: false,
          trigger: (context, toggle) => TextButton.icon(
            onPressed: toggle,
            icon: const Icon(Icons.format_list_numbered, size: 18),
            label: Text(listLabel),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          popover: (context, close) => FieldCarsList(pace: pace, cars: listed),
        ),
        if (view.noBand case final why?)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              why,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}
