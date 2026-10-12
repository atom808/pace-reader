// The comparison core (comparison proposal §9, step 2).
//
// What Compare needs from the chart layer before it has a screen of its own:
// a reference lap from any file, bounds that show all of a slower reference
// on the Time axis, and one shared cursor that knows whose lap it is on.
//
// Fed by the two real Sebring fixture laps — lap 2 (index 1, 1:04.497) and
// lap 4 (index 3, 1:04.030).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

const _race = TelemetrySource.path('/fixture/sebring.duckdb');

/// Another recording of the same course: the fixture laps served again from a
/// second file, which is all the chart layer can tell apart.
const _other = TelemetrySource.path('/fixture/sebring_other_session.duckdb');

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      for (final source in [_race, _other]) ...[
        lapTelemetryProvider(source, sebringLapIndex)
            .overrideWith((ref) async => sebringLapTelemetry()),
        lapTelemetryProvider(source, sebringLap3Index)
            .overrideWith((ref) async => sebringLap3Telemetry()),
      ],
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<LapChart> _chart(
  ProviderContainer container, {
  required LapRef base,
  LapRef? target,
}) async {
  final provider = FutureProvider.autoDispose<LapChart>(
    (ref) => buildComparisonChart(ref, base: base, target: target),
  );
  final subscription = container.listen(provider.future, (_, _) {});
  addTearDown(subscription.close);
  return subscription.read();
}

