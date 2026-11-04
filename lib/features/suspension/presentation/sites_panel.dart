/// The track map with its site glyphs, and the sites list (suspension
/// proposal §4.3). A site row, its glyph and the site view light together.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driving_technique/application/technique_providers.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../application/suspension_providers.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';
import 'suspension_glyphs.dart';
import 'suspension_text.dart';

/// The name of the place [station] is in: the segment's, from Technique's
/// course, else nothing.
String? placeName(TechniqueCourse? course, double station) {
  for (final s in course?.segments ?? const []) {
    if (s.contains(station)) return s.name;
  }
  return null;
}

bool _shown(Site site, StrikePhase? filter) =>
    filter == null || site.phases.keys.any((p) => phaseMatches(filter, p));

class SiteMapPanel extends ConsumerWidget {
  const SiteMapPanel({
    super.key,
    required this.source,
    required this.overview,
    required this.selected,
    required this.filter,
    required this.onSelect,
  });

  final TelemetrySource source;
  final SuspensionOverview overview;
  final int? selected;
  final StrikePhase? filter;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(techniqueCourseProvider(source));
    final hovered = ref.watch(
      suspensionHoverStateProvider(source).select((h) => h.siteKey),
    );
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Where it touches down',
            caption: 'Glyph shape is the phase, size the laps struck',
            trailing: InfoPopoverButton(
              title: 'Reading the map',
              paragraphs: [
                'Each glyph is a site: a place strikes from two or more laps '
                    'fall within 25 m of each other. Its shape says when it '
                    'happened (straight, braking, corner, or braking into a '
                    'corner), its size how many laps struck there.',
                'Solid glyphs went under the floor; faint ones only came '
                    'close. Click one to open it below.',
              ],
              footer: [sessionSource(overview.racingLapCount)],
            ),
          ),
          AsyncValueView<TechniqueCourse>(
            value: course,
            loading: (context) => const AspectRatio(
              aspectRatio: 1.7,
              child: Skeleton(height: double.infinity, radius: AppRadii.md),
            ),
            data: (context, course) {
              final map = course.map;
              if (map == null) {
                return AbsenceNote(
                  course.unavailable ??
                      'No map: the recording lacks the position channels.',
                );
              }
              return _SiteMap(
                source: source,
                map: map,
                sites: overview.sites,
                selected: selected,
                hovered: hovered,
                filter: filter,
                racingLaps: overview.racingLapCount,
                onSelect: onSelect,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The road on the inset map stage (map stage proposal §9), each site a
/// glyph pinned where it is: its shape the phase, its size the laps that
/// struck. A drag pans, Ctrl+scroll zooms, and the glyphs keep their size.
class _SiteMap extends ConsumerWidget {
  const _SiteMap({
    required this.source,
    required this.map,
    required this.sites,
    required this.selected,
    required this.hovered,
    required this.filter,
    required this.racingLaps,
    required this.onSelect,
  });

  final TelemetrySource source;
  final TrackPath map;
  final List<Site> sites;
  final int? selected;
  final int? hovered;
  final StrikePhase? filter;
  final int racingLaps;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final hover = ref.read(suspensionHoverStateProvider(source).notifier);
    final bounds = map.projection.boundsMetres;
    final aspect = bounds.height <= 0
        ? 1.6
        : (bounds.width / bounds.height).clamp(0.9, 2.2);
    final most = sites.fold(
      1,
      (m, s) => s.lapLows.length > m ? s.lapLows.length : m,
    );
    // Largest first, so the drop-in reads as the worst landing first.
    final order = [...sites]
      ..sort((a, b) => b.lapLows.length.compareTo(a.lapLows.length));
    final fast = AppMotion.duration(context, AppDurations.medium);
    final focus = sites.where((s) => s.key == selected).firstOrNull;
    final ink = scheme.onSurface;

    StagePin? pin(int rank, Site site) {
      final at = map.positionAtStation(site.place);
      if (at == null) return null;
      final glyph = 14 + 12 * (site.lapLows.length / most);
      final shown = _shown(site, filter);
      final isSelected = site.key == selected;
      final lit = isSelected || site.key == hovered;
      final strike = site.tier == StrikeTier.strike;
      final colour = isSelected
          ? scheme.primary
          : ink.withValues(alpha: strike ? (lit ? 1 : 0.86) : 0.42);
      return StagePin(
        key: ValueKey(site.key),
        at: at,
        size: glyph + 14,
        child: StaggeredEntrance(
          index: rank,
          rise: 14,
          child: AnimatedScale(
            scale: shown ? (lit ? 1.15 : 1) : 0,
            duration: fast,
            curve: AppCurves.entrance,
            child: AppTooltip(
              message:
                  '${metres(site.place)} · ${site.phase.label}'
                  ' · ${site.struckLaps.length} of $racingLaps '
                  'laps struck · ${axleWord(site.corner)}',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => hover.site(site.key),
                onExit: (_) => hover.site(null),
                child: GestureDetector(
                  onTap: () => onSelect(site.key),
                  child: AnimatedContainer(
                    duration: fast,
                    curve: AppCurves.standard,
                    decoration: ShapeDecoration(
                      shape: CircleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? scheme.primary
                              : const Color(0x00000000),
                          width: 2,
                        ),
                      ),
                      color: AppColors.surfaceHigh.withValues(
                        alpha: lit ? 0.95 : 0.8,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: SuspensionGlyph(
                      SuspensionGlyphKind.ofPhase(site.phase),
                      size: glyph,
                      color: colour,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // A portrait circuit (Le Mans) at full width would stand taller than the
    // screen: the height is capped and the map centred in what is left.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: AspectRatio(
          aspectRatio: aspect,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: MapStage.inset(
              path: map,
              colouring: SolidColouring(ink.withValues(alpha: 0.22)),
              strokeWidth: 5,
              overlays: [
                // The selected site's window, lifted along the road.
                if (focus != null)
                  StretchCasingLayer(
                    path: map,
                    from: focus.start,
                    to: focus.end,
                    colour: ink.withValues(alpha: 0.7),
                    width: 5,
                    margin: 0,
                  ),
              ],
              pins: [
                for (final (rank, site) in order.indexed) ?pin(rank, site),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SitesList extends ConsumerWidget {
  const SitesList({
    super.key,
    required this.source,
    required this.overview,
    required this.selected,
    required this.filter,
    required this.onSelect,
  });

  final TelemetrySource source;
  final SuspensionOverview overview;
  final int? selected;
  final StrikePhase? filter;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final course = ref.watch(techniqueCourseProvider(source)).value;
    final hovered = ref.watch(
      suspensionHoverStateProvider(source).select((h) => h.siteKey),
    );
    final hover = ref.read(suspensionHoverStateProvider(source).notifier);
    final shown = [
      for (final s in overview.sites)
        if (_shown(s, filter)) s,
    ];
    final offTrack = overview.strikes
        .where((s) => s.surface == StrikeSurface.offTrack)
        .length;
    return SquircleCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Sites',
            caption: filter == null
                ? 'Most laps struck first'
                : 'Showing ${filter!.label.toLowerCase()} only',
            trailing: InfoPopoverButton(
              title: 'The verdict word',
              paragraphs: [
                for (final k in VerdictKind.values) verdictMeaning(k),
              ],
              footer: [
                'A verdict says what goes with depth across your laps, not '
                    'what causes it.',
              ],
            ),
          ),
          AnimatedSize(
            duration: AppMotion.duration(context, AppDurations.medium),
            curve: AppCurves.standard,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shown.isEmpty)
                  AbsenceNote(
                    overview.sites.isEmpty
                        ? 'No site: no place was struck on two or more laps. '
                              '${overview.headline.length} strike'
                              '${overview.headline.length == 1 ? '' : 's'} in '
                              'all, each on its own.'
                        : 'No site in this phase. Click the card again to '
                              'show every site.',
                  ),
                for (final site in shown)
                  _SiteRow(
                    key: ValueKey(site.key),
                    site: site,
                    verdict: overview.verdicts[site.key],
                    name: placeName(course, site.place),
                    racingLaps: overview.racingLapCount,
                    selected: site.key == selected,
                    hovered: site.key == hovered,
                    onTap: () => onSelect(site.key),
                    onHover: (on) => hover.site(on ? site.key : null),
                  ),
                if (offTrack > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: AbsenceNote(
                      '$offTrack strike${offTrack == 1 ? '' : 's'} off track '
                      '(grass or gravel) left out of sites and verdicts.',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({
    super.key,
    required this.site,
    required this.verdict,
    required this.name,
    required this.racingLaps,
    required this.selected,
    required this.hovered,
    required this.onTap,
    required this.onHover,
  });

  final Site site;
  final SiteVerdict? verdict;
  final String? name;
  final int racingLaps;
  final bool selected;
  final bool hovered;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final strike = site.tier == StrikeTier.strike;
    final ink = scheme.onSurface.withValues(alpha: strike ? 1 : 0.55);
    final fast = AppMotion.duration(context, AppDurations.fast);
    final phases = site.phases.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final v = verdict;
    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Hoverable(
        radius: AppRadii.sm,
        onTap: onTap,
        semanticLabel: 'Site at ${metres(site.place)}',
        child: AnimatedContainer(
          duration: fast,
          curve: AppCurves.standard,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: ShapeDecoration(
            shape: AppRadii.squircle(AppRadii.sm),
            color: selected
                ? AppColors.surfaceHighest
                : hovered
                ? scheme.onSurface.withValues(alpha: 0.05)
                : const Color(0x00000000),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: fast,
                width: 8,
                height: 8,
                decoration: ShapeDecoration(
                  shape: const CircleBorder(),
                  color: selected
                      ? scheme.primary
                      : ink.withValues(alpha: strike ? 0.8 : 0.35),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          metres(site.place),
                          style: AppTextStyles.numeral.copyWith(
                            fontSize: 13,
                            color: ink,
                          ),
                        ),
                        if (name != null) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              name!,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        for (final p in phases)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: AppTooltip(
                              message:
                                  '${p.label}: ${site.phases[p]} lap'
                                  '${site.phases[p] == 1 ? '' : 's'}',
                              child: SuspensionGlyph(
                                SuspensionGlyphKind.ofPhase(p),
                                size: 15,
                                color: muted,
                              ),
                            ),
                          ),
                        if (site.isKerb)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: AppTooltip(
                              message: surfaceMeaning(
                                StrikeSurface.kerb,
                                site.phase,
                              ),
                              child: SuspensionGlyph(
                                SuspensionGlyphKind.kerb,
                                size: 15,
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${site.struckLaps.length}/$racingLaps struck',
                        if (site.closeLaps.isNotEmpty)
                          '${site.closeLaps.length} close',
                        axleWord(site.corner),
                        '${mm(site.medianDepth)} mm median',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (v != null) _VerdictChip(kind: v.kind),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.kind});

  final VerdictKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strong =
        kind != VerdictKind.notClear && kind != VerdictKind.tooFewLaps;
    return AppTooltip(
      message: verdictMeaning(kind),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(10),
          color: scheme.onSurface.withValues(alpha: strong ? 0.09 : 0.04),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == VerdictKind.line) ...[
                SuspensionGlyph(
                  SuspensionGlyphKind.line,
                  size: 12,
                  color: scheme.onSurface,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                kind.word.toUpperCase(),
                style: AppTextStyles.numeral.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  color: strong ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
