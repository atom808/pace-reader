// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fuel_energy.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(fuelEnergyReport)
final fuelEnergyReportProvider = FuelEnergyReportFamily._();

final class FuelEnergyReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<FuelEnergyReport>,
          FuelEnergyReport,
          FutureOr<FuelEnergyReport>
        >
    with $FutureModifier<FuelEnergyReport>, $FutureProvider<FuelEnergyReport> {
  FuelEnergyReportProvider._({
    required FuelEnergyReportFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'fuelEnergyReportProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fuelEnergyReportHash();

  @override
  String toString() {
    return r'fuelEnergyReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FuelEnergyReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FuelEnergyReport> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return fuelEnergyReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FuelEnergyReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fuelEnergyReportHash() => r'4b3a06828563c91a69972e99228384dc23462410';

final class FuelEnergyReportFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<FuelEnergyReport>, TelemetrySource> {
  FuelEnergyReportFamily._()
    : super(
        retry: _neverRetry,
        name: r'fuelEnergyReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  FuelEnergyReportProvider call(TelemetrySource source) =>
      FuelEnergyReportProvider._(argument: source, from: this);

  @override
  String toString() => r'fuelEnergyReportProvider';
}
