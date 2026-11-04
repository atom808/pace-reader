// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chart_sync.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different playheads,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one playhead moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
///
/// What Phase 3 does need is to know whose lap the playhead is on, so each
/// screen [claim]s the controller for what it shows (see `SyncOwner`), and a
/// screen that does not own it draws neither the playhead nor the window.

@ProviderFor(ChartSync)
final chartSyncProvider = ChartSyncProvider._();

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different playheads,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one playhead moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
///
/// What Phase 3 does need is to know whose lap the playhead is on, so each
/// screen [claim]s the controller for what it shows (see `SyncOwner`), and a
/// screen that does not own it draws neither the playhead nor the window.
final class ChartSyncProvider
    extends $NotifierProvider<ChartSync, ChartSyncState> {
  /// One controller, app-wide, deliberately not a family.
  ///
  /// A family keyed by session would let two open files hold different playheads,
  /// which is the opposite of what §8.8's comparison view needs: comparing two
  /// drivers' laps means one playhead moving across both. Phase 1 has one session
  /// open at a time, and Phase 3 wants them synced — neither wants a key.
  ///
  /// What Phase 3 does need is to know whose lap the playhead is on, so each
  /// screen [claim]s the controller for what it shows (see `SyncOwner`), and a
  /// screen that does not own it draws neither the playhead nor the window.
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

String _$chartSyncHash() => r'de65a5b8e7aa896ea7bb0bc809b268ad165544ad';

/// One controller, app-wide, deliberately not a family.
///
/// A family keyed by session would let two open files hold different playheads,
/// which is the opposite of what §8.8's comparison view needs: comparing two
/// drivers' laps means one playhead moving across both. Phase 1 has one session
/// open at a time, and Phase 3 wants them synced — neither wants a key.
///
/// What Phase 3 does need is to know whose lap the playhead is on, so each
/// screen [claim]s the controller for what it shows (see `SyncOwner`), and a
/// screen that does not own it draws neither the playhead nor the window.

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
