/// Search, filter chips and scan folders over the library (SPEC.md §8.1).
library;

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/folder_scan.dart';
import '../application/library_query.dart';
import '../application/session_library.dart';
import '../data/library_entry.dart';
import 'library_formatting.dart';
import 'library_widgets.dart';

/// The search box and the three chip groups.
///
/// Chips are built from what the library actually holds ([LibraryFacets]),
/// so no chip on its own can lead to an empty list, and each carries its
/// count so the reader knows what a tap will leave before making it.
class LibraryToolbar extends HookConsumerWidget {
  const LibraryToolbar({
    super.key,
    required this.view,
    required this.searchFocus,
  });

  final LibraryView view;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = view.query;
    final filter = ref.read(libraryFilterProvider.notifier);
    // Seeded from the kept-alive query, so coming back from the Overview
    // finds the box as it was left.
    final controller = useTextEditingController(text: query.search);
    useListenable(controller);
    // The query is the source of truth. "Clear filters" in the no-match state
    // resets it from outside this widget; without this the box would keep
    // showing the text of a filter that is no longer applied, over a list
    // that has gone back to showing everything.
    useEffect(() {
      if (controller.text != query.search) {
        controller.value = TextEditingValue(
          text: query.search,
          selection: TextSelection.collapsed(offset: query.search.length),
        );
      }
      return null;
    }, [query.search]);
    final facets = view.facets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () {
                    controller.clear();
                    filter.setSearch('');
                  },
                },
                child: TextField(
                  controller: controller,
                  focusNode: searchFocus,
                  onChanged: filter.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: 'Search track, car or driver',
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            iconSize: 16,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              controller.clear();
                              filter.setSearch('');
                            },
                          ),
                  ),
                ),
              ),
            ),
            MixedNumeralText(
              query.isEmpty
                  ? plural(view.all.length, 'session')
                  : '${view.visible.length} of ${view.all.length} sessions',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            AnimatedSwitcher(
              duration: libraryMotion(context, AppDurations.medium),
              switchInCurve: AppCurves.entrance,
              child: query.isEmpty
                  ? const SizedBox.shrink()
                  : TextButton.icon(
                      onPressed: () {
                        controller.clear();
                        filter.clear();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                      label: const Text('Clear filters'),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _FacetGroup<SessionType>(
          label: 'Type',
          facets: facets.sessionTypes,
          isSelected: query.sessionTypes.contains,
          onToggle: filter.toggleSessionType,
        ),
        _FacetGroup<String>(
          label: 'Class',
          facets: facets.carClasses,
          isSelected: query.carClasses.contains,
          onToggle: filter.toggleCarClass,
        ),
        _FacetGroup<TrackLayoutKey>(
          label: 'Track',
          facets: facets.tracks,
          isSelected: query.tracks.contains,
          onToggle: filter.toggleTrack,
        ),
      ],
    );
  }
}

/// One row of chips: a label, then the facet chips.
///
/// A group with more than [collapsedLimit] chips shows that many and a
/// "+N more" chip to open the rest. Track is the group that grows — every
/// circuit the driver has ever recorded at is a chip — and unbounded, it
/// would push the list itself below the fold. Nothing is dropped silently: the
/// toggle says how many are folded away, and a *selected* chip is never
/// folded, so the active filter is always in view.
class _FacetGroup<T> extends HookWidget {
  const _FacetGroup({
    required this.label,
    required this.facets,
    required this.isSelected,
    required this.onToggle,
  });

  static const collapsedLimit = 8;

  final String label;
  final List<LibraryFacet<T>> facets;
  final bool Function(T value) isSelected;
  final void Function(T value) onToggle;

  @override
  Widget build(BuildContext context) {
    if (facets.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final expanded = useState(false);
    final foldable = facets.length > collapsedLimit;
    final shown = [
      for (var i = 0; i < facets.length; i++)
        if (expanded.value ||
            !foldable ||
            i < collapsedLimit ||
            isSelected(facets[i].value))
          facets[i],
    ];
    final hidden = facets.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: MotionSize(
              duration: AppDurations.medium,
              curve: AppCurves.entrance,
              alignment: Alignment.topLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final f in shown)
                    _FacetChip(
                      key: ValueKey(f.value),
                      label: f.label,
                      count: f.count,
                      selected: isSelected(f.value),
                      onSelected: () => onToggle(f.value),
                    ),
                  if (foldable && (hidden > 0 || expanded.value))
                    TextButton(
                      onPressed: () => expanded.value = !expanded.value,
                      child: MixedNumeralText(
                        expanded.value ? 'Show fewer' : '+$hidden more',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacetChip extends StatelessWidget {
  const _FacetChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: AppTextStyles.numeral.copyWith(
              fontSize: 12,
              color: selected ? scheme.onSecondaryContainer : scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Remembered scan folders, plus Refresh and — on Windows, when it exists —
/// LMU's default folder as a one-click suggestion (§5).
class LibraryFolderBar extends ConsumerWidget {
  const LibraryFolderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final suggestion = ref.watch(suggestedTelemetryFolderProvider).value;
    final scanning = ref.watch(folderScanProvider) is FolderScanRunning;
    final now = ref.watch(libraryClockProvider)();
    if (folders.isEmpty && suggestion == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                'Folders',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final folder in folders)
                  _FolderChip(folder: folder, now: now),
                if (suggestion != null)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text("Add LMU's telemetry folder"),
                    tooltip: suggestion,
                    onPressed: scanning
                        ? null
                        : () => ref
                              .read(folderScanProvider.notifier)
                              .addAndScan(suggestion),
                  ),
                if (folders.isNotEmpty)
                  TextButton.icon(
                    onPressed: scanning
                        ? null
                        : () => ref
                              .read(folderScanProvider.notifier)
                              .refreshAll(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderChip extends ConsumerWidget {
  const _FolderChip({required this.folder, required this.now});

  final LibraryFolder folder;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanned = folder.lastScannedAt;
    final count = folder.lastScanFileCount;
    final detail = scanned == null
        ? 'not scanned yet'
        : '${plural(count ?? 0, 'recording')} · scanned '
              '${formatRelative(scanned, now)}';
    return InputChip(
      avatar: const Icon(Icons.folder_outlined, size: 16),
      label: MixedNumeralText('${_shortPath(folder.path)} · $detail'),
      tooltip: folder.path,
      deleteButtonTooltipMessage:
          'Forget this folder (its sessions stay in the library)',
      onDeleted: () =>
          ref.read(libraryFoldersProvider.notifier).remove(folder.path),
    );
  }

  /// The last two segments — `UserData\Telemetry` — which is what tells two
  /// folders apart; the full path is the tooltip.
  static String _shortPath(String path) {
    final parts = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty);
    final list = parts.toList();
    if (list.length <= 2) return path;
    final sep = path.contains(r'\') ? r'\' : '/';
    return '…$sep${list[list.length - 2]}$sep${list.last}';
  }
}
