// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different cursors,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one cursor moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.

@ProviderFor(ChartSync)
final chartSyncProvider = ChartSyncProvider._();

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different cursors,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one cursor moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
final class ChartSyncProvider
    extends $NotifierProvider<ChartSync, ChartSyncState> {
  /// One controller, app-wide, deliberately not a family.
  ///
  /// A family keyed by session would let two open files hold different cursors,
  /// which is the opposite of what §8.8's comparison view needs: comparing two
  /// drivers' laps means one cursor moving across both. Phase 1 has one session
  /// open at a time, and Phase 3 wants them synced — neither wants a key.
  ChartSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chartSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chartSyncHash();

  @$internal
  @override
  ChartSync create() => ChartSync();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChartSyncState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChartSyncState>(value),
    );
  }
}

String _$chartSyncHash() => r'f3e0786ae4432ce31b944d9ec5f1b97f736377c3';

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different cursors,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one cursor moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.

abstract class _$ChartSync extends $Notifier<ChartSyncState> {
  ChartSyncState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ChartSyncState, ChartSyncState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChartSyncState, ChartSyncState>,
              ChartSyncState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
