import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/folder_scan.dart';
import '../application/open_sessions.dart';
import '../application/session_import.dart';
import '../application/session_library.dart';
import 'library_list.dart';
import 'library_toolbar.dart';
import 'library_widgets.dart';
import 'open_now_section.dart';
import 'scan_banner.dart';

/// Session Library (SPEC.md §8.1, §9.6).
///
/// Two lists, because they answer two questions. **Open now** is this run's
/// sessions — what can be switched to without reading a file. **Library** is
/// the persistent index: every session ever opened or found by a folder
/// scan, newest recording first, searchable and filterable, with the
/// personal best per circuit and class marked. A file that has left disk
/// stays listed, says so, and can be removed — removing never touches the
/// file.
///
/// With nothing open and nothing indexed the screen is the import surface
/// it was in Phase 1, since there is nothing to list yet.
class SessionLibraryScreen extends HookConsumerWidget {
  const SessionLibraryScreen({super.key});

  /// Content column cap. Rows past ~1300 px only push the best-lap column
  /// further from the track name it belongs to.
  static const _maxContentWidth = 1320.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openSessionsProvider);
    final importState = ref.watch(sessionImportProvider);
    final library = ref.watch(libraryViewProvider);
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final supportsFolders = ref
        .watch(sessionFileSystemProvider)
        .supportsFolders;
    final scanning = ref.watch(folderScanProvider) is FolderScanRunning;
    final searchFocus = useFocusNode(debugLabel: 'library search');

    final libraryIsEmpty =
        library.hasValue && library.value!.all.isEmpty && folders.isEmpty;
    final showWelcome = open.isEmpty && libraryIsEmpty && !scanning;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            searchFocus.requestFocus,
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sessions'),
          actions: [
            if (supportsFolders)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: OutlinedButton.icon(
                  onPressed: scanning
                      ? null
                      : () =>
                            ref.read(folderScanProvider.notifier).pickAndScan(),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Add folder'),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: importState is SessionImportBusy
                    ? null
                    : () => ref.read(sessionImportProvider.notifier).pickFile(),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open file'),
              ),
            ),
          ],
        ),
        body: _DropZone(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImportBanner(state: importState),
              const ScanBanner(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppDurations.slow),
                  switchInCurve: AppCurves.entrance,
                  child: showWelcome
                      ? _WelcomeState(
                          key: const ValueKey('welcome'),
                          supportsFolders: supportsFolders,
                        )
                      : _LibraryContent(
                          key: const ValueKey('content'),
                          searchFocus: searchFocus,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryContent extends ConsumerWidget {
  const _LibraryContent({super.key, required this.searchFocus});

  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openSessionsProvider);
    final library = ref.watch(libraryViewProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = width > SessionLibraryScreen._maxContentWidth + 64
            ? (width - SessionLibraryScreen._maxContentWidth) / 2
            : 28.0;
        EdgeInsets pad(double top, double bottom) =>
            EdgeInsets.fromLTRB(gutter, top, gutter, bottom);

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MotionSize(
                duration: AppDurations.medium,
                curve: AppCurves.entrance,
                alignment: Alignment.topCenter,
                child: open.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: pad(24, 8),
                        child: OpenNowSection(sources: open),
                      ),
              ),
            ),
            SliverPadding(
              padding: pad(24, 14),
              sliver: SliverToBoxAdapter(
                child: LibrarySectionHeader(
                  title: 'Library',
                  count: library.value?.all.length,
                  caption:
                      'Every session you open or scan, newest first. '
                      'Remembered between runs.',
                ),
              ),
            ),
            ..._librarySlivers(context, library, open, pad),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        );
      },
    );
  }

  List<Widget> _librarySlivers(
    BuildContext context,
    AsyncValue<LibraryView> library,
    List<Object> open,
    EdgeInsets Function(double, double) pad,
  ) {
    if (library.hasError && !library.hasValue) {
      return [
        SliverPadding(
          padding: pad(0, 0),
          sliver: SliverToBoxAdapter(
            child: _IndexUnavailable(error: library.error!),
          ),
        ),
      ];
    }
    final view = library.value;
    if (view == null) {
      return [
        SliverPadding(
          padding: pad(0, 0),
          sliver: const SliverToBoxAdapter(child: _RowsSkeleton()),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: pad(0, 6),
        sliver: const SliverToBoxAdapter(child: LibraryFolderBar()),
      ),
      if (view.all.isNotEmpty) ...[
        SliverPadding(
          padding: pad(0, 16),
          sliver: SliverToBoxAdapter(
            child: LibraryToolbar(view: view, searchFocus: searchFocus),
          ),
        ),
        // The column labels only make sense over rows; over the "no match"
        // message they would label nothing.
        if (view.visible.isNotEmpty)
          SliverPadding(
            padding: pad(0, 0),
            sliver: const SliverToBoxAdapter(child: LibraryHeaderRow()),
          ),
      ],
      SliverPadding(
        padding: pad(0, 0),
        sliver: SliverMainAxisGroup(
          slivers: [
            _LibraryRows(view: view),
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: AppMotion.duration(context, AppDurations.medium),
                switchInCurve: AppCurves.entrance,
                child: view.visible.isNotEmpty
                    ? const SizedBox(width: double.infinity)
                    : view.all.isEmpty
                    ? const _EmptyLibrary(key: ValueKey('empty'))
                    : _NoMatches(key: const ValueKey('no-match'), view: view),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _LibraryRows extends ConsumerWidget {
  const _LibraryRows({required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openSessionsProvider);
    return AnimatedLibrarySliver(
      entries: view.visible,
      itemBuilder: (context, entry) => LibraryRow(
        entry: entry,
        best: view.personalBestHeldBy(entry),
        isOpen: isEntryOpen(open, entry),
      ),
    );
  }
}

/// The library has nothing in it yet, though something is open or a folder
/// is remembered.
class _EmptyLibrary extends ConsumerWidget {
  const _EmptyLibrary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final supportsFolders = ref
        .watch(sessionFileSystemProvider)
        .supportsFolders;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SquircleCard(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.library_books_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                supportsFolders
                    ? 'Nothing indexed yet. Every session you open is '
                          'remembered here, and "Add folder" indexes a whole '
                          'folder of recordings at once.'
                    : 'Nothing indexed yet. Every session you upload during '
                          'this visit is listed here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filters that match nothing say which filters, and offer the way back.
class _NoMatches extends ConsumerWidget {
  const _NoMatches({super.key, required this.view});

  final LibraryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final query = view.query;
    final search = query.search.trim();
    final what = [
      if (search.isNotEmpty) '"$search"',
      if (query.activeFilterCount > 0)
        '${query.activeFilterCount} '
            '${query.activeFilterCount == 1 ? 'filter' : 'filters'}',
    ].join(' and ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 10),
          MixedNumeralText(
            'No session matches $what.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => ref.read(libraryFilterProvider.notifier).clear(),
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _IndexUnavailable extends StatelessWidget {
  const _IndexUnavailable({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SquircleCard(
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "The library index couldn't be opened. Sessions you open "
                  'still work, but they will not be remembered.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  '$error',
                  style: AppTextStyles.numeral.copyWith(
                    fontSize: 12,
                    color: scheme.onErrorContainer,
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

class _RowsSkeleton extends StatelessWidget {
  const _RowsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Skeleton(width: 40, height: 40),
                SizedBox(width: 16),
                Expanded(child: Skeleton(height: 18)),
                SizedBox(width: 40),
                Skeleton(width: 110, height: 18),
              ],
            ),
          ),
      ],
    );
  }
}

/// Wraps the whole screen so a file can be dropped anywhere on it, not just
/// onto the welcome card — once sessions are listed, the card is gone but
/// the gesture should still work.
class _DropZone extends ConsumerStatefulWidget {
  const _DropZone({required this.child});

  final Widget child;

  @override
  ConsumerState<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends ConsumerState<_DropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (detail) {
        setState(() => _hovering = false);
        ref.read(sessionImportProvider.notifier).openDroppedPaths([
          for (final file in detail.files) file.path,
        ]);
      },
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppDurations.fast),
        curve: AppCurves.standard,
        decoration: BoxDecoration(
          color: _hovering
              ? scheme.secondaryContainer.withValues(alpha: 0.16)
              : null,
          border: Border.all(
            color: _hovering ? scheme.secondary : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Nothing open, nothing indexed: the screen is an import surface.
class _WelcomeState extends ConsumerWidget {
  const _WelcomeState({super.key, required this.supportsFolders});

  final bool supportsFolders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final suggestion = ref.watch(suggestedTelemetryFolderProvider).value;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SquircleCard(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.upload_file_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Open a telemetry session',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Drop a Le Mans Ultimate .duckdb recording here, or browse '
                  'for one. Everything is read locally — nothing is uploaded.'
                  '${supportsFolders ? ' Sessions you open are remembered '
                            'in the library, and a whole folder can be indexed at '
                            'once.' : ''}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(sessionImportProvider.notifier).pickFile(),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Browse'),
                    ),
                    if (supportsFolders)
                      OutlinedButton.icon(
                        onPressed: () => suggestion != null
                            ? ref
                                  .read(folderScanProvider.notifier)
                                  .addAndScan(suggestion)
                            : ref
                                  .read(folderScanProvider.notifier)
                                  .pickAndScan(),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: Text(
                          suggestion != null
                              ? "Index LMU's telemetry folder"
                              : 'Add folder',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Windows-only by nature: LMU doesn't run on macOS or Linux,
                // so there is no local install to point at on those targets
                // (§5).
                Text(
                  suggestion != null
                      ? 'Found at $suggestion'
                      : 'On Windows, recordings are usually under\n'
                            r'Steam\steamapps\common\Le Mans Ultimate\UserData\Telemetry',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The import controller's errors and warnings, above everything else.
class _ImportBanner extends StatelessWidget {
  const _ImportBanner({required this.state});

  final SessionImportState state;

  @override
  Widget build(BuildContext context) {
    final state = this.state;
    final child = switch (state) {
      SessionImportFailure() => _ImportError(
        key: ValueKey(state),
        message: state.message,
        detail: state.detail,
      ),
      SessionImportSuccess(:final indexWarning?) => _ImportError(
        key: ValueKey(state),
        message: indexWarning,
        detail: indexWarning,
        warning: true,
      ),
      SessionImportBusy() => const LinearProgressIndicator(
        key: ValueKey('busy'),
        minHeight: 3,
      ),
      _ => const SizedBox(width: double.infinity),
    };
    return MotionSize(
      duration: AppDurations.medium,
      curve: AppCurves.entrance,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _ImportError extends ConsumerWidget {
  const _ImportError({
    super.key,
    required this.message,
    required this.detail,
    this.warning = false,
  });

  final String message;
  final String detail;
  final bool warning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final fg = warning ? scheme.onSecondaryContainer : scheme.onErrorContainer;
    // A Material rather than a plain coloured Container: the expandable
    // "Details" tile paints its ink on the nearest Material ancestor, so a
    // ColoredBox in between would swallow the splash and leave the control
    // looking inert.
    return Material(
      color: warning ? scheme.secondaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(
              warning ? Icons.warning_amber_outlined : Icons.error_outline,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: TextStyle(color: fg)),
                  // The cause is kept behind a disclosure rather than
                  // dropped: the headline is for the user, the detail is
                  // what makes a bug report actionable.
                  if (!warning)
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'Details',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: fg),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          SelectableText(
                            detail,
                            style: AppTextStyles.numeral.copyWith(
                              fontSize: 12,
                              color: fg,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              color: fg,
              onPressed: () =>
                  ref.read(sessionImportProvider.notifier).dismissError(),
            ),
          ],
        ),
      ),
    );
  }
}
