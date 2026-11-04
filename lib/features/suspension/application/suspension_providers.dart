/// Suspension's providers (suspension proposal §7), keyed by
/// [TelemetrySource]:
///
/// 1. [suspensionOverviewProvider]: every strike, the sites and their
///    verdicts, each lap's platform numbers and damper histograms. Read once
///    per session: about 1 s on a 2-hour Le Mans segment.
/// 2. [siteTracesProvider]: one site's traces, read when the site is shown.
/// 3. [suspensionSelectionStateProvider] and [suspensionHoverStateProvider]: what
///    the screen is showing and pointing at.
///
/// The racing laps, the map and the segment names come from Technique's
/// providers, so the two screens agree on which laps count.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/technique_queries.dart' show LapSpan;
import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/providers.dart';
import '../../driving_technique/application/technique_providers.dart';
import '../../setup_viewer/application/car_setup.dart';
import '../../setup_viewer/application/car_setup_provider.dart';
import '../data/suspension_repository.dart';
import '../domain/platform.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';

part 'suspension_providers.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SuspensionRepository> suspensionRepository(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(telemetrySessionProvider(source).future);
  return SuspensionRepository(session.database, session.catalog);
}

/// Everything the screen draws before a site is opened.
class SuspensionOverview {
  const SuspensionOverview({
    required this.session,
    required this.hasRideHeights,
    this.strikes = const [],
    this.sites = const [],
    this.verdicts = const {},
    this.platform = const [],
    this.ceilings = const ThirdCeilings(),
    this.dampers = const {},
    this.setup,
    this.hasThirdElement = false,
    this.knee = const DamperKnee(front: 100, rear: 100, measured: false),
    this.balanceSteps = const [],
  });

  final TechniqueSession session;

  /// False when the file has no 100 Hz ride heights: nothing to measure.
  final bool hasRideHeights;

  /// Every strike on a racing lap, Close and off-track ones included.
  final List<Strike> strikes;

  /// Ranked: most laps struck first (§4.3).
  final List<Site> sites;
  final Map<int, SiteVerdict> verdicts;
  final List<LapPlatform> platform;
  final ThirdCeilings ceilings;
  final Map<int, Map<Corner, DamperHistogram>> dampers;
  final CarSetup? setup;

  /// From the setup, not the channels: GT3 files carry junk third channels.
  final bool hasThirdElement;
  final DamperKnee knee;

  /// Laps where the roll balance stepped.
  final List<int> balanceSteps;

  List<Lap> get racing => session.racing;
  int get racingLapCount => session.racing.length;

  /// Strike-tier, on track or kerb: what the headline counts.
  Iterable<Strike> get headline => strikes.where(
    (s) => s.tier == StrikeTier.strike && s.surface != StrikeSurface.offTrack,
  );

  /// [lap]'s strikes, every tier and surface.
  List<Strike> strikesOn(int lap) => [
    for (final s in strikes)
      if (s.lap == lap) s,
  ];

  Site? site(int? key) {
    if (key == null) return null;
    for (final s in sites) {
      if (s.key == key) return s;
    }
    return null;
  }

  LapPlatform? platformOf(int lap) {
    for (final p in platform) {
      if (p.lap == lap) return p;
    }
    return null;
  }

  /// The session's histogram for [corner], every racing lap.
  DamperHistogram sessionDampers(Corner corner) {
    var out = DamperHistogram.empty;
    for (final lap in dampers.values) {
      if (lap[corner] case final h?) out = out + h;
    }
    return out;
  }
}

