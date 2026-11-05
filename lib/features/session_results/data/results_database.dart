/// The desktop results index: a drift (SQLite) database of its own, beside
/// the Session Library's (results proposal, R1).
///
/// Separate on purpose. It is a cache of LMU's results files and can be
/// rebuilt from them at any time; the library's database also holds things
/// the files can't give back (remembered folders, "last opened"), and a
/// migration here should never be able to touch those.
///
/// Every value is a column of its own, named after the file's attribute where
/// it has one, so a row can be checked by eye against the XML.
library;

import 'package:drift/drift.dart';

import '../../session_library/data/library_entry.dart';
import '../domain/results_link.dart';
import '../domain/results_session.dart';
import 'results_index_store.dart';

part 'results_database.g.dart';

/// One row per results file.
@DataClassName('ResultsFileRow')
class ResultsFiles extends Table {
  /// What the other tables point at: an integer, so the path is stored once
  /// rather than on each of ~900k lap and event rows and again in each of
  /// their keys, which made the first full index 370 MB.
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  IntColumn get sizeBytes => integer()();
  IntColumn get modifiedMs => integer()();
  DateTimeColumn get indexedAt => dateTime()();

  TextColumn get sessionElement => text()();

  /// [ResultsSessionKind.name].
  TextColumn get kind => text()();

  /// UTC epoch milliseconds, as integers so the window query is exact.
  IntColumn get startedAtMs => integer()();
  IntColumn get endsAtMs => integer()();
  IntColumn get weekendStartedAtMs => integer()();
  TextColumn get setting => text()();
  TextColumn get serverName => text()();
  TextColumn get trackVenue => text()();
  TextColumn get trackCourse => text()();
  TextColumn get trackEvent => text()();
  RealColumn get trackLengthMetres => real().nullable()();
  TextColumn get gameVersion => text()();
  IntColumn get raceLaps => integer().nullable()();
  IntColumn get raceMinutes => integer().nullable()();
  RealColumn get fuelMultiplier => real().nullable()();
  RealColumn get tyreMultiplier => real().nullable()();
  RealColumn get damagePercent => real().nullable()();
}

/// One row per `<Driver>`.
@DataClassName('ResultsDriverRow')
class ResultsDrivers extends Table {
  /// [ResultsFiles.id].
  IntColumn get fileId => integer()();
  IntColumn get driverIndex => integer()();
  TextColumn get name => text()();
  BoolColumn get isPlayer => boolean()();
  TextColumn get vehicleFile => text()();
  TextColumn get vehicleName => text()();
  TextColumn get carType => text()();
  TextColumn get carClass => text()();
  TextColumn get category => text()();
  TextColumn get teamName => text()();
  TextColumn get carNumber => text()();
  IntColumn get gridPosition => integer().nullable()();
  IntColumn get classGridPosition => integer().nullable()();
  IntColumn get position => integer().nullable()();
  IntColumn get classPosition => integer().nullable()();
  RealColumn get bestLapSeconds => real().nullable()();
  RealColumn get finishElapsed => real().nullable()();
  IntColumn get lapsCompleted => integer()();
  IntColumn get pitStops => integer()();
  TextColumn get finishStatus => text()();
  TextColumn get dnfReason => text().nullable()();

  /// `<Swap>` and `<ControlAndAids>` ranges, one per line as
  /// `start<TAB>end<TAB>value` ([encodeStints]).
  TextColumn get swaps => text()();
  TextColumn get aids => text()();

  @override
  Set<Column<Object>> get primaryKey => {fileId, driverIndex};

  /// The key is the row: no second copy of it in a rowid table.
  @override
  bool get withoutRowId => true;
}

/// One row per `<Lap>`.
@DataClassName('ResultsLapRow')
class ResultsLaps extends Table {
  /// [ResultsFiles.id].
  IntColumn get fileId => integer()();
  IntColumn get driverIndex => integer()();

