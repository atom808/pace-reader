/// A session known only from LMU's results file (results proposal, R5): the
/// Overview it can have without a recording — facts, laps with sectors,
/// fuel and tyres, the class's pace, and race control's calls.
library;

import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../../widgets/identity/car_label.dart';
import '../../../widgets/identity/game_mark_view.dart';
import '../../lap_analysis/presentation/incident_marks.dart';
import '../../session_library/presentation/library_formatting.dart';
import '../../session_library/presentation/library_widgets.dart'
    show MixedNumeralText;
import '../application/timing_session.dart';
import '../domain/field_pace.dart';
import '../domain/race_control.dart';
import '../domain/results_session.dart';
import 'field_cars_list.dart';
import 'results_facts_card.dart';
import 'results_widgets.dart';

class TimingSessionScreen extends ConsumerWidget {
  const TimingSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openTimingSessionProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/sessions')),
        title: const Text('Timing only'),
      ),
      body: open == null
          ? const _Gone()
          : AsyncValueView<TimingSession?>(
              value: ref.watch(
                timingSessionProvider(open.path, open.driverName),
              ),
              loading: (_) => const _PageSkeleton(),
              data: (context, timing) =>
                  timing == null ? const _Gone() : _Page(timing: timing),
            ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.timing});

  final TimingSession timing;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _Header(timing: timing),
      const _Notice(),
      _Stats(timing: timing),
      ResultsFactsPanel(
        session: timing.session,
        car: timing.car,
        path: timing.path,
      ),
      _LapsCard(timing: timing),
      if (timing.pace.classSize > 1) _FieldCard(pace: timing.pace),
      if (timing.calls.isNotEmpty) _CallsCard(timing: timing),
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final (i, section) in sections.indexed)
          StaggeredEntrance(
            index: i,
            child: Padding(
              // The facts panel brings its own gap, as it does on the Overview.
              padding: EdgeInsets.only(
                bottom: section is ResultsFactsPanel ? 0 : 20,
              ),
              child: section,
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.timing});

  final TimingSession timing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = timing.session;
    final car = timing.car;
    final layoutIsDistinct =
        s.trackCourse.isNotEmpty && s.trackCourse != s.trackVenue;
    final type = switch (s.kind) {
      ResultsSessionKind.practice => 'Practice',
      ResultsSessionKind.qualify => 'Qualify',
      ResultsSessionKind.race => 'Race',
      ResultsSessionKind.other => s.sessionElement,
    };
    return SquircleCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.trackVenue, style: theme.textTheme.headlineMedium),
                    if (layoutIsDistinct) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.trackCourse,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              CircuitLogo(trackName: s.trackVenue, trackLayout: s.trackCourse),
            ],
          ),
          const SizedBox(height: 20),
          CarLabel.of(car.vehicleName, car.carClass, size: CarLabelSize.hero),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(
                avatar: const Icon(Icons.flag_outlined, size: 18),
                label: Text(type),
              ),
              Chip(
                avatar: const Icon(Icons.person_outline, size: 18),
                label: Text(car.name),
              ),
              Chip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: MixedNumeralText(
                  '${formatRecordedDate(s.startedAt)} · '
                  '${formatRecordedTime(s.startedAt)}',
                ),
              ),
              Chip(
                avatar: Icon(resultsIcon, size: 18),
                label: const Text('Timing only'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'No recording was made in this session, so this is LMU’s own timing: '
      'laps, sectors, fuel and tyres as its results file gives them, the '
      'class’s pace, and race control’s calls. The views that read telemetry '
      'have nothing to show for it.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.timing});

  final TimingSession timing;

  @override
  Widget build(BuildContext context) {
    final me = timing.pace.me;
    final pace = timing.pace;
    final bestNumber = me.paceLaps.entries
        .where((e) => e.value == me.best)
        .firstOrNull
        ?.key;
    final tiles = <Widget>[
      StatTile(
        label: 'Best lap',
        value: formatOptionalLapTime(me.best),
        caption: bestNumber == null ? 'no valid lap' : 'lap $bestNumber',
        emphasised: true,
      ),
      StatTile(
        label: 'Typical lap',
        value: formatOptionalLapTime(me.typical),
        caption: me.typical == null
            ? 'no valid lap'
            : 'median of ${me.paceLaps.length} valid laps',
      ),
      if (pace.typicalRank case final rank? when pace.classSize > 1)
        StatTile(
          label: 'In class',
          value: '${ordinal(rank)} of ${pace.classSize}',
          caption: 'on typical lap · best lap ${ordinal(pace.bestRank!)}',
        ),
      StatTile(
        label: 'Laps',
        value: '${timing.car.lapsCompleted}',
        caption:
            '${timing.car.laps.where((l) => l.lapSeconds != null).length} '
            'timed · ${timing.car.pitStops} '
            '${timing.car.pitStops == 1 ? 'stop' : 'stops'}',
      ),
    ];
    return Wrap(spacing: 16, runSpacing: 16, children: tiles);
  }
}

/// Column widths, shared by the header and the rows.
abstract final class _Col {
  static const lap = 44.0;
  static const time = 96.0;
  static const sector = 80.0;
  static const share = 76.0;
}

class _LapsCard extends StatelessWidget {
  const _LapsCard({required this.timing});

  final TimingSession timing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final head = theme.textTheme.labelSmall?.copyWith(color: muted);
    final laps = timing.laps;
    final hasEnergy = timing.car.laps.any((l) => l.energyUsedFraction != null);
    final hasWear = timing.car.laps.any((l) => l.wearFrontLeft != null);

    Widget header(String text, double width, {String? tip}) {
      final label = Text(text, style: head, textAlign: TextAlign.right);
      return SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerRight,
          child: tip == null ? label : AppTooltip(message: tip, child: label),
        ),
      );
    }

    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Laps', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'As LMU’s results file gives them. Fuel and energy are the share '
            'of the tank and of the allowance each lap used; tread is what '
            'was left, averaged over the four tyres.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          // Wide enough for every column, scrolled sideways on a narrow
          // window rather than squeezed.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: _Col.lap,
                        child: Text('Lap', style: head),
                      ),
                      header('Time', _Col.time),
                      header('S1', _Col.sector),
                      header('S2', _Col.sector),
                      header('S3', _Col.sector),
                      header('Fuel', _Col.share, tip: 'Share of the tank used'),
                      if (hasEnergy)
                        header(
                          'Energy',
                          _Col.share,
                          tip: 'Share of the energy allowance used',
                        ),
                      if (hasWear)
                        header(
                          'Tread',
                          _Col.share,
                          tip: 'Tread left, the four tyres averaged',
                        ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 360,
                        child: Text('Incidents', style: head),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  for (final lap in laps)
                    _LapRow(
                      lap: lap,
                      results: timing.resultsLap(lap),
                      calls: timing.callsByLap[lap.index] ?? const [],
                      fastest:
                          lap.lapTimeSeconds != null &&
                          lap.lapTimeSeconds == timing.pace.me.best,
                      hasEnergy: hasEnergy,
                      hasWear: hasWear,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LapRow extends StatelessWidget {
  const _LapRow({
    required this.lap,
    required this.results,
    required this.calls,
    required this.fastest,
    required this.hasEnergy,
    required this.hasWear,
  });

  final Lap lap;
  final ResultsLap results;
  final List<RaceControlCall> calls;
  final bool fastest;
  final bool hasEnergy;
  final bool hasWear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final numeral = AppTextStyles.numeral.copyWith(
      fontSize: 13,
      color: fastest ? scheme.tertiary : scheme.onSurface,
    );
    final muted = numeral.copyWith(color: scheme.onSurfaceVariant);
    String share(double? f) =>
        f == null ? '—' : '${(f * 100).toStringAsFixed(1)} %';
    Widget cell(String text, double width, {TextStyle? style}) => SizedBox(
      width: width,
      child: Text(text, style: style ?? numeral, textAlign: TextAlign.right),
    );
    final r = results;
    final wear = [
      r.wearFrontLeft,
      r.wearFrontRight,
      r.wearRearLeft,
      r.wearRearRight,
    ].nonNulls.toList();
    final tread = wear.isEmpty
        ? null
        : wear.reduce((a, b) => a + b) / wear.length;
    final marks = raceControlMarks(scheme, lap, calls);
    final notes = [
      if (r.pit) 'pit',
      if (r.lapSeconds != null && !r.hasAllSectors) 'not valid',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: _Col.lap,
            child: Text('${lap.displayNumber}', style: muted),
          ),
          cell(
            r.lapSeconds == null ? '—' : formatLapTime(r.lapSeconds!),
            _Col.time,
            style: r.hasAllSectors ? null : muted,
          ),
          cell(_sector(r.sector1Seconds), _Col.sector),
          cell(_sector(r.sector2Seconds), _Col.sector),
          cell(_sector(r.sector3Seconds), _Col.sector),
          cell(share(r.fuelUsedFraction), _Col.share, style: muted),
          if (hasEnergy)
            cell(share(r.energyUsedFraction), _Col.share, style: muted),
          if (hasWear)
            AppTooltip(
              message: wear.length < 4
                  ? 'Tread left'
                  : 'Tread left — FL ${share(r.wearFrontLeft)}, '
                        'FR ${share(r.wearFrontRight)}, '
                        'RL ${share(r.wearRearLeft)}, '
                        'RR ${share(r.wearRearRight)}',
              child: cell(share(tread), _Col.share, style: muted),
            ),
          const SizedBox(width: 24),
          SizedBox(
            width: 360,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final m in marks) _MarkBadge(mark: m),
                for (final n in notes)
                  Text(
                    n,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _sector(double? s) =>
      s == null ? '—' : formatLapTime(s).replaceFirst(RegExp(r'^0:'), '');
}

class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark});

  final IncidentMark mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppTooltip(
      message: mark.tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: ShapeDecoration(
          shape: AppRadii.squircle(8),
          color: mark.color.withValues(alpha: 0.14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mark.icon, size: 13, color: mark.color),
            const SizedBox(width: 4),
            Text(
              mark.label,
              style: theme.textTheme.labelSmall?.copyWith(color: mark.color),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.pace});

  final FieldPace pace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The whole class when it is short, the five fastest otherwise.
    final cars = pace.classSize <= 8
        ? pace.classCars
        : pace.classCars.take(5).toList();
    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Class pace', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: FieldCarsList(pace: pace, cars: cars),
          ),
        ],
      ),
    );
  }
}

