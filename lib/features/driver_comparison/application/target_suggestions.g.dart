// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'target_suggestions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Suggestions for [set]'s Base: library sessions in the window, the PB
/// here, and the fastest lap of Base's file — never Base's own lap, and
/// never the Target already chosen.

@ProviderFor(targetSuggestions)
final targetSuggestionsProvider = TargetSuggestionsFamily._();

/// Suggestions for [set]'s Base: library sessions in the window, the PB
/// here, and the fastest lap of Base's file — never Base's own lap, and
/// never the Target already chosen.

final class TargetSuggestionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TargetSuggestion>>,
          List<TargetSuggestion>,
          FutureOr<List<TargetSuggestion>>
        >
    with
        $FutureModifier<List<TargetSuggestion>>,
        $FutureProvider<List<TargetSuggestion>> {
  /// Suggestions for [set]'s Base: library sessions in the window, the PB
  /// here, and the fastest lap of Base's file — never Base's own lap, and
  /// never the Target already chosen.
  TargetSuggestionsProvider._({
    required TargetSuggestionsFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'targetSuggestionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$targetSuggestionsHash();

  @override
  String toString() {
    return r'targetSuggestionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<TargetSuggestion>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TargetSuggestion>> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return targetSuggestions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TargetSuggestionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$targetSuggestionsHash() => r'abadc93f9c4148592f030bb2ea1d720280e8dc3d';

/// Suggestions for [set]'s Base: library sessions in the window, the PB
/// here, and the fastest lap of Base's file — never Base's own lap, and
/// never the Target already chosen.

final class TargetSuggestionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<TargetSuggestion>>,
          ComparisonSet
        > {
  TargetSuggestionsFamily._()
    : super(
        retry: _neverRetry,
        name: r'targetSuggestionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Suggestions for [set]'s Base: library sessions in the window, the PB
  /// here, and the fastest lap of Base's file — never Base's own lap, and
  /// never the Target already chosen.

  TargetSuggestionsProvider call(ComparisonSet set) =>
      TargetSuggestionsProvider._(argument: set, from: this);

  @override
  String toString() => r'targetSuggestionsProvider';
}
