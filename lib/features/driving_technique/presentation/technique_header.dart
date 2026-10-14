/// The header (SPEC.md §8.13.7): the one glass surface on the screen, since
/// it is static chrome. It holds the selected lap, its conditions, the lens
/// selector, and the lap strip.
///
/// The strip doubles as a lap-time chart: each racing lap is a chip whose bar
/// is as tall as the lap was quick, so the session's shape — a slow opening
/// stint, a fast middle, the pit stop's gap — is visible before a lap is
/// chosen.
library;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/class_chip.dart';
import '../../../widgets/identity/compound_badge.dart';
import '../../driver_comparison/domain/lap_conditions.dart';
import '../application/technique_providers.dart';
import '../domain/conditions_lens.dart';
import '../domain/lap_technique.dart';
import 'technique_widgets.dart';

class TechniqueHeader extends ConsumerWidget {
  const TechniqueHeader({
    super.key,
    required this.source,
    required this.overview,
    required this.lap,
    required this.onSelectLap,
  });

  final TelemetrySource source;
  final TechniqueOverview overview;
  final LapTechnique lap;
  final ValueChanged<int> onSelectLap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final fastest = overview.fastest;
    final gap = fastest == null ? null : lap.lapTime - fastest.lapTime;
    final lens = ref.watch(techniqueLensProvider(source));
    final conditions = lens.value?.conditions[lap.lap.index];
    final metadata = overview.session.metadata;

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
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  FadeOnChange(
                    value: lap.lap.index,
                    duration: AppMotion.duration(context, AppDurations.fast),
                    child: Text(
                      'Lap ${lap.lap.displayNumber}',
                      style: AppTextStyles.numeral.copyWith(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RollingNumber(
                    value: lap.lapTime,
                    format: formatLapTime,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    gap == null
                        ? ''
                        : gap.abs() < 0.0005
                        ? 'fastest racing lap'
                        : '+${gap.toStringAsFixed(3)} s to the fastest',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              _LensSelector(source: source),
            ],
          ),
          const SizedBox(height: 8),
          // Fades once, when the conditions arrive. Stepping laps fades only
          // the chips whose value changed, and rolls the compound badge.
          FadeOnChange(
            value: conditions == null,
            duration: AppMotion.duration(context, AppDurations.medium),
            child: _ConditionChips(
              conditions: conditions,
              carClass: metadata.carClass,
              steerLock: overview.session.steerLock,
            ),
          ),
          const SizedBox(height: 10),
          LapStrip(
            overview: overview,
            selected: lap.lap.index,
            onSelect: onSelectLap,
          ),
        ],
      ),
    );
  }
}

/// The selected lap's conditions, as quiet chips. Track temperature lives
/// here rather than in the lens: within a race it moves with lap number at
/// |r| ≥ 0.87 in 19 of 20 races, so it cannot be separated from fuel and
/// tyres (§8.13.6).
class _ConditionChips extends StatelessWidget {
  const _ConditionChips({
    required this.conditions,
    required this.carClass,
    required this.steerLock,
  });

  final LapConditions? conditions;
  final String carClass;
  final ({double wheel, double? frontWheels})? steerLock;

  @override
  Widget build(BuildContext context) {
    final c = conditions;
    final lock = steerLock;
    final theme = Theme.of(context);
    final fade = AppMotion.duration(context, AppDurations.medium);

    Widget chip({required String tip, required Widget child}) => AppTooltip(
      message: tip,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(10),
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          child: DefaultTextStyle.merge(
            style: AppTextStyles.numeral.copyWith(
              fontSize: 11.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            child: child,
          ),
        ),
      ),
    );

    // A text chip cross-fades only when its own words change. Each is keyed
    // by what it measures, so one that comes and goes between laps leaves
    // the others where they are.
    Widget text(String id, String label, String tip) => KeyedSubtree(
      key: ValueKey(id),
      child: FadeOnChange(
        value: label,
        duration: fade,
        child: chip(tip: tip, child: Text(label)),
      ),
    );