@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SuspensionOverview> suspensionOverview(
  Ref ref,
  TelemetrySource source,
) async {
  final session = await ref.watch(techniqueSessionProvider(source).future);
  final repo = await ref.watch(suspensionRepositoryProvider(source).future);
  CarSetup? setup;
  try {
    setup = await ref.watch(carSetupProvider(source).future);
  } on SetupFormatException {
    setup = null;
  }
  if (repo.channels == null || session.laps.isEmpty) {
    return SuspensionOverview(
      session: session,
      hasRideHeights: repo.channels != null,
      setup: setup,
    );
  }
  // Racing laps by Technique's rule, decided without the pedals: a file
  // that lacks them still has ride heights to read.
  final racing = session.racing;
  final spans = <LapSpan>[
    for (final l in racing)
      (lap: l.index, start: l.startSeconds, end: l.endSeconds!),
  ];
  final hasThird =
      (setup?.hasThirdElement ?? false) &&
      (repo.channels?.hasThirdChannels ?? false);
  final platformRead = repo.readPlatform(spans);
  final dampersRead = repo.readDampers(spans);
  final strikes = await repo.readStrikes(spans);
  final sites = rankSites(clusterSites(strikes));
  final lows = await repo.readSiteLows(spans, sites);
  final (platform, ceilings) = await platformRead;
  final dampers = await dampersRead;
  return SuspensionOverview(
    session: session,
    hasRideHeights: true,
    strikes: strikes,
    sites: sites,
    verdicts: {
      for (final s in sites)
        s.key: verdictFor(
          s,
          lows[s.key] ?? const [],
          racingLaps: racing.length,
        ),
    },
    platform: hasThird
        ? platform
        : [
            for (final p in platform)
              LapPlatform(
                lap: p.lap,
                samplesAtSpeed: p.samplesAtSpeed,
                frontMedian: p.frontMedian,
                rearMedian: p.rearMedian,
                frontLowest: p.frontLowest,
                rearLowest: p.rearLowest,
                frontRoll: p.frontRoll,
                frontRollR: p.frontRollR,
                rearRoll: p.rearRoll,
                rearRollR: p.rearRollR,
                rollSamples: p.rollSamples,
              ),
          ],
    ceilings: hasThird ? ceilings : const ThirdCeilings(),
    dampers: dampers,
    setup: setup,
    hasThirdElement: hasThird,
    knee: DamperKnee.forCar(session.metadata.carName),
    balanceSteps: balanceSteps(platform),
  );
}

/// One site's traces, every racing lap, over its window.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<List<SiteTrace>> siteTraces(
  Ref ref,
  TelemetrySource source,
  int siteKey,
) async {
  final overview = await ref.watch(suspensionOverviewProvider(source).future);
  final site = overview.site(siteKey);
  if (site == null) return const [];
  final repo = await ref.watch(suspensionRepositoryProvider(source).future);
  return repo.readSiteTraces(
    overview.session.spans,
    start: site.start,
    end: site.end,
  );
}

/// What the screen shows.
class SuspensionSelection {
  const SuspensionSelection({
    this.lapIndex,
    this.siteKey,
    this.phase,
    this.evidence = false,
  });

  /// Null shows the lap with the most strikes, else the fastest.
  final int? lapIndex;

  /// Null shows the top-ranked site.
  final int? siteKey;

  /// Filters the map and the sites list to one phase; braking includes
  /// braking into a corner.
  final StrikePhase? phase;

  /// Whether the verdict's evidence is open.
  final bool evidence;

  SuspensionSelection copyWith({
    int? lapIndex,
    int? siteKey,
    StrikePhase? Function()? phase,
    bool? evidence,
  }) => SuspensionSelection(
    lapIndex: lapIndex ?? this.lapIndex,
    siteKey: siteKey ?? this.siteKey,
    phase: phase == null ? this.phase : phase(),
    evidence: evidence ?? this.evidence,
  );
}

@Riverpod(keepAlive: true)
class SuspensionSelectionState extends _$SuspensionSelectionState {
  @override
  SuspensionSelection build(TelemetrySource source) =>
      const SuspensionSelection();

  void selectLap(int index) => state = state.copyWith(lapIndex: index);

  void selectSite(int key) => state = state.copyWith(siteKey: key);

  void setPhase(StrikePhase? phase) =>
      state = state.copyWith(phase: () => phase);

  void toggleEvidence() => state = state.copyWith(evidence: !state.evidence);
}

/// What the pointer is on: a site (its row, glyph and ✕ light together) and
/// a metre in the site window (the trace cursor).
class SuspensionHover {
  const SuspensionHover({this.siteKey, this.metre, this.lap});

  final int? siteKey;
  final double? metre;

  /// A lap raised by hovering its line in the ribbon.
  final int? lap;
}

@riverpod
class SuspensionHoverState extends _$SuspensionHoverState {
  @override
  SuspensionHover build(TelemetrySource source) => const SuspensionHover();

  void site(int? key) {
    if (key == state.siteKey) return;
    state = SuspensionHover(siteKey: key, metre: state.metre, lap: state.lap);
  }

  void cursor(double? metre, {int? lap}) {
    if (metre == state.metre && lap == state.lap) return;
    state = SuspensionHover(siteKey: state.siteKey, metre: metre, lap: lap);
  }
}

/// Which phases a filter shows.
bool phaseMatches(StrikePhase? filter, StrikePhase phase) => switch (filter) {
  null => true,
  StrikePhase.braking => phase.isBraking,
  _ => phase == filter,
};
