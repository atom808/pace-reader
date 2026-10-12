// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comparison_focus.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SegmentFocus)
final segmentFocusProvider = SegmentFocusProvider._();

final class SegmentFocusProvider
    extends $NotifierProvider<SegmentFocus, SegmentFocusState> {
  SegmentFocusProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'segmentFocusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$segmentFocusHash();

  @$internal
  @override
  SegmentFocus create() => SegmentFocus();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SegmentFocusState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SegmentFocusState>(value),
    );
  }
}

String _$segmentFocusHash() => r'c3212fd0563f1a227db717b8b6b59a2b57fc9383';

abstract class _$SegmentFocus extends $Notifier<SegmentFocusState> {
  SegmentFocusState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SegmentFocusState, SegmentFocusState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SegmentFocusState, SegmentFocusState>,
              SegmentFocusState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
