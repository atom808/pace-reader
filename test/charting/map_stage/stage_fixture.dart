import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

/// A round lap of [radius] metres driven at a steady [speed] m/s, sampled
/// at 10 Hz, on the Distance axis: `xs` and `stations` are metres from the
/// line, `seconds` the recording clock from 100 s.
TrackPath circleLap({double radius = 200, double speed = 50}) {
  const latitude = 45.0;
  final circumference = 2 * math.pi * radius;
  final n = (circumference / speed * 10).round() + 1;
  final lats = Float64List(n);
  final lons = Float64List(n);
  final xs = Float64List(n);
  final seconds = Float64List(n);
  final metresPerDegreeLongitude = 111320 * math.cos(latitude * math.pi / 180);
  for (var i = 0; i < n; i++) {
    final metres = math.min(i * speed / 10, circumference);
    final theta = metres / radius;
    lats[i] = latitude + radius * math.sin(theta) / 111320;
    lons[i] = 7 + radius * math.cos(theta) / metresPerDegreeLongitude;
    xs[i] = metres;
    seconds[i] = 100 + i / 10;
  }
  return TrackPath(
    projection: TrackProjection.fromCoordinates(lats, lons),
    xs: xs,
    values: Float64List(n),
    valueRange: const ValueRange(0, 1),
    valueLabel: '',
    valueUnit: '',
    stations: xs,
    seconds: seconds,
  );
}

/// A plot of [values] at [xs], as a channel would project onto the axis.
TracePlot plotOf(List<double> xs, List<double> values) => TracePlot.fromSeries(
  TraceSeries(
    channelName: 'test',
    unit: '%',
    frequencyHz: 10,
    valueColumn: 'value',
    times: Float64List.fromList(xs),
    lows: Float64List.fromList(values),
    highs: Float64List.fromList(values),
  ),
  axis: TraceAxis.time,
);

/// The [MapStage]'s painter on screen: its layers are what the map draws.
/// The minimap paints with its own painter, so this is the stage's.
StagePainter stagePainter(WidgetTester tester) =>
    tester
            .widgetList<CustomPaint>(
              find.descendant(
                of: find.byType(MapStage),
                matching: find.byType(CustomPaint),
              ),
            )
            .firstWhere((p) => p.painter is StagePainter)
            .painter!
        as StagePainter;

/// The stage's layers of type [T], in paint order.
List<T> stageLayers<T extends StageLayer>(WidgetTester tester) =>
    stagePainter(tester).layers.whereType<T>().toList();
