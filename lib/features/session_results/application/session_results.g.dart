// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_results.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(resultsIndexStore)
final resultsIndexStoreProvider = ResultsIndexStoreProvider._();

final class ResultsIndexStoreProvider
    extends
        $FunctionalProvider<
          ResultsIndexStore,
          ResultsIndexStore,
          ResultsIndexStore
        >
    with $Provider<ResultsIndexStore> {
  ResultsIndexStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsIndexStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsIndexStoreHash();

  @$internal
  @override
  $ProviderElement<ResultsIndexStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResultsIndexStore create(Ref ref) {
    return resultsIndexStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResultsIndexStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResultsIndexStore>(value),
    );
  }
}

String _$resultsIndexStoreHash() => r'ec3c11072a01c36147f39c649605f6c5f1694495';

@ProviderFor(resultsFileSystem)
final resultsFileSystemProvider = ResultsFileSystemProvider._();

final class ResultsFileSystemProvider
    extends
        $FunctionalProvider<
          ResultsFileSystem,
          ResultsFileSystem,
          ResultsFileSystem
        >
    with $Provider<ResultsFileSystem> {
  ResultsFileSystemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsFileSystemProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsFileSystemHash();

  @$internal
  @override
  $ProviderElement<ResultsFileSystem> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResultsFileSystem create(Ref ref) {
    return resultsFileSystem(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResultsFileSystem value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResultsFileSystem>(value),
    );
  }
}

String _$resultsFileSystemHash() => r'5553c3b4ac4dfafd9c16e2e0be9e2d1369c8b26e';

/// [parseResultsBytes] on another isolate: the 24-hour race's 8.6 MB takes
/// half a second to parse, which would be thirty dropped frames on the UI
/// thread. A provider so a widget test can parse in its own zone.

@ProviderFor(resultsParser)
final resultsParserProvider = ResultsParserProvider._();

/// [parseResultsBytes] on another isolate: the 24-hour race's 8.6 MB takes
/// half a second to parse, which would be thirty dropped frames on the UI
/// thread. A provider so a widget test can parse in its own zone.

final class ResultsParserProvider
    extends $FunctionalProvider<ResultsParser, ResultsParser, ResultsParser>
    with $Provider<ResultsParser> {
  /// [parseResultsBytes] on another isolate: the 24-hour race's 8.6 MB takes
  /// half a second to parse, which would be thirty dropped frames on the UI
  /// thread. A provider so a widget test can parse in its own zone.
  ResultsParserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsParserProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsParserHash();

  @$internal
  @override
  $ProviderElement<ResultsParser> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ResultsParser create(Ref ref) {
    return resultsParser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResultsParser value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResultsParser>(value),
    );
  }
}

String _$resultsParserHash() => r'357f2dd6ed465d78f4a41862ed4422cd26eea8aa';

/// Moves whenever the index's content does, so everything read from it
/// (each row's link) is read again. Bumped once per scan, not per file: a
/// thousand files would otherwise re-link every visible row a thousand times.

@ProviderFor(ResultsIndexRevision)
final resultsIndexRevisionProvider = ResultsIndexRevisionProvider._();

/// Moves whenever the index's content does, so everything read from it
/// (each row's link) is read again. Bumped once per scan, not per file: a
/// thousand files would otherwise re-link every visible row a thousand times.
final class ResultsIndexRevisionProvider
    extends $NotifierProvider<ResultsIndexRevision, int> {
  /// Moves whenever the index's content does, so everything read from it
  /// (each row's link) is read again. Bumped once per scan, not per file: a
  /// thousand files would otherwise re-link every visible row a thousand times.
  ResultsIndexRevisionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsIndexRevisionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsIndexRevisionHash();

  @$internal
  @override
  ResultsIndexRevision create() => ResultsIndexRevision();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$resultsIndexRevisionHash() =>
    r'7c545dadcfee8c6d42e195098d26700982e3f097';

/// Moves whenever the index's content does, so everything read from it
/// (each row's link) is read again. Bumped once per scan, not per file: a
/// thousand files would otherwise re-link every visible row a thousand times.

abstract class _$ResultsIndexRevision extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Remembered results folders, oldest first.

@ProviderFor(ResultsFolders)
final resultsFoldersProvider = ResultsFoldersProvider._();

/// Remembered results folders, oldest first.
final class ResultsFoldersProvider
    extends $AsyncNotifierProvider<ResultsFolders, List<LibraryFolder>> {
  /// Remembered results folders, oldest first.
  ResultsFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'resultsFoldersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsFoldersHash();

  @$internal
  @override
  ResultsFolders create() => ResultsFolders();
}

String _$resultsFoldersHash() => r'e70a0510c81ddeebdfef7290cc112ec8f7d2dba7';

/// Remembered results folders, oldest first.

abstract class _$ResultsFolders extends $AsyncNotifier<List<LibraryFolder>> {
  FutureOr<List<LibraryFolder>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<LibraryFolder>>, List<LibraryFolder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<LibraryFolder>>, List<LibraryFolder>>,
              AsyncValue<List<LibraryFolder>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// LMU's results folder, when it exists and isn't remembered yet: the one
/// beside a remembered telemetry folder of the same install first, then
/// the default Steam location.

@ProviderFor(suggestedResultsFolder)
final suggestedResultsFolderProvider = SuggestedResultsFolderProvider._();

/// LMU's results folder, when it exists and isn't remembered yet: the one
/// beside a remembered telemetry folder of the same install first, then
/// the default Steam location.

final class SuggestedResultsFolderProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// LMU's results folder, when it exists and isn't remembered yet: the one
  /// beside a remembered telemetry folder of the same install first, then
  /// the default Steam location.
  SuggestedResultsFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'suggestedResultsFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestedResultsFolderHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return suggestedResultsFolder(ref);
  }
}

