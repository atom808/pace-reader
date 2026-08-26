// Widget tests for the Events Log (SPEC.md §8.12, §12).
//
// The values here are the ones actually read out of the Sebring Race sample,
// including the shapes that are easy to get wrong: a BOOLEAN event, a per-corner
// event, and a FLOAT whose 32-bit origin shows through when widened.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/providers.dart';
import 'package:pace_reader/features/events_log/presentation/events_log_screen.dart';
import 'package:pace_reader/features/session_library/application/open_sessions.dart';
import 'package:pace_reader/widgets/design_system/design_system.dart';

const _source = TelemetrySource.path('/fixture/sebring.duckdb');
const _origin = 23.5975;

class _FixedOpenSessions extends OpenSessions {
  @override
  List<TelemetrySource> build() => const [_source];
}

const _catalog = TelemetryCatalog(
  channels: [],
  events: [],
  masterRowCount: 134059,
  origin: _origin,
  endSeconds: 1364.18,
);

final _laps = [
  const Lap(
      index: 0,
      startSeconds: _origin,
      endSeconds: 195.82,
      sectors: SectorTimes()),
  const Lap(
      index: 1, startSeconds: 195.82, endSeconds: 260.32, sectors: SectorTimes()),
];

const _log = EventLog(events: [
  TelemetryEvent(
      name: 'Brake Bias Rear',
      unit: '',
      timeSeconds: _origin,
      values: [0.48750001192092896]),
  TelemetryEvent(name: 'Gear', unit: '', timeSeconds: 30.0, values: [3]),
  TelemetryEvent(name: 'ABS', unit: '', timeSeconds: 40.0, values: [true]),
  TelemetryEvent(
      name: 'SurfaceTypes',
      unit: '',
      timeSeconds: 200.0,
      values: [0, 0, 1, 1]),
]);

Future<void> _pump(
  WidgetTester tester, {
  EventLog log = _log,
  Size size = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        openSessionsProvider.overrideWith(() => _FixedOpenSessions()),
        telemetryCatalogProvider(_source).overrideWith((ref) async => _catalog),
        lapsProvider(_source).overrideWith((ref) async => _laps),
        sessionEventLogProvider(_source).overrideWith((ref) async => log),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const EventsLogScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each change with its value as recorded', (tester) async {
    await _pump(tester);

    // The clock starts at the file's origin, not at the raw ts.
    expect(find.text('0:00.000'), findsOneWidget);
    expect(find.text('0:06.402'), findsOneWidget);
    expect(find.text('2:56.403'), findsOneWidget);

    // A boolean stays a boolean — this view is what the others get checked
    // against, so 1 would be a lie about the column's type.
    expect(find.text('true'), findsOneWidget);
    // A 32-bit float does not get to show its widening noise.
    expect(find.text('0.4875'), findsOneWidget);
    expect(find.textContaining('0.48750001'), findsNothing);
    // Per-corner values stay on one row, unlabelled — §15's open question 5
    // means FL/FR/RL/RR would be a claim the data has not settled.
    expect(find.text('0  ·  0  ·  1  ·  1'), findsOneWidget);
  });

  testWidgets('attributes each change to the lap it happened on',
      (tester) async {
    await _pump(tester);
    // Three changes on lap 0, one at 200 s which is inside lap 1.
    expect(find.text('0'), findsNWidgets(3));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('filtering narrows to one signal and says so', (tester) async {
    await _pump(tester);
    expect(find.text('4 changes across 4 events'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'gear');
    await tester.pumpAndSettle();

    expect(find.text('Gear'), findsOneWidget);
    expect(find.text('ABS'), findsNothing);
    expect(find.text('1 of 4 changes'), findsOneWidget);
  });

  testWidgets('a filter matching nothing says which filter', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.textContaining('No event matches "zzz"'), findsOneWidget);
  });

  testWidgets('a clipped read names what was clipped', (tester) async {
    // §9.5's no-silent-caps rule: showing a prefix without saying so tells the
    // reader something false about the recording.
    await _pump(
      tester,
      log: const EventLog(events: [], clipped: ['SurfaceTypes', 'TC']),
    );
    expect(find.textContaining('SurfaceTypes, TC'), findsOneWidget);
    expect(find.textContaining('holds more'), findsOneWidget);
  });

  testWidgets('with no session open it offers a way out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EventsLogScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No session open'), findsOneWidget);
    expect(find.textContaining('the events log'), findsOneWidget);
  });
}
