/// The folder scan's progress and outcome (SPEC.md §8.1).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/design_system.dart';
import '../application/folder_scan.dart';
import 'library_formatting.dart';
import 'library_widgets.dart';

/// Shown while a scan runs and after it ends, until dismissed.
///
/// The outcome is spelled out file by file where anything went wrong: a
/// scan that says "12 indexed" of 13 recordings without naming the 13th is
/// the silent cap §9.5 rules out.
class ScanBanner extends ConsumerWidget {
  const ScanBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(folderScanProvider);
    final child = switch (state) {
      FolderScanIdle() => const SizedBox(width: double.infinity),
      FolderScanRunning() => _Running(
        key: const ValueKey('running'),
        state: state,
      ),
      FolderScanFinished(:final summary) => _Finished(
        key: const ValueKey('finished'),
        summary: summary,
      ),
      FolderScanFailed() => _Failed(
        key: const ValueKey('failed'),
        state: state,
      ),
    };
    return MotionSize(
      duration: AppDurations.medium,
      curve: AppCurves.entrance,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context, AppDurations.medium),
        switchInCurve: AppCurves.entrance,
        child: child,
      ),
    );
  }
}

class _Running extends ConsumerWidget {
  const _Running({super.key, required this.state});

  final FolderScanRunning state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: state.progress),
            duration: AppMotion.duration(context, AppDurations.medium),
            curve: AppCurves.standard,
            builder: (context, value, _) => LinearProgressIndicator(
              value: state.total == 0 ? null : value,
              minHeight: 3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.manage_search, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: MixedNumeralText(
                    state.total == 0
                        ? 'Looking for recordings…'
                        : 'Indexing ${state.done + 1} of ${state.total} · '
                              '${state.currentFile}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(folderScanProvider.notifier).stop(),
                  child: const Text('Stop'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({super.key, required this.summary});

  final FolderScanSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final problems = summary.hasProblems;
    final parts = [
      if (summary.added > 0) '${summary.added} new',
      if (summary.updated > 0) '${summary.updated} updated',
      if (summary.unchanged > 0) '${summary.unchanged} unchanged',
    ];
    final headline = summary.found == 0 && summary.unreadableFolders.isEmpty
        ? 'No .duckdb recordings in ${plural(summary.folders.length, 'folder')}.'
        : 'Scanned ${plural(summary.found, 'recording')}'
              '${parts.isEmpty ? '' : ': ${parts.join(', ')}'}.';
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: problems ? scheme.onErrorContainer : scheme.onSurfaceVariant,
    );

    return Material(
      color: problems
          ? scheme.errorContainer.withValues(alpha: 0.55)
          : scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                problems
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
                size: 18,
                color: problems ? scheme.onErrorContainer : scheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MixedNumeralText(headline),
                  for (final f in summary.failures)
                    MixedNumeralText(
                      "${f.fileName} wasn't added: ${f.reason}",
                      style: muted,
                    ),
                  for (final f in summary.unreadableFolders)
                    Text(
                      "${f.folder} couldn't be read: ${f.reason}",
                      style: muted,
                    ),
                  if (summary.notReached > 0)
                    MixedNumeralText(
                      'Stopped with ${plural(summary.notReached, 'file')} '
                      'not read — Refresh picks up where it left off.',
                      style: muted,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              iconSize: 18,
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(folderScanProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failed extends ConsumerWidget {
  const _Failed({super.key, required this.state});

  final FolderScanFailed state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Tooltip(
                message: state.detail,
                child: Text(
                  state.message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close),
              color: scheme.onErrorContainer,
              onPressed: () => ref.read(folderScanProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}
