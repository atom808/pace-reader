// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_library.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The index's storage: drift on desktop, memory on web (see
/// [MemorySessionIndexStore] for why). Overridden in tests.

@ProviderFor(sessionIndexStore)
final sessionIndexStoreProvider = SessionIndexStoreProvider._();

/// The index's storage: drift on desktop, memory on web (see
/// [MemorySessionIndexStore] for why). Overridden in tests.

final class SessionIndexStoreProvider
    extends
        $FunctionalProvider<
          SessionIndexStore,
          SessionIndexStore,
          SessionIndexStore
        >
    with $Provider<SessionIndexStore> {
  /// The index's storage: drift on desktop, memory on web (see
  /// [MemorySessionIndexStore] for why). Overridden in tests.
  SessionIndexStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionIndexStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionIndexStoreHash();

  @$internal
  @override
  $ProviderElement<SessionIndexStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionIndexStore create(Ref ref) {
    return sessionIndexStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionIndexStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionIndexStore>(value),
    );
  }
}

String _$sessionIndexStoreHash() => r'4f267e1899f8a4a7d8bfa90493e24823b3cb8e77';

@ProviderFor(sessionFileSystem)
final sessionFileSystemProvider = SessionFileSystemProvider._();

final class SessionFileSystemProvider
    extends
        $FunctionalProvider<
          SessionFileSystem,
          SessionFileSystem,
          SessionFileSystem
        >
    with $Provider<SessionFileSystem> {
  SessionFileSystemProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionFileSystemProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionFileSystemHash();

  @$internal
  @override
  $ProviderElement<SessionFileSystem> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionFileSystem create(Ref ref) {
    return sessionFileSystem(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionFileSystem value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionFileSystem>(value),
    );
  }
}

String _$sessionFileSystemHash() => r'93a0ff50ee34fe2133f57bf2631945cc9b0fcf94';

/// The folder scan's reader: [readSessionFactsBriefly]. A provider so a test
/// can hand the scan real numbers without a DuckDB connection.

@ProviderFor(sessionFactsReader)
final sessionFactsReaderProvider = SessionFactsReaderProvider._();

/// The folder scan's reader: [readSessionFactsBriefly]. A provider so a test
/// can hand the scan real numbers without a DuckDB connection.

final class SessionFactsReaderProvider
    extends
        $FunctionalProvider<
          SessionFactsReader,
          SessionFactsReader,
          SessionFactsReader
        >
    with $Provider<SessionFactsReader> {
  /// The folder scan's reader: [readSessionFactsBriefly]. A provider so a test
  /// can hand the scan real numbers without a DuckDB connection.
  SessionFactsReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionFactsReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionFactsReaderHash();

  @$internal
  @override
  $ProviderElement<SessionFactsReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionFactsReader create(Ref ref) {
    return sessionFactsReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionFactsReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionFactsReader>(value),
    );
  }
}

String _$sessionFactsReaderHash() =>
    r'22ca257f2238758e789f95b4c4d9085d122ba5a5';

/// "Now", injectable so "scanned 3 min ago" and `importedAt` are
/// deterministic under test.

@ProviderFor(libraryClock)
final libraryClockProvider = LibraryClockProvider._();

/// "Now", injectable so "scanned 3 min ago" and `importedAt` are
/// deterministic under test.

final class LibraryClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// "Now", injectable so "scanned 3 min ago" and `importedAt` are
  /// deterministic under test.
  LibraryClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return libraryClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$libraryClockHash() => r'0cd34bcc6cd07ac0039e39e5a5ae2b99cfb04cdd';

/// Every indexed session, newest recording first.

@ProviderFor(SessionLibrary)
final sessionLibraryProvider = SessionLibraryProvider._();

/// Every indexed session, newest recording first.
final class SessionLibraryProvider
    extends $AsyncNotifierProvider<SessionLibrary, List<LibraryEntry>> {
  /// Every indexed session, newest recording first.
  SessionLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'sessionLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionLibraryHash();

  @$internal
  @override
  SessionLibrary create() => SessionLibrary();
}

String _$sessionLibraryHash() => r'203f20f942d7dff1abf308841d0f78acb946e05b';

/// Every indexed session, newest recording first.

abstract class _$SessionLibrary extends $AsyncNotifier<List<LibraryEntry>> {
  FutureOr<List<LibraryEntry>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<LibraryEntry>>, List<LibraryEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<LibraryEntry>>, List<LibraryEntry>>,
              AsyncValue<List<LibraryEntry>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Remembered scan folders, oldest first.

@ProviderFor(LibraryFolders)
final libraryFoldersProvider = LibraryFoldersProvider._();

/// Remembered scan folders, oldest first.
final class LibraryFoldersProvider
    extends $AsyncNotifierProvider<LibraryFolders, List<LibraryFolder>> {
  /// Remembered scan folders, oldest first.
  LibraryFoldersProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'libraryFoldersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFoldersHash();

  @$internal
  @override
  LibraryFolders create() => LibraryFolders();
}

String _$libraryFoldersHash() => r'0c5fd8bca6be1ed8abfdc93267ca200e1e6f3559';

/// Remembered scan folders, oldest first.

abstract class _$LibraryFolders extends $AsyncNotifier<List<LibraryFolder>> {
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

/// The search box and chips. Kept alive so leaving for the Overview and
/// coming back finds the list as it was left.

@ProviderFor(LibraryFilter)
final libraryFilterProvider = LibraryFilterProvider._();

/// The search box and chips. Kept alive so leaving for the Overview and
/// coming back finds the list as it was left.
final class LibraryFilterProvider
    extends $NotifierProvider<LibraryFilter, LibraryQuery> {
  /// The search box and chips. Kept alive so leaving for the Overview and
  /// coming back finds the list as it was left.
  LibraryFilterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryFilterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryFilterHash();

  @$internal
  @override
  LibraryFilter create() => LibraryFilter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryQuery value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryQuery>(value),
    );
  }
}

