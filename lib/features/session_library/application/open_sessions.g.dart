// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'open_sessions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The sources the user has opened this run, most recent first.
///
/// Held in app state rather than encoded in the route, because a route
/// parameter cannot express both platforms: on web a session is a byte buffer
/// in memory with no path to put in a URL (§9.2). Keeping the identity here
/// means the same navigation works on desktop and web instead of one target
/// carrying file paths through the address bar.
///
/// This is *not* the Session Library's persistent index — that is
/// `SessionLibrary`, in drift (§9.6). This list is per-run: what is open now.

@ProviderFor(OpenSessions)
final openSessionsProvider = OpenSessionsProvider._();

/// The sources the user has opened this run, most recent first.
///
/// Held in app state rather than encoded in the route, because a route
/// parameter cannot express both platforms: on web a session is a byte buffer
/// in memory with no path to put in a URL (§9.2). Keeping the identity here
/// means the same navigation works on desktop and web instead of one target
/// carrying file paths through the address bar.
///
/// This is *not* the Session Library's persistent index — that is
/// `SessionLibrary`, in drift (§9.6). This list is per-run: what is open now.
final class OpenSessionsProvider
    extends $NotifierProvider<OpenSessions, List<TelemetrySource>> {
  /// The sources the user has opened this run, most recent first.
  ///
  /// Held in app state rather than encoded in the route, because a route
  /// parameter cannot express both platforms: on web a session is a byte buffer
  /// in memory with no path to put in a URL (§9.2). Keeping the identity here
  /// means the same navigation works on desktop and web instead of one target
  /// carrying file paths through the address bar.
  ///
  /// This is *not* the Session Library's persistent index — that is
  /// `SessionLibrary`, in drift (§9.6). This list is per-run: what is open now.
  OpenSessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openSessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openSessionsHash();

  @$internal
  @override
  OpenSessions create() => OpenSessions();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TelemetrySource> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TelemetrySource>>(value),
    );
  }
}

String _$openSessionsHash() => r'ffdd67024d0f5af76e42b23db3cf278030320241';

/// The sources the user has opened this run, most recent first.
///
/// Held in app state rather than encoded in the route, because a route
/// parameter cannot express both platforms: on web a session is a byte buffer
/// in memory with no path to put in a URL (§9.2). Keeping the identity here
/// means the same navigation works on desktop and web instead of one target
/// carrying file paths through the address bar.
///
/// This is *not* the Session Library's persistent index — that is
/// `SessionLibrary`, in drift (§9.6). This list is per-run: what is open now.

abstract class _$OpenSessions extends $Notifier<List<TelemetrySource>> {
  List<TelemetrySource> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<List<TelemetrySource>, List<TelemetrySource>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<TelemetrySource>, List<TelemetrySource>>,
              List<TelemetrySource>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The session the feature screens are looking at, or null when none is open.

@ProviderFor(currentSession)
final currentSessionProvider = CurrentSessionProvider._();

/// The session the feature screens are looking at, or null when none is open.

final class CurrentSessionProvider
    extends
        $FunctionalProvider<
          TelemetrySource?,
          TelemetrySource?,
          TelemetrySource?
        >
    with $Provider<TelemetrySource?> {
  /// The session the feature screens are looking at, or null when none is open.
  CurrentSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentSessionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentSessionHash();

  @$internal
  @override
  $ProviderElement<TelemetrySource?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TelemetrySource? create(Ref ref) {
    return currentSession(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TelemetrySource? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TelemetrySource?>(value),
    );
  }
}

String _$currentSessionHash() => r'1436475717ab2cd13a0c64254316e17a90fbc8e9';