    final compounds = c?.compoundMarks;
    // Left-aligned: the fade's switcher would centre a Wrap narrower than
    // the header.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ClassChip.raw(carClass),
          if (lock != null)
            text(
              'lock',
              '${lock.wheel.toStringAsFixed(0)}° lock',
              'Steering lock from the setup. Steering shares are compared '
                  'within a car only: the library spans 240–584°.',
            ),
          if (c != null) ...[
            if (c.trackTemperature case final t?)
              text(
                'track',
                'track ${t.toStringAsFixed(1)} °C',
                'Track temperature over the lap. Within a race it moves with '
                    'lap number, so it is shown, not compared.',
              ),
            if (c.ambientTemperature case final t?)
              text(
                'air',
                'air ${t.toStringAsFixed(1)} °C',
                'Air temperature over the lap.',
              ),
            if (c.wetness case final w?)
              text(
                'wetness',
                w.max == 0
                    ? 'dry'
                    : w.min == w.max
                    ? 'wet ${_trim(w.max)} %'
                    : 'wet ${_trim(w.min)}–${_trim(w.max)} %',
                'Minimum Path Wetness over the lap: the grip proxy the file '
                    'has.',
              ),
            // Not faded with the rest: the badge rolls to the new compound
            // when a lap crosses a tyre change.
            if (compounds != null)
              KeyedSubtree(
                key: const ValueKey('compound'),
                child: chip(
                  tip: _compoundTip(compounds),
                  child: CompoundBadges(
                    marks: compounds,
                    showName: true,
                    tooltip: false,
                  ),
                ),
              ),
            if (c.settings['TCLevel'] case final v?)
              text(
                'tc',
                'TC ${_trim(v)}'
                    '${c.settings['TCCut'] == null ? '' : ' · cut ${_trim(c.settings['TCCut']!)}'}'
                    '${c.settings['TCSlipAngle'] == null ? '' : ' · slip ${_trim(c.settings['TCSlipAngle']!)}'}',
                'Traction control level, power cut and slip angle in force at '
                    'the lap\'s start, read per lap: drivers change them '
                    'mid-session.',
              ),
          ],
        ],
      ),
    );
  }

  /// The compound chip's tooltip: the badge's own, or a mixed set's dots and
  /// each group's compound.
  static String _compoundTip(List<CompoundMark> marks) =>
      'Tyre compound at the lap\'s start.\n${compoundsTooltip(marks)}';

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// The racing laps as chips, each with a bar as tall as the lap was quick.
class LapStrip extends HookWidget {
  const LapStrip({
    super.key,
    required this.overview,
    required this.selected,
    required this.onSelect,
  });

  final TechniqueOverview overview;
  final int selected;
  final ValueChanged<int> onSelect;

  static const chipWidth = 34.0;
  static const gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final laps = overview.ordered;
    final controller = useScrollController();
    final position = laps.indexWhere((t) => t.lap.index == selected);

    // Keep the selected chip in view as ←/→ walk past the edge.
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

    final times = [for (final t in laps) t.lapTime];
    final fastest = times.isEmpty ? 0.0 : times.reduce((a, b) => a < b ? a : b);
    // The bar scale stops at 107 % of the fastest: a lap slower than that is
    // a short stub rather than flattening every other bar.
    final slowest = times.isEmpty
        ? 1.0
        : times.reduce((a, b) => a > b ? a : b).clamp(fastest, fastest * 1.07);
    double height(double t) {
      if (slowest <= fastest) return 1;
      return (1 - ((t - fastest) / (slowest - fastest)).clamp(0.0, 1.0)) * 0.8 +
          0.2;
    }

    return SizedBox(
      height: 58,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: laps.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (context, i) {
          final t = laps[i];
          return _LapChip(
            lap: t,
            selected: t.lap.index == selected,
            fastest: t.lapTime == fastest,
            barHeight: height(t.lapTime),
            onTap: () => onSelect(t.lap.index),
          );
        },
      ),
    );
  }
}

class _LapChip extends StatelessWidget {
  const _LapChip({
    required this.lap,
    required this.selected,
    required this.fastest,
    required this.barHeight,
    required this.onTap,
  });

  final LapTechnique lap;
  final bool selected;
  final bool fastest;

