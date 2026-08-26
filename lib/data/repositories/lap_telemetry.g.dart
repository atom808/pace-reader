// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_telemetry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads one lap, in one place, for every view that shows it.

@ProviderFor(lapTelemetry)
final lapTelemetryProvider = LapTelemetryFamily._();

/// Reads one lap, in one place, for every view that shows it.

final class LapTelemetryProvider
    extends
        $FunctionalProvider<
          AsyncValue<LapTelemetry>,
          LapTelemetry,
          FutureOr<LapTelemetry>
        >
    with $FutureModifier<LapTelemetry>, $FutureProvider<LapTelemetry> {
  /// Reads one lap, in one place, for every view that shows it.
  LapTelemetryProvider._({
    required LapTelemetryFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapTelemetryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapTelemetryHash();

  @override
  String toString() {
    return r'lapTelemetryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<LapTelemetry> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LapTelemetry> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return lapTelemetry(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LapTelemetryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapTelemetryHash() => r'c50796107f02dd4f8265cb97b8ca58e1bfee854c';

/// Reads one lap, in one place, for every view that shows it.

final class LapTelemetryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<LapTelemetry>,
          (TelemetrySource, int)
        > {
  LapTelemetryFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapTelemetryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Reads one lap, in one place, for every view that shows it.

  LapTelemetryProvider call(TelemetrySource source, int lapIndex) =>
      LapTelemetryProvider._(argument: (source, lapIndex), from: this);

  @override
  String toString() => r'lapTelemetryProvider';
}
