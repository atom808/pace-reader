// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'folder_scan.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Scans remembered folders and adds what it finds to the library.
///
/// On demand — "Add folder" and "Refresh" — rather than a filesystem
/// watcher. A watcher would pick up a recording LMU is still writing, whose
/// `Lap` table grows until the session ends, and index it half-finished; and
/// a rescan that skips unchanged files is cheap enough that pressing Refresh
/// after a session costs a second, not a minute.
///
/// Kept alive so a scan keeps going, and keeps reporting, when the user
/// navigates to another screen mid-way.

@ProviderFor(FolderScan)
final folderScanProvider = FolderScanProvider._();

/// Scans remembered folders and adds what it finds to the library.
///
/// On demand — "Add folder" and "Refresh" — rather than a filesystem
/// watcher. A watcher would pick up a recording LMU is still writing, whose
/// `Lap` table grows until the session ends, and index it half-finished; and
/// a rescan that skips unchanged files is cheap enough that pressing Refresh
/// after a session costs a second, not a minute.
///
/// Kept alive so a scan keeps going, and keeps reporting, when the user
/// navigates to another screen mid-way.
final class FolderScanProvider
    extends $NotifierProvider<FolderScan, FolderScanState> {
  /// Scans remembered folders and adds what it finds to the library.
  ///
  /// On demand — "Add folder" and "Refresh" — rather than a filesystem
  /// watcher. A watcher would pick up a recording LMU is still writing, whose
  /// `Lap` table grows until the session ends, and index it half-finished; and
  /// a rescan that skips unchanged files is cheap enough that pressing Refresh
  /// after a session costs a second, not a minute.
  ///
  /// Kept alive so a scan keeps going, and keeps reporting, when the user
  /// navigates to another screen mid-way.
  FolderScanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'folderScanProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$folderScanHash();

  @$internal
  @override
  FolderScan create() => FolderScan();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FolderScanState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FolderScanState>(value),
    );
  }
}

String _$folderScanHash() => r'fc2ebef596edbfe6b051112331bc28d4240fb61b';

/// Scans remembered folders and adds what it finds to the library.
///
/// On demand — "Add folder" and "Refresh" — rather than a filesystem
/// watcher. A watcher would pick up a recording LMU is still writing, whose
/// `Lap` table grows until the session ends, and index it half-finished; and
/// a rescan that skips unchanged files is cheap enough that pressing Refresh
/// after a session costs a second, not a minute.
///
/// Kept alive so a scan keeps going, and keeps reporting, when the user
/// navigates to another screen mid-way.

abstract class _$FolderScan extends $Notifier<FolderScanState> {
  FolderScanState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FolderScanState, FolderScanState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FolderScanState, FolderScanState>,
              FolderScanState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
