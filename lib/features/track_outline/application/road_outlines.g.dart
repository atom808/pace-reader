// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'road_outlines.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [readEdgeBinsBriefly], as a provider so a test can serve edges without a
/// DuckDB connection.

@ProviderFor(edgeBinsReader)
final edgeBinsReaderProvider = EdgeBinsReaderProvider._();

/// [readEdgeBinsBriefly], as a provider so a test can serve edges without a
/// DuckDB connection.

final class EdgeBinsReaderProvider
    extends $FunctionalProvider<EdgeBinsReader, EdgeBinsReader, EdgeBinsReader>
    with $Provider<EdgeBinsReader> {
  /// [readEdgeBinsBriefly], as a provider so a test can serve edges without a
  /// DuckDB connection.
  EdgeBinsReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'edgeBinsReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$edgeBinsReaderHash();

  @$internal
  @override
  $ProviderElement<EdgeBinsReader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  EdgeBinsReader create(Ref ref) {
    return edgeBinsReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EdgeBinsReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EdgeBinsReader>(value),
    );
  }
}

String _$edgeBinsReaderHash() => r'770c00d78f72f1a76d59afdd1571b092540c1797';

@ProviderFor(outlineCacheStore)
final outlineCacheStoreProvider = OutlineCacheStoreProvider._();

final class OutlineCacheStoreProvider
    extends
        $FunctionalProvider<
          OutlineCacheStore,
          OutlineCacheStore,
          OutlineCacheStore
        >
    with $Provider<OutlineCacheStore> {
  OutlineCacheStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outlineCacheStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outlineCacheStoreHash();

  @$internal
  @override
  $ProviderElement<OutlineCacheStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutlineCacheStore create(Ref ref) {
    return outlineCacheStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutlineCacheStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutlineCacheStore>(value),
    );
  }
}

String _$outlineCacheStoreHash() => r'8aa41ce6b0d1b698bf9346b1a72fa492a4fb6aa6';

/// The library's outline of a layout, filled in as its recordings are read.
///
/// Kept alive and cached on disk: reading a layout's recordings takes a
/// while the first time (a second or so each), so they are read one at a
/// time in the background and the band grows as they land; later runs read
/// only recordings the cache has not seen. A recording that changed or left
/// the library starts the pool again, since a sum can't take one back out.

@ProviderFor(LibraryOutline)
final libraryOutlineProvider = LibraryOutlineFamily._();

