/// Choosing Base's or the Target's lap (comparison proposal §3, "Lap
/// picker").
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';
import '../../session_library/application/session_library.dart';
import '../../session_library/data/library_entry.dart';
import '../../session_library/presentation/library_formatting.dart';
import '../application/compare_laps.dart';
import '../application/comparison_workspace.dart';
import '../domain/comparability.dart';
import '../domain/comparison_set.dart';
import 'compare_actions.dart';
import 'suggestion_list.dart';

/// Opens the picker for [role]'s lap of [set].
Future<void> showLapPicker(
  BuildContext context, {
  required ComparisonRole role,
  required ComparisonSet set,
}) => showDialog<void>(
  context: context,
  builder: (context) => LapPickerSheet(role: role, set: set),
);

/// The picker: suggestions, then every file of Base's course, open ones
/// first, each with its laps.
///
/// The course is fixed — Base's (§3: "course: … (fixed)"). The library lists
/// only files of Base's track and layout; other layouts of the track appear
/// disabled, never silently missing, so two courses of one track are never
/// confused. A library file's length is checked when it is expanded, by a
/// brief read that opens and closes it.
class LapPickerSheet extends ConsumerWidget {
  const LapPickerSheet({super.key, required this.role, required this.set});

  final ComparisonRole role;
  final ComparisonSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final base = ref.watch(comparableFileProvider(set.base.source));
    final open = ref.watch(openSessionsProvider);
    final library = ref.watch(sessionLibraryProvider).value ?? const [];

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 760),
        child: AsyncValueView<ComparableFile>(
          value: base,
          data: (context, baseFile) {
            final meta = baseFile.metadata;
            final otherOpen = [
              for (final s in open)
                if (s != set.base.source) s,
            ];
            final sameCourse = <LibraryEntry>[];
            final otherCourses = <LibraryEntry>[];
            for (final e in library) {
              if (e.kind != LibrarySourceKind.file ||
                  e.trackName != meta.trackName ||
                  open.contains(TelemetrySource.path(e.path))) {
                continue;
              }
              (e.trackLayout == meta.trackLayout ? sameCourse : otherCourses)
                  .add(e);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose the ${role.label} lap',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Course: ${meta.layoutIsDistinct ? meta.trackLayout : meta.trackName}'
                              '${baseFile.course.wrapLength == null ? '' : ' · ${baseFile.course.wrapLength!.toStringAsFixed(2)} m'}'
                              ' (fixed by Base)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (kIsWeb)
                        const _Notice(
                          'Comparing laps from two files works in the '
                          'Windows app. On the web, pick another lap of '
                          'this file.',
                        ),
                      if (role == ComparisonRole.target && !kIsWeb) ...[
                        const _SectionTitle('Suggested'),
                        SuggestionList(
                          set: set,
                          onChosen: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const _SectionTitle('This file'),
                      _FileTile(
                        source: set.base.source,
                        role: role,
                        set: set,
                        baseFile: baseFile,
                        initiallyExpanded: true,
                      ),
                      if (!kIsWeb && otherOpen.isNotEmpty) ...[
                        const _SectionTitle('Open now'),
                        for (final source in otherOpen)
                          _FileTile(
                            source: source,
                            role: role,
                            set: set,
                            baseFile: baseFile,
                            initiallyExpanded:
                                set.target?.source == source ||
                                (role == ComparisonRole.base &&
                                    set.base.source == source),
                          ),
                      ],
                      if (!kIsWeb && sameCourse.isNotEmpty) ...[
                        const _SectionTitle('Library'),
                        for (final entry in sameCourse)
                          _FileTile(
                            source: TelemetrySource.path(entry.path),
                            entry: entry,
                            role: role,
                            set: set,
                            baseFile: baseFile,
                          ),
                      ],
                      if (!kIsWeb && otherCourses.isNotEmpty) ...[
                        _SectionTitle(
                          'Other layouts of this track '
                          "(can't be compared by distance yet)",
                        ),
                        for (final entry in otherCourses)
                          _OtherCourseRow(entry: entry),
                      ],
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// A file of another layout of Base's track: listed, never pickable.
class _OtherCourseRow extends StatelessWidget {
  const _OtherCourseRow({required this.entry});

  final LibraryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      enabled: false,
      dense: true,
      leading: Icon(Icons.block, size: 18, color: muted),
      title: Text(
        '${entry.trackLayout} · ${entry.sessionType.rawValue} · '
        '${entry.recordedAt == null ? entry.recordingTime : formatRecordedDate(entry.recordedAt!)}',
      ),
      subtitle: Text(
        'A different layout: the comparison by distance needs the '
        'whole-lap centre-line check of a later version.',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
    );
  }
}

/// One file and, expanded, its laps — checked against Base's course first.
class _FileTile extends ConsumerWidget {
  const _FileTile({
    required this.source,
    required this.role,
    required this.set,
    required this.baseFile,
    this.entry,
    this.initiallyExpanded = false,
  });

  final TelemetrySource source;
  final LibraryEntry? entry;
  final ComparisonRole role;
  final ComparisonSet set;
  final ComparableFile baseFile;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final entry = this.entry;
    final title = entry == null
        ? _OpenFileTitle(source: source)
        : Text(
            '${entry.driverName} · ${entry.sessionType.rawValue} · '
            '${entry.recordedAt == null ? entry.recordingTime : formatRecordedDate(entry.recordedAt!)}',
          );
    final subtitle = entry == null
        ? null
        : Text(
            '${entry.carName} · ${entry.carClass} · best '
            '${formatOptionalLapTime(entry.bestLapSeconds)}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          );
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: title,
        subtitle: subtitle,
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _FileLaps(source: source, role: role, set: set, baseFile: baseFile),
        ],
      ),
    );
  }
}

class _OpenFileTitle extends ConsumerWidget {
  const _OpenFileTitle({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(comparableFileProvider(source)).value;
    if (file == null) return Text(source.label);
    final meta = file.metadata;
    final at = parseRecordingTime(meta.recordingTime);
    return Text(
      '${meta.driverName} · ${meta.sessionType.rawValue} · '
      '${at == null ? meta.recordingTime : formatRecordedDate(at)} · '
      'best ${formatOptionalLapTime(file.laps.bestLap?.lapTimeSeconds)}',
    );
  }
}

class _FileLaps extends ConsumerWidget {
  const _FileLaps({
    required this.source,
    required this.role,
    required this.set,
    required this.baseFile,
  });

  final TelemetrySource source;
  final ComparisonRole role;
  final ComparisonSet set;
  final ComparableFile baseFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AsyncValueView<ComparableFile>(
      value: ref.watch(comparableFileProvider(source)),
      error: (context, error, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text('This file could not be read: $error'),
      ),
      data: (context, file) {
        final course = CourseCheck.of(
          base: baseFile.metadata,
          baseCourse: baseFile.course,
          target: file.metadata,
          targetCourse: file.course,
          sameFile: source == set.base.source,
        );
        if (course.refuses) {
          return Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.block,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Not comparable: ${course.reason}.')),
              ],
            ),
          );
        }
        final best = file.laps.bestLap;
        final other = role == ComparisonRole.base ? set.target : set.base;
        final current = role == ComparisonRole.base ? set.base : set.target;
        return Column(
          children: [
            const _LapRowHeader(),
            for (final lap in file.laps)
              _LapRow(
                lap: lap,
                best: best,
                file: file,
                selected: current == LapRef(source, lap.index),
                disabledReason: isRecordingStart(file.laps, lap)
                    ? "out lap: the recording's first lap"
                    : other == LapRef(source, lap.index)
                    ? 'this is ${role == ComparisonRole.base ? 'the Target' : "Base's"} '
                          'Lap ${lap.displayNumber} again'
                    : null,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  final chosen = await chooseCompareLap(
                    context,
                    ref,
                    role: role,
                    base: set.base,
                    lap: LapRef(source, lap.index),
                  );
                  if (chosen && navigator.mounted) navigator.pop();
                },
              ),
          ],
        );
      },
    );
  }
}

