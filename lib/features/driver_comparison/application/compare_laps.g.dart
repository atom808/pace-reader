// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_laps.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [readComparableFactsBriefly], as a provider so a test can serve a file
/// without a DuckDB connection.

@ProviderFor(comparableFactsReader)
final comparableFactsReaderProvider = ComparableFactsReaderProvider._();

/// [readComparableFactsBriefly], as a provider so a test can serve a file
/// without a DuckDB connection.

final class ComparableFactsReaderProvider
    extends
        $FunctionalProvider<
          ComparableFactsReader,
          ComparableFactsReader,
          ComparableFactsReader
        >
    with $Provider<ComparableFactsReader> {
  /// [readComparableFactsBriefly], as a provider so a test can serve a file
  /// without a DuckDB connection.
  ComparableFactsReaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comparableFactsReaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comparableFactsReaderHash();

  @$internal
  @override
  $ProviderElement<ComparableFactsReader> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ComparableFactsReader create(Ref ref) {
    return comparableFactsReader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComparableFactsReader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComparableFactsReader>(value),
    );
  }
}

String _$comparableFactsReaderHash() =>
    r'f942e8a6cedd16f1dbd8fdaf3b01d9b439400e1e';

/// [source]'s facts: from its open session when it is in Open now, and
/// briefly otherwise — never by opening a kept-alive session for it.

@ProviderFor(comparableFile)
final comparableFileProvider = ComparableFileFamily._();

/// [source]'s facts: from its open session when it is in Open now, and
/// briefly otherwise — never by opening a kept-alive session for it.

final class ComparableFileProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComparableFile>,
          ComparableFile,
          FutureOr<ComparableFile>
        >
    with $FutureModifier<ComparableFile>, $FutureProvider<ComparableFile> {
  /// [source]'s facts: from its open session when it is in Open now, and
  /// briefly otherwise — never by opening a kept-alive session for it.
  ComparableFileProvider._({
    required ComparableFileFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'comparableFileProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comparableFileHash();

  @override
  String toString() {
    return r'comparableFileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ComparableFile> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComparableFile> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return comparableFile(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComparableFileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comparableFileHash() => r'cae2ba454fec9c4aca39a784d9eac3974377bad1';

/// [source]'s facts: from its open session when it is in Open now, and
/// briefly otherwise — never by opening a kept-alive session for it.

final class ComparableFileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ComparableFile>, TelemetrySource> {
  ComparableFileFamily._()
    : super(
        retry: _neverRetry,
        name: r'comparableFileProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [source]'s facts: from its open session when it is in Open now, and
  /// briefly otherwise — never by opening a kept-alive session for it.

  ComparableFileProvider call(TelemetrySource source) =>
      ComparableFileProvider._(argument: source, from: this);

  @override
  String toString() => r'comparableFileProvider';
}
