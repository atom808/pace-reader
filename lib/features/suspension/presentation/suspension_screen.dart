/// Suspension (suspension proposal, revision 2): where the car touches
/// down, when, and whether it goes with the line or the setup — then what
/// the platform did as a whole.
///
/// It opens on the worst site. The header, the cards and the platform panels
/// draw from one read of the session; a site's traces are read when it is
/// shown.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../driving_technique/application/technique_providers.dart';
import '../../driving_technique/presentation/technique_widgets.dart';
import '../../lap_focus/lap_focus.dart';
import '../../lap_focus/lap_focus_arrival.dart';
import '../../lap_focus/lap_focus_link.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/application/trace_focus.dart';
import '../application/suspension_focus.dart';
import '../application/suspension_providers.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';
import 'glance_cards.dart';
import 'platform_panels.dart';
import 'site_view.dart';
import 'sites_panel.dart';
import 'suspension_header.dart';

/// Where the map and the sites list sit side by side, and the platform
/// panels too (§6 "Responsive").
const _twoColumns = 1100.0;

class SuspensionScreen extends ConsumerWidget {
  const SuspensionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Suspension',
        subject: 'ride height and suspension data',
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const SuspensionTitle(),
        actions: [
          _OpenInTrace(source: source),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<SuspensionOverview>(
        value: ref.watch(suspensionOverviewProvider(source)),
        loading: (context) => const _LoadingLayout(),
        data: (context, overview) =>
            _Suspension(source: source, overview: overview),
      ),
    );
  }
}

/// The lap on screen: the selection; else the deepest lap at the top site;
/// else the fastest racing lap.
Lap? shownLap(SuspensionOverview overview, SuspensionSelection selection) {
  final racing = overview.racing;
  if (racing.isEmpty) return null;
  for (final l in racing) {
    if (l.index == selection.lapIndex) return l;
  }
  final site = overview.site(selection.siteKey) ?? overview.sites.firstOrNull;
  if (site != null && site.lapLows.isNotEmpty) {
    final deepest = site.lapLows.values.reduce(
      (a, b) => b.depth < a.depth ? b : a,
    );
    for (final l in racing) {
      if (l.index == deepest.lap) return l;
    }
  }
  final timed = [
    for (final l in racing)
      if (l.lapTimeSeconds != null) l,
  ];
  if (timed.isEmpty) return racing.first;
  return timed.reduce((a, b) => b.lapTimeSeconds! < a.lapTimeSeconds! ? b : a);
}

/// The site on screen: the selection, else the top site.
Site? shownSite(SuspensionOverview overview, SuspensionSelection selection) =>
    overview.site(selection.siteKey) ?? overview.sites.firstOrNull;

/// The shown lap as Trace should open it (map stage proposal §6.4): the car
/// on the site, the traces framed on its approach and exit.
LapFocus _traceFocus(TelemetrySource source, Lap lap, Site? site) => LapFocus(
  source: source,
  lap: lap.index,
  station: site?.place,
  tab: 'suspension',
);

class _OpenInTrace extends ConsumerWidget {
  const _OpenInTrace({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(suspensionOverviewProvider(source)).value;
    final selection = ref.watch(suspensionSelectionStateProvider(source));
    final lap = overview == null ? null : shownLap(overview, selection);
    return LapFocusLink(
      target: traceFocusTarget,
      focus: lap == null
          ? null
          : _traceFocus(source, lap, shownSite(overview!, selection)),
    );
  }
}

class _Suspension extends HookConsumerWidget {
  const _Suspension({required this.source, required this.overview});

  final TelemetrySource source;
  final SuspensionOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerHeight = useState(150.0);
    final selection = ref.watch(suspensionSelectionStateProvider(source));
    final notifier = ref.read(
      suspensionSelectionStateProvider(source).notifier,
    );
    final course = ref.watch(techniqueCourseProvider(source)).value;

    if (!overview.hasRideHeights) {
      return const _Notice(
        'This recording has no 100 Hz ride heights on the shared frame, so '
        'there is nothing here to measure.',
      );
    }
    final lap = shownLap(overview, selection);
    if (lap == null) {
      return _Notice(
        overview.session.hasPedals
            ? 'None of this recording\'s ${overview.session.laps.length} laps '
                  'is a racing lap: every one went through the pits or ran '
                  'on the limiter. Suspension is measured on racing laps, '
                  'the ones driven at pace.'
            : 'This recording lacks the throttle and brake channels that '
                  'decide which laps were driven at pace.',
      );
    }
    final site = shownSite(overview, selection);
    final racing = overview.racing;
    void openInTrace() => openFocus(
      context,
      ref,
      traceFocusTarget,
      _traceFocus(source, lap, site),
    );
    final position = racing.indexOf(lap);

    void stepLap(int by) {
      final next = position + by;
      if (next < 0 || next >= racing.length) return;
      notifier.selectLap(racing[next].index);
    }

    void stepSite(int by) {
      final shown = [
        for (final s in overview.sites)
          if (selection.phase == null ||
              s.phases.keys.any((p) => phaseMatches(selection.phase, p)))
            s,
      ];
      if (shown.isEmpty) return;
      final at = shown.indexWhere((s) => s.key == site?.key);
      final next = at < 0 ? 0 : (at + by).clamp(0, shown.length - 1);
      notifier.selectSite(shown[next].key);
    }