const _lapColumns = [56.0, 84.0, 72.0, 64.0, 64.0, 64.0];

class _LapRowHeader extends StatelessWidget {
  const _LapRowHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    const labels = ['Lap', 'Time', 'Δ best', 'S1', 'S2', 'S3'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            SizedBox(
              width: _lapColumns[i],
              child: Text(labels[i], style: style),
            ),
          Expanded(child: Text('Note', style: style)),
        ],
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({
    required this.lap,
    required this.best,
    required this.file,
    required this.selected,
    required this.disabledReason,
    required this.onTap,
  });

  final Lap lap;
  final Lap? best;
  final ComparableFile file;
  final bool selected;
  final String? disabledReason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = disabledReason == null;
    final numeral = AppTextStyles.numeral.copyWith(
      fontSize: 12,
      color: enabled ? null : scheme.onSurfaceVariant,
    );
    final seconds = lap.lapTimeSeconds;
    final notes = [
      ?disabledReason,
      if (enabled && file.inPitLane(lap)) 'pit lane',
      if (enabled && lap.isOpenEnded) 'incomplete',
      if (enabled && !lap.isOpenEnded && seconds == null) 'no lap time',
      if (identical(lap, best)) 'file best',
    ];
    final sectors = lap.sectors.all;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: selected
            ? BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: _lapColumns[0],
              child: Text('${lap.displayNumber}', style: numeral),
            ),
            SizedBox(
              width: _lapColumns[1],
              child: Text(formatOptionalLapTime(seconds), style: numeral),
            ),
            SizedBox(
              width: _lapColumns[2],
              child: Text(
                seconds == null || best?.lapTimeSeconds == null
                    ? '—'
                    : formatDelta(seconds - best!.lapTimeSeconds!),
                style: numeral,
              ),
            ),
            for (var i = 0; i < 3; i++)
              SizedBox(
                width: _lapColumns[3 + i],
                child: Text(
                  formatOptionalSectorTime(sectors[i]),
                  style: numeral,
                ),
              ),
            Expanded(
              child: Text(
                notes.join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
