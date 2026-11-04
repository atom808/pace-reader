/// Compare (SPEC.md §8.8; comparison proposal §3).
///
/// One lap explained against a faster one: Base drawn solid, the Target
/// dotted, from any recording of the same course. Under the lap cards is
/// Trace's own stage — the map, the traces docked over it — with Base's
/// clock as the axis: Compare is Trace's reference overlay widened to a
/// second file, not a second chart (map stage proposal §9).
library;

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/charting/charting.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/common/resizable_side_pane.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../telemetry_trace/presentation/lap_view_controls.dart';
import '../application/compare_source_guard.dart';
import '../application/comparison_chart.dart';
import '../application/comparison_workspace.dart';
import '../application/segment_tables.dart';
import '../domain/comparison_set.dart';
import 'compare_actions.dart';
import 'compare_panels.dart';
import 'compare_stage.dart';
import 'lap_card.dart';
import 'segment_navigator.dart';
import 'suggestion_list.dart';

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
    final segmentKeys = <ShortcutActivator, VoidCallback>{
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
    };
    return CallbackShortcuts(
      bindings: {
        ...segmentKeys,
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
      // No autofocus here: the stage takes the focus, so its own keys are
      // asked, and the plain layout takes it where there is no stage.
      child: Focus(
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
                        keys: segmentKeys,
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

class _Body extends StatelessWidget {
  const _Body({
    required this.view,
    required this.segments,
    required this.segmentsError,
    required this.keys,
  });

  final ComparisonView view;

  /// Null without a Target, and while the first detection runs.
  final ComparisonSegments? segments;

  /// Why the segments could not be read, when they could not.
  final Object? segmentsError;

  /// The segment keys, for the stage to ask before its own.
  final Map<ShortcutActivator, VoidCallback> keys;

  @override
  Widget build(BuildContext context) {
    final chart = view.chart;
    if (chart == null) return _Refused(view: view);
    if (chart.hasTrackMap) {
      return CompareStage(
        view: view,
        segments: segments,
        segmentsError: segmentsError,
        keys: keys,
      );
    }
    return Focus(
      autofocus: true,
      child: _Plain(
        view: view,
        segments: segments,
        segmentsError: segmentsError,
      ),
    );
  }
}

/// A lap without a map: the chips over the traces, with Why, Sectors and
/// Tyres beside them or, on a narrow window, instead of them.
class _Plain extends StatefulWidget {
  const _Plain({
    required this.view,
    required this.segments,
    required this.segmentsError,
  });

  final ComparisonView view;
  final ComparisonSegments? segments;
  final Object? segmentsError;

  @override
  State<_Plain> createState() => _PlainState();
}

class _PlainState extends State<_Plain> {
  /// Below this the detail leaves the stack's side for a view of its own.
  static const _sidePaneBreakpoint = 1080.0;

  /// Whether a narrow window shows the detail instead of the traces.
  var _detail = false;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final chart = view.chart!;
    final comparison = chart.comparison;
    final segments = widget.segments;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showSidePane = constraints.maxWidth >= _sidePaneBreakpoint;
        final detail = comparison != null && !showSidePane && _detail;
        final traces = ComparePanelStack(view: view);
        final side = comparison == null
            ? null
            : CompareDetailTabs(view: view, segments: segments);
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
                    CompareStrip(view: view),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (side != null && !showSidePane) ...[
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Traces')),
                            ButtonSegment(value: true, label: Text('Detail')),
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
              child: switch (side) {
                final side? when detail => Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: side,
                  ),
                ),
                final side? when showSidePane => ResizableSplit(
                  main: traces,
                  side: side,
                ),
                _ => traces,
              },
            ),
          ],
        );
      },
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
          onPressed: () => reopenCompareFile(context, set.base.source),
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
          onPressed: () => reopenCompareFile(context, set.target!.source),
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
