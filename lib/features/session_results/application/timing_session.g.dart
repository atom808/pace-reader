// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timing_session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The timing page's session, or null for none.
///
/// App state rather than a route parameter, for the reason the router gives
/// for recordings: a path does not belong in a URL.

@ProviderFor(OpenTimingSession)
final openTimingSessionProvider = OpenTimingSessionProvider._();

/// The timing page's session, or null for none.
///
/// App state rather than a route parameter, for the reason the router gives
/// for recordings: a path does not belong in a URL.
final class OpenTimingSessionProvider
    extends $NotifierProvider<OpenTimingSession, TimingSessionKey?> {
  /// The timing page's session, or null for none.
  ///
  /// App state rather than a route parameter, for the reason the router gives
  /// for recordings: a path does not belong in a URL.
  OpenTimingSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openTimingSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openTimingSessionHash();

  @$internal
  @override
  OpenTimingSession create() => OpenTimingSession();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TimingSessionKey? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TimingSessionKey?>(value),
    );
  }
}

String _$openTimingSessionHash() => r'acd6e78219dcb903d7df42aa624f8fbcb1365a37';

/// The timing page's session, or null for none.
///
/// App state rather than a route parameter, for the reason the router gives
/// for recordings: a path does not belong in a URL.

abstract class _$OpenTimingSession extends $Notifier<TimingSessionKey?> {
  TimingSessionKey? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TimingSessionKey?, TimingSessionKey?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TimingSessionKey?, TimingSessionKey?>,
              TimingSessionKey?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Null when the file is no longer in the index or has no such car.

@ProviderFor(timingSession)
final timingSessionProvider = TimingSessionFamily._();

/// Null when the file is no longer in the index or has no such car.

final class TimingSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<TimingSession?>,
          TimingSession?,
          FutureOr<TimingSession?>
        >
    with $FutureModifier<TimingSession?>, $FutureProvider<TimingSession?> {
  /// Null when the file is no longer in the index or has no such car.
  TimingSessionProvider._({
    required TimingSessionFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'timingSessionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$timingSessionHash();

  @override
  String toString() {
    return r'timingSessionProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<TimingSession?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TimingSession?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return timingSession(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is TimingSessionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$timingSessionHash() => r'd1b82c011ec108d9650dc4603c8bf638d133f6d4';

/// Null when the file is no longer in the index or has no such car.

final class TimingSessionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TimingSession?>, (String, String)> {
  TimingSessionFamily._()
    : super(
        retry: _neverRetry,
        name: r'timingSessionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Null when the file is no longer in the index or has no such car.

  TimingSessionProvider call(String path, String driverName) =>
      TimingSessionProvider._(argument: (path, driverName), from: this);

  @override
  String toString() => r'timingSessionProvider';
}
