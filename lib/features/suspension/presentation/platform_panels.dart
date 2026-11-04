/// The platform as a whole (suspension proposal §4.5): damper speeds per
/// corner on a car outline, roll per axle, and per-lap trends.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../../setup_viewer/application/car_setup.dart';
import '../application/suspension_providers.dart';
import '../domain/platform.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';
import 'suspension_glyphs.dart';
import 'suspension_text.dart';

WheelCorner _wheel(Corner c) => WheelCorner.values[c.index];

class DamperPanel extends StatelessWidget {
  const DamperPanel({super.key, required this.overview, required this.lap});

  final SuspensionOverview overview;
  final int lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final knee = overview.knee;
    final p = overview.platformOf(lap);
    final c = overview.ceilings;
    Widget card(Corner corner) => _CornerCard(
      corner: corner,
      session: overview.sessionDampers(corner),
      lap: overview.dampers[lap]?[corner] ?? DamperHistogram.empty,
      knee: knee.of(corner),
      clicks: overview.setup?.dampers(_wheel(corner)),
    );
    final third = overview.hasThirdElement
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SuspensionGlyph(
                SuspensionGlyphKind.packers,
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Third element on its packers above '
                  '${platformSpeedKph.round()} km/h this lap: front '
                  '${p?.frontPackers == null ? '—' : percent(p!.frontPackers!)}'
                  '${c.front == null ? '' : ' (at ${mm(c.front!, digits: 2)} mm)'}'
                  ', rear '
                  '${p?.rearPackers == null ? '—' : percent(p!.rearPackers!)}'
                  '${c.rear == null ? '' : ' (at ${mm(c.rear!, digits: 2)} mm)'}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.numeral.copyWith(
                    fontSize: 11.5,
                    color: muted,
                  ),
                ),
              ),
            ],
          )
        : Text(
            'This car has no third element.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          );
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Dampers',
            caption: 'How fast each corner moved: bump up, rebound down',
            trailing: InfoPopoverButton(
              title: 'Damper speeds',
              paragraphs: [
                'Each corner\'s suspension speed (how fast its travel '
                    'changed), in mm/s, counted in bins: bump (compressing) '
                    'above the line, rebound below. Grey is the whole session, '
                    'ink this lap.',
                'Dampers have a slow and a fast circuit. The shaded part is '
                    'the fast one. The game sets the split per car, and it '
                    'is in neither the recording nor the setup.',
                knee.measured
                    ? knee.source!
                    : 'This car\'s split has not been measured: '
                          '${knee.front.round()} mm/s is a default. Drive one '
                          'lap with slow dampers at minimum and fast at '
                          'maximum, and one the other way round, and the '
                          'split shows where their histograms part.',
                'Kerbs are where the fast damping works: 550–900 mm/s, '
                    'against under 50 mm/s on a straight (your Le Mans '
                    'test).',
              ],
              footer: [sessionSource(overview.racingLapCount)],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final corner in Corner.values) ...[
                      card(corner),
                      const SizedBox(height: 10),
                    ],
                    third,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: card(Corner.frontLeft)),
                      const SizedBox(width: 12),
                      Expanded(child: card(Corner.frontRight)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: third,
                  ),
                  Row(
                    children: [
                      Expanded(child: card(Corner.rearLeft)),
                      const SizedBox(width: 12),
                      Expanded(child: card(Corner.rearRight)),
                    ],
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

class _CornerCard extends StatelessWidget {
  const _CornerCard({
    required this.corner,
    required this.session,
    required this.lap,
    required this.knee,
    required this.clicks,
  });

  final Corner corner;
  final DamperHistogram session;
  final DamperHistogram lap;
  final double knee;
  final ({
    String? slowBump,
    String? fastBump,
    String? slowRebound,
    String? fastRebound,
  })?
  clicks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final k = clicks;
    final fast = lap.total == 0 ? null : lap.fastShare(knee);
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.md),
        color: scheme.onSurface.withValues(alpha: 0.03),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SuspensionGlyph(
                  SuspensionGlyphKind.damper,
                  size: 15,
                  color: muted,
                ),
                const SizedBox(width: 6),
                Text(corner.short, style: theme.textTheme.titleSmall),
                const Spacer(),
                if (fast != null)
                  AppTooltip(
                    message:
                        'Share of this lap\'s samples on the fast circuit, '
                        'over ${knee.round()} mm/s either way.',
                    child: Text(
                      '${percent(fast)} fast',
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 112,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.duration(context, AppDurations.slow),
                curve: AppCurves.entrance,
                builder: (context, grow, _) => RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _HistogramPainter(
                      session: session,
                      lap: lap,
                      knee: knee,
                      grow: grow,
                      ink: scheme.onSurface,
                      muted: muted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (k != null)
              Text(
                'Bump ${k.slowBump ?? '—'} / ${k.fastBump ?? '—'} · '
                'rebound ${k.slowRebound ?? '—'} / ${k.fastRebound ?? '—'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 10.5,
                  color: muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter({
    required this.session,
    required this.lap,
    required this.knee,
    required this.grow,
    required this.ink,
    required this.muted,
  });

  final DamperHistogram session;
  final DamperHistogram lap;
  final double knee;
  final double grow;
  final Color ink;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final bins = DamperHistogram.binsPerSide;
    final mid = size.height / 2;
    final w = size.width / bins;
    final st = session.total;
    final lt = lap.total;
    // Shares, so the session and the lap draw on one scale.
    var peak = 0.0;
    for (var b = -bins; b < bins; b++) {
      if (st > 0) peak = math.max(peak, session.at(b) / st);
      if (lt > 0) peak = math.max(peak, lap.at(b) / lt);
    }
    if (peak <= 0) return;
    // A square-root scale: the fast bins hold a few % of samples, and on a
    // linear scale they would vanish next to the slow ones.
    double h(double share) => math.sqrt(share / peak) * (mid - 6) * grow;

    // The fast zone, shaded.
    var kneeBin = bins;
    for (var b = 0; b < bins; b++) {
      if (DamperHistogram.lowerEdge(b) >= knee) {
        kneeBin = b;
        break;
      }
    }
    canvas.drawRect(
      Rect.fromLTRB(kneeBin * w, 0, size.width, size.height),
      Paint()..color = ink.withValues(alpha: 0.045),
    );
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = muted.withValues(alpha: 0.4)
        ..strokeWidth = 1,
    );
    for (var k = 0; k < bins; k++) {
      final x = k * w;
      for (final bump in [true, false]) {
        final b = bump ? k : -k - 1;
        void bar(double share, Color color, double inset) {
          final height = h(share);
          final r = bump
              ? Rect.fromLTRB(x + inset, mid - height, x + w - inset, mid)
              : Rect.fromLTRB(x + inset, mid, x + w - inset, mid + height);
          canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(1.5)),
            Paint()..color = color,
          );
        }

        if (st > 0) bar(session.at(b) / st, muted.withValues(alpha: 0.28), 1);
        if (lt > 0) bar(lap.at(b) / lt, ink.withValues(alpha: 0.85), w * 0.28);
      }
    }
    final style = TextStyle(fontSize: 9, color: muted);
    for (final (label, at) in [
      ('0', 0.0),
      ('${knee.round()}', kneeBin * w),
      ('800+', size.width - 22),
    ]) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(at + 1, size.height - tp.height));
    }
    final bumpLabel = TextPainter(
      text: TextSpan(text: 'bump', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    bumpLabel.paint(canvas, const Offset(1, 0));
  }

  @override
  bool shouldRepaint(_HistogramPainter old) =>
      old.lap != lap || old.grow != grow || old.session != session;
}

