/// At a glance (suspension proposal §4.2): strikes, one card per phase,
/// packers and ride height. A phase card filters the map and the sites
/// list to that phase.
library;

import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../application/suspension_providers.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';
import 'suspension_glyphs.dart';
import 'suspension_text.dart';

class GlanceCards extends StatelessWidget {
  const GlanceCards({
    super.key,
    required this.overview,
    required this.lap,
    required this.phase,
    required this.onPhase,
  });

  final SuspensionOverview overview;
  final int lap;
  final StrikePhase? phase;
  final ValueChanged<StrikePhase?> onPhase;

  @override
  Widget build(BuildContext context) {
    final headline = overview.headline.toList();
    final thisLap = headline.where((s) => s.lap == lap).length;
    final perLap = <int, int>{for (final l in overview.racing) l.index: 0};
    for (final s in headline) {
      perLap[s.lap] = (perLap[s.lap] ?? 0) + 1;
    }
    final sortedCounts = perLap.values.toList()..sort();
    final median = sortedCounts.isEmpty
        ? 0
        : sortedCounts[sortedCounts.length ~/ 2];
    final strikeSites = overview.sites
        .where((s) => s.tier == StrikeTier.strike)
        .length;
    final closeSites = overview.sites.length - strikeSites;
    final source = sessionSource(overview.racingLapCount);

    int count(bool Function(StrikePhase) test) =>
        headline.where((s) => test(s.phase)).length;
    int kerbs(bool Function(StrikePhase) test) => headline
        .where((s) => test(s.phase) && s.surface == StrikeSurface.kerb)
        .length;

    final cards = <Widget>[
      _GlanceCard(
        glyph: SuspensionGlyphKind.strike,
        title: 'Strikes',
        value: '$strikeSites',
        unit: strikeSites == 1 ? 'site' : 'sites',
        subtitle:
            '$thisLap this lap · session median $median'
            '${closeSites > 0 ? ' · $closeSites close' : ''}',
        info: (
          title: 'Strikes and sites',
          paragraphs: [
            tierMeaning,
            'A site is a place where strikes from two or more laps fall within '
                '${siteJoinMetres.round()} m of each other. At Indianapolis entry '
                'on your Le Mans race, 26 struck laps\' lowest points fell '
                'within 1 m.',
            floorNote,
          ],
          footer: [source],
        ),
      ),
      for (final p in const [
        StrikePhase.straight,
        StrikePhase.braking,
        StrikePhase.corner,
      ])
        _GlanceCard(
          glyph: SuspensionGlyphKind.ofPhase(p),
          title: p.label,
          value: '${count((x) => phaseMatches(p, x))}',
          unit: 'strikes',
          subtitle: _phaseSubtitle(
            p,
            kerbs((x) => phaseMatches(p, x)),
            headline.where((s) => s.lap == lap && phaseMatches(p, s.phase)),
          ),
          selected: phase == p,
          onTap: () => onPhase(phase == p ? null : p),
          info: (
            title: p.label,
            paragraphs: [
              p.meaning,
              if (p == StrikePhase.braking)
                'Of these, ${count((x) => x == StrikePhase.brakingCorner)} '
                    'were braking into a corner: braking and turning at once.',
              'Braking: brake over ${brakingPedalPercent.round()} % during the '
                  'strike, or slowing at over $brakingDecelerationG G. Corner: '
                  'over $cornerLateralG G sideways. Straight: neither.',
              if (p == StrikePhase.straight)
                'A kerb can look like a straight-line strike: '
                    '${kerbs((x) => x == StrikePhase.straight)} of these were '
                    'on kerbs, which the kerb tag tells apart.',
            ],
            footer: ['Click the card to show only these.', source],
          ),
        ),
      _packersCard(context, source),
      _rideHeightCard(context, source),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < cards.length; i++)
          StaggeredEntrance(index: i, child: cards[i]),
      ],
    );
  }

  static String _phaseSubtitle(
    StrikePhase p,
    int kerbs,
    Iterable<Strike> thisLap,
  ) {
    final n = thisLap.length;
    final kerb = kerbs == 0 ? '' : ' · $kerbs on kerbs';
    return '$n this lap$kerb';
  }

  Widget _packersCard(BuildContext context, String source) {
    final p = overview.platformOf(lap);
    final c = overview.ceilings;
    if (!overview.hasThirdElement) {
      return _GlanceCard(
        glyph: SuspensionGlyphKind.packers,
        title: 'Packers',
        value: '—',
        subtitle: 'This car has no third element.',
        info: (
          title: 'Packers',
          paragraphs: [
            'Prototypes have a third element (a heave spring) between the '
                'wheels of each axle, resting on packers at speed. This car\'s '
                'setup has none, so there is nothing to measure.',
            'GT3 recordings carry the third-element channels anyway, with '
                'junk in them (up to 87 mm), so the setup decides.',
          ],
          footer: const [],
        ),
      );
    }
    return _GlanceCard(
      glyph: SuspensionGlyphKind.packers,
      title: 'Packers',
      valueWidget: _Pair(
        front: p?.frontPackers,
        rear: p?.rearPackers,
        format: (v) => '${(v * 100).round()}',
        unit: '%',
      ),
      subtitle:
          'On the packers above ${platformSpeedKph.round()} km/h: '
          'normal on the straights.',
      info: (
        title: 'Packer contact',
        paragraphs: [
          'The third element resting on its packers. At speed the aero load '
              'pushes the car down until the packers take it: normal on the '
              'straights, a limit if it happens in corners.',
          'Contact is within ${(packerMarginMetres * 1000).toStringAsFixed(1)} '
              'mm of the session\'s ceiling: front '
              '${c.front == null ? '—' : mm(c.front!, digits: 2)} mm, rear '
              '${c.rear == null ? '—' : mm(c.rear!, digits: 2)} mm. On the '
              'Alpine the ceiling repeats to ±0.03 mm across 30 files.',
        ],
        footer: [source],
      ),
    );
  }

  Widget _rideHeightCard(BuildContext context, String source) {
    final p = overview.platformOf(lap);
    final lowF = p?.frontLowest;
    final lowR = p?.rearLowest;
    return _GlanceCard(
      glyph: SuspensionGlyphKind.rideHeight,
      title: 'Ride height',
      valueWidget: _Pair(
        front: p?.frontMedian,
        rear: p?.rearMedian,
        format: (v) => (v * 1000).toStringAsFixed(0),
        unit: 'mm',
      ),
      subtitle: lowF == null || lowR == null
          ? 'Median above ${platformSpeedKph.round()} km/h'
          : 'Lowest F ${mm(lowF)} · R ${mm(lowR)} mm',
      info: (
        title: 'Ride height',
        paragraphs: [
          'The median of each axle\'s two corners above '
              '${platformSpeedKph.round()} km/h on this lap, and below it the '
              'lowest any corner went.',
          'Corner ride heights are measured at the corners. On a crowned '
              'straight the plank in the middle can touch first while every '
              'corner still reads 17 mm or more: on your Le Mans test, within '
              '1 m of the centre line the front sat about 4 mm lower and the '
              'plank ground.',
          'Fuel moves it too: a full tank sat the rear about 1.4 mm lower at '
              '120–180 km/h on your Le Mans race, but only 0.25 mm above 290 '
              'km/h, where the car is on its packers.',
        ],
        footer: ['Measured on your Le Mans race and test, Oct–Nov 2026.'],
      ),
    );
  }
}