/// The library's outline of a layout, filled in as its recordings are read.
///
/// Kept alive and cached on disk: reading a layout's recordings takes a
/// while the first time (a second or so each), so they are read one at a
/// time in the background and the band grows as they land; later runs read
/// only recordings the cache has not seen. A recording that changed or left
/// the library starts the pool again, since a sum can't take one back out.
final class LibraryOutlineProvider
    extends $NotifierProvider<LibraryOutline, PooledOutline> {
  /// The library's outline of a layout, filled in as its recordings are read.
  ///
  /// Kept alive and cached on disk: reading a layout's recordings takes a
  /// while the first time (a second or so each), so they are read one at a
  /// time in the background and the band grows as they land; later runs read
  /// only recordings the cache has not seen. A recording that changed or left
  /// the library starts the pool again, since a sum can't take one back out.
  LibraryOutlineProvider._({
    required LibraryOutlineFamily super.from,
    required TrackKey super.argument,
  }) : super(
         retry: null,
         name: r'libraryOutlineProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryOutlineHash();

  @override
  String toString() {
    return r'libraryOutlineProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LibraryOutline create() => LibraryOutline();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PooledOutline value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PooledOutline>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryOutlineProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryOutlineHash() => r'49ec039663d780c4667d819579c4831749224b0e';

/// The library's outline of a layout, filled in as its recordings are read.
///
/// Kept alive and cached on disk: reading a layout's recordings takes a
/// while the first time (a second or so each), so they are read one at a
/// time in the background and the band grows as they land; later runs read
/// only recordings the cache has not seen. A recording that changed or left
/// the library starts the pool again, since a sum can't take one back out.

final class LibraryOutlineFamily extends $Family
    with
        $ClassFamilyOverride<
          LibraryOutline,
          PooledOutline,
          PooledOutline,
          PooledOutline,
          TrackKey
        > {
  LibraryOutlineFamily._()
    : super(
        retry: null,
        name: r'libraryOutlineProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The library's outline of a layout, filled in as its recordings are read.
  ///
  /// Kept alive and cached on disk: reading a layout's recordings takes a
  /// while the first time (a second or so each), so they are read one at a
  /// time in the background and the band grows as they land; later runs read
  /// only recordings the cache has not seen. A recording that changed or left
  /// the library starts the pool again, since a sum can't take one back out.

  LibraryOutlineProvider call(TrackKey layout) =>
      LibraryOutlineProvider._(argument: layout, from: this);

  @override
  String toString() => r'libraryOutlineProvider';
}

/// The library's outline of a layout, filled in as its recordings are read.
///
/// Kept alive and cached on disk: reading a layout's recordings takes a
/// while the first time (a second or so each), so they are read one at a
/// time in the background and the band grows as they land; later runs read
/// only recordings the cache has not seen. A recording that changed or left
/// the library starts the pool again, since a sum can't take one back out.

abstract class _$LibraryOutline extends $Notifier<PooledOutline> {
  late final _$args = ref.$arg as TrackKey;
  TrackKey get layout => _$args;

  PooledOutline build(TrackKey layout);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PooledOutline, PooledOutline>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PooledOutline, PooledOutline>,
              PooledOutline,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// How far either side this session's laps went, as an outline: the band
/// for a layout the library hardly knows.
///
/// Only for a file in Open now that is still on disk: the band never opens
/// a file of its own (Compare's rule, `compare_source_guard.dart`).

@ProviderFor(sessionEnvelope)
final sessionEnvelopeProvider = SessionEnvelopeFamily._();

/// How far either side this session's laps went, as an outline: the band
/// for a layout the library hardly knows.
///
/// Only for a file in Open now that is still on disk: the band never opens
/// a file of its own (Compare's rule, `compare_source_guard.dart`).

final class SessionEnvelopeProvider
    extends
        $FunctionalProvider<
          AsyncValue<TrackOutline?>,
          TrackOutline?,
          FutureOr<TrackOutline?>
        >
    with $FutureModifier<TrackOutline?>, $FutureProvider<TrackOutline?> {
  /// How far either side this session's laps went, as an outline: the band
  /// for a layout the library hardly knows.
  ///
  /// Only for a file in Open now that is still on disk: the band never opens
  /// a file of its own (Compare's rule, `compare_source_guard.dart`).
  SessionEnvelopeProvider._({
    required SessionEnvelopeFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionEnvelopeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionEnvelopeHash();

  @override
  String toString() {
    return r'sessionEnvelopeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TrackOutline?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TrackOutline?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionEnvelope(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionEnvelopeProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionEnvelopeHash() => r'fd50f9a0967c2d3763de060c13dc53f0410fcaf9';

/// How far either side this session's laps went, as an outline: the band
/// for a layout the library hardly knows.
///
/// Only for a file in Open now that is still on disk: the band never opens
/// a file of its own (Compare's rule, `compare_source_guard.dart`).

final class SessionEnvelopeFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TrackOutline?>, TelemetrySource> {
  SessionEnvelopeFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionEnvelopeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// How far either side this session's laps went, as an outline: the band
  /// for a layout the library hardly knows.
  ///
  /// Only for a file in Open now that is still on disk: the band never opens
  /// a file of its own (Compare's rule, `compare_source_guard.dart`).

  SessionEnvelopeProvider call(TelemetrySource source) =>
      SessionEnvelopeProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionEnvelopeProvider';
}

@ProviderFor(roadOutlines)
final roadOutlinesProvider = RoadOutlinesFamily._();

final class RoadOutlinesProvider
    extends
        $FunctionalProvider<
          AsyncValue<RoadOutlines>,
          RoadOutlines,
          FutureOr<RoadOutlines>
        >
    with $FutureModifier<RoadOutlines>, $FutureProvider<RoadOutlines> {
  RoadOutlinesProvider._({
    required RoadOutlinesFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'roadOutlinesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$roadOutlinesHash();

  @override
  String toString() {
    return r'roadOutlinesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RoadOutlines> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RoadOutlines> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return roadOutlines(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RoadOutlinesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$roadOutlinesHash() => r'c0841c99729ca048a01ef87e231af599a79158cd';

final class RoadOutlinesFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RoadOutlines>, TelemetrySource> {
  RoadOutlinesFamily._()
    : super(
        retry: _neverRetry,
        name: r'roadOutlinesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  RoadOutlinesProvider call(TelemetrySource source) =>
      RoadOutlinesProvider._(argument: source, from: this);

  @override
  String toString() => r'roadOutlinesProvider';
}