class _CallsCard extends StatelessWidget {
  const _CallsCard({required this.timing});

  final TimingSession timing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13);
    int? lapOf(RaceControlCall c) {
      for (final MapEntry(:key, :value) in timing.callsByLap.entries) {
        if (value.contains(c)) return key + 1;
      }
      return null;
    }

    return SquircleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Race control', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final call in timing.calls)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      formatLapTime(call.elapsed),
                      style: numeral,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      switch (lapOf(call)) {
                        final n? => 'lap $n',
                        null => '',
                      },
                      style: numeral.copyWith(color: muted),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    incidentKindKey(switch (call.kind) {
                      RaceControlKind.trackLimits => IncidentKind.trackLimits,
                      RaceControlKind.contact => IncidentKind.contact,
                      RaceControlKind.penalty => IncidentKind.penalty,
                      RaceControlKind.damage => IncidentKind.damage,
                    }).icon,
                    size: 16,
                    color: raceControlColor(scheme, call.severity),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      call.sentence,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resultsIcon,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'This results file is no longer in the index.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => context.go('/sessions'),
            child: const Text('Back to Sessions'),
          ),
        ],
      ),
    );
  }
}

/// The cards the page will show, and only those.
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Skeleton(height: 220, radius: AppRadii.lg),
        SizedBox(height: 56),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 220,
              child: Skeleton(height: 104, radius: AppRadii.lg),
            ),
            SizedBox(
              width: 220,
              child: Skeleton(height: 104, radius: AppRadii.lg),
            ),
            SizedBox(
              width: 220,
              child: Skeleton(height: 104, radius: AppRadii.lg),
            ),
            SizedBox(
              width: 220,
              child: Skeleton(height: 104, radius: AppRadii.lg),
            ),
          ],
        ),
        SizedBox(height: 20),
        Skeleton(height: 300, radius: AppRadii.lg),
        SizedBox(height: 20),
        Skeleton(height: 400, radius: AppRadii.lg),
      ],
    );
  }
}
