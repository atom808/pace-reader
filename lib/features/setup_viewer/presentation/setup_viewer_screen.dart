import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/car_label.dart';
import '../../../widgets/identity/class_chip.dart';
import '../../../widgets/identity/compound_badge.dart';
import '../../session_library/application/open_sessions.dart';
import '../application/car_setup.dart';
import '../application/car_setup_provider.dart';
import '../application/key_figures.dart';
import 'setting_widgets.dart';
import 'setup_section_card.dart';
import 'setup_toolbar.dart';

/// Setup Viewer (SPEC.md §8.10): the embedded `CarSetup`, read-only.
///
/// 172 keys are far too many to scroll and too few to page, so the screen is
/// built around finding things: the four figures a setup is usually asked
/// about lead the page; a pinned bar searches every section at once and jumps
/// to any one of them; and the sections themselves fold away. Per-wheel
/// settings sit in a car layout — FL FR over RL RR — because "front-left
/// camber" is a place before it is a name.
///
/// What the game marks `N/A` (38–58 of a sample's 170 settings) is hidden by
/// default and counted, not dropped: the toolbar and footer both say how many,
/// and one click brings them back.
class SetupViewerScreen extends ConsumerWidget {
  const SetupViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(title: 'Setup', subject: 'the car setup');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: AsyncValueView<CarSetup>(
        value: ref.watch(carSetupProvider(source)),
        loading: (context) => const _Loading(),
        error: (context, error, stack) => _Unreadable(error: error),
        data: (context, setup) => setup.isEmpty
            ? const _NoSetup()
            : _SetupBody(source: source, setup: setup),
      ),
    );
  }
}

class _SetupBody extends ConsumerStatefulWidget {
  const _SetupBody({required this.source, required this.setup});

  final TelemetrySource source;
  final CarSetup setup;

  @override
  ConsumerState<_SetupBody> createState() => _SetupBodyState();
}

