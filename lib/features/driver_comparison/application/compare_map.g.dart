// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compare_map.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the map shows the Target's ghost on the Time axis. Kept for the
/// run.

@ProviderFor(GhostShown)
final ghostShownProvider = GhostShownProvider._();

/// Whether the map shows the Target's ghost on the Time axis. Kept for the
/// run.
final class GhostShownProvider extends $NotifierProvider<GhostShown, bool> {
  /// Whether the map shows the Target's ghost on the Time axis. Kept for the
  /// run.
  GhostShownProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ghostShownProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ghostShownHash();

  @$internal
  @override
  GhostShown create() => GhostShown();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$ghostShownHash() => r'49d68f683fd035ac3c00e844352cef3e6982961a';

/// Whether the map shows the Target's ghost on the Time axis. Kept for the
/// run.

abstract class _$GhostShown extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
