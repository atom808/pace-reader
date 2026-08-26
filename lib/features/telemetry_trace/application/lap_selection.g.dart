// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lap_selection.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The user's explicit choice, or null for "no choice yet".
///
/// Kept as a nullable index rather than defaulting to a number, so
/// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
/// picked, choose well" — which are different, and only one of them should
/// land a user on the garage lap.
///
/// Keyed by session rather than global: lap 7 of one recording has nothing to
/// do with lap 7 of another, so a per-session key makes switching files land
/// on each one's own best lap instead of needing a reset that somebody has to
/// remember to call.

@ProviderFor(SelectedLapIndex)
final selectedLapIndexProvider = SelectedLapIndexFamily._();

/// The user's explicit choice, or null for "no choice yet".
///
/// Kept as a nullable index rather than defaulting to a number, so
/// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
/// picked, choose well" — which are different, and only one of them should
/// land a user on the garage lap.
///
/// Keyed by session rather than global: lap 7 of one recording has nothing to
/// do with lap 7 of another, so a per-session key makes switching files land
/// on each one's own best lap instead of needing a reset that somebody has to
/// remember to call.
final class SelectedLapIndexProvider
    extends $NotifierProvider<SelectedLapIndex, int?> {
  /// The user's explicit choice, or null for "no choice yet".
  ///
  /// Kept as a nullable index rather than defaulting to a number, so
  /// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
  /// picked, choose well" — which are different, and only one of them should
  /// land a user on the garage lap.
  ///
  /// Keyed by session rather than global: lap 7 of one recording has nothing to
  /// do with lap 7 of another, so a per-session key makes switching files land
  /// on each one's own best lap instead of needing a reset that somebody has to
  /// remember to call.
  SelectedLapIndexProvider._({
    required SelectedLapIndexFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: null,
         name: r'selectedLapIndexProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$selectedLapIndexHash();

  @override
  String toString() {
    return r'selectedLapIndexProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SelectedLapIndex create() => SelectedLapIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedLapIndexProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$selectedLapIndexHash() => r'7b870419aaf2cd047f05f862401be0e70b30131e';

/// The user's explicit choice, or null for "no choice yet".
///
/// Kept as a nullable index rather than defaulting to a number, so
/// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
/// picked, choose well" — which are different, and only one of them should
/// land a user on the garage lap.
///
/// Keyed by session rather than global: lap 7 of one recording has nothing to
/// do with lap 7 of another, so a per-session key makes switching files land
/// on each one's own best lap instead of needing a reset that somebody has to
/// remember to call.

final class SelectedLapIndexFamily extends $Family
    with
        $ClassFamilyOverride<
          SelectedLapIndex,
          int?,
          int?,
          int?,
          TelemetrySource
        > {
  SelectedLapIndexFamily._()
    : super(
        retry: null,
        name: r'selectedLapIndexProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The user's explicit choice, or null for "no choice yet".
  ///
  /// Kept as a nullable index rather than defaulting to a number, so
  /// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
  /// picked, choose well" — which are different, and only one of them should
  /// land a user on the garage lap.
  ///
  /// Keyed by session rather than global: lap 7 of one recording has nothing to
  /// do with lap 7 of another, so a per-session key makes switching files land
  /// on each one's own best lap instead of needing a reset that somebody has to
  /// remember to call.

  SelectedLapIndexProvider call(TelemetrySource source) =>
      SelectedLapIndexProvider._(argument: source, from: this);

  @override
  String toString() => r'selectedLapIndexProvider';
}

/// The user's explicit choice, or null for "no choice yet".
///
/// Kept as a nullable index rather than defaulting to a number, so
/// [displayedLap] can distinguish "show me lap 0" from "the user hasn't
/// picked, choose well" — which are different, and only one of them should
/// land a user on the garage lap.
///
/// Keyed by session rather than global: lap 7 of one recording has nothing to
/// do with lap 7 of another, so a per-session key makes switching files land
/// on each one's own best lap instead of needing a reset that somebody has to
/// remember to call.

abstract class _$SelectedLapIndex extends $Notifier<int?> {
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

/// The lap actually rendered.
///
/// Defaults to the session's best lap rather than the first: lap 0 is the
/// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
/// trace is a pit exit rather than a lap of the circuit. The best lap is both
/// the most interesting default and the one a user comparing against anything
/// else will want as their reference.

@ProviderFor(displayedLap)
final displayedLapProvider = DisplayedLapFamily._();

/// The lap actually rendered.
///
/// Defaults to the session's best lap rather than the first: lap 0 is the
/// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
/// trace is a pit exit rather than a lap of the circuit. The best lap is both
/// the most interesting default and the one a user comparing against anything
/// else will want as their reference.

final class DisplayedLapProvider
    extends $FunctionalProvider<AsyncValue<Lap?>, Lap?, FutureOr<Lap?>>
    with $FutureModifier<Lap?>, $FutureProvider<Lap?> {
  /// The lap actually rendered.
  ///
  /// Defaults to the session's best lap rather than the first: lap 0 is the
  /// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
  /// trace is a pit exit rather than a lap of the circuit. The best lap is both
  /// the most interesting default and the one a user comparing against anything
  /// else will want as their reference.
  DisplayedLapProvider._({
    required DisplayedLapFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'displayedLapProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayedLapHash();

  @override
  String toString() {
    return r'displayedLapProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Lap?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Lap?> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return displayedLap(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayedLapProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayedLapHash() => r'4a22c8ce8f6592938ebb99ebbd97baa1ac73cf6c';

/// The lap actually rendered.
///
/// Defaults to the session's best lap rather than the first: lap 0 is the
/// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
/// trace is a pit exit rather than a lap of the circuit. The best lap is both
/// the most interesting default and the one a user comparing against anything
/// else will want as their reference.

final class DisplayedLapFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Lap?>, TelemetrySource> {
  DisplayedLapFamily._()
    : super(
        retry: _neverRetry,
        name: r'displayedLapProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The lap actually rendered.
  ///
  /// Defaults to the session's best lap rather than the first: lap 0 is the
  /// garage lap in every sample (§5.2), so "the first lap" is the one lap whose
  /// trace is a pit exit rather than a lap of the circuit. The best lap is both
  /// the most interesting default and the one a user comparing against anything
  /// else will want as their reference.

  DisplayedLapProvider call(TelemetrySource source) =>
      DisplayedLapProvider._(argument: source, from: this);

  @override
  String toString() => r'displayedLapProvider';
}
