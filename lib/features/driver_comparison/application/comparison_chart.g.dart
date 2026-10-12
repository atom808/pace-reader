// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_chart.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the Line panel draws each lap's own `Path Lateral` rather than
/// the Target's against Base's (comparison proposal §6). Kept for the run.

@ProviderFor(LinePanelRaw)
final linePanelRawProvider = LinePanelRawProvider._();

/// Whether the Line panel draws each lap's own `Path Lateral` rather than
/// the Target's against Base's (comparison proposal §6). Kept for the run.
final class LinePanelRawProvider extends $NotifierProvider<LinePanelRaw, bool> {
  /// Whether the Line panel draws each lap's own `Path Lateral` rather than
  /// the Target's against Base's (comparison proposal §6). Kept for the run.
  LinePanelRawProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linePanelRawProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linePanelRawHash();

  @$internal
  @override
  LinePanelRaw create() => LinePanelRaw();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$linePanelRawHash() => r'a48c4a25e88a469225167f56bc876a9edd295f8b';

/// Whether the Line panel draws each lap's own `Path Lateral` rather than
/// the Target's against Base's (comparison proposal §6). Kept for the run.

abstract class _$LinePanelRaw extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. Parts 1 and 2 of the course gate run on file
/// facts alone — metadata and the whole-file course facts — before any lap
/// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
/// the whole-lap centre line, needs both laps, and runs on them before
/// anything is drawn.
///
/// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
/// projection costs less than a frame.

@ProviderFor(comparisonChart)
final comparisonChartProvider = ComparisonChartFamily._();

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. Parts 1 and 2 of the course gate run on file
/// facts alone — metadata and the whole-file course facts — before any lap
/// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
/// the whole-lap centre line, needs both laps, and runs on them before
/// anything is drawn.
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
  /// rather than a reopened one. Parts 1 and 2 of the course gate run on file
  /// facts alone — metadata and the whole-file course facts — before any lap
  /// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
  /// the whole-lap centre line, needs both laps, and runs on them before
  /// anything is drawn.
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

String _$comparisonChartHash() => r'7cea26ce9befdb5723f7b1e27433711844f53a7b';

/// [set] checked and projected.
///
/// Every file it reads is checked against Open now first
/// ([requireSourceOpen]), so a closed file is a [CompareSourceClosed] state
/// rather than a reopened one. Parts 1 and 2 of the course gate run on file
/// facts alone — metadata and the whole-file course facts — before any lap
/// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
/// the whole-lap centre line, needs both laps, and runs on them before
/// anything is drawn.
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
  /// rather than a reopened one. Parts 1 and 2 of the course gate run on file
  /// facts alone — metadata and the whole-file course facts — before any lap
  /// is read: a pair they refuse makes zero `lapTelemetry` reads (§4). Part 3,
  /// the whole-lap centre line, needs both laps, and runs on them before
  /// anything is drawn.
  ///
  /// Not kept alive, for `lapChart`'s reason: the reads it projects are, and a
  /// projection costs less than a frame.

  ComparisonChartProvider call(ComparisonSet set) =>
      ComparisonChartProvider._(argument: set, from: this);

  @override
  String toString() => r'comparisonChartProvider';
}
