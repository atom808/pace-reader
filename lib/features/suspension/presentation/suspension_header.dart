/// The header (suspension proposal §4.1): the one glass surface, holding
/// the car's and the circuit's marks, the selected lap, and the lap strip
/// with a dot on every lap that struck.
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/car_label.dart';
import '../../../widgets/identity/game_mark_view.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../application/suspension_providers.dart';
import '../domain/strikes.dart';
import 'suspension_glyphs.dart';

class SuspensionHeader extends StatelessWidget {
  const SuspensionHeader({
    super.key,
    required this.overview,
    required this.lap,
    required this.onSelectLap,
  });

  final SuspensionOverview overview;
  final Lap lap;
  final ValueChanged<int> onSelectLap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final metadata = overview.session.metadata;
    final strikes = overview.strikesOn(lap.index);
    final struck = strikes
        .where(
          (s) =>
              s.tier == StrikeTier.strike &&
              s.surface != StrikeSurface.offTrack,
        )
        .length;
    final steps = overview.balanceSteps;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 20,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircuitLogo(
                    trackName: metadata.trackName,
                    trackLayout: metadata.trackLayout,
                    height: 36,
                    maxWidth: 96,
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: CarLabel.of(
                      metadata.carName,
                      metadata.carClass,
                      size: CarLabelSize.row,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  FadeOnChange(
                    value: lap.index,
                    duration: AppMotion.duration(context, AppDurations.fast),
                    child: Text(
                      'Lap ${lap.displayNumber}',
                      style: AppTextStyles.numeral.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (lap.lapTimeSeconds case final t?)
                    RollingNumber(
                      value: t,
                      format: formatLapTime,
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(width: 12),
                  FadeOnChange(
                    value: struck,
                    duration: AppMotion.duration(context, AppDurations.fast),
                    child: Text(
                      struck == 0
                          ? 'no strikes'
                          : '$struck strike${struck == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LapStrip(
            overview: overview,
            selected: lap.index,
            balanceSteps: steps.toSet(),
            onSelect: onSelectLap,
          ),
        ],
      ),
    );
  }
}

class _LapStrip extends HookWidget {
  const _LapStrip({
    required this.overview,
    required this.selected,
    required this.balanceSteps,
    required this.onSelect,
  });

  final SuspensionOverview overview;
  final int selected;
  final Set<int> balanceSteps;
  final ValueChanged<int> onSelect;

  static const chipWidth = 34.0;
  static const gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final laps = overview.racing;
    final controller = useScrollController();
    final position = laps.indexWhere((l) => l.index == selected);
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.hasClients || position < 0) return;
        final viewport = controller.position.viewportDimension;
        final left = position * (chipWidth + gap);
        final current = controller.offset;
        double? target;
        if (left < current + chipWidth) {
          target = left - chipWidth * 2;
        } else if (left + chipWidth > current + viewport - chipWidth) {
          target = left + chipWidth * 3 - viewport;
        }
        if (target == null) return;
        final clamped = target.clamp(0.0, controller.position.maxScrollExtent);
        final duration = AppMotion.duration(context, AppDurations.medium);
        if (duration == Duration.zero) {
          controller.jumpTo(clamped);
        } else {
          controller.animateTo(
            clamped,
            duration: duration,
            curve: AppCurves.entrance,
          );
        }
      });
      return null;
    }, [position]);

    // Each lap's strike count on track and kerb: the bar's height.
    final counts = <int, int>{};
    final closes = <int>{};
    for (final s in overview.strikes) {
      if (s.surface == StrikeSurface.offTrack) continue;
      if (s.tier == StrikeTier.strike) {
        counts[s.lap] = (counts[s.lap] ?? 0) + 1;
      } else {
        closes.add(s.lap);
      }
    }
    final most = counts.values.fold(1, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 58,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: laps.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (context, i) {
          final lap = laps[i];
          final n = counts[lap.index] ?? 0;
          return _LapChip(
            lap: lap,
            strikes: n,
            close: closes.contains(lap.index),
            balanceStep: balanceSteps.contains(lap.index),
            share: n / most,
            selected: lap.index == selected,
            onTap: () => onSelect(lap.index),
          );
        },
      ),
    );
  }
}

class _LapChip extends StatelessWidget {
  const _LapChip({
    required this.lap,
    required this.strikes,
    required this.close,
    required this.balanceStep,
    required this.share,
    required this.selected,
    required this.onTap,
  });

  final Lap lap;
  final int strikes;
  final bool close;
  final bool balanceStep;

  /// This lap's strikes as a share of the most on any lap.
  final double share;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = AppMotion.duration(context, AppDurations.fast);
    final ink = selected ? scheme.primary : scheme.onSurface;
    final time = lap.lapTimeSeconds;
    final tip = [
      'Lap ${lap.displayNumber}${time == null ? '' : ' · ${formatLapTime(time)}'}',
      strikes == 0
          ? close
                ? 'came close, no strike'
                : 'no strikes'
          : '$strikes strike${strikes == 1 ? '' : 's'}',
      if (balanceStep) 'roll balance stepped here: a bar change?',
    ].join(' · ');
    return AppTooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 400),
      child: Hoverable(
        radius: AppRadii.sm,
        onTap: onTap,
        semanticLabel: 'Lap ${lap.displayNumber}',
        child: AnimatedContainer(
          duration: motion,
          curve: AppCurves.standard,
          width: _LapStrip.chipWidth,
          decoration: ShapeDecoration(
            shape: GradientSquircleBorder(
              radius: AppRadii.sm,
              gradient: selected
                  ? AppGradients.hairlineStrong
                  : const LinearGradient(
                      colors: [Color(0x00000000), Color(0x00000000)],
                    ),
            ),
            color: selected
                ? AppColors.surfaceHighest
                : scheme.onSurface.withValues(alpha: 0.03),
          ),
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
          child: Column(
            children: [
              // Strikes as a stack of dots up to three, then a bar: a lap
              // with one strike reads differently from a lap with eight.
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (balanceStep)
                      Positioned(
                        top: 0,
                        child: Icon(
                          Icons.swap_vert,
                          size: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (strikes > 0)
                      AnimatedFractionallySizedBox(
                        duration: motion,
                        heightFactor: 0.25 + 0.6 * share,
                        widthFactor: 0.42,
                        child: AnimatedContainer(
                          duration: motion,
                          decoration: ShapeDecoration(
                            shape: AppRadii.squircle(4),
                            color: ink.withValues(alpha: selected ? 1 : 0.7),
                          ),
                        ),
                      )
                    else if (close)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: ShapeDecoration(
                          shape: CircleBorder(
                            side: BorderSide(
                              color: ink.withValues(alpha: 0.45),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${lap.displayNumber}',
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 11,
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's title: the coilover glyph and the word.
class SuspensionTitle extends StatelessWidget {
  const SuspensionTitle({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SuspensionGlyph(
        SuspensionGlyphKind.coilover,
        size: 22,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 10),
      const Text('Suspension'),
    ],
  );
}
