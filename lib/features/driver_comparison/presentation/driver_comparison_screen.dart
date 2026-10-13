/// Compare (SPEC.md §8.8; comparison proposal §3).
///
/// One lap explained against a faster one: Base drawn solid, the Target
/// dotted, from any recording of the same course. The left column is Trace's
/// own panel stack and axis footer, and the right pane its map — Compare is
/// Trace's reference overlay widened to a second file, not a second chart.
library;

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/charting/charting.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/presentation/lap_view_controls.dart';
import '../../telemetry_trace/presentation/lap_view_panes.dart';
import '../application/compare_source_guard.dart';
import '../application/comparison_chart.dart';
import '../application/comparison_workspace.dart';
import '../application/lap_conditions.dart';
import '../application/segment_tables.dart';
import '../domain/comparison_set.dart';
import '../domain/lines.dart';
import 'comparability_strip.dart';
import 'compare_actions.dart';
import 'compare_map_pane.dart';
import 'lap_card.dart';
import 'sector_table.dart';
import 'segment_navigator.dart';
import 'suggestion_list.dart';
import 'tyres_this_lap.dart';
import 'why_card.dart';

class DriverComparisonScreen extends ConsumerWidget {
  const DriverComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeComparisonProvider);
    return switch (active) {
      AsyncData(value: null) => const NoSessionScreen(
        title: 'Compare',
        subject: 'one lap explained against another',
      ),
      AsyncData(value: final set?) => _Workspace(set: set),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: const Text('Compare')),
        body: Center(child: Text('$error')),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Compare')),
        body: const SizedBox.shrink(),
      ),
    };
  }
}

class _Workspace extends ConsumerWidget {
  const _Workspace({required this.set});

  final ComparisonSet set;

  /// Below this the suggestions move off the card row and into the
  /// Target's picker (§3, 1080–1279 px).
  static const _suggestionsBreakpoint = 1280.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(comparisonChartProvider(set));
    final segmentsRead = set.target == null
        ? null
        : ref.watch(comparisonSegmentsProvider(set));
    final segments = segmentsRead?.value;
    // The navigator's keys act on whatever the screen shows when pressed.
    void segmentKey(void Function(SegmentActions) action) {
      final chart = view.value?.chart;
      if (chart == null || segments == null) return;
      action(SegmentActions(ref, set: set, chart: chart, segments: segments));
    }

