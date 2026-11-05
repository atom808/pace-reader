// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_gap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [set]'s gap, phase by phase; null without a Target, without segments
/// (the clocks come with them), or where the Target's pedals were not
/// recorded.
///
/// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
/// from the reads the findings already hold for the pair.

@ProviderFor(comparisonGapSplit)
final comparisonGapSplitProvider = ComparisonGapSplitFamily._();

/// [set]'s gap, phase by phase; null without a Target, without segments
/// (the clocks come with them), or where the Target's pedals were not
/// recorded.
///
/// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
/// from the reads the findings already hold for the pair.

final class ComparisonGapSplitProvider
    extends
        $FunctionalProvider<
          AsyncValue<GapSplit?>,
          GapSplit?,
          FutureOr<GapSplit?>
        >
    with $FutureModifier<GapSplit?>, $FutureProvider<GapSplit?> {
  /// [set]'s gap, phase by phase; null without a Target, without segments
  /// (the clocks come with them), or where the Target's pedals were not
  /// recorded.
  ///
  /// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
  /// from the reads the findings already hold for the pair.
  ComparisonGapSplitProvider._({
    required ComparisonGapSplitFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'comparisonGapSplitProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comparisonGapSplitHash();

  @override
  String toString() {
    return r'comparisonGapSplitProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GapSplit?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<GapSplit?> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return comparisonGapSplit(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComparisonGapSplitProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comparisonGapSplitHash() =>
    r'f59d5b2a31cbb1388d6dac91e458ae8fcae2c95f';

/// [set]'s gap, phase by phase; null without a Target, without segments
/// (the clocks come with them), or where the Target's pedals were not
/// recorded.
///
/// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
/// from the reads the findings already hold for the pair.

final class ComparisonGapSplitFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GapSplit?>, ComparisonSet> {
  ComparisonGapSplitFamily._()
    : super(
        retry: _neverRetry,
        name: r'comparisonGapSplitProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [set]'s gap, phase by phase; null without a Target, without segments
  /// (the clocks come with them), or where the Target's pedals were not
  /// recorded.
  ///
  /// Reads the Target's pedals and `Regen Rate` at the recording's own rate,
  /// from the reads the findings already hold for the pair.

  ComparisonGapSplitProvider call(ComparisonSet set) =>
      ComparisonGapSplitProvider._(argument: set, from: this);

  @override
  String toString() => r'comparisonGapSplitProvider';
}

@ProviderFor(GapPhaseFocus)
final gapPhaseFocusProvider = GapPhaseFocusProvider._();

final class GapPhaseFocusProvider
    extends $NotifierProvider<GapPhaseFocus, GapPhaseFocusState> {
  GapPhaseFocusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gapPhaseFocusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gapPhaseFocusHash();

  @$internal
  @override
  GapPhaseFocus create() => GapPhaseFocus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GapPhaseFocusState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GapPhaseFocusState>(value),
    );
  }
}

String _$gapPhaseFocusHash() => r'9080527c7647097ad8277b3b191597954e1e64cb';

abstract class _$GapPhaseFocus extends $Notifier<GapPhaseFocusState> {
  GapPhaseFocusState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GapPhaseFocusState, GapPhaseFocusState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GapPhaseFocusState, GapPhaseFocusState>,
              GapPhaseFocusState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
