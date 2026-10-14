/// One course's corner table, frozen next to Compare's segment table
/// (SPEC.md §8.13.5, §8.13.9).
library;

import '../../driver_comparison/domain/segments.dart';
import 'geometric_corners.dart';

/// One course's corners, frozen like Compare's [SegmentTable] and keyed the
/// same way.
class CornerTable {
  const CornerTable({
    required this.key,
    required this.wrapLength,
    required this.corners,
    required this.laps,
    this.detectorVersion = CornerDetector.version,
  });

  final TrackKey key;

  /// The course's lap length; a file whose length differs by more than
  /// [SegmentTable.fingerprintTolerance] gets its own detection.
  final double wrapLength;
  final List<GeoCorner> corners;

  /// How many laps the median profile was over.
  final int laps;
  final int detectorVersion;

  bool fits(double otherWrapLength) =>
      (otherWrapLength - wrapLength).abs() <= SegmentTable.fingerprintTolerance;

  /// [segment]'s corners, by apex, in track order.
  List<GeoCorner> inSegment(Segment segment) => [
    for (final c in corners)
      if (segment.contains(c.apex)) c,
  ];
}

/// "Seg 3 · corner 2 · R, 43 m": a corner named by where it sits, never by an
/// official turn number (§8.13.5).
String cornerLabel(GeoCorner corner, Segment segment, int positionInSegment) =>
    '${segment.name} · corner $positionInSegment · '
    '${corner.direction.letter}, ${corner.radius.toStringAsFixed(0)} m';
