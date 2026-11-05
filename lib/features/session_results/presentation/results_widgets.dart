/// The results index in the Session Library: its folder chip, the one-click
/// suggestion, and the glyph on a linked recording's row (results proposal,
/// R1).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/data/session_file_system.dart' show baseName;
import '../../session_library/presentation/library_formatting.dart';
import '../../session_library/presentation/library_widgets.dart';
import '../application/session_results.dart';
import '../domain/results_link.dart';

/// The glyph a results session wears everywhere in the app: a chequered
/// flag, since it is the session's timing sheet.
const resultsIcon = Icons.sports_score;

/// What the folder is, in the words every results tooltip starts with.
const _whatTheFolderIs =
    'LMU writes one results file here when each session ends: every car\'s '
    'laps and sectors, and race control\'s calls. Pace Reader reads them and '
    'links each to its recording. It never writes to this folder.';

/// Counts stay bare (`1054`), as the library's other counts are: in the
/// numeral face a thousands comma takes a full cell and reads `1, 054`.
String _count(int n) => '$n';

/// The last three segments — `…\Log\Results` — as the telemetry chips show
/// their last two.
String _shortPath(String path) {
  final list = path.split(RegExp(r'[\\/]')).where((p) => p.isNotEmpty).toList();
  if (list.length <= 2) return path;
  final sep = path.contains(r'\') ? r'\' : '/';
  return '…$sep${list[list.length - 2]}$sep${list.last}';
}

/// A remembered results folder: how many sessions it holds and when it was
/// read, or how far the reading has got. While a scan runs, the flag gives
/// way to a ring that fills with it.
class ResultsFolderChip extends ConsumerWidget {
  const ResultsFolderChip({super.key, required this.folder, required this.now});

  final LibraryFolder folder;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final scan = ref.watch(resultsScanProvider);
    final running = scan is ResultsScanRunning ? scan : null;
    final finished = scan is ResultsScanFinished ? scan.summary : null;
    final problems = finished?.failures.length ?? 0;

    final scanned = folder.lastScannedAt;
    final detail = running != null
        ? 'reading ${_count(running.done + 1)} of ${_count(running.total)}'
        : scanned == null
        ? 'not read yet'
        : '${_count(folder.lastScanFileCount ?? 0)} '
              '${folder.lastScanFileCount == 1 ? 'session' : 'sessions'}'
              ' · read ${formatRelative(scanned, now)}';

    final tooltip = [
      _whatTheFolderIs,
      folder.path,
      if (running != null) 'Now: ${running.currentFile}',
      if (problems > 0) ...[
        'Not read on the last pass, and tried again on the next:',
        for (final f in finished!.failures.take(5))
          '${f.fileName}: ${f.reason}',
        if (problems > 5) '…and ${problems - 5} more',
      ],
    ].join('\n');

    final duration = AppMotion.duration(context, AppDurations.medium);
    return AppTooltip(
      message: tooltip,
      child: InputChip(
        avatar: AnimatedSwitcher(
          duration: duration,
          switchInCurve: AppCurves.entrance,
          child: running != null
              ? SizedBox.square(
                  key: const ValueKey('ring'),
                  dimension: 14,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: running.progress),
                    duration: duration,
                    curve: AppCurves.standard,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 2,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                )
              : Icon(
                  resultsIcon,
                  key: const ValueKey('flag'),
                  size: 16,
                  color: problems > 0 ? scheme.error : null,
                ),
        ),
        label: MixedNumeralText(
          [
            _shortPath(folder.path),
            detail,
            if (running == null && problems > 0)
              '${_count(problems)} unreadable',
          ].join(' · '),
        ),
        // While reading, the ✕ stops the pass rather than forgetting the
        // folder. It is never absent: a chip with no action renders disabled,
        // and the progress is exactly when the label should be legible.
        deleteButtonTooltipMessage: running != null
            ? 'Stop reading (what was read stays)'
            : 'Stop reading this folder (what was read stays linked)',
        onDeleted: running != null
            ? () => ref.read(resultsScanProvider.notifier).stop()
            : () =>
                  ref.read(resultsFoldersProvider.notifier).remove(folder.path),
      ),
    );
  }
}

/// LMU's results folder, offered once it exists and isn't remembered.
class ResultsFolderSuggestion extends ConsumerWidget {
  const ResultsFolderSuggestion({super.key, required this.folder});

  final String folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(resultsScanProvider) is ResultsScanRunning;
    return AppTooltip(
      message: '$_whatTheFolderIs\n$folder',
      child: ActionChip(
        avatar: const Icon(Icons.add, size: 16),
        label: const Text("Add LMU's results"),
        onPressed: running
            ? null
            : () => ref.read(resultsScanProvider.notifier).addAndScan(folder),
      ),
    );
  }
}

/// On a library row: this recording's session is in a results file. Nothing
/// at all when it isn't, so an unlinked row looks as it always did.
class ResultsLinkGlyph extends ConsumerWidget {
  const ResultsLinkGlyph({super.key, required this.entry, this.color});

  final LibraryEntry entry;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(resultsLinkProvider(entry)).value;
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppDurations.medium),
      switchInCurve: AppCurves.entrance,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: link == null
          ? const SizedBox.shrink(key: ValueKey('none'))
          : Padding(
              key: ValueKey(link),
              padding: const EdgeInsets.only(left: 8),
              child: AppTooltip(
                message: describeResultsLink(link),
                child: Icon(
                  resultsIcon,
                  size: 14,
                  semanticLabel: 'In LMU\'s results',
                  color: color ?? Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
    );
  }
}

/// The glyph's tooltip: which file, and how sure.
String describeResultsLink(ResultsLink link) {
  final file = baseName(link.path);
  return switch (link.basis) {
    ResultsLinkBasis.lapTime =>
      'This session is in LMU\'s results ($file). The recording\'s best lap, '
          '${formatLapTime(link.matchedLapSeconds!)}, is the same lap in both '
          'files.',
    ResultsLinkBasis.timeOnly =>
      'Probably this session in LMU\'s results ($file). The recording has no '
          'timed lap, so it was matched on the car, the driver and the time '
          'only.',
  };
}
