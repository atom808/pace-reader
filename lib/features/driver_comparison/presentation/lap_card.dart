/// Base's and the Target's cards (comparison proposal §3, "Lap cards").
///
/// No live channel readouts: each panel's header already shows both laps at
/// the cursor, and a second copy would be a second place for the numbers to
/// disagree (§3; recorded as an amendment to §8.8 in step 12).
library;

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/presentation/library_formatting.dart';
import '../../telemetry_trace/application/lap_selection.dart';
import '../application/compare_laps.dart';
import '../application/comparison_workspace.dart';
import '../domain/comparison_set.dart';
import 'compare_actions.dart';
import 'lap_picker_sheet.dart';
import 'suggestion_list.dart';

/// One lap's card: which lap, whose, how fast, and what is odd about it.
class LapCard extends ConsumerWidget {
  const LapCard({super.key, required this.role, required this.set});

  final ComparisonRole role;
  final ComparisonSet set;

  LapRef? get _lap => role == ComparisonRole.base ? set.base : set.target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lap = _lap;
    return Semantics(
      container: true,
      label: role.label,
      child: SquircleCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        radius: AppRadii.md,
        // Base carries the ink edge (§4 Roles); the Target, the chrome every
        // card wears.
        border: role == ComparisonRole.base
            ? AppGradients.hairlineStrong
            : null,
        child: lap == null
            ? _EmptyTarget(set: set)
            : AsyncValueView<ComparableFile>(
                value: ref.watch(comparableFileProvider(lap.source)),
                loading: (context) => const SizedBox(height: 88),
                error: (context, error, _) =>
                    _CardError(role: role, message: '$error'),
                data: (context, file) =>
                    _CardBody(role: role, set: set, lap: lap, file: file),
              ),
      ),
    );
  }
}

class _CardBody extends ConsumerWidget {
  const _CardBody({
    required this.role,
    required this.set,
    required this.lap,
    required this.file,
  });

  final ComparisonRole role;
  final ComparisonSet set;
  final LapRef lap;
  final ComparableFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final meta = file.metadata;
    final shown = file.laps.where((l) => l.index == lap.lapIndex).firstOrNull;
    if (shown == null) {
      return _CardError(
        role: role,
        message: 'This file has no Lap ${lap.lapIndex + 1}.',
      );
    }
    final at = parseRecordingTime(meta.recordingTime);
    final flags = <String>[
      if (role == ComparisonRole.target && lap.source == set.base.source)
        'same file ✓'
      else if (role == ComparisonRole.target)
        ...?_sameRecording(ref),
      if (file.inPitLane(shown)) 'pit lane',
      if (_clockGapInLap(file.clockGaps, shown)) 'clock gap in this lap',
      if (shown.isOpenEnded)
        'incomplete'
      else if (shown.lapTimeSeconds == null)
        'no lap time',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _RoleMark(role: role),
            const SizedBox(width: 8),
            Text(
              role.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: muted,
              ),
            ),
            const Spacer(),
            _LapMenu(role: role, set: set, file: file),
            _MoreMenu(role: role, set: set, lap: lap),
          ],
        ),
        Text(
          '${meta.sessionType.rawValue} · '
          '${at == null ? meta.recordingTime : formatRecordedDate(at)} · '
          'Lap ${shown.displayNumber}',
          style: theme.textTheme.titleSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${meta.driverName} · ${meta.carName}',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatOptionalLapTime(shown.lapTimeSeconds),
              style: AppTextStyles.numeral.copyWith(
                fontSize: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            if (role == ComparisonRole.target)
              _Relation(set: set, target: shown),
            for (final flag in flags)
              Text(
                flag,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
          ],
        ),
      ],
    );
  }

  /// "same recording" when the Target is a copy of Base's recording in
  /// another file — the label RecordingIdentity exists for (§4).
  List<String>? _sameRecording(WidgetRef ref) {
    final base = ref.watch(comparableFileProvider(set.base.source)).value;
    if (base == null) return null;
    return base.metadata.recordingIdentity == file.metadata.recordingIdentity
        ? const ['same recording']
        : null;
  }
}

bool _clockGapInLap(List<ClockGap> gaps, Lap lap) {
  final end = lap.endSeconds ?? double.infinity;
  return gaps.any((g) {
    final at = g.atSeconds;
    return at != null && at > lap.startSeconds && at <= end;
  });
}

/// The Target's lap time in words against Base's — never a bare sign.
class _Relation extends ConsumerWidget {
  const _Relation({required this.set, required this.target});

