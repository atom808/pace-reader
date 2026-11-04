// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'suspension_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(suspensionRepository)
final suspensionRepositoryProvider = SuspensionRepositoryFamily._();

final class SuspensionRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SuspensionRepository>,
          SuspensionRepository,
          FutureOr<SuspensionRepository>
        >
    with
        $FutureModifier<SuspensionRepository>,
        $FutureProvider<SuspensionRepository> {
  SuspensionRepositoryProvider._({
    required SuspensionRepositoryFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'suspensionRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$suspensionRepositoryHash();

  @override
  String toString() {
    return r'suspensionRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SuspensionRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SuspensionRepository> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return suspensionRepository(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SuspensionRepositoryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$suspensionRepositoryHash() =>
    r'2076975a8a584d5040bba6c764d3f0d71382582d';

final class SuspensionRepositoryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SuspensionRepository>,
          TelemetrySource
        > {
  SuspensionRepositoryFamily._()
    : super(
        retry: _neverRetry,
        name: r'suspensionRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SuspensionRepositoryProvider call(TelemetrySource source) =>
      SuspensionRepositoryProvider._(argument: source, from: this);

  @override
  String toString() => r'suspensionRepositoryProvider';
}

@ProviderFor(suspensionOverview)
final suspensionOverviewProvider = SuspensionOverviewFamily._();

final class SuspensionOverviewProvider
    extends
        $FunctionalProvider<
          AsyncValue<SuspensionOverview>,
          SuspensionOverview,
          FutureOr<SuspensionOverview>
        >
    with
        $FutureModifier<SuspensionOverview>,
        $FutureProvider<SuspensionOverview> {
  SuspensionOverviewProvider._({
    required SuspensionOverviewFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'suspensionOverviewProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$suspensionOverviewHash();

  @override
  String toString() {
    return r'suspensionOverviewProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SuspensionOverview> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SuspensionOverview> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return suspensionOverview(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SuspensionOverviewProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$suspensionOverviewHash() =>
    r'e35e88a3d23dc791f009a1e2e88cc68a07d9d4c2';

final class SuspensionOverviewFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SuspensionOverview>,
          TelemetrySource
        > {
  SuspensionOverviewFamily._()
    : super(
        retry: _neverRetry,
        name: r'suspensionOverviewProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SuspensionOverviewProvider call(TelemetrySource source) =>
      SuspensionOverviewProvider._(argument: source, from: this);

  @override
  String toString() => r'suspensionOverviewProvider';
}

/// One site's traces, every racing lap, over its window.

@ProviderFor(siteTraces)
final siteTracesProvider = SiteTracesFamily._();

/// One site's traces, every racing lap, over its window.

final class SiteTracesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SiteTrace>>,
          List<SiteTrace>,
          FutureOr<List<SiteTrace>>
        >
    with $FutureModifier<List<SiteTrace>>, $FutureProvider<List<SiteTrace>> {
  /// One site's traces, every racing lap, over its window.
  SiteTracesProvider._({
    required SiteTracesFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'siteTracesProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$siteTracesHash();

  @override
  String toString() {
    return r'siteTracesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<SiteTrace>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SiteTrace>> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return siteTraces(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SiteTracesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$siteTracesHash() => r'380965b1e16df09a377148ca5a1f76a98671a948';

/// One site's traces, every racing lap, over its window.

final class SiteTracesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SiteTrace>>,
          (TelemetrySource, int)
        > {
  SiteTracesFamily._()
    : super(
        retry: _neverRetry,
        name: r'siteTracesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// One site's traces, every racing lap, over its window.

  SiteTracesProvider call(TelemetrySource source, int siteKey) =>
      SiteTracesProvider._(argument: (source, siteKey), from: this);

  @override
  String toString() => r'siteTracesProvider';
}

@ProviderFor(SuspensionSelectionState)
final suspensionSelectionStateProvider = SuspensionSelectionStateFamily._();

final class SuspensionSelectionStateProvider
    extends $NotifierProvider<SuspensionSelectionState, SuspensionSelection> {
  SuspensionSelectionStateProvider._({
    required SuspensionSelectionStateFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'suspensionSelectionStateProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$suspensionSelectionStateHash();

  @override
  String toString() {
    return r'suspensionSelectionStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SuspensionSelectionState create() => SuspensionSelectionState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SuspensionSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SuspensionSelection>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SuspensionSelectionStateProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$suspensionSelectionStateHash() =>
    r'f9a8f631eb322ebddb3b69665fad59a6ac5e28cb';

final class SuspensionSelectionStateFamily extends $Family
    with
        $ClassFamilyOverride<
          SuspensionSelectionState,
          SuspensionSelection,
          SuspensionSelection,
          SuspensionSelection,
          TelemetrySource
        > {
  SuspensionSelectionStateFamily._()
    : super(
        retry: null,
        name: r'suspensionSelectionStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SuspensionSelectionStateProvider call(TelemetrySource source) =>
      SuspensionSelectionStateProvider._(argument: source, from: this);

  @override
  String toString() => r'suspensionSelectionStateProvider';
}

abstract class _$SuspensionSelectionState
    extends $Notifier<SuspensionSelection> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  SuspensionSelection build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SuspensionSelection, SuspensionSelection>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SuspensionSelection, SuspensionSelection>,
              SuspensionSelection,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(SuspensionHoverState)
final suspensionHoverStateProvider = SuspensionHoverStateFamily._();

final class SuspensionHoverStateProvider
    extends $NotifierProvider<SuspensionHoverState, SuspensionHover> {
  SuspensionHoverStateProvider._({
    required SuspensionHoverStateFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'suspensionHoverStateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$suspensionHoverStateHash();

  @override
  String toString() {
    return r'suspensionHoverStateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SuspensionHoverState create() => SuspensionHoverState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SuspensionHover value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SuspensionHover>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SuspensionHoverStateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$suspensionHoverStateHash() =>
    r'a8ce10efbde7a57d53ef05e1c7f8027bf1d6c1ea';

final class SuspensionHoverStateFamily extends $Family
    with
        $ClassFamilyOverride<
          SuspensionHoverState,
          SuspensionHover,
          SuspensionHover,
          SuspensionHover,
          TelemetrySource
        > {
  SuspensionHoverStateFamily._()
    : super(
        retry: null,
        name: r'suspensionHoverStateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SuspensionHoverStateProvider call(TelemetrySource source) =>
      SuspensionHoverStateProvider._(argument: source, from: this);

  @override
  String toString() => r'suspensionHoverStateProvider';
}

abstract class _$SuspensionHoverState extends $Notifier<SuspensionHover> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  SuspensionHover build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SuspensionHover, SuspensionHover>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SuspensionHover, SuspensionHover>,
              SuspensionHover,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
