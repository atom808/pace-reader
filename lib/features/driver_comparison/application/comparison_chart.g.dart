// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_chart.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. The course gate runs on file facts alone —
/// metadata and the whole-file course facts — before any lap is read: a
/// refused pair makes zero `lapTelemetry` reads (§4).
///
/// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
/// projection costs less than a frame.

@ProviderFor(comparisonChart)
final comparisonChartProvider = ComparisonChartFamily._();

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. The course gate runs on file facts alone —
/// metadata and the whole-file course facts — before any lap is read: a
/// refused pair makes zero `lapTelemetry` reads (§4).
///
/// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
/// projection costs less than a frame.

final class ComparisonChartProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComparisonView>,
          ComparisonView,
          FutureOr<ComparisonView>
        >
    with $FutureModifier<ComparisonView>, $FutureProvider<ComparisonView> {
  /// [set] checked and projected.
  ///
  /// Every file it reads is checked against Open now first
  /// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
  /// rather than a reopened one. The course gate runs on file facts alone —
  /// metadata and the whole-file course facts — before any lap is read: a
  /// refused pair makes zero `lapTelemetry` reads (§4).
  ///
  /// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
  /// projection costs less than a frame.
  ComparisonChartProvider._({
    required ComparisonChartFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'comparisonChartProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comparisonChartHash();

  @override
  String toString() {
    return r'comparisonChartProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ComparisonView> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComparisonView> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return comparisonChart(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComparisonChartProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comparisonChartHash() => r'9853989285d53e77d4284a910c8dc6040571b439';

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. The course gate runs on file facts alone —
/// metadata and the whole-file course facts — before any lap is read: a
/// refused pair makes zero `lapTelemetry` reads (§4).
///
/// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
/// projection costs less than a frame.

final class ComparisonChartFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ComparisonView>, ComparisonSet> {
  ComparisonChartFamily._()
    : super(
        retry: _neverRetry,
        name: r'comparisonChartProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [set] checked and projected.
  ///
  /// Every file it reads is checked against Open now first
  /// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
  /// rather than a reopened one. The course gate runs on file facts alone —
  /// metadata and the whole-file course facts — before any lap is read: a
  /// refused pair makes zero `lapTelemetry` reads (§4).
  ///
  /// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
  /// projection costs less than a frame.

  ComparisonChartProvider call(ComparisonSet set) =>
      ComparisonChartProvider._(argument: set, from: this);

  @override
  String toString() => r'comparisonChartProvider';
}