class _SetupBodyState extends ConsumerState<_SetupBody> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _viewportKey = GlobalKey();
  final _sectionKeys = <SetupSectionId, GlobalKey>{};
  final _active = ValueNotifier<SetupSectionId?>(null);

  SetupFilter _filter = const SetupFilter();

  /// Sections the reader has folded. Everything starts open.
  final _collapsed = <SetupSectionId>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackActiveSection);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _active.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(SetupSectionId id) =>
      _sectionKeys.putIfAbsent(id, GlobalKey.new);

  /// A section's top edge, in the scroll view's own coordinates.
  double? _topOf(SetupSectionId id) {
    final box = _keyFor(id).currentContext?.findRenderObject();
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || viewport is! RenderBox) return null;
    if (!box.attached || !viewport.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: viewport).dy;
  }

  /// Lights the chip of the last section whose top has passed under the bar.
  void _trackActiveSection() {
    SetupSectionId? current;
    for (final section in widget.setup.sections) {
      final top = _topOf(section.id);
      if (top == null) continue;
      if (top <= setupToolbarExtent + 24) current = section.id;
    }
    if (_active.value != current) _active.value = current;
  }

  void _goTo(SetupSectionId id) {
    setState(() => _collapsed.remove(id));
    _active.value = id;
    // After the frame, so a section that was folded has been laid out open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final top = _topOf(id);
      if (top == null || !_scroll.hasClients) return;
      final target = (_scroll.offset + top - setupToolbarExtent - 4).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: AppDurations.slow,
          curve: AppCurves.entrance,
        );
      }
    });
  }

  void _setQuery(String query) =>
      setState(() => _filter = _filter.copyWith(query: query));

  void _toggle(SetupSectionId id) => setState(() {
    if (!_collapsed.remove(id)) _collapsed.add(id);
  });

  void _focusSearch() {
    _searchFocus.requestFocus();
    _search.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _search.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = widget.setup;
    final view = setup.apply(_filter);
    final style = RowStyle.of(setup);
    final metadata = ref.watch(sessionMetadataProvider(widget.source)).value;

    return CallbackShortcuts(
      bindings: {
        // Ctrl/Cmd+F: the search box is the find bar of this page.
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _focusSearch,
      },
      child: Focus(
        // Holds focus from the first frame, so Ctrl/Cmd+F works before anything
        // on the page has been clicked: a shortcut only fires under a focused
        // descendant of its CallbackShortcuts.
        autofocus: true,
        child: CustomScrollView(
          key: _viewportKey,
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: _Header(setup: setup, metadata: metadata),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: SetupToolbarDelegate(
                child: SetupToolbar(
                  setup: setup,
                  view: view,
                  filter: _filter,
                  controller: _search,
                  focusNode: _searchFocus,
                  active: _active,
                  onQuery: _setQuery,
                  onFilter: (filter) => setState(() => _filter = filter),
                  onSection: _goTo,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              // One box, not a lazy list: a chip has to be able to scroll to a
              // section that is thousands of pixels down, and a lazy list has
              // not built it (no context, no position). 170 rows is nothing
              // to lay out once.
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (view.sections.isEmpty)
                      _NoMatches(
                        filter: _filter,
                        view: view,
                        onClear: () {
                          _search.clear();
                          setState(() => _filter = _filter.copyWith(query: ''));
                        },
                        onShowNotApplicable: () => setState(
                          () => _filter = _filter.copyWith(
                            showNotApplicable: true,
                          ),
                        ),
                      )
                    else
                      for (final section in view.sections) ...[
                        KeyedSubtree(
                          key: _keyFor(section.id),
                          child: SetupSectionCard(
                            section: section,
                            // A search always opens what it found: hiding a hit
                            // inside a folded card would read as "no match".
                            expanded:
                                _filter.query.trim().isNotEmpty ||
                                !_collapsed.contains(section.id),
                            onToggle: () => _toggle(section.id),
                            style: style,
                            gears: setup.gears,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: _Footer(
                  setup: setup,
                  view: view,
                  filter: _filter,
                  onShowNotApplicable: () => setState(
                    () => _filter = _filter.copyWith(showNotApplicable: true),
                  ),
                  onAllowLocked: () => setState(
                    () => _filter = _filter.copyWith(adjustableOnly: false),
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

/// The car, what kind of setup this is, and the headline figures.
class _Header extends StatelessWidget {
  const _Header({required this.setup, required this.metadata});

  final CarSetup setup;
  final SessionMetadata? metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final figures = keyFigures(setup);

    final car = metadata?.carName;
    final carClass = metadata?.carClass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A setup is for a model: it leads, with the class and entry under it.
        if (car != null && car.isNotEmpty) ...[
          CarLabel.of(car, carClass ?? '', size: CarLabelSize.row),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if ((car == null || car.isEmpty) &&
                carClass != null &&
                carClass.isNotEmpty)
              ClassChip.raw(carClass),
            if (setup.symmetric != null)
              _FactChip(
                icon: Icons.compare_arrows_rounded,
                label: setup.symmetric!
                    ? 'Symmetric'
                    : 'Left and right independent',
                tooltip: setup.symmetric!
                    ? 'Left and right are set as a pair: every FL/FR and RL/RR '
                          'reads the same'
                    : 'Left and right corners can differ',
              ),
            if (setup.hasLockedSettings)
              _FactChip(
                icon: Icons.lock_outline_rounded,
                label:
                    '${setup.adjustableCount} of ${setup.settingCount} '
                    'adjustable in this session',
                tooltip:
                    'The other ${setup.lockedCount} are locked by the '
                    'session, as in a fixed-setup race',
              ),
            if (setup.movedCount > 0)
              _FactChip(
                icon: Icons.change_history_rounded,
                label: '${setup.movedCount} with a recorded change',
                tooltip:
                    'The game counted steps moved on these settings '
                    '(the Δ on each row)',
              ),
          ],
        ),
        if (figures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final figure in figures)
                StatTile(
                  label: figure.label,
                  value: figure.value,
                  caption: figure.caption,
                  leading: figure.compounds.isEmpty
                      ? null
                      : CompoundBadges(
                          marks: figure.compounds,
                          size: CompoundBadgeSize.large,
                        ),
                ),
            ],
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'None of the usual headline settings are set on this car.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppTooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          color: AppColors.surfaceMid,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: scheme.secondary),
              const SizedBox(width: 7),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is on screen against what the file holds, and why the difference.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.setup,
    required this.view,
    required this.filter,
    required this.onShowNotApplicable,
    required this.onAllowLocked,
  });

  final CarSetup setup;
  final SetupView view;
  final SetupFilter filter;
  final VoidCallback onShowNotApplicable;
  final VoidCallback onAllowLocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.bodySmall?.copyWith(color: muted);
    final num = AppTextStyles.numeral.copyWith(fontSize: 12, color: muted);

    Widget note(String text, String action, VoidCallback onTap) => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text, style: style),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(action),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: style,
            children: [
              const TextSpan(text: 'Showing '),
              TextSpan(text: '${view.shown}', style: num),
              const TextSpan(text: ' of '),
              TextSpan(text: '${view.total}', style: num),
              const TextSpan(text: ' settings'),
              if (filter.query.trim().isNotEmpty)
                TextSpan(text: ' matching “${filter.query.trim()}”'),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        if (view.hiddenNotApplicable > 0 && !filter.showNotApplicable)
          note(
            view.hiddenNotApplicable == 1
                ? '1 setting the game marks N/A is hidden.'
                : '${view.hiddenNotApplicable} settings the game marks N/A are hidden.',
            'Show them',
            onShowNotApplicable,
          ),
        if (view.hiddenLocked > 0 && filter.adjustableOnly)
          note(
            view.hiddenLocked == 1
                ? '1 setting locked by this session is hidden.'
                : '${view.hiddenLocked} settings locked by this session are hidden.',
            'Show them',
            onAllowLocked,
          ),
        if (setup.rawCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${setup.rawCount} ${setup.rawCount == 1 ? 'entry' : 'entries'} '
              'this version does not recognise ${setup.rawCount == 1 ? 'is' : 'are'} '
              'listed as text under Other.',
              style: style,
            ),
          ),
      ],
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({
    required this.filter,
    required this.view,
    required this.onClear,
    required this.onShowNotApplicable,
  });

  final SetupFilter filter;
  final SetupView view;
  final VoidCallback onClear;
  final VoidCallback onShowNotApplicable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final query = filter.query.trim();
    final onlyNa = view.hiddenNotApplicable > 0 && !filter.showNotApplicable;
    return SquircleCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: muted),
          const SizedBox(height: 14),
          Text(
            query.isEmpty ? 'Nothing to show' : 'No setting matches “$query”',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            onlyNa
                ? (view.hiddenNotApplicable == 1
                      ? '1 setting matches but reads N/A on this car, so it is hidden.'
                      : '${view.hiddenNotApplicable} settings match but read N/A on this car, so they are hidden.')
                : filter.adjustableOnly
                ? 'Only settings this session lets you change are listed.'
                : 'Try a setting name, a value, or a section.',
            style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              if (onlyNa)
                FilledButton.icon(
                  onPressed: onShowNotApplicable,
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('Show N/A settings'),
                ),
              if (query.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Clear search'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoSetup extends StatelessWidget {
  const _NoSetup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.build_circle_outlined, size: 48, color: muted),
            const SizedBox(height: 16),
            Text(
              'No car setup in this recording',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'The file’s metadata has no CarSetup entry, or an empty one, so '
              'there is no setup to show. Everything else about the session is '
              'unaffected.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Unreadable extends StatelessWidget {
  const _Unreadable({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = error is SetupFormatException
        ? (error as SetupFormatException).message
        : '$error';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'The car setup could not be read',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A skeleton of the page that is coming: a header, the toolbar, two sections.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    Widget card(int rows) => SquircleCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 22, width: 200),
          const SizedBox(height: 18),
          for (var i = 0; i < rows; i++) ...[
            const Skeleton(height: 16),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const Row(
          children: [
            Skeleton(height: 96, width: 220, radius: 24),
            SizedBox(width: 16),
            Skeleton(height: 96, width: 220, radius: 24),
            SizedBox(width: 16),
            Skeleton(height: 96, width: 220, radius: 24),
          ],
        ),
        const SizedBox(height: 20),
        const Skeleton(height: 56, radius: 22),
        const SizedBox(height: 20),
        card(4),
        const SizedBox(height: 16),
        card(3),
      ],
    );
  }
}
