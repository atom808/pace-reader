// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'results_database.dart';

// ignore_for_file: type=lint
class $ResultsFilesTable extends ResultsFiles
    with TableInfo<$ResultsFilesTable, ResultsFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiedMsMeta = const VerificationMeta(
    'modifiedMs',
  );
  @override
  late final GeneratedColumn<int> modifiedMs = GeneratedColumn<int>(
    'modified_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _indexedAtMeta = const VerificationMeta(
    'indexedAt',
  );
  @override
  late final GeneratedColumn<DateTime> indexedAt = GeneratedColumn<DateTime>(
    'indexed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionElementMeta = const VerificationMeta(
    'sessionElement',
  );
  @override
  late final GeneratedColumn<String> sessionElement = GeneratedColumn<String>(
    'session_element',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMsMeta = const VerificationMeta(
    'startedAtMs',
  );
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
    'started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMsMeta = const VerificationMeta(
    'endsAtMs',
  );
  @override
  late final GeneratedColumn<int> endsAtMs = GeneratedColumn<int>(
    'ends_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weekendStartedAtMsMeta =
      const VerificationMeta('weekendStartedAtMs');
  @override
  late final GeneratedColumn<int> weekendStartedAtMs = GeneratedColumn<int>(
    'weekend_started_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settingMeta = const VerificationMeta(
    'setting',
  );
  @override
  late final GeneratedColumn<String> setting = GeneratedColumn<String>(
    'setting',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverNameMeta = const VerificationMeta(
    'serverName',
  );
  @override
  late final GeneratedColumn<String> serverName = GeneratedColumn<String>(
    'server_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackVenueMeta = const VerificationMeta(
    'trackVenue',
  );
  @override
  late final GeneratedColumn<String> trackVenue = GeneratedColumn<String>(
    'track_venue',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackCourseMeta = const VerificationMeta(
    'trackCourse',
  );
  @override
  late final GeneratedColumn<String> trackCourse = GeneratedColumn<String>(
    'track_course',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackEventMeta = const VerificationMeta(
    'trackEvent',
  );
  @override
  late final GeneratedColumn<String> trackEvent = GeneratedColumn<String>(
    'track_event',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackLengthMetresMeta = const VerificationMeta(
    'trackLengthMetres',
  );
  @override
  late final GeneratedColumn<double> trackLengthMetres =
      GeneratedColumn<double>(
        'track_length_metres',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _gameVersionMeta = const VerificationMeta(
    'gameVersion',
  );
  @override
  late final GeneratedColumn<String> gameVersion = GeneratedColumn<String>(
    'game_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raceLapsMeta = const VerificationMeta(
    'raceLaps',
  );
  @override
  late final GeneratedColumn<int> raceLaps = GeneratedColumn<int>(
    'race_laps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _raceMinutesMeta = const VerificationMeta(
    'raceMinutes',
  );
  @override
  late final GeneratedColumn<int> raceMinutes = GeneratedColumn<int>(
    'race_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelMultiplierMeta = const VerificationMeta(
    'fuelMultiplier',
  );
  @override
  late final GeneratedColumn<double> fuelMultiplier = GeneratedColumn<double>(
    'fuel_multiplier',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tyreMultiplierMeta = const VerificationMeta(
    'tyreMultiplier',
  );
  @override
  late final GeneratedColumn<double> tyreMultiplier = GeneratedColumn<double>(
    'tyre_multiplier',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _damagePercentMeta = const VerificationMeta(
    'damagePercent',
  );
  @override
  late final GeneratedColumn<double> damagePercent = GeneratedColumn<double>(
    'damage_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    sizeBytes,
    modifiedMs,
    indexedAt,
    sessionElement,
    kind,
    startedAtMs,
    endsAtMs,
    weekendStartedAtMs,
    setting,
    serverName,
    trackVenue,
    trackCourse,
    trackEvent,
    trackLengthMetres,
    gameVersion,
    raceLaps,
    raceMinutes,
    fuelMultiplier,
    tyreMultiplier,
    damagePercent,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResultsFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('modified_ms')) {
      context.handle(
        _modifiedMsMeta,
        modifiedMs.isAcceptableOrUnknown(data['modified_ms']!, _modifiedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_modifiedMsMeta);
    }
    if (data.containsKey('indexed_at')) {
      context.handle(
        _indexedAtMeta,
        indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_indexedAtMeta);
    }
    if (data.containsKey('session_element')) {
      context.handle(
        _sessionElementMeta,
        sessionElement.isAcceptableOrUnknown(
          data['session_element']!,
          _sessionElementMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionElementMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
        _startedAtMsMeta,
        startedAtMs.isAcceptableOrUnknown(
          data['started_at_ms']!,
          _startedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMsMeta);
    }
    if (data.containsKey('ends_at_ms')) {
      context.handle(
        _endsAtMsMeta,
        endsAtMs.isAcceptableOrUnknown(data['ends_at_ms']!, _endsAtMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endsAtMsMeta);
    }
    if (data.containsKey('weekend_started_at_ms')) {
      context.handle(
        _weekendStartedAtMsMeta,
        weekendStartedAtMs.isAcceptableOrUnknown(
          data['weekend_started_at_ms']!,
          _weekendStartedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weekendStartedAtMsMeta);
    }
    if (data.containsKey('setting')) {
      context.handle(
        _settingMeta,
        setting.isAcceptableOrUnknown(data['setting']!, _settingMeta),
      );
    } else if (isInserting) {
      context.missing(_settingMeta);
    }
    if (data.containsKey('server_name')) {
      context.handle(
        _serverNameMeta,
        serverName.isAcceptableOrUnknown(data['server_name']!, _serverNameMeta),
      );
    } else if (isInserting) {
      context.missing(_serverNameMeta);
    }
    if (data.containsKey('track_venue')) {
      context.handle(
        _trackVenueMeta,
        trackVenue.isAcceptableOrUnknown(data['track_venue']!, _trackVenueMeta),
      );
    } else if (isInserting) {
      context.missing(_trackVenueMeta);
    }
    if (data.containsKey('track_course')) {
      context.handle(
        _trackCourseMeta,
        trackCourse.isAcceptableOrUnknown(
          data['track_course']!,
          _trackCourseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackCourseMeta);
    }
    if (data.containsKey('track_event')) {
      context.handle(
        _trackEventMeta,
        trackEvent.isAcceptableOrUnknown(data['track_event']!, _trackEventMeta),
      );
    } else if (isInserting) {
      context.missing(_trackEventMeta);
    }
    if (data.containsKey('track_length_metres')) {
      context.handle(
        _trackLengthMetresMeta,
        trackLengthMetres.isAcceptableOrUnknown(
          data['track_length_metres']!,
          _trackLengthMetresMeta,
        ),
      );
    }
    if (data.containsKey('game_version')) {
      context.handle(
        _gameVersionMeta,
        gameVersion.isAcceptableOrUnknown(
          data['game_version']!,
          _gameVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gameVersionMeta);
    }
    if (data.containsKey('race_laps')) {
      context.handle(
        _raceLapsMeta,
        raceLaps.isAcceptableOrUnknown(data['race_laps']!, _raceLapsMeta),
      );
    }
    if (data.containsKey('race_minutes')) {
      context.handle(
        _raceMinutesMeta,
        raceMinutes.isAcceptableOrUnknown(
          data['race_minutes']!,
          _raceMinutesMeta,
        ),
      );
    }
    if (data.containsKey('fuel_multiplier')) {
      context.handle(
        _fuelMultiplierMeta,
        fuelMultiplier.isAcceptableOrUnknown(
          data['fuel_multiplier']!,
          _fuelMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('tyre_multiplier')) {
      context.handle(
        _tyreMultiplierMeta,
        tyreMultiplier.isAcceptableOrUnknown(
          data['tyre_multiplier']!,
          _tyreMultiplierMeta,
        ),
      );
    }
    if (data.containsKey('damage_percent')) {
      context.handle(
        _damagePercentMeta,
        damagePercent.isAcceptableOrUnknown(
          data['damage_percent']!,
          _damagePercentMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ResultsFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResultsFileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      modifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_ms'],
      )!,
      indexedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}indexed_at'],
      )!,
      sessionElement: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_element'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      startedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_ms'],
      )!,
      endsAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ends_at_ms'],
      )!,
      weekendStartedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekend_started_at_ms'],
      )!,
      setting: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting'],
      )!,
      serverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_name'],
      )!,
      trackVenue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_venue'],
      )!,
      trackCourse: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_course'],
      )!,
      trackEvent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_event'],
      )!,
      trackLengthMetres: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}track_length_metres'],
      ),
      gameVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}game_version'],
      )!,
      raceLaps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}race_laps'],
      ),
      raceMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}race_minutes'],
      ),
      fuelMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_multiplier'],
      ),
      tyreMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tyre_multiplier'],
      ),
      damagePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}damage_percent'],
      ),
    );
  }

  @override
  $ResultsFilesTable createAlias(String alias) {
    return $ResultsFilesTable(attachedDatabase, alias);
  }
}

class ResultsFileRow extends DataClass implements Insertable<ResultsFileRow> {
  /// What the other tables point at: an integer, so the path is stored once
  /// rather than on each of ~900k lap and event rows and again in each of
  /// their keys, which made the first full index 370 MB.
  final int id;
  final String path;
  final int sizeBytes;
  final int modifiedMs;
  final DateTime indexedAt;
  final String sessionElement;

  /// [ResultsSessionKind.name].
  final String kind;

  /// UTC epoch milliseconds, as integers so the window query is exact.
  final int startedAtMs;
  final int endsAtMs;
  final int weekendStartedAtMs;
  final String setting;
  final String serverName;
  final String trackVenue;
  final String trackCourse;
  final String trackEvent;
  final double? trackLengthMetres;
  final String gameVersion;
  final int? raceLaps;
  final int? raceMinutes;
  final double? fuelMultiplier;
  final double? tyreMultiplier;
  final double? damagePercent;
  const ResultsFileRow({
    required this.id,
    required this.path,
    required this.sizeBytes,
    required this.modifiedMs,
    required this.indexedAt,
    required this.sessionElement,
    required this.kind,
    required this.startedAtMs,
    required this.endsAtMs,
    required this.weekendStartedAtMs,
    required this.setting,
    required this.serverName,
    required this.trackVenue,
    required this.trackCourse,
    required this.trackEvent,
    this.trackLengthMetres,
    required this.gameVersion,
    this.raceLaps,
    this.raceMinutes,
    this.fuelMultiplier,
    this.tyreMultiplier,
    this.damagePercent,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['modified_ms'] = Variable<int>(modifiedMs);
    map['indexed_at'] = Variable<DateTime>(indexedAt);
    map['session_element'] = Variable<String>(sessionElement);
    map['kind'] = Variable<String>(kind);
    map['started_at_ms'] = Variable<int>(startedAtMs);
    map['ends_at_ms'] = Variable<int>(endsAtMs);
    map['weekend_started_at_ms'] = Variable<int>(weekendStartedAtMs);
    map['setting'] = Variable<String>(setting);
    map['server_name'] = Variable<String>(serverName);
    map['track_venue'] = Variable<String>(trackVenue);
    map['track_course'] = Variable<String>(trackCourse);
    map['track_event'] = Variable<String>(trackEvent);
    if (!nullToAbsent || trackLengthMetres != null) {
      map['track_length_metres'] = Variable<double>(trackLengthMetres);
    }
    map['game_version'] = Variable<String>(gameVersion);
    if (!nullToAbsent || raceLaps != null) {
      map['race_laps'] = Variable<int>(raceLaps);
    }
    if (!nullToAbsent || raceMinutes != null) {
      map['race_minutes'] = Variable<int>(raceMinutes);
    }
    if (!nullToAbsent || fuelMultiplier != null) {
      map['fuel_multiplier'] = Variable<double>(fuelMultiplier);
    }
    if (!nullToAbsent || tyreMultiplier != null) {
      map['tyre_multiplier'] = Variable<double>(tyreMultiplier);
    }
    if (!nullToAbsent || damagePercent != null) {
      map['damage_percent'] = Variable<double>(damagePercent);
    }
    return map;
  }

  ResultsFilesCompanion toCompanion(bool nullToAbsent) {
    return ResultsFilesCompanion(
      id: Value(id),
      path: Value(path),
      sizeBytes: Value(sizeBytes),
      modifiedMs: Value(modifiedMs),
      indexedAt: Value(indexedAt),
      sessionElement: Value(sessionElement),
      kind: Value(kind),
      startedAtMs: Value(startedAtMs),
      endsAtMs: Value(endsAtMs),
      weekendStartedAtMs: Value(weekendStartedAtMs),
      setting: Value(setting),
      serverName: Value(serverName),
      trackVenue: Value(trackVenue),
      trackCourse: Value(trackCourse),
      trackEvent: Value(trackEvent),
      trackLengthMetres: trackLengthMetres == null && nullToAbsent
          ? const Value.absent()
          : Value(trackLengthMetres),
      gameVersion: Value(gameVersion),
      raceLaps: raceLaps == null && nullToAbsent
          ? const Value.absent()
          : Value(raceLaps),
      raceMinutes: raceMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(raceMinutes),
      fuelMultiplier: fuelMultiplier == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelMultiplier),
      tyreMultiplier: tyreMultiplier == null && nullToAbsent
          ? const Value.absent()
          : Value(tyreMultiplier),
      damagePercent: damagePercent == null && nullToAbsent
          ? const Value.absent()
          : Value(damagePercent),
    );
  }