typedef _Info = ({String title, List<String> paragraphs, List<String> footer});

class _GlanceCard extends StatelessWidget {
  const _GlanceCard({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.info,
    this.value,
    this.unit,
    this.valueWidget,
    this.selected = false,
    this.onTap,
  });

  final SuspensionGlyphKind glyph;
  final String title;
  final String? value;
  final String? unit;
  final Widget? valueWidget;
  final String subtitle;
  final _Info info;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final body = SquircleCard(
      border: selected ? AppGradients.hairlineStrong : null,
      color: selected ? AppColors.surfaceHighest : null,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SuspensionGlyph(
                glyph,
                size: 18,
                color: selected ? scheme.primary : muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
              InfoPopoverButton(
                title: info.title,
                paragraphs: info.paragraphs,
                footer: info.footer,
              ),
            ],
          ),
          const SizedBox(height: 4),
          valueWidget ??
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  if (double.tryParse(value ?? '') case final n?)
                    RollingNumber(
                      value: n,
                      format: (v) => v.round().toString(),
                      style: AppTextStyles.numeral.copyWith(fontSize: 26),
                    )
                  else
                    Text(
                      value ?? '',
                      style: AppTextStyles.numeral.copyWith(fontSize: 26),
                    ),
                  if (unit != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      unit!,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FadeOnChange(
              value: subtitle,
              duration: AppMotion.duration(context, AppDurations.fast),
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ),
        ],
      ),
    );
    final sized = SizedBox(width: 214, height: 132, child: body);
    final tap = onTap;
    if (tap == null) return sized;
    return Hoverable(
      radius: AppRadii.lg,
      onTap: tap,
      semanticLabel: '$title: show only these',
      child: sized,
    );
  }
}

/// "F 28 · R 37 %" with each number rolling.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.front,
    required this.rear,
    required this.format,
    required this.unit,
  });

  final double? front;
  final double? rear;
  final String Function(double) format;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final label = theme.textTheme.bodySmall?.copyWith(color: muted);
    const big = TextStyle(fontSize: 24);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('F ', style: label),
        RollingNumber(value: front, format: format, style: big),
        const SizedBox(width: 10),
        Text('R ', style: label),
        RollingNumber(value: rear, format: format, style: big),
        const SizedBox(width: 6),
        Text(unit, style: label),
      ],
    );
  }
}
