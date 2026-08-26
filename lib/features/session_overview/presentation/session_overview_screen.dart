import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';

/// Session Overview (SPEC.md §8.2).
class SessionOverviewScreen extends ConsumerWidget {
  const SessionOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) return const NoSessionScreen(title: 'Overview');

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: AsyncValueView<SessionMetadata>(
        value: ref.watch(sessionMetadataProvider(source)),
        data: (context, metadata) =>
            _Overview(metadata: metadata, source: source),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.metadata, required this.source});

  final SessionMetadata metadata;
  final TelemetrySource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final laps = ref.watch(lapsProvider(source));
    final catalog = ref.watch(telemetryCatalogProvider(source));
    final gaps = ref.watch(sessionClockGapsProvider(source));

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Header(metadata: metadata),
        const SizedBox(height: 20),
        // Absent until the scan has actually run, rather than optimistically
        // absent — "no gaps found" and "not looked yet" are different claims.
        if (gaps.value case final found? when found.isNotEmpty) ...[
          _ClockGapNotice(gaps: found),
          const SizedBox(height: 20),
        ],
        laps.when(
          loading: () => const _StatSkeletons(),
          error: (error, _) => Text('Could not read laps: \$error'),
          data: (laps) => _Stats(
            laps: laps,
            recordedSeconds: catalog.value?.recordedSeconds,
            originSeconds: catalog.value?.origin,
          ),
        ),
        const SizedBox(height: 20),
        _Conditions(metadata: metadata),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.metadata});

  final SessionMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SquircleCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metadata.trackName, style: theme.textTheme.headlineMedium),
          if (metadata.layoutIsDistinct) ...[
            const SizedBox(height: 4),
            // Shown as its own line rather than folded into the track name:
            // the layout can halve the lap length (§8.1), so it's a fact about
            // the session, not a subtitle.
            Text(metadata.trackLayout,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.primary)),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Chip(label: metadata.sessionType.rawValue, icon: Icons.flag_outlined),
              _Chip(label: metadata.carClass, icon: Icons.category_outlined),
              _Chip(label: metadata.carName, icon: Icons.directions_car_outlined),
              _Chip(label: metadata.driverName, icon: Icons.person_outline),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.laps,
    required this.recordedSeconds,
    required this.originSeconds,
  });

  final List<Lap> laps;
  final double? recordedSeconds;
  final double? originSeconds;

  @override
  Widget build(BuildContext context) {
    final best = laps.bestLap;
    final theoretical = laps.theoreticalBestSeconds;
    final consistency = laps.consistencyStdDevSeconds;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatCard(
          label: 'Best lap',
          value: formatOptionalLapTime(best?.lapTimeSeconds),
          caption: best == null ? 'no timed lap' : 'lap ${best.displayNumber}',
          emphasised: true,
        ),
        _StatCard(
          label: 'Theoretical best',
          value: formatOptionalLapTime(theoretical),
          // Null whenever any sector was never recorded, which happens on real
          // sessions (§8.3.1) — worth saying rather than showing a dash alone.
          caption: theoretical == null
              ? 'a sector was never recorded'
              : 'best sectors combined',
        ),
        _StatCard(
          label: 'Completed laps',
          // `COUNT(*)` on the Lap table counts lap *starts*, so the completed
          // figure is one fewer (§5.2/§8.2). Both are shown because "19 of 20"
          // is the honest description of a recording that stopped mid-lap.
          value: '${laps.completedCount}',
          caption: '${laps.length} started · ${laps.timed.length} timed',
        ),
        _StatCard(
          label: 'Consistency',
          value: consistency == null ? '—' : '±${consistency.toStringAsFixed(3)}',
          caption: consistency == null
              ? 'needs two timed laps'
              : 'std. dev. of timed laps',
        ),
        _StatCard(
          label: 'Recording',
          value: recordedSeconds == null
              ? '—'
              : formatSessionDuration(recordedSeconds!),
          caption: originSeconds == null
              ? 'reading…'
              : 'from ${formatSessionDuration(originSeconds!)} '
                  'on the telemetry clock',
        ),
      ],
    );
  }
}

/// §15.12 asks for discontinuities to be surfaced rather than absorbed: a gap
/// is invisible to a row-index clock, so a session containing one is a session
/// whose timing depends on the master-clock derivation being right.
class _ClockGapNotice extends StatelessWidget {
  const _ClockGapNotice({required this.gaps});

  final List<ClockGap> gaps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lost = gaps.fold<double>(0, (sum, gap) => sum + gap.lostSeconds);
    return SquircleCard(
      color: scheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(Icons.timer_off_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gaps.length == 1
                      ? 'This recording has 1 discontinuity'
                      : 'This recording has ${gaps.length} discontinuities',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lost.toStringAsFixed(2)} s of telemetry is missing. Times '
                  'are read from the recording clock, so they stay correct '
                  'across the gap.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Conditions extends StatelessWidget {
  const _Conditions({required this.metadata});

  final SessionMetadata metadata;

  @override
  Widget build(BuildContext context) {
    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _Row(label: 'Weather', value: metadata.weatherConditions),
          // Named "time of day" rather than "session time": the raw key is
          // `SessionTime` and reads like a duration, but it is a clock time.
          _Row(label: 'Started at', value: metadata.sessionTimeOfDay),
          _Row(label: 'Recorded', value: metadata.recordingTime),
          _Row(label: 'Format version', value: metadata.version),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.caption,
    this.emphasised = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: SquircleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              value,
              // Tabular figures so these hold their width as values change
              // (§9.7.7) — the reason JetBrains Mono is bundled at all.
              style: AppTextStyles.numeral.copyWith(
                fontSize: 26,
                color: emphasised ? theme.colorScheme.primary : null,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 6),
              Text(caption!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatSkeletons extends StatelessWidget {
  const _StatSkeletons();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(width: 220, child: Skeleton(height: 104, radius: AppRadii.lg)),
        SizedBox(width: 220, child: Skeleton(height: 104, radius: AppRadii.lg)),
        SizedBox(width: 220, child: Skeleton(height: 104, radius: AppRadii.lg)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
