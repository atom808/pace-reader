/// "Lap at a glance": one card per measure family (SPEC.md §8.13.7).
///
/// Each card leads with the lap's value, set large, and places it among the
/// session's laps on a small range bar — lowest to highest, the median a
/// tick — so "is this a lot?" is answered without a second number to
/// compare. A plain line says what it is; the ⓘ says exactly how it was
/// measured and checked.
library;

import 'dart:math' as math;

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/technique_providers.dart';
import '../domain/lap_technique.dart';
import '../domain/shifts.dart';
import 'technique_text.dart';
import 'technique_widgets.dart';

/// Every card for [lap], in reading order.
class LapAtAGlance extends StatelessWidget {
  const LapAtAGlance({super.key, required this.overview, required this.lap});

  final TechniqueOverview overview;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context) {
    final session = overview.session;
    final measures = [
      TechniqueMeasure.fullThrottle,
      TechniqueMeasure.braking,
      TechniqueMeasure.gripUsed,
      TechniqueMeasure.trail,
      TechniqueMeasure.overlap,
      TechniqueMeasure.coasting,
      TechniqueMeasure.tc,
      if (session.hasAbs) TechniqueMeasure.abs,
    ];
    final cards = <Widget>[
      for (final m in measures) _cardFor(context, m),
      _ShiftCard(overview: overview, lap: lap),
      _SlidesCard(overview: overview, lap: lap),
    ];
    // Balanced rows that fill the width — ten cards as 5 + 5, not 6 + 4 —
    // each row as tall as its tallest card, so the edges line up.
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final fit = math.max(
          1,
          ((constraints.maxWidth + gap) / (MeasureCard.width + gap)).floor(),
        );
        final rows = (cards.length / fit).ceil();
        final columns = (cards.length / rows).ceil();
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++)
                      if (r * columns + c < cards.length) ...[
                        if (c > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: width,
                          child: StaggeredEntrance(
                            index: r * columns + c,
                            child: cards[r * columns + c],
                          ),
                        ),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _cardFor(BuildContext context, TechniqueMeasure m) {
    final p = lap.pedals;
    final extra = switch (m) {
      TechniqueMeasure.coasting =>
        '${p.coastMetres.toStringAsFixed(0)} m of track',
      TechniqueMeasure.tc => _episodes(lap.tcEpisodes, 'intervention'),
      TechniqueMeasure.abs => _episodes(lap.absEpisodes, 'intervention'),
      TechniqueMeasure.braking =>
        '${p.seconds(p.braking).toStringAsFixed(1)} s on the brake',
      TechniqueMeasure.fullThrottle =>
        '${p.seconds(p.fullThrottle).toStringAsFixed(1)} s flat out',
      _ => null,
    };
    final breakdown = switch (m) {
      TechniqueMeasure.overlap => overlapBreakdown(lap.spans),
      TechniqueMeasure.coasting => coastBreakdown(lap.spans),
      _ => null,
    };
    return MeasureCard(
      measure: m,
      value: m.of(lap),
      median: overview.median(m),
      range: overview.range(m),
      extra: extra,
      footer: [
        if (breakdown != null) 'This lap: $breakdown.',
        paceNote(m),
        ?sessionCorrelation(overview.correlation(m), overview.laps.length),
      ],
    );
  }

  static String _episodes(int n, String what) =>
      n == 0 ? 'none this lap' : '$n $what${n == 1 ? '' : 's'}';
}

/// One measure on one lap.
class MeasureCard extends StatelessWidget {
  const MeasureCard({
    super.key,
    required this.measure,
    required this.value,
    this.median,
    this.range,
    this.extra,
    this.footer = const [],
  });

  static const width = 236.0;

  final TechniqueMeasure measure;
  final double? value;
  final double? median;
  final ({double min, double max})? range;

  /// A second, smaller fact: "127 m of track", "8 interventions".
  final String? extra;

