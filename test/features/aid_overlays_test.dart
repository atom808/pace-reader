// The aid overlays against a reference lap (driver-aids proposal §2.4):
// the reference's own aids drawn hollow on its line, placed on Base's axis
// the way its traces are, under Base's own.
//
// Fed by the two real Sebring fixture laps — lap 2 (index 1) as Base and
// lap 4 (index 3) as the reference — with constructed aids.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/features/telemetry_trace/application/aid_overlays.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/widgets/charting/charting.dart';
import 'package:pace_reader/widgets/design_system/color_tokens.dart';

import '../fixtures/sebring_lap1.dart';
import '../fixtures/sebring_lap3.dart';

const _race = TelemetrySource.path('/fixture/sebring.duckdb');

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      lapTelemetryProvider(
        _race,
        sebringLapIndex,
      ).overrideWith((ref) async => sebringLapTelemetry()),
      lapTelemetryProvider(
        _race,
        sebringLap3Index,
      ).overrideWith((ref) async => sebringLap3Telemetry()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<LapChart> _chart(
  ProviderContainer container, {
  required TraceAxis axis,
  bool reference = true,
}) async {
  container.read(chartSyncProvider.notifier).setAxis(axis);
  final provider = FutureProvider.autoDispose<LapChart>(
    (ref) => buildComparisonChart(
      ref,
      base: const LapRef(_race, sebringLapIndex),
      target: reference ? const LapRef(_race, sebringLap3Index) : null,
    ),
  );
  final subscription = container.listen(provider.future, (_, _) {});
  addTearDown(subscription.close);
  return subscription.read();
}

/// One pulse 10 s into the lap starting at [start], as an aid of [name].
AidPulses _pulse(String name, double start, double end) => AidPulses.fromEdges(
  name,
  [(start + 10, true), (start + 10.02, false)],
  start: start,
  end: end,
);

LapAids _aids(double start, double end, {bool abs = false}) => LapAids(
  tc: _pulse('TC', start, end),
  abs: _pulse('ABS', start, end),
  absFitted: abs,
  lockups: const [],
);

final _base = _aids(sebringLapStartSeconds, sebringLapEndSeconds);
final _reference = _aids(
  sebringLap3StartSeconds,
  sebringLap3EndSeconds,
  abs: true,
);

List<TraceOverlay> _on(LapChart chart, ChannelRole role) =>
    chart.panels.firstWhere((p) => p.role == role).overlays;

void main() {
  test("on Time, the reference's pulses sit where its trace does", () async {
    final chart = await _chart(_container(), axis: TraceAxis.time);
    final overlays = LapAidOverlays.of(chart, _base, referenceAids: _reference);
    final decorated = overlays.decorate(chart, TraceAid.values.toSet());
    final throttle = _on(decorated, ChannelRole.throttle);
    // The reference's under Base's.
    expect(throttle.whereType<PulseOverlay>().map((o) => o.onReference), [
      true,
      false,
    ]);
    final theirs = throttle.whereType<PulseOverlay>().first;
    final shift = chart.comparison!.timeShift;
    expect(
      theirs.pulses.single,
      closeTo(sebringLap3StartSeconds + 10.01 + shift, 1e-9),
    );
    final ours = throttle.whereType<PulseOverlay>().last;
    expect(ours.pulses.single, closeTo(sebringLapStartSeconds + 10.01, 1e-9));
  });

  test("on Distance, at the reference's own Lap Dist", () async {
    final chart = await _chart(_container(), axis: TraceAxis.distance);
    final overlays = LapAidOverlays.of(chart, _base, referenceAids: _reference);
    final theirs = _on(
      overlays.decorate(chart, {TraceAid.tc}),
      ChannelRole.throttle,
    ).whereType<PulseOverlay>().first;
    expect(theirs.onReference, isTrue);
    expect(
      theirs.pulses.single,
      LapAlignment.stationAt(
        chart.comparison!.referenceAxis,
        sebringLap3StartSeconds + 10.01,
      ),
    );
  });

  test("ABS is offered when only the reference's car has it, and only its "
      'pulses are drawn', () async {
    final chart = await _chart(_container(), axis: TraceAxis.time);
    final overlays = LapAidOverlays.of(chart, _base, referenceAids: _reference);
    expect(overlays.offers(TraceAid.abs), isTrue);
    final brake = _on(
      overlays.decorate(chart, {TraceAid.abs}),
      ChannelRole.brake,
    );
    expect(brake.whereType<PulseOverlay>().map((o) => o.onReference), [true]);
  });

  test('without a reference, only the lap\'s own', () async {
    final chart = await _chart(
      _container(),
      axis: TraceAxis.time,
      reference: false,
    );
    final overlays = LapAidOverlays.of(chart, _base, referenceAids: _reference);
    expect(overlays.referenceAids, isNull);
    expect(overlays.offers(TraceAid.abs), isFalse);
    final throttle = _on(
      overlays.decorate(chart, TraceAid.values.toSet()),
      ChannelRole.throttle,
    );
    expect(throttle.whereType<PulseOverlay>().map((o) => o.onReference), [
      false,
    ]);
  });

  test("the readout names this lap's aids, never the reference's", () {
    final ours = _pulseOverlay(onReference: false);
    final theirs = _pulseOverlay(onReference: true);
    expect(activeAidLabels([theirs, ours], 5), ['TC']);
    expect(activeAidLabels([theirs], 5), isEmpty);
    expect(overlayKey(theirs), isNot(overlayKey(ours)));
  });
}

PulseOverlay _pulseOverlay({required bool onReference}) => pulseOverlay(
  AidPulses.fromEdges('TC', [(4.0, true), (6.0, false)], start: 0, end: 10),
  (s) => s,
  label: 'TC',
  onReference: onReference,
);
