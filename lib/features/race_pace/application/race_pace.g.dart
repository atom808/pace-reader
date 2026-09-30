// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'race_pace.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The race-pace report for one session.
///
/// **Two reads of the same channel, on purpose.** The trace drawn is fetched
/// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
/// session scope. The analysis is not: a change of car ahead is a single
/// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
/// bucket count — it cannot be seen, so every lap's figure would be quietly
/// contaminated by passes the bucketing had swallowed. The full series costs
/// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
/// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
/// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
/// *drawing* that many points, and nothing here does.
///
/// A session that is not a race returns before reading the channel at all.

@ProviderFor(racePaceReport)
final racePaceReportProvider = RacePaceReportFamily._();

/// The race-pace report for one session.
///
/// **Two reads of the same channel, on purpose.** The trace drawn is fetched
/// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
/// session scope. The analysis is not: a change of car ahead is a single
/// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
/// bucket count — it cannot be seen, so every lap's figure would be quietly
/// contaminated by passes the bucketing had swallowed. The full series costs
/// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
/// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
/// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
/// *drawing* that many points, and nothing here does.
///
/// A session that is not a race returns before reading the channel at all.

final class RacePaceReportProvider
    extends
        $FunctionalProvider<
          AsyncValue<RacePaceReport>,
          RacePaceReport,
          FutureOr<RacePaceReport>
        >
    with $FutureModifier<RacePaceReport>, $FutureProvider<RacePaceReport> {
  /// The race-pace report for one session.
  ///
  /// **Two reads of the same channel, on purpose.** The trace drawn is fetched
  /// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
  /// session scope. The analysis is not: a change of car ahead is a single
  /// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
  /// bucket count — it cannot be seen, so every lap's figure would be quietly
  /// contaminated by passes the bucketing had swallowed. The full series costs
  /// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
  /// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
  /// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
  /// *drawing* that many points, and nothing here does.
  ///
  /// A session that is not a race returns before reading the channel at all.
  RacePaceReportProvider._({
    required RacePaceReportFamily super.from,
    required TelemetrySource super.argument,
  }) : super(
         retry: _neverRetry,
         name: r'racePaceReportProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$racePaceReportHash();

  @override
  String toString() {
    return r'racePaceReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RacePaceReport> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RacePaceReport> create(Ref ref) {
    final argument = this.argument as TelemetrySource;
    return racePaceReport(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RacePaceReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$racePaceReportHash() => r'7372a5d840cc6abc0dc7f9a1bdd50bddfd38532b';

/// The race-pace report for one session.
///
/// **Two reads of the same channel, on purpose.** The trace drawn is fetched
/// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
/// session scope. The analysis is not: a change of car ahead is a single
/// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
/// bucket count — it cannot be seen, so every lap's figure would be quietly
/// contaminated by passes the bucketing had swallowed. The full series costs
/// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
/// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
/// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
/// *drawing* that many points, and nothing here does.
///
/// A session that is not a race returns before reading the channel at all.

final class RacePaceReportFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RacePaceReport>, TelemetrySource> {
  RacePaceReportFamily._()
    : super(
        retry: _neverRetry,
        name: r'racePaceReportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The race-pace report for one session.
  ///
  /// **Two reads of the same channel, on purpose.** The trace drawn is fetched
  /// decimated ([sessionEnvelopeBuckets] min/max buckets), as §9.5 requires at
  /// session scope. The analysis is not: a change of car ahead is a single
  /// 0.5 s step, and inside a bucket of 173 readings — a 24-hour file at that
  /// bucket count — it cannot be seen, so every lap's figure would be quietly
  /// contaminated by passes the bucketing had swallowed. The full series costs
  /// what an event table does, not what a trace does: `Time Behind Next` is 2 Hz,
  /// 172,800 rows over 24 hours against 2.16M for a 6-hour 100 Hz channel, and
  /// the Race sample's 2,682 read in a few milliseconds. What §9.5 forbids is
  /// *drawing* that many points, and nothing here does.
  ///
  /// A session that is not a race returns before reading the channel at all.

  RacePaceReportProvider call(TelemetrySource source) =>
      RacePaceReportProvider._(argument: source, from: this);

  @override
  String toString() => r'racePaceReportProvider';
}
