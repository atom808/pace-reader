/// Driving Technique (SPEC.md §8.13): how a lap was driven, measured from
/// the pedals, the wheel, the G sensor and the gearbox, and placed on the
/// track.
///
/// It loads in the order it can be read: the session's laps, then every
/// lap's measures (the header and the cards), then the course (the map, the
/// segments and the corners), then each stretch's measures, then the
/// conditions lens. Each part draws as soon as its own data lands.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../application/technique_providers.dart';
import '../domain/lap_technique.dart';
import '../domain/racing_laps.dart';
import 'gg_panel.dart';
import 'measure_cards.dart';
import 'segment_table.dart';
import 'shift_panel.dart';
import 'technique_header.dart';
import 'technique_widgets.dart';
import 'track_panel.dart';
import 'trend_grid.dart';

/// Where the screen splits into two columns (§8.13.7 "Layout").
const _twoColumns = 1100.0;

class DrivingTechniqueScreen extends ConsumerWidget {
  const DrivingTechniqueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(
        title: 'Driving technique',
        subject: 'pedal, steering and G data',
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driving technique'),
        actions: [
          _OpenInTrace(source: source),
          const SizedBox(width: 12),
        ],
      ),
      body: AsyncValueView<TechniqueOverview>(
        value: ref.watch(techniqueOverviewProvider(source)),
        loading: (context) => const _LoadingLayout(),
        data: (context, overview) =>
            _Technique(source: source, overview: overview),
      ),
    );
  }
}

/// The lap on screen: the selection, else the fastest racing lap.
LapTechnique? _shownLap(TechniqueOverview overview, int? selected) =>
    overview.laps[selected] ?? overview.fastest;

/// Opens the shown lap in Trace (§8.13.7): the screen's one link into the
/// synced system. It selects the lap; Trace opens at its start.
void _openInTrace(
  BuildContext context,
  WidgetRef ref,
  TelemetrySource source,
  LapTechnique lap,
) {
  ref.read(selectedLapIndexProvider(source).notifier).select(lap.lap.index);
  context.go('/trace');
}

class _OpenInTrace extends ConsumerWidget {
  const _OpenInTrace({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(techniqueOverviewProvider(source)).value;
    final selected = ref.watch(
      techniqueSelectionStateProvider(source).select((s) => s.lapIndex),
    );
    final lap = overview == null ? null : _shownLap(overview, selected);
    return Tooltip(
      message: 'Ctrl+Enter',
      child: TextButton.icon(
        style: AppButtonStyles.secondary(context),
        onPressed: lap == null
            ? null
            : () => _openInTrace(context, ref, source, lap),
        icon: const Icon(Icons.show_chart, size: 18),
        label: Text(
          lap == null
              ? 'Open in Trace'
              : 'Lap ${lap.lap.displayNumber} in Trace',
        ),
      ),
    );
  }
}

class _Technique extends HookConsumerWidget {
  const _Technique({required this.source, required this.overview});

  final TelemetrySource source;
  final TechniqueOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headerHeight = useState(156.0);
    // Keeps the linking state alive without rebuilding the screen on every
    // hover: each panel watches the part it draws.
    ref.listen(techniqueFocusStateProvider(source), (_, _) {});
    final selected = ref.watch(
      techniqueSelectionStateProvider(source).select((s) => s.lapIndex),
    );
    final session = overview.session;
    if (!session.hasPedals) {
      return const _Notice(
        'This recording has no throttle and brake channels on a shared '
        'frame, so there is nothing here to measure.',
      );
    }
    final lap = _shownLap(overview, selected);
    if (lap == null) {
      return _Notice(_noRacingLaps(session));
    }
    final ordered = overview.ordered;
    final position = ordered.indexOf(lap);

    void selectLap(int index) => ref
        .read(techniqueSelectionStateProvider(source).notifier)
        .selectLap(index);
    void stepLap(int by) {
      final next = position + by;
      if (next < 0 || next >= ordered.length) return;
      selectLap(ordered[next].lap.index);
    }

    final focus = ref.read(techniqueFocusStateProvider(source).notifier);
    void stepSegment(int by) {
      final segments = ref
          .read(techniqueCourseProvider(source))
          .value
          ?.segments;
      if (segments == null || segments.isEmpty) return;
      final current = ref.read(techniqueFocusStateProvider(source)).selected;
      final at = segments.indexWhere((s) => s.number == current?.segment);
      final next = at < 0
          ? (by > 0 ? 0 : segments.length - 1)
          : (at + by).clamp(0, segments.length - 1);
      focus.select(StretchRef.segment(segments[next].number));
    }

