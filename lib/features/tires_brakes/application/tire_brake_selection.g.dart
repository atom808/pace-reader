// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tire_brake_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The lap the corner cards show — the user's choice, or null for
/// [TireBrakeReport.defaultLap].
///
/// Nullable rather than defaulting to a number for the reason
/// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
/// are different, and only one of them should land on the garage lap. Keyed
/// by session, since lap 7 of one file has nothing to do with lap 7 of
/// another.

@ProviderFor(TyreLapSelection)
final tyreLapSelectionProvider = TyreLapSelectionFamily._();

/// The lap the corner cards show — the user's choice, or null for
/// [TireBrakeReport.defaultLap].
///
/// Nullable rather than defaulting to a number for the reason
/// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
/// are different, and only one of them should land on the garage lap. Keyed
/// by session, since lap 7 of one file has nothing to do with lap 7 of
/// another.
final class TyreLapSelectionProvider
    extends $NotifierProvider<TyreLapSelection, int?> {
  /// The lap the corner cards show — the user's choice, or null for
  /// [TireBrakeReport.defaultLap].
  ///
  /// Nullable rather than defaulting to a number for the reason
  /// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
  /// are different, and only one of them should land on the garage lap. Keyed
  /// by session, since lap 7 of one file has nothing to do with lap 7 of
  /// another.
  TyreLapSelectionProvider._({
    required TyreLapSelectionFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'tyreLapSelectionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tyreLapSelectionHash();

  @override
  String toString() {
    return r'tyreLapSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TyreLapSelection create() => TyreLapSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TyreLapSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tyreLapSelectionHash() => r'e9d9ccf779589ac4f25ed8fbcebabd78a428a5aa';

/// The lap the corner cards show — the user's choice, or null for
/// [TireBrakeReport.defaultLap].
///
/// Nullable rather than defaulting to a number for the reason
/// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
/// are different, and only one of them should land on the garage lap. Keyed
/// by session, since lap 7 of one file has nothing to do with lap 7 of
/// another.

final class TyreLapSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          TyreLapSelection,
          int?,
          int?,
          int?,
          TelemetrySource
        > {
  TyreLapSelectionFamily._()
    : super(
        retry: null,
        name: r'tyreLapSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The lap the corner cards show — the user's choice, or null for
  /// [TireBrakeReport.defaultLap].
  ///
  /// Nullable rather than defaulting to a number for the reason
  /// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
  /// are different, and only one of them should land on the garage lap. Keyed
  /// by session, since lap 7 of one file has nothing to do with lap 7 of
  /// another.

  TyreLapSelectionProvider call(TelemetrySource source) =>
      TyreLapSelectionProvider._(argument: source, from: this);

  @override
  String toString() => r'tyreLapSelectionProvider';
}

/// The lap the corner cards show — the user's choice, or null for
/// [TireBrakeReport.defaultLap].
///
/// Nullable rather than defaulting to a number for the reason
/// `SelectedLapIndex` gives: "show lap 0" and "no choice yet, choose well"
/// are different, and only one of them should land on the garage lap. Keyed
/// by session, since lap 7 of one file has nothing to do with lap 7 of
/// another.

abstract class _$TyreLapSelection extends $Notifier<int?> {
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

/// The quantity the four trend charts and the table show.

@ProviderFor(TyreMetricSelection)
final tyreMetricSelectionProvider = TyreMetricSelectionFamily._();

/// The quantity the four trend charts and the table show.
final class TyreMetricSelectionProvider
    extends $NotifierProvider<TyreMetricSelection, TyreMetric> {
  /// The quantity the four trend charts and the table show.
  TyreMetricSelectionProvider._({
    required TyreMetricSelectionFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'tyreMetricSelectionProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tyreMetricSelectionHash();

  @override
  String toString() {
    return r'tyreMetricSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TyreMetricSelection create() => TyreMetricSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TyreMetric value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TyreMetric>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TyreMetricSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tyreMetricSelectionHash() =>
    r'17f0523b8b44880a7da427e8f8b1ad6f4d434599';

/// The quantity the four trend charts and the table show.

final class TyreMetricSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          TyreMetricSelection,
          TyreMetric,
          TyreMetric,
          TyreMetric,
          TelemetrySource
        > {
  TyreMetricSelectionFamily._()
    : super(
        retry: null,
        name: r'tyreMetricSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The quantity the four trend charts and the table show.

  TyreMetricSelectionProvider call(TelemetrySource source) =>
      TyreMetricSelectionProvider._(argument: source, from: this);

  @override
  String toString() => r'tyreMetricSelectionProvider';
}

/// The quantity the four trend charts and the table show.

abstract class _$TyreMetricSelection extends $Notifier<TyreMetric> {
  late final _$args = ref.$arg as TelemetrySource;
  TelemetrySource get source => _$args;

  TyreMetric build(TelemetrySource source);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TyreMetric, TyreMetric>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TyreMetric, TyreMetric>,
              TyreMetric,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
