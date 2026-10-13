// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'segment_tables.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Every course's table, held in memory for the run (persisted from step 10).
///
/// Written only by [ensure], so nothing that merely reads a table — a new
/// Target, a Swap, the canonical lap's file closing — can recompute it:
/// "Seg 3" keeps meaning the same metres whichever lap is Base.

@ProviderFor(SegmentTableStore)
final segmentTableStoreProvider = SegmentTableStoreProvider._();

/// Every course's table, held in memory for the run (persisted from step 10).
///
/// Written only by [ensure], so nothing that merely reads a table — a new
/// Target, a Swap, the canonical lap's file closing — can recompute it:
/// "Seg 3" keeps meaning the same metres whichever lap is Base.
final class SegmentTableStoreProvider
    extends $NotifierProvider<SegmentTableStore, Map<TrackKey, SegmentTable>> {
  /// Every course's table, held in memory for the run (persisted from step 10).
  ///
  /// Written only by [ensure], so nothing that merely reads a table — a new
  /// Target, a Swap, the canonical lap's file closing — can recompute it:
  /// "Seg 3" keeps meaning the same metres whichever lap is Base.
  SegmentTableStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'segmentTableStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$segmentTableStoreHash();

  @$internal
  @override
  SegmentTableStore create() => SegmentTableStore();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<TrackKey, SegmentTable> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<TrackKey, SegmentTable>>(value),
    );
  }
}

String _$segmentTableStoreHash() => r'9a98ddd02db408e9d1f53e84d4fc1a3fa6ea443b';

/// Every course's table, held in memory for the run (persisted from step 10).
///
/// Written only by [ensure], so nothing that merely reads a table — a new
/// Target, a Swap, the canonical lap's file closing — can recompute it:
/// "Seg 3" keeps meaning the same metres whichever lap is Base.