  /// The popover's closing lines.
  final List<String> footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final color = measureColor(context, measure);
    return SizedBox(
      width: width,
      child: SquircleCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MeasureGlyph(measure: measure),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    measure.label,
                    style: theme.textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InfoPopoverButton(
                  title: measure.label,
                  paragraphs: measureDefinition(measure),
                  footer: footer,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: RollingNumber(
                value: value,
                format: measure.format,
                unit: measure.unit,
                style: const TextStyle(fontSize: 28, height: 1.1),
                unitStyle: TextStyle(fontSize: 14, color: muted),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SessionRangeBar(
                value: value,
                median: median,
                range: range,
                color: color,
                format: (v) => '${measure.format(v)} ${measure.unit}',
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      median == null
                          ? 'no session median'
                          : 'median ${measure.format(median!)} ${measure.unit}',
                      style: AppTextStyles.numeral.copyWith(
                        fontSize: 11,
                        color: muted,
                      ),
                    ),
                  ),
                  if (measure.goesWithPace) const PaceTag(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                extra == null
                    ? measure.subtitle
                    : '${measure.subtitle} · $extra',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the lap sits among the session's laps: a track from the lowest lap
/// to the highest, the median a tick, this lap a dot that slides when the
/// lap changes.
class SessionRangeBar extends StatelessWidget {
  const SessionRangeBar({
    super.key,
    required this.value,
    required this.median,
    required this.range,
    required this.color,
    required this.format,
  });

  final double? value;
  final double? median;
  final ({double min, double max})? range;
  final Color color;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = range;
    double at(double v) {
      if (r == null || r.max <= r.min) return 0.5;
      return ((v - r.min) / (r.max - r.min)).clamp(0.0, 1.0);
    }

    final v = value;
    return Tooltip(
      message: r == null
          ? 'No other laps to place this one among.'
          : 'Session: ${format(r.min)} to ${format(r.max)}'
                '${median == null ? '' : ', median ${format(median!)}'}',
      child: SizedBox(
        height: 14,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: v == null ? 0.5 : at(v)),
          duration: AppMotion.duration(context, rollDuration),
          curve: AppCurves.entrance,
          builder: (context, position, _) => CustomPaint(
            size: Size.infinite,
            painter: _RangePainter(
              position: v == null ? null : position,
              median: median == null ? null : at(median!),
              color: color,
              track: theme.colorScheme.onSurface.withValues(alpha: 0.12),
              tick: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter({
    required this.position,
    required this.median,
    required this.color,
    required this.track,
    required this.tick,
  });

  final double? position;
  final double? median;
  final Color color;
  final Color track;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final y = size.height / 2;
    final left = inset;
    final right = size.width - inset;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      Paint()
        ..color = track
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    final m = median;
    if (m != null) {
      final x = left + (right - left) * m;
      canvas.drawLine(
        Offset(x, y - 5),
        Offset(x, y + 5),
        Paint()
          ..color = tick
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    final p = position;
    if (p != null) {
      final x = left + (right - left) * p;
      canvas.drawCircle(
        Offset(x, y),
        5.5,
        Paint()..color = AppColors.surfaceBase,
      );
      canvas.drawCircle(Offset(x, y), 4.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_RangePainter old) =>
      old.position != position ||
      old.median != median ||
      old.color != color ||
      old.track != track;
}

/// Shifts this lap: up and down, and how many upshifts reached the limiter.
class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.overview, required this.lap});

  final TechniqueOverview overview;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final gear = ChannelColors.resolve(context).gear;
    final mine = [
      for (final u in overview.upshifts)
        if (u.lap == lap.lap.index) u,
    ];
    final atLimit = mine
        .where((u) => u.band == ShiftBand.atLimiter || u.band == ShiftBand.late)
        .length;
    final medianUps = medianOf([
      for (final t in overview.laps.values) t.upshifts.toDouble(),
    ]);
    final limiter = overview.session.revLimiter;
    return SizedBox(
      width: MeasureCard.width,
      child: SquircleCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Dot(color: gear),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Shifts', style: theme.textTheme.labelLarge),
                ),
                InfoPopoverButton(
                  title: 'Shifts',
                  paragraphs: const [
                    'Upshifts and downshifts on the lap. Every gear change in '
                        'these files passes through neutral, so a shift is a '
                        'change between two gears, not every row of the gear '
                        'channel.',
                    'The rev limit is the setup\'s rev limiter, not the '
                        'file\'s "Engine Max RPM", which sits 25 % above it on '
                        'every GT3.',
                  ],
                  footer: [
                    if (limiter != null)
                      'Limiter: ${limiter.toStringAsFixed(0)} rpm.',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${lap.upshifts}'),
                  TextSpan(
                    text: ' up  ',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                  TextSpan(text: '${lap.downshifts}'),
                  TextSpan(
                    text: ' down',
                    style: TextStyle(fontSize: 14, color: muted),
                  ),
                ],
              ),
              style: AppTextStyles.numeral.copyWith(fontSize: 28, height: 1.1),
            ),
            const SizedBox(height: 10),
            Text(
              medianUps == null
                  ? ''
                  : 'median ${medianUps.toStringAsFixed(0)} up a lap',
              style: AppTextStyles.numeral.copyWith(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                limiter == null
                    ? 'The setup records no rev limiter.'
                    : mine.isEmpty
                    ? 'No upshift on this lap.'
                    : '$atLimit of ${mine.length} upshifts within 200 rpm '
                          'of the limiter',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caught slides this lap, with a marker that pulses once when the lap is
/// first shown (§8.13.8 "Countersteer"), never on a loop.
class _SlidesCard extends HookWidget {
  const _SlidesCard({required this.overview, required this.lap});

  final TechniqueOverview overview;
  final LapTechnique lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final steering = ChannelColors.resolve(context).steering;
    final episodes = lap.countersteer;
    final lapsWith = overview.laps.values
        .where((t) => t.countersteer.isNotEmpty)
        .length;
    final pulse = useAnimationController(
      duration: AppMotion.duration(context, const Duration(milliseconds: 900)),
    );
    useEffect(() {
      if (episodes.isNotEmpty && !AppMotion.reduced(context)) {
        pulse.forward(from: 0);
      }
      return null;
    }, [lap.lap.index]);

    final first = episodes.firstOrNull;
    return SizedBox(
      width: MeasureCard.width,
      child: SquircleCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) {
                    final t = pulse.value;
                    final ring = episodes.isEmpty || t == 0 || t == 1 ? 0.0 : t;
                    return SizedBox.square(
                      dimension: 9,
                      child: CustomPaint(
                        painter: _PulsePainter(
                          color: steering,
                          ring: ring,
                          filled: episodes.isNotEmpty,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Caught slides',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const InfoPopoverButton(
                  title: 'Caught slides',
                  paragraphs: [
                    'Steering against the turn: the wheel turned at least 5 % '
                        'the same way the car is being pushed, at 0.5 G or '
                        'more and above 60 km/h, for 0.3 s or longer, '
                        'reaching 20 % opposite lock.',
                    'It finds the slides the driver corrected. A slide not '
                        'caught, and understeer, need a yaw rate the file '
                        'does not record.',
                  ],
                  footer: [
                    'Across five races, laps with one ran a median 0.5–2.5 s '
                        'slower than their session\'s median lap.',
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${episodes.length}',
              style: AppTextStyles.numeral.copyWith(fontSize: 28, height: 1.1),
            ),
            const SizedBox(height: 10),
            Text(
              '$lapsWith of ${overview.laps.length} laps had one',
              style: AppTextStyles.numeral.copyWith(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                first == null
                    ? 'No slide caught on this lap.'
                    : 'At ${first.station.toStringAsFixed(0)} m, '
                          '${first.peakSteer.toStringAsFixed(0)} % opposite '
                          'lock at ${first.speed.toStringAsFixed(0)} km/h'
                          '${episodes.length > 1 ? ', and ${episodes.length - 1} more' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 9,
    child: DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.color,
    required this.ring,
    required this.filled,
  });

  final Color color;

  /// 0..1 through the one pulse; 0 when still.
  final double ring;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    if (ring > 0) {
      canvas.drawCircle(
        c,
        r + ring * 9,
        Paint()
          ..color = color.withValues(alpha: (1 - ring) * 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.ring != ring || old.filled != filled || old.color != color;
}