    void next() => segmentKey((a) => a.step(forward: true));
    void previous() => segmentKey((a) => a.step(forward: false));
    void zoom() => segmentKey((a) => a.zoom());
    void wholeLap() => segmentKey((a) => a.wholeLap());
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): next,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): previous,
        // `[` and `]` by the character typed, not the key: on Spanish and
        // other non-US layouts they need AltGr, which Windows reports as
        // Ctrl+Alt, so a key-based binding would never match (§3).
        const CharacterActivator(']'): next,
        const CharacterActivator(']', control: true, alt: true): next,
        const CharacterActivator('['): previous,
        const CharacterActivator('[', control: true, alt: true): previous,
        const SingleActivator(LogicalKeyboardKey.enter): zoom,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): zoom,
        const SingleActivator(LogicalKeyboardKey.digit0): wholeLap,
        const SingleActivator(LogicalKeyboardKey.numpad0): wholeLap,
        const SingleActivator(LogicalKeyboardKey.escape): wholeLap,
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true): () =>
            ref.read(comparisonWorkspaceProvider.notifier).swap(),
        const SingleActivator(LogicalKeyboardKey.keyT, alt: true): () {
          final chart = view.value?.chart;
          if (chart == null) return;
          ref
              .read(chartSyncProvider.notifier)
              .setAxis(
                chart.axis == TraceAxis.distance
                    ? TraceAxis.time
                    : TraceAxis.distance,
                distanceAxis: chart.distanceAxis,
              );
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(title: const Text('Compare')),
          // Base's clock is the axis, so Base owns the cursor and the zoom:
          // a Swap or another Base is a new owner, and starts from the whole
          // lap (§9).
          body: SyncOwner(
            owner: set.base,
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                    child: _CardsRow(
                      set: set,
                      withSuggestions:
                          constraints.maxWidth >= _suggestionsBreakpoint,
                    ),
                  ),
                  Expanded(
                    child: AsyncValueView<ComparisonView>(
                      value: view,
                      error: (context, error, _) => switch (error) {
                        CompareSourceClosed(role: ComparisonRole.base) =>
                          _BaseClosed(set: set),
                        CompareSourceClosed(role: ComparisonRole.target) =>
                          _TargetClosed(set: set),
                        _ => Center(child: Text('$error')),
                      },
                      data: (context, view) => _Body(
                        view: view,
                        segments: segments,
                        segmentsError: segmentsRead?.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardsRow extends ConsumerWidget {
  const _CardsRow({required this.set, required this.withSuggestions});

  final ComparisonSet set;
  final bool withSuggestions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LapCard(role: ComparisonRole.base, set: set),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: IconButton(
                tooltip: 'Swap Base and Target (Alt+S)',
                icon: const Icon(Icons.swap_horiz),
                onPressed: set.target == null
                    ? null
                    : ref.read(comparisonWorkspaceProvider.notifier).swap,
              ),
            ),
          ),
          Expanded(
            child: LapCard(role: ComparisonRole.target, set: set),
          ),
          if (withSuggestions && set.target != null) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: 260,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Suggested targets',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: SingleChildScrollView(
                      child: SuggestionList(set: set, dense: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({
    required this.view,
    required this.segments,
    required this.segmentsError,
  });

  final ComparisonView view;

  /// Null without a Target, and while the first detection runs.
  final ComparisonSegments? segments;

  /// Why the segments could not be read, when they could not.
  final Object? segmentsError;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  /// Below this the map and the sectors leave the stack's side for a view
  /// of their own (§3, "Map & detail").
  static const _sidePaneBreakpoint = 1080.0;
  static const _sidePaneWidth = 360.0;

  /// Whether a narrow window shows "Map & detail" instead of the traces.
  var _detail = false;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final chart = view.chart;
    if (chart == null) return _Refused(view: view);
    final comparison = chart.comparison;
    final segments = widget.segments;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidePane = constraints.maxWidth >= _sidePaneBreakpoint;
        final detail = !showSidePane && _detail;
        // The map takes 60% of the pane; the card under it, the rest (§3).
        final sidePane = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (view.map case final map?)
              Expanded(
                flex: 3,
                child: CompareMapPane(view: view, map: map, segments: segments),
              )
            else if (chart.hasTrackMap)
              Expanded(flex: 3, child: LapTrackMapPane(chart: chart)),
            if (comparison != null)
              Expanded(
                flex: 2,
                child: _DetailTabs(
                  view: view,
                  segments: segments,
                  sectors: SectorTable(
                    base: chart.lap,
                    target: comparison.reference,
                  ),
                ),
              ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (view.chips.isEmpty)
                    Text(
                      'Base alone: choose a Target to compare it against.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    _Strip(view: view),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!showSidePane) ...[
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Traces')),
                            ButtonSegment(
                              value: true,
                              label: Text('Map & detail'),
                            ),
                          ],
                          selected: {detail},
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            shape: WidgetStatePropertyAll(
                              AppRadii.squircle(AppRadii.sm),
                            ),
                          ),
                          onSelectionChanged: (selection) =>
                              setState(() => _detail = selection.first),
                        ),
                        const SizedBox(width: 12),
                      ],
                      AxisToggle(chart: chart),
                      const ZoomResetButton(),
                    ],
                  ),
                ],
              ),
            ),
            if (comparison?.note case final note?)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: ComparisonNote(note: note),
              ),
            if (comparison != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: segments == null
                    ? Text(
                        widget.segmentsError == null
                            ? 'Finding the corners…'
                            : 'No segments: ${widget.segmentsError}',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : SegmentNavigator(
                        set: view.set,
                        chart: chart,
                        segments: segments,
                      ),
              ),
            const Divider(height: 1),
            Expanded(
              child: detail
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: sidePane,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: chart.panels.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No traceable channels in this lap.',
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: LapPanelStack(
                                        chart: chart,
                                        below: (panel) => switch (panel.role) {
                                          ChannelRole.line =>
                                            const _LineToggle(),
                                          ChannelRole.steering =>
                                            view.line?.withheld == null
                                                ? null
                                                : _LineWithheld(
                                                    reason:
                                                        view.line!.withheld!,
                                                  ),
                                          _ => null,
                                        },
                                      ),
                                    ),
                                    // Pinned, not in the scrolling stack:
                                    // it answers for wherever the cursor is.
                                    if (view.map case final map?
                                        when chart.axis == TraceAxis.time) ...[
                                      const Divider(height: 1),
                                      TimeReadoutBar(map: map),
                                    ],
                                  ],
                                ),
                        ),
                        if (showSidePane) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(width: _sidePaneWidth, child: sidePane),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Under the Line panel: what it shows, and the switch to each lap's own
