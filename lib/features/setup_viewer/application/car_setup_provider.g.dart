// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_setup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The session's car setup, parsed.
///
/// Built on [sessionMetadataProvider] rather than a query of its own: the
/// `CarSetup` JSON is one of the twelve `metadata` rows the session already
/// reads when it opens, so the Setup Viewer adds no SQL and no second pass
/// over the file. Its own provider, rather than a parse inside the screen, so
/// a widget test hands the screen a [CarSetup] built from a real sample's JSON
/// without a DuckDB connection, and so switching sections and back does not
/// re-parse 38 kB.
///
/// A blank entry yields [CarSetup.empty], which the screen states rather than
/// draws blank; text that is not a JSON object surfaces as a
/// [SetupFormatException] through the usual error state.

@ProviderFor(carSetup)
final carSetupProvider = CarSetupFamily._();

/// The session's car setup, parsed.
///
/// Built on [sessionMetadataProvider] rather than a query of its own: the
/// `CarSetup` JSON is one of the twelve `metadata` rows the session already
/// reads when it opens, so the Setup Viewer adds no SQL and no second pass
/// over the file. Its own provider, rather than a parse inside the screen, so
/// a widget test hands the screen a [CarSetup] built from a real sample's JSON
/// without a DuckDB connection, and so switching sections and back does not
/// re-parse 38 kB.
///
/// A blank entry yields [CarSetup.empty], which the screen states rather than
/// draws blank; text that is not a JSON object surfaces as a
/// [SetupFormatException] through the usual error state.

final class CarSetupProvider
    extends
        $FunctionalProvider<AsyncValue<CarSetup>, CarSetup, FutureOr<CarSetup>>
    with $FutureModifier<CarSetup>, $FutureProvider<CarSetup> {
  /// The session's car setup, parsed.
  ///
  /// Built on [sessionMetadataProvider] rather than a query of its own: the
  /// `CarSetup` JSON is one of the twelve `metadata` rows the session already
  /// reads when it opens, so the Setup Viewer adds no SQL and no second pass
  /// over the file. Its own provider, rather than a parse inside the screen, so
  /// a widget test hands the screen a [CarSetup] built from a real sample's JSON
  /// without a DuckDB connection, and so switching sections and back does not
  /// re-parse 38 kB.
  ///
  /// A blank entry yields [CarSetup.empty], which the screen states rather than
  /// draws blank; text that is not a JSON object surfaces as a
  /// [SetupFormatException] through the usual error state.
  CarSetupProvider._({
    required CarSetupFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'carSetupProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$carSetupHash();

  @override
  String toString() {
    return r'carSetupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CarSetup> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CarSetup> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return carSetup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CarSetupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$carSetupHash() => r'8ec689ac747a8e56705db1c31d4f0648ce7ddc7c';

/// The session's car setup, parsed.
///
/// Built on [sessionMetadataProvider] rather than a query of its own: the
/// `CarSetup` JSON is one of the twelve `metadata` rows the session already
/// reads when it opens, so the Setup Viewer adds no SQL and no second pass
/// over the file. Its own provider, rather than a parse inside the screen, so
/// a widget test hands the screen a [CarSetup] built from a real sample's JSON
/// without a DuckDB connection, and so switching sections and back does not
/// re-parse 38 kB.
///
/// A blank entry yields [CarSetup.empty], which the screen states rather than
/// draws blank; text that is not a JSON object surfaces as a
/// [SetupFormatException] through the usual error state.

final class CarSetupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CarSetup>, TelemetrySource> {
  CarSetupFamily._()
    : super(
        retry: _neverRetry,
        name: r'carSetupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The session's car setup, parsed.
  ///
  /// Built on [sessionMetadataProvider] rather than a query of its own: the
  /// `CarSetup` JSON is one of the twelve `metadata` rows the session already
  /// reads when it opens, so the Setup Viewer adds no SQL and no second pass
  /// over the file. Its own provider, rather than a parse inside the screen, so
  /// a widget test hands the screen a [CarSetup] built from a real sample's JSON
  /// without a DuckDB connection, and so switching sections and back does not
  /// re-parse 38 kB.
  ///
  /// A blank entry yields [CarSetup.empty], which the screen states rather than
  /// draws blank; text that is not a JSON object surfaces as a
  /// [SetupFormatException] through the usual error state.

  CarSetupProvider call(TelemetrySource source) =>
      CarSetupProvider._(argument: source, from: this);

  @override
  String toString() => r'carSetupProvider';
}
