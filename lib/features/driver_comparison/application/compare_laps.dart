/// What the lap picker knows about a file (comparison proposal §3, "Lap
/// picker").
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/lap_repository.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/repositories/session_repository.dart';
import 'compare_source_guard.dart';

part 'compare_laps.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// One file's metadata, laps and course facts — everything the picker shows
/// and the course gate checks, without reading a lap.
class ComparableFile {
  const ComparableFile({
    required this.metadata,
    required this.laps,
    required this.course,
    required this.clockGaps,
  });

  final SessionMetadata metadata;
  final List<Lap> laps;
  final CourseFacts course;
  final List<ClockGap> clockGaps;

  /// Whether [lap] spent time in the pit lane (§4 Lap rules).
  bool inPitLane(Lap lap) {
    final end = lap.endSeconds;
    return end != null && course.pitLaneDuring(lap.startSeconds, end);
  }
}

/// Reads a file that is *not* open: open, read, dispose.
typedef ComparableFactsReader = Future<ComparableFile> Function(
  TelemetrySource source,
);

/// [readComparableFactsBriefly], as a provider so a test can serve a file
/// without a DuckDB connection.
@Riverpod(keepAlive: true)
ComparableFactsReader comparableFactsReader(Ref ref) =>
    readComparableFactsBriefly;

/// Opens [source] read-only just long enough to read its metadata, laps and
/// course facts, then closes it — `readSessionFactsBriefly`'s pattern, and
/// for the same reason: the kept-alive session provider would hold every
/// file the user merely browsed in the picker.
///
/// A separate reader rather than more reads in `readSessionFactsBriefly`:
/// that one runs for every file of a folder scan, and the course facts
/// would cost every scan a whole-file pass for an answer nothing stores
/// until the library's schema v2 (step 10).
Future<ComparableFile> readComparableFactsBriefly(
  TelemetrySource source,
) async {
  final session = await openTelemetrySession(source);
  try {
    return ComparableFile(
      metadata: session.metadata,
      laps: await LapRepository(session.database).readLaps(),
      course: await CourseRepository(
        session.database,
        session.catalog,
      ).readCourseFacts(),
      clockGaps: session.clockGaps,
    );
  } finally {
    await session.dispose();
  }
}

/// [source]'s facts: from its open session when it is in Open now, and
/// briefly otherwise — never by opening a kept-alive session for it.
@Riverpod(retry: _neverRetry)
Future<ComparableFile> comparableFile(Ref ref, TelemetrySource source) async {
  if (!watchSourceOpen(ref, source)) {
    return ref.watch(comparableFactsReaderProvider)(source);
  }
  return ComparableFile(
    metadata: await ref.watch(sessionMetadataProvider(source).future),
    laps: await ref.watch(lapsProvider(source).future),
    course: await ref.watch(courseFactsProvider(source).future),
    clockGaps: await ref.watch(sessionClockGapsProvider(source).future),
  );
}