    final header = SuspensionHeader(
      overview: overview,
      lap: lap,
      onSelectLap: notifier.selectLap,
    );
    final cards = GlanceCards(
      overview: overview,
      lap: lap.index,
      phase: selection.phase,
      onPhase: notifier.setPhase,
    );
    final map = SiteMapPanel(
      source: source,
      overview: overview,
      selected: site?.key,
      filter: selection.phase,
      onSelect: notifier.selectSite,
    );
    final list = SitesList(
      source: source,
      overview: overview,
      selected: site?.key,
      filter: selection.phase,
      onSelect: notifier.selectSite,
    );
    final siteView = site == null
        ? SquircleCard(
            child: AbsenceNote(
              overview.headline.isEmpty
                  ? 'No strikes: no corner went under '
                        '${(strikeFloorMetres * 1000).round()} mm on a racing lap. The '
                        'platform below still shows how the car rode.'
                  : 'No site: strikes happened, but never twice in the same '
                        'place. Each one is a lap of its own, not the car.',
            ),
          )
        : SiteView(
            key: ValueKey('site-${site.key}'),
            source: source,
            overview: overview,
            site: site,
            lap: lap.index,
            placeName: placeName(course, site.place),
            evidence: selection.evidence,
            onToggleEvidence: notifier.toggleEvidence,
            onOpenInTrace: openInTrace,
          );
    final dampers = DamperPanel(overview: overview, lap: lap.index);
    final roll = RollPanel(
      overview: overview,
      lap: lap.index,
      onSelectLap: notifier.selectLap,
    );
    final trends = TrendsPanel(
      overview: overview,
      lap: lap.index,
      onSelectLap: notifier.selectLap,
    );
    const gap = SizedBox(height: 16);
    Widget enter(int i, Widget child) =>
        StaggeredEntrance(index: 8 + i, child: child);

    void phaseKey(StrikePhase? p) =>
        notifier.setPhase(selection.phase == p ? null : p);

    final page = CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => stepLap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => stepLap(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => stepSite(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => stepSite(1),
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            phaseKey(StrikePhase.straight),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            phaseKey(StrikePhase.braking),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            phaseKey(StrikePhase.corner),
        const SingleActivator(LogicalKeyboardKey.digit0): () =>
            notifier.setPhase(null),
        const SingleActivator(LogicalKeyboardKey.enter):
            notifier.toggleEvidence,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            openInTrace,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            openInTrace,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumns;
            final where = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: enter(0, map)),
                      const SizedBox(width: 16),
                      Expanded(flex: 5, child: enter(1, list)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [enter(1, list), gap, enter(0, map)],
                  );
            final platform = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: enter(3, dampers)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: enter(4, roll)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [enter(3, dampers), gap, enter(4, roll)],
                  );
            return Stack(
              children: [
                ListView(
                  // Built a screen ahead, so a focus from Trace can scroll to
                  // the platform panels before the user has (§6.4).
                  scrollCacheExtent: const ScrollCacheExtent.viewport(1),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    headerHeight.value + 28,
                    24,
                    32,
                  ),
                  children: [
                    cards,
                    gap,
                    where,
                    gap,
                    enter(
                      2,
                      LapFocusReveal(
                        id: suspensionSiteReveal,
                        alignment: 0.25,
                        child: siteView,
                      ),
                    ),
                    gap,
                    LapFocusReveal(
                      id: suspensionPlatformReveal,
                      alignment: 0.25,
                      child: platform,
                    ),
                    gap,
                    enter(5, trends),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: _ReportSize(
                    onSize: (size) {
                      if ((size.height - headerHeight.value).abs() > 0.5) {
                        headerHeight.value = size.height;
                      }
                    },
                    child: header,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    return LapFocusArrival(
      target: suspensionFocusTarget,
      source: source,
      lap: lap.index,
      onArrival: (focus) {
        final reveal = ref.read(lapFocusRevealProvider.notifier);
        if (focusedSite(overview.sites, focus) case final near?) {
          notifier.selectSite(near.key);
          reveal.reveal(suspensionSiteReveal);
        } else {
          reveal.reveal(suspensionPlatformReveal);
        }
      },
      child: page,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SquircleCard(child: AbsenceNote(text)),
      ),
    ),
  );
}

/// The skeleton, in the shape of what is coming: the header, the cards, the
/// map beside the list, then the site view.
class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _twoColumns;
        const map = SquircleCard(child: Skeleton(height: 300));
        final list = SquircleCard(
          child: Column(
            children: [
              for (var i = 0; i < 5; i++)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Skeleton(height: 28),
                ),
            ],
          ),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const Skeleton(height: 120, radius: AppRadii.lg),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 6; i++)
                  const Skeleton(width: 214, height: 132, radius: AppRadii.lg),
              ],
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(flex: 6, child: map),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: list),
                ],
              )
            else ...[
              list,
              const SizedBox(height: 16),
              map,
            ],
            const SizedBox(height: 16),
            const SquircleCard(child: Skeleton(height: 420)),
          ],
        );
      },
    );
  }
}

/// Reports its child's size after each layout that changes it, so the page
/// can clear the floating header exactly.
class _ReportSize extends SingleChildRenderObjectWidget {
  const _ReportSize({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _reported) return;
    final now = _reported = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) onSize(now);
    });
  }
}
