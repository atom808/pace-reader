// A lap's kerb and off-track stretches from `SurfaceTypes` (map stage P9d).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pace_reader/data/models/models.dart';

StepSeries _wheel(List<(double, int)> rows) => StepSeries(
  eventName: 'SurfaceTypes',
  unit: '',
  times: Float64List.fromList([for (final (t, _) in rows) t]),
  values: Float64List.fromList([for (final (_, v) in rows) v.toDouble()]),
);

final _track = _wheel([(0, SurfaceCode.track)]);

void main() {
  test('a kerb, its stripes one stretch, and a wheel in the grass', () {
    final stretches = surfaceStretches(
      [
        // The left pair rides a kerb, its stripes alternating 5 and 6.
        _wheel([(0, 0), (10, 5), (10.02, 6), (10.05, 5), (11, 0)]),
        _track,
        _wheel([(0, 0), (10.2, 6), (10.4, 5), (11.2, 0)]),
        // The right rear drops a wheel in the grass.
        _wheel([(0, 0), (20, SurfaceCode.grass), (21, 0)]),
      ],
      start: 5,
      end: 30,
    );
    expect(stretches, const [
      SurfaceStretch(TrackSurface.kerb, 10, 11.2),
      SurfaceStretch(TrackSurface.offTrack, 20, 21),
    ]);
  });

  test('off track wins over a kerb, and a skip along the kerb is one', () {
    final stretches = surfaceStretches(
      [
        _wheel([(0, 0), (10, 5), (10.5, 0), (10.6, 5), (12, 0)]),
        _wheel([(0, 0), (11, SurfaceCode.gravel), (11.5, 0)]),
        _track,
        _track,
      ],
      start: 0,
      end: 20,
    );
    expect(stretches, const [
      SurfaceStretch(TrackSurface.kerb, 10, 11),
      SurfaceStretch(TrackSurface.offTrack, 11, 11.5),
      SurfaceStretch(TrackSurface.kerb, 11.5, 12),
    ]);
  });

  test('a lap that starts on a kerb, ends on one, and codes 30 as track', () {
    final stretches = surfaceStretches(
      [
        _wheel([(0, 5), (3, 30), (8, 6)]),
        _track,
        _track,
        _track,
      ],
      start: 2,
      end: 9,
    );
    expect(stretches, const [
      SurfaceStretch(TrackSurface.kerb, 2, 3),
      SurfaceStretch(TrackSurface.kerb, 8, 9),
    ]);
  });
}
