import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/design_system/design_system.dart';
import '../application/open_sessions.dart';
import '../application/session_import.dart';

/// Session Library (SPEC.md §8.1).
///
/// Phase 1 scope: import a file and open it. The persistent index, folder
/// watching, and track/car/class filters are Phase 2 (§9.6) — this screen is
/// deliberately the import surface first and a library second, since with no
/// index yet there is nothing to list across runs.
class SessionLibraryScreen extends ConsumerWidget {
  const SessionLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openSessionsProvider);
    final importState = ref.watch(sessionImportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
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
          children: [
            if (importState is SessionImportFailure)
              _ImportError(failure: importState),
            if (importState is SessionImportBusy)
              const LinearProgressIndicator(),
            Expanded(
              child: open.isEmpty
                  ? const _EmptyState()
                  : _SessionList(sources: open),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps the whole screen so a file can be dropped anywhere on it, not just
/// onto the empty-state card — once sessions are listed, the card is gone but
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
        duration: AppDurations.fast,
        curve: AppCurves.standard,
        decoration: BoxDecoration(
          color: _hovering
              ? scheme.primaryContainer.withValues(alpha: 0.16)
              : null,
          border: Border.all(
            color: _hovering ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
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
                'Drop a Le Mans Ultimate .duckdb recording here, or browse for '
                'one. Everything is read locally — nothing is uploaded.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(sessionImportProvider.notifier).pickFile(),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Browse'),
              ),
              const SizedBox(height: 16),
              // Windows-only by nature: LMU doesn't run on macOS or Linux, so
              // there is no local install to point at on those targets (§5).
              Text(
                'On Windows, recordings are usually under\n'
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
    );
  }
}

class _ImportError extends ConsumerWidget {
  const _ImportError({required this.failure});

  final SessionImportFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // A Material rather than a plain coloured Container: the expandable
    // "Details" tile paints its ink on the nearest Material ancestor, so a
    // ColoredBox in between would swallow the splash and leave the control
    // looking inert.
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failure.message,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                  // The cause is kept behind a disclosure rather than dropped:
                  // the headline is for the user, the detail is what makes a bug
                  // report actionable.
                  Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: Text(
                        'Details',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        SelectableText(
                          failure.detail,
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
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: scheme.onErrorContainer,
              onPressed: () =>
                  ref.read(sessionImportProvider.notifier).dismissError(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sources});

  final List<TelemetrySource> sources;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sources.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _SessionCard(source: sources[index]),
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metadata = ref.watch(sessionMetadataProvider(source));

    return Hoverable(
      onTap: () => context.go('/overview'),
      child: SquircleCard(
        child: AsyncValueView<SessionMetadata>(
          value: metadata,
          loading: (context) => const Row(
            children: [
              Expanded(child: Skeleton(height: 22)),
              SizedBox(width: 16),
              Skeleton(height: 22, width: 90),
            ],
          ),
          data: (context, meta) => Row(
            children: [
              _SessionTypeBadge(type: meta.sessionType),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.layoutIsDistinct
                          ? '${meta.trackName} — ${meta.trackLayout}'
                          : meta.trackName,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${meta.carName}  ·  ${meta.carClass}  ·  ${meta.driverName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _SessionBest(source: source),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionBest extends ConsumerWidget {
  const _SessionBest({required this.source});

  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laps = ref.watch(lapsProvider(source));
    return laps.maybeWhen(
      data: (laps) {
        final best = laps.bestLap;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatOptionalLapTime(best?.lapTimeSeconds),
              style: AppTextStyles.numeral.copyWith(
                fontSize: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(
              '${laps.timed.length} timed laps',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
      orElse: () => const Skeleton(height: 22, width: 90),
    );
  }
}

class _SessionTypeBadge extends StatelessWidget {
  const _SessionTypeBadge({required this.type});

  final SessionType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: ShapeDecoration(
        shape: AppRadii.squircle(AppRadii.sm),
        color: scheme.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        type.filenameCode,
        style: AppTextStyles.numeral.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
