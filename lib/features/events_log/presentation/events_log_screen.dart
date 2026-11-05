import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/telemetry_repository.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../lap_analysis/presentation/incident_marks.dart';
import '../../session_library/application/open_sessions.dart';
import '../../session_results/application/linked_results.dart';
import '../../session_results/domain/race_control.dart';

/// Events Log (SPEC.md §8.12).
///
/// A direct window onto the 42 event tables — no derivation, no curation. Its
/// second job is the one §8.12 names explicitly: it is the view that says what
/// the file actually contains, which is what every *other* screen's numbers get
/// checked against. That makes faithfulness the design constraint. Values keep
/// the types they were recorded in (`true`, not `1`), per-corner readings stay
/// on one row, and nothing is hidden — the only transformation applied is
/// subtracting the file's origin so the clock starts at zero (§5.2).
class EventsLogScreen extends ConsumerWidget {
  const EventsLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(currentSessionProvider);
    if (source == null) {
      return const NoSessionScreen(title: 'Events', subject: 'the events log');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: AsyncValueView<EventLog>(
        value: ref.watch(sessionEventLogProvider(source)),
        data: (context, log) => _EventsBody(
          log: log,
          origin: ref.watch(telemetryCatalogProvider(source)).value?.origin ?? 0,
          laps: ref.watch(lapsProvider(source)).value ?? const [],
          raceControl: ref.watch(sessionRaceControlProvider(source)).value,
        ),
      ),
    );
  }
}

class _EventsBody extends StatefulWidget {
  const _EventsBody({
    required this.log,
    required this.origin,
    required this.laps,
    required this.raceControl,
  });

  final EventLog log;
  final double origin;
  final List<Lap> laps;

  /// Race control's calls about this car, from LMU's results file (results
  /// proposal, R3); null when no file links, which hides the toggle.
  final SessionRaceControl? raceControl;

  @override
  State<_EventsBody> createState() => _EventsBodyState();
}

class _EventsBodyState extends State<_EventsBody> {
  String _query = '';

  /// Showing race control's calls rather than the recording's events.
  bool _calls = false;

  bool get _showingCalls => _calls && widget.raceControl != null;

  /// Matched against the call's sentence: there is no name to narrow to,
  /// and the sentence is short enough that a match is visible.
  List<RaceControlCall> get _visibleCalls {
    final calls = widget.raceControl?.calls ?? const <RaceControlCall>[];
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return calls;
    return calls
        .where((c) => c.sentence.toLowerCase().contains(needle))
        .toList();
  }

  /// Matched against the event's name only.
  ///
  /// Not against the value: "0" would match most of the log, and a substring
  /// search over formatted numbers finds things for reasons the reader can't
  /// see. Narrowing to a signal is the operation this view is actually for.
  List<TelemetryEvent> get _visible {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return widget.log.events;
    return widget.log.events
        .where((e) => e.name.toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calls = _showingCalls;
    final visible = calls ? const <TelemetryEvent>[] : _visible;
    final visibleCalls = calls ? _visibleCalls : const <RaceControlCall>[];

    final Widget list;
    if (calls) {
      list = visibleCalls.isEmpty
          ? _Empty(
              query: _query,
              noun: 'call',
              none: 'Race control made no call about this car.',
            )
          : ListView.builder(
              itemCount: visibleCalls.length,
              itemExtent: 34,
              itemBuilder: (context, index) => StaggeredEntrance(
                index: index.clamp(0, 12),
                child: _CallRow(
                  call: visibleCalls[index],
                  origin: widget.origin,
                  lap: widget.laps.lapAt(visibleCalls[index].elapsed),
                ),
              ),
            );
    } else {
      list = visible.isEmpty
          ? _Empty(
              query: _query,
              noun: 'event',
              none: 'This recording contains no events.',
            )
          // Builder rather than a DataTable: the log runs to 20,304 rows
          // on the Sebring sample and a DataTable materialises every row
          // it is given, filter or no filter.
          : ListView.builder(
              itemCount: visible.length,
              itemExtent: 34,
              itemBuilder: (context, index) => _EventRow(
                event: visible[index],
                origin: widget.origin,
                lap: widget.laps.lapAt(visible[index].timeSeconds),
              ),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              if (widget.raceControl != null)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.sensors, size: 18),
                      label: Text('Recording'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.gavel, size: 18),
                      label: Text('Race control'),
                    ),
                  ],
                  selected: {calls},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    shape: WidgetStatePropertyAll(
                      AppRadii.squircle(AppRadii.sm),
                    ),
                  ),
                  onSelectionChanged: (selection) =>
                      setState(() => _calls = selection.first),
                ),
              SizedBox(
                width: 280,
                child: TextField(
                  // No `border:` here on purpose. A bare
                  // `OutlineInputBorder()` overrode the theme with Material's
                  // 4px circular default, which is the one shape in the app
                  // that was neither a token radius nor a squircle
                  // (§9.7.2) — the theme's [SquircleInputBorder] is the
                  // right answer for every field, so no field states one.
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: calls ? 'Filter calls' : 'Filter by event',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Text(
                calls
                    ? _callCountLabel(visibleCalls.length)
                    : _countLabel(visible.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (!calls && widget.log.truncated)
          _ClippedNotice(names: widget.log.clipped),
        _HeaderRow(calls: calls),
        const Divider(height: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppDurations.medium),
            switchInCurve: AppCurves.entrance,
            child: KeyedSubtree(key: ValueKey(calls), child: list),
          ),
        ),
      ],
    );
  }

  String _callCountLabel(int shown) {
    final total = widget.raceControl?.calls.length ?? 0;
    if (shown == total) {
      return '$total ${total == 1 ? 'call' : 'calls'} in LMU’s results file';
    }
    return '$shown of $total calls';
  }

  String _countLabel(int shown) {
    final total = widget.log.events.length;
    final events = widget.log.names.length;
    if (shown == total) return '$total changes across $events events';
    return '$shown of $total changes';
  }
}