  /// Order within the car's laps. The key, rather than [number], so a file
  /// that ever repeats a lap number still stores both.
  IntColumn get seq => integer()();
  IntColumn get number => integer()();
  IntColumn get position => integer().nullable()();
  RealColumn get startElapsed => real().nullable()();
  RealColumn get lapSeconds => real().nullable()();
  RealColumn get sector1Seconds => real().nullable()();
  RealColumn get sector2Seconds => real().nullable()();
  RealColumn get sector3Seconds => real().nullable()();
  RealColumn get topSpeedKmh => real().nullable()();
  RealColumn get fuelFraction => real().nullable()();
  RealColumn get fuelUsedFraction => real().nullable()();
  RealColumn get energyFraction => real().nullable()();
  RealColumn get energyUsedFraction => real().nullable()();
  RealColumn get wearFrontLeft => real().nullable()();
  RealColumn get wearFrontRight => real().nullable()();
  RealColumn get wearRearLeft => real().nullable()();
  RealColumn get wearRearRight => real().nullable()();
  TextColumn get compoundFront => text().nullable()();
  TextColumn get compoundRear => text().nullable()();
  BoolColumn get pit => boolean()();

  @override
  Set<Column<Object>> get primaryKey => {fileId, driverIndex, seq};

  @override
  bool get withoutRowId => true;
}

/// One row per race-control line.
@DataClassName('ResultsEventRow')
class ResultsEvents extends Table {
  /// [ResultsFiles.id].
  IntColumn get fileId => integer()();
  IntColumn get seq => integer()();

  /// [ResultsEventKind.name].
  TextColumn get kind => text()();
  RealColumn get elapsed => real()();
  TextColumn get body => text()();
  TextColumn get driverName => text().nullable()();
  IntColumn get slot => integer().nullable()();
  IntColumn get lap => integer().nullable()();
  IntColumn get resolution => integer().nullable()();
  RealColumn get warningPoints => real().nullable()();
  RealColumn get currentPoints => real().nullable()();
  TextColumn get penalty => text().nullable()();
  TextColumn get reason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {fileId, seq};

  @override
  bool get withoutRowId => true;
}

@DataClassName('ResultsFolderRow')
class ResultsFolders extends Table {
  TextColumn get path => text()();
  DateTimeColumn get addedAt => dateTime()();
  DateTimeColumn get lastScannedAt => dateTime().nullable()();
  IntColumn get lastScanFileCount => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DriftDatabase(
  tables: [
    ResultsFiles,
    ResultsDrivers,
    ResultsLaps,
    ResultsEvents,
    ResultsFolders,
  ],
)
class ResultsDatabase extends _$ResultsDatabase {
  ResultsDatabase(super.executor);

  /// A cache of the files: a future schema change can drop and refill every
  /// table but [ResultsFolders] with a rescan.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // The link query: one track, one kind, a time window.
      await customStatement(
        'CREATE INDEX results_files_by_track ON results_files '
        '(track_venue, track_course, kind, started_at_ms)',
      );
    },
  );
}

/// `start<TAB>end<TAB>value` per line.
String encodeStints(List<ResultsStint> stints) => [
  for (final s in stints)
    '${s.startLap}\t${s.endLap}\t${s.value.replaceAll(RegExp(r'[\t\n]'), ' ')}',
].join('\n');

List<ResultsStint> decodeStints(String text) => [
  for (final line in text.split('\n'))
    if (line.isNotEmpty)
      if (line.split('\t') case [final start, final end, final value])
        ResultsStint(
          startLap: int.tryParse(start) ?? 0,
          endLap: int.tryParse(end) ?? 0,
          value: value,
        ),
];

/// [ResultsIndexStore] over [ResultsDatabase].
class DriftResultsIndexStore implements ResultsIndexStore {
  DriftResultsIndexStore(this._db);

  final ResultsDatabase _db;

  @override
  Future<Map<String, FileFacts>> readFileFacts() async {
    final rows =
        await (_db.selectOnly(_db.resultsFiles)..addColumns([
              _db.resultsFiles.path,
              _db.resultsFiles.sizeBytes,
              _db.resultsFiles.modifiedMs,
            ]))
            .get();
    return {
      for (final row in rows)
        row.read(_db.resultsFiles.path)!: FileFacts(
          sizeBytes: row.read(_db.resultsFiles.sizeBytes)!,
          modifiedMs: row.read(_db.resultsFiles.modifiedMs)!,
        ),
    };
  }

