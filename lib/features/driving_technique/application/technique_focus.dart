/// Driving Technique as a [LapFocusTarget] (map stage proposal §6.4): a lap
/// opens with the segment the sender pointed at selected.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../driver_comparison/domain/segments.dart';
import '../../lap_focus/lap_focus.dart';
import 'technique_providers.dart';

class TechniqueFocusTarget implements LapFocusTarget {
  const TechniqueFocusTarget();

  @override
  String get route => '/driving-technique';

  @override
  String get label => 'Technique';

  @override
  IconData get icon => Icons.insights;

  @override
  void apply(WidgetRef ref, LapFocus focus) => ref
      .read(techniqueSelectionStateProvider(focus.source).notifier)
      .selectLap(focus.lap);
}

const techniqueFocusTarget = TechniqueFocusTarget();

/// The segment [focus] points into, or null when it points nowhere or
/// between segments.
Segment? focusedSegment(List<Segment> segments, LapFocus focus) {
  final point = focus.point;
  if (point == null) return null;
  for (final s in segments) {
    if (s.contains(point)) return s;
  }
  return null;
}
