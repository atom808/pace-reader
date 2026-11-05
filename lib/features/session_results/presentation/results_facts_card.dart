/// "Session results" on the Overview: what LMU's results file says about the
/// session this recording was made in (results proposal, R4).
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/data/session_file_system.dart' show baseName;
import '../../session_library/presentation/library_widgets.dart';
import '../application/linked_results.dart';
import '../application/session_results.dart';
import '../domain/results_facts.dart';
import '../domain/results_session.dart';
import 'results_widgets.dart';

/// Nothing at all until a results folder has been added, so a user who never
/// adds one sees the Overview exactly as before. With one, either the facts
/// or a sentence saying no file matched.
class ResultsFactsCard extends ConsumerWidget {
  const ResultsFactsCard({super.key, required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(resultsFoldersProvider).value ?? const [];
    final linked = ref.watch(linkedResultsProvider(source));
    final duration = AppMotion.duration(context, AppDurations.slow);

    final Widget child;
    if (folders.isEmpty) {
      child = const SizedBox.shrink(key: ValueKey('off'));
    } else if (linked.isLoading && !linked.hasValue) {
      child = const Skeleton(
        key: ValueKey('loading'),
        height: 160,
        radius: AppRadii.lg,
      );
    } else if (linked.value case final results?) {
      child = ResultsFactsPanel(
        key: ValueKey(results.link),
        session: results.session,
        car: results.car,
        path: results.link.path,
        matchedHow: describeResultsLink(results.link),
      );
    } else {
      child = const _NoMatch(key: ValueKey('none'));
    }

    return AnimatedSize(
      duration: duration,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: AppCurves.entrance,
        child: child,
      ),
    );
  }
}

/// The facts themselves: for a recording's linked file on the Overview, or
/// a timing-only session's own (results proposal, R5).
class ResultsFactsPanel extends StatelessWidget {
  const ResultsFactsPanel({
    super.key,
    required this.session,
    required this.car,
    required this.path,
    this.matchedHow,
  });

  final ResultsSession session;
  final ResultsDriver car;

  /// The results file.
  final String path;

  /// How the recording was matched to the file, for the ⓘ; null shows none.
  final String? matchedHow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final facts = resultsFactsOf(session, car);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SquircleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(resultsIcon, size: 20, color: scheme.secondary),
                const SizedBox(width: 10),
                Text('Session results', style: theme.textTheme.titleMedium),
                if (matchedHow case final how?) ...[
                  const SizedBox(width: 8),
                  AppTooltip(
                    message: how,
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                      semanticLabel: 'How this was matched',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'From LMU\'s results file ${baseName(path)}',
              style: muted,
            ),
            const SizedBox(height: 12),
            for (final (i, fact) in facts.indexed)
              StaggeredEntrance(
                index: i,
                child: _FactRow(fact: fact),
              ),
          ],
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final ResultsFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      fact.label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: fact.detail == null
                ? label
                : AppTooltip(
                    message: fact.detail!,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: label),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.info_outline,
                          size: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: MixedNumeralText(
              fact.value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SquircleCard(
        child: Row(
          children: [
            Icon(resultsIcon, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No LMU results file matches this recording. The game writes '
                'one when a session ends, so a session left early, or one '
                'whose file has not been read yet (Refresh in Sessions), has '
                'none here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