  @override
  Future<void> putSession(ResultsFileRecord record, ResultsSession s) =>
      _db.transaction(() async {
        await _deleteContent(record.path);
        final fileId = await _db
            .into(_db.resultsFiles)
            .insert(
              ResultsFilesCompanion.insert(
                path: record.path,
                sizeBytes: record.file.sizeBytes,
                modifiedMs: record.file.modifiedMs,
                indexedAt: record.indexedAt,
                sessionElement: s.sessionElement,
                kind: s.kind.name,
                startedAtMs: s.startedAt.millisecondsSinceEpoch,
                endsAtMs: s.endsAt.millisecondsSinceEpoch,
                weekendStartedAtMs: s.weekendStartedAt.millisecondsSinceEpoch,
                setting: s.setting,
                serverName: s.serverName,
                trackVenue: s.trackVenue,
                trackCourse: s.trackCourse,
                trackEvent: s.trackEvent,
                trackLengthMetres: Value(s.trackLengthMetres),
                gameVersion: s.gameVersion,
                raceLaps: Value(s.raceLaps),
                raceMinutes: Value(s.raceMinutes),
                fuelMultiplier: Value(s.fuelMultiplier),
                tyreMultiplier: Value(s.tyreMultiplier),
                damagePercent: Value(s.damagePercent),
              ),
            );
        await _db.batch((b) {
          b.insertAll(_db.resultsDrivers, [
            for (final d in s.drivers)
              ResultsDriversCompanion.insert(
                fileId: fileId,
                driverIndex: d.index,
                name: d.name,
                isPlayer: d.isPlayer,
                vehicleFile: d.vehicleFile,
                vehicleName: d.vehicleName,
                carType: d.carType,
                carClass: d.carClass,
                category: d.category,
                teamName: d.teamName,
                carNumber: d.carNumber,
                gridPosition: Value(d.gridPosition),
                classGridPosition: Value(d.classGridPosition),
                position: Value(d.position),
                classPosition: Value(d.classPosition),
                bestLapSeconds: Value(d.bestLapSeconds),
                finishElapsed: Value(d.finishElapsed),
                lapsCompleted: d.lapsCompleted,
                pitStops: d.pitStops,
                finishStatus: d.finishStatus,
                dnfReason: Value(d.dnfReason),
                swaps: encodeStints(d.swaps),
                aids: encodeStints(d.aids),
              ),
          ]);
          b.insertAll(_db.resultsLaps, [
            for (final d in s.drivers)
              for (final (seq, l) in d.laps.indexed)
                ResultsLapsCompanion.insert(
                  fileId: fileId,
                  driverIndex: d.index,
                  seq: seq,
                  number: l.number,
                  position: Value(l.position),
                  startElapsed: Value(l.startElapsed),
                  lapSeconds: Value(l.lapSeconds),
                  sector1Seconds: Value(l.sector1Seconds),
                  sector2Seconds: Value(l.sector2Seconds),
                  sector3Seconds: Value(l.sector3Seconds),
                  topSpeedKmh: Value(l.topSpeedKmh),
                  fuelFraction: Value(l.fuelFraction),
                  fuelUsedFraction: Value(l.fuelUsedFraction),
                  energyFraction: Value(l.energyFraction),
                  energyUsedFraction: Value(l.energyUsedFraction),
                  wearFrontLeft: Value(l.wearFrontLeft),
                  wearFrontRight: Value(l.wearFrontRight),
                  wearRearLeft: Value(l.wearRearLeft),
                  wearRearRight: Value(l.wearRearRight),
                  compoundFront: Value(l.compoundFront),
                  compoundRear: Value(l.compoundRear),
                  pit: l.pit,
                ),
          ]);
          b.insertAll(_db.resultsEvents, [
            for (final (seq, e) in s.events.indexed)
              ResultsEventsCompanion.insert(
                fileId: fileId,
                seq: seq,
                kind: e.kind.name,
                elapsed: e.elapsed,
                body: e.text,
                driverName: Value(e.driverName),
                slot: Value(e.slot),
                lap: Value(e.lap),
                resolution: Value(e.resolution),
                warningPoints: Value(e.warningPoints),
                currentPoints: Value(e.currentPoints),
                penalty: Value(e.penalty),
                reason: Value(e.reason),
              ),
          ]);
        });
      });

  Future<ResultsFileRow?> _file(String path) => (_db.select(
    _db.resultsFiles,
  )..where((t) => t.path.equals(path))).getSingleOrNull();

