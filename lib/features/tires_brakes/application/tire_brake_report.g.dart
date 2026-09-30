// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tire_brake_report.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(tireBrakeReport)
final tireBrakeReportProvider = TireBrakeReportFamily._();

final class TireBrakeReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<TireBrakeReport>,
          TireBrakeReport,
          FutureOr<TireBrakeReport>
        >
    with $FutureModifier<TireBrakeReport>, $FutureProvider<TireBrakeReport> {
  TireBrakeReportProvider._({
    required TireBrakeReportFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'tireBrakeReportProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tireBrakeReportHash();

  @override
  String toString() {
    return r'tireBrakeReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TireBrakeReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TireBrakeReport> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return tireBrakeReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TireBrakeReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tireBrakeReportHash() => r'afd5109fd52bf602b28f472544e36d1f9b628f62';

final class TireBrakeReportFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TireBrakeReport>, TelemetrySource> {
  TireBrakeReportFamily._()
    : super(
        retry: _neverRetry,
        name: r'tireBrakeReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  TireBrakeReportProvider call(TelemetrySource source) =>
      TireBrakeReportProvider._(argument: source, from: this);

  @override
  String toString() => r'tireBrakeReportProvider';
}
