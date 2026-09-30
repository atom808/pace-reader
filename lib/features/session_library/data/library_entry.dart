/// What the Session Library remembers about one recording (SPEC.md §8.1,
/// §9.6).
///
/// Everything here is read once, while the file is already open, so the
/// library can list, search and rank sessions across runs without reopening
/// every recording on every launch — the point of §9.6's index. It is a
/// cache of the file, never a second source of truth: the file is re-read
/// whenever its size or modification time moves.
library;

import '../../../data/models/models.dart';

/// Where an indexed session came from.
enum LibrarySourceKind {
  /// A path on disk — desktop. Reopenable from the index for as long as the
  /// file stays where it was.
  file,

  /// Bytes handed over by a browser upload — web. There is no path to go
  /// back to (§9.2), so the entry describes the session but cannot reopen
  /// it; only a fresh upload can.
  upload,
}

/// Size and modification time — the change-detection pair.
///
/// Size alone would miss a recording rewritten to the same length, and mtime
/// alone would treat a copy that preserved its timestamp as the same file
/// even if it were truncated. Together they are what every incremental
/// indexer (rsync's quick check, make) settles on, and both come from one
/// `stat` rather than from opening the file.
class FileFacts {
  const FileFacts({required this.sizeBytes, required this.modifiedMs});

  final int sizeBytes;

  /// Milliseconds since the epoch, kept as an integer rather than a
  /// [DateTime] so equality is exact: the checked-in fixture's mtime is
  /// `1790726677.710` s, and any representation that rounds it (drift's
  /// default Unix-seconds storage does) would make every rescan see a change.
  final int modifiedMs;

  bool matches(LibraryEntry entry) =>
      entry.sizeBytes == sizeBytes && entry.modifiedMs == modifiedMs;

  @override
  bool operator ==(Object other) =>
      other is FileFacts &&
      other.sizeBytes == sizeBytes &&
      other.modifiedMs == modifiedMs;

  @override
  int get hashCode => Object.hash(sizeBytes, modifiedMs);

  @override
  String toString() => 'FileFacts($sizeBytes B, mtime $modifiedMs ms)';
}

/// The facts an index row is built from, read while a session is open.
class SessionFacts {
  const SessionFacts({
    required this.metadata,
    required this.laps,
    required this.clockGapCount,
  });

  final SessionMetadata metadata;
  final List<Lap> laps;

  /// Recording discontinuities found by the master-clock scan (§5.2,
  /// §15.12). §9.6 asks for the count at import time because the file is
  /// already open and it is otherwise invisible later: Practice and Qualify
  /// each have one, Race none.
  final int clockGapCount;
}

/// `(TrackName, TrackLayout)` — the only correct way to group sessions by
/// circuit (§8.1).
typedef TrackLayoutKey = ({String trackName, String trackLayout});

/// The scope a personal best is ranked in: circuit **and** car class.
///
/// Layout is load-bearing for the reason §8.1 gives: the Sebring Race sample
/// is the 3.08 km School Circuit, and a best keyed on `TrackName` alone would
/// set its 1:03.941 against a full-course lap twice as long. Class is the
/// same mistake one dimension over. A GT3 and a Hypercar on the same layout
/// are different cars running to different regulations, so "fastest ever
/// here" across both only ever says which class was driven, never whether
/// the driver improved — a GT3 run would never hold the badge again after
/// one Hypercar session. None of the three samples shares a layout, so the
/// class gap cannot be measured on them; the split is structural, and
/// `CarClass` is the file's own name for it (`"GT3"`, `"Hyper"`). The car
/// itself is deliberately *not* in the key: `CarName` is an opaque composite
/// (§5.1, §15.6) with livery and number in it, and two entries of the same
/// model would never share a best.
typedef PersonalBestKey = ({
  String trackName,
  String trackLayout,
  String carClass,
});

/// One indexed session.
class LibraryEntry {
  const LibraryEntry({
    required this.path,
    required this.fileName,
    required this.kind,
    required this.sizeBytes,
    required this.modifiedMs,
    required this.trackName,
    required this.trackLayout,
    required this.carName,
    required this.carClass,
    required this.sessionType,
    required this.driverName,
    required this.recordingTime,
    required this.weather,
    required this.formatVersion,
    required this.completedLaps,
    required this.timedLaps,
    required this.bestLapSeconds,
    required this.bestLapIndex,
    required this.clockGapCount,
    required this.importedAt,
    this.lastOpenedAt,
  });

