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
import '../../../widgets/identity/game_mark_view.dart';
import '../application/linked_results.dart';
import '../domain/bop.dart';
import '../domain/field_pace.dart';
import '../domain/field_resources.dart';
import 'bop_text.dart';
import 'results_widgets.dart';

/// Nothing when no results file links to the recording; a sentence when the
/// file has no fuel, energy or tyre figures; otherwise the table.
class FieldResourcesCard extends ConsumerWidget {
  const FieldResourcesCard({super.key, required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final field = ref.watch(sessionFieldPaceProvider(source)).value;
    final bop = ref.watch(sessionBopProvider(source)).value;
    final duration = AppMotion.duration(context, AppDurations.slow);
    final Widget child;
    if (field == null || field.pace.classSize < 2) {
      child = const SizedBox.shrink(key: ValueKey('none'));
    } else if (!hasResources(field.pace)) {
      child = const _NoFigures(key: ValueKey('no figures'));
    } else {
      child = _Table(key: const ValueKey('table'), pace: field.pace, bop: bop);
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
  const _Table({super.key, required this.pace, required this.bop});

  final FieldPace pace;

  /// Null while it loads, and without a linked file.
  final SessionBop? bop;

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
    final bop = this.bop;
    final document = bop?.document;
    final showAllowance =
        document != null && cars.any((c) => bop!.of(c.car.driver) != null);
    final megajoules = showEnergy && (bop?.inMegajoules ?? false);

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
          if (showAllowance) right(88, cells[5]),
          if (showTread) right(80, cells[6]),
          const SizedBox(width: 20),
          SizedBox(width: 140, child: cells[7]),
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
            const SizedBox(height: 6),
            const _BopLine(text: bopNote),
            if (bop != null && showEnergy) ...[
              const SizedBox(height: 4),
              _BopLine(text: bopStatus(bop), strong: megajoules),
            ],
            const SizedBox(height: 12),
            row([
              const SizedBox.shrink(),
              Text('Car', style: head),
              Text('Typical', style: head),
              AppTooltip(
                message:
                    'Share of a full tank per lap, as LMU’s results file '
                    'writes it. It is not turned into litres: in the race '
                    'measured, the file’s shares fit no single tank size, '
                    'and tanks differ between models.',
                child: Text('Fuel', style: head),
              ),
              AppTooltip(
                message: megajoules
                    ? 'Megajoules per lap: the share of the allowance a lap '
                          'took, times the model’s stint energy in BoP '
                          '${document!.version}. The file writes shares in '
                          'steps of 1/256, so each figure is good to about '
                          '±2 MJ.'
                    : 'Share of the car’s own energy allowance per lap. '
                          'Balance of performance sets that allowance per '
                          'model and track, so the same share can be a '
                          'different number of megajoules on another model.',
                child: Text('Energy', style: head),
              ),
              if (document == null)
                Text('Allowance', style: head)
              else
                AppTooltip(
                  message:
                      'Stint energy: the allowance BoP ${document.version} '
                      'gives each model at ${bop!.group}. Hover a car for '
                      'the rest of its BoP.',
                  child: Text('Allowance', style: head),
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
                  bop: bop?.of(c.car.driver),
                  document: document,
                  megajoules: megajoules,
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
    required this.bop,
    required this.document,
    required this.megajoules,
  });

  final CarResources resources;
  final int rank;
  final bool isMe;
  final Widget Function(List<Widget>) row;

  /// The car's BoP, when the document lists it.
  final BopEntry? bop;
  final BopDocument? document;

  /// Whether energy reads in MJ (the session kept BoP's allowance).
  final bool megajoules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = isMe ? scheme.primary : scheme.onSurface;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13, color: ink);
    final d = resources.car.driver;
    final stints = resources.stints;
    final bop = this.bop;
    final document = this.document;
    final energy = resources.energyPerLap;
    final Widget car = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MakeBadge(model: d.model),
            Flexible(
              child: Text(
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
            ),
          ],
        ),
        Text(
          isMe ? '${d.name} · this car' : d.name,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return row([
      Text('$rank', style: numeral.copyWith(color: scheme.onSurfaceVariant)),
      if (bop != null && document != null)
        AppTooltip(message: bopSummary(bop, document), child: car)
      else
        car,
      Text(formatLapTime(resources.car.typical!), style: numeral),
      Text(_share(resources.fuelPerLap), style: numeral),
      Text(
        megajoules && bop != null && energy != null
            ? '${(energy * bop.stintEnergyMJ.value).round()} MJ'
            : _share(energy),
        style: numeral,
      ),
      Text(
        bop == null ? '—' : bopFigure(bop.stintEnergyMJ, ' MJ'),
        style: numeral.copyWith(color: scheme.onSurfaceVariant),
      ),
      Text(_share(resources.treadPerLap, decimals: 2), style: numeral),
      Text(
        stints.length <= 1 ? '${stints.firstOrNull ?? 0}' : stints.join(' · '),
        overflow: TextOverflow.ellipsis,
        style: numeral.copyWith(color: scheme.onSurfaceVariant),
      ),
    ]);
  }
}

/// A balance-of-performance line under the description: the general caveat,
/// or what this session's BoP and allowance are ([strong] when energy reads
/// in megajoules).
class _BopLine extends StatelessWidget {
  const _BopLine({required this.text, this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final general = text == bopNote;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            general ? Icons.balance : Icons.bolt,
            size: 14,
            color: strong ? scheme.primary : muted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppDurations.medium),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ),
      ],
    );
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
