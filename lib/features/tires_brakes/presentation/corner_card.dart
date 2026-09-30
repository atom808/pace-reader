/// One corner of the car on one lap (SPEC.md §8.6).
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/charting/value_ramp.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/tire_brake_report.dart';
import 'tyre_format.dart';

/// Motion for a value that changed because the lap did — a short settle
/// rather than an entrance, and none at all under reduced motion.
Duration valueChangeDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppDurations.slow;

/// A number that eases to its new value when the lap changes, so stepping
/// laps reads as the tyre changing rather than the card being replaced.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double? value;
  final String Function(double) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final target = value;
    if (target == null) return Text('—', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: valueChangeDuration(context),
      curve: AppCurves.standard,
      builder: (context, shown, _) => Text(format(shown), style: style),
    );
  }
}

/// The corner card: pressure against its cold setting, the tread across its
/// width, carcass, wear and brake — every figure printed, none hover-only.
class CornerCard extends StatelessWidget {
  const CornerCard({
    super.key,
    required this.snapshot,
    required this.ramp,
    required this.rampRange,
    required this.selectedMetric,
    required this.onSelectMetric,
    this.hottest = false,
    this.mostWorn = false,
  });

  final CornerSnapshot snapshot;
  final ValueRamp ramp;
  final ({double min, double max})? rampRange;

  /// The metric the trend charts show, marked on the card so the two views
  /// read as one.
  final TyreMetric selectedMetric;
  final ValueChanged<TyreMetric> onSelectMetric;

  final bool hottest;
  final bool mostWorn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final corner = snapshot.corner;
    final emphasised = hottest || mostWorn;