/// `Path Lateral` (comparison proposal §6).
class _LineToggle extends ConsumerWidget {
  const _LineToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final raw = ref.watch(linePanelRawProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              raw
                  ? "Each lap's Path Lateral: metres from the centre path, "
                        '+ = right.'
                  : 'Target against Base, + = Target further right. The band '
                        'is the ${lineFloor.toStringAsFixed(1)} m floor: '
                        'differences inside it are not stated.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(linePanelRawProvider.notifier).toggle(),
            child: Text(raw ? 'Show the difference' : 'Show raw Path Lateral'),
          ),
        ],
      ),
    );
  }
}

/// Where the Line panel would be, when it is not shown: why.
class _LineWithheld extends StatelessWidget {
  const _LineWithheld({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No Line panel: $reason.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The chart's chips, then each lap's conditions and setup once they are
/// read (§7): they are not needed to draw either lap, so they never hold the
/// chart up.
class _Strip extends ConsumerWidget {
  const _Strip({required this.view});

  final ComparisonView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conditions = view.chart?.comparison == null
        ? null
        : ref.watch(comparisonConditionsProvider(view.set)).value;
    return ComparabilityStrip(chips: [...view.chips, ...?conditions]);
  }
}

/// The card under the map: Why, Sectors and Tyres (§3).
class _DetailTabs extends StatelessWidget {
  const _DetailTabs({
    required this.view,
    required this.segments,
    required this.sectors,
  });

  final ComparisonView view;
  final ComparisonSegments? segments;
  final Widget sectors;

  @override
  Widget build(BuildContext context) {
    final segments = this.segments;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Why'),
              Tab(text: 'Sectors'),
              Tab(text: 'Tyres'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: segments == null
                      ? const SizedBox.shrink()
                      : WhyCard(set: view.set, segments: segments, view: view),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: sectors,
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: TyresThisLap(set: view.set),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The course gate said no (§4): parts 1 and 2 before either lap was read,
/// or part 3 once both were, before anything was drawn.
class _Refused extends ConsumerWidget {
  const _Refused({required this.view});

  final ComparisonView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StateMessage(
      icon: Icons.block,
      title: 'These laps cannot be compared',
      body:
          'The Target is from ${view.course?.reason ?? 'another course'}. '
          'Lap distance starts at zero on every course, so a delta across '
          'two courses would look believable and mean nothing.',
      actions: [
        FilledButton(
          onPressed: () =>
              ref.read(comparisonWorkspaceProvider.notifier).clearTarget(),
          child: const Text('Clear the Target'),
        ),
      ],
    );
  }
}

/// Base's file was closed (§9 "Closing Base's file").
class _BaseClosed extends ConsumerWidget {
  const _BaseClosed({required this.set});

  final ComparisonSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.read(comparisonWorkspaceProvider.notifier);
    final target = set.target;
    return _StateMessage(
      icon: Icons.folder_off_outlined,
      title: "Base's file was closed",
      body: 'Reopen it to carry on, or compare from the Target instead.',
      actions: [
        FilledButton(
          onPressed: () => reopenCompareFile(context, ref, set.base.source),
          child: const Text('Reopen'),
        ),
        if (target != null &&
            ref.watch(openSessionsProvider).contains(target.source))
          OutlinedButton(
            // A Swap without the closed side: Base's clock changes, so the
            // cursor and zoom start over.
            onPressed: () => workspace.start(target),
            child: const Text('Make the Target the base'),
          ),
        TextButton(
          onPressed: workspace.clear,
          child: const Text('Follow the current session'),
        ),
      ],
    );
  }
}

/// The Target's file was closed without the close dialog — from somewhere
/// that does not ask.
class _TargetClosed extends ConsumerWidget {
  const _TargetClosed({required this.set});

  final ComparisonSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StateMessage(
      icon: Icons.folder_off_outlined,
      title: "The Target's file was closed",
      body: 'Reopen it, or choose another Target.',
      actions: [
        FilledButton(
          onPressed: () => reopenCompareFile(context, ref, set.target!.source),
          child: const Text('Reopen'),
        ),
        TextButton(
          onPressed: () =>
              ref.read(comparisonWorkspaceProvider.notifier).clearTarget(),
          child: const Text('Clear the Target'),
        ),
      ],
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
