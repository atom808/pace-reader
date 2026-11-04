/// The site view (suspension proposal §4.4), the core of the screen: the
/// verdict in one sentence, the road ribbon with every lap's line, the trace
/// stack on the site's distance axis, and the evidence one click away.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../../setup_viewer/application/car_setup.dart';
import '../application/suspension_providers.dart';
import '../data/suspension_repository.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';
import 'site_charts.dart';
import 'suspension_glyphs.dart';
import 'suspension_text.dart';

class SiteView extends HookConsumerWidget {
  const SiteView({
    super.key,
    required this.source,
    required this.overview,
    required this.site,
    required this.lap,
    required this.placeName,
    required this.evidence,
    required this.onToggleEvidence,
    required this.onOpenInTrace,
  });

  final TelemetrySource source;
  final SuspensionOverview overview;
  final Site site;
  final int lap;
  final String? placeName;
  final bool evidence;
  final VoidCallback onToggleEvidence;
  final VoidCallback onOpenInTrace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final verdict = overview.verdicts[site.key];
    final traces = ref.watch(siteTracesProvider(source, site.key));
    final fade = AppMotion.duration(context, AppDurations.medium);
    final sentence = verdict == null
        ? null
        : verdictSentence(site, verdict, racingLaps: overview.racingLapCount);
    final low = site.lapLows[lap];
    final phases = site.phases.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return SquircleCard(
      border: AppGradients.hairlineStrong,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SuspensionGlyph(
                SuspensionGlyphKind.strike,
                size: 22,
                color: scheme.primary,
              ),
              FadeOnChange(
                value: site.key,
                duration: fade,
                child: Text(
                  '${metres(site.place)} ± ${siteWindowMetres.round()} m'
                  '${placeName == null ? '' : ' · $placeName'}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final p in phases)
                _Tag(
                  glyph: SuspensionGlyphKind.ofPhase(p),
                  label: '${p.label} ${site.phases[p]}',
                  tip: p.meaning,
                ),
              if (site.isKerb)
                _Tag(
                  glyph: SuspensionGlyphKind.kerb,
                  label: 'Kerb',
                  tip:
                      '${surfaceMeaning(StrikeSurface.kerb, site.phase)} '
                      '$surfaceSource',
                ),
              _Tag(
                glyph: SuspensionGlyphKind.rideHeight,
                label:
                    '${site.corner.short} · ${mm(site.medianDepth)} mm median',
                tip:
                    'The ${site.corner.label.toLowerCase()} went lowest here '
                    'most often. Median of each lap\'s deepest: '
                    '${mm(site.medianDepth)} mm; deepest '
                    '${mm(site.deepest)} mm.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (verdict != null && sentence != null)
            FadeOnChange(
              value: (site.key, verdict.kind),
              duration: fade,
              child: _Verdict(
                verdict: verdict,
                sentence: sentence.sentence,
                suggestion: sentence.suggestion,
                lapLow: low,
                lap: lap,
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                style: AppButtonStyles.secondary(context),
                onPressed: onToggleEvidence,
                icon: AnimatedRotation(
                  turns: evidence ? 0.5 : 0,
                  duration: fade,
                  child: const Icon(Icons.expand_more, size: 18),
                ),
                label: Text(evidence ? 'Hide evidence' : 'Evidence'),
              ),
              AppTooltip(
                message:
                    'Opens this lap in Trace with the car on this site '
                    '(Ctrl+Enter).',
                child: TextButton.icon(
                  style: AppButtonStyles.secondary(context),
                  onPressed: onOpenInTrace,
                  icon: const Icon(Icons.show_chart, size: 18),
                  label: const Text('Open in Trace'),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: fade,
            curve: AppCurves.standard,
            alignment: Alignment.topCenter,
            child: evidence && verdict != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _Evidence(
                      overview: overview,
                      site: site,
                      verdict: verdict,
                      lap: lap,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          AsyncValueView<List<SiteTrace>>(
            value: traces,
            loading: (context) => const Column(
              children: [
                Skeleton(height: 120, radius: AppRadii.md),
                SizedBox(height: 12),
                Skeleton(height: 260, radius: AppRadii.md),
              ],
            ),
            data: (context, traces) {
              if (traces.isEmpty) {
                return const AbsenceNote(
                  'No lap passed through this window above the speed floor.',
                );
              }
              return _SiteCharts(
                source: source,
                overview: overview,
                site: site,
                verdict: verdict,
                lap: lap,
                traces: traces,
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '${sessionSource(overview.racingLapCount)} Selected lap solid, '
            'cleanest comparable lap dashed, the session\'s middle 80 % '
            'shaded.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.glyph, required this.label, required this.tip});

  final SuspensionGlyphKind glyph;
  final String label;
  final String tip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppTooltip(
      message: tip,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(10),
          color: scheme.onSurface.withValues(alpha: 0.06),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SuspensionGlyph(glyph, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.verdict,
    required this.sentence,
    required this.suggestion,
    required this.lapLow,
    required this.lap,
  });

  final SiteVerdict verdict;
  final String sentence;
  final String suggestion;
  final Strike? lapLow;
  final int lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final cleanest = verdict.cleanest;
    final low = lapLow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTooltip(
          message: verdictMeaning(verdict.kind),
          child: Container(
            constraints: const BoxConstraints(minWidth: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: ShapeDecoration(
              shape: AppRadii.squircle(AppRadii.sm),
              color: AppColors.surfaceHighest,
            ),
            child: Column(
              children: [
                if (verdict.kind == VerdictKind.line)
                  SuspensionGlyph(
                    SuspensionGlyphKind.line,
                    size: 18,
                    color: scheme.primary,
                  )
                else if (verdict.kind == VerdictKind.kerb)
                  SuspensionGlyph(
                    SuspensionGlyphKind.kerb,
                    size: 18,
                    color: scheme.primary,
                  )
                else
                  SuspensionGlyph(
                    SuspensionGlyphKind.coilover,
                    size: 18,
                    color: verdict.kind.pointsAtSetup ? scheme.primary : muted,
                  ),
                const SizedBox(height: 4),
                Text(
                  verdict.kind.word.toUpperCase(),
                  style: AppTextStyles.numeral.copyWith(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sentence, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                suggestion,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  low == null
                      ? 'This lap did not strike here'
                      : 'This lap: ${mm(low.depth)} mm at '
                            '${low.speed?.round() ?? '—'} km/h, '
                            '${low.phase.label.toLowerCase()}, '
                            '${low.surface.label.toLowerCase()}',
                  if (cleanest != null && cleanest != lap)
                    'cleanest comparable lap: ${cleanest + 1}',
                ].join(' · '),
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 11.5,
                  color: muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The fit behind the verdict: depth against line and against speed, lap by
/// lap, and the setup values that bear on it — the "setup thing" side.
class _Evidence extends StatelessWidget {
  const _Evidence({
    required this.overview,
    required this.site,
    required this.verdict,
    required this.lap,
  });

  final SuspensionOverview overview;
  final Site site;
  final SiteVerdict verdict;
  final int lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final struck = site.struckLaps;
    List<(double, double, bool, bool)> points(double? Function(SiteLapLow) x) =>
        [
          for (final l in verdict.lows)
            if (x(l) case final v?)
              (v, l.depth * 1000, struck.contains(l.lap), l.lap == lap),
        ];
    Widget scatter(
      String title,
      String axis,
      double? r,
      double? slope,
      String slopeUnit,
      List<(double, double, bool, bool)> pts,
    ) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          Text(
            r == null
                ? 'no fit'
                : 'r = ${r.toStringAsFixed(2)} · '
                      '${slope!.toStringAsFixed(1)} $slopeUnit',
            style: AppTextStyles.numeral.copyWith(fontSize: 11.5, color: muted),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 150,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: ScatterPainter(
                  points: pts,
                  ink: scheme.onSurface,
                  muted: muted,
                  accent: scheme.primary,
                  slope: slope == null ? null : slope / _xScale(axis),
                  floor: strikeFloorMetres * 1000,
                ),
              ),
            ),
          ),
          Text(axis, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );

    final setup = overview.setup;
    final settings =
        setup?.axleSuspension(front: site.isFront) ?? const <SetupSetting>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            scatter(
              'Depth against line',
              'Line at the lowest point, m (+ right of centre)',
              verdict.lineR,
              verdict.lineSlope,
              'mm per m',
              points((l) => l.line),
            ),
            const SizedBox(width: 20),
            scatter(
              'Depth against speed',
              'Speed at the lowest point, km/h',
              verdict.speedR,
              verdict.speedSlope,
              'mm per 10 km/h',
              points((l) => l.speed),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Each dot is a lap: filled struck, hollow clean, the selected lap '
          'in colour. Depth is the ${site.corner.label.toLowerCase()}\'s lowest '
          'within ${siteSearchMetres.round()} m of the site; the dashed rule '
          'is the ${mm(strikeFloorMetres, digits: 0)} mm floor.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SuspensionGlyph(
              SuspensionGlyphKind.coilover,
              size: 16,
              color: muted,
            ),
            const SizedBox(width: 8),
            Text(
              'The ${axleWord(site.corner)} setup',
              style: theme.textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (settings.isEmpty)
          const AbsenceNote('The recording carries no setup to show.')
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in settings)
                DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: AppRadii.squircle(10),
                    color: scheme.onSurface.withValues(alpha: 0.05),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: s.corner == null
                                ? '${s.label}  '
                                : '${s.label} ${s.corner!.code}  ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                          TextSpan(
                            text: s.display,
                            style: AppTextStyles.numeral.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// The verdict's speed slope is per 10 km/h; the scatter's x is km/h.
  static double _xScale(String axis) => axis.contains('km/h') ? 10 : 1;
}

/// A trace panel's definition.
class _Panel {
  const _Panel({
    required this.label,
    required this.unit,
    required this.channels,
    required this.colors,
    this.scale = 1,
    this.rules = const [],
    this.digits = 0,
    this.tip,
  });

  final String label;
  final String unit;
  final List<SiteChannel> channels;
  final List<Color> colors;
  final double scale;
  final List<PanelRule> rules;
  final int digits;
  final String? tip;
}

class _SiteCharts extends HookConsumerWidget {
  const _SiteCharts({
    required this.source,
    required this.overview,
    required this.site,
    required this.verdict,
    required this.lap,
    required this.traces,
  });

  final TelemetrySource source;
  final SuspensionOverview overview;
  final Site site;
  final SiteVerdict? verdict;
  final int lap;
  final List<SiteTrace> traces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final colors = ChannelColors.resolve(context);
    final series = useMemoized(
      () => SiteSeries.of(traces, site.start, site.end),
      [traces, site.key],
    );
    final hover = ref.watch(suspensionHoverStateProvider(source));
    final hoverNotifier = ref.read(
      suspensionHoverStateProvider(source).notifier,
    );

    // The ribbon unrolls from the centre whenever the site changes.
    final unroll = useAnimationController(
      duration: AppMotion.duration(context, const Duration(milliseconds: 450)),
    );
    useEffect(() {
      if (AppMotion.reduced(context)) {
        unroll.value = 1;
      } else {
        unroll.forward(from: 0);
      }
      return null;
    }, [site.key]);

    // Lines morph from the last lap shown to this one, bin for bin.
    final previousLap = useRef<int?>(null);
    final morph = useAnimationController(
      duration: AppMotion.duration(context, AppDurations.slow),
    );
    final from = useRef<int?>(null);
    useEffect(() {
      from.value = previousLap.value;
      previousLap.value = lap;
      if (AppMotion.reduced(context) || from.value == null) {
        morph.value = 1;
      } else {
        morph.forward(from: 0);
      }
      return null;
    }, [lap]);

    final cleanest = verdict?.cleanest;
    final corner = site.corner;
    final axleFront = corner.isFront;
    final ceiling = axleFront
        ? overview.ceilings.front
        : overview.ceilings.rear;
    final panels = <_Panel>[
      _Panel(
        label: 'Ride height ${corner.short}',
        unit: 'mm',
        channels: [SiteChannel.ride(corner)],
        colors: [scheme.onSurface],
        scale: 1000,
        digits: 1,
        rules: [
          PanelRule(strikeFloorMetres * 1000, 'floor'),
          PanelRule((strikeFloorMetres + closeBandMetres) * 1000, 'close'),
        ],
        tip:
            'The ${corner.label.toLowerCase()} corner\'s ride height. Under '
            'the floor is a strike; between the floor and the close line, '
            'close. $floorNote',
      ),
      _Panel(
        label: 'Speed',
        unit: 'km/h',
        channels: const [SiteChannel.speed],
        colors: [colors.speed],
      ),
      _Panel(
        label: 'Brake · throttle',
        unit: '%',
        channels: const [SiteChannel.brake, SiteChannel.throttle],
        colors: [colors.brake, colors.throttle],
      ),
      _Panel(
        label: 'Line',
        unit: 'm',
        channels: const [SiteChannel.line],
        colors: [colors.line],
        digits: 1,
        rules: const [PanelRule(0, 'centre')],
        tip:
            'Path Lateral: where on the road the car was, + right of the '
            'centre line. Lines vary by 0.8–1.0 m across laps at the Le Mans '
            'sites; how finely Path Lateral resolves under that is not yet '
            'established.',
      ),
      _Panel(
        label: 'Steering',
        unit: '',
        channels: const [SiteChannel.steering],
        colors: [colors.steering],
      ),
      _Panel(
        label: 'Lateral G',
        unit: 'G',
        channels: const [SiteChannel.lateralG],
        colors: [colors.steering],
        digits: 2,
        rules: const [PanelRule(0, '', dashed: false)],
      ),
      _Panel(
        label: 'Vertical G',
        unit: 'G',
        channels: const [SiteChannel.verticalG],
        colors: [scheme.onSurface.withValues(alpha: 0.8)],
        digits: 2,
        tip:
            'A spike at the lowest point is the floor meeting the road: it '
            'confirms a real contact.',
      ),
      _Panel(
        label: 'Travel ${corner.short}',
        unit: 'mm',
        channels: [SiteChannel.travel(corner)],
        colors: [scheme.onSurface.withValues(alpha: 0.8)],
        scale: 1000,
        digits: 1,
        tip: 'Suspension travel, compression positive.',
      ),
      if (overview.hasThirdElement)
        _Panel(
          label: '${axleFront ? 'Front' : 'Rear'} 3rd',
          unit: 'mm',
          channels: [
            axleFront ? SiteChannel.frontThird : SiteChannel.rearThird,
          ],
          colors: [scheme.onSurface.withValues(alpha: 0.8)],
          scale: 1000,
          digits: 2,
          rules: [if (ceiling != null) PanelRule(ceiling * 1000, 'packers')],
          tip:
              'The third element\'s deflection. At the packers line it is '
              'resting on its packers.',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final shown = narrow
            ? [panels[0], panels[1], panels[2], panels[3]]
            : panels;
        final n = series.length;
        final cursorBin = hover.metre == null
            ? null
            : (hover.metre! - series.start).clamp(0, n - 1).toDouble();
        final centreBin = (site.place - series.start).toDouble();
        const labelWidth = 116.0;

        void track(Offset local, double width, {int? lap}) {
          final f = ((local.dx) / width).clamp(0.0, 1.0);
          hoverNotifier.cursor(series.start + f * (n - 1), lap: lap);
        }

        return AnimatedBuilder(
          animation: Listenable.merge([unroll, morph]),
          builder: (context, _) {
            final t = AppCurves.entrance.transform(morph.value);
            Float64List? lapLine(SiteChannel c, int l, double scale) {
              final v = series.of(l, c);
              if (v == null) return null;
              return scale == 1
                  ? v
                  : Float64List.fromList([for (final x in v) x * scale]);
            }

            Float64List? morphed(SiteChannel c, double scale) {
              final now = lapLine(c, lap, scale);
              if (now == null) return null;
              final was = from.value == null
                  ? null
                  : lapLine(c, from.value!, scale);
              return lerpSeries(was, now, t);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RibbonBlock(
                  series: series,
                  site: site,
                  verdict: verdict,
                  lap: lap,
                  cleanest: cleanest,
                  raised: hover.lap,
                  reveal: AppCurves.entrance.transform(unroll.value),
                  cursor: cursorBin,
                  centre: centreBin,
                  labelWidth: labelWidth,
                  onHover: (local, width, lap) => track(local, width, lap: lap),
                  onExit: () => hoverNotifier.cursor(null),
                ),
                const SizedBox(height: 10),
                for (final p in shown)
                  _PanelRow(
                    panel: p,
                    labelWidth: labelWidth,
                    cursorBin: cursorBin,
                    readout: cursorBin == null
                        ? null
                        : [
                            for (final c in p.channels)
                              series.of(lap, c)?[cursorBin.round()],
                          ],
                    painter: () {
                      final (lo, hi) = series.band(p.channels.first);
                      var (y0, y1) = series.range(p.channels.first);
                      for (final c in p.channels.skip(1)) {
                        final (a, b) = series.range(c);
                        y0 = math.min(y0, a);
                        y1 = math.max(y1, b);
                      }
                      for (final r in p.rules) {
                        y0 = math.min(y0, r.value / p.scale);
                        y1 = math.max(y1, r.value / p.scale);
                      }
                      final lines = <PanelLine>[];
                      for (final (k, c) in p.channels.indexed) {
                        final color = p.colors[k];
                        if (cleanest != null && cleanest != lap) {
                          if (lapLine(c, cleanest, p.scale) case final v?) {
                            lines.add(
                              PanelLine(
                                v,
                                color: color.withValues(alpha: 0.75),
                                width: 1.3,
                                dashed: true,
                              ),
                            );
                          }
                        }
                        if (morphed(c, p.scale) case final v?) {
                          lines.add(PanelLine(v, color: color, width: 1.8));
                        }
                      }
                      Float64List scaled(Float64List v) => p.scale == 1
                          ? v
                          : Float64List.fromList([
                              for (final x in v) x * p.scale,
                            ]);
                      return TracePanelPainter(
                        lines: lines,
                        yMin: y0 * p.scale,
                        yMax: y1 * p.scale,
                        ink: scheme.onSurface,
                        muted: muted,
                        band: (scaled(lo), scaled(hi)),
                        bandColor: p.colors.first,
                        rules: p.rules,
                        cursor: cursorBin,
                        centre: centreBin,
                      );
                    },
                    onHover: (local, width) => track(local, width),
                    onExit: () => hoverNotifier.cursor(null),
                  ),
                if (narrow)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Narrow window: the four panels that decide the verdict. '
                      'Widen it for steering, G, travel and the third element.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    required this.panel,
    required this.labelWidth,
    required this.cursorBin,
    required this.readout,
    required this.painter,
    required this.onHover,
    required this.onExit,
  });

  final _Panel panel;
  final double labelWidth;
  final double? cursorBin;
  final List<double?>? readout;
  final TracePanelPainter Function() painter;
  final void Function(Offset local, double width) onHover;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final values = readout;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          panel.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        Text(
          values == null
              ? panel.unit
              : [
                      for (final v in values)
                        v == null || v.isNaN
                            ? '—'
                            : (v * panel.scale).toStringAsFixed(panel.digits),
                    ].join(' · ') +
                    (panel.unit.isEmpty ? '' : ' ${panel.unit}'),
          style: AppTextStyles.numeral.copyWith(fontSize: 11, color: muted),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            SizedBox(
              width: labelWidth,
              child: panel.tip == null
                  ? label
                  : AppTooltip(message: panel.tip!, child: label),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => MouseRegion(
                  onHover: (e) => onHover(e.localPosition, c.maxWidth),
                  onExit: (_) => onExit(),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: AppRadii.squircle(10),
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.025,
                      ),
                    ),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(c.maxWidth, 62),
                        painter: painter(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonBlock extends StatelessWidget {
  const _RibbonBlock({
    required this.series,
    required this.site,
    required this.verdict,
    required this.lap,
    required this.cleanest,
    required this.raised,
    required this.reveal,
    required this.cursor,
    required this.centre,
    required this.labelWidth,
    required this.onHover,
    required this.onExit,
  });

  final SiteSeries series;
  final Site site;
  final SiteVerdict? verdict;
  final int lap;
  final int? cleanest;
  final int? raised;
  final double reveal;
  final double? cursor;
  final double centre;
  final double labelWidth;
  final void Function(Offset local, double width, int? lap) onHover;
  final VoidCallback onExit;

  static const height = 132.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final struck = site.struckLaps;
    final lows = {
      for (final l in verdict?.lows ?? const <SiteLapLow>[]) l.lap: l,
    };
    final laps = [
      for (final l in series.laps)
        if (series.of(l, SiteChannel.line) case final line?)
          RibbonLap(
            lap: l,
            line: line,
            struck: struck.contains(l),
            lowIndex: lows[l]?.station == null
                ? null
                : lows[l]!.station! - series.start,
            lowDepth: lows[l]?.depth,
          ),
    ];
    final (lo, hi) = series.range(SiteChannel.line, pad: 0.12);
    final spread = hi - lo;
    // A scale bar: how tall a metre is on this ribbon.
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            SuspensionGlyph(SuspensionGlyphKind.line, size: 15, color: muted),
            const SizedBox(width: 6),
            Text('Road', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${spread.toStringAsFixed(1)} m across\n'
          '${(siteWindowMetres * 2).round()} m along',
          style: AppTextStyles.numeral.copyWith(fontSize: 10.5, color: muted),
        ),
      ],
    );
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: AppTooltip(
              message:
                  'The site straightened: distance along, where on the road '
                  'across, with the sideways scale stretched so a 1 m '
                  'difference in line shows. Struck laps in ink, clean laps '
                  'faint, ✕ at each lap\'s lowest point (bigger is deeper). '
                  'Hover a line to raise it.',
              child: label,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                int? nearest(Offset local) {
                  final n = series.length;
                  final i = ((local.dx / c.maxWidth) * (n - 1)).round().clamp(
                    0,
                    n - 1,
                  );
                  const top = 14.0;
                  final h = height - top - 18;
                  int? best;
                  var bestD = 12.0;
                  for (final l in laps) {
                    final v = l.line[i];
                    if (v.isNaN) continue;
                    final y = top + (v - lo) / (hi - lo) * h;
                    final d = (y - local.dy).abs();
                    if (d < bestD) {
                      bestD = d;
                      best = l.lap;
                    }
                  }
                  return best;
                }

                return MouseRegion(
                  onHover: (e) => onHover(
                    e.localPosition,
                    c.maxWidth,
                    nearest(e.localPosition),
                  ),
                  onExit: (_) => onExit(),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size(c.maxWidth, height),
                      painter: RibbonPainter(
                        laps: laps,
                        selected: lap,
                        cleanest: cleanest,
                        raised: raised,
                        lateralMin: lo,
                        lateralMax: hi,
                        ink: scheme.onSurface,
                        muted: muted,
                        accent: scheme.primary,
                        reveal: reveal,
                        cursor: cursor,
                        centre: centre,
                        floor: strikeFloorMetres,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// [corner]'s short name for a sentence.
String cornerName(Corner corner) => corner.label.toLowerCase();
