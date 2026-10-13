// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_conditions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [source]'s conditions, per lap.
///
/// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
/// two sparse event tables: a session's worth costs about as much as the
/// fuel view's own reads. Kept alive as that view's report is.

@ProviderFor(sessionConditions)
final sessionConditionsProvider = SessionConditionsFamily._();

/// [source]'s conditions, per lap.
///
/// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
/// two sparse event tables: a session's worth costs about as much as the
/// fuel view's own reads. Kept alive as that view's report is.

final class SessionConditionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SessionConditions>,
          SessionConditions,
          FutureOr<SessionConditions>
        >
    with
        $FutureModifier<SessionConditions>,
        $FutureProvider<SessionConditions> {
  /// [source]'s conditions, per lap.
  ///
  /// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
  /// two sparse event tables: a session's worth costs about as much as the
  /// fuel view's own reads. Kept alive as that view's report is.
  SessionConditionsProvider._({
    required SessionConditionsFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'sessionConditionsProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionConditionsHash();

  @override
  String toString() {
    return r'sessionConditionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SessionConditions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SessionConditions> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return sessionConditions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SessionConditionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionConditionsHash() => r'99252cdac7be8112712fb6d304a88b6cf073db35';

/// [source]'s conditions, per lap.
///
/// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
/// two sparse event tables: a session's worth costs about as much as the
/// fuel view's own reads. Kept alive as that view's report is.

final class SessionConditionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SessionConditions>,
          TelemetrySource
        > {
  SessionConditionsFamily._()
    : super(
        retry: _neverRetry,
        name: r'sessionConditionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// [source]'s conditions, per lap.
  ///
  /// Per-lap aggregates computed in SQL, one row per lap (`lapStatsSql`), and
  /// two sparse event tables: a session's worth costs about as much as the
  /// fuel view's own reads. Kept alive as that view's report is.

  SessionConditionsProvider call(TelemetrySource source) =>
      SessionConditionsProvider._(argument: source, from: this);

  @override
  String toString() => r'sessionConditionsProvider';
}

/// The strip's chips for [set]'s conditions and setups; empty without a
/// Target.
///
/// Reads each lap from its file's lap table rather than from the chart, so
/// switching axis or panels never re-derives these.

@ProviderFor(comparisonConditions)
final comparisonConditionsProvider = ComparisonConditionsFamily._();

/// The strip's chips for [set]'s conditions and setups; empty without a
/// Target.
///
/// Reads each lap from its file's lap table rather than from the chart, so
/// switching axis or panels never re-derives these.

final class ComparisonConditionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ComparabilityChip>>,
          List<ComparabilityChip>,
          FutureOr<List<ComparabilityChip>>
        >
    with
        $FutureModifier<List<ComparabilityChip>>,
        $FutureProvider<List<ComparabilityChip>> {
  /// The strip's chips for [set]'s conditions and setups; empty without a
  /// Target.
  ///
  /// Reads each lap from its file's lap table rather than from the chart, so
  /// switching axis or panels never re-derives these.
  ComparisonConditionsProvider._({
    required ComparisonConditionsFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'comparisonConditionsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comparisonConditionsHash();

  @override
  String toString() {
    return r'comparisonConditionsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ComparabilityChip>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ComparabilityChip>> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return comparisonConditions(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComparisonConditionsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comparisonConditionsHash() =>
    r'ffd473508425d7a9f41a599208c6d0e474e38644';

/// The strip's chips for [set]'s conditions and setups; empty without a
/// Target.
///
/// Reads each lap from its file's lap table rather than from the chart, so
/// switching axis or panels never re-derives these.

final class ComparisonConditionsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ComparabilityChip>>,
          ComparisonSet
        > {
  ComparisonConditionsFamily._()
    : super(
        retry: _neverRetry,
        name: r'comparisonConditionsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The strip's chips for [set]'s conditions and setups; empty without a
  /// Target.
  ///
  /// Reads each lap from its file's lap table rather than from the chart, so
  /// switching axis or panels never re-derives these.

  ComparisonConditionsProvider call(ComparisonSet set) =>
      ComparisonConditionsProvider._(argument: set, from: this);

  @override
  String toString() => r'comparisonConditionsProvider';
}
