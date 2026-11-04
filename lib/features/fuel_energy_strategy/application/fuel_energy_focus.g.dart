// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fuel_energy_focus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lap highlighted in the table, as `Lap.index`; null for none.

@ProviderFor(FuelEnergyLap)
final fuelEnergyLapProvider = FuelEnergyLapFamily._();

/// The lap highlighted in the table, as `Lap.index`; null for none.
final class FuelEnergyLapProvider
    extends $NotifierProvider<FuelEnergyLap, int?> {
  /// The lap highlighted in the table, as `Lap.index`; null for none.
  FuelEnergyLapProvider._({
    required FuelEnergyLapFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'fuelEnergyLapProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fuelEnergyLapHash();

  @override
  String toString() {
    return r'fuelEnergyLapProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FuelEnergyLap create() => FuelEnergyLap();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FuelEnergyLapProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fuelEnergyLapHash() => r'19b0b44e1905f741f464e3e49effc94c67e75a9f';

/// The lap highlighted in the table, as `Lap.index`; null for none.

final class FuelEnergyLapFamily extends $Family
    with
        $ClassFamilyOverride<FuelEnergyLap, int?, int?, int?, TelemetrySource> {
  FuelEnergyLapFamily._()
    : super(
        retry: null,
        name: r'fuelEnergyLapProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The lap highlighted in the table, as `Lap.index`; null for none.

  FuelEnergyLapProvider call(TelemetrySource source) =>
      FuelEnergyLapProvider._(argument: source, from: this);

  @override
  String toString() => r'fuelEnergyLapProvider';
}

/// The lap highlighted in the table, as `Lap.index`; null for none.

abstract class _$FuelEnergyLap extends $Notifier<int?> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  int? build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
