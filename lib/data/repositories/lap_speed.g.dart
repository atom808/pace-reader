// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_speed.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [lapIndex]'s speed and distance, read at full resolution.
///
/// Not kept alive: the segment table it feeds is, and holds plain numbers.

@ProviderFor(lapSpeed)
final lapSpeedProvider = LapSpeedFamily._();

/// [lapIndex]'s speed and distance, read at full resolution.
///
/// Not kept alive: the segment table it feeds is, and holds plain numbers.

final class LapSpeedProvider
    extends
        $FunctionalProvider<AsyncValue<LapSpeed>, LapSpeed, FutureOr<LapSpeed>>
    with $FutureModifier<LapSpeed>, $FutureProvider<LapSpeed> {
  /// [lapIndex]'s speed and distance, read at full resolution.
  ///
  /// Not kept alive: the segment table it feeds is, and holds plain numbers.
  LapSpeedProvider._({
    required LapSpeedFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapSpeedProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapSpeedHash();

  @override
  String toString() {
    return r'lapSpeedProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<LapSpeed> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<LapSpeed> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return lapSpeed(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LapSpeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapSpeedHash() => r'bef0f1e2ab629fc9f2377c3a188d189b255cb9f3';

/// [lapIndex]'s speed and distance, read at full resolution.
///
/// Not kept alive: the segment table it feeds is, and holds plain numbers.

final class LapSpeedFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<LapSpeed>, (TelemetrySource, int)> {
  LapSpeedFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapSpeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [lapIndex]'s speed and distance, read at full resolution.
  ///
  /// Not kept alive: the segment table it feeds is, and holds plain numbers.

  LapSpeedProvider call(TelemetrySource source, int lapIndex) =>
      LapSpeedProvider._(argument: (source, lapIndex), from: this);

  @override
  String toString() => r'lapSpeedProvider';
}
