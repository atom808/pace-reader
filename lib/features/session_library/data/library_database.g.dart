// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_database.dart';

// ignore_for_file: type=lint
class $LibrarySessionsTable extends LibrarySessions
    with TableInfo<$LibrarySessionsTable, LibrarySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibrarySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
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
  static const VerificationMeta _trackNameMeta = const VerificationMeta(
    'trackName',
  );
  @override
  late final GeneratedColumn<String> trackName = GeneratedColumn<String>(
    'track_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackLayoutMeta = const VerificationMeta(
    'trackLayout',
  );
  @override
  late final GeneratedColumn<String> trackLayout = GeneratedColumn<String>(
    'track_layout',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carNameMeta = const VerificationMeta(
    'carName',
  );
  @override
  late final GeneratedColumn<String> carName = GeneratedColumn<String>(
    'car_name',
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
  static const VerificationMeta _sessionTypeMeta = const VerificationMeta(
    'sessionType',
  );
  @override
  late final GeneratedColumn<String> sessionType = GeneratedColumn<String>(
    'session_type',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordingTimeMeta = const VerificationMeta(
    'recordingTime',
  );
  @override
  late final GeneratedColumn<String> recordingTime = GeneratedColumn<String>(
    'recording_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weatherMeta = const VerificationMeta(
    'weather',
  );
  @override
  late final GeneratedColumn<String> weather = GeneratedColumn<String>(
    'weather',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<String> formatVersion = GeneratedColumn<String>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedLapsMeta = const VerificationMeta(
    'completedLaps',
  );
  @override
  late final GeneratedColumn<int> completedLaps = GeneratedColumn<int>(
    'completed_laps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timedLapsMeta = const VerificationMeta(
    'timedLaps',
  );
  @override
  late final GeneratedColumn<int> timedLaps = GeneratedColumn<int>(
    'timed_laps',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _bestLapIndexMeta = const VerificationMeta(
    'bestLapIndex',
  );
  @override
  late final GeneratedColumn<int> bestLapIndex = GeneratedColumn<int>(
    'best_lap_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _clockGapCountMeta = const VerificationMeta(
    'clockGapCount',
  );
  @override
  late final GeneratedColumn<int> clockGapCount = GeneratedColumn<int>(
    'clock_gap_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
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
    importedAt,
    lastOpenedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'library_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibrarySessionRow> instance, {
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
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
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
    if (data.containsKey('track_name')) {
      context.handle(
        _trackNameMeta,
        trackName.isAcceptableOrUnknown(data['track_name']!, _trackNameMeta),
      );
    } else if (isInserting) {
      context.missing(_trackNameMeta);
    }
    if (data.containsKey('track_layout')) {
      context.handle(
        _trackLayoutMeta,
        trackLayout.isAcceptableOrUnknown(
          data['track_layout']!,
          _trackLayoutMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trackLayoutMeta);
    }
    if (data.containsKey('car_name')) {
      context.handle(
        _carNameMeta,
        carName.isAcceptableOrUnknown(data['car_name']!, _carNameMeta),
      );
    } else if (isInserting) {
      context.missing(_carNameMeta);
    }
    if (data.containsKey('car_class')) {
      context.handle(
        _carClassMeta,
        carClass.isAcceptableOrUnknown(data['car_class']!, _carClassMeta),
      );
    } else if (isInserting) {
      context.missing(_carClassMeta);
    }
    if (data.containsKey('session_type')) {
      context.handle(
        _sessionTypeMeta,
        sessionType.isAcceptableOrUnknown(
          data['session_type']!,
          _sessionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionTypeMeta);
    }
    if (data.containsKey('driver_name')) {
      context.handle(
        _driverNameMeta,
        driverName.isAcceptableOrUnknown(data['driver_name']!, _driverNameMeta),
      );
    } else if (isInserting) {
      context.missing(_driverNameMeta);
    }
    if (data.containsKey('recording_time')) {
      context.handle(
        _recordingTimeMeta,
        recordingTime.isAcceptableOrUnknown(
          data['recording_time']!,
          _recordingTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordingTimeMeta);
    }
    if (data.containsKey('weather')) {
      context.handle(
        _weatherMeta,
        weather.isAcceptableOrUnknown(data['weather']!, _weatherMeta),
      );
    } else if (isInserting) {
      context.missing(_weatherMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('completed_laps')) {
      context.handle(
        _completedLapsMeta,
        completedLaps.isAcceptableOrUnknown(
          data['completed_laps']!,
          _completedLapsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedLapsMeta);
    }
    if (data.containsKey('timed_laps')) {
      context.handle(
        _timedLapsMeta,
        timedLaps.isAcceptableOrUnknown(data['timed_laps']!, _timedLapsMeta),
      );
    } else if (isInserting) {
      context.missing(_timedLapsMeta);
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
    if (data.containsKey('best_lap_index')) {
      context.handle(
        _bestLapIndexMeta,
        bestLapIndex.isAcceptableOrUnknown(
          data['best_lap_index']!,
          _bestLapIndexMeta,
        ),
      );
    }
    if (data.containsKey('clock_gap_count')) {
      context.handle(
        _clockGapCountMeta,
        clockGapCount.isAcceptableOrUnknown(
          data['clock_gap_count']!,
          _clockGapCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clockGapCountMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  LibrarySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibrarySessionRow(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      modifiedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_ms'],
      )!,
      trackName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_name'],
      )!,
      trackLayout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}track_layout'],
      )!,
      carName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_name'],
      )!,
      carClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}car_class'],
      )!,
      sessionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_type'],
      )!,
      driverName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driver_name'],
      )!,
      recordingTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_time'],
      )!,
      weather: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weather'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_version'],
      )!,
      completedLaps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_laps'],
      )!,
      timedLaps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timed_laps'],
      )!,
      bestLapSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}best_lap_seconds'],
      ),
      bestLapIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_lap_index'],
      ),
      clockGapCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clock_gap_count'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
    );
  }

  @override
  $LibrarySessionsTable createAlias(String alias) {
    return $LibrarySessionsTable(attachedDatabase, alias);
  }
}