    void expandSelected() {
      final current = ref.read(techniqueFocusStateProvider(source)).selected;
      if (current != null) focus.toggleExpanded(current.segment);
    }

    final header = TechniqueHeader(
      source: source,
      overview: overview,
      lap: lap,
      onSelectLap: selectLap,
    );
    final glance = LapAtAGlance(overview: overview, lap: lap);
    final track = TrackPanel(source: source, episodes: lap.countersteer);
    final segments = SegmentTable(source: source, lap: lap);
    final gg = GgPanel(source: source, overview: overview, lap: lap);
    final shifts = ShiftPanel(overview: overview, lap: lap);
    final trends = TrendGrid(
      overview: overview,
      lap: lap,
      onSelectLap: selectLap,
    );
    const gap = SizedBox(height: 16);
    // Panels continue the cards' stagger, in reading order (§8.13.8).
    Widget enter(int i, Widget child) =>
        StaggeredEntrance(index: 10 + i, child: child);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => stepLap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => stepLap(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            stepSegment(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            stepSegment(1),
        const SingleActivator(LogicalKeyboardKey.enter): expandSelected,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
            _openInTrace(context, ref, source, lap),
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
            _openInTrace(context, ref, source, lap),
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _twoColumns;
            final body = wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [enter(0, track), gap, enter(1, segments)],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [enter(2, gg), gap, enter(3, shifts)],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      enter(0, track),
                      gap,
                      enter(1, segments),
                      gap,
                      enter(2, gg),
                      gap,
                      enter(3, shifts),
                    ],
                  );
            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    headerHeight.value + 28,
                    24,
                    32,
                  ),
                  children: [glance, gap, body, gap, enter(4, trends)],
                ),
                // The header floats as glass over the scrolling page: the
                // one piece of static chrome (§9.7.3).
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
  }
}

String _noRacingLaps(TechniqueSession session) {
  if (session.laps.isEmpty) {
    return 'This recording has no laps: its Lap table marks no lap start.';
  }
  final reasons = <NotRacing, int>{};
  for (final why in session.excluded.values) {
    reasons[why] = (reasons[why] ?? 0) + 1;
  }
  final parts = [
    for (final MapEntry(key: why, value: n) in reasons.entries)
      '$n because ${why.description}',
  ];
  return 'None of this recording\'s ${session.laps.length} '
      'lap${session.laps.length == 1 ? ' is' : 's is'} a racing lap: '
      '${parts.join('; ')}. Technique is measured on racing laps only, since '
      'a lap through the pits or on the limiter is not driven at pace.';
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

/// The skeleton, in the shape of what is coming: a header, a row of cards,
/// the map and table beside a ring, then bars.
class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _twoColumns;
        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SquircleCard(child: Skeleton(height: 280)),
            const SizedBox(height: 16),
            SquircleCard(
              child: Column(
                children: [
                  for (var i = 0; i < 6; i++)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Skeleton(height: 20),
                    ),
                ],
              ),
            ),
          ],
        );
        const ring = SquircleCard(child: _RingSkeleton());
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const Skeleton(height: 128, radius: AppRadii.lg),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < 6; i++)
                  const Skeleton(width: 236, height: 132, radius: AppRadii.lg),
              ],
            ),
            const SizedBox(height: 16),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: left),
                  const SizedBox(width: 16),
                  const Expanded(flex: 4, child: ring),
                ],
              )
            else ...[
              left,
              const SizedBox(height: 16),
              ring,
            ],
            const SizedBox(height: 16),
            const TrendGridSkeleton(),
          ],
        );
      },
    );
  }
}

class _RingSkeleton extends StatelessWidget {
  const _RingSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.maxWidth.clamp(0.0, 320.0);
      return Center(
        child: ClipPath(
          clipper: const _RingClipper(),
          child: Skeleton(width: side, height: side, radius: side / 2),
        ),
      );
    },
  );
}

class _RingClipper extends CustomClipper<Path> {
  const _RingClipper();

  @override
  Path getClip(Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: centre, radius: outer))
      ..addOval(Rect.fromCircle(center: centre, radius: outer - 14));
  }

  @override
  bool shouldReclip(_RingClipper oldClipper) => false;
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
