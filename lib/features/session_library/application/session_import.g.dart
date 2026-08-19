// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_import.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives file selection and opening, and owns the error surface for both.
///
/// The controller reports failure as state rather than throwing, because every
/// failure here is a *user* event — wrong file, unreadable file, a session
/// recorded by a newer game build — and each has something specific to say
/// (§10). An import that throws past the UI would collapse all of them into
/// one generic red screen.

@ProviderFor(SessionImport)
final sessionImportProvider = SessionImportProvider._();

/// Drives file selection and opening, and owns the error surface for both.
///
/// The controller reports failure as state rather than throwing, because every
/// failure here is a *user* event — wrong file, unreadable file, a session
/// recorded by a newer game build — and each has something specific to say
/// (§10). An import that throws past the UI would collapse all of them into
/// one generic red screen.
final class SessionImportProvider
    extends $NotifierProvider<SessionImport, SessionImportState> {
  /// Drives file selection and opening, and owns the error surface for both.
  ///
  /// The controller reports failure as state rather than throwing, because every
  /// failure here is a *user* event — wrong file, unreadable file, a session
  /// recorded by a newer game build — and each has something specific to say
  /// (§10). An import that throws past the UI would collapse all of them into
  /// one generic red screen.
  SessionImportProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'sessionImportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionImportHash();

  @$internal
  @override
  SessionImport create() => SessionImport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionImportState>(value),
    );
  }
}

String _$sessionImportHash() => r'686c37e9cb5d870e1a2ad44b217de9e917d97c0e';

/// Drives file selection and opening, and owns the error surface for both.
///
/// The controller reports failure as state rather than throwing, because every
/// failure here is a *user* event — wrong file, unreadable file, a session
/// recorded by a newer game build — and each has something specific to say
/// (§10). An import that throws past the UI would collapse all of them into
/// one generic red screen.

abstract class _$SessionImport extends $Notifier<SessionImportState> {
  SessionImportState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionImportState, SessionImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionImportState, SessionImportState>,
              SessionImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