  Future<void> _deleteContent(String path) async {
    final file = await _file(path);
    if (file == null) return;
    final id = file.id;
    await (_db.delete(
      _db.resultsDrivers,
    )..where((t) => t.fileId.equals(id))).go();
    await (_db.delete(_db.resultsLaps)..where((t) => t.fileId.equals(id))).go();
    await (_db.delete(
      _db.resultsEvents,
    )..where((t) => t.fileId.equals(id))).go();
    await (_db.delete(_db.resultsFiles)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<ResultsSession?> readSession(String path) async {
    final file = await _file(path);
    if (file == null) return null;
    final id = file.id;
    final drivers =
        await (_db.select(_db.resultsDrivers)
              ..where((t) => t.fileId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.driverIndex)]))
            .get();
    final laps =
        await (_db.select(_db.resultsLaps)
              ..where((t) => t.fileId.equals(id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.driverIndex),
                (t) => OrderingTerm.asc(t.seq),
              ]))
            .get();
    final events =
        await (_db.select(_db.resultsEvents)
              ..where((t) => t.fileId.equals(id))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
            .get();
    final lapsByDriver = <int, List<ResultsLap>>{};
    for (final l in laps) {
      (lapsByDriver[l.driverIndex] ??= []).add(_lap(l));
    }
    return _session(file).copyWith(
      drivers: [
        for (final d in drivers)
          _driver(d).copyWith(laps: lapsByDriver[d.driverIndex] ?? const []),
      ],
      events: [for (final e in events) ?_event(e)],
    );
  }

  @override
  Future<List<ResultsCandidate>> candidates({
    required String trackVenue,
    required String trackCourse,
    required ResultsSessionKind kind,
    required DateTime from,
    required DateTime to,
  }) async {
    final files =
        await (_db.select(_db.resultsFiles)..where(
              (t) =>
                  t.trackVenue.equals(trackVenue) &
                  t.trackCourse.equals(trackCourse) &
                  t.kind.equals(kind.name) &
                  t.startedAtMs.isSmallerOrEqualValue(
                    to.millisecondsSinceEpoch,
                  ) &
                  t.endsAtMs.isBiggerOrEqualValue(from.millisecondsSinceEpoch),
            ))
            .get();
    if (files.isEmpty) return const [];
    final ids = [for (final f in files) f.id];
    final drivers = await (_db.select(
      _db.resultsDrivers,
    )..where((t) => t.fileId.isIn(ids))).get();
    final lapRows =
        await (_db.selectOnly(_db.resultsLaps)
              ..addColumns([
                _db.resultsLaps.fileId,
                _db.resultsLaps.driverIndex,
                _db.resultsLaps.lapSeconds,
              ])
              ..where(
                _db.resultsLaps.fileId.isIn(ids) &
                    _db.resultsLaps.lapSeconds.isNotNull(),
              ))
            .get();
    final times = <(int, int), List<double>>{};
    for (final row in lapRows) {
      final key = (
        row.read(_db.resultsLaps.fileId)!,
        row.read(_db.resultsLaps.driverIndex)!,
      );
      (times[key] ??= []).add(row.read(_db.resultsLaps.lapSeconds)!);
    }
    return [
      for (final f in files)
        ResultsCandidate(
          path: f.path,
          kind: _kind(f.kind),
          trackVenue: f.trackVenue,
          trackCourse: f.trackCourse,
          startedAt: _utc(f.startedAtMs),
          endsAt: _utc(f.endsAtMs),
          drivers: [
            for (final d in drivers)
              if (d.fileId == f.id)
                ResultsCandidateDriver(
                  index: d.driverIndex,
                  driverNames: _driver(d).driverNames,
                  isPlayer: d.isPlayer,
                  vehicleName: d.vehicleName,
                  carClass: d.carClass,
                  lapTimes: times[(f.id, d.driverIndex)] ?? const [],
                ),
          ],
        ),
    ];
  }

