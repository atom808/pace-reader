// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_workspace.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The pair the user chose, or null for "not chosen yet".
///
/// Kept for the run and not persisted (open question 6). Null means Compare
/// follows the current session, with that session's displayed lap as Base
/// and no Target ([activeComparison]); the first explicit choice — a Target,
/// a Swap, "Open in Compare" — fixes the set, and from then on switching the
/// current session changes nothing here (§9: "Open in Trace is the only
/// action that makes a compared file current", and the reverse holds too).

@ProviderFor(ComparisonWorkspace)
final comparisonWorkspaceProvider = ComparisonWorkspaceProvider._();

/// The pair the user chose, or null for "not chosen yet".
///
/// Kept for the run and not persisted (open question 6). Null means Compare
/// follows the current session, with that session's displayed lap as Base
/// and no Target ([activeComparison]); the first explicit choice — a Target,
/// a Swap, "Open in Compare" — fixes the set, and from then on switching the
/// current session changes nothing here (§9: "Open in Trace is the only
/// action that makes a compared file current", and the reverse holds too).
final class ComparisonWorkspaceProvider
    extends $NotifierProvider<ComparisonWorkspace, ComparisonSet?> {
  /// The pair the user chose, or null for "not chosen yet".
  ///
  /// Kept for the run and not persisted (open question 6). Null means Compare
  /// follows the current session, with that session's displayed lap as Base
  /// and no Target ([activeComparison]); the first explicit choice — a Target,
  /// a Swap, "Open in Compare" — fixes the set, and from then on switching the
  /// current session changes nothing here (§9: "Open in Trace is the only
  /// action that makes a compared file current", and the reverse holds too).
  ComparisonWorkspaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'comparisonWorkspaceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$comparisonWorkspaceHash();

  @$internal
  @override
  ComparisonWorkspace create() => ComparisonWorkspace();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ComparisonSet? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ComparisonSet?>(value),
    );
  }
}

String _$comparisonWorkspaceHash() =>
    r'baf4517ae910a0378a47634b1019e990796faa25';

/// The pair the user chose, or null for "not chosen yet".
///
/// Kept for the run and not persisted (open question 6). Null means Compare
/// follows the current session, with that session's displayed lap as Base
/// and no Target ([activeComparison]); the first explicit choice — a Target,
/// a Swap, "Open in Compare" — fixes the set, and from then on switching the
/// current session changes nothing here (§9: "Open in Trace is the only
/// action that makes a compared file current", and the reverse holds too).

abstract class _$ComparisonWorkspace extends $Notifier<ComparisonSet?> {
  ComparisonSet? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ComparisonSet?, ComparisonSet?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ComparisonSet?, ComparisonSet?>,
              ComparisonSet?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The pair Compare shows: the user's choice, or else the current session's
/// displayed lap alone.
///
/// A recording's first lap is never a Compare lap (§4 Lap rules: its `Lap`
/// event is not a lap boundary), so a session showing it elsewhere opens
/// Compare on its best lap instead.

@ProviderFor(activeComparison)
final activeComparisonProvider = ActiveComparisonProvider._();

/// The pair Compare shows: the user's choice, or else the current session's
/// displayed lap alone.
///
/// A recording's first lap is never a Compare lap (§4 Lap rules: its `Lap`
/// event is not a lap boundary), so a session showing it elsewhere opens
/// Compare on its best lap instead.

final class ActiveComparisonProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComparisonSet?>,
          ComparisonSet?,
          FutureOr<ComparisonSet?>
        >
    with $FutureModifier<ComparisonSet?>, $FutureProvider<ComparisonSet?> {
  /// The pair Compare shows: the user's choice, or else the current session's
  /// displayed lap alone.
  ///
  /// A recording's first lap is never a Compare lap (§4 Lap rules: its `Lap`
  /// event is not a lap boundary), so a session showing it elsewhere opens
  /// Compare on its best lap instead.
  ActiveComparisonProvider._()
    : super(
        from: null,
        argument: null,
        retry: _neverRetry,
        name: r'activeComparisonProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeComparisonHash();

  @$internal
  @override
  $FutureProviderElement<ComparisonSet?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComparisonSet?> create(Ref ref) {
    return activeComparison(ref);
  }
}

String _$activeComparisonHash() => r'ea29bee819474b5120c5851058fd42d0fa1ec9e0';
