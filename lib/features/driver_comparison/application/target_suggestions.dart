/// Which laps to compare against (comparison proposal §4, "Suggested
/// targets").
///
/// All local: the library index and Base's own file. Nothing is opened to
/// suggest a lap — a suggestion is a row the index already holds, and the
/// course gate checks it when it is chosen.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_ref.dart';
import '../../../data/repositories/providers.dart';
import '../../session_library/application/library_query.dart';
import '../../session_library/application/session_library.dart';
import '../../session_library/data/library_entry.dart';
import '../domain/comparison_set.dart';
import 'compare_source_guard.dart';

part 'target_suggestions.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// Where a suggestion comes from, in the order they are offered.
enum SuggestionKind {
  /// Another recording of the course, 0.2–2.0 s faster than Base.
  librarySession,

  /// The fastest lap on record for the course and Base's class.
  personalBest,

  /// The fastest lap of Base's own file.
  fileBest,
}

class TargetSuggestion {
  const TargetSuggestion({
    required this.kind,
    required this.lap,
    required this.lapSeconds,
    required this.gapSeconds,
    this.entry,
    this.sameCar = false,
  });

  final SuggestionKind kind;

  /// The lap suggested. Its file is open only for [SuggestionKind.fileBest];
  /// choosing any other opens it behind the current session.
  final LapRef lap;

  final double lapSeconds;

  /// Base's lap time minus this lap's: how much faster it is.
  final double gapSeconds;

  /// The library row holding the lap; null for Base's own file.
  final LibraryEntry? entry;

  final bool sameCar;

  /// So much faster that most segments will read as losses (§4: more than
  /// 2.0 s ahead).
  bool get tooFast => gapSeconds > suggestionWindow.max;
}

/// A Target is most useful 0.2–2.0 s faster than Base: Garage 61 advises
/// "around a second"; further than that "everything shows as a loss"
/// (Coach Dave Delta). Measured on the library, an in-window session exists
/// for 82% of recordings.
const suggestionWindow = (min: 0.2, max: 2.0);

/// How many library sessions are offered beside the PB and the file's best.
const librarySuggestionCount = 3;

/// Suggestions for [set]'s Base: library sessions in the window, the PB
/// here, and the fastest lap of Base's file — never Base's own lap, and
/// never the Target already chosen.
@Riverpod(retry: _neverRetry)
Future<List<TargetSuggestion>> targetSuggestions(
  Ref ref,
  ComparisonSet set,
) async {
  final base = set.base;
  requireSourceOpen(ref, base.source, ComparisonRole.base);
  final metadata = await ref.watch(sessionMetadataProvider(base.source).future);
  final laps = await ref.watch(lapsProvider(base.source).future);
  final entries = await ref.watch(sessionLibraryProvider.future);
  return suggestTargets(
    base: base,
    metadata: metadata,
    laps: laps,
    library: entries,
    chosen: set.target,
  );
}

/// The ranking itself, pure.
List<TargetSuggestion> suggestTargets({
  required LapRef base,
  required SessionMetadata metadata,
  required List<Lap> laps,
  required List<LibraryEntry> library,
  LapRef? chosen,
}) {
  final baseSeconds = laps
      .where((l) => l.index == base.lapIndex)
      .firstOrNull
      ?.lapTimeSeconds;
  final baseRecording = metadata.recordingIdentity;
  final out = <TargetSuggestion>[];
  // One lap of one recording is offered once, whichever file holds a copy.
  final offered = <(RecordingIdentity, int)>{(baseRecording, base.lapIndex)};
  if (chosen != null) {
    final recording = chosen.source == base.source
        ? baseRecording
        : _recordingOf(chosen, library);
    if (recording != null) offered.add((recording, chosen.lapIndex));
  }

  if (baseSeconds != null) {
    final sameCourse = [
      for (final e in library)
        if (e.kind == LibrarySourceKind.file &&
            e.trackName == metadata.trackName &&
            e.trackLayout == metadata.trackLayout &&
            e.recordingIdentity != baseRecording &&
            e.bestLapSeconds != null &&
            e.bestLapIndex != null &&
            baseSeconds - e.bestLapSeconds! >= suggestionWindow.min &&
            baseSeconds - e.bestLapSeconds! <= suggestionWindow.max)
          e,
    ];
    // Conditions first — the car is the one condition the index holds —
    // then the gap nearest a second.
    double fromOneSecond(LibraryEntry e) =>
        ((baseSeconds - e.bestLapSeconds!) - 1.0).abs();
    int sameCar(LibraryEntry e) => e.carName == metadata.carName ? 0 : 1;
    sameCourse.sort((a, b) {
      final car = sameCar(a).compareTo(sameCar(b));
      return car != 0 ? car : fromOneSecond(a).compareTo(fromOneSecond(b));
    });
    for (final e in sameCourse) {
      if (out.length >= librarySuggestionCount) break;
      if (!offered.add((e.recordingIdentity, e.bestLapIndex!))) continue;
      out.add(
        TargetSuggestion(
          kind: SuggestionKind.librarySession,
          lap: LapRef(TelemetrySource.path(e.path), e.bestLapIndex!),
          lapSeconds: e.bestLapSeconds!,
          gapSeconds: baseSeconds - e.bestLapSeconds!,
          entry: e,
          sameCar: e.carName == metadata.carName,
        ),
      );
    }

    final pb =
        personalBestsOf(library)[(
          trackName: metadata.trackName,
          trackLayout: metadata.trackLayout,
          carClass: metadata.carClass,
        )];
    final holder = pb == null
        ? null
        : library.where((e) => e.path == pb.path).firstOrNull;
    if (pb != null &&
        holder != null &&
        pb.lapSeconds < baseSeconds &&
        offered.add((holder.recordingIdentity, pb.lapIndex))) {
      out.add(
        TargetSuggestion(
          kind: SuggestionKind.personalBest,
          lap: holder.recordingIdentity == baseRecording
              ? LapRef(base.source, pb.lapIndex)
              : LapRef(TelemetrySource.path(holder.path), pb.lapIndex),
          lapSeconds: pb.lapSeconds,
          gapSeconds: baseSeconds - pb.lapSeconds,
          entry: holder,
          sameCar: holder.carName == metadata.carName,
        ),
      );
    }
  }

  final best = laps.bestLap;
  if (best != null && offered.add((baseRecording, best.index))) {
    out.add(
      TargetSuggestion(
        kind: SuggestionKind.fileBest,
        lap: LapRef(base.source, best.index),
        lapSeconds: best.lapTimeSeconds!,
        gapSeconds: baseSeconds == null
            ? 0
            : baseSeconds - best.lapTimeSeconds!,
        sameCar: true,
      ),
    );
  }
  return out;
}

RecordingIdentity? _recordingOf(LapRef lap, List<LibraryEntry> library) {
  final source = lap.source;
  if (source is! FileTelemetrySource) return null;
  final key = source.canonicalPath;
  return library
      .where((e) => canonicalSessionPath(e.path) == key)
      .firstOrNull
      ?.recordingIdentity;
}
