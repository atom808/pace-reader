/// Suggested Targets (comparison proposal §4), as the empty Target card, the
/// column beside it and the picker list them.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/presentation/library_formatting.dart';
import '../application/target_suggestions.dart';
import '../domain/comparison_set.dart';
import 'compare_actions.dart';

class SuggestionList extends ConsumerWidget {
  const SuggestionList({
    super.key,
    required this.set,
    this.onChosen,
    this.dense = false,
  });

  final ComparisonSet set;

  /// Called after a suggestion became the Target — the picker closes itself.
  final VoidCallback? onChosen;

  /// One line per suggestion, for the narrow column beside the cards.
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final suggestions = ref.watch(targetSuggestionsProvider(set));
    return suggestions.when(
      loading: () => const SizedBox(height: 24),
      error: (error, _) => Text(
        'No suggestions: $error',
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Text(
            'No faster lap of this course in the library yet.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in list)
              _SuggestionRow(
                suggestion: s,
                dense: dense,
                onTap: () async {
                  final chosen = await chooseCompareLap(
                    context,
                    ref,
                    role: ComparisonRole.target,
                    base: set.base,
                    lap: s.lap,
                  );
                  if (chosen) onChosen?.call();
                },
              ),
          ],
        );
      },
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.suggestion,
    required this.dense,
    required this.onTap,
  });

  final TargetSuggestion suggestion;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final s = suggestion;
    final entry = s.entry;
    final when = entry?.recordedAt;
    final title = switch (s.kind) {
      SuggestionKind.librarySession =>
        '${entry!.sessionType.rawValue} · '
            '${when == null ? entry.recordingTime : formatRecordedDate(when)} '
            '· Lap ${s.lap.lapIndex + 1}',
      SuggestionKind.personalBest => 'Your PB here · Lap ${s.lap.lapIndex + 1}',
      SuggestionKind.fileBest =>
        'Fastest of this file · Lap ${s.lap.lapIndex + 1}',
    };
    final detail = [
      if (s.gapSeconds > 0)
        '${s.gapSeconds.toStringAsFixed(3)} s quicker'
      else if (s.gapSeconds < 0)
        '${(-s.gapSeconds).toStringAsFixed(3)} s slower',
      if (s.kind != SuggestionKind.fileBest)
        s.sameCar ? 'same car' : '${entry!.carName} · ${entry.carClass}',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: dense ? 4 : 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (s.tooFast)
                    Text(
                      '${s.gapSeconds.toStringAsFixed(1)} s faster: most '
                      'segments will read as losses',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatLapTime(s.lapSeconds),
              style: AppTextStyles.numeral.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
