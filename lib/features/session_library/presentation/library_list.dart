/// The library's rows (SPEC.md §8.1).
library;

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/car_label.dart';
import '../application/library_query.dart';
import '../application/session_import.dart';
import '../application/session_library.dart';
import '../data/library_entry.dart';
import 'library_formatting.dart';
import 'library_widgets.dart';

/// Column widths shared by the header and every row, so the numbers line
/// up down the list the way a timing screen's do.
abstract final class _Columns {
  static const badge = 40.0;
  static const recorded = 118.0;
  static const laps = 96.0;
  static const best = 118.0;
  static const actions = 44.0;
}

/// Labels over the row columns, so every figure is readable as what it is
/// without hovering anything.
class LibraryHeaderRow extends StatelessWidget {
  const LibraryHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      letterSpacing: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          const SizedBox(width: _Columns.badge + 16),
          Expanded(child: Text('SESSION', style: style)),
          SizedBox(
            width: _Columns.recorded,
            child: Text('RECORDED', style: style),
          ),
          SizedBox(
            width: _Columns.laps,
            child: Text('LAPS', style: style),
          ),
          SizedBox(
            width: _Columns.best,
            child: Text('BEST LAP', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

/// A [SliverAnimatedList] that diffs its entries by path.
///
/// Rows grow in as a folder scan finds them, collapse out when removed, and
/// a filter change does both at once — the rows that stop matching fold
/// away while the new matches unfold in their place, which is what makes a
/// chip tap read as the list *changing* rather than being replaced.
///
/// Falls back to an instant rebuild when the surviving rows change order
/// (a re-read that moved a session's recording time), since animating a
/// reorder as removals and insertions would show rows that never left.
class AnimatedLibrarySliver extends StatefulWidget {
  const AnimatedLibrarySliver({
    super.key,
    required this.entries,
    required this.itemBuilder,
  });

  final List<LibraryEntry> entries;
  final Widget Function(BuildContext context, LibraryEntry entry) itemBuilder;

  @override
  State<AnimatedLibrarySliver> createState() => _AnimatedLibrarySliverState();
}

class _AnimatedLibrarySliverState extends State<AnimatedLibrarySliver> {
  var _listKey = GlobalKey<SliverAnimatedListState>();
  late List<LibraryEntry> _items = [...widget.entries];

  Duration get _duration => AppMotion.duration(context, AppDurations.medium);

  @override
  void didUpdateWidget(AnimatedLibrarySliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.entries;
    final list = _listKey.currentState;
    if (list == null) {
      _items = [...next];
      return;
    }

    final nextPaths = {for (final e in next) e.path};
    for (var i = _items.length - 1; i >= 0; i--) {
      if (nextPaths.contains(_items[i].path)) continue;
      final removed = _items.removeAt(i);
      list.removeItem(
        i,
        (context, animation) => _Exit(
          animation: animation,
          child: widget.itemBuilder(context, removed),
        ),
        duration: _duration,
      );
    }

    final kept = {for (final e in _items) e.path};
    final keptOrder = [
      for (final e in next)
        if (kept.contains(e.path)) e.path,
    ];
    if (!_samePaths(keptOrder, _items)) {
      setState(() {
        _items = [...next];
        _listKey = GlobalKey<SliverAnimatedListState>();
      });
      return;
    }

    for (var j = 0; j < next.length; j++) {
      if (j < _items.length && _items[j].path == next[j].path) {
        _items[j] = next[j];
      } else {
        _items.insert(j, next[j]);
        list.insertItem(j, duration: _duration);
      }
    }
  }

  static bool _samePaths(List<String> paths, List<LibraryEntry> entries) {
    if (paths.length != entries.length) return false;
    for (var i = 0; i < paths.length; i++) {
      if (paths[i] != entries[i].path) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      itemBuilder: (context, index, animation) => _Enter(
        animation: animation,
        child: KeyedSubtree(
          key: ValueKey(_items[index].path),
          child: widget.itemBuilder(context, _items[index]),
        ),
      ),
    );
  }
}

class _Enter extends StatelessWidget {
  const _Enter({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppCurves.entrance,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

class _Exit extends StatelessWidget {
  const _Exit({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppCurves.standard,
    );
    // Not interactive on the way out: a row that is leaving must not take a
    // click meant for the one sliding up into its place.
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: curved,
        alignment: AlignmentDirectional.topStart,
        child: FadeTransition(opacity: curved, child: child),
      ),
    );
  }
}

/// One indexed session.
///
/// Everything on it comes from the index, never from the file, so a
/// session whose recording has since moved still shows what it was — and
/// says, in words and with its own action, that the file is gone.
class LibraryRow extends ConsumerWidget {
  const LibraryRow({
    super.key,
    required this.entry,
    required this.best,
    required this.isOpen,
  });

  final LibraryEntry entry;

  /// Non-null when this session holds its scope's personal best.
  final PersonalBest? best;

  /// Open in this run — the row says so, since reopening it is then free.
  final bool isOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(libraryFileStatusProvider(entry)).value;
    final missing = status == LibraryFileStatus.missing;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final recorded = entry.recordedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        customBorder: AppRadii.squircle(AppRadii.md),
        hoverColor: scheme.onSurface.withValues(alpha: 0.04),
        focusColor: scheme.secondary.withValues(alpha: 0.14),
        // Tappable even when the row says the file is missing: the status is
        // a snapshot taken when the row was built, and a file put back since
        // should be reachable without a rescan. Reopening checks the disk
        // afresh and, if the file really is gone, says so by name.
        onTap: () => _open(context, ref),
        child: AnimatedOpacity(
          duration: AppMotion.duration(context, AppDurations.medium),
          opacity: missing ? 0.72 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                SessionTypeBadge(type: entry.sessionType, size: _Columns.badge),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    // Keeps the last thing on the file line ("1 clock gap")
                    // off the recorded-date column at ~1000 px.
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                entry.circuitLabel,
                                style: theme.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOpen) ...[
                              const SizedBox(width: 8),
                              _Tag(label: 'open', color: scheme.primary),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        CarLabel.of(
                          entry.carName,
                          entry.carClass,
                          trailing: [entry.driverName],
                          style: muted,
                        ),
                        const SizedBox(height: 2),
                        _FileLine(entry: entry, status: status),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: _Columns.recorded,
                  child: recorded == null
                      ? MixedNumeralText(entry.recordingTime, style: muted)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            MixedNumeralText(
                              formatRecordedDate(recorded),
                              style: theme.textTheme.bodyMedium,
                            ),
                            MixedNumeralText(
                              formatRecordedTime(recorded),
                              style: muted,
                            ),
                          ],
                        ),
                ),
                SizedBox(
                  width: _Columns.laps,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MixedNumeralText(
                        plural(entry.completedLaps, 'lap'),
                        style: theme.textTheme.bodyMedium,
                      ),
                      MixedNumeralText(
                        '${entry.timedLaps} timed',
                        style: muted,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _Columns.best,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatOptionalLapTime(entry.bestLapSeconds),
                        style: AppTextStyles.numeral.copyWith(
                          fontSize: 16,
                          color: best != null ? scheme.tertiary : null,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (best != null) ...[
                            PersonalBestBadge(entry: entry, best: best!),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: MixedNumeralText(
                              entry.bestLapNumber == null
                                  ? 'no timed lap'
                                  : 'lap ${entry.bestLapNumber}',
                              style: muted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: _Columns.actions,
                  child: _RowMenu(entry: entry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final opened = await ref
        .read(sessionImportProvider.notifier)
        .openFromLibrary(entry);
    if (opened) router.go('/overview');
  }
}

/// The file line: name and size, or what is wrong with the file.
class _FileLine extends ConsumerWidget {
  const _FileLine({required this.entry, required this.status});

  final LibraryEntry entry;
  final LibraryFileStatus? status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faint = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
    );
    final (icon, message, color) = switch (status) {
      LibraryFileStatus.missing => (
        Icons.link_off,
        'File not found — moved, renamed or deleted since it was indexed',
        scheme.error,
      ),
      LibraryFileStatus.changed => (
        Icons.sync,
        'Changed on disk since it was indexed — re-read when opened',
        scheme.secondary,
      ),
      LibraryFileStatus.notOnDisk => (
        Icons.cloud_upload_outlined,
        'Uploaded this visit — a browser cannot reopen it by path',
        scheme.onSurfaceVariant,
      ),
      _ => (null, null, null),
    };
    final gaps = entry.clockGapCount;
    // When the user last looked at it — §9.6 keeps the stamp, and a library
    // of fifty recordings is easier to navigate by "the one from yesterday".
    final opened = entry.lastOpenedAt;
    final fileText = [
      entry.fileName,
      formatFileSize(entry.sizeBytes),
      if (opened != null)
        'opened ${formatRelative(opened, ref.watch(libraryClockProvider)())}',
    ].join(' · ');

    return FadeOnChange(
      // The file itself, or which problem it has.
      value: message == null ? null : status,
      duration: AppMotion.duration(context, AppDurations.medium),
      child: message == null
          ? Row(
              children: [
                Flexible(
                  child: MixedNumeralText(
                    fileText,
                    style: faint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (gaps > 0) ...[
                  const SizedBox(width: 8),
                  AppTooltip(
                    message:
                        'The recording clock jumps '
                        '${plural(gaps, 'time')}. Timing after a jump is '
                        'read from the clock itself, not counted from rows.',
                    child: MixedNumeralText(
                      plural(gaps, 'clock gap'),
                      style: faint?.copyWith(color: scheme.secondary),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message,
                    style: faint?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Row actions. A missing file gets its one useful action as a visible
/// button rather than behind a menu, since it is the only thing left to do
/// with the row.
class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing =
        ref.watch(libraryFileStatusProvider(entry)).value ==
        LibraryFileStatus.missing;
    if (missing) {
      return IconButton(
        tooltip: 'Remove from library (the file is already gone)',
        icon: const Icon(Icons.delete_sweep_outlined, size: 20),
        onPressed: () => removeFromLibrary(context, ref, entry),
      );
    }
    return PopupMenuButton<void>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz, size: 20),
      itemBuilder: (context) => [
        PopupMenuItem(
          onTap: () => removeFromLibrary(context, ref, entry),
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.playlist_remove, size: 20),
            title: Text('Remove from library'),
            subtitle: Text('The file itself is not touched'),
          ),
        ),
      ],
    );
  }
}

/// Forgets [entry] and offers to undo it.
///
/// No confirmation dialog: removing a row loses nothing that the file can't
/// give back, and an undo is cheaper for the user than a question.
Future<void> removeFromLibrary(
  BuildContext context,
  WidgetRef ref,
  LibraryEntry entry,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final library = ref.read(sessionLibraryProvider.notifier);
  await library.remove(entry.path);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          'Removed ${entry.fileName} from the library. The file was not '
          'touched.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => library.record(entry),
        ),
      ),
    );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(8),
        color: color.withValues(alpha: 0.16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Whether [entry] is open in this run.
///
/// Matched on the canonical path, so a recording opened from a drop as
/// `c:\…` still shows as open on a row the index holds as `C:\…`.
bool isEntryOpen(List<TelemetrySource> open, LibraryEntry entry) => open.any(
  (s) => switch (s) {
    FileTelemetrySource() =>
      entry.kind == LibrarySourceKind.file &&
          s.canonicalPath == canonicalSessionPath(entry.path),
    BytesTelemetrySource(:final name) =>
      entry.kind == LibrarySourceKind.upload && name == entry.path,
  },
);