    return SquircleCard(
      // The corner that stands out gets the lit edge — the app's one
      // "this is the subject" treatment — and a word saying why.
      border: emphasised ? AppGradients.hairlineStrong : null,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(corner.short,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  corner.label,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (hottest) const _Tag('hottest'),
              if (hottest && mostWorn) const SizedBox(width: 6),
              if (mostWorn) const _Tag('most worn'),
            ],
          ),
          const SizedBox(height: 12),
          _TreadStrip(
            corner: corner,
            tread: snapshot.tread,
            ramp: ramp,
            range: rampRange,
            selected: selectedMetric == TyreMetric.tread,
            onTap: () => onSelectMetric(TyreMetric.tread),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Fact(
                  label: 'Pressure',
                  value: snapshot.pressure?.mean,
                  unit: 'kPa',
                  decimals: 1,
                  caption: switch ((
                    snapshot.coldPressure?.number,
                    snapshot.pressureGain,
                  )) {
                    (final cold?, final gain?) =>
                      'cold ${cold.toStringAsFixed(0)} · '
                          '${formatSigned(gain, 1)}',
                    (final cold?, null) => 'cold ${cold.toStringAsFixed(0)}',
                    _ => 'no cold setting',
                  },
                  selected: selectedMetric == TyreMetric.pressure,
                  onTap: () => onSelectMetric(TyreMetric.pressure),
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Carcass',
                  value: snapshot.carcass?.mean,
                  unit: '°C',
                  decimals: 1,
                  caption: switch (snapshot.rim?.mean) {
                    final rim? => 'rim ${rim.toStringAsFixed(1)} °C',
                    null => null,
                  },
                  selected: selectedMetric == TyreMetric.carcass,
                  onTap: () => onSelectMetric(TyreMetric.carcass),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Fact(
                  label: 'Life left',
                  value: snapshot.wearLeft,
                  unit: '%',
                  decimals: 2,
                  caption: switch (snapshot.wear?.used) {
                    final used? => '${formatSigned(-used, 2)} this lap',
                    null => null,
                  },
                  selected: selectedMetric == TyreMetric.wear,
                  onTap: () => onSelectMetric(TyreMetric.wear),
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Brake peak',
                  value: snapshot.brake?.max,
                  unit: '°C',
                  decimals: 0,
                  caption: switch (snapshot.brake?.mean) {
                    final mean? => 'mean ${mean.toStringAsFixed(0)} °C',
                    null => null,
                  },
                  selected: selectedMetric == TyreMetric.brake,
                  onTap: () => onSelectMetric(TyreMetric.brake),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.sm),
        color: theme.colorScheme.primary.withValues(alpha: 0.16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

/// A figure on the card that is also the way into its trend: tapping it
/// shows that quantity in the charts below, and the one they show is marked.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.label,
    required this.value,
    required this.unit,
    required this.decimals,
    required this.caption,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Show $label across the stint',
      child: InkWell(
        onTap: onTap,
        customBorder: AppRadii.squircle(AppRadii.sm),
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDurations.medium,
          curve: AppCurves.standard,
          margin: const EdgeInsets.only(top: 4, right: 6),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          decoration: ShapeDecoration(
            shape: AppRadii.squircle(AppRadii.sm),
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: selected ? scheme.primary : muted,
                  )),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AnimatedNumber(
                    value: value,
                    format: (v) => v.toStringAsFixed(decimals),
                    style: AppTextStyles.numeral.copyWith(fontSize: 18),
                  ),
                  if (value != null) ...[
                    const SizedBox(width: 4),
                    Text(unit,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: muted)),
                  ],
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: AppTextStyles.numeral
                      .copyWith(fontSize: 11.5, color: muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The tread across its width, as the car sees it from above, nose up.
///
/// Drawn in **car-frame order** — `TyresTempLeft`, `Centre`, `Right` from
/// the screen's left to right — because that is where each edge physically
/// is in the 2×2 layout: a left wheel's outer edge faces the left of the
/// screen, a right wheel's faces the right. So the cells never reorder; only
/// their inner/outer labels differ by side, and those come from
/// [Corner.innerEdge], not from this widget.
///
/// Coloured by the single-hue tyre ramp (value_ramp.dart: magnitude is
/// lightness, never a rainbow), with the number printed in every cell so the
/// colour is a reading aid and never the only record.
class _TreadStrip extends StatelessWidget {
  const _TreadStrip({
    required this.corner,
    required this.tread,
    required this.ramp,
    required this.range,
    required this.selected,
    required this.onTap,
  });

  final Corner corner;
  final TreadTemps? tread;
  final ValueRamp ramp;
  final ({double min, double max})? range;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = tread;
    if (t == null) {
      return SizedBox(
        height: 58,
        child: Center(
          child: Text('No tread temperatures for this lap',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      );
    }
    // Car-frame left → right.
    final zones = corner.isLeft
        ? [('outer', t.outer), ('centre', t.centre), ('inner', t.inner)]
        : [('inner', t.inner), ('centre', t.centre), ('outer', t.outer)];

    double normalized(double v) {
      final r = range;
      if (r == null || r.max == r.min) return 0.5;
      return (v - r.min) / (r.max - r.min);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: 'Tread temperatures, inner ${t.inner.mean.toStringAsFixed(1)}, '
          'centre ${t.centre.mean.toStringAsFixed(1)}, '
          'outer ${t.outer.mean.toStringAsFixed(1)} °C. '
          'Show tread temperature across the stint',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: AppRadii.squircle(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              ClipPath(
                clipper: ShapeBorderClipper(
                    shape: AppRadii.squircle(AppRadii.sm)),
                child: Row(
                  children: [
                    for (var i = 0; i < zones.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        child: _Zone(
                          value: zones[i].$2.mean,
                          color: ramp.at(normalized(zones[i].$2.mean)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final (label, _) in zones)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Zone extends StatelessWidget {
  const _Zone({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Ink that stays legible across the whole ramp: dark on its light end,
    // light on its dark end.
    final ink = ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : AppColors.surfaceBase;
    return AnimatedContainer(
      duration: valueChangeDuration(context),
      curve: AppCurves.standard,
      height: 38,
      color: color,
      alignment: Alignment.center,
      child: AnimatedNumber(
        value: value,
        format: (v) => v.toStringAsFixed(1),
        style: AppTextStyles.numeral.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
    );
  }
}

/// The ramp's key: its stops as discrete swatches between the two numbers
/// it spans — swatches rather than a gradient bar, because gradients in this
/// app are chrome (§9.7.1) and this is a scale.
class TreadRampLegend extends StatelessWidget {
  const TreadRampLegend({super.key, required this.ramp, required this.range});

  final ValueRamp ramp;
  final ({double min, double max}) range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = AppTextStyles.numeral.copyWith(fontSize: 11.5, color: muted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tread', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(width: 8),
        Text('${range.min.toStringAsFixed(1)} °C', style: style),
        const SizedBox(width: 6),
        for (final stop in ramp.stops(count: 6))
          Container(
            width: 14,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: ShapeDecoration(
              shape: AppRadii.squircle(4),
              color: stop,
            ),
          ),
        const SizedBox(width: 6),
        Text('${range.max.toStringAsFixed(1)} °C', style: style),
      ],
    );
  }
}
