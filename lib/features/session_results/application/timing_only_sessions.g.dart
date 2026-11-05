// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'timing_only_sessions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Empty until a results folder has been added.

@ProviderFor(timingOnlySessions)
final timingOnlySessionsProvider = TimingOnlySessionsProvider._();

/// Empty until a results folder has been added.

final class TimingOnlySessionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<TimingOnlySessions>,
          TimingOnlySessions,
          FutureOr<TimingOnlySessions>
        >
    with
        $FutureModifier<TimingOnlySessions>,
        $FutureProvider<TimingOnlySessions> {
  /// Empty until a results folder has been added.
  TimingOnlySessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'timingOnlySessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$timingOnlySessionsHash();

  @$internal
  @override
  $FutureProviderElement<TimingOnlySessions> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TimingOnlySessions> create(Ref ref) {
    return timingOnlySessions(ref);
  }
}

String _$timingOnlySessionsHash() =>
    r'cc9f0903142eb0a819605eae9ea8ec67131c03e6';
