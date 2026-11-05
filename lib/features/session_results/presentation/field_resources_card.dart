/// "In class" on Fuel & Energy (results proposal, R6): what the class's
/// fastest cars used per lap, beside this car, from LMU's results file.
///
/// It says what each car used and nothing about what this one should do
/// (SPEC §3): no target, no "save more".
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/linked_results.dart';
import '../domain/field_pace.dart';
import '../domain/field_resources.dart';
import 'results_widgets.dart';

/// Nothing when no results file links to the recording; a sentence when the
/// file has no fuel, energy or tyre figures; otherwise the table.
class FieldResourcesCard extends ConsumerWidget {
  const FieldResourcesCard({super.key, required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final field = ref.watch(sessionFieldPaceProvider(source)).value;
    final duration = AppMotion.duration(context, AppDurations.slow);
    final Widget child;
    if (field == null || field.pace.classSize < 2) {
      child = const SizedBox.shrink(key: ValueKey('none'));
    } else if (!hasResources(field.pace)) {
      child = const _NoFigures(key: ValueKey('no figures'));
    } else {
      child = _Table(key: const ValueKey('table'), pace: field.pace);
    }
    return AnimatedSize(
      duration: duration,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppCurves.entrance,
        child: child,
      ),
    );
  }
}

String _share(double? f, {int decimals = 1}) =>
    f == null ? '—' : '${(f * 100).toStringAsFixed(decimals)} %';

class _Table extends StatelessWidget {
  const _Table({super.key, required this.pace});

  final FieldPace pace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final head = theme.textTheme.labelSmall?.copyWith(color: muted);

    final top = pace.classCars.take(5).toList();
    final cars = [
      for (final c in top) CarResources.of(c),
      if (!top.contains(pace.me) && pace.me.typical != null)
        CarResources.of(pace.me),
    ];
    final showEnergy = cars.any((c) => c.energyPerLap != null);
    final showTread = cars.any((c) => c.treadPerLap != null);

    Widget right(double width, Widget child) => SizedBox(
      width: width,
      child: Align(alignment: Alignment.centerRight, child: child),
    );
    Widget row(List<Widget> cells) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 28, child: cells[0]),
          Expanded(child: cells[1]),
          right(84, cells[2]),
          right(80, cells[3]),
          if (showEnergy) right(80, cells[4]),
          if (showTread) right(80, cells[5]),
          const SizedBox(width: 20),
          SizedBox(width: 140, child: cells[6]),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SquircleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(resultsIcon, size: 20, color: scheme.secondary),
                const SizedBox(width: 10),
                Text('In class', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'What the class’s five fastest cars by typical lap used per '
              'lap, beside this car: the median of their laps with all three '
              'sectors and no stop, as a share of a full tank, of the energy '
              'allowance and of new tread. From LMU’s results file.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: 12),
            row([
              const SizedBox.shrink(),
              Text('Car', style: head),
              Text('Typical', style: head),
              AppTooltip(
                message:
                    'Share of a full tank per lap, as LMU’s results file '
                    'writes it. It is not turned into litres: in the race '
                    'measured, the file’s shares fit no single tank size.',
                child: Text('Fuel', style: head),
              ),
              AppTooltip(
                message: 'Share of the energy allowance per lap',
                child: Text('Energy', style: head),
              ),
              AppTooltip(
                message:
                    'Share of new tread per lap, the four tyres averaged. '
                    'LMU writes tread in steps of 0.4 %, so this is a '
                    'median of many coarse readings.',
                child: Text('Tread', style: head),
              ),
              AppTooltip(
                message: 'Laps in each stint, a stop closing one',
                child: Text('Stints', style: head),
              ),
            ]),
            const Divider(height: 1),
            for (final (i, c) in cars.indexed) ...[
              if (i == top.length) const Divider(height: 9),
              StaggeredEntrance(
                index: i,
                child: _CarLine(
                  resources: c,
                  rank:
                      1 +
                      pace.classCars
                          .where((o) => o.typical! < c.car.typical!)
                          .length,
                  isMe: c.car == pace.me,
                  row: row,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarLine extends StatelessWidget {
  const _CarLine({
    required this.resources,
    required this.rank,
    required this.isMe,
    required this.row,
  });

  final CarResources resources;
  final int rank;
  final bool isMe;
  final Widget Function(List<Widget>) row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = isMe ? scheme.primary : scheme.onSurface;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13, color: ink);
    final d = resources.car.driver;
    final stints = resources.stints;
    return row([
      Text('$rank', style: numeral.copyWith(color: scheme.onSurfaceVariant)),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              if (d.carNumber.isNotEmpty) '#${d.carNumber}',
              d.carType,
            ].join(' '),
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ink,
              fontWeight: isMe ? FontWeight.w600 : null,
            ),
          ),
          Text(
            isMe ? '${d.name} · this car' : d.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      Text(formatLapTime(resources.car.typical!), style: numeral),
      Text(_share(resources.fuelPerLap), style: numeral),
      Text(_share(resources.energyPerLap), style: numeral),
      Text(_share(resources.treadPerLap, decimals: 2), style: numeral),
      Text(
        stints.length <= 1 ? '${stints.firstOrNull ?? 0}' : stints.join(' · '),
        overflow: TextOverflow.ellipsis,
        style: numeral.copyWith(color: scheme.onSurfaceVariant),
      ),
    ]);
  }
}

class _NoFigures extends StatelessWidget {
  const _NoFigures({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SquircleCard(
        child: Row(
          children: [
            Icon(resultsIcon, size: 20, color: muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'LMU’s results file for this session has no fuel, energy or '
                'tyre figures for the class: some servers leave them out for '
                'every car.',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
