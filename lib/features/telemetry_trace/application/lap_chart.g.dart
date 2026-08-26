// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_chart.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which channel colours the track map (§8.5).

@ProviderFor(TrackMapChannel)
final trackMapChannelProvider = TrackMapChannelProvider._();

/// Which channel colours the track map (§8.5).
final class TrackMapChannelProvider
    extends $NotifierProvider<TrackMapChannel, String> {
  /// Which channel colours the track map (§8.5).
  TrackMapChannelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trackMapChannelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trackMapChannelHash();

  @$internal
  @override
  TrackMapChannel create() => TrackMapChannel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$trackMapChannelHash() => r'99f2e71f60a78b89e1a0f877c8794c246e7cfb56';

/// Which channel colours the track map (§8.5).

abstract class _$TrackMapChannel extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(lapChart)
final lapChartProvider = LapChartFamily._();

final class LapChartProvider
    extends
        $FunctionalProvider<AsyncValue<LapChart>, LapChart, FutureOr<LapChart>>
    with $FutureModifier<LapChart>, $FutureProvider<LapChart> {
  LapChartProvider._({
    required LapChartFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapChartProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapChartHash();

  @override
  String toString() {
    return r'lapChartProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<LapChart> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LapChart> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return lapChart(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LapChartProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapChartHash() => r'5ca51c80c18e69c470d44f365fa9ec5c142277ab';

final class LapChartFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LapChart>, (TelemetrySource, int)> {
  LapChartFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapChartProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LapChartProvider call(TelemetrySource source, int lapIndex) =>
      LapChartProvider._(argument: (source, lapIndex), from: this);

  @override
  String toString() => r'lapChartProvider';
}
