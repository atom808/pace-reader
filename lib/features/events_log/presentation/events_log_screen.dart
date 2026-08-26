import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/telemetry_repository.dart';
import '../../../widgets/common/no_session_screen.dart';
import '../../../widgets/design_system/design_system.dart';
import '../../session_library/application/open_sessions.dart';

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
  });

  final EventLog log;
  final double origin;
  final List<Lap> laps;

  @override
  State<_EventsBody> createState() => _EventsBodyState();
}

class _EventsBodyState extends State<_EventsBody> {
  String _query = '';

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
    final visible = _visible;

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
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Filter by event',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Text(
                _countLabel(visible.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.log.truncated) _ClippedNotice(names: widget.log.clipped),
        const _HeaderRow(),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? _Empty(query: _query)
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
                ),
        ),
      ],
    );
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
  const _HeaderRow();

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
          Expanded(child: Text('Event', style: style)),
          SizedBox(
            width: _valueWidth,
            child: Text('Value', style: style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 16),
          SizedBox(width: _unitWidth, child: Text('Unit', style: style)),
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
              // Per-corner values stay in file order. §15's open question 5
              // is that the left/right assignment inside each axle is *not*
              // confirmed, so labelling these FL/FR/RL/RR would state
              // something the data has not established.
              event.values.map(formatEventValue).join('  ·  '),
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
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      query.trim().isEmpty
          ? 'This recording contains no events.'
          : 'No event matches "$query".',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