  @override
  Future<int> sessionCount() async {
    final count = _db.resultsFiles.id.count();
    final row = await (_db.selectOnly(
      _db.resultsFiles,
    )..addColumns([count])).getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<List<LibraryFolder>> readFolders() async {
    final rows = await (_db.select(
      _db.resultsFolders,
    )..orderBy([(t) => OrderingTerm.asc(t.addedAt)])).get();
    return [
      for (final row in rows)
        LibraryFolder(
          path: row.path,
          addedAt: row.addedAt,
          lastScannedAt: row.lastScannedAt,
          lastScanFileCount: row.lastScanFileCount,
        ),
    ];
  }

  @override
  Future<void> upsertFolder(LibraryFolder folder) => _db
      .into(_db.resultsFolders)
      .insertOnConflictUpdate(
        ResultsFoldersCompanion.insert(
          path: folder.path,
          addedAt: folder.addedAt,
          lastScannedAt: Value(folder.lastScannedAt),
          lastScanFileCount: Value(folder.lastScanFileCount),
        ),
      );

  @override
  Future<void> removeFolder(String path) =>
      (_db.delete(_db.resultsFolders)..where((t) => t.path.equals(path))).go();

  @override
  Future<void> close() => _db.close();

  static DateTime _utc(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

  static ResultsSessionKind _kind(String name) =>
      ResultsSessionKind.values.asNameMap()[name] ?? ResultsSessionKind.other;

  static ResultsSession _session(ResultsFileRow f) => ResultsSession(
    sessionElement: f.sessionElement,
    kind: _kind(f.kind),
    startedAt: _utc(f.startedAtMs),
    weekendStartedAt: _utc(f.weekendStartedAtMs),
    setting: f.setting,
    serverName: f.serverName,
    trackVenue: f.trackVenue,
    trackCourse: f.trackCourse,
    trackEvent: f.trackEvent,
    trackLengthMetres: f.trackLengthMetres,
    gameVersion: f.gameVersion,
    raceLaps: f.raceLaps,
    raceMinutes: f.raceMinutes,
    fuelMultiplier: f.fuelMultiplier,
    tyreMultiplier: f.tyreMultiplier,
    damagePercent: f.damagePercent,
  );

  static ResultsDriver _driver(ResultsDriverRow d) => ResultsDriver(
    index: d.driverIndex,
    name: d.name,
    isPlayer: d.isPlayer,
    vehicleFile: d.vehicleFile,
    vehicleName: d.vehicleName,
    carType: d.carType,
    carClass: d.carClass,
    category: d.category,
    teamName: d.teamName,
    carNumber: d.carNumber,
    gridPosition: d.gridPosition,
    classGridPosition: d.classGridPosition,
    position: d.position,
    classPosition: d.classPosition,
    bestLapSeconds: d.bestLapSeconds,
    finishElapsed: d.finishElapsed,
    lapsCompleted: d.lapsCompleted,
    pitStops: d.pitStops,
    finishStatus: d.finishStatus,
    dnfReason: d.dnfReason,
    swaps: decodeStints(d.swaps),
    aids: decodeStints(d.aids),
  );

  static ResultsLap _lap(ResultsLapRow l) => ResultsLap(
    number: l.number,
    position: l.position,
    startElapsed: l.startElapsed,
    lapSeconds: l.lapSeconds,
    sector1Seconds: l.sector1Seconds,
    sector2Seconds: l.sector2Seconds,
    sector3Seconds: l.sector3Seconds,
    topSpeedKmh: l.topSpeedKmh,
    fuelFraction: l.fuelFraction,
    fuelUsedFraction: l.fuelUsedFraction,
    energyFraction: l.energyFraction,
    energyUsedFraction: l.energyUsedFraction,
    wearFrontLeft: l.wearFrontLeft,
    wearFrontRight: l.wearFrontRight,
    wearRearLeft: l.wearRearLeft,
    wearRearRight: l.wearRearRight,
    compoundFront: l.compoundFront,
    compoundRear: l.compoundRear,
    pit: l.pit,
  );

  /// Null for a kind this build doesn't know (a row from a newer build).
  static ResultsEvent? _event(ResultsEventRow e) {
    final kind = ResultsEventKind.values.asNameMap()[e.kind];
    if (kind == null) return null;
    return ResultsEvent(
      kind: kind,
      elapsed: e.elapsed,
      text: e.body,
      driverName: e.driverName,
      slot: e.slot,
      lap: e.lap,
      resolution: e.resolution,
      warningPoints: e.warningPoints,
      currentPoints: e.currentPoints,
      penalty: e.penalty,
      reason: e.reason,
    );
  }
}