  /// 0.2–1 of the bar's room.
  final double barHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = AppMotion.duration(context, AppDurations.fast);
    final slides = lap.countersteer.length;
    final barColor = selected
        ? scheme.primary
        : fastest
        ? scheme.tertiary.withValues(alpha: 0.85)
        : scheme.onSurface.withValues(alpha: 0.32);
    return AppTooltip(
      message:
          'Lap ${lap.lap.displayNumber} · ${formatLapTime(lap.lapTime)}'
          '${fastest ? ' · fastest' : ''}'
          '${slides == 0 ? '' : ' · $slides caught slide${slides == 1 ? '' : 's'}'}',
      waitDuration: const Duration(milliseconds: 400),
      child: Hoverable(
        radius: AppRadii.sm,
        onTap: onTap,
        semanticLabel: 'Lap ${lap.lap.displayNumber}',
        child: AnimatedContainer(
          duration: motion,
          curve: AppCurves.standard,
          width: LapStrip.chipWidth,
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedFractionallySizedBox(
                        duration: motion,
                        heightFactor: barHeight,
                        widthFactor: 0.42,
                        child: AnimatedContainer(
                          duration: motion,
                          decoration: ShapeDecoration(
                            shape: AppRadii.squircle(4),
                            color: barColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${lap.lap.displayNumber}',
                    style: AppTextStyles.numeral.copyWith(
                      fontSize: 11,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
              if (slides > 0)
                Positioned(
                  top: -2,
                  right: -1,
                  child: SizedBox.square(
                    dimension: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ChannelColors.resolve(context).steering,
                        border: Border.all(
                          color: AppColors.surfaceBase,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The conditions lens selector (§8.13.6): only the conditions that changed
/// this session, and a sentence when none did.
class _LensSelector extends ConsumerWidget {
  const _LensSelector({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final lens = ref.watch(techniqueLensProvider(source));
    final chosen = ref.watch(
      techniqueSelectionStateProvider(source).select((s) => s.lens),
    );
    final options = lens.value?.options;
    if (options == null) {
      return lens.hasError
          ? Text(
              'Conditions could not be read.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            )
          : const Skeleton(width: 220, height: 30);
    }
    if (options.isEmpty) {
      return AppTooltip(
        message:
            'The lens compares segments across a change of wetness, compound '
            'or electronics. None changed with at least three racing laps '
            'either side.',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_center_focus, size: 16, color: muted),
            const SizedBox(width: 8),
            Text(
              'Conditions were constant this session',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      );
    }
    void set(LensOption? option) => ref
        .read(techniqueSelectionStateProvider(source).notifier)
        .setLens(option);
    return GlassPopoverAnchor(
      width: 340,
      trigger: (context, toggle) => Hoverable(
        radius: AppRadii.sm,
        onTap: toggle,
        semanticLabel: 'Conditions lens',
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppDurations.fast),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: ShapeDecoration(
            shape: GradientSquircleBorder(
              radius: AppRadii.sm,
              gradient: chosen == null
                  ? AppGradients.hairline
                  : AppGradients.hairlineStrong,
            ),
            color: chosen == null
                ? null
                : ChannelColors.resolve(context).delta.withValues(alpha: 0.16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_center_focus,
                size: 16,
                color: chosen == null
                    ? muted
                    : ChannelColors.resolve(context).delta,
              ),
              const SizedBox(width: 8),
              Text(
                chosen == null ? 'Conditions lens' : chosen.label,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: muted),
            ],
          ),
        ),
      ),
      popover: (context, close) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Conditions lens', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Compare each segment across a change this session. What changed '
            'together is named; a change within lap-to-lap noise is greyed.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 10),
          _LensOptionRow(
            label: 'Off',
            detail: 'Show the selected lap against the session median',
            selected: chosen == null,
            onTap: () {
              set(null);
              close();
            },
          ),
          for (final o in options)
            _LensOptionRow(
              label: o.label,
              detail:
                  '${o.baselineLaps} laps ${o.condition.format(o.baseline)} · '
                  '${o.otherLaps} laps ${o.condition.format(o.other)}',
              leading: o.condition == LensCondition.compound
                  ? _CompoundChange(
                      from: lens.value!.compounds[o.baseline],
                      to: lens.value!.compounds[o.other],
                    )
                  : null,
              selected: o == chosen,
              onTap: () {
                set(o);
                close();
              },
            ),
        ],
      ),
    );
  }
}

class _LensOptionRow extends StatelessWidget {
  const _LensOptionRow({
    required this.label,
    required this.detail,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  /// What the option is between, drawn: a compound's badges.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Hoverable(
        radius: AppRadii.sm,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppDurations.fast),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: ShapeDecoration(
            shape: AppRadii.squircle(AppRadii.sm),
            color: selected
                ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                : null,
          ),
          child: Row(
            children: [
              if (leading case final mark?) ...[mark, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelLarge),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check, size: 16, color: theme.colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compound lens option drawn: the usual compound's badge, an arrow, the
/// other's.
class _CompoundChange extends StatelessWidget {
  const _CompoundChange({required this.from, required this.to});

  final CompoundMark? from;
  final CompoundMark? to;

  @override
  Widget build(BuildContext context) {
    final from = this.from;
    final to = this.to;
    if (from == null || to == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompoundBadge(mark: from, showTread: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        CompoundBadge(mark: to, showTread: false),
      ],
    );
  }
}