/// Column widths, shared by the header and every row so they stay aligned
/// without a Table's all-rows-at-once layout.
const _timeWidth = 96.0;
const _lapWidth = 56.0;
const _valueWidth = 200.0;
const _unitWidth = 72.0;
const _rowPadding = EdgeInsets.symmetric(horizontal: 24);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.calls});

  /// Race control's columns rather than the recording's.
  final bool calls;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: _rowPadding.add(const EdgeInsets.only(bottom: 8)),
      child: Row(
        children: [
          SizedBox(
            width: _timeWidth,
            child: Text('Time', style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _lapWidth,
            child: Text('Lap', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(calls ? 'Call' : 'Event', style: style)),
          SizedBox(
            width: _valueWidth,
            child: Text(
              calls ? 'Contact size' : 'Value',
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _unitWidth,
            child: Text(calls ? 'Kind' : 'Unit', style: style),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.origin,
    required this.lap,
  });

  final TelemetryEvent event;
  final double origin;
  final Lap? lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13);

    return Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          SizedBox(
            width: _timeWidth,
            child: Text(
              formatSessionTime(event.timeSeconds, origin: origin),
              style: numeral,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _lapWidth,
            child: Text(
              lap == null ? '—' : '${lap!.index}',
              style: numeral.copyWith(color: muted),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              event.name,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: _valueWidth,
            child: Text(
              formatEventValues(event.values),
              overflow: TextOverflow.ellipsis,
              style: numeral,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _unitWidth,
            child: Text(
              event.unit,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// One race-control call, in the recording's columns: the time and lap on
/// the recording's clock (the results file's `et` is that clock), the call
/// as a sentence, and for a contact the game's magnitude.
class _CallRow extends StatelessWidget {
  const _CallRow({required this.call, required this.origin, required this.lap});

  final RaceControlCall call;
  final double origin;
  final Lap? lap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final numeral = AppTextStyles.numeral.copyWith(fontSize: 13);
    final kind = incidentKindKey(switch (call.kind) {
      RaceControlKind.trackLimits => IncidentKind.trackLimits,
      RaceControlKind.contact => IncidentKind.contact,
      RaceControlKind.penalty => IncidentKind.penalty,
      RaceControlKind.damage => IncidentKind.damage,
    });

    return Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          SizedBox(
            width: _timeWidth,
            child: Text(
              formatSessionTime(call.elapsed, origin: origin),
              style: numeral,
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: _lapWidth,
            child: Text(
              lap == null ? '—' : '${lap!.index}',
              style: numeral.copyWith(color: muted),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 16),
          Icon(
            kind.icon,
            size: 16,
            color: raceControlColor(scheme, call.severity),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              call.sentence,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: _valueWidth,
            child: call.magnitude == null
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerRight,
                    child: AppTooltip(
                      message: _sizeExplanation(call),
                      child: Text(
                        call.magnitude!.toStringAsFixed(1),
                        style: numeral,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: _unitWidth,
            child: Text(
              kind.text,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }

  static String _sizeExplanation(RaceControlCall call) {
    final target = call.contactTarget ?? '';
    final (median, p90) =
        contactPercentiles[target.startsWith('another vehicle')
            ? 'another vehicle'
            : target] ??
        contactPercentilesAll;
    return 'The game’s contact magnitude, in its own unit. Against every '
        'contact of this kind in your results files, half are under '
        '${median.toStringAsFixed(0)} and one in ten is over '
        '${p90.toStringAsFixed(0)}: light, firm and heavy split there.';
  }
}

class _ClippedNotice extends StatelessWidget {
  const _ClippedNotice({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Text(
        'Showing the first '
        '${TelemetryRepository.defaultMaxRowsPerEvent} changes of '
        '${names.join(', ')} — this recording holds more.',
        style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 13),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.query,
    required this.noun,
    required this.none,
  });

  final String query;

  /// What a row is: `event` or `call`.
  final String noun;

  /// What to say when there is nothing to filter.
  final String none;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      query.trim().isEmpty ? none : 'No $noun matches "$query".',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// An event's values as the log shows them: one value bare, a per-corner
/// four labelled by wheel.
///
/// Labelled since §15.5 was resolved (§5.3: `value1..value4` are FL, FR, RL,
/// RR, by wheel-speed kinematics, tyre heat and wear, and roll). Before that
/// the four stayed in file order unlabelled, because a corner name would have
/// stated something the data had not established; the order itself was
/// always the file's.
String formatEventValues(List<Object?> values) {
  if (values.length != Corner.values.length) {
    return values.map(formatEventValue).join('  ·  ');
  }
  return [
    for (final corner in Corner.values)
      '${corner.short} ${formatEventValue(values[corner.index])}',
  ].join('  ');
}
