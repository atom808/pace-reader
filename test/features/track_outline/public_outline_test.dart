import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/features/track_outline/domain/public_outline.dart';
import 'package:pace_reader/features/track_outline/domain/road_band.dart';
import 'package:pace_reader/widgets/charting/charting.dart';

import '../../charting/map_stage/stage_fixture.dart';

/// A survey in the TUM format: a loop of [radius] m, its points every
/// 5 m starting at [start] radians, run anticlockwise (y up) or the other
/// way, rotated, shifted and squashed by [aspect] (1: a circle).
String _survey({
  double radius = 200,
  double start = 0,
  bool clockwise = false,
  double aspect = 1,
  double right = 5,
  double left = 7,
}) {
  final n = (2 * math.pi * radius / 5).round();
  final rows = ['# x_m,y_m,w_tr_right_m,w_tr_left_m'];
  for (var i = 0; i < n; i++) {
    final theta = start + (clockwise ? -1 : 1) * 2 * math.pi * i / n;
    final x = radius * math.cos(theta) * aspect;
    final y = radius * math.sin(theta) / aspect;
    // Somewhere else, at another angle.
    const turn = 0.7;
    rows.add(
      '${x * math.cos(turn) - y * math.sin(turn) + 1234},'
      '${x * math.sin(turn) + y * math.cos(turn) - 567},$right,$left',
    );
  }
  return rows.join('\n');
}

void main() {
  final lap = circleLap(radius: 200);
  final flat = Float64List(lap.length);
  final centres = centrePath(lap, flat);

  CentrelineFit fit(String csv) => fitCentreline(
    Centreline.fromCsv(csv),
    centres: centres,
    stations: lap.stations!,
  )!;

  test('reads the TUM format, resampled every metre round the loop', () {
    final line = Centreline.fromCsv(_survey());
    expect(line.length, closeTo(2 * math.pi * 200, 2));
    expect(
      () => Centreline.fromCsv('# header\n1,2,3,4'),
      throwsFormatException,
    );
  });

  test("fits a survey of the lap's own circuit, wherever it starts and "
      'whichever way its points run', () {
    for (final survey in [
      _survey(),
      _survey(start: 2.1),
      _survey(clockwise: true, start: 4),
    ]) {
      final f = fit(survey);
      expect(f.rms, lessThan(0.5));
      expect(f.scale, closeTo(1, 0.005));
      expect(f.passes, isTrue);
    }
  });

  test("the survey's widths land on the right sides of the lap", () {
    // The fixture laps anticlockwise, as the survey runs: its right is the
    // outside on both.
    final f = fit(_survey(right: 5, left: 7));
    final i = lap.length ~/ 3;
    final edges = f.outline.edgesAt(lap.stations![i])!;
    expect(edges.$1, closeTo(-7, 0.3));
    expect(edges.$2, closeTo(5, 0.3));
  });

  test('a survey of another shape fails the gate', () {
    final f = fit(_survey(aspect: 1.15));
    expect(f.passes, isFalse);
  });

  test('too little of a lap is not tried', () {
    expect(
      fitCentreline(
        Centreline.fromCsv(_survey()),
        centres: [...centres.take(40), ...List.filled(lap.length - 40, null)],
        stations: lap.stations!,
      ),
      isNull,
    );
  });

  test('the road falls to a survey that fits, and says so', () {
    final road = chooseRoad(
      path: lap,
      lateral: flat,
      survey: Centreline.fromCsv(_survey()),
      envelope: TrackOutline(
        binMetres: 2,
        left: Float64List(700)..fillRange(0, 700, -3),
        right: Float64List(700)..fillRange(0, 700, 3),
      ),
    )!;
    expect(road.note, 'Road from public track data (TUM)');

    final misfit = chooseRoad(
      path: lap,
      lateral: flat,
      survey: Centreline.fromCsv(_survey(aspect: 1.15)),
      envelope: TrackOutline(
        binMetres: 2,
        left: Float64List(700)..fillRange(0, 700, -3),
        right: Float64List(700)..fillRange(0, 700, 3),
      ),
    )!;
    expect(misfit.note, 'Road: the width your laps used');
  });
}