String _$suggestedResultsFolderHash() =>
    r'6ae89d3b46c91615eb33ca7326a24728c3009bac';

/// The results session [entry]'s recording was made in, or null.
///
/// Checked per row when the row is built, like the file's status: a store
/// query narrowed to one track, one kind and a few minutes, then
/// [linkRecording]. No recording is opened.

@ProviderFor(resultsLink)
final resultsLinkProvider = ResultsLinkFamily._();

/// The results session [entry]'s recording was made in, or null.
///
/// Checked per row when the row is built, like the file's status: a store
/// query narrowed to one track, one kind and a few minutes, then
/// [linkRecording]. No recording is opened.

final class ResultsLinkProvider
    extends
        $FunctionalProvider<
          AsyncValue<ResultsLink?>,
          ResultsLink?,
          FutureOr<ResultsLink?>
        >
    with $FutureModifier<ResultsLink?>, $FutureProvider<ResultsLink?> {
  /// The results session [entry]'s recording was made in, or null.
  ///
  /// Checked per row when the row is built, like the file's status: a store
  /// query narrowed to one track, one kind and a few minutes, then
  /// [linkRecording]. No recording is opened.
  ResultsLinkProvider._({
    required ResultsLinkFamily super.from,
    required LibraryEntry super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'resultsLinkProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$resultsLinkHash();

  @override
  String toString() {
    return r'resultsLinkProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ResultsLink?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ResultsLink?> create(Ref ref) {
    final argument = this.argument as LibraryEntry;
    return resultsLink(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ResultsLinkProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$resultsLinkHash() => r'34ed2374dc4b94145d66b216a297d42c816e570a';

/// The results session [entry]'s recording was made in, or null.
///
/// Checked per row when the row is built, like the file's status: a store
/// query narrowed to one track, one kind and a few minutes, then
/// [linkRecording]. No recording is opened.

final class ResultsLinkFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ResultsLink?>, LibraryEntry> {
  ResultsLinkFamily._()
    : super(
        retry: _neverRetry,
        name: r'resultsLinkProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The results session [entry]'s recording was made in, or null.
  ///
  /// Checked per row when the row is built, like the file's status: a store
  /// query narrowed to one track, one kind and a few minutes, then
  /// [linkRecording]. No recording is opened.

  ResultsLinkProvider call(LibraryEntry entry) =>
      ResultsLinkProvider._(argument: entry, from: this);

  @override
  String toString() => r'resultsLinkProvider';
}

/// Reads remembered results folders into the index.
///
/// On demand, like the telemetry scan: when the folder is added and on
/// Refresh. LMU writes a results file once, when a session ends, so there is
/// nothing to watch for. Files whose size and mtime match the index are
/// skipped without being opened, so a Refresh after one session reads one
/// file.

@ProviderFor(ResultsScan)
final resultsScanProvider = ResultsScanProvider._();

/// Reads remembered results folders into the index.
///
/// On demand, like the telemetry scan: when the folder is added and on
/// Refresh. LMU writes a results file once, when a session ends, so there is
/// nothing to watch for. Files whose size and mtime match the index are
/// skipped without being opened, so a Refresh after one session reads one
/// file.
final class ResultsScanProvider
    extends $NotifierProvider<ResultsScan, ResultsScanState> {
  /// Reads remembered results folders into the index.
  ///
  /// On demand, like the telemetry scan: when the folder is added and on
  /// Refresh. LMU writes a results file once, when a session ends, so there is
  /// nothing to watch for. Files whose size and mtime match the index are
  /// skipped without being opened, so a Refresh after one session reads one
  /// file.
  ResultsScanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resultsScanProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resultsScanHash();

  @$internal
  @override
  ResultsScan create() => ResultsScan();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResultsScanState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResultsScanState>(value),
    );
  }
}

String _$resultsScanHash() => r'818faf1cfd10fc3eaf6bd9bbe5650278ac13bec6';

/// Reads remembered results folders into the index.
///
/// On demand, like the telemetry scan: when the folder is added and on
/// Refresh. LMU writes a results file once, when a session ends, so there is
/// nothing to watch for. Files whose size and mtime match the index are
/// skipped without being opened, so a Refresh after one session reads one
/// file.

abstract class _$ResultsScan extends $Notifier<ResultsScanState> {
  ResultsScanState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ResultsScanState, ResultsScanState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ResultsScanState, ResultsScanState>,
              ResultsScanState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
