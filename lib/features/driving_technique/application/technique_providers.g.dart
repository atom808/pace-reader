// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'technique_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The repository for [source].

@ProviderFor(techniqueRepository)
final techniqueRepositoryProvider = TechniqueRepositoryFamily._();

/// The repository for [source].

final class TechniqueRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniqueRepository>,
          TechniqueRepository,
          FutureOr<TechniqueRepository>
        >
    with
        $FutureModifier<TechniqueRepository>,
        $FutureProvider<TechniqueRepository> {
  /// The repository for [source].
  TechniqueRepositoryProvider._({
    required TechniqueRepositoryFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueRepositoryHash();

  @override
  String toString() {
    return r'techniqueRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniqueRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniqueRepository> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueRepository(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueRepositoryHash() =>
    r'8d89acfed53f7d6f848a7cc5e0cb7a69279199cb';

/// The repository for [source].

final class TechniqueRepositoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TechniqueRepository>,
          TelemetrySource
        > {
  TechniqueRepositoryFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The repository for [source].

  TechniqueRepositoryProvider call(TelemetrySource source) =>
      TechniqueRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueRepositoryProvider';
}

@ProviderFor(techniqueSession)
final techniqueSessionProvider = TechniqueSessionFamily._();

final class TechniqueSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniqueSession>,
          TechniqueSession,
          FutureOr<TechniqueSession>
        >
    with $FutureModifier<TechniqueSession>, $FutureProvider<TechniqueSession> {
  TechniqueSessionProvider._({
    required TechniqueSessionFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueSessionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueSessionHash();

  @override
  String toString() {
    return r'techniqueSessionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniqueSession> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniqueSession> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueSession(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueSessionHash() => r'83d0f6a9d61daadff7cfbe0934e30da6070be239';

final class TechniqueSessionFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<TechniqueSession>, TelemetrySource> {
  TechniqueSessionFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniqueSessionProvider call(TelemetrySource source) =>
      TechniqueSessionProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueSessionProvider';
}

@ProviderFor(techniqueOverview)
final techniqueOverviewProvider = TechniqueOverviewFamily._();

final class TechniqueOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniqueOverview>,
          TechniqueOverview,
          FutureOr<TechniqueOverview>
        >
    with
        $FutureModifier<TechniqueOverview>,
        $FutureProvider<TechniqueOverview> {
  TechniqueOverviewProvider._({
    required TechniqueOverviewFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueOverviewProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueOverviewHash();

  @override
  String toString() {
    return r'techniqueOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniqueOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniqueOverview> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueOverviewHash() => r'c72ea3b408326e87b4e2815020132ea5b26190f1';

final class TechniqueOverviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TechniqueOverview>,
          TelemetrySource
        > {
  TechniqueOverviewFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniqueOverviewProvider call(TelemetrySource source) =>
      TechniqueOverviewProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueOverviewProvider';
}

/// Every course's corner table, held for the run next to Compare's segment
/// tables and written the same way: only by [ensure].

@ProviderFor(CornerTableStore)
final cornerTableStoreProvider = CornerTableStoreProvider._();

/// Every course's corner table, held for the run next to Compare's segment
/// tables and written the same way: only by [ensure].
final class CornerTableStoreProvider
    extends $NotifierProvider<CornerTableStore, Map<TrackKey, CornerTable>> {
  /// Every course's corner table, held for the run next to Compare's segment
  /// tables and written the same way: only by [ensure].
  CornerTableStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cornerTableStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cornerTableStoreHash();

  @$internal
  @override
  CornerTableStore create() => CornerTableStore();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<TrackKey, CornerTable> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<TrackKey, CornerTable>>(value),
    );
  }
}

String _$cornerTableStoreHash() => r'a3f87007c4252c0bec5850997fae31cab9d99c74';

/// Every course's corner table, held for the run next to Compare's segment
/// tables and written the same way: only by [ensure].

abstract class _$CornerTableStore
    extends $Notifier<Map<TrackKey, CornerTable>> {
  Map<TrackKey, CornerTable> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<TrackKey, CornerTable>, Map<TrackKey, CornerTable>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<TrackKey, CornerTable>,
                Map<TrackKey, CornerTable>
              >,
              Map<TrackKey, CornerTable>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(techniqueCourse)
final techniqueCourseProvider = TechniqueCourseFamily._();

final class TechniqueCourseProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniqueCourse>,
          TechniqueCourse,
          FutureOr<TechniqueCourse>
        >
    with $FutureModifier<TechniqueCourse>, $FutureProvider<TechniqueCourse> {
  TechniqueCourseProvider._({
    required TechniqueCourseFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueCourseProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueCourseHash();

  @override
  String toString() {
    return r'techniqueCourseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniqueCourse> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniqueCourse> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueCourse(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueCourseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueCourseHash() => r'4b1bcec4184d0171cdbafabfa2a533bbae86b39d';

final class TechniqueCourseFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TechniqueCourse>, TelemetrySource> {
  TechniqueCourseFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueCourseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniqueCourseProvider call(TelemetrySource source) =>
      TechniqueCourseProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueCourseProvider';
}

@ProviderFor(techniquePlacement)
final techniquePlacementProvider = TechniquePlacementFamily._();

final class TechniquePlacementProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniquePlacement?>,
          TechniquePlacement?,
          FutureOr<TechniquePlacement?>
        >
    with
        $FutureModifier<TechniquePlacement?>,
        $FutureProvider<TechniquePlacement?> {
  TechniquePlacementProvider._({
    required TechniquePlacementFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniquePlacementProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniquePlacementHash();

  @override
  String toString() {
    return r'techniquePlacementProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniquePlacement?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniquePlacement?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniquePlacement(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniquePlacementProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniquePlacementHash() =>
    r'4e2e0b778aadf0d34d2aa74baae3b84fbcf47877';

final class TechniquePlacementFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<TechniquePlacement?>,
          TelemetrySource
        > {
  TechniquePlacementFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniquePlacementProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniquePlacementProvider call(TelemetrySource source) =>
      TechniquePlacementProvider._(argument: source, from: this);

  @override
  String toString() => r'techniquePlacementProvider';
}

@ProviderFor(techniqueLens)
final techniqueLensProvider = TechniqueLensFamily._();

final class TechniqueLensProvider
    extends
        $FunctionalProvider<
          AsyncValue<TechniqueLens>,
          TechniqueLens,
          FutureOr<TechniqueLens>
        >
    with $FutureModifier<TechniqueLens>, $FutureProvider<TechniqueLens> {
  TechniqueLensProvider._({
    required TechniqueLensFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueLensProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueLensHash();

  @override
  String toString() {
    return r'techniqueLensProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TechniqueLens> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TechniqueLens> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueLens(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueLensProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueLensHash() => r'df47217d4ce9350ec2b0db22c8158b37510027fb';

final class TechniqueLensFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TechniqueLens>, TelemetrySource> {
  TechniqueLensFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueLensProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniqueLensProvider call(TelemetrySource source) =>
      TechniqueLensProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueLensProvider';
}

/// One lap's G-G points, read when the lap is shown.

@ProviderFor(techniqueLapPoints)
final techniqueLapPointsProvider = TechniqueLapPointsFamily._();

/// One lap's G-G points, read when the lap is shown.

final class TechniqueLapPointsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GgPoint>>,
          List<GgPoint>,
          FutureOr<List<GgPoint>>
        >
    with $FutureModifier<List<GgPoint>>, $FutureProvider<List<GgPoint>> {
  /// One lap's G-G points, read when the lap is shown.
  TechniqueLapPointsProvider._({
    required TechniqueLapPointsFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'techniqueLapPointsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueLapPointsHash();

  @override
  String toString() {
    return r'techniqueLapPointsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<GgPoint>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GgPoint>> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return techniqueLapPoints(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueLapPointsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueLapPointsHash() =>
    r'bb43066a90a5dcfcd30be57e56c01624c8c95004';

/// One lap's G-G points, read when the lap is shown.

final class TechniqueLapPointsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<GgPoint>>,
          (TelemetrySource, int)
        > {
  TechniqueLapPointsFamily._()
    : super(
        retry: _neverRetry,
        name: r'techniqueLapPointsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One lap's G-G points, read when the lap is shown.

  TechniqueLapPointsProvider call(TelemetrySource source, int lapIndex) =>
      TechniqueLapPointsProvider._(argument: (source, lapIndex), from: this);

  @override
  String toString() => r'techniqueLapPointsProvider';
}

@ProviderFor(TechniqueSelectionState)
final techniqueSelectionStateProvider = TechniqueSelectionStateFamily._();

final class TechniqueSelectionStateProvider
    extends $NotifierProvider<TechniqueSelectionState, TechniqueSelection> {
  TechniqueSelectionStateProvider._({
    required TechniqueSelectionStateFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'techniqueSelectionStateProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueSelectionStateHash();

  @override
  String toString() {
    return r'techniqueSelectionStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TechniqueSelectionState create() => TechniqueSelectionState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TechniqueSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TechniqueSelection>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueSelectionStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueSelectionStateHash() =>
    r'4a17ab628c32aec7c5b0beadb571f9dd2d3db46c';

final class TechniqueSelectionStateFamily extends $Family
    with
        $ClassFamilyOverride<
          TechniqueSelectionState,
          TechniqueSelection,
          TechniqueSelection,
          TechniqueSelection,
          TelemetrySource
        > {
  TechniqueSelectionStateFamily._()
    : super(
        retry: null,
        name: r'techniqueSelectionStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TechniqueSelectionStateProvider call(TelemetrySource source) =>
      TechniqueSelectionStateProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueSelectionStateProvider';
}

abstract class _$TechniqueSelectionState extends $Notifier<TechniqueSelection> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  TechniqueSelection build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TechniqueSelection, TechniqueSelection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TechniqueSelection, TechniqueSelection>,
              TechniqueSelection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The lens result for [source]'s selected option, or null.

@ProviderFor(techniqueLensResult)
final techniqueLensResultProvider = TechniqueLensResultFamily._();

/// The lens result for [source]'s selected option, or null.

final class TechniqueLensResultProvider
    extends $FunctionalProvider<LensResult?, LensResult?, LensResult?>
    with $Provider<LensResult?> {
  /// The lens result for [source]'s selected option, or null.
  TechniqueLensResultProvider._({
    required TechniqueLensResultFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'techniqueLensResultProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueLensResultHash();

  @override
  String toString() {
    return r'techniqueLensResultProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<LensResult?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LensResult? create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return techniqueLensResult(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LensResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LensResult?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueLensResultProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueLensResultHash() =>
    r'403006f3def0458224ad649db0a30e45f45d26a3';

/// The lens result for [source]'s selected option, or null.

final class TechniqueLensResultFamily extends $Family
    with $FunctionalFamilyOverride<LensResult?, TelemetrySource> {
  TechniqueLensResultFamily._()
    : super(
        retry: null,
        name: r'techniqueLensResultProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The lens result for [source]'s selected option, or null.

  TechniqueLensResultProvider call(TelemetrySource source) =>
      TechniqueLensResultProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueLensResultProvider';
}

@ProviderFor(TechniqueFocusState)
final techniqueFocusStateProvider = TechniqueFocusStateFamily._();

final class TechniqueFocusStateProvider
    extends $NotifierProvider<TechniqueFocusState, TechniqueFocus> {
  TechniqueFocusStateProvider._({
    required TechniqueFocusStateFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'techniqueFocusStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$techniqueFocusStateHash();

  @override
  String toString() {
    return r'techniqueFocusStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TechniqueFocusState create() => TechniqueFocusState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TechniqueFocus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TechniqueFocus>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TechniqueFocusStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$techniqueFocusStateHash() =>
    r'9a559ce0674322bc8b26265a8523d623d5ee7f65';

final class TechniqueFocusStateFamily extends $Family
    with
        $ClassFamilyOverride<
          TechniqueFocusState,
          TechniqueFocus,
          TechniqueFocus,
          TechniqueFocus,
          TelemetrySource
        > {
  TechniqueFocusStateFamily._()
    : super(
        retry: null,
        name: r'techniqueFocusStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TechniqueFocusStateProvider call(TelemetrySource source) =>
      TechniqueFocusStateProvider._(argument: source, from: this);

  @override
  String toString() => r'techniqueFocusStateProvider';
}

abstract class _$TechniqueFocusState extends $Notifier<TechniqueFocus> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  TechniqueFocus build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TechniqueFocus, TechniqueFocus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TechniqueFocus, TechniqueFocus>,
              TechniqueFocus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