class RollPanel extends StatelessWidget {
  const RollPanel({
    super.key,
    required this.overview,
    required this.lap,
    required this.onSelectLap,
  });

  final SuspensionOverview overview;
  final int lap;
  final ValueChanged<int> onSelectLap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = overview.platformOf(lap);
    final bars = overview.setup?.antiRollBars;
    String roll(double? slope, double? r) => slope == null
        ? '—'
        : '${slope.toStringAsFixed(2)} mm/G'
              '${r == null ? '' : '  r ${r.toStringAsFixed(2)}'}';
    final steps = overview.balanceSteps;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Roll',
            caption: 'Travel per G of cornering, per axle',
            trailing: InfoPopoverButton(
              title: 'Roll and the bars',
              paragraphs: [
                'Roll is the left corner\'s travel minus the right\'s, per G '
                    'of lateral load: millimetres of travel per G, not '
                    'degrees. Travel is compression positive.',
                'A stiffer bar on one axle makes that axle roll less. The '
                    'ratio of front to rear roll is the balance; a step in it '
                    'between laps is marked, because a bar changed from the '
                    'cockpit is not logged and shows only this way.',
                'On your 499P runs the bar settings ordered from −8.3 mm/G '
                    '(A-P1, softest) to −1.85 (E-P5, stiffest) of front roll. '
                    'On the Alpine a front-bar change did not show at all.',
              ],
              footer: [sessionSource(overview.racingLapCount)],
            ),
          ),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _RollFigure(
                axle: 'Front',
                value: roll(p?.frontRoll, p?.frontRollR),
                bar: bars?.front,
              ),
              _RollFigure(
                axle: 'Rear',
                value: roll(p?.rearRoll, p?.rearRollR),
                bar: bars?.rear,
              ),
              _RollFigure(
                axle: 'Front ÷ rear',
                value: p?.rollRatio?.toStringAsFixed(2) ?? '—',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Trend(
            label: 'Front ÷ rear roll',
            values: {for (final l in overview.platform) l.lap: l.rollRatio},
            laps: [for (final l in overview.racing) l.index],
            selected: lap,
            markers: steps.toSet(),
            onSelect: onSelectLap,
            format: (v) => v.toStringAsFixed(2),
          ),
          const SizedBox(height: 4),
          Text(
            steps.isEmpty
                ? 'The balance held all session: no lap stepped more than '
                      '${(balanceStepShare * 100).round()} % from the laps '
                      'before it.'
                : 'Balance stepped on lap'
                      '${steps.length == 1 ? '' : 's'} '
                      '${steps.map((l) => l + 1).join(', ')}: a bar change, '
                      'or a change in how the laps were driven.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _RollFigure extends StatelessWidget {
  const _RollFigure({required this.axle, required this.value, this.bar});

  final String axle;
  final String value;
  final String? bar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(axle, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        FadeOnChange(
          value: value,
          duration: AppMotion.duration(context, AppDurations.fast),
          child: Text(
            value,
            style: AppTextStyles.numeral.copyWith(fontSize: 15),
          ),
        ),
        if (bar != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuspensionGlyph(
                SuspensionGlyphKind.antiRollBar,
                size: 13,
                color: muted,
              ),
              const SizedBox(width: 4),
              Text(
                'bar $bar',
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 11,
                  color: muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class TrendsPanel extends StatelessWidget {
  const TrendsPanel({
    super.key,
    required this.overview,
    required this.lap,
    required this.onSelectLap,
  });

  final SuspensionOverview overview;
  final int lap;
  final ValueChanged<int> onSelectLap;

  @override
  Widget build(BuildContext context) {
    final laps = [for (final l in overview.racing) l.index];
    final strikes = <int, double>{for (final l in laps) l: 0};
    for (final s in overview.headline) {
      strikes[s.lap] = (strikes[s.lap] ?? 0) + 1;
    }
    final lapTimes = {
      for (final l in overview.racing) l.index: l.lapTimeSeconds,
    };
    Map<int, double?> of(double? Function(LapPlatform) f, {double k = 1}) => {
      for (final p in overview.platform) p.lap: f(p) == null ? null : f(p)! * k,
    };
    final steps = overview.balanceSteps.toSet();
    final trends = [
      _Trend(
        label: 'Lap time',
        values: lapTimes,
        laps: laps,
        selected: lap,
        markers: steps,
        onSelect: onSelectLap,
        format: (v) => v.toStringAsFixed(1),
        unit: 's',
      ),
      _Trend(
        label: 'Strikes',
        values: strikes,
        laps: laps,
        selected: lap,
        markers: steps,
        onSelect: onSelectLap,
        format: (v) => v.round().toString(),
        bars: true,
      ),
      _Trend(
        label: 'Lowest front',
        values: of((p) => p.frontLowest, k: 1000),
        laps: laps,
        selected: lap,
        markers: steps,
        onSelect: onSelectLap,
        format: (v) => v.toStringAsFixed(1),
        unit: 'mm',
        floor: strikeFloorMetres * 1000,
      ),
      _Trend(
        label: 'Lowest rear',
        values: of((p) => p.rearLowest, k: 1000),
        laps: laps,
        selected: lap,
        markers: steps,
        onSelect: onSelectLap,
        format: (v) => v.toStringAsFixed(1),
        unit: 'mm',
        floor: strikeFloorMetres * 1000,
      ),
      if (overview.hasThirdElement) ...[
        _Trend(
          label: 'Front packers',
          values: of((p) => p.frontPackers, k: 100),
          laps: laps,
          selected: lap,
          markers: steps,
          onSelect: onSelectLap,
          format: (v) => v.round().toString(),
          unit: '%',
        ),
        _Trend(
          label: 'Rear packers',
          values: of((p) => p.rearPackers, k: 100),
          laps: laps,
          selected: lap,
          markers: steps,
          onSelect: onSelectLap,
          format: (v) => v.round().toString(),
          unit: '%',
        ),
      ],
    ];
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Lap by lap',
            caption: 'Click a lap to select it; ⇅ marks a balance step',
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  for (final t in trends) SizedBox(width: width, child: t),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One measure over the racing laps, the selected lap marked.
class _Trend extends StatelessWidget {
  const _Trend({
    required this.label,
    required this.values,
    required this.laps,
    required this.selected,
    required this.markers,
    required this.onSelect,
    required this.format,
    this.unit,
    this.bars = false,
    this.floor,
  });

  final String label;
  final Map<int, double?> values;
  final List<int> laps;
  final int selected;
  final Set<int> markers;
  final ValueChanged<int> onSelect;
  final String Function(double) format;
  final String? unit;
  final bool bars;
  final double? floor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final v = values[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
            RollingNumber(
              value: v,
              format: format,
              style: const TextStyle(fontSize: 12.5),
              unit: unit,
              unitStyle: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 46,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              onTapUp: (e) {
                if (laps.isEmpty) return;
                final i = (e.localPosition.dx / c.maxWidth * laps.length)
                    .floor()
                    .clamp(0, laps.length - 1);
                onSelect(laps[i]);
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(c.maxWidth, 46),
                    painter: _TrendPainter(
                      values: [for (final l in laps) values[l]],
                      selectedIndex: laps.indexOf(selected),
                      markers: [
                        for (final (i, l) in laps.indexed)
                          if (markers.contains(l)) i,
                      ],
                      bars: bars,
                      floor: floor,
                      ink: scheme.onSurface,
                      muted: muted,
                      accent: scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.selectedIndex,
    required this.markers,
    required this.bars,
    required this.floor,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final List<double?> values;
  final int selectedIndex;
  final List<int> markers;
  final bool bars;
  final double? floor;
  final Color ink;
  final Color muted;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final present = [for (final v in values) ?v];
    if (present.isEmpty) return;
    var lo = present.reduce(math.min);
    var hi = present.reduce(math.max);
    if (bars) lo = 0;
    if (floor case final f?) {
      lo = math.min(lo, f);
      hi = math.max(hi, f);
    }
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= bars ? 0 : 1;
    }
    final n = values.length;
    final w = size.width / n;
    double x(int i) => (i + 0.5) * w;
    double y(double v) =>
        size.height - 3 - (v - lo) / (hi - lo) * (size.height - 6);

    for (final i in markers) {
      canvas.drawLine(
        Offset(i * w, 0),
        Offset(i * w, size.height),
        Paint()
          ..color = muted.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
    if (floor case final f?) {
      final fy = y(f);
      for (var dx = 0.0; dx < size.width; dx += 6) {
        canvas.drawLine(
          Offset(dx, fy),
          Offset(math.min(dx + 3, size.width), fy),
          Paint()
            ..color = muted.withValues(alpha: 0.6)
            ..strokeWidth = 1,
        );
      }
    }
    if (bars) {
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null || v <= 0) continue;
        canvas.drawRRect(
          RRect.fromLTRBR(
            i * w + w * 0.2,
            y(v),
            (i + 1) * w - w * 0.2,
            size.height - 3,
            const Radius.circular(1.5),
          ),
          Paint()
            ..color = i == selectedIndex ? accent : ink.withValues(alpha: 0.5),
        );
      }
    } else {
      final path = Path();
      var pen = false;
      for (var i = 0; i < n; i++) {
        final v = values[i];
        if (v == null) {
          pen = false;
          continue;
        }
        if (pen) {
          path.lineTo(x(i), y(v));
        } else {
          path.moveTo(x(i), y(v));
          pen = true;
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = ink.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
      if (selectedIndex >= 0 && selectedIndex < n) {
        final v = values[selectedIndex];
        if (v != null) {
          canvas.drawCircle(
            Offset(x(selectedIndex), y(v)),
            3.6,
            Paint()..color = accent,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => true;
}

/// Strike counts for a lap, by phase, for the screen's tests and tooltips.
Map<StrikePhase, int> phaseCounts(Iterable<Strike> strikes) {
  final out = <StrikePhase, int>{};
  for (final s in strikes) {
    out[s.phase] = (out[s.phase] ?? 0) + 1;
  }
  return out;
}
