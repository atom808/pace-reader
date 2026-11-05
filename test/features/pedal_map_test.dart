// The map reads the pedal where the Throttle panel does (driver-aids
// proposal D1): its pedal colouring and its "Throttle" colouring hold steady
// through a TC cut instead of flickering with the engine throttle.
//
// Fed by the real Sebring fixture lap, whose engine throttle is cut under
// a held pedal.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/channels.dart';
import 'package:pace_reader/data/duckdb/telemetry_database.dart';
import 'package:pace_reader/data/repositories/lap_ref.dart';
import 'package:pace_reader/data/repositories/lap_telemetry.dart';
import 'package:pace_reader/features/telemetry_trace/application/lap_chart.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../fixtures/sebring_lap1.dart';

const _race = TelemetrySource.path('/fixture/sebring.duckdb');

Future<LapChart> _chart({String? colourBy}) async {
  final container = ProviderContainer(
    overrides: [
      lapTelemetryProvider(
        _race,
        sebringLapIndex,
      ).overrideWith((ref) async => sebringLapTelemetry()),
    ],
  );
  addTearDown(container.dispose);
  if (colourBy != null) {
    container.read(trackMapChannelProvider.notifier).select(colourBy);
  }
  final provider = FutureProvider.autoDispose<LapChart>(
    (ref) =>
        buildComparisonChart(ref, base: const LapRef(_race, sebringLapIndex)),
  );
  final subscription = container.listen(provider.future, (_, _) {});
  addTearDown(subscription.close);
  return subscription.read();
}

TracePlot _plot(LapChart chart, String channel) => TracePlot.fromSeries(
  chart.telemetry.channels[channel]!,
  axis: chart.axis,
  distanceAxis: chart.distanceAxis,
  label: channel,
);

void main() {
  test('the pedal colouring reads the pedal, not the cut engine', () async {
    final chart = await _chart();
    final path = chart.trackPath!;
    final pedal = PedalSamples.sample(
      path,
      throttle: _plot(chart, pedalChannelName),
    ).throttle;
    final engine = PedalSamples.sample(
      path,
      throttle: _plot(chart, Channels.throttlePos),
    ).throttle;
    // The fixture's cuts reach the map's points, so the two differ.
    expect(pedal, isNot(engine));
    expect(chart.trackPedals!.throttle, pedal);
  });

  test('"Colour by Throttle" reads the pedal too', () async {
    final chart = await _chart(colourBy: Channels.throttlePos);
    final path = chart.trackPath!;
    final pedal = path.recoloured(_plot(chart, pedalChannelName)).values;
    expect(path.values, pedal);
  });
}