class LibrarySessionRow extends DataClass
    implements Insertable<LibrarySessionRow> {
  final String path;
  final String fileName;

  /// [LibrarySourceKind.name].
  final String kind;
  final int sizeBytes;

  /// See [FileFacts.modifiedMs] — an integer so the change check is exact.
  final int modifiedMs;
  final String trackName;
  final String trackLayout;
  final String carName;
  final String carClass;

  /// `metadata.SessionType` verbatim ([SessionType.rawValue]).
  final String sessionType;
  final String driverName;
  final String recordingTime;
  final String weather;
  final String formatVersion;
  final int completedLaps;
  final int timedLaps;
  final double? bestLapSeconds;
  final int? bestLapIndex;
  final int clockGapCount;
  final DateTime importedAt;
  final DateTime? lastOpenedAt;
  const LibrarySessionRow({
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
    this.bestLapSeconds,
    this.bestLapIndex,
    required this.clockGapCount,
    required this.importedAt,
    this.lastOpenedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['file_name'] = Variable<String>(fileName);
    map['kind'] = Variable<String>(kind);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['modified_ms'] = Variable<int>(modifiedMs);
    map['track_name'] = Variable<String>(trackName);
    map['track_layout'] = Variable<String>(trackLayout);
    map['car_name'] = Variable<String>(carName);
    map['car_class'] = Variable<String>(carClass);
    map['session_type'] = Variable<String>(sessionType);
    map['driver_name'] = Variable<String>(driverName);
    map['recording_time'] = Variable<String>(recordingTime);
    map['weather'] = Variable<String>(weather);
    map['format_version'] = Variable<String>(formatVersion);
    map['completed_laps'] = Variable<int>(completedLaps);
    map['timed_laps'] = Variable<int>(timedLaps);
    if (!nullToAbsent || bestLapSeconds != null) {
      map['best_lap_seconds'] = Variable<double>(bestLapSeconds);
    }
    if (!nullToAbsent || bestLapIndex != null) {
      map['best_lap_index'] = Variable<int>(bestLapIndex);
    }
    map['clock_gap_count'] = Variable<int>(clockGapCount);
    map['imported_at'] = Variable<DateTime>(importedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    return map;
  }

  LibrarySessionsCompanion toCompanion(bool nullToAbsent) {
    return LibrarySessionsCompanion(
      path: Value(path),
      fileName: Value(fileName),
      kind: Value(kind),
      sizeBytes: Value(sizeBytes),
      modifiedMs: Value(modifiedMs),
      trackName: Value(trackName),
      trackLayout: Value(trackLayout),
      carName: Value(carName),
      carClass: Value(carClass),
      sessionType: Value(sessionType),
      driverName: Value(driverName),
      recordingTime: Value(recordingTime),
      weather: Value(weather),
      formatVersion: Value(formatVersion),
      completedLaps: Value(completedLaps),
      timedLaps: Value(timedLaps),
      bestLapSeconds: bestLapSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(bestLapSeconds),
      bestLapIndex: bestLapIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(bestLapIndex),
      clockGapCount: Value(clockGapCount),
      importedAt: Value(importedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
    );
  }

  factory LibrarySessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibrarySessionRow(
      path: serializer.fromJson<String>(json['path']),
      fileName: serializer.fromJson<String>(json['fileName']),
      kind: serializer.fromJson<String>(json['kind']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      modifiedMs: serializer.fromJson<int>(json['modifiedMs']),
      trackName: serializer.fromJson<String>(json['trackName']),
      trackLayout: serializer.fromJson<String>(json['trackLayout']),
      carName: serializer.fromJson<String>(json['carName']),
      carClass: serializer.fromJson<String>(json['carClass']),
      sessionType: serializer.fromJson<String>(json['sessionType']),
      driverName: serializer.fromJson<String>(json['driverName']),
      recordingTime: serializer.fromJson<String>(json['recordingTime']),
      weather: serializer.fromJson<String>(json['weather']),
      formatVersion: serializer.fromJson<String>(json['formatVersion']),
      completedLaps: serializer.fromJson<int>(json['completedLaps']),
      timedLaps: serializer.fromJson<int>(json['timedLaps']),
      bestLapSeconds: serializer.fromJson<double?>(json['bestLapSeconds']),
      bestLapIndex: serializer.fromJson<int?>(json['bestLapIndex']),
      clockGapCount: serializer.fromJson<int>(json['clockGapCount']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'fileName': serializer.toJson<String>(fileName),
      'kind': serializer.toJson<String>(kind),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'modifiedMs': serializer.toJson<int>(modifiedMs),
      'trackName': serializer.toJson<String>(trackName),
      'trackLayout': serializer.toJson<String>(trackLayout),
      'carName': serializer.toJson<String>(carName),
      'carClass': serializer.toJson<String>(carClass),
      'sessionType': serializer.toJson<String>(sessionType),
      'driverName': serializer.toJson<String>(driverName),
      'recordingTime': serializer.toJson<String>(recordingTime),
      'weather': serializer.toJson<String>(weather),
      'formatVersion': serializer.toJson<String>(formatVersion),
      'completedLaps': serializer.toJson<int>(completedLaps),
      'timedLaps': serializer.toJson<int>(timedLaps),
      'bestLapSeconds': serializer.toJson<double?>(bestLapSeconds),
      'bestLapIndex': serializer.toJson<int?>(bestLapIndex),
      'clockGapCount': serializer.toJson<int>(clockGapCount),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
    };
  }

  LibrarySessionRow copyWith({
    String? path,
    String? fileName,
    String? kind,
    int? sizeBytes,
    int? modifiedMs,
    String? trackName,
    String? trackLayout,
    String? carName,
    String? carClass,
    String? sessionType,
    String? driverName,
    String? recordingTime,
    String? weather,
    String? formatVersion,
    int? completedLaps,
    int? timedLaps,
    Value<double?> bestLapSeconds = const Value.absent(),
    Value<int?> bestLapIndex = const Value.absent(),
    int? clockGapCount,
    DateTime? importedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
  }) => LibrarySessionRow(
    path: path ?? this.path,
    fileName: fileName ?? this.fileName,
    kind: kind ?? this.kind,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    modifiedMs: modifiedMs ?? this.modifiedMs,
    trackName: trackName ?? this.trackName,
    trackLayout: trackLayout ?? this.trackLayout,
    carName: carName ?? this.carName,
    carClass: carClass ?? this.carClass,
    sessionType: sessionType ?? this.sessionType,
    driverName: driverName ?? this.driverName,
    recordingTime: recordingTime ?? this.recordingTime,
    weather: weather ?? this.weather,
    formatVersion: formatVersion ?? this.formatVersion,
    completedLaps: completedLaps ?? this.completedLaps,
    timedLaps: timedLaps ?? this.timedLaps,
    bestLapSeconds: bestLapSeconds.present
        ? bestLapSeconds.value
        : this.bestLapSeconds,
    bestLapIndex: bestLapIndex.present ? bestLapIndex.value : this.bestLapIndex,
    clockGapCount: clockGapCount ?? this.clockGapCount,
    importedAt: importedAt ?? this.importedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
  );
  LibrarySessionRow copyWithCompanion(LibrarySessionsCompanion data) {
    return LibrarySessionRow(
      path: data.path.present ? data.path.value : this.path,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      kind: data.kind.present ? data.kind.value : this.kind,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedMs: data.modifiedMs.present
          ? data.modifiedMs.value
          : this.modifiedMs,
      trackName: data.trackName.present ? data.trackName.value : this.trackName,
      trackLayout: data.trackLayout.present
          ? data.trackLayout.value
          : this.trackLayout,
      carName: data.carName.present ? data.carName.value : this.carName,
      carClass: data.carClass.present ? data.carClass.value : this.carClass,
      sessionType: data.sessionType.present
          ? data.sessionType.value
          : this.sessionType,
      driverName: data.driverName.present
          ? data.driverName.value
          : this.driverName,
      recordingTime: data.recordingTime.present
          ? data.recordingTime.value
          : this.recordingTime,
      weather: data.weather.present ? data.weather.value : this.weather,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      completedLaps: data.completedLaps.present
          ? data.completedLaps.value
          : this.completedLaps,
      timedLaps: data.timedLaps.present ? data.timedLaps.value : this.timedLaps,
      bestLapSeconds: data.bestLapSeconds.present
          ? data.bestLapSeconds.value
          : this.bestLapSeconds,
      bestLapIndex: data.bestLapIndex.present
          ? data.bestLapIndex.value
          : this.bestLapIndex,
      clockGapCount: data.clockGapCount.present
          ? data.clockGapCount.value
          : this.clockGapCount,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySessionRow(')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('trackName: $trackName, ')
          ..write('trackLayout: $trackLayout, ')
          ..write('carName: $carName, ')
          ..write('carClass: $carClass, ')
          ..write('sessionType: $sessionType, ')
          ..write('driverName: $driverName, ')
          ..write('recordingTime: $recordingTime, ')
          ..write('weather: $weather, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('completedLaps: $completedLaps, ')
          ..write('timedLaps: $timedLaps, ')
          ..write('bestLapSeconds: $bestLapSeconds, ')
          ..write('bestLapIndex: $bestLapIndex, ')
          ..write('clockGapCount: $clockGapCount, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
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
    importedAt,
    lastOpenedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LibrarySessionRow &&
          other.path == this.path &&
          other.fileName == this.fileName &&
          other.kind == this.kind &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedMs == this.modifiedMs &&
          other.trackName == this.trackName &&
          other.trackLayout == this.trackLayout &&
          other.carName == this.carName &&
          other.carClass == this.carClass &&
          other.sessionType == this.sessionType &&
          other.driverName == this.driverName &&
          other.recordingTime == this.recordingTime &&
          other.weather == this.weather &&
          other.formatVersion == this.formatVersion &&
          other.completedLaps == this.completedLaps &&
          other.timedLaps == this.timedLaps &&
          other.bestLapSeconds == this.bestLapSeconds &&
          other.bestLapIndex == this.bestLapIndex &&
          other.clockGapCount == this.clockGapCount &&
          other.importedAt == this.importedAt &&
          other.lastOpenedAt == this.lastOpenedAt);
}

class LibrarySessionsCompanion extends UpdateCompanion<LibrarySessionRow> {
  final Value<String> path;
  final Value<String> fileName;
  final Value<String> kind;
  final Value<int> sizeBytes;
  final Value<int> modifiedMs;
  final Value<String> trackName;
  final Value<String> trackLayout;
  final Value<String> carName;
  final Value<String> carClass;
  final Value<String> sessionType;
  final Value<String> driverName;
  final Value<String> recordingTime;
  final Value<String> weather;
  final Value<String> formatVersion;
  final Value<int> completedLaps;
  final Value<int> timedLaps;
  final Value<double?> bestLapSeconds;
  final Value<int?> bestLapIndex;
  final Value<int> clockGapCount;
  final Value<DateTime> importedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<int> rowid;
  const LibrarySessionsCompanion({
    this.path = const Value.absent(),
    this.fileName = const Value.absent(),
    this.kind = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedMs = const Value.absent(),
    this.trackName = const Value.absent(),
    this.trackLayout = const Value.absent(),
    this.carName = const Value.absent(),
    this.carClass = const Value.absent(),
    this.sessionType = const Value.absent(),
    this.driverName = const Value.absent(),
    this.recordingTime = const Value.absent(),
    this.weather = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.completedLaps = const Value.absent(),
    this.timedLaps = const Value.absent(),
    this.bestLapSeconds = const Value.absent(),
    this.bestLapIndex = const Value.absent(),
    this.clockGapCount = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibrarySessionsCompanion.insert({
    required String path,
    required String fileName,
    required String kind,
    required int sizeBytes,
    required int modifiedMs,
    required String trackName,
    required String trackLayout,
    required String carName,
    required String carClass,
    required String sessionType,
    required String driverName,
    required String recordingTime,
    required String weather,
    required String formatVersion,
    required int completedLaps,
    required int timedLaps,
    this.bestLapSeconds = const Value.absent(),
    this.bestLapIndex = const Value.absent(),
    required int clockGapCount,
    required DateTime importedAt,
    this.lastOpenedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       fileName = Value(fileName),
       kind = Value(kind),
       sizeBytes = Value(sizeBytes),
       modifiedMs = Value(modifiedMs),
       trackName = Value(trackName),
       trackLayout = Value(trackLayout),
       carName = Value(carName),
       carClass = Value(carClass),
       sessionType = Value(sessionType),
       driverName = Value(driverName),
       recordingTime = Value(recordingTime),
       weather = Value(weather),
       formatVersion = Value(formatVersion),
       completedLaps = Value(completedLaps),
       timedLaps = Value(timedLaps),
       clockGapCount = Value(clockGapCount),
       importedAt = Value(importedAt);
  static Insertable<LibrarySessionRow> custom({
    Expression<String>? path,
    Expression<String>? fileName,
    Expression<String>? kind,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedMs,
    Expression<String>? trackName,
    Expression<String>? trackLayout,
    Expression<String>? carName,
    Expression<String>? carClass,
    Expression<String>? sessionType,
    Expression<String>? driverName,
    Expression<String>? recordingTime,
    Expression<String>? weather,
    Expression<String>? formatVersion,
    Expression<int>? completedLaps,
    Expression<int>? timedLaps,
    Expression<double>? bestLapSeconds,
    Expression<int>? bestLapIndex,
    Expression<int>? clockGapCount,
    Expression<DateTime>? importedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (fileName != null) 'file_name': fileName,
      if (kind != null) 'kind': kind,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedMs != null) 'modified_ms': modifiedMs,
      if (trackName != null) 'track_name': trackName,
      if (trackLayout != null) 'track_layout': trackLayout,
      if (carName != null) 'car_name': carName,
      if (carClass != null) 'car_class': carClass,
      if (sessionType != null) 'session_type': sessionType,
      if (driverName != null) 'driver_name': driverName,
      if (recordingTime != null) 'recording_time': recordingTime,
      if (weather != null) 'weather': weather,
      if (formatVersion != null) 'format_version': formatVersion,
      if (completedLaps != null) 'completed_laps': completedLaps,
      if (timedLaps != null) 'timed_laps': timedLaps,
      if (bestLapSeconds != null) 'best_lap_seconds': bestLapSeconds,
      if (bestLapIndex != null) 'best_lap_index': bestLapIndex,
      if (clockGapCount != null) 'clock_gap_count': clockGapCount,
      if (importedAt != null) 'imported_at': importedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibrarySessionsCompanion copyWith({
    Value<String>? path,
    Value<String>? fileName,
    Value<String>? kind,
    Value<int>? sizeBytes,
    Value<int>? modifiedMs,
    Value<String>? trackName,
    Value<String>? trackLayout,
    Value<String>? carName,
    Value<String>? carClass,
    Value<String>? sessionType,
    Value<String>? driverName,
    Value<String>? recordingTime,
    Value<String>? weather,
    Value<String>? formatVersion,
    Value<int>? completedLaps,
    Value<int>? timedLaps,
    Value<double?>? bestLapSeconds,
    Value<int?>? bestLapIndex,
    Value<int>? clockGapCount,
    Value<DateTime>? importedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<int>? rowid,
  }) {
    return LibrarySessionsCompanion(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      kind: kind ?? this.kind,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedMs: modifiedMs ?? this.modifiedMs,
      trackName: trackName ?? this.trackName,
      trackLayout: trackLayout ?? this.trackLayout,
      carName: carName ?? this.carName,
      carClass: carClass ?? this.carClass,
      sessionType: sessionType ?? this.sessionType,
      driverName: driverName ?? this.driverName,
      recordingTime: recordingTime ?? this.recordingTime,
      weather: weather ?? this.weather,
      formatVersion: formatVersion ?? this.formatVersion,
      completedLaps: completedLaps ?? this.completedLaps,
      timedLaps: timedLaps ?? this.timedLaps,
      bestLapSeconds: bestLapSeconds ?? this.bestLapSeconds,
      bestLapIndex: bestLapIndex ?? this.bestLapIndex,
      clockGapCount: clockGapCount ?? this.clockGapCount,
      importedAt: importedAt ?? this.importedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedMs.present) {
      map['modified_ms'] = Variable<int>(modifiedMs.value);
    }
    if (trackName.present) {
      map['track_name'] = Variable<String>(trackName.value);
    }
    if (trackLayout.present) {
      map['track_layout'] = Variable<String>(trackLayout.value);
    }
    if (carName.present) {
      map['car_name'] = Variable<String>(carName.value);
    }
    if (carClass.present) {
      map['car_class'] = Variable<String>(carClass.value);
    }
    if (sessionType.present) {
      map['session_type'] = Variable<String>(sessionType.value);
    }
    if (driverName.present) {
      map['driver_name'] = Variable<String>(driverName.value);
    }
    if (recordingTime.present) {
      map['recording_time'] = Variable<String>(recordingTime.value);
    }
    if (weather.present) {
      map['weather'] = Variable<String>(weather.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<String>(formatVersion.value);
    }
    if (completedLaps.present) {
      map['completed_laps'] = Variable<int>(completedLaps.value);
    }
    if (timedLaps.present) {
      map['timed_laps'] = Variable<int>(timedLaps.value);
    }
    if (bestLapSeconds.present) {
      map['best_lap_seconds'] = Variable<double>(bestLapSeconds.value);
    }
    if (bestLapIndex.present) {
      map['best_lap_index'] = Variable<int>(bestLapIndex.value);
    }
    if (clockGapCount.present) {
      map['clock_gap_count'] = Variable<int>(clockGapCount.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrarySessionsCompanion(')
          ..write('path: $path, ')
          ..write('fileName: $fileName, ')
          ..write('kind: $kind, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedMs: $modifiedMs, ')
          ..write('trackName: $trackName, ')
          ..write('trackLayout: $trackLayout, ')
          ..write('carName: $carName, ')
          ..write('carClass: $carClass, ')
          ..write('sessionType: $sessionType, ')
          ..write('driverName: $driverName, ')
          ..write('recordingTime: $recordingTime, ')
          ..write('weather: $weather, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('completedLaps: $completedLaps, ')
          ..write('timedLaps: $timedLaps, ')
          ..write('bestLapSeconds: $bestLapSeconds, ')
          ..write('bestLapIndex: $bestLapIndex, ')
          ..write('clockGapCount: $clockGapCount, ')
          ..write('importedAt: $importedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LibraryFoldersTable extends LibraryFolders
    with TableInfo<$LibraryFoldersTable, LibraryFolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibraryFoldersTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'library_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<LibraryFolderRow> instance, {
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
  LibraryFolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LibraryFolderRow(
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
  $LibraryFoldersTable createAlias(String alias) {
    return $LibraryFoldersTable(attachedDatabase, alias);
  }
}

class LibraryFolderRow extends DataClass
    implements Insertable<LibraryFolderRow> {
  final String path;
  final DateTime addedAt;
  final DateTime? lastScannedAt;
  final int? lastScanFileCount;
  const LibraryFolderRow({
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

  LibraryFoldersCompanion toCompanion(bool nullToAbsent) {
    return LibraryFoldersCompanion(
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

  factory LibraryFolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LibraryFolderRow(
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

  LibraryFolderRow copyWith({
    String? path,
    DateTime? addedAt,
    Value<DateTime?> lastScannedAt = const Value.absent(),
    Value<int?> lastScanFileCount = const Value.absent(),
  }) => LibraryFolderRow(
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    lastScannedAt: lastScannedAt.present
        ? lastScannedAt.value
        : this.lastScannedAt,
    lastScanFileCount: lastScanFileCount.present
        ? lastScanFileCount.value
        : this.lastScanFileCount,
  );
  LibraryFolderRow copyWithCompanion(LibraryFoldersCompanion data) {
    return LibraryFolderRow(
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
    return (StringBuffer('LibraryFolderRow(')
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
      (other is LibraryFolderRow &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.lastScannedAt == this.lastScannedAt &&
          other.lastScanFileCount == this.lastScanFileCount);
}

class LibraryFoldersCompanion extends UpdateCompanion<LibraryFolderRow> {
  final Value<String> path;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastScannedAt;
  final Value<int?> lastScanFileCount;
  final Value<int> rowid;
  const LibraryFoldersCompanion({
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
    this.lastScanFileCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibraryFoldersCompanion.insert({
    required String path,
    required DateTime addedAt,
    this.lastScannedAt = const Value.absent(),
    this.lastScanFileCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       addedAt = Value(addedAt);
  static Insertable<LibraryFolderRow> custom({
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

  LibraryFoldersCompanion copyWith({
    Value<String>? path,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastScannedAt,
    Value<int?>? lastScanFileCount,
    Value<int>? rowid,
  }) {
    return LibraryFoldersCompanion(
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
    return (StringBuffer('LibraryFoldersCompanion(')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('lastScanFileCount: $lastScanFileCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LibraryDatabase extends GeneratedDatabase {
  _$LibraryDatabase(QueryExecutor e) : super(e);
  $LibraryDatabaseManager get managers => $LibraryDatabaseManager(this);
  late final $LibrarySessionsTable librarySessions = $LibrarySessionsTable(
    this,
  );
  late final $LibraryFoldersTable libraryFolders = $LibraryFoldersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    librarySessions,
    libraryFolders,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$LibrarySessionsTableCreateCompanionBuilder =
    LibrarySessionsCompanion Function({
      required String path,
      required String fileName,
      required String kind,
      required int sizeBytes,
      required int modifiedMs,
      required String trackName,
      required String trackLayout,
      required String carName,
      required String carClass,
      required String sessionType,
      required String driverName,
      required String recordingTime,
      required String weather,
      required String formatVersion,
      required int completedLaps,
      required int timedLaps,
      Value<double?> bestLapSeconds,
      Value<int?> bestLapIndex,
      required int clockGapCount,
      required DateTime importedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });
typedef $$LibrarySessionsTableUpdateCompanionBuilder =
    LibrarySessionsCompanion Function({
      Value<String> path,
      Value<String> fileName,
      Value<String> kind,
      Value<int> sizeBytes,
      Value<int> modifiedMs,
      Value<String> trackName,
      Value<String> trackLayout,
      Value<String> carName,
      Value<String> carClass,
      Value<String> sessionType,
      Value<String> driverName,
      Value<String> recordingTime,
      Value<String> weather,
      Value<String> formatVersion,
      Value<int> completedLaps,
      Value<int> timedLaps,
      Value<double?> bestLapSeconds,
      Value<int?> bestLapIndex,
      Value<int> clockGapCount,
      Value<DateTime> importedAt,
      Value<DateTime?> lastOpenedAt,
      Value<int> rowid,
    });

class $$LibrarySessionsTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibrarySessionsTable> {
  $$LibrarySessionsTableFilterComposer({
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

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
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

  ColumnFilters<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trackLayout => $composableBuilder(
    column: $table.trackLayout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carName => $composableBuilder(
    column: $table.carName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get carClass => $composableBuilder(
    column: $table.carClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionType => $composableBuilder(
    column: $table.sessionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingTime => $composableBuilder(
    column: $table.recordingTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedLaps => $composableBuilder(
    column: $table.completedLaps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timedLaps => $composableBuilder(
    column: $table.timedLaps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestLapIndex => $composableBuilder(
    column: $table.bestLapIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clockGapCount => $composableBuilder(
    column: $table.clockGapCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LibrarySessionsTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibrarySessionsTable> {
  $$LibrarySessionsTableOrderingComposer({
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

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
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

  ColumnOrderings<String> get trackName => $composableBuilder(
    column: $table.trackName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trackLayout => $composableBuilder(
    column: $table.trackLayout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carName => $composableBuilder(
    column: $table.carName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get carClass => $composableBuilder(
    column: $table.carClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionType => $composableBuilder(
    column: $table.sessionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingTime => $composableBuilder(
    column: $table.recordingTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weather => $composableBuilder(
    column: $table.weather,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedLaps => $composableBuilder(
    column: $table.completedLaps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timedLaps => $composableBuilder(
    column: $table.timedLaps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestLapIndex => $composableBuilder(
    column: $table.bestLapIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clockGapCount => $composableBuilder(
    column: $table.clockGapCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibrarySessionsTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibrarySessionsTable> {
  $$LibrarySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedMs => $composableBuilder(
    column: $table.modifiedMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trackName =>
      $composableBuilder(column: $table.trackName, builder: (column) => column);

  GeneratedColumn<String> get trackLayout => $composableBuilder(
    column: $table.trackLayout,
    builder: (column) => column,
  );

  GeneratedColumn<String> get carName =>
      $composableBuilder(column: $table.carName, builder: (column) => column);

  GeneratedColumn<String> get carClass =>
      $composableBuilder(column: $table.carClass, builder: (column) => column);

  GeneratedColumn<String> get sessionType => $composableBuilder(
    column: $table.sessionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get driverName => $composableBuilder(
    column: $table.driverName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordingTime => $composableBuilder(
    column: $table.recordingTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weather =>
      $composableBuilder(column: $table.weather, builder: (column) => column);

  GeneratedColumn<String> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedLaps => $composableBuilder(
    column: $table.completedLaps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timedLaps =>
      $composableBuilder(column: $table.timedLaps, builder: (column) => column);

  GeneratedColumn<double> get bestLapSeconds => $composableBuilder(
    column: $table.bestLapSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bestLapIndex => $composableBuilder(
    column: $table.bestLapIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get clockGapCount => $composableBuilder(
    column: $table.clockGapCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );
}

class $$LibrarySessionsTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibrarySessionsTable,
          LibrarySessionRow,
          $$LibrarySessionsTableFilterComposer,
          $$LibrarySessionsTableOrderingComposer,
          $$LibrarySessionsTableAnnotationComposer,
          $$LibrarySessionsTableCreateCompanionBuilder,
          $$LibrarySessionsTableUpdateCompanionBuilder,
          (
            LibrarySessionRow,
            BaseReferences<
              _$LibraryDatabase,
              $LibrarySessionsTable,
              LibrarySessionRow
            >,
          ),
          LibrarySessionRow,
          PrefetchHooks Function()
        > {
  $$LibrarySessionsTableTableManager(
    _$LibraryDatabase db,
    $LibrarySessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibrarySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibrarySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibrarySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> modifiedMs = const Value.absent(),
                Value<String> trackName = const Value.absent(),
                Value<String> trackLayout = const Value.absent(),
                Value<String> carName = const Value.absent(),
                Value<String> carClass = const Value.absent(),
                Value<String> sessionType = const Value.absent(),
                Value<String> driverName = const Value.absent(),
                Value<String> recordingTime = const Value.absent(),
                Value<String> weather = const Value.absent(),
                Value<String> formatVersion = const Value.absent(),
                Value<int> completedLaps = const Value.absent(),
                Value<int> timedLaps = const Value.absent(),
                Value<double?> bestLapSeconds = const Value.absent(),
                Value<int?> bestLapIndex = const Value.absent(),
                Value<int> clockGapCount = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibrarySessionsCompanion(
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
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String fileName,
                required String kind,
                required int sizeBytes,
                required int modifiedMs,
                required String trackName,
                required String trackLayout,
                required String carName,
                required String carClass,
                required String sessionType,
                required String driverName,
                required String recordingTime,
                required String weather,
                required String formatVersion,
                required int completedLaps,
                required int timedLaps,
                Value<double?> bestLapSeconds = const Value.absent(),
                Value<int?> bestLapIndex = const Value.absent(),
                required int clockGapCount,
                required DateTime importedAt,
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibrarySessionsCompanion.insert(
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
                lastOpenedAt: lastOpenedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibrarySessionsTable, LibrarySessionRow>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $LibrarySessionsTable,
                    LibrarySessionRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibrarySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibrarySessionsTable,
      LibrarySessionRow,
      $$LibrarySessionsTableFilterComposer,
      $$LibrarySessionsTableOrderingComposer,
      $$LibrarySessionsTableAnnotationComposer,
      $$LibrarySessionsTableCreateCompanionBuilder,
      $$LibrarySessionsTableUpdateCompanionBuilder,
      (
        LibrarySessionRow,
        BaseReferences<
          _$LibraryDatabase,
          $LibrarySessionsTable,
          LibrarySessionRow
        >,
      ),
      LibrarySessionRow,
      PrefetchHooks Function()
    >;
typedef $$LibraryFoldersTableCreateCompanionBuilder =
    LibraryFoldersCompanion Function({
      required String path,
      required DateTime addedAt,
      Value<DateTime?> lastScannedAt,
      Value<int?> lastScanFileCount,
      Value<int> rowid,
    });
typedef $$LibraryFoldersTableUpdateCompanionBuilder =
    LibraryFoldersCompanion Function({
      Value<String> path,
      Value<DateTime> addedAt,
      Value<DateTime?> lastScannedAt,
      Value<int?> lastScanFileCount,
      Value<int> rowid,
    });

class $$LibraryFoldersTableFilterComposer
    extends Composer<_$LibraryDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableFilterComposer({
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

class $$LibraryFoldersTableOrderingComposer
    extends Composer<_$LibraryDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableOrderingComposer({
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

class $$LibraryFoldersTableAnnotationComposer
    extends Composer<_$LibraryDatabase, $LibraryFoldersTable> {
  $$LibraryFoldersTableAnnotationComposer({
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

class $$LibraryFoldersTableTableManager
    extends
        RootTableManager<
          _$LibraryDatabase,
          $LibraryFoldersTable,
          LibraryFolderRow,
          $$LibraryFoldersTableFilterComposer,
          $$LibraryFoldersTableOrderingComposer,
          $$LibraryFoldersTableAnnotationComposer,
          $$LibraryFoldersTableCreateCompanionBuilder,
          $$LibraryFoldersTableUpdateCompanionBuilder,
          (
            LibraryFolderRow,
            BaseReferences<
              _$LibraryDatabase,
              $LibraryFoldersTable,
              LibraryFolderRow
            >,
          ),
          LibraryFolderRow,
          PrefetchHooks Function()
        > {
  $$LibraryFoldersTableTableManager(
    _$LibraryDatabase db,
    $LibraryFoldersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibraryFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibraryFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibraryFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastScannedAt = const Value.absent(),
                Value<int?> lastScanFileCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibraryFoldersCompanion(
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
              }) => LibraryFoldersCompanion.insert(
                path: path,
                addedAt: addedAt,
                lastScannedAt: lastScannedAt,
                lastScanFileCount: lastScanFileCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LibraryFoldersTable, LibraryFolderRow>(table),
                  BaseReferences<
                    _$LibraryDatabase,
                    $LibraryFoldersTable,
                    LibraryFolderRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LibraryFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$LibraryDatabase,
      $LibraryFoldersTable,
      LibraryFolderRow,
      $$LibraryFoldersTableFilterComposer,
      $$LibraryFoldersTableOrderingComposer,
      $$LibraryFoldersTableAnnotationComposer,
      $$LibraryFoldersTableCreateCompanionBuilder,
      $$LibraryFoldersTableUpdateCompanionBuilder,
      (
        LibraryFolderRow,
        BaseReferences<
          _$LibraryDatabase,
          $LibraryFoldersTable,
          LibraryFolderRow
        >,
      ),
      LibraryFolderRow,
      PrefetchHooks Function()
    >;

class $LibraryDatabaseManager {
  final _$LibraryDatabase _db;
  $LibraryDatabaseManager(this._db);
  $$LibrarySessionsTableTableManager get librarySessions =>
      $$LibrarySessionsTableTableManager(_db, _db.librarySessions);
  $$LibraryFoldersTableTableManager get libraryFolders =>
      $$LibraryFoldersTableTableManager(_db, _db.libraryFolders);
}
