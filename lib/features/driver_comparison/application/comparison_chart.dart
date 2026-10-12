/// Base against Target, projected for the synced views and checked (comparison
/// proposal §4, §9).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/lap_telemetry.dart';
import '../../../data/repositories/providers.dart';
import '../../../widgets/charting/charting.dart';
import '../../../widgets/design_system/color_tokens.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import '../domain/comparability.dart';
import '../domain/comparison_set.dart';
import '../domain/lines.dart';
import 'compare_source_guard.dart';

part 'comparison_chart.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// What Compare draws for one [ComparisonSet].
class ComparisonView {
  const ComparisonView({
    required this.set,
    required this.base,
    this.chart,
    this.target,
    this.course,
    this.line,
    this.chips = const [],
  });

  final ComparisonSet set;

  /// Base's file.
  final SessionMetadata base;

  /// The Target's file, when there is a Target.
  final SessionMetadata? target;

  /// The course gate's verdict; null without a Target.
  final CourseCheck? course;

  /// Null when the course gate refused the pair: nothing of either lap is
  /// drawn.
  final LapChart? chart;

  /// Whether the two laps' lines compare; null without a Target.
  final LineCheck? line;

  /// The comparability strip, in reading order.
  final List<ComparabilityChip> chips;

  bool get refused => course?.refuses ?? false;
}

/// Whether the Line panel draws each lap's own `Path Lateral` rather than
/// the Target's against Base's (comparison proposal §6). Kept for the run.
@Riverpod(keepAlive: true)
class LinePanelRaw extends _$LinePanelRaw {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. Parts 1 and 2 of the course gate run on file
/// facts alone — metadata and the whole-file course facts — before any lap
/// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
/// the whole-lap centre line, needs both laps, and runs on them before
/// anything is drawn.
///
/// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
/// projection costs less than a frame.
@Riverpod(retry: _neverRetry)
Future<ComparisonView> comparisonChart(Ref ref, ComparisonSet set) async {
  final base = set.base;
  final target = set.target;
  requireSourceOpen(ref, base.source, ComparisonRole.base);
  if (target != null) {
    requireSourceOpen(ref, target.source, ComparisonRole.target);
  }

  final baseMetadata = await ref.watch(
    sessionMetadataProvider(base.source).future,
  );
  if (target == null) {
    return ComparisonView(
      set: set,
      base: baseMetadata,
      chart: await buildComparisonChart(ref, base: base),
    );
  }

  final sameFile = target.source == base.source;
  final targetMetadata = sameFile
      ? baseMetadata
      : await ref.watch(sessionMetadataProvider(target.source).future);
  final baseCourse = await ref.watch(courseFactsProvider(base.source).future);
  final targetCourse = sameFile
      ? baseCourse
      : await ref.watch(courseFactsProvider(target.source).future);
  var course = CourseCheck.of(
    base: baseMetadata,
    baseCourse: baseCourse,
    target: targetMetadata,
    targetCourse: targetCourse,
    sameFile: sameFile,
  );
  ComparisonView refused() => ComparisonView(
    set: set,
    base: baseMetadata,
    target: targetMetadata,
    course: course,
  );
  if (course.refuses) return refused();

  final chart = await buildComparisonChart(ref, base: base, target: target);
  final comparison = chart.comparison;
  if (comparison == null) {
    // Base against itself: `ComparisonSet.withTarget` never builds one, but
    // a set made by hand could.
    return ComparisonView(set: set, base: baseMetadata, chart: chart);
  }

  final targetTelemetry = await ref.watch(
    lapTelemetryProvider(target.source, target.lapIndex).future,
  );
  final line = LineCheck.measure(
    base: chart.telemetry,
    target: targetTelemetry,
    baseCourse: baseCourse,
    targetCourse: targetCourse,
    sameFile: sameFile,
    alignment: comparison.alignment,
  );
  course = course.withCentreLine(line.centre);
  if (course.refuses) return refused();

  final baseGaps = await ref.watch(
    sessionClockGapsProvider(base.source).future,
  );
  final targetGaps = sameFile
      ? baseGaps
      : await ref.watch(sessionClockGapsProvider(target.source).future);
  final linePanel = _linePanel(
    chart,
    line,
    raw: ref.watch(linePanelRawProvider),
  );
  return ComparisonView(
    set: set,
    base: baseMetadata,
    target: targetMetadata,
    course: course,
    line: line,
    chart: linePanel == null
        ? chart
        : chart.withPanels(_insertAfterSteering(chart.panels, linePanel)),
    chips: comparabilityChips(
      course: course,
      comparison: comparison,
      line: line,
      facts: PairFacts(
        base: baseMetadata,
        target: targetMetadata,
        baseLap: chart.lap,
        targetLap: comparison.reference,
        baseCourse: baseCourse,
        targetCourse: targetCourse,
        baseClockGaps: baseGaps,
        targetClockGaps: targetGaps,
      ),
    ),
  );
}

/// The Line panel (§6): the Target's `Path Lateral` less Base's at equal
/// `Lap Dist`, zero = Base, with the 0.5 m floor drawn as a band; or, [raw],
/// each lap's own. Null when [line] withholds it.
TracePanelSpec? _linePanel(
  LapChart chart,
  LineCheck line, {
  required bool raw,
}) {
  final base = line.base;
  final target = line.target;
  final comparison = chart.comparison;
  if (!line.shown || base == null || target == null || comparison == null) {
    return null;
  }
  if (raw) {
    return TracePanelSpec(
      title: 'Line',
      unit: 'm',
      role: ChannelRole.line,
      decimals: 1,
      series: LineSeries(
        TracePlot.fromSeries(
          pathLateralOf(base),
          axis: chart.axis,
          distanceAxis: chart.distanceAxis,
          label: 'Line',
        ),
        reference: comparison.overlaid
            ? TracePlot.fromSeries(
                pathLateralOf(target),
                axis: chart.axis,
                distanceAxis: comparison.referenceAxis,
                label: 'Line',
                timeShift: comparison.timeShift,
              )
            : null,
      ),
    );
  }
  final difference = pathLateralDifference(base, target);
  if (difference == null) return null;
  return TracePanelSpec(
    title: 'Line',
    unit: 'm',
    role: ChannelRole.line,
    decimals: 1,
    series: DeltaSeriesPanel(
      TracePlot.fromSeries(
        difference,
        axis: chart.axis,
        distanceAxis: chart.distanceAxis,
        label: 'Line',
      ),
      floorBand: lineFloor,
    ),
  );
}

/// [panels] with [line] after Steering, the panel it is read against (§3).
List<TracePanelSpec> _insertAfterSteering(
  List<TracePanelSpec> panels,
  TracePanelSpec line,
) {
  final steering = panels.indexWhere((p) => p.role == ChannelRole.steering);
  final at = steering >= 0
      ? steering + 1
      : panels.indexWhere(
          (p) => p.role == ChannelRole.rpm || p.role == ChannelRole.gear,
        );
  return [...panels]..insert(at < 0 ? panels.length : at, line);
}
