/// Base against Target, projected for the synced views and checked (comparison
/// proposal §4, §9).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import '../domain/comparability.dart';
import '../domain/comparison_set.dart';
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
  /// read, let alone drawn.
  final LapChart? chart;

  /// The comparability strip, in reading order.
  final List<ComparabilityChip> chips;

  bool get refused => course?.refuses ?? false;
}

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. The course gate runs on file facts alone —
/// metadata and the whole-file course facts — before any lap is read: a
/// refused pair makes zero `lapTelemetry` reads (§4).
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
  final course = CourseCheck.of(
    base: baseMetadata,
    baseCourse: baseCourse,
    target: targetMetadata,
    targetCourse: targetCourse,
    sameFile: sameFile,
  );
  if (course.refuses) {
    return ComparisonView(
      set: set,
      base: baseMetadata,
      target: targetMetadata,
      course: course,
    );
  }

  final chart = await buildComparisonChart(ref, base: base, target: target);
  final comparison = chart.comparison;
  if (comparison == null) {
    // Base against itself: `ComparisonSet.withTarget` never builds one, but
    // a set made by hand could.
    return ComparisonView(set: set, base: baseMetadata, chart: chart);
  }
  final baseGaps = await ref.watch(
    sessionClockGapsProvider(base.source).future,
  );
  final targetGaps = sameFile
      ? baseGaps
      : await ref.watch(sessionClockGapsProvider(target.source).future);
  return ComparisonView(
    set: set,
    base: baseMetadata,
    target: targetMetadata,
    course: course,
    chart: chart,
    chips: comparabilityChips(
      course: course,
      comparison: comparison,
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