void main() {
  group('a reference from another file', () {
    test('compares exactly as a reference from the same file does', () async {
      final container = _container();
      const base = LapRef(_race, sebringLapIndex);
      final sameFile = await _chart(
        container,
        base: base,
        target: const LapRef(_race, sebringLap3Index),
      );
      final otherFile = await _chart(
        container,
        base: base,
        target: const LapRef(_other, sebringLap3Index),
      );

      expect(otherFile.comparison, isNotNull);
      expect(otherFile.comparison!.target,
          const LapRef(_other, sebringLap3Index));
      expect(otherFile.comparison!.overlaid, isTrue);
      expect(otherFile.comparison!.delta!.finalDelta,
          sameFile.comparison!.delta!.finalDelta);
      expect(otherFile.panels.map((p) => p.title),
          sameFile.panels.map((p) => p.title));
    });

    test('lapChart is the same-file case of the shared builder', () async {
      final container = _container();
      final viaProvider = await container.read(
        lapChartProvider(_race, sebringLapIndex, sebringLap3Index).future,
      );
      final viaBuilder = await _chart(
        container,
        base: const LapRef(_race, sebringLapIndex),
        target: const LapRef(_race, sebringLap3Index),
      );
      expect(viaProvider.comparison!.delta!.finalDelta,
          viaBuilder.comparison!.delta!.finalDelta);
      expect(viaProvider.bounds, viaBuilder.bounds);
    });

    test('a lap against itself is no comparison', () async {
      final chart = await _chart(
        _container(),
        base: const LapRef(_race, sebringLapIndex),
        target: const LapRef(_race, sebringLapIndex),
      );
      expect(chart.comparison, isNull);
    });
  });

  group('bounds', () {
    test('on the Time axis they cover all of a slower reference', () async {
      final container = _container();
      container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
      final base = sebringLap3Telemetry(); // 1:04.030, the faster lap
      final slower = sebringLapTelemetry(); // 1:04.497

      final chart = await _chart(
        container,
        base: const LapRef(_race, sebringLap3Index),
        target: const LapRef(_other, sebringLapIndex),
      );

      expect(chart.axis, TraceAxis.time);
      // Both start at their own line crossing, so the reference ends one lap
      // of its own after Base's start — past Base's end. Before, that last
      // stretch (about 0.44 s) was cut off.
      expect(slower.durationSeconds, greaterThan(base.durationSeconds));
      expect(chart.bounds.start, closeTo(base.startSeconds, 1e-9));
      expect(chart.bounds.end,
          closeTo(base.startSeconds + slower.durationSeconds, 1e-9));
    });

    test('on the Time axis a faster reference leaves them Base\'s own',
        () async {
      final container = _container();
      container.read(chartSyncProvider.notifier).setAxis(TraceAxis.time);
      final base = sebringLapTelemetry();
      final chart = await _chart(
        container,
        base: const LapRef(_race, sebringLapIndex),
        target: const LapRef(_other, sebringLap3Index),
      );
      expect(chart.bounds,
          ChartViewport(base.startSeconds, base.endSeconds));
    });

    test('on the Distance axis they stay Base\'s', () async {
      final container = _container();
      final chart = await _chart(
        container,
        base: const LapRef(_race, sebringLap3Index),
        target: const LapRef(_other, sebringLapIndex),
      );
      expect(chart.axis, TraceAxis.distance);
      expect(chart.bounds, chart.distanceAxis!.bounds);
    });
  });

  group('SyncOwner', () {
    testWidgets('a new owner clears the cursor and zoom, with no foreign '
        'frame', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sync = container.read(chartSyncProvider.notifier);
      sync.claim('lap X');
      sync.setCursor(500);
      sync.showWindow(const ChartViewport(400, 600),
          bounds: const ChartViewport(0, 3000));

      final seen = <ChartSyncState>[];
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: SyncOwner(owner: 'lap A', child: _Probe(seen)),
      ));
      // The first frame is drawn before the claim lands: it must show the
      // whole lap and no cursor, not lap X's window.
      expect(seen.first.cursor, isNull);
      expect(seen.first.viewport, isNull);

      await tester.pump();
      expect(container.read(chartSyncProvider).owner, 'lap A');
      expect(container.read(chartSyncProvider).cursor, isNull);
      expect(container.read(chartSyncProvider).isZoomed, isFalse);
      expect(seen.every((s) => s.viewport == null), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the same owner keeps the cursor and zoom', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sync = container.read(chartSyncProvider.notifier);
      sync.claim('lap A');
      sync.setCursor(500);

      final seen = <ChartSyncState>[];
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: SyncOwner(owner: 'lap A', child: _Probe(seen)),
      ));
      await tester.pump();
      expect(seen.last.cursor, 500);
      expect(container.read(chartSyncProvider).cursor, 500);
    });

    testWidgets('a change of owner in place claims again', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seen = <ChartSyncState>[];
      Widget owned(String owner) => UncontrolledProviderScope(
        container: container,
        child: SyncOwner(owner: owner, child: _Probe(seen)),
      );

      await tester.pumpWidget(owned('lap 2'));
      await tester.pump();
      container.read(chartSyncProvider.notifier).setCursor(500);
      await tester.pump();
      expect(seen.last.cursor, 500);

      // Another lap picked on the same screen: the same widget, a new owner.
      await tester.pumpWidget(owned('lap 4'));
      await tester.pump();
      expect(container.read(chartSyncProvider).owner, 'lap 4');
      expect(seen.last.cursor, isNull);
    });

    testWidgets('during a transition the outgoing page goes quiet when the '
        'incoming one claims', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final outgoing = <ChartSyncState>[];
      final incoming = <ChartSyncState>[];

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: Column(children: [
          SyncOwner(
            key: const ValueKey('trace'),
            owner: 'trace lap',
            child: _Probe(outgoing),
          ),
        ])),
      ));
      await tester.pump();
      container.read(chartSyncProvider.notifier).setCursor(500);
      await tester.pump();
      expect(outgoing.last.cursor, 500);

      // Both pages mounted, as while a route slides and fades.
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Directionality(textDirection: TextDirection.ltr, child: Column(children: [
          SyncOwner(
            key: const ValueKey('trace'),
            owner: 'trace lap',
            child: _Probe(outgoing),
          ),
          SyncOwner(
            key: const ValueKey('compare'),
            owner: 'compare base',
            child: _Probe(incoming),
          ),
        ])),
      ));
      expect(incoming.every((s) => s.cursor == null), isTrue,
          reason: 'the incoming page never draws the outgoing page\'s cursor');
      await tester.pump();
      expect(container.read(chartSyncProvider).owner, 'compare base');
      expect(outgoing.last.cursor, isNull);
      // And the outgoing page, rebuilt, does not take it back.
      await tester.pump();
      expect(container.read(chartSyncProvider).owner, 'compare base');
    });
  });
}

/// Records the sync state every time it builds, as the synced widget at its
/// place in the tree sees it.
class _Probe extends ConsumerWidget {
  const _Probe(this.seen);

  final List<ChartSyncState> seen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    seen.add(watchChartSync(ref, context).state);
    return const SizedBox(width: 10, height: 10);
  }
}
