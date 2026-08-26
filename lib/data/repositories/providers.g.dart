// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The open session for a given source.
///
/// `keepAlive` because the family key *is* the open file: disposing on the
/// last listener would close the DuckDB connection whenever the user navigated
/// between two feature screens, and reopening re-reads the catalog and
/// re-scans the clock (§9.6). Sessions are released explicitly instead.
///
/// Note this only works because [TelemetrySource] has value equality — a
/// family keyed on identity would reopen the file on every rebuild.

@ProviderFor(telemetrySession)
final telemetrySessionProvider = TelemetrySessionFamily._();

/// The open session for a given source.
///
/// `keepAlive` because the family key *is* the open file: disposing on the
/// last listener would close the DuckDB connection whenever the user navigated
/// between two feature screens, and reopening re-reads the catalog and
/// re-scans the clock (§9.6). Sessions are released explicitly instead.
///
/// Note this only works because [TelemetrySource] has value equality — a
/// family keyed on identity would reopen the file on every rebuild.

final class TelemetrySessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<TelemetrySession>,
          TelemetrySession,
          FutureOr<TelemetrySession>
        >
    with $FutureModifier<TelemetrySession>, $FutureProvider<TelemetrySession> {
  /// The open session for a given source.
  ///
  /// `keepAlive` because the family key *is* the open file: disposing on the
  /// last listener would close the DuckDB connection whenever the user navigated
  /// between two feature screens, and reopening re-reads the catalog and
  /// re-scans the clock (§9.6). Sessions are released explicitly instead.
  ///
  /// Note this only works because [TelemetrySource] has value equality — a
  /// family keyed on identity would reopen the file on every rebuild.
  TelemetrySessionProvider._({
    required TelemetrySessionFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'telemetrySessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$telemetrySessionHash();

  @override
  String toString() {
    return r'telemetrySessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TelemetrySession> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TelemetrySession> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return telemetrySession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TelemetrySessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$telemetrySessionHash() => r'c7e953bfc29632a85822c0f4baa5c42659d3715a';

/// The open session for a given source.
///
/// `keepAlive` because the family key *is* the open file: disposing on the
/// last listener would close the DuckDB connection whenever the user navigated
/// between two feature screens, and reopening re-reads the catalog and
/// re-scans the clock (§9.6). Sessions are released explicitly instead.
///
/// Note this only works because [TelemetrySource] has value equality — a
/// family keyed on identity would reopen the file on every rebuild.

final class TelemetrySessionFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<TelemetrySession>, TelemetrySource> {
  TelemetrySessionFamily._()
    : super(
        retry: _neverRetry,
        name: r'telemetrySessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The open session for a given source.
  ///
  /// `keepAlive` because the family key *is* the open file: disposing on the
  /// last listener would close the DuckDB connection whenever the user navigated
  /// between two feature screens, and reopening re-reads the catalog and
  /// re-scans the clock (§9.6). Sessions are released explicitly instead.
  ///
  /// Note this only works because [TelemetrySource] has value equality — a
  /// family keyed on identity would reopen the file on every rebuild.

  TelemetrySessionProvider call(TelemetrySource source) =>
      TelemetrySessionProvider._(argument: source, from: this);

  @override
  String toString() => r'telemetrySessionProvider';
}

/// Session metadata (§8.2) — the cheapest thing to depend on when a screen
/// needs the header facts but no telemetry.

@ProviderFor(sessionMetadata)
final sessionMetadataProvider = SessionMetadataFamily._();

/// Session metadata (§8.2) — the cheapest thing to depend on when a screen
/// needs the header facts but no telemetry.

final class SessionMetadataProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionMetadata>,
          SessionMetadata,
          FutureOr<SessionMetadata>
        >
    with $FutureModifier<SessionMetadata>, $FutureProvider<SessionMetadata> {
  /// Session metadata (§8.2) — the cheapest thing to depend on when a screen
  /// needs the header facts but no telemetry.
  SessionMetadataProvider._({
    required SessionMetadataFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionMetadataProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionMetadataHash();

  @override
  String toString() {
    return r'sessionMetadataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionMetadata> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionMetadata> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionMetadata(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionMetadataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionMetadataHash() => r'd6bfcc9765bd5d16d707873a33a80f05346ec487';

/// Session metadata (§8.2) — the cheapest thing to depend on when a screen
/// needs the header facts but no telemetry.

final class SessionMetadataFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SessionMetadata>, TelemetrySource> {
  SessionMetadataFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionMetadataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Session metadata (§8.2) — the cheapest thing to depend on when a screen
  /// needs the header facts but no telemetry.

  SessionMetadataProvider call(TelemetrySource source) =>
      SessionMetadataProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionMetadataProvider';
}

@ProviderFor(telemetryCatalog)
final telemetryCatalogProvider = TelemetryCatalogFamily._();

final class TelemetryCatalogProvider
    extends
        $FunctionalProvider<
          AsyncValue<TelemetryCatalog>,
          TelemetryCatalog,
          FutureOr<TelemetryCatalog>
        >
    with $FutureModifier<TelemetryCatalog>, $FutureProvider<TelemetryCatalog> {
  TelemetryCatalogProvider._({
    required TelemetryCatalogFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'telemetryCatalogProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$telemetryCatalogHash();

  @override
  String toString() {
    return r'telemetryCatalogProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TelemetryCatalog> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TelemetryCatalog> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return telemetryCatalog(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TelemetryCatalogProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$telemetryCatalogHash() => r'cb9a34525f21886ce4d1c3c8e79f17b19fbdbf29';

final class TelemetryCatalogFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<TelemetryCatalog>, TelemetrySource> {
  TelemetryCatalogFamily._()
    : super(
        retry: _neverRetry,
        name: r'telemetryCatalogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TelemetryCatalogProvider call(TelemetrySource source) =>
      TelemetryCatalogProvider._(argument: source, from: this);

  @override
  String toString() => r'telemetryCatalogProvider';
}

@ProviderFor(lapRepository)
final lapRepositoryProvider = LapRepositoryFamily._();

final class LapRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<LapRepository>,
          LapRepository,
          FutureOr<LapRepository>
        >
    with $FutureModifier<LapRepository>, $FutureProvider<LapRepository> {
  LapRepositoryProvider._({
    required LapRepositoryFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapRepositoryHash();

  @override
  String toString() {
    return r'lapRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LapRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LapRepository> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return lapRepository(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LapRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapRepositoryHash() => r'fc9369df5056a09128b9426e9ef422499b7b586b';

final class LapRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LapRepository>, TelemetrySource> {
  LapRepositoryFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LapRepositoryProvider call(TelemetrySource source) =>
      LapRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'lapRepositoryProvider';
}

@ProviderFor(telemetryRepository)
final telemetryRepositoryProvider = TelemetryRepositoryFamily._();

final class TelemetryRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TelemetryRepository>,
          TelemetryRepository,
          FutureOr<TelemetryRepository>
        >
    with
        $FutureModifier<TelemetryRepository>,
        $FutureProvider<TelemetryRepository> {
  TelemetryRepositoryProvider._({
    required TelemetryRepositoryFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'telemetryRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$telemetryRepositoryHash();

  @override
  String toString() {
    return r'telemetryRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TelemetryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TelemetryRepository> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return telemetryRepository(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TelemetryRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$telemetryRepositoryHash() =>
    r'8baae84fc84367ad71b8f824994caa106405d312';

final class TelemetryRepositoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TelemetryRepository>,
          TelemetrySource
        > {
  TelemetryRepositoryFamily._()
    : super(
        retry: _neverRetry,
        name: r'telemetryRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TelemetryRepositoryProvider call(TelemetrySource source) =>
      TelemetryRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'telemetryRepositoryProvider';
}

/// Recording discontinuities (§5.2, §15.12).
///
/// Its own provider rather than reached through the session handle, so a
/// screen showing the notice depends on a `List<ClockGap>` it can be given in
/// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
/// connection, and a screen that requires one is a screen only an
/// `integration_test` can cover.

@ProviderFor(sessionClockGaps)
final sessionClockGapsProvider = SessionClockGapsFamily._();

/// Recording discontinuities (§5.2, §15.12).
///
/// Its own provider rather than reached through the session handle, so a
/// screen showing the notice depends on a `List<ClockGap>` it can be given in
/// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
/// connection, and a screen that requires one is a screen only an
/// `integration_test` can cover.

final class SessionClockGapsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClockGap>>,
          List<ClockGap>,
          FutureOr<List<ClockGap>>
        >
    with $FutureModifier<List<ClockGap>>, $FutureProvider<List<ClockGap>> {
  /// Recording discontinuities (§5.2, §15.12).
  ///
  /// Its own provider rather than reached through the session handle, so a
  /// screen showing the notice depends on a `List<ClockGap>` it can be given in
  /// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
  /// connection, and a screen that requires one is a screen only an
  /// `integration_test` can cover.
  SessionClockGapsProvider._({
    required SessionClockGapsFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionClockGapsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionClockGapsHash();

  @override
  String toString() {
    return r'sessionClockGapsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ClockGap>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClockGap>> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionClockGaps(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionClockGapsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionClockGapsHash() => r'5839b8193d698b698fed620983f7ad367a857e9c';

/// Recording discontinuities (§5.2, §15.12).
///
/// Its own provider rather than reached through the session handle, so a
/// screen showing the notice depends on a `List<ClockGap>` it can be given in
/// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
/// connection, and a screen that requires one is a screen only an
/// `integration_test` can cover.

final class SessionClockGapsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ClockGap>>, TelemetrySource> {
  SessionClockGapsFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionClockGapsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Recording discontinuities (§5.2, §15.12).
  ///
  /// Its own provider rather than reached through the session handle, so a
  /// screen showing the notice depends on a `List<ClockGap>` it can be given in
  /// a widget test — a `TelemetrySession` cannot exist without a live DuckDB
  /// connection, and a screen that requires one is a screen only an
  /// `integration_test` can cover.

  SessionClockGapsProvider call(TelemetrySource source) =>
      SessionClockGapsProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionClockGapsProvider';
}

/// Every lap in the session (§8.3).
///
/// Read once and shared rather than re-queried per screen: the lap table, the
/// trace view's lap picker, the track map and the fuel view all need the same
/// list, and the query is small enough that caching it beats coordinating who
/// owns it.

@ProviderFor(laps)
final lapsProvider = LapsFamily._();

/// Every lap in the session (§8.3).
///
/// Read once and shared rather than re-queried per screen: the lap table, the
/// trace view's lap picker, the track map and the fuel view all need the same
/// list, and the query is small enough that caching it beats coordinating who
/// owns it.

final class LapsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Lap>>,
          List<Lap>,
          FutureOr<List<Lap>>
        >
    with $FutureModifier<List<Lap>>, $FutureProvider<List<Lap>> {
  /// Every lap in the session (§8.3).
  ///
  /// Read once and shared rather than re-queried per screen: the lap table, the
  /// trace view's lap picker, the track map and the fuel view all need the same
  /// list, and the query is small enough that caching it beats coordinating who
  /// owns it.
  LapsProvider._({
    required LapsFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapsHash();

  @override
  String toString() {
    return r'lapsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Lap>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Lap>> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return laps(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LapsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapsHash() => r'daa951218926771df21c5645e433048187948900';

/// Every lap in the session (§8.3).
///
/// Read once and shared rather than re-queried per screen: the lap table, the
/// trace view's lap picker, the track map and the fuel view all need the same
/// list, and the query is small enough that caching it beats coordinating who
/// owns it.

final class LapsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Lap>>, TelemetrySource> {
  LapsFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Every lap in the session (§8.3).
  ///
  /// Read once and shared rather than re-queried per screen: the lap table, the
  /// trace view's lap picker, the track map and the fuel view all need the same
  /// list, and the query is small enough that caching it beats coordinating who
  /// owns it.

  LapsProvider call(TelemetrySource source) =>
      LapsProvider._(argument: source, from: this);

  @override
  String toString() => r'lapsProvider';
}

/// Every recorded change in the session, in time order (§8.12).
///
/// Session-scoped rather than window-scoped because the Events Log is a
/// filtering view over the whole recording, and the whole recording is small:
/// 4,280–20,304 rows across all 42 tables in the three real samples, read in
/// 62 ms. Filtering happens in Dart over the loaded list, so changing the
/// filter costs nothing and re-querying per keystroke never arises.

@ProviderFor(sessionEventLog)
final sessionEventLogProvider = SessionEventLogFamily._();

/// Every recorded change in the session, in time order (§8.12).
///
/// Session-scoped rather than window-scoped because the Events Log is a
/// filtering view over the whole recording, and the whole recording is small:
/// 4,280–20,304 rows across all 42 tables in the three real samples, read in
/// 62 ms. Filtering happens in Dart over the loaded list, so changing the
/// filter costs nothing and re-querying per keystroke never arises.

final class SessionEventLogProvider
    extends
        $FunctionalProvider<AsyncValue<EventLog>, EventLog, FutureOr<EventLog>>
    with $FutureModifier<EventLog>, $FutureProvider<EventLog> {
  /// Every recorded change in the session, in time order (§8.12).
  ///
  /// Session-scoped rather than window-scoped because the Events Log is a
  /// filtering view over the whole recording, and the whole recording is small:
  /// 4,280–20,304 rows across all 42 tables in the three real samples, read in
  /// 62 ms. Filtering happens in Dart over the loaded list, so changing the
  /// filter costs nothing and re-querying per keystroke never arises.
  SessionEventLogProvider._({
    required SessionEventLogFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionEventLogProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionEventLogHash();

  @override
  String toString() {
    return r'sessionEventLogProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<EventLog> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<EventLog> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionEventLog(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionEventLogProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionEventLogHash() => r'f08cb56cd558440acce593ed8102d2e7c012f4b7';

/// Every recorded change in the session, in time order (§8.12).
///
/// Session-scoped rather than window-scoped because the Events Log is a
/// filtering view over the whole recording, and the whole recording is small:
/// 4,280–20,304 rows across all 42 tables in the three real samples, read in
/// 62 ms. Filtering happens in Dart over the loaded list, so changing the
/// filter costs nothing and re-querying per keystroke never arises.

final class SessionEventLogFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<EventLog>, TelemetrySource> {
  SessionEventLogFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionEventLogProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Every recorded change in the session, in time order (§8.12).
  ///
  /// Session-scoped rather than window-scoped because the Events Log is a
  /// filtering view over the whole recording, and the whole recording is small:
  /// 4,280–20,304 rows across all 42 tables in the three real samples, read in
  /// 62 ms. Filtering happens in Dart over the loaded list, so changing the
  /// filter costs nothing and re-querying per keystroke never arises.

  SessionEventLogProvider call(TelemetrySource source) =>
      SessionEventLogProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionEventLogProvider';
}