  factory ResultsFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResultsFileRow(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      modifiedMs: serializer.fromJson<int>(json['modifiedMs']),
      indexedAt: serializer.fromJson<DateTime>(json['indexedAt']),
      sessionElement: serializer.fromJson<String>(json['sessionElement']),
      kind: serializer.fromJson<String>(json['kind']),
      startedAtMs: serializer.fromJson<int>(json['startedAtMs']),
      endsAtMs: serializer.fromJson<int>(json['endsAtMs']),
      weekendStartedAtMs: serializer.fromJson<int>(json['weekendStartedAtMs']),
      setting: serializer.fromJson<String>(json['setting']),
      serverName: serializer.fromJson<String>(json['serverName']),
      trackVenue: serializer.fromJson<String>(json['trackVenue']),
      trackCourse: serializer.fromJson<String>(json['trackCourse']),
      trackEvent: serializer.fromJson<String>(json['trackEvent']),
      trackLengthMetres: serializer.fromJson<double?>(
        json['trackLengthMetres'],
      ),
      gameVersion: serializer.fromJson<String>(json['gameVersion']),
      raceLaps: serializer.fromJson<int?>(json['raceLaps']),
      raceMinutes: serializer.fromJson<int?>(json['raceMinutes']),
      fuelMultiplier: serializer.fromJson<double?>(json['fuelMultiplier']),
      tyreMultiplier: serializer.fromJson<double?>(json['tyreMultiplier']),
      damagePercent: serializer.fromJson<double?>(json['damagePercent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'modifiedMs': serializer.toJson<int>(modifiedMs),
      'indexedAt': serializer.toJson<DateTime>(indexedAt),
      'sessionElement': serializer.toJson<String>(sessionElement),
      'kind': serializer.toJson<String>(kind),
      'startedAtMs': serializer.toJson<int>(startedAtMs),
      'endsAtMs': serializer.toJson<int>(endsAtMs),
      'weekendStartedAtMs': serializer.toJson<int>(weekendStartedAtMs),
      'setting': serializer.toJson<String>(setting),
      'serverName': serializer.toJson<String>(serverName),
      'trackVenue': serializer.toJson<String>(trackVenue),
      'trackCourse': serializer.toJson<String>(trackCourse),
      'trackEvent': serializer.toJson<String>(trackEvent),
      'trackLengthMetres': serializer.toJson<double?>(trackLengthMetres),
      'gameVersion': serializer.toJson<String>(gameVersion),
      'raceLaps': serializer.toJson<int?>(raceLaps),
      'raceMinutes': serializer.toJson<int?>(raceMinutes),
      'fuelMultiplier': serializer.toJson<double?>(fuelMultiplier),
      'tyreMultiplier': serializer.toJson<double?>(tyreMultiplier),
      'damagePercent': serializer.toJson<double?>(damagePercent),
    };
  }

  ResultsFileRow copyWith({
    int? id,
    String? path,
    int? sizeBytes,
    int? modifiedMs,
    DateTime? indexedAt,
    String? sessionElement,
    String? kind,
    int? startedAtMs,
    int? endsAtMs,
    int? weekendStartedAtMs,
    String? setting,
    String? serverName,
    String? trackVenue,
    String? trackCourse,
    String? trackEvent,
    Value<double?> trackLengthMetres = const Value.absent(),
    String? gameVersion,
    Value<int?> raceLaps = const Value.absent(),
    Value<int?> raceMinutes = const Value.absent(),
    Value<double?> fuelMultiplier = const Value.absent(),
    Value<double?> tyreMultiplier = const Value.absent(),
    Value<double?> damagePercent = const Value.absent(),
  }) => ResultsFileRow(
    id: id ?? this.id,
    path: path ?? this.path,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    modifiedMs: modifiedMs ?? this.modifiedMs,
    indexedAt: indexedAt ?? this.indexedAt,
    sessionElement: sessionElement ?? this.sessionElement,
    kind: kind ?? this.kind,
    startedAtMs: startedAtMs ?? this.startedAtMs,
    endsAtMs: endsAtMs ?? this.endsAtMs,
    weekendStartedAtMs: weekendStartedAtMs ?? this.weekendStartedAtMs,
    setting: setting ?? this.setting,
    serverName: serverName ?? this.serverName,
    trackVenue: trackVenue ?? this.trackVenue,
    trackCourse: trackCourse ?? this.trackCourse,
    trackEvent: trackEvent ?? this.trackEvent,
    trackLengthMetres: trackLengthMetres.present
        ? trackLengthMetres.value
        : this.trackLengthMetres,
    gameVersion: gameVersion ?? this.gameVersion,
    raceLaps: raceLaps.present ? raceLaps.value : this.raceLaps,
    raceMinutes: raceMinutes.present ? raceMinutes.value : this.raceMinutes,
    fuelMultiplier: fuelMultiplier.present
        ? fuelMultiplier.value
        : this.fuelMultiplier,
    tyreMultiplier: tyreMultiplier.present
        ? tyreMultiplier.value
        : this.tyreMultiplier,
    damagePercent: damagePercent.present
        ? damagePercent.value
        : this.damagePercent,
  );
  ResultsFileRow copyWithCompanion(ResultsFilesCompanion data) {
    return ResultsFileRow(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedMs: data.modifiedMs.present
          ? data.modifiedMs.value
          : this.modifiedMs,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
      sessionElement: data.sessionElement.present
          ? data.sessionElement.value
          : this.sessionElement,
      kind: data.kind.present ? data.kind.value : this.kind,
      startedAtMs: data.startedAtMs.present
          ? data.startedAtMs.value
          : this.startedAtMs,
      endsAtMs: data.endsAtMs.present ? data.endsAtMs.value : this.endsAtMs,
      weekendStartedAtMs: data.weekendStartedAtMs.present
          ? data.weekendStartedAtMs.value
          : this.weekendStartedAtMs,
      setting: data.setting.present ? data.setting.value : this.setting,
      serverName: data.serverName.present
          ? data.serverName.value
          : this.serverName,
      trackVenue: data.trackVenue.present
          ? data.trackVenue.value
          : this.trackVenue,
      trackCourse: data.trackCourse.present
          ? data.trackCourse.value
          : this.trackCourse,
      trackEvent: data.trackEvent.present
          ? data.trackEvent.value
          : this.trackEvent,
      trackLengthMetres: data.trackLengthMetres.present
          ? data.trackLengthMetres.value
          : this.trackLengthMetres,
      gameVersion: data.gameVersion.present
          ? data.gameVersion.value
          : this.gameVersion,
      raceLaps: data.raceLaps.present ? data.raceLaps.value : this.raceLaps,
      raceMinutes: data.raceMinutes.present
          ? data.raceMinutes.value
          : this.raceMinutes,
      fuelMultiplier: data.fuelMultiplier.present
          ? data.fuelMultiplier.value
          : this.fuelMultiplier,
      tyreMultiplier: data.tyreMultiplier.present
          ? data.tyreMultiplier.value
          : this.tyreMultiplier,
      damagePercent: data.damagePercent.present
          ? data.damagePercent.value
          : this.damagePercent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResultsFileRow(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('sessionElement: $sessionElement, ')
          ..write('kind: $kind, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endsAtMs: $endsAtMs, ')
          ..write('weekendStartedAtMs: $weekendStartedAtMs, ')
          ..write('setting: $setting, ')
          ..write('serverName: $serverName, ')
          ..write('trackVenue: $trackVenue, ')
          ..write('trackCourse: $trackCourse, ')
          ..write('trackEvent: $trackEvent, ')
          ..write('trackLengthMetres: $trackLengthMetres, ')
          ..write('gameVersion: $gameVersion, ')
          ..write('raceLaps: $raceLaps, ')
          ..write('raceMinutes: $raceMinutes, ')
          ..write('fuelMultiplier: $fuelMultiplier, ')
          ..write('tyreMultiplier: $tyreMultiplier, ')
          ..write('damagePercent: $damagePercent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    path,
    sizeBytes,
    modifiedMs,
    indexedAt,
    sessionElement,
    kind,
    startedAtMs,
    endsAtMs,
    weekendStartedAtMs,
    setting,
    serverName,
    trackVenue,
    trackCourse,
    trackEvent,
    trackLengthMetres,
    gameVersion,
    raceLaps,
    raceMinutes,
    fuelMultiplier,
    tyreMultiplier,
    damagePercent,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResultsFileRow &&
          other.id == this.id &&
          other.path == this.path &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedMs == this.modifiedMs &&
          other.indexedAt == this.indexedAt &&
          other.sessionElement == this.sessionElement &&
          other.kind == this.kind &&
          other.startedAtMs == this.startedAtMs &&
          other.endsAtMs == this.endsAtMs &&
          other.weekendStartedAtMs == this.weekendStartedAtMs &&
          other.setting == this.setting &&
          other.serverName == this.serverName &&
          other.trackVenue == this.trackVenue &&
          other.trackCourse == this.trackCourse &&
          other.trackEvent == this.trackEvent &&
          other.trackLengthMetres == this.trackLengthMetres &&
          other.gameVersion == this.gameVersion &&
          other.raceLaps == this.raceLaps &&
          other.raceMinutes == this.raceMinutes &&
          other.fuelMultiplier == this.fuelMultiplier &&
          other.tyreMultiplier == this.tyreMultiplier &&
          other.damagePercent == this.damagePercent);
}

class ResultsFilesCompanion extends UpdateCompanion<ResultsFileRow> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> sizeBytes;
  final Value<int> modifiedMs;
  final Value<DateTime> indexedAt;
  final Value<String> sessionElement;
  final Value<String> kind;
  final Value<int> startedAtMs;
  final Value<int> endsAtMs;
  final Value<int> weekendStartedAtMs;
  final Value<String> setting;
  final Value<String> serverName;
  final Value<String> trackVenue;
  final Value<String> trackCourse;
  final Value<String> trackEvent;
  final Value<double?> trackLengthMetres;
  final Value<String> gameVersion;
  final Value<int?> raceLaps;
  final Value<int?> raceMinutes;
  final Value<double?> fuelMultiplier;
  final Value<double?> tyreMultiplier;
  final Value<double?> damagePercent;
  const ResultsFilesCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedMs = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.sessionElement = const Value.absent(),
    this.kind = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.endsAtMs = const Value.absent(),
    this.weekendStartedAtMs = const Value.absent(),
    this.setting = const Value.absent(),
    this.serverName = const Value.absent(),
    this.trackVenue = const Value.absent(),
    this.trackCourse = const Value.absent(),
    this.trackEvent = const Value.absent(),
    this.trackLengthMetres = const Value.absent(),
    this.gameVersion = const Value.absent(),
    this.raceLaps = const Value.absent(),
    this.raceMinutes = const Value.absent(),
    this.fuelMultiplier = const Value.absent(),
    this.tyreMultiplier = const Value.absent(),
    this.damagePercent = const Value.absent(),
  });
  ResultsFilesCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int sizeBytes,
    required int modifiedMs,
    required DateTime indexedAt,
    required String sessionElement,
    required String kind,
    required int startedAtMs,
    required int endsAtMs,
    required int weekendStartedAtMs,
    required String setting,
    required String serverName,
    required String trackVenue,
    required String trackCourse,
    required String trackEvent,
    this.trackLengthMetres = const Value.absent(),
    required String gameVersion,
    this.raceLaps = const Value.absent(),
    this.raceMinutes = const Value.absent(),
    this.fuelMultiplier = const Value.absent(),
    this.tyreMultiplier = const Value.absent(),
    this.damagePercent = const Value.absent(),
  }) : path = Value(path),
       sizeBytes = Value(sizeBytes),
       modifiedMs = Value(modifiedMs),
       indexedAt = Value(indexedAt),
       sessionElement = Value(sessionElement),
       kind = Value(kind),
       startedAtMs = Value(startedAtMs),
       endsAtMs = Value(endsAtMs),
       weekendStartedAtMs = Value(weekendStartedAtMs),
       setting = Value(setting),
       serverName = Value(serverName),
       trackVenue = Value(trackVenue),
       trackCourse = Value(trackCourse),
       trackEvent = Value(trackEvent),
       gameVersion = Value(gameVersion);
  static Insertable<ResultsFileRow> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedMs,
    Expression<DateTime>? indexedAt,
    Expression<String>? sessionElement,
    Expression<String>? kind,
    Expression<int>? startedAtMs,
    Expression<int>? endsAtMs,
    Expression<int>? weekendStartedAtMs,
    Expression<String>? setting,
    Expression<String>? serverName,
    Expression<String>? trackVenue,
    Expression<String>? trackCourse,
    Expression<String>? trackEvent,
    Expression<double>? trackLengthMetres,
    Expression<String>? gameVersion,
    Expression<int>? raceLaps,
    Expression<int>? raceMinutes,
    Expression<double>? fuelMultiplier,
    Expression<double>? tyreMultiplier,
    Expression<double>? damagePercent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedMs != null) 'modified_ms': modifiedMs,
      if (indexedAt != null) 'indexed_at': indexedAt,
      if (sessionElement != null) 'session_element': sessionElement,
      if (kind != null) 'kind': kind,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (endsAtMs != null) 'ends_at_ms': endsAtMs,
      if (weekendStartedAtMs != null)
        'weekend_started_at_ms': weekendStartedAtMs,
      if (setting != null) 'setting': setting,
      if (serverName != null) 'server_name': serverName,
      if (trackVenue != null) 'track_venue': trackVenue,
      if (trackCourse != null) 'track_course': trackCourse,
      if (trackEvent != null) 'track_event': trackEvent,
      if (trackLengthMetres != null) 'track_length_metres': trackLengthMetres,
      if (gameVersion != null) 'game_version': gameVersion,
      if (raceLaps != null) 'race_laps': raceLaps,
      if (raceMinutes != null) 'race_minutes': raceMinutes,
      if (fuelMultiplier != null) 'fuel_multiplier': fuelMultiplier,
      if (tyreMultiplier != null) 'tyre_multiplier': tyreMultiplier,
      if (damagePercent != null) 'damage_percent': damagePercent,
    });
  }

  ResultsFilesCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? sizeBytes,
    Value<int>? modifiedMs,
    Value<DateTime>? indexedAt,
    Value<String>? sessionElement,
    Value<String>? kind,
    Value<int>? startedAtMs,
    Value<int>? endsAtMs,
    Value<int>? weekendStartedAtMs,
    Value<String>? setting,
    Value<String>? serverName,
    Value<String>? trackVenue,
    Value<String>? trackCourse,
    Value<String>? trackEvent,
    Value<double?>? trackLengthMetres,
    Value<String>? gameVersion,
    Value<int?>? raceLaps,
    Value<int?>? raceMinutes,
    Value<double?>? fuelMultiplier,
    Value<double?>? tyreMultiplier,
    Value<double?>? damagePercent,
  }) {
    return ResultsFilesCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedMs: modifiedMs ?? this.modifiedMs,
      indexedAt: indexedAt ?? this.indexedAt,
      sessionElement: sessionElement ?? this.sessionElement,
      kind: kind ?? this.kind,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      endsAtMs: endsAtMs ?? this.endsAtMs,
      weekendStartedAtMs: weekendStartedAtMs ?? this.weekendStartedAtMs,
      setting: setting ?? this.setting,
      serverName: serverName ?? this.serverName,
      trackVenue: trackVenue ?? this.trackVenue,
      trackCourse: trackCourse ?? this.trackCourse,
      trackEvent: trackEvent ?? this.trackEvent,
      trackLengthMetres: trackLengthMetres ?? this.trackLengthMetres,
      gameVersion: gameVersion ?? this.gameVersion,
      raceLaps: raceLaps ?? this.raceLaps,
      raceMinutes: raceMinutes ?? this.raceMinutes,
      fuelMultiplier: fuelMultiplier ?? this.fuelMultiplier,
      tyreMultiplier: tyreMultiplier ?? this.tyreMultiplier,
      damagePercent: damagePercent ?? this.damagePercent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedMs.present) {
      map['modified_ms'] = Variable<int>(modifiedMs.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<DateTime>(indexedAt.value);
    }
    if (sessionElement.present) {
      map['session_element'] = Variable<String>(sessionElement.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (endsAtMs.present) {
      map['ends_at_ms'] = Variable<int>(endsAtMs.value);
    }
    if (weekendStartedAtMs.present) {
      map['weekend_started_at_ms'] = Variable<int>(weekendStartedAtMs.value);
    }
    if (setting.present) {
      map['setting'] = Variable<String>(setting.value);
    }
    if (serverName.present) {
      map['server_name'] = Variable<String>(serverName.value);
    }
    if (trackVenue.present) {
      map['track_venue'] = Variable<String>(trackVenue.value);
    }
    if (trackCourse.present) {
      map['track_course'] = Variable<String>(trackCourse.value);
    }
    if (trackEvent.present) {
      map['track_event'] = Variable<String>(trackEvent.value);
    }
    if (trackLengthMetres.present) {
      map['track_length_metres'] = Variable<double>(trackLengthMetres.value);
    }
    if (gameVersion.present) {
      map['game_version'] = Variable<String>(gameVersion.value);
    }
    if (raceLaps.present) {
      map['race_laps'] = Variable<int>(raceLaps.value);
    }
    if (raceMinutes.present) {
      map['race_minutes'] = Variable<int>(raceMinutes.value);
    }
    if (fuelMultiplier.present) {
      map['fuel_multiplier'] = Variable<double>(fuelMultiplier.value);
    }
    if (tyreMultiplier.present) {
      map['tyre_multiplier'] = Variable<double>(tyreMultiplier.value);
    }
    if (damagePercent.present) {
      map['damage_percent'] = Variable<double>(damagePercent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsFilesCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('sessionElement: $sessionElement, ')
          ..write('kind: $kind, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('endsAtMs: $endsAtMs, ')
          ..write('weekendStartedAtMs: $weekendStartedAtMs, ')
          ..write('setting: $setting, ')
          ..write('serverName: $serverName, ')
          ..write('trackVenue: $trackVenue, ')
          ..write('trackCourse: $trackCourse, ')
          ..write('trackEvent: $trackEvent, ')
          ..write('trackLengthMetres: $trackLengthMetres, ')
          ..write('gameVersion: $gameVersion, ')
          ..write('raceLaps: $raceLaps, ')
          ..write('raceMinutes: $raceMinutes, ')
          ..write('fuelMultiplier: $fuelMultiplier, ')
          ..write('tyreMultiplier: $tyreMultiplier, ')
          ..write('damagePercent: $damagePercent')
          ..write(')'))
        .toString();
  }
}

class $ResultsDriversTable extends ResultsDrivers
    with TableInfo<$ResultsDriversTable, ResultsDriverRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsDriversTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverIndexMeta = const VerificationMeta(
    'driverIndex',
  );
  @override
  late final GeneratedColumn<int> driverIndex = GeneratedColumn<int>(
    'driver_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPlayerMeta = const VerificationMeta(
    'isPlayer',
  );
  @override
  late final GeneratedColumn<bool> isPlayer = GeneratedColumn<bool>(
    'is_player',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_player" IN (0, 1))',
    ),
  );
  static const VerificationMeta _vehicleFileMeta = const VerificationMeta(
    'vehicleFile',
  );
  @override
  late final GeneratedColumn<String> vehicleFile = GeneratedColumn<String>(
    'vehicle_file',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vehicleNameMeta = const VerificationMeta(
    'vehicleName',
  );
  @override
  late final GeneratedColumn<String> vehicleName = GeneratedColumn<String>(
    'vehicle_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carTypeMeta = const VerificationMeta(
    'carType',
  );
  @override
  late final GeneratedColumn<String> carType = GeneratedColumn<String>(
    'car_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carClassMeta = const VerificationMeta(
    'carClass',
  );
  @override
  late final GeneratedColumn<String> carClass = GeneratedColumn<String>(
    'car_class',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamNameMeta = const VerificationMeta(
    'teamName',
  );
  @override
  late final GeneratedColumn<String> teamName = GeneratedColumn<String>(
    'team_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carNumberMeta = const VerificationMeta(
    'carNumber',
  );
  @override
  late final GeneratedColumn<String> carNumber = GeneratedColumn<String>(
    'car_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gridPositionMeta = const VerificationMeta(
    'gridPosition',
  );
  @override
  late final GeneratedColumn<int> gridPosition = GeneratedColumn<int>(
    'grid_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classGridPositionMeta = const VerificationMeta(
    'classGridPosition',
  );
  @override
  late final GeneratedColumn<int> classGridPosition = GeneratedColumn<int>(
    'class_grid_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classPositionMeta = const VerificationMeta(
    'classPosition',
  );
  @override
  late final GeneratedColumn<int> classPosition = GeneratedColumn<int>(
    'class_position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bestLapSecondsMeta = const VerificationMeta(
    'bestLapSeconds',
  );
  @override
  late final GeneratedColumn<double> bestLapSeconds = GeneratedColumn<double>(
    'best_lap_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishElapsedMeta = const VerificationMeta(
    'finishElapsed',
  );
  @override
  late final GeneratedColumn<double> finishElapsed = GeneratedColumn<double>(
    'finish_elapsed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapsCompletedMeta = const VerificationMeta(
    'lapsCompleted',
  );
  @override
  late final GeneratedColumn<int> lapsCompleted = GeneratedColumn<int>(
    'laps_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pitStopsMeta = const VerificationMeta(
    'pitStops',
  );
  @override
  late final GeneratedColumn<int> pitStops = GeneratedColumn<int>(
    'pit_stops',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finishStatusMeta = const VerificationMeta(
    'finishStatus',
  );
  @override
  late final GeneratedColumn<String> finishStatus = GeneratedColumn<String>(
    'finish_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dnfReasonMeta = const VerificationMeta(
    'dnfReason',
  );
  @override
  late final GeneratedColumn<String> dnfReason = GeneratedColumn<String>(
    'dnf_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _swapsMeta = const VerificationMeta('swaps');
  @override
  late final GeneratedColumn<String> swaps = GeneratedColumn<String>(
    'swaps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aidsMeta = const VerificationMeta('aids');
  @override
  late final GeneratedColumn<String> aids = GeneratedColumn<String>(
    'aids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    driverIndex,
    name,
    isPlayer,
    vehicleFile,
    vehicleName,
    carType,
    carClass,
    category,
    teamName,
    carNumber,
    gridPosition,
    classGridPosition,
    position,
    classPosition,
    bestLapSeconds,
    finishElapsed,
    lapsCompleted,
    pitStops,
    finishStatus,
    dnfReason,
    swaps,
    aids,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results_drivers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResultsDriverRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('driver_index')) {
      context.handle(
        _driverIndexMeta,
        driverIndex.isAcceptableOrUnknown(
          data['driver_index']!,
          _driverIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driverIndexMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_player')) {
      context.handle(
        _isPlayerMeta,
        isPlayer.isAcceptableOrUnknown(data['is_player']!, _isPlayerMeta),
      );
    } else if (isInserting) {
      context.missing(_isPlayerMeta);
    }
    if (data.containsKey('vehicle_file')) {
      context.handle(
        _vehicleFileMeta,
        vehicleFile.isAcceptableOrUnknown(
          data['vehicle_file']!,
          _vehicleFileMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vehicleFileMeta);
    }
    if (data.containsKey('vehicle_name')) {
      context.handle(
        _vehicleNameMeta,
        vehicleName.isAcceptableOrUnknown(
          data['vehicle_name']!,
          _vehicleNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vehicleNameMeta);
    }
    if (data.containsKey('car_type')) {
      context.handle(
        _carTypeMeta,
        carType.isAcceptableOrUnknown(data['car_type']!, _carTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_carTypeMeta);
    }
    if (data.containsKey('car_class')) {
      context.handle(
        _carClassMeta,
        carClass.isAcceptableOrUnknown(data['car_class']!, _carClassMeta),
      );
    } else if (isInserting) {
      context.missing(_carClassMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('team_name')) {
      context.handle(
        _teamNameMeta,
        teamName.isAcceptableOrUnknown(data['team_name']!, _teamNameMeta),
      );
    } else if (isInserting) {
      context.missing(_teamNameMeta);
    }
    if (data.containsKey('car_number')) {
      context.handle(
        _carNumberMeta,
        carNumber.isAcceptableOrUnknown(data['car_number']!, _carNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_carNumberMeta);
    }
    if (data.containsKey('grid_position')) {
      context.handle(
        _gridPositionMeta,
        gridPosition.isAcceptableOrUnknown(
          data['grid_position']!,
          _gridPositionMeta,
        ),
      );
    }
    if (data.containsKey('class_grid_position')) {
      context.handle(
        _classGridPositionMeta,
        classGridPosition.isAcceptableOrUnknown(
          data['class_grid_position']!,
          _classGridPositionMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('class_position')) {
      context.handle(
        _classPositionMeta,
        classPosition.isAcceptableOrUnknown(
          data['class_position']!,
          _classPositionMeta,
        ),
      );
    }
    if (data.containsKey('best_lap_seconds')) {
      context.handle(
        _bestLapSecondsMeta,
        bestLapSeconds.isAcceptableOrUnknown(
          data['best_lap_seconds']!,
          _bestLapSecondsMeta,
        ),
      );
    }
    if (data.containsKey('finish_elapsed')) {
      context.handle(
        _finishElapsedMeta,
        finishElapsed.isAcceptableOrUnknown(
          data['finish_elapsed']!,
          _finishElapsedMeta,
        ),
      );
    }
    if (data.containsKey('laps_completed')) {
      context.handle(
        _lapsCompletedMeta,
        lapsCompleted.isAcceptableOrUnknown(
          data['laps_completed']!,
          _lapsCompletedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lapsCompletedMeta);
    }
    if (data.containsKey('pit_stops')) {
      context.handle(
        _pitStopsMeta,
        pitStops.isAcceptableOrUnknown(data['pit_stops']!, _pitStopsMeta),
      );
    } else if (isInserting) {
      context.missing(_pitStopsMeta);
    }
    if (data.containsKey('finish_status')) {
      context.handle(
        _finishStatusMeta,
        finishStatus.isAcceptableOrUnknown(
          data['finish_status']!,
          _finishStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finishStatusMeta);
    }
    if (data.containsKey('dnf_reason')) {
      context.handle(
        _dnfReasonMeta,
        dnfReason.isAcceptableOrUnknown(data['dnf_reason']!, _dnfReasonMeta),
      );
    }
    if (data.containsKey('swaps')) {
      context.handle(
        _swapsMeta,
        swaps.isAcceptableOrUnknown(data['swaps']!, _swapsMeta),
      );
    } else if (isInserting) {
      context.missing(_swapsMeta);
    }
    if (data.containsKey('aids')) {
      context.handle(
        _aidsMeta,
        aids.isAcceptableOrUnknown(data['aids']!, _aidsMeta),
      );
    } else if (isInserting) {
      context.missing(_aidsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId, driverIndex};
  @override
  ResultsDriverRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResultsDriverRow(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      )!,
      driverIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}driver_index'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isPlayer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_player'],
      )!,
      vehicleFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_file'],
      )!,
      vehicleName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehicle_name'],
      )!,
      carType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_type'],
      )!,
      carClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_class'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      teamName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_name'],
      )!,
      carNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_number'],
      )!,
      gridPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grid_position'],
      ),
      classGridPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}class_grid_position'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
      classPosition: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}class_position'],
      ),
      bestLapSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}best_lap_seconds'],
      ),
      finishElapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}finish_elapsed'],
      ),
      lapsCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}laps_completed'],
      )!,
      pitStops: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pit_stops'],
      )!,
      finishStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}finish_status'],
      )!,
      dnfReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dnf_reason'],
      ),
      swaps: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}swaps'],
      )!,
      aids: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aids'],
      )!,
    );
  }

  @override
  $ResultsDriversTable createAlias(String alias) {
    return $ResultsDriversTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ResultsDriverRow extends DataClass
    implements Insertable<ResultsDriverRow> {
  /// [ResultsFiles.id].
  final int fileId;
  final int driverIndex;
  final String name;
  final bool isPlayer;
  final String vehicleFile;
  final String vehicleName;
  final String carType;
  final String carClass;
  final String category;
  final String teamName;
  final String carNumber;
  final int? gridPosition;
  final int? classGridPosition;
  final int? position;
  final int? classPosition;
  final double? bestLapSeconds;
  final double? finishElapsed;
  final int lapsCompleted;
  final int pitStops;
  final String finishStatus;
  final String? dnfReason;

  /// `<Swap>` and `<ControlAndAids>` ranges, one per line as
  /// `start<TAB>end<TAB>value` ([encodeStints]).
  final String swaps;
  final String aids;
  const ResultsDriverRow({
    required this.fileId,
    required this.driverIndex,
    required this.name,
    required this.isPlayer,
    required this.vehicleFile,
    required this.vehicleName,
    required this.carType,
    required this.carClass,
    required this.category,
    required this.teamName,
    required this.carNumber,
    this.gridPosition,
    this.classGridPosition,
    this.position,
    this.classPosition,
    this.bestLapSeconds,
    this.finishElapsed,
    required this.lapsCompleted,
    required this.pitStops,
    required this.finishStatus,
    this.dnfReason,
    required this.swaps,
    required this.aids,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<int>(fileId);
    map['driver_index'] = Variable<int>(driverIndex);
    map['name'] = Variable<String>(name);
    map['is_player'] = Variable<bool>(isPlayer);
    map['vehicle_file'] = Variable<String>(vehicleFile);
    map['vehicle_name'] = Variable<String>(vehicleName);
    map['car_type'] = Variable<String>(carType);
    map['car_class'] = Variable<String>(carClass);
    map['category'] = Variable<String>(category);
    map['team_name'] = Variable<String>(teamName);
    map['car_number'] = Variable<String>(carNumber);
    if (!nullToAbsent || gridPosition != null) {
      map['grid_position'] = Variable<int>(gridPosition);
    }
    if (!nullToAbsent || classGridPosition != null) {
      map['class_grid_position'] = Variable<int>(classGridPosition);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    if (!nullToAbsent || classPosition != null) {
      map['class_position'] = Variable<int>(classPosition);
    }
    if (!nullToAbsent || bestLapSeconds != null) {
      map['best_lap_seconds'] = Variable<double>(bestLapSeconds);
    }
    if (!nullToAbsent || finishElapsed != null) {
      map['finish_elapsed'] = Variable<double>(finishElapsed);
    }
    map['laps_completed'] = Variable<int>(lapsCompleted);
    map['pit_stops'] = Variable<int>(pitStops);
    map['finish_status'] = Variable<String>(finishStatus);
    if (!nullToAbsent || dnfReason != null) {
      map['dnf_reason'] = Variable<String>(dnfReason);
    }
    map['swaps'] = Variable<String>(swaps);
    map['aids'] = Variable<String>(aids);
    return map;
  }

  ResultsDriversCompanion toCompanion(bool nullToAbsent) {
    return ResultsDriversCompanion(
      fileId: Value(fileId),
      driverIndex: Value(driverIndex),
      name: Value(name),
      isPlayer: Value(isPlayer),
      vehicleFile: Value(vehicleFile),
      vehicleName: Value(vehicleName),
      carType: Value(carType),
      carClass: Value(carClass),
      category: Value(category),
      teamName: Value(teamName),
      carNumber: Value(carNumber),
      gridPosition: gridPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(gridPosition),
      classGridPosition: classGridPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(classGridPosition),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      classPosition: classPosition == null && nullToAbsent
          ? const Value.absent()
          : Value(classPosition),
      bestLapSeconds: bestLapSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(bestLapSeconds),
      finishElapsed: finishElapsed == null && nullToAbsent
          ? const Value.absent()
          : Value(finishElapsed),
      lapsCompleted: Value(lapsCompleted),
      pitStops: Value(pitStops),
      finishStatus: Value(finishStatus),
      dnfReason: dnfReason == null && nullToAbsent
          ? const Value.absent()
          : Value(dnfReason),
      swaps: Value(swaps),
      aids: Value(aids),
    );
  }

  factory ResultsDriverRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResultsDriverRow(
      fileId: serializer.fromJson<int>(json['fileId']),
      driverIndex: serializer.fromJson<int>(json['driverIndex']),
      name: serializer.fromJson<String>(json['name']),
      isPlayer: serializer.fromJson<bool>(json['isPlayer']),
      vehicleFile: serializer.fromJson<String>(json['vehicleFile']),
      vehicleName: serializer.fromJson<String>(json['vehicleName']),
      carType: serializer.fromJson<String>(json['carType']),
      carClass: serializer.fromJson<String>(json['carClass']),
      category: serializer.fromJson<String>(json['category']),
      teamName: serializer.fromJson<String>(json['teamName']),
      carNumber: serializer.fromJson<String>(json['carNumber']),
      gridPosition: serializer.fromJson<int?>(json['gridPosition']),
      classGridPosition: serializer.fromJson<int?>(json['classGridPosition']),
      position: serializer.fromJson<int?>(json['position']),
      classPosition: serializer.fromJson<int?>(json['classPosition']),
      bestLapSeconds: serializer.fromJson<double?>(json['bestLapSeconds']),
      finishElapsed: serializer.fromJson<double?>(json['finishElapsed']),
      lapsCompleted: serializer.fromJson<int>(json['lapsCompleted']),
      pitStops: serializer.fromJson<int>(json['pitStops']),
      finishStatus: serializer.fromJson<String>(json['finishStatus']),
      dnfReason: serializer.fromJson<String?>(json['dnfReason']),
      swaps: serializer.fromJson<String>(json['swaps']),
      aids: serializer.fromJson<String>(json['aids']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<int>(fileId),
      'driverIndex': serializer.toJson<int>(driverIndex),
      'name': serializer.toJson<String>(name),
      'isPlayer': serializer.toJson<bool>(isPlayer),
      'vehicleFile': serializer.toJson<String>(vehicleFile),
      'vehicleName': serializer.toJson<String>(vehicleName),
      'carType': serializer.toJson<String>(carType),
      'carClass': serializer.toJson<String>(carClass),
      'category': serializer.toJson<String>(category),
      'teamName': serializer.toJson<String>(teamName),
      'carNumber': serializer.toJson<String>(carNumber),
      'gridPosition': serializer.toJson<int?>(gridPosition),
      'classGridPosition': serializer.toJson<int?>(classGridPosition),
      'position': serializer.toJson<int?>(position),
      'classPosition': serializer.toJson<int?>(classPosition),
      'bestLapSeconds': serializer.toJson<double?>(bestLapSeconds),
      'finishElapsed': serializer.toJson<double?>(finishElapsed),
      'lapsCompleted': serializer.toJson<int>(lapsCompleted),
      'pitStops': serializer.toJson<int>(pitStops),
      'finishStatus': serializer.toJson<String>(finishStatus),
      'dnfReason': serializer.toJson<String?>(dnfReason),
      'swaps': serializer.toJson<String>(swaps),
      'aids': serializer.toJson<String>(aids),
    };
  }

  ResultsDriverRow copyWith({
    int? fileId,
    int? driverIndex,
    String? name,
    bool? isPlayer,
    String? vehicleFile,
    String? vehicleName,
    String? carType,
    String? carClass,
    String? category,
    String? teamName,
    String? carNumber,
    Value<int?> gridPosition = const Value.absent(),
    Value<int?> classGridPosition = const Value.absent(),
    Value<int?> position = const Value.absent(),
    Value<int?> classPosition = const Value.absent(),
    Value<double?> bestLapSeconds = const Value.absent(),
    Value<double?> finishElapsed = const Value.absent(),
    int? lapsCompleted,
    int? pitStops,
    String? finishStatus,
    Value<String?> dnfReason = const Value.absent(),
    String? swaps,
    String? aids,
  }) => ResultsDriverRow(
    fileId: fileId ?? this.fileId,
    driverIndex: driverIndex ?? this.driverIndex,
    name: name ?? this.name,
    isPlayer: isPlayer ?? this.isPlayer,
    vehicleFile: vehicleFile ?? this.vehicleFile,
    vehicleName: vehicleName ?? this.vehicleName,
    carType: carType ?? this.carType,
    carClass: carClass ?? this.carClass,
    category: category ?? this.category,
    teamName: teamName ?? this.teamName,
    carNumber: carNumber ?? this.carNumber,
    gridPosition: gridPosition.present ? gridPosition.value : this.gridPosition,
    classGridPosition: classGridPosition.present
        ? classGridPosition.value
        : this.classGridPosition,
    position: position.present ? position.value : this.position,
    classPosition: classPosition.present
        ? classPosition.value
        : this.classPosition,
    bestLapSeconds: bestLapSeconds.present
        ? bestLapSeconds.value
        : this.bestLapSeconds,
    finishElapsed: finishElapsed.present
        ? finishElapsed.value
        : this.finishElapsed,
    lapsCompleted: lapsCompleted ?? this.lapsCompleted,
    pitStops: pitStops ?? this.pitStops,
    finishStatus: finishStatus ?? this.finishStatus,
    dnfReason: dnfReason.present ? dnfReason.value : this.dnfReason,
    swaps: swaps ?? this.swaps,
    aids: aids ?? this.aids,
  );
  ResultsDriverRow copyWithCompanion(ResultsDriversCompanion data) {
    return ResultsDriverRow(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      driverIndex: data.driverIndex.present
          ? data.driverIndex.value
          : this.driverIndex,
      name: data.name.present ? data.name.value : this.name,
      isPlayer: data.isPlayer.present ? data.isPlayer.value : this.isPlayer,
      vehicleFile: data.vehicleFile.present
          ? data.vehicleFile.value
          : this.vehicleFile,
      vehicleName: data.vehicleName.present
          ? data.vehicleName.value
          : this.vehicleName,
      carType: data.carType.present ? data.carType.value : this.carType,
      carClass: data.carClass.present ? data.carClass.value : this.carClass,
      category: data.category.present ? data.category.value : this.category,
      teamName: data.teamName.present ? data.teamName.value : this.teamName,
      carNumber: data.carNumber.present ? data.carNumber.value : this.carNumber,
      gridPosition: data.gridPosition.present
          ? data.gridPosition.value
          : this.gridPosition,
      classGridPosition: data.classGridPosition.present
          ? data.classGridPosition.value
          : this.classGridPosition,
      position: data.position.present ? data.position.value : this.position,
      classPosition: data.classPosition.present
          ? data.classPosition.value
          : this.classPosition,
      bestLapSeconds: data.bestLapSeconds.present
          ? data.bestLapSeconds.value
          : this.bestLapSeconds,
      finishElapsed: data.finishElapsed.present
          ? data.finishElapsed.value
          : this.finishElapsed,
      lapsCompleted: data.lapsCompleted.present
          ? data.lapsCompleted.value
          : this.lapsCompleted,
      pitStops: data.pitStops.present ? data.pitStops.value : this.pitStops,
      finishStatus: data.finishStatus.present
          ? data.finishStatus.value
          : this.finishStatus,
      dnfReason: data.dnfReason.present ? data.dnfReason.value : this.dnfReason,
      swaps: data.swaps.present ? data.swaps.value : this.swaps,
      aids: data.aids.present ? data.aids.value : this.aids,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResultsDriverRow(')
          ..write('fileId: $fileId, ')
          ..write('driverIndex: $driverIndex, ')
          ..write('name: $name, ')
          ..write('isPlayer: $isPlayer, ')
          ..write('vehicleFile: $vehicleFile, ')
          ..write('vehicleName: $vehicleName, ')
          ..write('carType: $carType, ')
          ..write('carClass: $carClass, ')
          ..write('category: $category, ')
          ..write('teamName: $teamName, ')
          ..write('carNumber: $carNumber, ')
          ..write('gridPosition: $gridPosition, ')
          ..write('classGridPosition: $classGridPosition, ')
          ..write('position: $position, ')
          ..write('classPosition: $classPosition, ')
          ..write('bestLapSeconds: $bestLapSeconds, ')
          ..write('finishElapsed: $finishElapsed, ')
          ..write('lapsCompleted: $lapsCompleted, ')
          ..write('pitStops: $pitStops, ')
          ..write('finishStatus: $finishStatus, ')
          ..write('dnfReason: $dnfReason, ')
          ..write('swaps: $swaps, ')
          ..write('aids: $aids')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    fileId,
    driverIndex,
    name,
    isPlayer,
    vehicleFile,
    vehicleName,
    carType,
    carClass,
    category,
    teamName,
    carNumber,
    gridPosition,
    classGridPosition,
    position,
    classPosition,
    bestLapSeconds,
    finishElapsed,
    lapsCompleted,
    pitStops,
    finishStatus,
    dnfReason,
    swaps,
    aids,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResultsDriverRow &&
          other.fileId == this.fileId &&
          other.driverIndex == this.driverIndex &&
          other.name == this.name &&
          other.isPlayer == this.isPlayer &&
          other.vehicleFile == this.vehicleFile &&
          other.vehicleName == this.vehicleName &&
          other.carType == this.carType &&
          other.carClass == this.carClass &&
          other.category == this.category &&
          other.teamName == this.teamName &&
          other.carNumber == this.carNumber &&
          other.gridPosition == this.gridPosition &&
          other.classGridPosition == this.classGridPosition &&
          other.position == this.position &&
          other.classPosition == this.classPosition &&
          other.bestLapSeconds == this.bestLapSeconds &&
          other.finishElapsed == this.finishElapsed &&
          other.lapsCompleted == this.lapsCompleted &&
          other.pitStops == this.pitStops &&
          other.finishStatus == this.finishStatus &&
          other.dnfReason == this.dnfReason &&
          other.swaps == this.swaps &&
          other.aids == this.aids);
}

class ResultsDriversCompanion extends UpdateCompanion<ResultsDriverRow> {
  final Value<int> fileId;
  final Value<int> driverIndex;
  final Value<String> name;
  final Value<bool> isPlayer;
  final Value<String> vehicleFile;
  final Value<String> vehicleName;
  final Value<String> carType;
  final Value<String> carClass;
  final Value<String> category;
  final Value<String> teamName;
  final Value<String> carNumber;
  final Value<int?> gridPosition;
  final Value<int?> classGridPosition;
  final Value<int?> position;
  final Value<int?> classPosition;
  final Value<double?> bestLapSeconds;
  final Value<double?> finishElapsed;
  final Value<int> lapsCompleted;
  final Value<int> pitStops;
  final Value<String> finishStatus;
  final Value<String?> dnfReason;
  final Value<String> swaps;
  final Value<String> aids;
  const ResultsDriversCompanion({
    this.fileId = const Value.absent(),
    this.driverIndex = const Value.absent(),
    this.name = const Value.absent(),
    this.isPlayer = const Value.absent(),
    this.vehicleFile = const Value.absent(),
    this.vehicleName = const Value.absent(),
    this.carType = const Value.absent(),
    this.carClass = const Value.absent(),
    this.category = const Value.absent(),
    this.teamName = const Value.absent(),
    this.carNumber = const Value.absent(),
    this.gridPosition = const Value.absent(),
    this.classGridPosition = const Value.absent(),
    this.position = const Value.absent(),
    this.classPosition = const Value.absent(),
    this.bestLapSeconds = const Value.absent(),
    this.finishElapsed = const Value.absent(),
    this.lapsCompleted = const Value.absent(),
    this.pitStops = const Value.absent(),
    this.finishStatus = const Value.absent(),
    this.dnfReason = const Value.absent(),
    this.swaps = const Value.absent(),
    this.aids = const Value.absent(),
  });
  ResultsDriversCompanion.insert({
    required int fileId,
    required int driverIndex,
    required String name,
    required bool isPlayer,
    required String vehicleFile,
    required String vehicleName,
    required String carType,
    required String carClass,
    required String category,
    required String teamName,
    required String carNumber,
    this.gridPosition = const Value.absent(),
    this.classGridPosition = const Value.absent(),
    this.position = const Value.absent(),
    this.classPosition = const Value.absent(),
    this.bestLapSeconds = const Value.absent(),
    this.finishElapsed = const Value.absent(),
    required int lapsCompleted,
    required int pitStops,
    required String finishStatus,
    this.dnfReason = const Value.absent(),
    required String swaps,
    required String aids,
  }) : fileId = Value(fileId),
       driverIndex = Value(driverIndex),
       name = Value(name),
       isPlayer = Value(isPlayer),
       vehicleFile = Value(vehicleFile),
       vehicleName = Value(vehicleName),
       carType = Value(carType),
       carClass = Value(carClass),
       category = Value(category),
       teamName = Value(teamName),
       carNumber = Value(carNumber),
       lapsCompleted = Value(lapsCompleted),
       pitStops = Value(pitStops),
       finishStatus = Value(finishStatus),
       swaps = Value(swaps),
       aids = Value(aids);
  static Insertable<ResultsDriverRow> custom({
    Expression<int>? fileId,
    Expression<int>? driverIndex,
    Expression<String>? name,
    Expression<bool>? isPlayer,
    Expression<String>? vehicleFile,
    Expression<String>? vehicleName,
    Expression<String>? carType,
    Expression<String>? carClass,
    Expression<String>? category,
    Expression<String>? teamName,
    Expression<String>? carNumber,
    Expression<int>? gridPosition,
    Expression<int>? classGridPosition,
    Expression<int>? position,
    Expression<int>? classPosition,
    Expression<double>? bestLapSeconds,
    Expression<double>? finishElapsed,
    Expression<int>? lapsCompleted,
    Expression<int>? pitStops,
    Expression<String>? finishStatus,
    Expression<String>? dnfReason,
    Expression<String>? swaps,
    Expression<String>? aids,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (driverIndex != null) 'driver_index': driverIndex,
      if (name != null) 'name': name,
      if (isPlayer != null) 'is_player': isPlayer,
      if (vehicleFile != null) 'vehicle_file': vehicleFile,
      if (vehicleName != null) 'vehicle_name': vehicleName,
      if (carType != null) 'car_type': carType,
      if (carClass != null) 'car_class': carClass,
      if (category != null) 'category': category,
      if (teamName != null) 'team_name': teamName,
      if (carNumber != null) 'car_number': carNumber,
      if (gridPosition != null) 'grid_position': gridPosition,
      if (classGridPosition != null) 'class_grid_position': classGridPosition,
      if (position != null) 'position': position,
      if (classPosition != null) 'class_position': classPosition,
      if (bestLapSeconds != null) 'best_lap_seconds': bestLapSeconds,
      if (finishElapsed != null) 'finish_elapsed': finishElapsed,
      if (lapsCompleted != null) 'laps_completed': lapsCompleted,
      if (pitStops != null) 'pit_stops': pitStops,
      if (finishStatus != null) 'finish_status': finishStatus,
      if (dnfReason != null) 'dnf_reason': dnfReason,
      if (swaps != null) 'swaps': swaps,
      if (aids != null) 'aids': aids,
    });
  }

  ResultsDriversCompanion copyWith({
    Value<int>? fileId,
    Value<int>? driverIndex,
    Value<String>? name,
    Value<bool>? isPlayer,
    Value<String>? vehicleFile,
    Value<String>? vehicleName,
    Value<String>? carType,
    Value<String>? carClass,
    Value<String>? category,
    Value<String>? teamName,
    Value<String>? carNumber,
    Value<int?>? gridPosition,
    Value<int?>? classGridPosition,
    Value<int?>? position,
    Value<int?>? classPosition,
    Value<double?>? bestLapSeconds,
    Value<double?>? finishElapsed,
    Value<int>? lapsCompleted,
    Value<int>? pitStops,
    Value<String>? finishStatus,
    Value<String?>? dnfReason,
    Value<String>? swaps,
    Value<String>? aids,
  }) {
    return ResultsDriversCompanion(
      fileId: fileId ?? this.fileId,
      driverIndex: driverIndex ?? this.driverIndex,
      name: name ?? this.name,
      isPlayer: isPlayer ?? this.isPlayer,
      vehicleFile: vehicleFile ?? this.vehicleFile,
      vehicleName: vehicleName ?? this.vehicleName,
      carType: carType ?? this.carType,
      carClass: carClass ?? this.carClass,
      category: category ?? this.category,
      teamName: teamName ?? this.teamName,
      carNumber: carNumber ?? this.carNumber,
      gridPosition: gridPosition ?? this.gridPosition,
      classGridPosition: classGridPosition ?? this.classGridPosition,
      position: position ?? this.position,
      classPosition: classPosition ?? this.classPosition,
      bestLapSeconds: bestLapSeconds ?? this.bestLapSeconds,
      finishElapsed: finishElapsed ?? this.finishElapsed,
      lapsCompleted: lapsCompleted ?? this.lapsCompleted,
      pitStops: pitStops ?? this.pitStops,
      finishStatus: finishStatus ?? this.finishStatus,
      dnfReason: dnfReason ?? this.dnfReason,
      swaps: swaps ?? this.swaps,
      aids: aids ?? this.aids,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (driverIndex.present) {
      map['driver_index'] = Variable<int>(driverIndex.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isPlayer.present) {
      map['is_player'] = Variable<bool>(isPlayer.value);
    }
    if (vehicleFile.present) {
      map['vehicle_file'] = Variable<String>(vehicleFile.value);
    }
    if (vehicleName.present) {
      map['vehicle_name'] = Variable<String>(vehicleName.value);
    }
    if (carType.present) {
      map['car_type'] = Variable<String>(carType.value);
    }
    if (carClass.present) {
      map['car_class'] = Variable<String>(carClass.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (teamName.present) {
      map['team_name'] = Variable<String>(teamName.value);
    }
    if (carNumber.present) {
      map['car_number'] = Variable<String>(carNumber.value);
    }
    if (gridPosition.present) {
      map['grid_position'] = Variable<int>(gridPosition.value);
    }
    if (classGridPosition.present) {
      map['class_grid_position'] = Variable<int>(classGridPosition.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (classPosition.present) {
      map['class_position'] = Variable<int>(classPosition.value);
    }
    if (bestLapSeconds.present) {
      map['best_lap_seconds'] = Variable<double>(bestLapSeconds.value);
    }
    if (finishElapsed.present) {
      map['finish_elapsed'] = Variable<double>(finishElapsed.value);
    }
    if (lapsCompleted.present) {
      map['laps_completed'] = Variable<int>(lapsCompleted.value);
    }
    if (pitStops.present) {
      map['pit_stops'] = Variable<int>(pitStops.value);
    }
    if (finishStatus.present) {
      map['finish_status'] = Variable<String>(finishStatus.value);
    }
    if (dnfReason.present) {
      map['dnf_reason'] = Variable<String>(dnfReason.value);
    }
    if (swaps.present) {
      map['swaps'] = Variable<String>(swaps.value);
    }
    if (aids.present) {
      map['aids'] = Variable<String>(aids.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsDriversCompanion(')
          ..write('fileId: $fileId, ')
          ..write('driverIndex: $driverIndex, ')
          ..write('name: $name, ')
          ..write('isPlayer: $isPlayer, ')
          ..write('vehicleFile: $vehicleFile, ')
          ..write('vehicleName: $vehicleName, ')
          ..write('carType: $carType, ')
          ..write('carClass: $carClass, ')
          ..write('category: $category, ')
          ..write('teamName: $teamName, ')
          ..write('carNumber: $carNumber, ')
          ..write('gridPosition: $gridPosition, ')
          ..write('classGridPosition: $classGridPosition, ')
          ..write('position: $position, ')
          ..write('classPosition: $classPosition, ')
          ..write('bestLapSeconds: $bestLapSeconds, ')
          ..write('finishElapsed: $finishElapsed, ')
          ..write('lapsCompleted: $lapsCompleted, ')
          ..write('pitStops: $pitStops, ')
          ..write('finishStatus: $finishStatus, ')
          ..write('dnfReason: $dnfReason, ')
          ..write('swaps: $swaps, ')
          ..write('aids: $aids')
          ..write(')'))
        .toString();
  }
}

class $ResultsLapsTable extends ResultsLaps
    with TableInfo<$ResultsLapsTable, ResultsLapRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsLapsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverIndexMeta = const VerificationMeta(
    'driverIndex',
  );
  @override
  late final GeneratedColumn<int> driverIndex = GeneratedColumn<int>(
    'driver_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startElapsedMeta = const VerificationMeta(
    'startElapsed',
  );
  @override
  late final GeneratedColumn<double> startElapsed = GeneratedColumn<double>(
    'start_elapsed',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapSecondsMeta = const VerificationMeta(
    'lapSeconds',
  );
  @override
  late final GeneratedColumn<double> lapSeconds = GeneratedColumn<double>(
    'lap_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sector1SecondsMeta = const VerificationMeta(
    'sector1Seconds',
  );
  @override
  late final GeneratedColumn<double> sector1Seconds = GeneratedColumn<double>(
    'sector1_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sector2SecondsMeta = const VerificationMeta(
    'sector2Seconds',
  );
  @override
  late final GeneratedColumn<double> sector2Seconds = GeneratedColumn<double>(
    'sector2_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sector3SecondsMeta = const VerificationMeta(
    'sector3Seconds',
  );
  @override
  late final GeneratedColumn<double> sector3Seconds = GeneratedColumn<double>(
    'sector3_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topSpeedKmhMeta = const VerificationMeta(
    'topSpeedKmh',
  );
  @override
  late final GeneratedColumn<double> topSpeedKmh = GeneratedColumn<double>(
    'top_speed_kmh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelFractionMeta = const VerificationMeta(
    'fuelFraction',
  );
  @override
  late final GeneratedColumn<double> fuelFraction = GeneratedColumn<double>(
    'fuel_fraction',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuelUsedFractionMeta = const VerificationMeta(
    'fuelUsedFraction',
  );
  @override
  late final GeneratedColumn<double> fuelUsedFraction = GeneratedColumn<double>(
    'fuel_used_fraction',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyFractionMeta = const VerificationMeta(
    'energyFraction',
  );
  @override
  late final GeneratedColumn<double> energyFraction = GeneratedColumn<double>(
    'energy_fraction',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _energyUsedFractionMeta =
      const VerificationMeta('energyUsedFraction');
  @override
  late final GeneratedColumn<double> energyUsedFraction =
      GeneratedColumn<double>(
        'energy_used_fraction',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _wearFrontLeftMeta = const VerificationMeta(
    'wearFrontLeft',
  );
  @override
  late final GeneratedColumn<double> wearFrontLeft = GeneratedColumn<double>(
    'wear_front_left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wearFrontRightMeta = const VerificationMeta(
    'wearFrontRight',
  );
  @override
  late final GeneratedColumn<double> wearFrontRight = GeneratedColumn<double>(
    'wear_front_right',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wearRearLeftMeta = const VerificationMeta(
    'wearRearLeft',
  );
  @override
  late final GeneratedColumn<double> wearRearLeft = GeneratedColumn<double>(
    'wear_rear_left',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wearRearRightMeta = const VerificationMeta(
    'wearRearRight',
  );
  @override
  late final GeneratedColumn<double> wearRearRight = GeneratedColumn<double>(
    'wear_rear_right',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _compoundFrontMeta = const VerificationMeta(
    'compoundFront',
  );
  @override
  late final GeneratedColumn<String> compoundFront = GeneratedColumn<String>(
    'compound_front',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _compoundRearMeta = const VerificationMeta(
    'compoundRear',
  );
  @override
  late final GeneratedColumn<String> compoundRear = GeneratedColumn<String>(
    'compound_rear',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pitMeta = const VerificationMeta('pit');
  @override
  late final GeneratedColumn<bool> pit = GeneratedColumn<bool>(
    'pit',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pit" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    driverIndex,
    seq,
    number,
    position,
    startElapsed,
    lapSeconds,
    sector1Seconds,
    sector2Seconds,
    sector3Seconds,
    topSpeedKmh,
    fuelFraction,
    fuelUsedFraction,
    energyFraction,
    energyUsedFraction,
    wearFrontLeft,
    wearFrontRight,
    wearRearLeft,
    wearRearRight,
    compoundFront,
    compoundRear,
    pit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results_laps';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResultsLapRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('driver_index')) {
      context.handle(
        _driverIndexMeta,
        driverIndex.isAcceptableOrUnknown(
          data['driver_index']!,
          _driverIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_driverIndexMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('start_elapsed')) {
      context.handle(
        _startElapsedMeta,
        startElapsed.isAcceptableOrUnknown(
          data['start_elapsed']!,
          _startElapsedMeta,
        ),
      );
    }
    if (data.containsKey('lap_seconds')) {
      context.handle(
        _lapSecondsMeta,
        lapSeconds.isAcceptableOrUnknown(data['lap_seconds']!, _lapSecondsMeta),
      );
    }
    if (data.containsKey('sector1_seconds')) {
      context.handle(
        _sector1SecondsMeta,
        sector1Seconds.isAcceptableOrUnknown(
          data['sector1_seconds']!,
          _sector1SecondsMeta,
        ),
      );
    }
    if (data.containsKey('sector2_seconds')) {
      context.handle(
        _sector2SecondsMeta,
        sector2Seconds.isAcceptableOrUnknown(
          data['sector2_seconds']!,
          _sector2SecondsMeta,
        ),
      );
    }
    if (data.containsKey('sector3_seconds')) {
      context.handle(
        _sector3SecondsMeta,
        sector3Seconds.isAcceptableOrUnknown(
          data['sector3_seconds']!,
          _sector3SecondsMeta,
        ),
      );
    }
    if (data.containsKey('top_speed_kmh')) {
      context.handle(
        _topSpeedKmhMeta,
        topSpeedKmh.isAcceptableOrUnknown(
          data['top_speed_kmh']!,
          _topSpeedKmhMeta,
        ),
      );
    }
    if (data.containsKey('fuel_fraction')) {
      context.handle(
        _fuelFractionMeta,
        fuelFraction.isAcceptableOrUnknown(
          data['fuel_fraction']!,
          _fuelFractionMeta,
        ),
      );
    }
    if (data.containsKey('fuel_used_fraction')) {
      context.handle(
        _fuelUsedFractionMeta,
        fuelUsedFraction.isAcceptableOrUnknown(
          data['fuel_used_fraction']!,
          _fuelUsedFractionMeta,
        ),
      );
    }
    if (data.containsKey('energy_fraction')) {
      context.handle(
        _energyFractionMeta,
        energyFraction.isAcceptableOrUnknown(
          data['energy_fraction']!,
          _energyFractionMeta,
        ),
      );
    }
    if (data.containsKey('energy_used_fraction')) {
      context.handle(
        _energyUsedFractionMeta,
        energyUsedFraction.isAcceptableOrUnknown(
          data['energy_used_fraction']!,
          _energyUsedFractionMeta,
        ),
      );
    }
    if (data.containsKey('wear_front_left')) {
      context.handle(
        _wearFrontLeftMeta,
        wearFrontLeft.isAcceptableOrUnknown(
          data['wear_front_left']!,
          _wearFrontLeftMeta,
        ),
      );
    }
    if (data.containsKey('wear_front_right')) {
      context.handle(
        _wearFrontRightMeta,
        wearFrontRight.isAcceptableOrUnknown(
          data['wear_front_right']!,
          _wearFrontRightMeta,
        ),
      );
    }
    if (data.containsKey('wear_rear_left')) {
      context.handle(
        _wearRearLeftMeta,
        wearRearLeft.isAcceptableOrUnknown(
          data['wear_rear_left']!,
          _wearRearLeftMeta,
        ),
      );
    }
    if (data.containsKey('wear_rear_right')) {
      context.handle(
        _wearRearRightMeta,
        wearRearRight.isAcceptableOrUnknown(
          data['wear_rear_right']!,
          _wearRearRightMeta,
        ),
      );
    }
    if (data.containsKey('compound_front')) {
      context.handle(
        _compoundFrontMeta,
        compoundFront.isAcceptableOrUnknown(
          data['compound_front']!,
          _compoundFrontMeta,
        ),
      );
    }
    if (data.containsKey('compound_rear')) {
      context.handle(
        _compoundRearMeta,
        compoundRear.isAcceptableOrUnknown(
          data['compound_rear']!,
          _compoundRearMeta,
        ),
      );
    }
    if (data.containsKey('pit')) {
      context.handle(
        _pitMeta,
        pit.isAcceptableOrUnknown(data['pit']!, _pitMeta),
      );
    } else if (isInserting) {
      context.missing(_pitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId, driverIndex, seq};
  @override
  ResultsLapRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResultsLapRow(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      )!,
      driverIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}driver_index'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      ),
      startElapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_elapsed'],
      ),
      lapSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lap_seconds'],
      ),
      sector1Seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sector1_seconds'],
      ),
      sector2Seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sector2_seconds'],
      ),
      sector3Seconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sector3_seconds'],
      ),
      topSpeedKmh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}top_speed_kmh'],
      ),
      fuelFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_fraction'],
      ),
      fuelUsedFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fuel_used_fraction'],
      ),
      energyFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_fraction'],
      ),
      energyUsedFraction: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}energy_used_fraction'],
      ),
      wearFrontLeft: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wear_front_left'],
      ),
      wearFrontRight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wear_front_right'],
      ),
      wearRearLeft: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wear_rear_left'],
      ),
      wearRearRight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wear_rear_right'],
      ),
      compoundFront: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_front'],
      ),
      compoundRear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compound_rear'],
      ),
      pit: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pit'],
      )!,
    );
  }

  @override
  $ResultsLapsTable createAlias(String alias) {
    return $ResultsLapsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ResultsLapRow extends DataClass implements Insertable<ResultsLapRow> {
  /// [ResultsFiles.id].
  final int fileId;
  final int driverIndex;

  /// Order within the car's laps. The key, rather than [number], so a file
  /// that ever repeats a lap number still stores both.
  final int seq;
  final int number;
  final int? position;
  final double? startElapsed;
  final double? lapSeconds;
  final double? sector1Seconds;
  final double? sector2Seconds;
  final double? sector3Seconds;
  final double? topSpeedKmh;
  final double? fuelFraction;
  final double? fuelUsedFraction;
  final double? energyFraction;
  final double? energyUsedFraction;
  final double? wearFrontLeft;
  final double? wearFrontRight;
  final double? wearRearLeft;
  final double? wearRearRight;
  final String? compoundFront;
  final String? compoundRear;
  final bool pit;
  const ResultsLapRow({
    required this.fileId,
    required this.driverIndex,
    required this.seq,
    required this.number,
    this.position,
    this.startElapsed,
    this.lapSeconds,
    this.sector1Seconds,
    this.sector2Seconds,
    this.sector3Seconds,
    this.topSpeedKmh,
    this.fuelFraction,
    this.fuelUsedFraction,
    this.energyFraction,
    this.energyUsedFraction,
    this.wearFrontLeft,
    this.wearFrontRight,
    this.wearRearLeft,
    this.wearRearRight,
    this.compoundFront,
    this.compoundRear,
    required this.pit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<int>(fileId);
    map['driver_index'] = Variable<int>(driverIndex);
    map['seq'] = Variable<int>(seq);
    map['number'] = Variable<int>(number);
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<int>(position);
    }
    if (!nullToAbsent || startElapsed != null) {
      map['start_elapsed'] = Variable<double>(startElapsed);
    }
    if (!nullToAbsent || lapSeconds != null) {
      map['lap_seconds'] = Variable<double>(lapSeconds);
    }
    if (!nullToAbsent || sector1Seconds != null) {
      map['sector1_seconds'] = Variable<double>(sector1Seconds);
    }
    if (!nullToAbsent || sector2Seconds != null) {
      map['sector2_seconds'] = Variable<double>(sector2Seconds);
    }
    if (!nullToAbsent || sector3Seconds != null) {
      map['sector3_seconds'] = Variable<double>(sector3Seconds);
    }
    if (!nullToAbsent || topSpeedKmh != null) {
      map['top_speed_kmh'] = Variable<double>(topSpeedKmh);
    }
    if (!nullToAbsent || fuelFraction != null) {
      map['fuel_fraction'] = Variable<double>(fuelFraction);
    }
    if (!nullToAbsent || fuelUsedFraction != null) {
      map['fuel_used_fraction'] = Variable<double>(fuelUsedFraction);
    }
    if (!nullToAbsent || energyFraction != null) {
      map['energy_fraction'] = Variable<double>(energyFraction);
    }
    if (!nullToAbsent || energyUsedFraction != null) {
      map['energy_used_fraction'] = Variable<double>(energyUsedFraction);
    }
    if (!nullToAbsent || wearFrontLeft != null) {
      map['wear_front_left'] = Variable<double>(wearFrontLeft);
    }
    if (!nullToAbsent || wearFrontRight != null) {
      map['wear_front_right'] = Variable<double>(wearFrontRight);
    }
    if (!nullToAbsent || wearRearLeft != null) {
      map['wear_rear_left'] = Variable<double>(wearRearLeft);
    }
    if (!nullToAbsent || wearRearRight != null) {
      map['wear_rear_right'] = Variable<double>(wearRearRight);
    }
    if (!nullToAbsent || compoundFront != null) {
      map['compound_front'] = Variable<String>(compoundFront);
    }
    if (!nullToAbsent || compoundRear != null) {
      map['compound_rear'] = Variable<String>(compoundRear);
    }
    map['pit'] = Variable<bool>(pit);
    return map;
  }

  ResultsLapsCompanion toCompanion(bool nullToAbsent) {
    return ResultsLapsCompanion(
      fileId: Value(fileId),
      driverIndex: Value(driverIndex),
      seq: Value(seq),
      number: Value(number),
      position: position == null && nullToAbsent
          ? const Value.absent()
          : Value(position),
      startElapsed: startElapsed == null && nullToAbsent
          ? const Value.absent()
          : Value(startElapsed),
      lapSeconds: lapSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(lapSeconds),
      sector1Seconds: sector1Seconds == null && nullToAbsent
          ? const Value.absent()
          : Value(sector1Seconds),
      sector2Seconds: sector2Seconds == null && nullToAbsent
          ? const Value.absent()
          : Value(sector2Seconds),
      sector3Seconds: sector3Seconds == null && nullToAbsent
          ? const Value.absent()
          : Value(sector3Seconds),
      topSpeedKmh: topSpeedKmh == null && nullToAbsent
          ? const Value.absent()
          : Value(topSpeedKmh),
      fuelFraction: fuelFraction == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelFraction),
      fuelUsedFraction: fuelUsedFraction == null && nullToAbsent
          ? const Value.absent()
          : Value(fuelUsedFraction),
      energyFraction: energyFraction == null && nullToAbsent
          ? const Value.absent()
          : Value(energyFraction),
      energyUsedFraction: energyUsedFraction == null && nullToAbsent
          ? const Value.absent()
          : Value(energyUsedFraction),
      wearFrontLeft: wearFrontLeft == null && nullToAbsent
          ? const Value.absent()
          : Value(wearFrontLeft),
      wearFrontRight: wearFrontRight == null && nullToAbsent
          ? const Value.absent()
          : Value(wearFrontRight),
      wearRearLeft: wearRearLeft == null && nullToAbsent
          ? const Value.absent()
          : Value(wearRearLeft),
      wearRearRight: wearRearRight == null && nullToAbsent
          ? const Value.absent()
          : Value(wearRearRight),
      compoundFront: compoundFront == null && nullToAbsent
          ? const Value.absent()
          : Value(compoundFront),
      compoundRear: compoundRear == null && nullToAbsent
          ? const Value.absent()
          : Value(compoundRear),
      pit: Value(pit),
    );
  }

  factory ResultsLapRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResultsLapRow(
      fileId: serializer.fromJson<int>(json['fileId']),
      driverIndex: serializer.fromJson<int>(json['driverIndex']),
      seq: serializer.fromJson<int>(json['seq']),
      number: serializer.fromJson<int>(json['number']),
      position: serializer.fromJson<int?>(json['position']),
      startElapsed: serializer.fromJson<double?>(json['startElapsed']),
      lapSeconds: serializer.fromJson<double?>(json['lapSeconds']),
      sector1Seconds: serializer.fromJson<double?>(json['sector1Seconds']),
      sector2Seconds: serializer.fromJson<double?>(json['sector2Seconds']),
      sector3Seconds: serializer.fromJson<double?>(json['sector3Seconds']),
      topSpeedKmh: serializer.fromJson<double?>(json['topSpeedKmh']),
      fuelFraction: serializer.fromJson<double?>(json['fuelFraction']),
      fuelUsedFraction: serializer.fromJson<double?>(json['fuelUsedFraction']),
      energyFraction: serializer.fromJson<double?>(json['energyFraction']),
      energyUsedFraction: serializer.fromJson<double?>(
        json['energyUsedFraction'],
      ),
      wearFrontLeft: serializer.fromJson<double?>(json['wearFrontLeft']),
      wearFrontRight: serializer.fromJson<double?>(json['wearFrontRight']),
      wearRearLeft: serializer.fromJson<double?>(json['wearRearLeft']),
      wearRearRight: serializer.fromJson<double?>(json['wearRearRight']),
      compoundFront: serializer.fromJson<String?>(json['compoundFront']),
      compoundRear: serializer.fromJson<String?>(json['compoundRear']),
      pit: serializer.fromJson<bool>(json['pit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<int>(fileId),
      'driverIndex': serializer.toJson<int>(driverIndex),
      'seq': serializer.toJson<int>(seq),
      'number': serializer.toJson<int>(number),
      'position': serializer.toJson<int?>(position),
      'startElapsed': serializer.toJson<double?>(startElapsed),
      'lapSeconds': serializer.toJson<double?>(lapSeconds),
      'sector1Seconds': serializer.toJson<double?>(sector1Seconds),
      'sector2Seconds': serializer.toJson<double?>(sector2Seconds),
      'sector3Seconds': serializer.toJson<double?>(sector3Seconds),
      'topSpeedKmh': serializer.toJson<double?>(topSpeedKmh),
      'fuelFraction': serializer.toJson<double?>(fuelFraction),
      'fuelUsedFraction': serializer.toJson<double?>(fuelUsedFraction),
      'energyFraction': serializer.toJson<double?>(energyFraction),
      'energyUsedFraction': serializer.toJson<double?>(energyUsedFraction),
      'wearFrontLeft': serializer.toJson<double?>(wearFrontLeft),
      'wearFrontRight': serializer.toJson<double?>(wearFrontRight),
      'wearRearLeft': serializer.toJson<double?>(wearRearLeft),
      'wearRearRight': serializer.toJson<double?>(wearRearRight),
      'compoundFront': serializer.toJson<String?>(compoundFront),
      'compoundRear': serializer.toJson<String?>(compoundRear),
      'pit': serializer.toJson<bool>(pit),
    };
  }

  ResultsLapRow copyWith({
    int? fileId,
    int? driverIndex,
    int? seq,
    int? number,
    Value<int?> position = const Value.absent(),
    Value<double?> startElapsed = const Value.absent(),
    Value<double?> lapSeconds = const Value.absent(),
    Value<double?> sector1Seconds = const Value.absent(),
    Value<double?> sector2Seconds = const Value.absent(),
    Value<double?> sector3Seconds = const Value.absent(),
    Value<double?> topSpeedKmh = const Value.absent(),
    Value<double?> fuelFraction = const Value.absent(),
    Value<double?> fuelUsedFraction = const Value.absent(),
    Value<double?> energyFraction = const Value.absent(),
    Value<double?> energyUsedFraction = const Value.absent(),
    Value<double?> wearFrontLeft = const Value.absent(),
    Value<double?> wearFrontRight = const Value.absent(),
    Value<double?> wearRearLeft = const Value.absent(),
    Value<double?> wearRearRight = const Value.absent(),
    Value<String?> compoundFront = const Value.absent(),
    Value<String?> compoundRear = const Value.absent(),
    bool? pit,
  }) => ResultsLapRow(
    fileId: fileId ?? this.fileId,
    driverIndex: driverIndex ?? this.driverIndex,
    seq: seq ?? this.seq,
    number: number ?? this.number,
    position: position.present ? position.value : this.position,
    startElapsed: startElapsed.present ? startElapsed.value : this.startElapsed,
    lapSeconds: lapSeconds.present ? lapSeconds.value : this.lapSeconds,
    sector1Seconds: sector1Seconds.present
        ? sector1Seconds.value
        : this.sector1Seconds,
    sector2Seconds: sector2Seconds.present
        ? sector2Seconds.value
        : this.sector2Seconds,
    sector3Seconds: sector3Seconds.present
        ? sector3Seconds.value
        : this.sector3Seconds,
    topSpeedKmh: topSpeedKmh.present ? topSpeedKmh.value : this.topSpeedKmh,
    fuelFraction: fuelFraction.present ? fuelFraction.value : this.fuelFraction,
    fuelUsedFraction: fuelUsedFraction.present
        ? fuelUsedFraction.value
        : this.fuelUsedFraction,
    energyFraction: energyFraction.present
        ? energyFraction.value
        : this.energyFraction,
    energyUsedFraction: energyUsedFraction.present
        ? energyUsedFraction.value
        : this.energyUsedFraction,
    wearFrontLeft: wearFrontLeft.present
        ? wearFrontLeft.value
        : this.wearFrontLeft,
    wearFrontRight: wearFrontRight.present
        ? wearFrontRight.value
        : this.wearFrontRight,
    wearRearLeft: wearRearLeft.present ? wearRearLeft.value : this.wearRearLeft,
    wearRearRight: wearRearRight.present
        ? wearRearRight.value
        : this.wearRearRight,
    compoundFront: compoundFront.present
        ? compoundFront.value
        : this.compoundFront,
    compoundRear: compoundRear.present ? compoundRear.value : this.compoundRear,
    pit: pit ?? this.pit,
  );
  ResultsLapRow copyWithCompanion(ResultsLapsCompanion data) {
    return ResultsLapRow(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      driverIndex: data.driverIndex.present
          ? data.driverIndex.value
          : this.driverIndex,
      seq: data.seq.present ? data.seq.value : this.seq,
      number: data.number.present ? data.number.value : this.number,
      position: data.position.present ? data.position.value : this.position,
      startElapsed: data.startElapsed.present
          ? data.startElapsed.value
          : this.startElapsed,
      lapSeconds: data.lapSeconds.present
          ? data.lapSeconds.value
          : this.lapSeconds,
      sector1Seconds: data.sector1Seconds.present
          ? data.sector1Seconds.value
          : this.sector1Seconds,
      sector2Seconds: data.sector2Seconds.present
          ? data.sector2Seconds.value
          : this.sector2Seconds,
      sector3Seconds: data.sector3Seconds.present
          ? data.sector3Seconds.value
          : this.sector3Seconds,
      topSpeedKmh: data.topSpeedKmh.present
          ? data.topSpeedKmh.value
          : this.topSpeedKmh,
      fuelFraction: data.fuelFraction.present
          ? data.fuelFraction.value
          : this.fuelFraction,
      fuelUsedFraction: data.fuelUsedFraction.present
          ? data.fuelUsedFraction.value
          : this.fuelUsedFraction,
      energyFraction: data.energyFraction.present
          ? data.energyFraction.value
          : this.energyFraction,
      energyUsedFraction: data.energyUsedFraction.present
          ? data.energyUsedFraction.value
          : this.energyUsedFraction,
      wearFrontLeft: data.wearFrontLeft.present
          ? data.wearFrontLeft.value
          : this.wearFrontLeft,
      wearFrontRight: data.wearFrontRight.present
          ? data.wearFrontRight.value
          : this.wearFrontRight,
      wearRearLeft: data.wearRearLeft.present
          ? data.wearRearLeft.value
          : this.wearRearLeft,
      wearRearRight: data.wearRearRight.present
          ? data.wearRearRight.value
          : this.wearRearRight,
      compoundFront: data.compoundFront.present
          ? data.compoundFront.value
          : this.compoundFront,
      compoundRear: data.compoundRear.present
          ? data.compoundRear.value
          : this.compoundRear,
      pit: data.pit.present ? data.pit.value : this.pit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResultsLapRow(')
          ..write('fileId: $fileId, ')
          ..write('driverIndex: $driverIndex, ')
          ..write('seq: $seq, ')
          ..write('number: $number, ')
          ..write('position: $position, ')
          ..write('startElapsed: $startElapsed, ')
          ..write('lapSeconds: $lapSeconds, ')
          ..write('sector1Seconds: $sector1Seconds, ')
          ..write('sector2Seconds: $sector2Seconds, ')
          ..write('sector3Seconds: $sector3Seconds, ')
          ..write('topSpeedKmh: $topSpeedKmh, ')
          ..write('fuelFraction: $fuelFraction, ')
          ..write('fuelUsedFraction: $fuelUsedFraction, ')
          ..write('energyFraction: $energyFraction, ')
          ..write('energyUsedFraction: $energyUsedFraction, ')
          ..write('wearFrontLeft: $wearFrontLeft, ')
          ..write('wearFrontRight: $wearFrontRight, ')
          ..write('wearRearLeft: $wearRearLeft, ')
          ..write('wearRearRight: $wearRearRight, ')
          ..write('compoundFront: $compoundFront, ')
          ..write('compoundRear: $compoundRear, ')
          ..write('pit: $pit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    fileId,
    driverIndex,
    seq,
    number,
    position,
    startElapsed,
    lapSeconds,
    sector1Seconds,
    sector2Seconds,
    sector3Seconds,
    topSpeedKmh,
    fuelFraction,
    fuelUsedFraction,
    energyFraction,
    energyUsedFraction,
    wearFrontLeft,
    wearFrontRight,
    wearRearLeft,
    wearRearRight,
    compoundFront,
    compoundRear,
    pit,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResultsLapRow &&
          other.fileId == this.fileId &&
          other.driverIndex == this.driverIndex &&
          other.seq == this.seq &&
          other.number == this.number &&
          other.position == this.position &&
          other.startElapsed == this.startElapsed &&
          other.lapSeconds == this.lapSeconds &&
          other.sector1Seconds == this.sector1Seconds &&
          other.sector2Seconds == this.sector2Seconds &&
          other.sector3Seconds == this.sector3Seconds &&
          other.topSpeedKmh == this.topSpeedKmh &&
          other.fuelFraction == this.fuelFraction &&
          other.fuelUsedFraction == this.fuelUsedFraction &&
          other.energyFraction == this.energyFraction &&
          other.energyUsedFraction == this.energyUsedFraction &&
          other.wearFrontLeft == this.wearFrontLeft &&
          other.wearFrontRight == this.wearFrontRight &&
          other.wearRearLeft == this.wearRearLeft &&
          other.wearRearRight == this.wearRearRight &&
          other.compoundFront == this.compoundFront &&
          other.compoundRear == this.compoundRear &&
          other.pit == this.pit);
}

class ResultsLapsCompanion extends UpdateCompanion<ResultsLapRow> {
  final Value<int> fileId;
  final Value<int> driverIndex;
  final Value<int> seq;
  final Value<int> number;
  final Value<int?> position;
  final Value<double?> startElapsed;
  final Value<double?> lapSeconds;
  final Value<double?> sector1Seconds;
  final Value<double?> sector2Seconds;
  final Value<double?> sector3Seconds;
  final Value<double?> topSpeedKmh;
  final Value<double?> fuelFraction;
  final Value<double?> fuelUsedFraction;
  final Value<double?> energyFraction;
  final Value<double?> energyUsedFraction;
  final Value<double?> wearFrontLeft;
  final Value<double?> wearFrontRight;
  final Value<double?> wearRearLeft;
  final Value<double?> wearRearRight;
  final Value<String?> compoundFront;
  final Value<String?> compoundRear;
  final Value<bool> pit;
  const ResultsLapsCompanion({
    this.fileId = const Value.absent(),
    this.driverIndex = const Value.absent(),
    this.seq = const Value.absent(),
    this.number = const Value.absent(),
    this.position = const Value.absent(),
    this.startElapsed = const Value.absent(),
    this.lapSeconds = const Value.absent(),
    this.sector1Seconds = const Value.absent(),
    this.sector2Seconds = const Value.absent(),
    this.sector3Seconds = const Value.absent(),
    this.topSpeedKmh = const Value.absent(),
    this.fuelFraction = const Value.absent(),
    this.fuelUsedFraction = const Value.absent(),
    this.energyFraction = const Value.absent(),
    this.energyUsedFraction = const Value.absent(),
    this.wearFrontLeft = const Value.absent(),
    this.wearFrontRight = const Value.absent(),
    this.wearRearLeft = const Value.absent(),
    this.wearRearRight = const Value.absent(),
    this.compoundFront = const Value.absent(),
    this.compoundRear = const Value.absent(),
    this.pit = const Value.absent(),
  });
  ResultsLapsCompanion.insert({
    required int fileId,
    required int driverIndex,
    required int seq,
    required int number,
    this.position = const Value.absent(),
    this.startElapsed = const Value.absent(),
    this.lapSeconds = const Value.absent(),
    this.sector1Seconds = const Value.absent(),
    this.sector2Seconds = const Value.absent(),
    this.sector3Seconds = const Value.absent(),
    this.topSpeedKmh = const Value.absent(),
    this.fuelFraction = const Value.absent(),
    this.fuelUsedFraction = const Value.absent(),
    this.energyFraction = const Value.absent(),
    this.energyUsedFraction = const Value.absent(),
    this.wearFrontLeft = const Value.absent(),
    this.wearFrontRight = const Value.absent(),
    this.wearRearLeft = const Value.absent(),
    this.wearRearRight = const Value.absent(),
    this.compoundFront = const Value.absent(),
    this.compoundRear = const Value.absent(),
    required bool pit,
  }) : fileId = Value(fileId),
       driverIndex = Value(driverIndex),
       seq = Value(seq),
       number = Value(number),
       pit = Value(pit);
  static Insertable<ResultsLapRow> custom({
    Expression<int>? fileId,
    Expression<int>? driverIndex,
    Expression<int>? seq,
    Expression<int>? number,
    Expression<int>? position,
    Expression<double>? startElapsed,
    Expression<double>? lapSeconds,
    Expression<double>? sector1Seconds,
    Expression<double>? sector2Seconds,
    Expression<double>? sector3Seconds,
    Expression<double>? topSpeedKmh,
    Expression<double>? fuelFraction,
    Expression<double>? fuelUsedFraction,
    Expression<double>? energyFraction,
    Expression<double>? energyUsedFraction,
    Expression<double>? wearFrontLeft,
    Expression<double>? wearFrontRight,
    Expression<double>? wearRearLeft,
    Expression<double>? wearRearRight,
    Expression<String>? compoundFront,
    Expression<String>? compoundRear,
    Expression<bool>? pit,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (driverIndex != null) 'driver_index': driverIndex,
      if (seq != null) 'seq': seq,
      if (number != null) 'number': number,
      if (position != null) 'position': position,
      if (startElapsed != null) 'start_elapsed': startElapsed,
      if (lapSeconds != null) 'lap_seconds': lapSeconds,
      if (sector1Seconds != null) 'sector1_seconds': sector1Seconds,
      if (sector2Seconds != null) 'sector2_seconds': sector2Seconds,
      if (sector3Seconds != null) 'sector3_seconds': sector3Seconds,
      if (topSpeedKmh != null) 'top_speed_kmh': topSpeedKmh,
      if (fuelFraction != null) 'fuel_fraction': fuelFraction,
      if (fuelUsedFraction != null) 'fuel_used_fraction': fuelUsedFraction,
      if (energyFraction != null) 'energy_fraction': energyFraction,
      if (energyUsedFraction != null)
        'energy_used_fraction': energyUsedFraction,
      if (wearFrontLeft != null) 'wear_front_left': wearFrontLeft,
      if (wearFrontRight != null) 'wear_front_right': wearFrontRight,
      if (wearRearLeft != null) 'wear_rear_left': wearRearLeft,
      if (wearRearRight != null) 'wear_rear_right': wearRearRight,
      if (compoundFront != null) 'compound_front': compoundFront,
      if (compoundRear != null) 'compound_rear': compoundRear,
      if (pit != null) 'pit': pit,
    });
  }

  ResultsLapsCompanion copyWith({
    Value<int>? fileId,
    Value<int>? driverIndex,
    Value<int>? seq,
    Value<int>? number,
    Value<int?>? position,
    Value<double?>? startElapsed,
    Value<double?>? lapSeconds,
    Value<double?>? sector1Seconds,
    Value<double?>? sector2Seconds,
    Value<double?>? sector3Seconds,
    Value<double?>? topSpeedKmh,
    Value<double?>? fuelFraction,
    Value<double?>? fuelUsedFraction,
    Value<double?>? energyFraction,
    Value<double?>? energyUsedFraction,
    Value<double?>? wearFrontLeft,
    Value<double?>? wearFrontRight,
    Value<double?>? wearRearLeft,
    Value<double?>? wearRearRight,
    Value<String?>? compoundFront,
    Value<String?>? compoundRear,
    Value<bool>? pit,
  }) {
    return ResultsLapsCompanion(
      fileId: fileId ?? this.fileId,
      driverIndex: driverIndex ?? this.driverIndex,
      seq: seq ?? this.seq,
      number: number ?? this.number,
      position: position ?? this.position,
      startElapsed: startElapsed ?? this.startElapsed,
      lapSeconds: lapSeconds ?? this.lapSeconds,
      sector1Seconds: sector1Seconds ?? this.sector1Seconds,
      sector2Seconds: sector2Seconds ?? this.sector2Seconds,
      sector3Seconds: sector3Seconds ?? this.sector3Seconds,
      topSpeedKmh: topSpeedKmh ?? this.topSpeedKmh,
      fuelFraction: fuelFraction ?? this.fuelFraction,
      fuelUsedFraction: fuelUsedFraction ?? this.fuelUsedFraction,
      energyFraction: energyFraction ?? this.energyFraction,
      energyUsedFraction: energyUsedFraction ?? this.energyUsedFraction,
      wearFrontLeft: wearFrontLeft ?? this.wearFrontLeft,
      wearFrontRight: wearFrontRight ?? this.wearFrontRight,
      wearRearLeft: wearRearLeft ?? this.wearRearLeft,
      wearRearRight: wearRearRight ?? this.wearRearRight,
      compoundFront: compoundFront ?? this.compoundFront,
      compoundRear: compoundRear ?? this.compoundRear,
      pit: pit ?? this.pit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (driverIndex.present) {
      map['driver_index'] = Variable<int>(driverIndex.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (startElapsed.present) {
      map['start_elapsed'] = Variable<double>(startElapsed.value);
    }
    if (lapSeconds.present) {
      map['lap_seconds'] = Variable<double>(lapSeconds.value);
    }
    if (sector1Seconds.present) {
      map['sector1_seconds'] = Variable<double>(sector1Seconds.value);
    }
    if (sector2Seconds.present) {
      map['sector2_seconds'] = Variable<double>(sector2Seconds.value);
    }
    if (sector3Seconds.present) {
      map['sector3_seconds'] = Variable<double>(sector3Seconds.value);
    }
    if (topSpeedKmh.present) {
      map['top_speed_kmh'] = Variable<double>(topSpeedKmh.value);
    }
    if (fuelFraction.present) {
      map['fuel_fraction'] = Variable<double>(fuelFraction.value);
    }
    if (fuelUsedFraction.present) {
      map['fuel_used_fraction'] = Variable<double>(fuelUsedFraction.value);
    }
    if (energyFraction.present) {
      map['energy_fraction'] = Variable<double>(energyFraction.value);
    }
    if (energyUsedFraction.present) {
      map['energy_used_fraction'] = Variable<double>(energyUsedFraction.value);
    }
    if (wearFrontLeft.present) {
      map['wear_front_left'] = Variable<double>(wearFrontLeft.value);
    }
    if (wearFrontRight.present) {
      map['wear_front_right'] = Variable<double>(wearFrontRight.value);
    }
    if (wearRearLeft.present) {
      map['wear_rear_left'] = Variable<double>(wearRearLeft.value);
    }
    if (wearRearRight.present) {
      map['wear_rear_right'] = Variable<double>(wearRearRight.value);
    }
    if (compoundFront.present) {
      map['compound_front'] = Variable<String>(compoundFront.value);
    }
    if (compoundRear.present) {
      map['compound_rear'] = Variable<String>(compoundRear.value);
    }
    if (pit.present) {
      map['pit'] = Variable<bool>(pit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsLapsCompanion(')
          ..write('fileId: $fileId, ')
          ..write('driverIndex: $driverIndex, ')
          ..write('seq: $seq, ')
          ..write('number: $number, ')
          ..write('position: $position, ')
          ..write('startElapsed: $startElapsed, ')
          ..write('lapSeconds: $lapSeconds, ')
          ..write('sector1Seconds: $sector1Seconds, ')
          ..write('sector2Seconds: $sector2Seconds, ')
          ..write('sector3Seconds: $sector3Seconds, ')
          ..write('topSpeedKmh: $topSpeedKmh, ')
          ..write('fuelFraction: $fuelFraction, ')
          ..write('fuelUsedFraction: $fuelUsedFraction, ')
          ..write('energyFraction: $energyFraction, ')
          ..write('energyUsedFraction: $energyUsedFraction, ')
          ..write('wearFrontLeft: $wearFrontLeft, ')
          ..write('wearFrontRight: $wearFrontRight, ')
          ..write('wearRearLeft: $wearRearLeft, ')
          ..write('wearRearRight: $wearRearRight, ')
          ..write('compoundFront: $compoundFront, ')
          ..write('compoundRear: $compoundRear, ')
          ..write('pit: $pit')
          ..write(')'))
        .toString();
  }
}

class $ResultsEventsTable extends ResultsEvents
    with TableInfo<$ResultsEventsTable, ResultsEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<int> fileId = GeneratedColumn<int>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _elapsedMeta = const VerificationMeta(
    'elapsed',
  );
  @override
  late final GeneratedColumn<double> elapsed = GeneratedColumn<double>(
    'elapsed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _driverNameMeta = const VerificationMeta(
    'driverName',
  );
  @override
  late final GeneratedColumn<String> driverName = GeneratedColumn<String>(
    'driver_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lapMeta = const VerificationMeta('lap');
  @override
  late final GeneratedColumn<int> lap = GeneratedColumn<int>(
    'lap',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<int> resolution = GeneratedColumn<int>(
    'resolution',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warningPointsMeta = const VerificationMeta(
    'warningPoints',
  );
  @override
  late final GeneratedColumn<double> warningPoints = GeneratedColumn<double>(
    'warning_points',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentPointsMeta = const VerificationMeta(
    'currentPoints',
  );
  @override
  late final GeneratedColumn<double> currentPoints = GeneratedColumn<double>(
    'current_points',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _penaltyMeta = const VerificationMeta(
    'penalty',
  );
  @override
  late final GeneratedColumn<String> penalty = GeneratedColumn<String>(
    'penalty',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileId,
    seq,
    kind,
    elapsed,
    body,
    driverName,
    slot,
    lap,
    resolution,
    warningPoints,
    currentPoints,
    penalty,
    reason,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResultsEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('elapsed')) {
      context.handle(
        _elapsedMeta,
        elapsed.isAcceptableOrUnknown(data['elapsed']!, _elapsedMeta),
      );
    } else if (isInserting) {
      context.missing(_elapsedMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('driver_name')) {
      context.handle(
        _driverNameMeta,
        driverName.isAcceptableOrUnknown(data['driver_name']!, _driverNameMeta),
      );
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    }
    if (data.containsKey('lap')) {
      context.handle(
        _lapMeta,
        lap.isAcceptableOrUnknown(data['lap']!, _lapMeta),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    }
    if (data.containsKey('warning_points')) {
      context.handle(
        _warningPointsMeta,
        warningPoints.isAcceptableOrUnknown(
          data['warning_points']!,
          _warningPointsMeta,
        ),
      );
    }
    if (data.containsKey('current_points')) {
      context.handle(
        _currentPointsMeta,
        currentPoints.isAcceptableOrUnknown(
          data['current_points']!,
          _currentPointsMeta,
        ),
      );
    }
    if (data.containsKey('penalty')) {
      context.handle(
        _penaltyMeta,
        penalty.isAcceptableOrUnknown(data['penalty']!, _penaltyMeta),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileId, seq};
  @override
  ResultsEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResultsEventRow(
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      elapsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}elapsed'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      driverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver_name'],
      ),
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      ),
      lap: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lap'],
      ),
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resolution'],
      ),
      warningPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}warning_points'],
      ),
      currentPoints: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_points'],
      ),
      penalty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}penalty'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      ),
    );
  }

  @override
  $ResultsEventsTable createAlias(String alias) {
    return $ResultsEventsTable(attachedDatabase, alias);
  }

  @override
  bool get withoutRowId => true;
}

class ResultsEventRow extends DataClass implements Insertable<ResultsEventRow> {
  /// [ResultsFiles.id].
  final int fileId;
  final int seq;

  /// [ResultsEventKind.name].
  final String kind;
  final double elapsed;
  final String body;
  final String? driverName;
  final int? slot;
  final int? lap;
  final int? resolution;
  final double? warningPoints;
  final double? currentPoints;
  final String? penalty;
  final String? reason;
  const ResultsEventRow({
    required this.fileId,
    required this.seq,
    required this.kind,
    required this.elapsed,
    required this.body,
    this.driverName,
    this.slot,
    this.lap,
    this.resolution,
    this.warningPoints,
    this.currentPoints,
    this.penalty,
    this.reason,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_id'] = Variable<int>(fileId);
    map['seq'] = Variable<int>(seq);
    map['kind'] = Variable<String>(kind);
    map['elapsed'] = Variable<double>(elapsed);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || driverName != null) {
      map['driver_name'] = Variable<String>(driverName);
    }
    if (!nullToAbsent || slot != null) {
      map['slot'] = Variable<int>(slot);
    }
    if (!nullToAbsent || lap != null) {
      map['lap'] = Variable<int>(lap);
    }
    if (!nullToAbsent || resolution != null) {
      map['resolution'] = Variable<int>(resolution);
    }
    if (!nullToAbsent || warningPoints != null) {
      map['warning_points'] = Variable<double>(warningPoints);
    }
    if (!nullToAbsent || currentPoints != null) {
      map['current_points'] = Variable<double>(currentPoints);
    }
    if (!nullToAbsent || penalty != null) {
      map['penalty'] = Variable<String>(penalty);
    }
    if (!nullToAbsent || reason != null) {
      map['reason'] = Variable<String>(reason);
    }
    return map;
  }

  ResultsEventsCompanion toCompanion(bool nullToAbsent) {
    return ResultsEventsCompanion(
      fileId: Value(fileId),
      seq: Value(seq),
      kind: Value(kind),
      elapsed: Value(elapsed),
      body: Value(body),
      driverName: driverName == null && nullToAbsent
          ? const Value.absent()
          : Value(driverName),
      slot: slot == null && nullToAbsent ? const Value.absent() : Value(slot),
      lap: lap == null && nullToAbsent ? const Value.absent() : Value(lap),
      resolution: resolution == null && nullToAbsent
          ? const Value.absent()
          : Value(resolution),
      warningPoints: warningPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(warningPoints),
      currentPoints: currentPoints == null && nullToAbsent
          ? const Value.absent()
          : Value(currentPoints),
      penalty: penalty == null && nullToAbsent
          ? const Value.absent()
          : Value(penalty),
      reason: reason == null && nullToAbsent
          ? const Value.absent()
          : Value(reason),
    );
  }

  factory ResultsEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResultsEventRow(
      fileId: serializer.fromJson<int>(json['fileId']),
      seq: serializer.fromJson<int>(json['seq']),
      kind: serializer.fromJson<String>(json['kind']),
      elapsed: serializer.fromJson<double>(json['elapsed']),
      body: serializer.fromJson<String>(json['body']),
      driverName: serializer.fromJson<String?>(json['driverName']),
      slot: serializer.fromJson<int?>(json['slot']),
      lap: serializer.fromJson<int?>(json['lap']),
      resolution: serializer.fromJson<int?>(json['resolution']),
      warningPoints: serializer.fromJson<double?>(json['warningPoints']),
      currentPoints: serializer.fromJson<double?>(json['currentPoints']),
      penalty: serializer.fromJson<String?>(json['penalty']),
      reason: serializer.fromJson<String?>(json['reason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileId': serializer.toJson<int>(fileId),
      'seq': serializer.toJson<int>(seq),
      'kind': serializer.toJson<String>(kind),
      'elapsed': serializer.toJson<double>(elapsed),
      'body': serializer.toJson<String>(body),
      'driverName': serializer.toJson<String?>(driverName),
      'slot': serializer.toJson<int?>(slot),
      'lap': serializer.toJson<int?>(lap),
      'resolution': serializer.toJson<int?>(resolution),
      'warningPoints': serializer.toJson<double?>(warningPoints),
      'currentPoints': serializer.toJson<double?>(currentPoints),
      'penalty': serializer.toJson<String?>(penalty),
      'reason': serializer.toJson<String?>(reason),
    };
  }

  ResultsEventRow copyWith({
    int? fileId,
    int? seq,
    String? kind,
    double? elapsed,
    String? body,
    Value<String?> driverName = const Value.absent(),
    Value<int?> slot = const Value.absent(),
    Value<int?> lap = const Value.absent(),
    Value<int?> resolution = const Value.absent(),
    Value<double?> warningPoints = const Value.absent(),
    Value<double?> currentPoints = const Value.absent(),
    Value<String?> penalty = const Value.absent(),
    Value<String?> reason = const Value.absent(),
  }) => ResultsEventRow(
    fileId: fileId ?? this.fileId,
    seq: seq ?? this.seq,
    kind: kind ?? this.kind,
    elapsed: elapsed ?? this.elapsed,
    body: body ?? this.body,
    driverName: driverName.present ? driverName.value : this.driverName,
    slot: slot.present ? slot.value : this.slot,
    lap: lap.present ? lap.value : this.lap,
    resolution: resolution.present ? resolution.value : this.resolution,
    warningPoints: warningPoints.present
        ? warningPoints.value
        : this.warningPoints,
    currentPoints: currentPoints.present
        ? currentPoints.value
        : this.currentPoints,
    penalty: penalty.present ? penalty.value : this.penalty,
    reason: reason.present ? reason.value : this.reason,
  );
  ResultsEventRow copyWithCompanion(ResultsEventsCompanion data) {
    return ResultsEventRow(
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      seq: data.seq.present ? data.seq.value : this.seq,
      kind: data.kind.present ? data.kind.value : this.kind,
      elapsed: data.elapsed.present ? data.elapsed.value : this.elapsed,
      body: data.body.present ? data.body.value : this.body,
      driverName: data.driverName.present
          ? data.driverName.value
          : this.driverName,
      slot: data.slot.present ? data.slot.value : this.slot,
      lap: data.lap.present ? data.lap.value : this.lap,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
      warningPoints: data.warningPoints.present
          ? data.warningPoints.value
          : this.warningPoints,
      currentPoints: data.currentPoints.present
          ? data.currentPoints.value
          : this.currentPoints,
      penalty: data.penalty.present ? data.penalty.value : this.penalty,
      reason: data.reason.present ? data.reason.value : this.reason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResultsEventRow(')
          ..write('fileId: $fileId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('elapsed: $elapsed, ')
          ..write('body: $body, ')
          ..write('driverName: $driverName, ')
          ..write('slot: $slot, ')
          ..write('lap: $lap, ')
          ..write('resolution: $resolution, ')
          ..write('warningPoints: $warningPoints, ')
          ..write('currentPoints: $currentPoints, ')
          ..write('penalty: $penalty, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileId,
    seq,
    kind,
    elapsed,
    body,
    driverName,
    slot,
    lap,
    resolution,
    warningPoints,
    currentPoints,
    penalty,
    reason,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResultsEventRow &&
          other.fileId == this.fileId &&
          other.seq == this.seq &&
          other.kind == this.kind &&
          other.elapsed == this.elapsed &&
          other.body == this.body &&
          other.driverName == this.driverName &&
          other.slot == this.slot &&
          other.lap == this.lap &&
          other.resolution == this.resolution &&
          other.warningPoints == this.warningPoints &&
          other.currentPoints == this.currentPoints &&
          other.penalty == this.penalty &&
          other.reason == this.reason);
}

class ResultsEventsCompanion extends UpdateCompanion<ResultsEventRow> {
  final Value<int> fileId;
  final Value<int> seq;
  final Value<String> kind;
  final Value<double> elapsed;
  final Value<String> body;
  final Value<String?> driverName;
  final Value<int?> slot;
  final Value<int?> lap;
  final Value<int?> resolution;
  final Value<double?> warningPoints;
  final Value<double?> currentPoints;
  final Value<String?> penalty;
  final Value<String?> reason;
  const ResultsEventsCompanion({
    this.fileId = const Value.absent(),
    this.seq = const Value.absent(),
    this.kind = const Value.absent(),
    this.elapsed = const Value.absent(),
    this.body = const Value.absent(),
    this.driverName = const Value.absent(),
    this.slot = const Value.absent(),
    this.lap = const Value.absent(),
    this.resolution = const Value.absent(),
    this.warningPoints = const Value.absent(),
    this.currentPoints = const Value.absent(),
    this.penalty = const Value.absent(),
    this.reason = const Value.absent(),
  });
  ResultsEventsCompanion.insert({
    required int fileId,
    required int seq,
    required String kind,
    required double elapsed,
    required String body,
    this.driverName = const Value.absent(),
    this.slot = const Value.absent(),
    this.lap = const Value.absent(),
    this.resolution = const Value.absent(),
    this.warningPoints = const Value.absent(),
    this.currentPoints = const Value.absent(),
    this.penalty = const Value.absent(),
    this.reason = const Value.absent(),
  }) : fileId = Value(fileId),
       seq = Value(seq),
       kind = Value(kind),
       elapsed = Value(elapsed),
       body = Value(body);
  static Insertable<ResultsEventRow> custom({
    Expression<int>? fileId,
    Expression<int>? seq,
    Expression<String>? kind,
    Expression<double>? elapsed,
    Expression<String>? body,
    Expression<String>? driverName,
    Expression<int>? slot,
    Expression<int>? lap,
    Expression<int>? resolution,
    Expression<double>? warningPoints,
    Expression<double>? currentPoints,
    Expression<String>? penalty,
    Expression<String>? reason,
  }) {
    return RawValuesInsertable({
      if (fileId != null) 'file_id': fileId,
      if (seq != null) 'seq': seq,
      if (kind != null) 'kind': kind,
      if (elapsed != null) 'elapsed': elapsed,
      if (body != null) 'body': body,
      if (driverName != null) 'driver_name': driverName,
      if (slot != null) 'slot': slot,
      if (lap != null) 'lap': lap,
      if (resolution != null) 'resolution': resolution,
      if (warningPoints != null) 'warning_points': warningPoints,
      if (currentPoints != null) 'current_points': currentPoints,
      if (penalty != null) 'penalty': penalty,
      if (reason != null) 'reason': reason,
    });
  }

  ResultsEventsCompanion copyWith({
    Value<int>? fileId,
    Value<int>? seq,
    Value<String>? kind,
    Value<double>? elapsed,
    Value<String>? body,
    Value<String?>? driverName,
    Value<int?>? slot,
    Value<int?>? lap,
    Value<int?>? resolution,
    Value<double?>? warningPoints,
    Value<double?>? currentPoints,
    Value<String?>? penalty,
    Value<String?>? reason,
  }) {
    return ResultsEventsCompanion(
      fileId: fileId ?? this.fileId,
      seq: seq ?? this.seq,
      kind: kind ?? this.kind,
      elapsed: elapsed ?? this.elapsed,
      body: body ?? this.body,
      driverName: driverName ?? this.driverName,
      slot: slot ?? this.slot,
      lap: lap ?? this.lap,
      resolution: resolution ?? this.resolution,
      warningPoints: warningPoints ?? this.warningPoints,
      currentPoints: currentPoints ?? this.currentPoints,
      penalty: penalty ?? this.penalty,
      reason: reason ?? this.reason,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileId.present) {
      map['file_id'] = Variable<int>(fileId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (elapsed.present) {
      map['elapsed'] = Variable<double>(elapsed.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (driverName.present) {
      map['driver_name'] = Variable<String>(driverName.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (lap.present) {
      map['lap'] = Variable<int>(lap.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<int>(resolution.value);
    }
    if (warningPoints.present) {
      map['warning_points'] = Variable<double>(warningPoints.value);
    }
    if (currentPoints.present) {
      map['current_points'] = Variable<double>(currentPoints.value);
    }
    if (penalty.present) {
      map['penalty'] = Variable<String>(penalty.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsEventsCompanion(')
          ..write('fileId: $fileId, ')
          ..write('seq: $seq, ')
          ..write('kind: $kind, ')
          ..write('elapsed: $elapsed, ')
          ..write('body: $body, ')
          ..write('driverName: $driverName, ')
          ..write('slot: $slot, ')
          ..write('lap: $lap, ')
          ..write('resolution: $resolution, ')
          ..write('warningPoints: $warningPoints, ')
          ..write('currentPoints: $currentPoints, ')
          ..write('penalty: $penalty, ')
          ..write('reason: $reason')
          ..write(')'))
        .toString();
  }
}

class $ResultsFoldersTable extends ResultsFolders
    with TableInfo<$ResultsFoldersTable, ResultsFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResultsFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScannedAtMeta = const VerificationMeta(
    'lastScannedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastScannedAt =
      GeneratedColumn<DateTime>(
        'last_scanned_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastScanFileCountMeta = const VerificationMeta(
    'lastScanFileCount',
  );
  @override
  late final GeneratedColumn<int> lastScanFileCount = GeneratedColumn<int>(
    'last_scan_file_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    addedAt,
    lastScannedAt,
    lastScanFileCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'results_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ResultsFolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('last_scanned_at')) {
      context.handle(
        _lastScannedAtMeta,
        lastScannedAt.isAcceptableOrUnknown(
          data['last_scanned_at']!,
          _lastScannedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_scan_file_count')) {
      context.handle(
        _lastScanFileCountMeta,
        lastScanFileCount.isAcceptableOrUnknown(
          data['last_scan_file_count']!,
          _lastScanFileCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  ResultsFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ResultsFolderRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      lastScannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_scanned_at'],
      ),
      lastScanFileCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scan_file_count'],
      ),
    );
  }

  @override
  $ResultsFoldersTable createAlias(String alias) {
    return $ResultsFoldersTable(attachedDatabase, alias);
  }
}

class ResultsFolderRow extends DataClass
    implements Insertable<ResultsFolderRow> {
  final String path;
  final DateTime addedAt;
  final DateTime? lastScannedAt;
  final int? lastScanFileCount;
  const ResultsFolderRow({
    required this.path,
    required this.addedAt,
    this.lastScannedAt,
    this.lastScanFileCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || lastScannedAt != null) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt);
    }
    if (!nullToAbsent || lastScanFileCount != null) {
      map['last_scan_file_count'] = Variable<int>(lastScanFileCount);
    }
    return map;
  }

  ResultsFoldersCompanion toCompanion(bool nullToAbsent) {
    return ResultsFoldersCompanion(
      path: Value(path),
      addedAt: Value(addedAt),
      lastScannedAt: lastScannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScannedAt),
      lastScanFileCount: lastScanFileCount == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScanFileCount),
    );
  }

  factory ResultsFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ResultsFolderRow(
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastScannedAt: serializer.fromJson<DateTime?>(json['lastScannedAt']),
      lastScanFileCount: serializer.fromJson<int?>(json['lastScanFileCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastScannedAt': serializer.toJson<DateTime?>(lastScannedAt),
      'lastScanFileCount': serializer.toJson<int?>(lastScanFileCount),
    };
  }

  ResultsFolderRow copyWith({
    String? path,
    DateTime? addedAt,
    Value<DateTime?> lastScannedAt = const Value.absent(),
    Value<int?> lastScanFileCount = const Value.absent(),
  }) => ResultsFolderRow(
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    lastScannedAt: lastScannedAt.present
        ? lastScannedAt.value
        : this.lastScannedAt,
    lastScanFileCount: lastScanFileCount.present
        ? lastScanFileCount.value
        : this.lastScanFileCount,
  );
  ResultsFolderRow copyWithCompanion(ResultsFoldersCompanion data) {
    return ResultsFolderRow(
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastScannedAt: data.lastScannedAt.present
          ? data.lastScannedAt.value
          : this.lastScannedAt,
      lastScanFileCount: data.lastScanFileCount.present
          ? data.lastScanFileCount.value
          : this.lastScanFileCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ResultsFolderRow(')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('lastScanFileCount: $lastScanFileCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(path, addedAt, lastScannedAt, lastScanFileCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ResultsFolderRow &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.lastScannedAt == this.lastScannedAt &&
          other.lastScanFileCount == this.lastScanFileCount);
}

class ResultsFoldersCompanion extends UpdateCompanion<ResultsFolderRow> {
  final Value<String> path;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastScannedAt;
  final Value<int?> lastScanFileCount;
  final Value<int> rowid;
  const ResultsFoldersCompanion({
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
    this.lastScanFileCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ResultsFoldersCompanion.insert({
    required String path,
    required DateTime addedAt,
    this.lastScannedAt = const Value.absent(),
    this.lastScanFileCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       addedAt = Value(addedAt);
  static Insertable<ResultsFolderRow> custom({
    Expression<String>? path,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? lastScannedAt,
    Expression<int>? lastScanFileCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (lastScannedAt != null) 'last_scanned_at': lastScannedAt,
      if (lastScanFileCount != null) 'last_scan_file_count': lastScanFileCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ResultsFoldersCompanion copyWith({
    Value<String>? path,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastScannedAt,
    Value<int?>? lastScanFileCount,
    Value<int>? rowid,
  }) {
    return ResultsFoldersCompanion(
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      lastScanFileCount: lastScanFileCount ?? this.lastScanFileCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (lastScannedAt.present) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt.value);
    }
    if (lastScanFileCount.present) {
      map['last_scan_file_count'] = Variable<int>(lastScanFileCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResultsFoldersCompanion(')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('lastScanFileCount: $lastScanFileCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ResultsDatabase extends GeneratedDatabase {
  _$ResultsDatabase(QueryExecutor e) : super(e);
  $ResultsDatabaseManager get managers => $ResultsDatabaseManager(this);
  late final $ResultsFilesTable resultsFiles = $ResultsFilesTable(this);
  late final $ResultsDriversTable resultsDrivers = $ResultsDriversTable(this);
  late final $ResultsLapsTable resultsLaps = $ResultsLapsTable(this);
  late final $ResultsEventsTable resultsEvents = $ResultsEventsTable(this);
  late final $ResultsFoldersTable resultsFolders = $ResultsFoldersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    resultsFiles,
    resultsDrivers,
    resultsLaps,
    resultsEvents,
    resultsFolders,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$ResultsFilesTableCreateCompanionBuilder =
    ResultsFilesCompanion Function({
      Value<int> id,
      required String path,
      required int sizeBytes,
      required int modifiedMs,
      required DateTime indexedAt,
      required String sessionElement,
      required String kind,
      required int startedAtMs,
      required int endsAtMs,
      required int weekendStartedAtMs,
      required String setting,
      required String serverName,
      required String trackVenue,
      required String trackCourse,
      required String trackEvent,
      Value<double?> trackLengthMetres,
      required String gameVersion,
      Value<int?> raceLaps,
      Value<int?> raceMinutes,
      Value<double?> fuelMultiplier,
      Value<double?> tyreMultiplier,
      Value<double?> damagePercent,
    });
typedef $$ResultsFilesTableUpdateCompanionBuilder =
    ResultsFilesCompanion Function({
      Value<int> id,
      Value<String> path,
      Value<int> sizeBytes,
      Value<int> modifiedMs,
      Value<DateTime> indexedAt,
      Value<String> sessionElement,
      Value<String> kind,
      Value<int> startedAtMs,
      Value<int> endsAtMs,
      Value<int> weekendStartedAtMs,
      Value<String> setting,
      Value<String> serverName,
      Value<String> trackVenue,
      Value<String> trackCourse,
      Value<String> trackEvent,
      Value<double?> trackLengthMetres,
      Value<String> gameVersion,
      Value<int?> raceLaps,
      Value<int?> raceMinutes,
      Value<double?> fuelMultiplier,
      Value<double?> tyreMultiplier,
      Value<double?> damagePercent,
    });

class $$ResultsFilesTableFilterComposer
    extends Composer<_$ResultsDatabase, $ResultsFilesTable> {
  $$ResultsFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionElement => $composableBuilder(
    column: $table.sessionElement,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endsAtMs => $composableBuilder(
    column: $table.endsAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weekendStartedAtMs => $composableBuilder(
    column: $table.weekendStartedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setting => $composableBuilder(
    column: $table.setting,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackVenue => $composableBuilder(
    column: $table.trackVenue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackCourse => $composableBuilder(
    column: $table.trackCourse,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackEvent => $composableBuilder(
    column: $table.trackEvent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get trackLengthMetres => $composableBuilder(
    column: $table.trackLengthMetres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gameVersion => $composableBuilder(
    column: $table.gameVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get raceLaps => $composableBuilder(
    column: $table.raceLaps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get raceMinutes => $composableBuilder(
    column: $table.raceMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelMultiplier => $composableBuilder(
    column: $table.fuelMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tyreMultiplier => $composableBuilder(
    column: $table.tyreMultiplier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get damagePercent => $composableBuilder(
    column: $table.damagePercent,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsFilesTableOrderingComposer
    extends Composer<_$ResultsDatabase, $ResultsFilesTable> {
  $$ResultsFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get indexedAt => $composableBuilder(
    column: $table.indexedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionElement => $composableBuilder(
    column: $table.sessionElement,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endsAtMs => $composableBuilder(
    column: $table.endsAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weekendStartedAtMs => $composableBuilder(
    column: $table.weekendStartedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setting => $composableBuilder(
    column: $table.setting,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackVenue => $composableBuilder(
    column: $table.trackVenue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackCourse => $composableBuilder(
    column: $table.trackCourse,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackEvent => $composableBuilder(
    column: $table.trackEvent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get trackLengthMetres => $composableBuilder(
    column: $table.trackLengthMetres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gameVersion => $composableBuilder(
    column: $table.gameVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get raceLaps => $composableBuilder(
    column: $table.raceLaps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get raceMinutes => $composableBuilder(
    column: $table.raceMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelMultiplier => $composableBuilder(
    column: $table.fuelMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tyreMultiplier => $composableBuilder(
    column: $table.tyreMultiplier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get damagePercent => $composableBuilder(
    column: $table.damagePercent,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsFilesTableAnnotationComposer
    extends Composer<_$ResultsDatabase, $ResultsFilesTable> {
  $$ResultsFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  GeneratedColumn<String> get sessionElement => $composableBuilder(
    column: $table.sessionElement,
    builder: (column) => column,
  );

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
    column: $table.startedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endsAtMs =>
      $composableBuilder(column: $table.endsAtMs, builder: (column) => column);

  GeneratedColumn<int> get weekendStartedAtMs => $composableBuilder(
    column: $table.weekendStartedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get setting =>
      $composableBuilder(column: $table.setting, builder: (column) => column);

  GeneratedColumn<String> get serverName => $composableBuilder(
    column: $table.serverName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackVenue => $composableBuilder(
    column: $table.trackVenue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackCourse => $composableBuilder(
    column: $table.trackCourse,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackEvent => $composableBuilder(
    column: $table.trackEvent,
    builder: (column) => column,
  );

  GeneratedColumn<double> get trackLengthMetres => $composableBuilder(
    column: $table.trackLengthMetres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get gameVersion => $composableBuilder(
    column: $table.gameVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get raceLaps =>
      $composableBuilder(column: $table.raceLaps, builder: (column) => column);

  GeneratedColumn<int> get raceMinutes => $composableBuilder(
    column: $table.raceMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fuelMultiplier => $composableBuilder(
    column: $table.fuelMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tyreMultiplier => $composableBuilder(
    column: $table.tyreMultiplier,
    builder: (column) => column,
  );

  GeneratedColumn<double> get damagePercent => $composableBuilder(
    column: $table.damagePercent,
    builder: (column) => column,
  );
}

class $$ResultsFilesTableTableManager
    extends
        RootTableManager<
          _$ResultsDatabase,
          $ResultsFilesTable,
          ResultsFileRow,
          $$ResultsFilesTableFilterComposer,
          $$ResultsFilesTableOrderingComposer,
          $$ResultsFilesTableAnnotationComposer,
          $$ResultsFilesTableCreateCompanionBuilder,
          $$ResultsFilesTableUpdateCompanionBuilder,
          (
            ResultsFileRow,
            BaseReferences<
              _$ResultsDatabase,
              $ResultsFilesTable,
              ResultsFileRow
            >,
          ),
          ResultsFileRow,
          PrefetchHooks Function()
        > {
  $$ResultsFilesTableTableManager(
    _$ResultsDatabase db,
    $ResultsFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> modifiedMs = const Value.absent(),
                Value<DateTime> indexedAt = const Value.absent(),
                Value<String> sessionElement = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> startedAtMs = const Value.absent(),
                Value<int> endsAtMs = const Value.absent(),
                Value<int> weekendStartedAtMs = const Value.absent(),
                Value<String> setting = const Value.absent(),
                Value<String> serverName = const Value.absent(),
                Value<String> trackVenue = const Value.absent(),
                Value<String> trackCourse = const Value.absent(),
                Value<String> trackEvent = const Value.absent(),
                Value<double?> trackLengthMetres = const Value.absent(),
                Value<String> gameVersion = const Value.absent(),
                Value<int?> raceLaps = const Value.absent(),
                Value<int?> raceMinutes = const Value.absent(),
                Value<double?> fuelMultiplier = const Value.absent(),
                Value<double?> tyreMultiplier = const Value.absent(),
                Value<double?> damagePercent = const Value.absent(),
              }) => ResultsFilesCompanion(
                id: id,
                path: path,
                sizeBytes: sizeBytes,
                modifiedMs: modifiedMs,
                indexedAt: indexedAt,
                sessionElement: sessionElement,
                kind: kind,
                startedAtMs: startedAtMs,
                endsAtMs: endsAtMs,
                weekendStartedAtMs: weekendStartedAtMs,
                setting: setting,
                serverName: serverName,
                trackVenue: trackVenue,
                trackCourse: trackCourse,
                trackEvent: trackEvent,
                trackLengthMetres: trackLengthMetres,
                gameVersion: gameVersion,
                raceLaps: raceLaps,
                raceMinutes: raceMinutes,
                fuelMultiplier: fuelMultiplier,
                tyreMultiplier: tyreMultiplier,
                damagePercent: damagePercent,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int sizeBytes,
                required int modifiedMs,
                required DateTime indexedAt,
                required String sessionElement,
                required String kind,
                required int startedAtMs,
                required int endsAtMs,
                required int weekendStartedAtMs,
                required String setting,
                required String serverName,
                required String trackVenue,
                required String trackCourse,
                required String trackEvent,
                Value<double?> trackLengthMetres = const Value.absent(),
                required String gameVersion,
                Value<int?> raceLaps = const Value.absent(),
                Value<int?> raceMinutes = const Value.absent(),
                Value<double?> fuelMultiplier = const Value.absent(),
                Value<double?> tyreMultiplier = const Value.absent(),
                Value<double?> damagePercent = const Value.absent(),
              }) => ResultsFilesCompanion.insert(
                id: id,
                path: path,
                sizeBytes: sizeBytes,
                modifiedMs: modifiedMs,
                indexedAt: indexedAt,
                sessionElement: sessionElement,
                kind: kind,
                startedAtMs: startedAtMs,
                endsAtMs: endsAtMs,
                weekendStartedAtMs: weekendStartedAtMs,
                setting: setting,
                serverName: serverName,
                trackVenue: trackVenue,
                trackCourse: trackCourse,
                trackEvent: trackEvent,
                trackLengthMetres: trackLengthMetres,
                gameVersion: gameVersion,
                raceLaps: raceLaps,
                raceMinutes: raceMinutes,
                fuelMultiplier: fuelMultiplier,
                tyreMultiplier: tyreMultiplier,
                damagePercent: damagePercent,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResultsFilesTable, ResultsFileRow>(table),
                  BaseReferences<
                    _$ResultsDatabase,
                    $ResultsFilesTable,
                    ResultsFileRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$ResultsDatabase,
      $ResultsFilesTable,
      ResultsFileRow,
      $$ResultsFilesTableFilterComposer,
      $$ResultsFilesTableOrderingComposer,
      $$ResultsFilesTableAnnotationComposer,
      $$ResultsFilesTableCreateCompanionBuilder,
      $$ResultsFilesTableUpdateCompanionBuilder,
      (
        ResultsFileRow,
        BaseReferences<_$ResultsDatabase, $ResultsFilesTable, ResultsFileRow>,
      ),
      ResultsFileRow,
      PrefetchHooks Function()
    >;
typedef $$ResultsDriversTableCreateCompanionBuilder =
    ResultsDriversCompanion Function({
      required int fileId,
      required int driverIndex,
      required String name,
      required bool isPlayer,
      required String vehicleFile,
      required String vehicleName,
      required String carType,
      required String carClass,
      required String category,
      required String teamName,
      required String carNumber,
      Value<int?> gridPosition,
      Value<int?> classGridPosition,
      Value<int?> position,
      Value<int?> classPosition,
      Value<double?> bestLapSeconds,
      Value<double?> finishElapsed,
      required int lapsCompleted,
      required int pitStops,
      required String finishStatus,
      Value<String?> dnfReason,
      required String swaps,
      required String aids,
    });
typedef $$ResultsDriversTableUpdateCompanionBuilder =
    ResultsDriversCompanion Function({
      Value<int> fileId,
      Value<int> driverIndex,
      Value<String> name,
      Value<bool> isPlayer,
      Value<String> vehicleFile,
      Value<String> vehicleName,
      Value<String> carType,
      Value<String> carClass,
      Value<String> category,
      Value<String> teamName,
      Value<String> carNumber,
      Value<int?> gridPosition,
      Value<int?> classGridPosition,
      Value<int?> position,
      Value<int?> classPosition,
      Value<double?> bestLapSeconds,
      Value<double?> finishElapsed,
      Value<int> lapsCompleted,
      Value<int> pitStops,
      Value<String> finishStatus,
      Value<String?> dnfReason,
      Value<String> swaps,
      Value<String> aids,
    });

class $$ResultsDriversTableFilterComposer
    extends Composer<_$ResultsDatabase, $ResultsDriversTable> {
  $$ResultsDriversTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlayer => $composableBuilder(
    column: $table.isPlayer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleFile => $composableBuilder(
    column: $table.vehicleFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehicleName => $composableBuilder(
    column: $table.vehicleName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carType => $composableBuilder(
    column: $table.carType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carClass => $composableBuilder(
    column: $table.carClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teamName => $composableBuilder(
    column: $table.teamName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carNumber => $composableBuilder(
    column: $table.carNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridPosition => $composableBuilder(
    column: $table.gridPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get classGridPosition => $composableBuilder(
    column: $table.classGridPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get classPosition => $composableBuilder(
    column: $table.classPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get finishElapsed => $composableBuilder(
    column: $table.finishElapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapsCompleted => $composableBuilder(
    column: $table.lapsCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pitStops => $composableBuilder(
    column: $table.pitStops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get finishStatus => $composableBuilder(
    column: $table.finishStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dnfReason => $composableBuilder(
    column: $table.dnfReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get swaps => $composableBuilder(
    column: $table.swaps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aids => $composableBuilder(
    column: $table.aids,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsDriversTableOrderingComposer
    extends Composer<_$ResultsDatabase, $ResultsDriversTable> {
  $$ResultsDriversTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlayer => $composableBuilder(
    column: $table.isPlayer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleFile => $composableBuilder(
    column: $table.vehicleFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehicleName => $composableBuilder(
    column: $table.vehicleName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carType => $composableBuilder(
    column: $table.carType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carClass => $composableBuilder(
    column: $table.carClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teamName => $composableBuilder(
    column: $table.teamName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carNumber => $composableBuilder(
    column: $table.carNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridPosition => $composableBuilder(
    column: $table.gridPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get classGridPosition => $composableBuilder(
    column: $table.classGridPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get classPosition => $composableBuilder(
    column: $table.classPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get finishElapsed => $composableBuilder(
    column: $table.finishElapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapsCompleted => $composableBuilder(
    column: $table.lapsCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pitStops => $composableBuilder(
    column: $table.pitStops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get finishStatus => $composableBuilder(
    column: $table.finishStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dnfReason => $composableBuilder(
    column: $table.dnfReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get swaps => $composableBuilder(
    column: $table.swaps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aids => $composableBuilder(
    column: $table.aids,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsDriversTableAnnotationComposer
    extends Composer<_$ResultsDatabase, $ResultsDriversTable> {
  $$ResultsDriversTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isPlayer =>
      $composableBuilder(column: $table.isPlayer, builder: (column) => column);

  GeneratedColumn<String> get vehicleFile => $composableBuilder(
    column: $table.vehicleFile,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vehicleName => $composableBuilder(
    column: $table.vehicleName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carType =>
      $composableBuilder(column: $table.carType, builder: (column) => column);

  GeneratedColumn<String> get carClass =>
      $composableBuilder(column: $table.carClass, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get teamName =>
      $composableBuilder(column: $table.teamName, builder: (column) => column);

  GeneratedColumn<String> get carNumber =>
      $composableBuilder(column: $table.carNumber, builder: (column) => column);

  GeneratedColumn<int> get gridPosition => $composableBuilder(
    column: $table.gridPosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get classGridPosition => $composableBuilder(
    column: $table.classGridPosition,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get classPosition => $composableBuilder(
    column: $table.classPosition,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get finishElapsed => $composableBuilder(
    column: $table.finishElapsed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapsCompleted => $composableBuilder(
    column: $table.lapsCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pitStops =>
      $composableBuilder(column: $table.pitStops, builder: (column) => column);

  GeneratedColumn<String> get finishStatus => $composableBuilder(
    column: $table.finishStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dnfReason =>
      $composableBuilder(column: $table.dnfReason, builder: (column) => column);

  GeneratedColumn<String> get swaps =>
      $composableBuilder(column: $table.swaps, builder: (column) => column);

  GeneratedColumn<String> get aids =>
      $composableBuilder(column: $table.aids, builder: (column) => column);
}

class $$ResultsDriversTableTableManager
    extends
        RootTableManager<
          _$ResultsDatabase,
          $ResultsDriversTable,
          ResultsDriverRow,
          $$ResultsDriversTableFilterComposer,
          $$ResultsDriversTableOrderingComposer,
          $$ResultsDriversTableAnnotationComposer,
          $$ResultsDriversTableCreateCompanionBuilder,
          $$ResultsDriversTableUpdateCompanionBuilder,
          (
            ResultsDriverRow,
            BaseReferences<
              _$ResultsDatabase,
              $ResultsDriversTable,
              ResultsDriverRow
            >,
          ),
          ResultsDriverRow,
          PrefetchHooks Function()
        > {
  $$ResultsDriversTableTableManager(
    _$ResultsDatabase db,
    $ResultsDriversTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsDriversTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsDriversTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsDriversTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> fileId = const Value.absent(),
                Value<int> driverIndex = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isPlayer = const Value.absent(),
                Value<String> vehicleFile = const Value.absent(),
                Value<String> vehicleName = const Value.absent(),
                Value<String> carType = const Value.absent(),
                Value<String> carClass = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> teamName = const Value.absent(),
                Value<String> carNumber = const Value.absent(),
                Value<int?> gridPosition = const Value.absent(),
                Value<int?> classGridPosition = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<int?> classPosition = const Value.absent(),
                Value<double?> bestLapSeconds = const Value.absent(),
                Value<double?> finishElapsed = const Value.absent(),
                Value<int> lapsCompleted = const Value.absent(),
                Value<int> pitStops = const Value.absent(),
                Value<String> finishStatus = const Value.absent(),
                Value<String?> dnfReason = const Value.absent(),
                Value<String> swaps = const Value.absent(),
                Value<String> aids = const Value.absent(),
              }) => ResultsDriversCompanion(
                fileId: fileId,
                driverIndex: driverIndex,
                name: name,
                isPlayer: isPlayer,
                vehicleFile: vehicleFile,
                vehicleName: vehicleName,
                carType: carType,
                carClass: carClass,
                category: category,
                teamName: teamName,
                carNumber: carNumber,
                gridPosition: gridPosition,
                classGridPosition: classGridPosition,
                position: position,
                classPosition: classPosition,
                bestLapSeconds: bestLapSeconds,
                finishElapsed: finishElapsed,
                lapsCompleted: lapsCompleted,
                pitStops: pitStops,
                finishStatus: finishStatus,
                dnfReason: dnfReason,
                swaps: swaps,
                aids: aids,
              ),
          createCompanionCallback:
              ({
                required int fileId,
                required int driverIndex,
                required String name,
                required bool isPlayer,
                required String vehicleFile,
                required String vehicleName,
                required String carType,
                required String carClass,
                required String category,
                required String teamName,
                required String carNumber,
                Value<int?> gridPosition = const Value.absent(),
                Value<int?> classGridPosition = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<int?> classPosition = const Value.absent(),
                Value<double?> bestLapSeconds = const Value.absent(),
                Value<double?> finishElapsed = const Value.absent(),
                required int lapsCompleted,
                required int pitStops,
                required String finishStatus,
                Value<String?> dnfReason = const Value.absent(),
                required String swaps,
                required String aids,
              }) => ResultsDriversCompanion.insert(
                fileId: fileId,
                driverIndex: driverIndex,
                name: name,
                isPlayer: isPlayer,
                vehicleFile: vehicleFile,
                vehicleName: vehicleName,
                carType: carType,
                carClass: carClass,
                category: category,
                teamName: teamName,
                carNumber: carNumber,
                gridPosition: gridPosition,
                classGridPosition: classGridPosition,
                position: position,
                classPosition: classPosition,
                bestLapSeconds: bestLapSeconds,
                finishElapsed: finishElapsed,
                lapsCompleted: lapsCompleted,
                pitStops: pitStops,
                finishStatus: finishStatus,
                dnfReason: dnfReason,
                swaps: swaps,
                aids: aids,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResultsDriversTable, ResultsDriverRow>(table),
                  BaseReferences<
                    _$ResultsDatabase,
                    $ResultsDriversTable,
                    ResultsDriverRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsDriversTableProcessedTableManager =
    ProcessedTableManager<
      _$ResultsDatabase,
      $ResultsDriversTable,
      ResultsDriverRow,
      $$ResultsDriversTableFilterComposer,
      $$ResultsDriversTableOrderingComposer,
      $$ResultsDriversTableAnnotationComposer,
      $$ResultsDriversTableCreateCompanionBuilder,
      $$ResultsDriversTableUpdateCompanionBuilder,
      (
        ResultsDriverRow,
        BaseReferences<
          _$ResultsDatabase,
          $ResultsDriversTable,
          ResultsDriverRow
        >,
      ),
      ResultsDriverRow,
      PrefetchHooks Function()
    >;
typedef $$ResultsLapsTableCreateCompanionBuilder =
    ResultsLapsCompanion Function({
      required int fileId,
      required int driverIndex,
      required int seq,
      required int number,
      Value<int?> position,
      Value<double?> startElapsed,
      Value<double?> lapSeconds,
      Value<double?> sector1Seconds,
      Value<double?> sector2Seconds,
      Value<double?> sector3Seconds,
      Value<double?> topSpeedKmh,
      Value<double?> fuelFraction,
      Value<double?> fuelUsedFraction,
      Value<double?> energyFraction,
      Value<double?> energyUsedFraction,
      Value<double?> wearFrontLeft,
      Value<double?> wearFrontRight,
      Value<double?> wearRearLeft,
      Value<double?> wearRearRight,
      Value<String?> compoundFront,
      Value<String?> compoundRear,
      required bool pit,
    });
typedef $$ResultsLapsTableUpdateCompanionBuilder =
    ResultsLapsCompanion Function({
      Value<int> fileId,
      Value<int> driverIndex,
      Value<int> seq,
      Value<int> number,
      Value<int?> position,
      Value<double?> startElapsed,
      Value<double?> lapSeconds,
      Value<double?> sector1Seconds,
      Value<double?> sector2Seconds,
      Value<double?> sector3Seconds,
      Value<double?> topSpeedKmh,
      Value<double?> fuelFraction,
      Value<double?> fuelUsedFraction,
      Value<double?> energyFraction,
      Value<double?> energyUsedFraction,
      Value<double?> wearFrontLeft,
      Value<double?> wearFrontRight,
      Value<double?> wearRearLeft,
      Value<double?> wearRearRight,
      Value<String?> compoundFront,
      Value<String?> compoundRear,
      Value<bool> pit,
    });

class $$ResultsLapsTableFilterComposer
    extends Composer<_$ResultsDatabase, $ResultsLapsTable> {
  $$ResultsLapsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startElapsed => $composableBuilder(
    column: $table.startElapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lapSeconds => $composableBuilder(
    column: $table.lapSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sector1Seconds => $composableBuilder(
    column: $table.sector1Seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sector2Seconds => $composableBuilder(
    column: $table.sector2Seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sector3Seconds => $composableBuilder(
    column: $table.sector3Seconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get topSpeedKmh => $composableBuilder(
    column: $table.topSpeedKmh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelFraction => $composableBuilder(
    column: $table.fuelFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fuelUsedFraction => $composableBuilder(
    column: $table.fuelUsedFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyFraction => $composableBuilder(
    column: $table.energyFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get energyUsedFraction => $composableBuilder(
    column: $table.energyUsedFraction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wearFrontLeft => $composableBuilder(
    column: $table.wearFrontLeft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wearFrontRight => $composableBuilder(
    column: $table.wearFrontRight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wearRearLeft => $composableBuilder(
    column: $table.wearRearLeft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wearRearRight => $composableBuilder(
    column: $table.wearRearRight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compoundFront => $composableBuilder(
    column: $table.compoundFront,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get compoundRear => $composableBuilder(
    column: $table.compoundRear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pit => $composableBuilder(
    column: $table.pit,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsLapsTableOrderingComposer
    extends Composer<_$ResultsDatabase, $ResultsLapsTable> {
  $$ResultsLapsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startElapsed => $composableBuilder(
    column: $table.startElapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lapSeconds => $composableBuilder(
    column: $table.lapSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sector1Seconds => $composableBuilder(
    column: $table.sector1Seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sector2Seconds => $composableBuilder(
    column: $table.sector2Seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sector3Seconds => $composableBuilder(
    column: $table.sector3Seconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get topSpeedKmh => $composableBuilder(
    column: $table.topSpeedKmh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelFraction => $composableBuilder(
    column: $table.fuelFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fuelUsedFraction => $composableBuilder(
    column: $table.fuelUsedFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyFraction => $composableBuilder(
    column: $table.energyFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get energyUsedFraction => $composableBuilder(
    column: $table.energyUsedFraction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wearFrontLeft => $composableBuilder(
    column: $table.wearFrontLeft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wearFrontRight => $composableBuilder(
    column: $table.wearFrontRight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wearRearLeft => $composableBuilder(
    column: $table.wearRearLeft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wearRearRight => $composableBuilder(
    column: $table.wearRearRight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compoundFront => $composableBuilder(
    column: $table.compoundFront,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get compoundRear => $composableBuilder(
    column: $table.compoundRear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pit => $composableBuilder(
    column: $table.pit,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsLapsTableAnnotationComposer
    extends Composer<_$ResultsDatabase, $ResultsLapsTable> {
  $$ResultsLapsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get driverIndex => $composableBuilder(
    column: $table.driverIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<double> get startElapsed => $composableBuilder(
    column: $table.startElapsed,
    builder: (column) => column,
  );

  GeneratedColumn<double> get lapSeconds => $composableBuilder(
    column: $table.lapSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sector1Seconds => $composableBuilder(
    column: $table.sector1Seconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sector2Seconds => $composableBuilder(
    column: $table.sector2Seconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sector3Seconds => $composableBuilder(
    column: $table.sector3Seconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get topSpeedKmh => $composableBuilder(
    column: $table.topSpeedKmh,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fuelFraction => $composableBuilder(
    column: $table.fuelFraction,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fuelUsedFraction => $composableBuilder(
    column: $table.fuelUsedFraction,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyFraction => $composableBuilder(
    column: $table.energyFraction,
    builder: (column) => column,
  );

  GeneratedColumn<double> get energyUsedFraction => $composableBuilder(
    column: $table.energyUsedFraction,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wearFrontLeft => $composableBuilder(
    column: $table.wearFrontLeft,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wearFrontRight => $composableBuilder(
    column: $table.wearFrontRight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wearRearLeft => $composableBuilder(
    column: $table.wearRearLeft,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wearRearRight => $composableBuilder(
    column: $table.wearRearRight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compoundFront => $composableBuilder(
    column: $table.compoundFront,
    builder: (column) => column,
  );

  GeneratedColumn<String> get compoundRear => $composableBuilder(
    column: $table.compoundRear,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pit =>
      $composableBuilder(column: $table.pit, builder: (column) => column);
}

class $$ResultsLapsTableTableManager
    extends
        RootTableManager<
          _$ResultsDatabase,
          $ResultsLapsTable,
          ResultsLapRow,
          $$ResultsLapsTableFilterComposer,
          $$ResultsLapsTableOrderingComposer,
          $$ResultsLapsTableAnnotationComposer,
          $$ResultsLapsTableCreateCompanionBuilder,
          $$ResultsLapsTableUpdateCompanionBuilder,
          (
            ResultsLapRow,
            BaseReferences<_$ResultsDatabase, $ResultsLapsTable, ResultsLapRow>,
          ),
          ResultsLapRow,
          PrefetchHooks Function()
        > {
  $$ResultsLapsTableTableManager(_$ResultsDatabase db, $ResultsLapsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsLapsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsLapsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsLapsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> fileId = const Value.absent(),
                Value<int> driverIndex = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<int?> position = const Value.absent(),
                Value<double?> startElapsed = const Value.absent(),
                Value<double?> lapSeconds = const Value.absent(),
                Value<double?> sector1Seconds = const Value.absent(),
                Value<double?> sector2Seconds = const Value.absent(),
                Value<double?> sector3Seconds = const Value.absent(),
                Value<double?> topSpeedKmh = const Value.absent(),
                Value<double?> fuelFraction = const Value.absent(),
                Value<double?> fuelUsedFraction = const Value.absent(),
                Value<double?> energyFraction = const Value.absent(),
                Value<double?> energyUsedFraction = const Value.absent(),
                Value<double?> wearFrontLeft = const Value.absent(),
                Value<double?> wearFrontRight = const Value.absent(),
                Value<double?> wearRearLeft = const Value.absent(),
                Value<double?> wearRearRight = const Value.absent(),
                Value<String?> compoundFront = const Value.absent(),
                Value<String?> compoundRear = const Value.absent(),
                Value<bool> pit = const Value.absent(),
              }) => ResultsLapsCompanion(
                fileId: fileId,
                driverIndex: driverIndex,
                seq: seq,
                number: number,
                position: position,
                startElapsed: startElapsed,
                lapSeconds: lapSeconds,
                sector1Seconds: sector1Seconds,
                sector2Seconds: sector2Seconds,
                sector3Seconds: sector3Seconds,
                topSpeedKmh: topSpeedKmh,
                fuelFraction: fuelFraction,
                fuelUsedFraction: fuelUsedFraction,
                energyFraction: energyFraction,
                energyUsedFraction: energyUsedFraction,
                wearFrontLeft: wearFrontLeft,
                wearFrontRight: wearFrontRight,
                wearRearLeft: wearRearLeft,
                wearRearRight: wearRearRight,
                compoundFront: compoundFront,
                compoundRear: compoundRear,
                pit: pit,
              ),
          createCompanionCallback:
              ({
                required int fileId,
                required int driverIndex,
                required int seq,
                required int number,
                Value<int?> position = const Value.absent(),
                Value<double?> startElapsed = const Value.absent(),
                Value<double?> lapSeconds = const Value.absent(),
                Value<double?> sector1Seconds = const Value.absent(),
                Value<double?> sector2Seconds = const Value.absent(),
                Value<double?> sector3Seconds = const Value.absent(),
                Value<double?> topSpeedKmh = const Value.absent(),
                Value<double?> fuelFraction = const Value.absent(),
                Value<double?> fuelUsedFraction = const Value.absent(),
                Value<double?> energyFraction = const Value.absent(),
                Value<double?> energyUsedFraction = const Value.absent(),
                Value<double?> wearFrontLeft = const Value.absent(),
                Value<double?> wearFrontRight = const Value.absent(),
                Value<double?> wearRearLeft = const Value.absent(),
                Value<double?> wearRearRight = const Value.absent(),
                Value<String?> compoundFront = const Value.absent(),
                Value<String?> compoundRear = const Value.absent(),
                required bool pit,
              }) => ResultsLapsCompanion.insert(
                fileId: fileId,
                driverIndex: driverIndex,
                seq: seq,
                number: number,
                position: position,
                startElapsed: startElapsed,
                lapSeconds: lapSeconds,
                sector1Seconds: sector1Seconds,
                sector2Seconds: sector2Seconds,
                sector3Seconds: sector3Seconds,
                topSpeedKmh: topSpeedKmh,
                fuelFraction: fuelFraction,
                fuelUsedFraction: fuelUsedFraction,
                energyFraction: energyFraction,
                energyUsedFraction: energyUsedFraction,
                wearFrontLeft: wearFrontLeft,
                wearFrontRight: wearFrontRight,
                wearRearLeft: wearRearLeft,
                wearRearRight: wearRearRight,
                compoundFront: compoundFront,
                compoundRear: compoundRear,
                pit: pit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResultsLapsTable, ResultsLapRow>(table),
                  BaseReferences<
                    _$ResultsDatabase,
                    $ResultsLapsTable,
                    ResultsLapRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsLapsTableProcessedTableManager =
    ProcessedTableManager<
      _$ResultsDatabase,
      $ResultsLapsTable,
      ResultsLapRow,
      $$ResultsLapsTableFilterComposer,
      $$ResultsLapsTableOrderingComposer,
      $$ResultsLapsTableAnnotationComposer,
      $$ResultsLapsTableCreateCompanionBuilder,
      $$ResultsLapsTableUpdateCompanionBuilder,
      (
        ResultsLapRow,
        BaseReferences<_$ResultsDatabase, $ResultsLapsTable, ResultsLapRow>,
      ),
      ResultsLapRow,
      PrefetchHooks Function()
    >;
typedef $$ResultsEventsTableCreateCompanionBuilder =
    ResultsEventsCompanion Function({
      required int fileId,
      required int seq,
      required String kind,
      required double elapsed,
      required String body,
      Value<String?> driverName,
      Value<int?> slot,
      Value<int?> lap,
      Value<int?> resolution,
      Value<double?> warningPoints,
      Value<double?> currentPoints,
      Value<String?> penalty,
      Value<String?> reason,
    });
typedef $$ResultsEventsTableUpdateCompanionBuilder =
    ResultsEventsCompanion Function({
      Value<int> fileId,
      Value<int> seq,
      Value<String> kind,
      Value<double> elapsed,
      Value<String> body,
      Value<String?> driverName,
      Value<int?> slot,
      Value<int?> lap,
      Value<int?> resolution,
      Value<double?> warningPoints,
      Value<double?> currentPoints,
      Value<String?> penalty,
      Value<String?> reason,
    });

class $$ResultsEventsTableFilterComposer
    extends Composer<_$ResultsDatabase, $ResultsEventsTable> {
  $$ResultsEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get elapsed => $composableBuilder(
    column: $table.elapsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lap => $composableBuilder(
    column: $table.lap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get warningPoints => $composableBuilder(
    column: $table.warningPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentPoints => $composableBuilder(
    column: $table.currentPoints,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get penalty => $composableBuilder(
    column: $table.penalty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsEventsTableOrderingComposer
    extends Composer<_$ResultsDatabase, $ResultsEventsTable> {
  $$ResultsEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get elapsed => $composableBuilder(
    column: $table.elapsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lap => $composableBuilder(
    column: $table.lap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get warningPoints => $composableBuilder(
    column: $table.warningPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentPoints => $composableBuilder(
    column: $table.currentPoints,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get penalty => $composableBuilder(
    column: $table.penalty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsEventsTableAnnotationComposer
    extends Composer<_$ResultsDatabase, $ResultsEventsTable> {
  $$ResultsEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<double> get elapsed =>
      $composableBuilder(column: $table.elapsed, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get lap =>
      $composableBuilder(column: $table.lap, builder: (column) => column);

  GeneratedColumn<int> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  GeneratedColumn<double> get warningPoints => $composableBuilder(
    column: $table.warningPoints,
    builder: (column) => column,
  );

  GeneratedColumn<double> get currentPoints => $composableBuilder(
    column: $table.currentPoints,
    builder: (column) => column,
  );

  GeneratedColumn<String> get penalty =>
      $composableBuilder(column: $table.penalty, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);
}

class $$ResultsEventsTableTableManager
    extends
        RootTableManager<
          _$ResultsDatabase,
          $ResultsEventsTable,
          ResultsEventRow,
          $$ResultsEventsTableFilterComposer,
          $$ResultsEventsTableOrderingComposer,
          $$ResultsEventsTableAnnotationComposer,
          $$ResultsEventsTableCreateCompanionBuilder,
          $$ResultsEventsTableUpdateCompanionBuilder,
          (
            ResultsEventRow,
            BaseReferences<
              _$ResultsDatabase,
              $ResultsEventsTable,
              ResultsEventRow
            >,
          ),
          ResultsEventRow,
          PrefetchHooks Function()
        > {
  $$ResultsEventsTableTableManager(
    _$ResultsDatabase db,
    $ResultsEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> fileId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<double> elapsed = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> driverName = const Value.absent(),
                Value<int?> slot = const Value.absent(),
                Value<int?> lap = const Value.absent(),
                Value<int?> resolution = const Value.absent(),
                Value<double?> warningPoints = const Value.absent(),
                Value<double?> currentPoints = const Value.absent(),
                Value<String?> penalty = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => ResultsEventsCompanion(
                fileId: fileId,
                seq: seq,
                kind: kind,
                elapsed: elapsed,
                body: body,
                driverName: driverName,
                slot: slot,
                lap: lap,
                resolution: resolution,
                warningPoints: warningPoints,
                currentPoints: currentPoints,
                penalty: penalty,
                reason: reason,
              ),
          createCompanionCallback:
              ({
                required int fileId,
                required int seq,
                required String kind,
                required double elapsed,
                required String body,
                Value<String?> driverName = const Value.absent(),
                Value<int?> slot = const Value.absent(),
                Value<int?> lap = const Value.absent(),
                Value<int?> resolution = const Value.absent(),
                Value<double?> warningPoints = const Value.absent(),
                Value<double?> currentPoints = const Value.absent(),
                Value<String?> penalty = const Value.absent(),
                Value<String?> reason = const Value.absent(),
              }) => ResultsEventsCompanion.insert(
                fileId: fileId,
                seq: seq,
                kind: kind,
                elapsed: elapsed,
                body: body,
                driverName: driverName,
                slot: slot,
                lap: lap,
                resolution: resolution,
                warningPoints: warningPoints,
                currentPoints: currentPoints,
                penalty: penalty,
                reason: reason,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResultsEventsTable, ResultsEventRow>(table),
                  BaseReferences<
                    _$ResultsDatabase,
                    $ResultsEventsTable,
                    ResultsEventRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$ResultsDatabase,
      $ResultsEventsTable,
      ResultsEventRow,
      $$ResultsEventsTableFilterComposer,
      $$ResultsEventsTableOrderingComposer,
      $$ResultsEventsTableAnnotationComposer,
      $$ResultsEventsTableCreateCompanionBuilder,
      $$ResultsEventsTableUpdateCompanionBuilder,
      (
        ResultsEventRow,
        BaseReferences<_$ResultsDatabase, $ResultsEventsTable, ResultsEventRow>,
      ),
      ResultsEventRow,
      PrefetchHooks Function()
    >;
typedef $$ResultsFoldersTableCreateCompanionBuilder =
    ResultsFoldersCompanion Function({
      required String path,
      required DateTime addedAt,
      Value<DateTime?> lastScannedAt,
      Value<int?> lastScanFileCount,
      Value<int> rowid,
    });
typedef $$ResultsFoldersTableUpdateCompanionBuilder =
    ResultsFoldersCompanion Function({
      Value<String> path,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScannedAt,
      Value<int?> lastScanFileCount,
      Value<int> rowid,
    });

class $$ResultsFoldersTableFilterComposer
    extends Composer<_$ResultsDatabase, $ResultsFoldersTable> {
  $$ResultsFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScanFileCount => $composableBuilder(
    column: $table.lastScanFileCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ResultsFoldersTableOrderingComposer
    extends Composer<_$ResultsDatabase, $ResultsFoldersTable> {
  $$ResultsFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScanFileCount => $composableBuilder(
    column: $table.lastScanFileCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ResultsFoldersTableAnnotationComposer
    extends Composer<_$ResultsDatabase, $ResultsFoldersTable> {
  $$ResultsFoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastScanFileCount => $composableBuilder(
    column: $table.lastScanFileCount,
    builder: (column) => column,
  );
}

class $$ResultsFoldersTableTableManager
    extends
        RootTableManager<
          _$ResultsDatabase,
          $ResultsFoldersTable,
          ResultsFolderRow,
          $$ResultsFoldersTableFilterComposer,
          $$ResultsFoldersTableOrderingComposer,
          $$ResultsFoldersTableAnnotationComposer,
          $$ResultsFoldersTableCreateCompanionBuilder,
          $$ResultsFoldersTableUpdateCompanionBuilder,
          (
            ResultsFolderRow,
            BaseReferences<
              _$ResultsDatabase,
              $ResultsFoldersTable,
              ResultsFolderRow
            >,
          ),
          ResultsFolderRow,
          PrefetchHooks Function()
        > {
  $$ResultsFoldersTableTableManager(
    _$ResultsDatabase db,
    $ResultsFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResultsFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResultsFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResultsFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScannedAt = const Value.absent(),
                Value<int?> lastScanFileCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResultsFoldersCompanion(
                path: path,
                addedAt: addedAt,
                lastScannedAt: lastScannedAt,
                lastScanFileCount: lastScanFileCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required DateTime addedAt,
                Value<DateTime?> lastScannedAt = const Value.absent(),
                Value<int?> lastScanFileCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ResultsFoldersCompanion.insert(
                path: path,
                addedAt: addedAt,
                lastScannedAt: lastScannedAt,
                lastScanFileCount: lastScanFileCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResultsFoldersTable, ResultsFolderRow>(table),
                  BaseReferences<
                    _$ResultsDatabase,
                    $ResultsFoldersTable,
                    ResultsFolderRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ResultsFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$ResultsDatabase,
      $ResultsFoldersTable,
      ResultsFolderRow,
      $$ResultsFoldersTableFilterComposer,
      $$ResultsFoldersTableOrderingComposer,
      $$ResultsFoldersTableAnnotationComposer,
      $$ResultsFoldersTableCreateCompanionBuilder,
      $$ResultsFoldersTableUpdateCompanionBuilder,
      (
        ResultsFolderRow,
        BaseReferences<
          _$ResultsDatabase,
          $ResultsFoldersTable,
          ResultsFolderRow
        >,
      ),
      ResultsFolderRow,
      PrefetchHooks Function()
    >;

class $ResultsDatabaseManager {
  final _$ResultsDatabase _db;
  $ResultsDatabaseManager(this._db);
  $$ResultsFilesTableTableManager get resultsFiles =>
      $$ResultsFilesTableTableManager(_db, _db.resultsFiles);
  $$ResultsDriversTableTableManager get resultsDrivers =>
      $$ResultsDriversTableTableManager(_db, _db.resultsDrivers);
  $$ResultsLapsTableTableManager get resultsLaps =>
      $$ResultsLapsTableTableManager(_db, _db.resultsLaps);
  $$ResultsEventsTableTableManager get resultsEvents =>
      $$ResultsEventsTableTableManager(_db, _db.resultsEvents);
  $$ResultsFoldersTableTableManager get resultsFolders =>
      $$ResultsFoldersTableTableManager(_db, _db.resultsFolders);
}