  /// Builds the row for a session, carrying over what the index already
  /// knew about it.
  ///
  /// [previous] keeps [importedAt] stable across re-reads — "imported" means
  /// when the library first saw the file, not when it last changed — and
  /// [lastOpenedAt] falls back to the previous value so a rescan does not
  /// forget that a session was ever opened.
  factory LibraryEntry.derive({
    required String path,
    required String fileName,
    required LibrarySourceKind kind,
    required FileFacts file,
    required SessionFacts facts,
    required DateTime now,
    LibraryEntry? previous,
    DateTime? openedAt,
  }) {
    final metadata = facts.metadata;
    final best = facts.laps.bestLap;
    return LibraryEntry(
      path: path,
      fileName: fileName,
      kind: kind,
      sizeBytes: file.sizeBytes,
      modifiedMs: file.modifiedMs,
      trackName: metadata.trackName,
      trackLayout: metadata.trackLayout,
      carName: metadata.carName,
      carClass: metadata.carClass,
      sessionType: metadata.sessionType,
      driverName: metadata.driverName,
      recordingTime: metadata.recordingTime,
      weather: metadata.weatherConditions,
      formatVersion: metadata.version,
      completedLaps: facts.laps.completedCount,
      timedLaps: facts.laps.timed.length,
      bestLapSeconds: best?.lapTimeSeconds,
      bestLapIndex: best?.index,
      clockGapCount: facts.clockGapCount,
      importedAt: previous?.importedAt ?? now,
      lastOpenedAt: openedAt ?? previous?.lastOpenedAt,
    );
  }

  /// The identity of the row: the file's path, or the upload's name.
  final String path;
  final String fileName;
  final LibrarySourceKind kind;

  final int sizeBytes;

  /// See [FileFacts.modifiedMs]. Zero for an upload, which has no mtime.
  final int modifiedMs;

  final String trackName;
  final String trackLayout;
  final String carName;
  final String carClass;
  final SessionType sessionType;
  final String driverName;

  /// `metadata.RecordingTime` verbatim (`2026-07-07T06_42_17Z`) — the same
  /// stamp LMU puts in the filename (§5). [recordedAt] is its parsed form.
  final String recordingTime;
  final String weather;

  /// `metadata.Version` (§5.1, §9.6): `"1"` in every sample. Kept so a
  /// library built by this version can tell a future format apart without
  /// reopening the file.
  final String formatVersion;

  /// Laps with a closing boundary — `COUNT(*)` on `Lap` minus the open final
  /// row (§5.2, §8.2). Includes the garage lap, exactly as the Overview's
  /// "Completed laps" does, so the two screens never disagree.
  final int completedLaps;

  /// Laps usable for pace: timed, closed, and not the garage lap (§8.3.1).
  final int timedLaps;

  /// Null when the session has no timed lap — the Qualify sample has only
  /// one, and an out-and-in run has none.
  final double? bestLapSeconds;

  /// 0-based `Lap` value of the best lap (§5.2); shown `+1`.
  final int? bestLapIndex;

  final int clockGapCount;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;

  /// [recordingTime] as a UTC instant, or null if the file wrote something
  /// this build does not recognise — the library then sorts it last rather
  /// than guessing.
  DateTime? get recordedAt => parseRecordingTime(recordingTime);

  TrackLayoutKey get trackKey =>
      (trackName: trackName, trackLayout: trackLayout);

  PersonalBestKey get personalBestKey =>
      (trackName: trackName, trackLayout: trackLayout, carClass: carClass);

  /// See `SessionMetadata.layoutIsDistinct`: Interlagos names its only
  /// layout after the track, and "X — X" would be noise.
  bool get layoutIsDistinct =>
      trackLayout.isNotEmpty && trackLayout != trackName;

  String get circuitLabel =>
      layoutIsDistinct ? '$trackName — $trackLayout' : trackName;

  int? get bestLapNumber => bestLapIndex == null ? null : bestLapIndex! + 1;

