import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';
import 'package:pace_reader/features/track_outline/domain/road_band.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import 'stage_fixture.dart';

/// Both edges [left] and [right] metres from the centre, every 2 m of a
/// lap [metres] long.
TrackOutline _uniform(double metres, double left, double right) {
  final n = (metres / 2).ceil() + 1;
  return TrackOutline(
    binMetres: 2,
    left: Float64List(n)..fillRange(0, n, left),
    right: Float64List(n)..fillRange(0, n, right),
  );
}

/// The middle of a sampled circle: its bounds', which a missing sample
/// hardly moves (a mean of the points leans away from the gap).
Offset _centreOf(List<Offset> points) {
  double edge(
    double Function(Offset) axis,
    double Function(double, double) pick,
  ) => points.map(axis).reduce(pick);
  return Rect.fromLTRB(
    edge((p) => p.dx, math.min),
    edge((p) => p.dy, math.min),
    edge((p) => p.dx, math.max),
    edge((p) => p.dy, math.max),
  ).center;
}

void main() {
  const radius = 200.0;
  final lap = circleLap(radius: radius);
  final metres = lap.stations!.last;
  final centre = _centreOf(lap.projection.points);
  double fromCentre(Offset? p) => (p! - centre).distance;
  Float64List lateral(double v) =>
      Float64List(lap.length)..fillRange(0, lap.length, v);

  group('trackEdges', () {
    // The fixture laps anticlockwise: left of travel is the inside.
    test('the left edge is on the left of travel, the right on the right', () {
      final edges = trackEdges(lap, lateral(0), _uniform(metres, -5, 7));
      final i = lap.length ~/ 3;
      expect(fromCentre(edges.left[i]), closeTo(radius - 5, 0.5));
      expect(fromCentre(edges.right[i]), closeTo(radius + 7, 0.5));
    });

    test('hangs off the centre path, not the car', () {
      // The car 2 m right of the centre: the centre is 2 m to its left.
      final edges = trackEdges(lap, lateral(2), _uniform(metres, -5, 5));
      final i = lap.length ~/ 2;
      expect(fromCentre(edges.left[i]), closeTo(radius - 7, 0.5));
      expect(fromCentre(edges.right[i]), closeTo(radius + 3, 0.5));
    });

    test('no edge where the outline or Path Lateral does not know', () {
      final outline = _uniform(metres, -5, 5);
      outline.left.fillRange(0, 50, double.nan); // the first 100 m
      final lat = lateral(0)..[lap.length - 1] = double.nan;
      final edges = trackEdges(lap, lat, outline);
      expect(edges.left.first, isNull);
      expect(edges.right.first, isNull, reason: 'a band needs both');
      expect(edges.left.last, isNull);
      expect(
        knownShare(edges.left, edges.right),
        closeTo(1 - 100 / metres, 0.01),
      );
    });
  });

  group('chooseRoad', () {
    test("the library's outline where it covers half the lap or more", () {
      final library = _uniform(metres, -6, 6);
      library.right.fillRange(0, library.length ~/ 3, double.nan);
      final road = chooseRoad(
        path: lap,
        lateral: lateral(0),
        library: library,
        recordings: 23,
        envelope: _uniform(metres, -3, 3),
      )!;
      expect(
        road.note,
        matches(RegExp(r'^Road from your 23 recordings · 6\d %$')),
      );
      final i = lap.length - 2;
      expect(fromCentre(road.right[i]), closeTo(radius + 6, 0.5));
    });

    test('a whole lap says no share', () {
      final road = chooseRoad(
        path: lap,
        lateral: lateral(0),
        library: _uniform(metres, -6, 6),
        recordings: 1,
      )!;
      expect(road.note, 'Road from your 1 recording');
    });

    test('below half, the envelope, said to be only that', () {
      final library = _uniform(metres, -6, 6);
      library.left.fillRange(0, library.length * 2 ~/ 3, double.nan);
      final road = chooseRoad(
        path: lap,
        lateral: lateral(0),
        library: library,
        recordings: 2,
        envelope: _uniform(metres, -3, 3),
      )!;
      expect(road.note, 'Road: the width your laps used');
      expect(fromCentre(road.left[1]), closeTo(radius - 3, 0.5));
    });

    test('none from neither', () {
      expect(chooseRoad(path: lap, lateral: lateral(0)), isNull);
    });
  });

  test('lateralAlong reads the series by the clock, between samples', () {
    // The lap's clock runs from 100 s at 10 Hz; a series at 1 Hz.
    final times = Float64List.fromList([100, 101, 102]);
    final values = Float64List.fromList([0, 2, -2]);
    final series = TraceSeries(
      channelName: 'Path Lateral',
      unit: 'm',
      frequencyHz: 1,
      valueColumn: 'value',
      times: times,
      lows: values,
      highs: values,
    );
    final along = lateralAlong(lap, series);
    expect(along[0], 0);
    expect(along[5], closeTo(1, 1e-9));
    expect(along[15], closeTo(0, 1e-9));
    expect(along[25].isNaN, isTrue, reason: 'after the last sample');
  });

  testWidgets('the band fills between the edges, and nothing inside them', (
    tester,
  ) async {
    final edges = trackEdges(lap, lateral(0), _uniform(metres, -6, 6));
    const size = Size(500, 500);
    final view = StageView(
      camera: MapCamera(
        centre: centre,
        pixelsPerMetre: 1,
        focus: const Offset(250, 250),
      ),
      size: size,
    );
    final recorder = PictureRecorder();
    TrackOutlineLayer(
      left: edges.left,
      right: edges.right,
      colour: const Color(0x99808080),
    ).paint(Canvas(recorder), view);
    final bytes = await tester.runAsync(() async {
      final image = await recorder.endRecording().toImage(500, 500);
      return image.toByteData();
    });
    int alphaAt(Offset p) =>
        bytes!.getUint8((p.dy.round() * 500 + p.dx.round()) * 4 + 3);
    // On the road at the lap's first point, then the infield.
    final onRoad = view.toScreen(lap.projection.points.first);
    expect(alphaAt(onRoad), closeTo(0x99, 2));
    expect(alphaAt(const Offset(250, 250)), 0);
    // A seam would show where neighbouring quads overlap: one alpha all
    // along the road.
    final quarter = view.toScreen(lap.projection.points[lap.length ~/ 4]);
    expect(alphaAt(quarter), closeTo(0x99, 2));
  });
}
