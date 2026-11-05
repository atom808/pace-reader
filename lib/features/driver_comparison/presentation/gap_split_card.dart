/// "Where the gap goes" (GO reference proposal P3): the lap's delta in four
/// rows, by what the Target is doing — full throttle with and without
/// deployment, braking, mid-corner — each a bar in its phase's colour. A
/// click lights the phase's stretches on the map.
///
/// It says where, never why or what to do: "Target braking +0.92 s", not
/// "brake later". Under full throttle, one line splits the straights' loss
/// into what was carried from the corner before and what was made on the
/// straight (P8): "carried", never "work on your exits".
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

/// What the map lights [phase]'s stretches in; the accent for the carried
/// straights ([phase] null), which run over the throttle colouring.
Color gapLitColour(BuildContext context, GapPhase? phase) => phase == null
    ? Theme.of(context).colorScheme.primary
    : gapPhaseColour(context, phase);

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
    final lighting = ref.watch(gapPhaseFocusProvider);
    final lit = lighting.forSet(set);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final widest = split.seconds.values.fold(
      0.0,
      (a, b) => a > b.abs() ? a : b.abs(),
    );
    final straights = split.straights;
    final stated = straights != null && straights.stated;
    // The straights' line sits under the last full-throttle row it splits.
    final lastFull = split.phases.lastWhere(
      (p) => p.isFullThrottle,
      orElse: () => GapPhase.midCorner,
    );
    final focus = ref.read(gapPhaseFocusProvider.notifier);
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
        for (final phase in split.phases) ...[
          _PhaseRow(
            key: ValueKey('gap-${phase.name}'),
            label: phase.label(hybrid: split.hybrid),
            seconds: split.seconds[phase]!,
            share: widest == 0 ? 0 : split.seconds[phase]!.abs() / widest,
            colour: gapPhaseColour(context, phase),
            lit: lit == phase,
            onTap: () => focus.toggle(set, phase),
          ),
          if (stated && phase == lastFull)
            _StraightsLine(
              key: const ValueKey('gap-straights'),
              straights: straights,
              colour: gapLitColour(context, null),
              lit: lighting.carriedFor(set),
              onTap: () => focus.toggleCarried(set),
            ),
        ],
        const SizedBox(height: 6),
        Text(
          'Base against the Target, sorted by what the Target is doing every '
          '${gapSplitStep.toStringAsFixed(0)} m. Choose a row to light it on '
          'the map.'
          '${stated ? ' On a straight of ${gapStraightMin.toStringAsFixed(0)} m '
                    "or more, a loss is carried when Base's speed gap to the "
                    'Target closes along it, and made there when it grows.' : ''}',
          style: muted,
        ),
      ],
    );
  }
}

/// Under the full-throttle rows: how much of the straights' loss was carried
/// from the corner before, and how much made on the straight (P8). A click
/// lights the carried straights with their corner exits.
class _StraightsLine extends StatelessWidget {
  const _StraightsLine({
    super.key,
    required this.straights,
    required this.colour,
    required this.lit,
    required this.onTap,
  });

  final GapStraights straights;
  final Color colour;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final number = AppTextStyles.numeral.copyWith(
      fontSize: 12,
      color: theme.colorScheme.onSurface,
    );
    final carried = gapText(straights.carried);
    final made = gapText(straights.made);
    // Arrives after the bars have started to grow, so it reads as their
    // footnote rather than a fifth row.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.duration(context, AppDurations.slow),
      curve: const Interval(0.4, 1, curve: Curves.easeOut),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Semantics(
        button: true,
        selected: lit,
        label:
            'On the straights: $carried carried from the corner before, '
            '$made made on the straight',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: AppRadii.squircle(AppRadii.sm),
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppDurations.fast),
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 5),
              decoration: ShapeDecoration(
                shape: AppRadii.squircle(AppRadii.sm),
                color: lit
                    ? colour.withValues(alpha: 0.14)
                    : Colors.transparent,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: colour,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: muted,
                        children: [
                          const TextSpan(text: 'On the straights: '),
                          TextSpan(text: carried, style: number),
                          const TextSpan(
                            text: ' carried from the corner before, ',
                          ),
                          TextSpan(text: made, style: number),
                          const TextSpan(text: ' made on the straight'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