  LibraryEntry copyWith({DateTime? lastOpenedAt}) => LibraryEntry(
    path: path,
    fileName: fileName,
    kind: kind,
    sizeBytes: sizeBytes,
    modifiedMs: modifiedMs,
    trackName: trackName,
    trackLayout: trackLayout,
    carName: carName,
    carClass: carClass,
    sessionType: sessionType,
    driverName: driverName,
    recordingTime: recordingTime,
    weather: weather,
    formatVersion: formatVersion,
    completedLaps: completedLaps,
    timedLaps: timedLaps,
    bestLapSeconds: bestLapSeconds,
    bestLapIndex: bestLapIndex,
    clockGapCount: clockGapCount,
    importedAt: importedAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
  );

  List<Object?> get _fields => [
    path,
    fileName,
    kind,
    sizeBytes,
    modifiedMs,
    trackName,
    trackLayout,
    carName,
    carClass,
    sessionType,
    driverName,
    recordingTime,
    weather,
    formatVersion,
    completedLaps,
    timedLaps,
    bestLapSeconds,
    bestLapIndex,
    clockGapCount,
    importedAt.millisecondsSinceEpoch,
    lastOpenedAt?.millisecondsSinceEpoch,
  ];

  // Instants compare by moment, not by `DateTime ==`, which also compares
  // `isUtc`: a row written in local time and read back in UTC is the same
  // row.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LibraryEntry) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);

  @override
  String toString() =>
      'LibraryEntry($path, $circuitLabel, $carClass, '
      '${sessionType.rawValue}, best $bestLapSeconds)';
}

/// A folder the user asked the library to index (§8.1's scan location).
class LibraryFolder {
  const LibraryFolder({
    required this.path,
    required this.addedAt,
    this.lastScannedAt,
    this.lastScanFileCount,
  });

  final String path;
  final DateTime addedAt;

  /// Null until the first scan finishes.
  final DateTime? lastScannedAt;

  /// `.duckdb` files the last scan found — what the folder chip reports.
  final int? lastScanFileCount;

  LibraryFolder scanned({required DateTime at, required int fileCount}) =>
      LibraryFolder(
        path: path,
        addedAt: addedAt,
        lastScannedAt: at,
        lastScanFileCount: fileCount,
      );

  @override
  bool operator ==(Object other) =>
      other is LibraryFolder &&
      other.path == path &&
      other.addedAt.isAtSameMomentAs(addedAt) &&
      other.lastScannedAt?.millisecondsSinceEpoch ==
          lastScannedAt?.millisecondsSinceEpoch &&
      other.lastScanFileCount == lastScanFileCount;

  @override
  int get hashCode => Object.hash(
    path,
    addedAt.millisecondsSinceEpoch,
    lastScannedAt?.millisecondsSinceEpoch,
    lastScanFileCount,
  );
}

/// `metadata.RecordingTime` → a UTC instant.
///
/// LMU writes ISO-8601 with the time separators swapped for underscores
/// (`2026-07-07T06_42_17Z`) because the same string goes into the filename,
/// where `:` is illegal on Windows (§5). All three samples use exactly this
/// shape.
DateTime? parseRecordingTime(String raw) {
  final match = _recordingTime.firstMatch(raw.trim());
  if (match == null) return null;
  int part(int i) => int.parse(match.group(i)!);
  return DateTime.utc(part(1), part(2), part(3), part(4), part(5), part(6));
}

final _recordingTime = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2})[_:](\d{2})[_:](\d{2})Z$',
);

/// Newest recording first — the library's one ordering.
///
/// Defined once, in Dart, rather than as an `ORDER BY` in the drift store:
/// the web build keeps its index in memory (see `session_index_store.dart`),
/// and two definitions of "newest" would eventually disagree. A session
/// whose recording time can't be parsed sorts after every one that can, then
/// by when it was imported, then by path so the order is total.
int compareNewestFirst(LibraryEntry a, LibraryEntry b) {
  final ra = a.recordedAt, rb = b.recordedAt;
  if (ra != null && rb != null) {
    final byRecording = rb.compareTo(ra);
    if (byRecording != 0) return byRecording;
  } else if (ra != null) {
    return -1;
  } else if (rb != null) {
    return 1;
  }
  final byImport = b.importedAt.compareTo(a.importedAt);
  if (byImport != 0) return byImport;
  return a.path.compareTo(b.path);
}