String _$libraryFilterHash() => r'813d94eb2a0e064e8d2ec46c64a0baaa0c229465';

/// The search box and chips. Kept alive so leaving for the Overview and
/// coming back finds the list as it was left.

abstract class _$LibraryFilter extends $Notifier<LibraryQuery> {
  LibraryQuery build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibraryQuery, LibraryQuery>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibraryQuery, LibraryQuery>,
              LibraryQuery,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Synchronous over the library's [AsyncValue] rather than a
/// `FutureProvider`, so a keystroke in the search box re-filters in the same
/// frame instead of passing through a loading state first.

@ProviderFor(libraryView)
final libraryViewProvider = LibraryViewProvider._();

/// Synchronous over the library's [AsyncValue] rather than a
/// `FutureProvider`, so a keystroke in the search box re-filters in the same
/// frame instead of passing through a loading state first.

final class LibraryViewProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryView>,
          AsyncValue<LibraryView>,
          AsyncValue<LibraryView>
        >
    with $Provider<AsyncValue<LibraryView>> {
  /// Synchronous over the library's [AsyncValue] rather than a
  /// `FutureProvider`, so a keystroke in the search box re-filters in the same
  /// frame instead of passing through a loading state first.
  LibraryViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryViewProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryViewHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<LibraryView>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<LibraryView> create(Ref ref) {
    return libraryView(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<LibraryView> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<LibraryView>>(value),
    );
  }
}

String _$libraryViewHash() => r'aed20bd0cee6b621d3864a97e7977bec19460cd5';

/// Checked per row, lazily, when the row is built — a `stat`, never an open.
///
/// Family-keyed on the entry itself rather than its path, so re-indexing a
/// file (a new size/mtime) is a new key and the status is re-checked rather
/// than served stale.

@ProviderFor(libraryFileStatus)
final libraryFileStatusProvider = LibraryFileStatusFamily._();

/// Checked per row, lazily, when the row is built — a `stat`, never an open.
///
/// Family-keyed on the entry itself rather than its path, so re-indexing a
/// file (a new size/mtime) is a new key and the status is re-checked rather
/// than served stale.

final class LibraryFileStatusProvider
    extends
        $FunctionalProvider<
          AsyncValue<LibraryFileStatus>,
          LibraryFileStatus,
          FutureOr<LibraryFileStatus>
        >
    with
        $FutureModifier<LibraryFileStatus>,
        $FutureProvider<LibraryFileStatus> {
  /// Checked per row, lazily, when the row is built — a `stat`, never an open.
  ///
  /// Family-keyed on the entry itself rather than its path, so re-indexing a
  /// file (a new size/mtime) is a new key and the status is re-checked rather
  /// than served stale.
  LibraryFileStatusProvider._({
    required LibraryFileStatusFamily super.from,
    required LibraryEntry super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'libraryFileStatusProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$libraryFileStatusHash();

  @override
  String toString() {
    return r'libraryFileStatusProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<LibraryFileStatus> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LibraryFileStatus> create(Ref ref) {
    final argument = this.argument as LibraryEntry;
    return libraryFileStatus(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryFileStatusProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$libraryFileStatusHash() => r'67b9c869bbf85350521e5c4fe2dc3c342eff3402';

/// Checked per row, lazily, when the row is built — a `stat`, never an open.
///
/// Family-keyed on the entry itself rather than its path, so re-indexing a
/// file (a new size/mtime) is a new key and the status is re-checked rather
/// than served stale.

final class LibraryFileStatusFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LibraryFileStatus>, LibraryEntry> {
  LibraryFileStatusFamily._()
    : super(
        retry: _neverRetry,
        name: r'libraryFileStatusProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Checked per row, lazily, when the row is built — a `stat`, never an open.
  ///
  /// Family-keyed on the entry itself rather than its path, so re-indexing a
  /// file (a new size/mtime) is a new key and the status is re-checked rather
  /// than served stale.

  LibraryFileStatusProvider call(LibraryEntry entry) =>
      LibraryFileStatusProvider._(argument: entry, from: this);

  @override
  String toString() => r'libraryFileStatusProvider';
}

/// LMU's default folder, when it exists here and isn't remembered yet.

@ProviderFor(suggestedTelemetryFolder)
final suggestedTelemetryFolderProvider = SuggestedTelemetryFolderProvider._();

/// LMU's default folder, when it exists here and isn't remembered yet.

final class SuggestedTelemetryFolderProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// LMU's default folder, when it exists here and isn't remembered yet.
  SuggestedTelemetryFolderProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'suggestedTelemetryFolderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestedTelemetryFolderHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return suggestedTelemetryFolder(ref);
  }
}

String _$suggestedTelemetryFolderHash() =>
    r'ae0b18de5e0e8c86206cc827e0cf9e44de975732';
