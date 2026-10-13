// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_tyres.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [set]'s two laps' tyres; null without a Target.

@ProviderFor(compareTyres)
final compareTyresProvider = CompareTyresFamily._();

/// [set]'s two laps' tyres; null without a Target.

final class CompareTyresProvider
    extends
        $FunctionalProvider<
          AsyncValue<CompareTyres?>,
          CompareTyres?,
          FutureOr<CompareTyres?>
        >
    with $FutureModifier<CompareTyres?>, $FutureProvider<CompareTyres?> {
  /// [set]'s two laps' tyres; null without a Target.
  CompareTyresProvider._({
    required CompareTyresFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'compareTyresProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$compareTyresHash();

  @override
  String toString() {
    return r'compareTyresProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<CompareTyres?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CompareTyres?> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return compareTyres(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CompareTyresProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$compareTyresHash() => r'c9b8caca9ca4a009ae843ad7cbf3836bbb651153';

/// [set]'s two laps' tyres; null without a Target.

final class CompareTyresFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<CompareTyres?>, ComparisonSet> {
  CompareTyresFamily._()
    : super(
        retry: _neverRetry,
        name: r'compareTyresProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [set]'s two laps' tyres; null without a Target.

  CompareTyresProvider call(ComparisonSet set) =>
      CompareTyresProvider._(argument: set, from: this);

  @override
  String toString() => r'compareTyresProvider';
}