  final ComparisonSet set;
  final Lap target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ref
        .watch(comparableFileProvider(set.base.source))
        .value
        ?.laps
        .where((l) => l.index == set.base.lapIndex)
        .firstOrNull;
    final a = base?.lapTimeSeconds;
    final b = target.lapTimeSeconds;
    if (a == null || b == null) return const SizedBox.shrink();
    final gap = a - b;
    final text = gap.abs() < 0.0005
        ? 'level with Base'
        : gap > 0
        ? '${gap.toStringAsFixed(3)} s quicker than Base'
        : '${(-gap).toStringAsFixed(3)} s slower than Base';
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

/// Base's filled dot, the Target's hollow ring — the shapes their cursor
/// marks take (§8).
class _RoleMark extends StatelessWidget {
  const _RoleMark({required this.role});

  final ComparisonRole role;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: role == ComparisonRole.base ? color : null,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

/// The other laps of the same file, one click away.
class _LapMenu extends ConsumerWidget {
  const _LapMenu({required this.role, required this.set, required this.file});

  final ComparisonRole role;
  final ComparisonSet set;
  final ComparableFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lap = role == ComparisonRole.base ? set.base : set.target!;
    final other = role == ComparisonRole.base ? set.target : set.base;
    final choices = [
      for (final l in file.laps)
        if (!isRecordingStart(file.laps, l) &&
            LapRef(lap.source, l.index) != other)
          l,
    ];
    return PopupMenuButton<int>(
      tooltip: 'Another lap of this file',
      icon: const Icon(Icons.format_list_numbered, size: 18),
      onSelected: (index) => chooseCompareLap(
        context,
        role: role,
        base: set.base,
        lap: LapRef(lap.source, index),
      ),
      itemBuilder: (context) => [
        for (final l in choices)
          CheckedPopupMenuItem(
            value: l.index,
            checked: l.index == lap.lapIndex,
            child: Text(
              'Lap ${l.displayNumber} · '
              '${l.isOpenEnded ? 'incomplete' : formatOptionalLapTime(l.lapTimeSeconds)}',
            ),
          ),
      ],
    );
  }
}

enum _MoreAction { pick, openInTrace, clear, clearAndClose }

class _MoreMenu extends ConsumerWidget {
  const _MoreMenu({required this.role, required this.set, required this.lap});

  final ComparisonRole role;
  final ComparisonSet set;
  final LapRef lap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_MoreAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_horiz, size: 18),
      onSelected: (action) async {
        final workspace = ref.read(comparisonWorkspaceProvider.notifier);
        switch (action) {
          case _MoreAction.pick:
            await showLapPicker(context, role: role, set: set);
          case _MoreAction.openInTrace:
            // The one action that makes a compared file current (§9).
            ref.read(openSessionsProvider.notifier).open(lap.source);
            ref
                .read(selectedLapIndexProvider(lap.source).notifier)
                .select(lap.lapIndex);
            if (context.mounted) context.go('/trace');
          case _MoreAction.clear:
            if (role == ComparisonRole.target) {
              workspace.clearTarget();
            } else {
              workspace.clear();
            }
          case _MoreAction.clearAndClose:
            await clearAndCloseCompareFile(ref, set: set, role: role);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _MoreAction.pick,
          child: Text('Pick a lap…'),
        ),
        const PopupMenuItem(
          value: _MoreAction.openInTrace,
          child: Text('Open in Trace'),
        ),
        PopupMenuItem(
          value: _MoreAction.clear,
          child: Text(
            role == ComparisonRole.target
                ? 'Clear'
                : 'Clear: follow the current session',
          ),
        ),
        if (canCloseCompareFile(ref, set: set, role: role))
          const PopupMenuItem(
            value: _MoreAction.clearAndClose,
            child: Text('Clear and close file'),
          ),
      ],
    );
  }
}

/// No Target yet: the card holds the suggestions (§3).
class _EmptyTarget extends StatelessWidget {
  const _EmptyTarget({required this.set});

  final ComparisonSet set;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _RoleMark(role: ComparisonRole.target),
            const SizedBox(width: 8),
            Text(
              'TARGET',
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  showLapPicker(context, role: ComparisonRole.target, set: set),
              child: const Text('Pick a lap…'),
            ),
          ],
        ),
        Text(
          'Choose a lap to compare Base against',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        SuggestionList(set: set, dense: true),
      ],
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.role, required this.message});

  final ComparisonRole role;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(role.label.toUpperCase(), style: theme.textTheme.labelSmall),
        const SizedBox(height: 4),
        Text(message, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
