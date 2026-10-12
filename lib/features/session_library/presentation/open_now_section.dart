/// "Open now": the sessions open in this run (SPEC.md §8.1).
library;

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/design_system/design_system.dart';
// Closing a file Compare uses asks first. The one place this feature reaches
// into Compare: the workspace names the files it uses, so there is no second
// registry of them here to drift out of step.
import '../../driver_comparison/presentation/compare_close_guard.dart';
import '../application/open_sessions.dart';
import 'library_widgets.dart';

/// Every open session as a card, the current one lit.
///
/// Separate from the library list rather than a filter over it, because the
/// two answer different questions: this is "what can I switch to right now
/// without reading a file", the library is "what have I ever recorded". A
/// session appears in both, and that is correct.
class OpenNowSection extends ConsumerWidget {
  const OpenNowSection({super.key, required this.sources});

  final List<TelemetrySource> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentSessionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibrarySectionHeader(
          title: 'Open now',
          count: sources.length,
          caption:
              'This run only. Closing one frees its memory; the library '
              'keeps it.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            // Three across at 1280 px, two at ~1000, never narrower than a
            // card can hold its best-lap numeral.
            const gap = 14.0;
            final columns = (constraints.maxWidth / 340).floor().clamp(1, 4);
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final source in sources)
                  SizedBox(
                    key: ValueKey(source),
                    width: width,
                    child: OpenSessionCard(
                      source: source,
                      isCurrent: source == current,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One open session.
///
/// Tapping it makes it current *and then* navigates. The Phase 1 card only
/// navigated, so with two sessions open, tapping the second showed the
/// first — every feature screen reads `currentSessionProvider`, which is the
/// front of the open list, and a tap never moved anything to the front.
class OpenSessionCard extends ConsumerWidget {
  const OpenSessionCard({
    super.key,
    required this.source,
    required this.isCurrent,
  });

  final TelemetrySource source;
  final bool isCurrent;

  void _activate(BuildContext context, WidgetRef ref) {
    ref.read(openSessionsProvider.notifier).open(source);
    context.go('/overview');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metadata = ref.watch(sessionMetadataProvider(source));

    // Hoverable is the Tab stop: it brings the click cursor, Enter/Space
    // activation, button semantics and the keyboard focus ring (§9.7.6), so a
    // second focus wrapper here would make every card two stops.
    return Semantics(
      selected: isCurrent,
      child: Hoverable(
        onTap: () => _activate(context, ref),
        child: SquircleCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          // Lit when current: the same "this one is the subject" edge the
          // selected nav slot wears.
          border: isCurrent ? AppGradients.hairlineStrong : null,
          child: AsyncValueView<SessionMetadata>(
            value: metadata,
            loading: (context) => const _CardSkeleton(),
            data: (context, meta) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SessionTypeBadge(type: meta.sessionType, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.trackName,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (meta.layoutIsDistinct)
                            Text(
                              meta.trackLayout,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 2),
                          MixedNumeralText(
                            '${meta.carName} · ${meta.carClass}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close session',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          closeSessionChecked(context, ref, source),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _CardBest(source: source)),
                      AnimatedSwitcher(
                        duration: AppMotion.duration(
                          context,
                          AppDurations.medium,
                        ),
                        switchInCurve: AppCurves.entrance,
                        child: isCurrent
                            ? const _CurrentTag(key: ValueKey('current'))
                            : const SizedBox.shrink(key: ValueKey('other')),
                      ),
                    ],
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

class _CardBest extends ConsumerWidget {
  const _CardBest({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ref
        .watch(lapsProvider(source))
        .maybeWhen(
          data: (laps) {
            final best = laps.bestLap;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatOptionalLapTime(best?.lapTimeSeconds),
                  style: AppTextStyles.numeral.copyWith(
                    fontSize: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                MixedNumeralText(
                  best == null
                      ? 'no timed lap'
                      : 'best · lap ${best.displayNumber} · '
                            '${laps.timed.length} timed laps',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
          orElse: () => const Align(
            alignment: Alignment.centerLeft,
            child: Skeleton(height: 22, width: 120),
          ),
        );
  }
}

class _CurrentTag extends StatelessWidget {
  const _CurrentTag({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          // A squircle, not a circle: nothing in the app rounds into one
          // (§9.7.2), a status dot included.
          decoration: ShapeDecoration(
            color: scheme.primary,
            shape: AppRadii.squircle(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Current',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: scheme.primary),
        ),
      ],
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Skeleton(height: 40, width: 40),
              SizedBox(width: 12),
              Expanded(child: Skeleton(height: 18)),
            ],
          ),
          SizedBox(height: 16),
          Skeleton(height: 22, width: 120),
        ],
      ),
    );
  }
}