abstract class _$SegmentTableStore
    extends $Notifier<Map<TrackKey, SegmentTable>> {
  Map<TrackKey, SegmentTable> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<Map<TrackKey, SegmentTable>, Map<TrackKey, SegmentTable>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                Map<TrackKey, SegmentTable>,
                Map<TrackKey, SegmentTable>
              >,
              Map<TrackKey, SegmentTable>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// [key]'s table, if one was detected — read from the store and nothing else.

@ProviderFor(segmentTable)
final segmentTableProvider = SegmentTableFamily._();

/// [key]'s table, if one was detected — read from the store and nothing else.

final class SegmentTableProvider
    extends $FunctionalProvider<SegmentTable?, SegmentTable?, SegmentTable?>
    with $Provider<SegmentTable?> {
  /// [key]'s table, if one was detected — read from the store and nothing else.
  SegmentTableProvider._({
    required SegmentTableFamily super.from,
    required TrackKey super.argument,
  }) : super(
         retry: null,
         name: r'segmentTableProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$segmentTableHash();

  @override
  String toString() {
    return r'segmentTableProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SegmentTable?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SegmentTable? create(Ref ref) {
    final argument = this.argument as TrackKey;
    return segmentTable(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SegmentTable? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SegmentTable?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SegmentTableProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$segmentTableHash() => r'cf602a1d34d7e593bc9f160fcea8174e64ff306d';

/// [key]'s table, if one was detected — read from the store and nothing else.

final class SegmentTableFamily extends $Family
    with $FunctionalFamilyOverride<SegmentTable?, TrackKey> {
  SegmentTableFamily._()
    : super(
        retry: null,
        name: r'segmentTableProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [key]'s table, if one was detected — read from the store and nothing else.

  SegmentTableProvider call(TrackKey key) =>
      SegmentTableProvider._(argument: key, from: this);

  @override
  String toString() => r'segmentTableProvider';
}

/// A table detected for [set]'s course: the command [comparisonSegments]
/// issues when the course has none yet.
///
/// The canonical lap is the faster *clean* lap of Base and the Target; if
/// neither is clean, the fastest clean lap of their files (§5 "Canonical
/// lap"). Every other clean lap of the two files then votes on each corner's
/// stability. Reads Ground Speed for every lap that passes the cheap rules,
/// and only from files in Open now.

@ProviderFor(segmentDetection)
final segmentDetectionProvider = SegmentDetectionFamily._();

/// A table detected for [set]'s course: the command [comparisonSegments]
/// issues when the course has none yet.
///
/// The canonical lap is the faster *clean* lap of Base and the Target; if
/// neither is clean, the fastest clean lap of their files (§5 "Canonical
/// lap"). Every other clean lap of the two files then votes on each corner's
/// stability. Reads Ground Speed for every lap that passes the cheap rules,
/// and only from files in Open now.

final class SegmentDetectionProvider
    extends
        $FunctionalProvider<
          AsyncValue<SegmentTable>,
          SegmentTable,
          FutureOr<SegmentTable>
        >
    with $FutureModifier<SegmentTable>, $FutureProvider<SegmentTable> {
  /// A table detected for [set]'s course: the command [comparisonSegments]
  /// issues when the course has none yet.
  ///
  /// The canonical lap is the faster *clean* lap of Base and the Target; if
  /// neither is clean, the fastest clean lap of their files (§5 "Canonical
  /// lap"). Every other clean lap of the two files then votes on each corner's
  /// stability. Reads Ground Speed for every lap that passes the cheap rules,
  /// and only from files in Open now.
  SegmentDetectionProvider._({
    required SegmentDetectionFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'segmentDetectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$segmentDetectionHash();

  @override
  String toString() {
    return r'segmentDetectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SegmentTable> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SegmentTable> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return segmentDetection(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SegmentDetectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$segmentDetectionHash() => r'd8db529e81ca25fd00e73f7a08b9fc4c2e36f74d';

/// A table detected for [set]'s course: the command [comparisonSegments]
/// issues when the course has none yet.
///
/// The canonical lap is the faster *clean* lap of Base and the Target; if
/// neither is clean, the fastest clean lap of their files (§5 "Canonical
/// lap"). Every other clean lap of the two files then votes on each corner's
/// stability. Reads Ground Speed for every lap that passes the cheap rules,
/// and only from files in Open now.

final class SegmentDetectionFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SegmentTable>, ComparisonSet> {
  SegmentDetectionFamily._()
    : super(
        retry: _neverRetry,
        name: r'segmentDetectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A table detected for [set]'s course: the command [comparisonSegments]
  /// issues when the course has none yet.
  ///
  /// The canonical lap is the faster *clean* lap of Base and the Target; if
  /// neither is clean, the fastest clean lap of their files (§5 "Canonical
  /// lap"). Every other clean lap of the two files then votes on each corner's
  /// stability. Reads Ground Speed for every lap that passes the cheap rules,
  /// and only from files in Open now.

  SegmentDetectionProvider call(ComparisonSet set) =>
      SegmentDetectionProvider._(argument: set, from: this);

  @override
  String toString() => r'segmentDetectionProvider';
}

/// [set]'s segment losses and sectors, or null without a Target or for a
/// pair the course gate refused.
///
/// Reads the course's table from the store. When the course has none yet,
/// or one cut for a different lap length, it detects one and issues
/// [SegmentTableStore.ensure]: the store then holds it for every later
/// comparison of the course, and this rebuilds from the store.

@ProviderFor(comparisonSegments)
final comparisonSegmentsProvider = ComparisonSegmentsFamily._();

/// [set]'s segment losses and sectors, or null without a Target or for a
/// pair the course gate refused.
///
/// Reads the course's table from the store. When the course has none yet,
/// or one cut for a different lap length, it detects one and issues
/// [SegmentTableStore.ensure]: the store then holds it for every later
/// comparison of the course, and this rebuilds from the store.

final class ComparisonSegmentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<ComparisonSegments?>,
          ComparisonSegments?,
          FutureOr<ComparisonSegments?>
        >
    with
        $FutureModifier<ComparisonSegments?>,
        $FutureProvider<ComparisonSegments?> {
  /// [set]'s segment losses and sectors, or null without a Target or for a
  /// pair the course gate refused.
  ///
  /// Reads the course's table from the store. When the course has none yet,
  /// or one cut for a different lap length, it detects one and issues
  /// [SegmentTableStore.ensure]: the store then holds it for every later
  /// comparison of the course, and this rebuilds from the store.
  ComparisonSegmentsProvider._({
    required ComparisonSegmentsFamily super.from,
    required ComparisonSet super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'comparisonSegmentsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$comparisonSegmentsHash();

  @override
  String toString() {
    return r'comparisonSegmentsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ComparisonSegments?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ComparisonSegments?> create(Ref ref) {
    final argument = this.argument as ComparisonSet;
    return comparisonSegments(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ComparisonSegmentsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$comparisonSegmentsHash() =>
    r'62e3d1cd6e8bfa016bc6f731488479cc979bd17b';

/// [set]'s segment losses and sectors, or null without a Target or for a
/// pair the course gate refused.
///
/// Reads the course's table from the store. When the course has none yet,
/// or one cut for a different lap length, it detects one and issues
/// [SegmentTableStore.ensure]: the store then holds it for every later
/// comparison of the course, and this rebuilds from the store.

final class ComparisonSegmentsFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ComparisonSegments?>,
          ComparisonSet
        > {
  ComparisonSegmentsFamily._()
    : super(
        retry: _neverRetry,
        name: r'comparisonSegmentsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// [set]'s segment losses and sectors, or null without a Target or for a
  /// pair the course gate refused.
  ///
  /// Reads the course's table from the store. When the course has none yet,
  /// or one cut for a different lap length, it detects one and issues
  /// [SegmentTableStore.ensure]: the store then holds it for every later
  /// comparison of the course, and this rebuilds from the store.

  ComparisonSegmentsProvider call(ComparisonSet set) =>
      ComparisonSegmentsProvider._(argument: set, from: this);

  @override
  String toString() => r'comparisonSegmentsProvider';
}
