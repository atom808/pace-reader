/// Which outline a lap's road band is drawn from (map stage proposal §3.4,
/// D6): the layout's, from the library, where it covers at least half the
/// lap; else a published survey of the circuit, where it fits the lap;
/// else this session's envelope, said to be only that.
library;

import 'dart:typed_data';
import 'dart:ui' show Offset;

import '../../../data/models/trace.dart';
import '../../../widgets/charting/charting.dart';
import 'outline_pool.dart';
import 'public_outline.dart';

/// A lap's road: its two edges along the lap's line, and the line under
/// the HUD that says where they came from.
class RoadBand {
  const RoadBand({required this.left, required this.right, required this.note});

  final List<Offset?> left;
  final List<Offset?> right;
  final String note;
}

/// The road along [path], or null when neither outline gives one.
///
/// [lateral] is `Path Lateral` at each of [path]'s points
/// ([lateralAlong]). Coverage is measured on this lap's own points, so a
/// layout the library knows only in part still draws where the lap goes.
RoadBand? chooseRoad({
  required TrackPath path,
  required Float64List lateral,
  TrackOutline? library,
  int recordings = 0,
  Centreline? survey,
  TrackOutline? envelope,
}) {
  if (library != null) {
    final edges = trackEdges(path, lateral, library);
    final share = knownShare(edges.left, edges.right);
    if (share >= outlineMinCoverage) {
      final percent = (share * 100).round();
      final from = recordings == 1
          ? 'your 1 recording'
          : 'your $recordings recordings';
      return RoadBand(
        left: edges.left,
        right: edges.right,
        note: percent >= 99
            ? 'Road from $from'
            : 'Road from $from · $percent %',
      );
    }
  }
  final stations = path.stations;
  if (survey != null && stations != null) {
    final fit = fitCentreline(
      survey,
      centres: centrePath(path, lateral),
      stations: stations,
    );
    if (fit != null && fit.passes) {
      final edges = trackEdges(path, lateral, fit.outline);
      if (knownShare(edges.left, edges.right) >= outlineMinCoverage) {
        return RoadBand(
          left: edges.left,
          right: edges.right,
          note: 'Road from public track data (TUM)',
        );
      }
    }
  }
  if (envelope != null) {
    final edges = trackEdges(path, lateral, envelope);
    if (knownShare(edges.left, edges.right) > 0) {
      return RoadBand(
        left: edges.left,
        right: edges.right,
        note: 'Road: the width your laps used',
      );
    }
  }
  return null;
}

/// [series] at each of [path]'s points, by its clock: linear between the
/// samples either side, NaN outside them or where [path] has no clock.
Float64List lateralAlong(TrackPath path, TraceSeries series) {
  final seconds = path.seconds;
  final n = path.length;
  final out = Float64List(n)..fillRange(0, n, double.nan);
  final times = series.times;
  final values = series.lows;
  if (seconds == null || times.isEmpty) return out;
  var j = 0;
  for (var i = 0; i < n; i++) {
    final t = seconds[i];
    if (t < times.first || t > times.last) continue;
    while (j + 1 < times.length && times[j + 1] < t) {
      j++;
    }
    if (j + 1 >= times.length || times[j] == t) {
      out[i] = values[j];
      continue;
    }
    final span = times[j + 1] - times[j];
    final f = span <= 0 ? 0.0 : (t - times[j]) / span;
    out[i] = values[j] + (values[j + 1] - values[j]) * f;
  }
  return out;
}
