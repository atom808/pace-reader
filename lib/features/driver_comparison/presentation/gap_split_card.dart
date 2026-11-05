/// "Where the gap goes" (GO reference proposal P3): the lap's delta in four
/// rows, by what the Target is doing — full throttle with and without
/// deployment, braking, mid-corner — each a bar in its phase's colour. A
/// click lights the phase's stretches on the map.
///
/// It says where, never why or what to do: "Target braking +0.92 s", not
/// "brake later".
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/compare_gap.dart';
import '../domain/comparison_set.dart';
import '../domain/gap_split.dart';
import '../domain/segment_losses.dart';

/// [phase]'s colour: the pedal it is, the battery's for deployment, and the
/// neutral line for mid-corner, as the map's pedal colouring draws them.
Color gapPhaseColour(BuildContext context, GapPhase phase) {
  final channels = ChannelColors.resolve(context);
  return switch (phase) {
    GapPhase.deploying => channels.charge,
    GapPhase.fullThrottle => channels.throttle,
    GapPhase.braking => channels.brake,
    GapPhase.midCorner => Theme.of(context).colorScheme.outline,
  };
}

/// "+0.78 s", "−0.12 s", or "≈0 s" inside the segments' noise floor.
String gapText(double seconds) =>
    seconds.abs() < segmentNoiseFloor ? '≈0 s' : '${formatDelta(seconds)} s';

class GapSplitCard extends ConsumerWidget {
  const GapSplitCard({super.key, required this.set});

  final ComparisonSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(comparisonGapSplitProvider(set)).value;
    // Nothing until it is measured, and nothing where it cannot be: the Why
    // card below says what there is.
    if (split == null || split.phases.isEmpty) return const SizedBox.shrink();
    final lit = ref.watch(gapPhaseFocusProvider).forSet(set);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final widest = split.seconds.values.fold(
      0.0,
      (a, b) => a > b.abs() ? a : b.abs(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Where the gap goes',
                style: theme.textTheme.titleSmall,
              ),
            ),
            Text(gapText(split.total), style: AppTextStyles.numeral),
          ],
        ),
        const SizedBox(height: 6),
        for (final phase in split.phases)
          _PhaseRow(
            key: ValueKey('gap-${phase.name}'),
            label: phase.label(hybrid: split.hybrid),
            seconds: split.seconds[phase]!,
            share: widest == 0 ? 0 : split.seconds[phase]!.abs() / widest,
            colour: gapPhaseColour(context, phase),
            lit: lit == phase,
            onTap: () =>
                ref.read(gapPhaseFocusProvider.notifier).toggle(set, phase),
          ),
        const SizedBox(height: 6),
        Text(
          'Base against the Target, sorted by what the Target is doing every '
          '${gapSplitStep.toStringAsFixed(0)} m. Choose a row to light it on '
          'the map.',
          style: muted,
        ),
      ],
    );
  }
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    super.key,
    required this.label,
    required this.seconds,
    required this.share,
    required this.colour,
    required this.lit,
    required this.onTap,
  });

  final String label;
  final double seconds;

  /// The bar's length against the widest row's, 0–1.
  final double share;
  final Color colour;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gained = seconds < 0;
    final motion = AppMotion.duration(context, AppDurations.slow);
    return Semantics(
      button: true,
      selected: lit,
      label: '$label: ${gapText(seconds)}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: AppRadii.squircle(AppRadii.sm),
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppDurations.fast),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: ShapeDecoration(
              shape: AppRadii.squircle(AppRadii.sm),
              color: lit ? colour.withValues(alpha: 0.14) : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      gapText(seconds),
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 12,
                        color: gained ? theme.colorScheme.tertiary : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Grows from the left on arrival; a gain is the same bar,
                // hollowed, so loss and gain never need a second axis.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share),
                  duration: motion,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: gained ? null : colour,
                        border: gained
                            ? Border.all(color: colour, width: 1.5)
                            : null,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
