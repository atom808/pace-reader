// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_finding_reads.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
///
/// Not kept alive: the findings it feeds are re-derived only with the pair.

@ProviderFor(lapFindingReads)
final lapFindingReadsProvider = LapFindingReadsFamily._();

/// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
///
/// Not kept alive: the findings it feeds are re-derived only with the pair.

final class LapFindingReadsProvider
    extends
        $FunctionalProvider<
          AsyncValue<LapFindingReads>,
          LapFindingReads,
          FutureOr<LapFindingReads>
        >
    with $FutureModifier<LapFindingReads>, $FutureProvider<LapFindingReads> {
  /// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
  ///
  /// Not kept alive: the findings it feeds are re-derived only with the pair.
  LapFindingReadsProvider._({
    required LapFindingReadsFamily super.from,
    required (TelemetrySource, int) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'lapFindingReadsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lapFindingReadsHash();

  @override
  String toString() {
    return r'lapFindingReadsProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<LapFindingReads> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<LapFindingReads> create(Ref ref) {
    final argument = this.argument as (TelemetrySource, int);
    return lapFindingReads(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LapFindingReadsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lapFindingReadsHash() => r'7dd6b3d7d99ff143284279482c0d0b8f2bc2e707';

/// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
///
/// Not kept alive: the findings it feeds are re-derived only with the pair.

final class LapFindingReadsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<LapFindingReads>,
          (TelemetrySource, int)
        > {
  LapFindingReadsFamily._()
    : super(
        retry: _neverRetry,
        name: r'lapFindingReadsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [lapIndex]'s brake pedal and Ground Speed, read at full resolution.
  ///
  /// Not kept alive: the findings it feeds are re-derived only with the pair.

  LapFindingReadsProvider call(TelemetrySource source, int lapIndex) =>
      LapFindingReadsProvider._(argument: (source, lapIndex), from: this);

  @override
  String toString() => r'lapFindingReadsProvider';
}
