/// The Tyres tab (comparison proposal §3, §7 "Tyres this lap"): one corner
/// of each lap, Base's card over the Target's, on one tread scale.
///
/// No in-lap tyre traces: temperatures move only 1.3–2.6 °C within a lap,
/// so a lap's means are its honest summary, as on the Tyres & Brakes screen.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/charting/value_ramp.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../tires_brakes/presentation/corner_card.dart';
import '../application/compare_tyres.dart';
import '../domain/comparison_set.dart';

class TyresThisLap extends ConsumerStatefulWidget {
  const TyresThisLap({super.key, required this.set});

  final ComparisonSet set;

  @override
  ConsumerState<TyresThisLap> createState() => _TyresThisLapState();
}

class _TyresThisLapState extends ConsumerState<TyresThisLap> {
  var _corner = Corner.frontLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final read = ref.watch(compareTyresProvider(widget.set));
    return switch (read) {
      AsyncData(value: null) => const SizedBox.shrink(),
      AsyncData(value: final tyres?) => _cards(context, tyres, muted),
      AsyncError(:final error) => Text('Tyres not read: $error', style: muted),
      _ => Text('Reading the tyres…', style: muted),
    };
  }

  Widget _cards(BuildContext context, CompareTyres tyres, TextStyle? muted) {
    final theme = Theme.of(context);
    final ramp = ValueRamp(ChannelColors.resolve(context).tyre);
    final range = tyres.treadRange;
    Widget card(ComparisonRole role, LapTyres lap) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            '${role.label} · Lap ${lap.lap.displayNumber}',
            style: theme.textTheme.labelLarge,
          ),
        ),
        CornerCard(
          snapshot: lap.snapshot[_corner]!,
          ramp: ramp,
          rampRange: range,
          hottest: lap.report.hottestOn(lap.lap) == _corner,
          mostWorn: lap.report.mostWornOn(lap.lap) == _corner,
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<Corner>(
          segments: [
            for (final corner in Corner.values)
              ButtonSegment(
                value: corner,
                label: Text(corner.short),
                tooltip: corner.label,
              ),
          ],
          selected: {_corner},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(AppRadii.squircle(AppRadii.sm)),
          ),
          onSelectionChanged: (selection) =>
              setState(() => _corner = selection.first),
        ),
        card(ComparisonRole.base, tyres.base),
        card(ComparisonRole.target, tyres.target),
        if (range != null) ...[
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: TreadRampLegend(ramp: ramp, range: range),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'One tread scale for both laps. Lap means: temperatures move only '
          '1.3–2.6 °C within a lap, so no in-lap traces.',
          style: muted,
        ),
      ],
    );
  }
}
