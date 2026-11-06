/// The open recording's session in LMU's results: what the Overview's facts
/// (results proposal, R4) and the race-control marks (R3) read.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/duckdb/telemetry_database.dart';
import '../../../data/repositories/providers.dart';
import '../../../data/models/models.dart';
import '../data/results_index_store.dart';
import '../domain/bop.dart';
import '../domain/bop_allowance.dart';
import '../domain/bop_documents.dart';
import '../domain/field_pace.dart';
import '../domain/race_control.dart';
import '../domain/results_link.dart';
import '../domain/results_session.dart';
import 'session_results.dart';

part 'linked_results.g.dart';

Duration? _neverRetry(int retryCount, Object error) => null;

/// A recording's results session, the car in it, and how they were matched.
class LinkedResults {
  const LinkedResults({required this.link, required this.session});

  final ResultsLink link;
  final ResultsSession session;

  /// The recording's car in [session].
  ResultsDriver get car =>
      session.drivers.firstWhere((d) => d.index == link.driverIndex);

  /// The cars in [car]'s class, [car] included.
  List<ResultsDriver> get classField => [
    for (final d in session.drivers)
      if (d.carClass == car.carClass) d,
  ];
}

/// The results session [source] was recorded in, read whole from the index,
/// or null when no file links (or no results folder was ever added).
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<LinkedResults?> linkedResults(Ref ref, TelemetrySource source) async {
  ref.watch(resultsIndexRevisionProvider);
  final store = ref.watch(resultsIndexStoreProvider);
  final metadata = await ref.watch(sessionMetadataProvider(source).future);
  final laps = await ref.watch(lapsProvider(source).future);
  final link = await findResultsLink(
    store,
    RecordingKey.ofSession(metadata, laps),
  );
  if (link == null) return null;
  final session = await store.readSession(link.path);
  if (session == null) return null;
  if (!session.drivers.any((d) => d.index == link.driverIndex)) return null;
  return LinkedResults(link: link, session: session);
}

/// The BoP a results session ran under: each car's figures, and whether the
/// event kept BoP's stint energy (PACE-FACTORS §5.6, §5.7).
class SessionBop {
  const SessionBop({
    this.document,
    this.group,
    this.entries = const {},
    this.allowance = const BopAllowance(kind: BopAllowanceKind.unchecked),
    this.missing,
  });

  /// Null when no document the app holds covers the session.
  final BopDocument? document;

  /// The document's track group (`Le Mans`).
  final String? group;

  /// By [ResultsDriver.index], for the cars the document lists.
  final Map<int, BopEntry> entries;
  final BopAllowance allowance;

  /// Why there is no BoP, in a sentence, when there is none.
  final String? missing;

  BopEntry? of(ResultsDriver car) => entries[car.index];

  /// Whether energy shares may be read as megajoules: only where the
  /// session's shares match the user's other sessions under this BoP.
  bool get inMegajoules => allowance.kind == BopAllowanceKind.matches;
}

/// [session]'s BoP, the allowance checked against [store]'s other files.
Future<SessionBop> sessionBopOf({
  required ResultsIndexStore store,
  required String path,
  required ResultsSession session,
  required ResultsDriver car,
  List<BopDocument> documents = bopDocuments,
}) async {
  final document = bopDocumentFor(session, documents: documents);
  if (document == null) {
    final oldest = documents.isEmpty ? null : documents.first;
    return SessionBop(
      missing: oldest == null || session.startedAt.isBefore(oldest.publishedOn)
          ? 'The app holds no BoP from before '
                '${oldest == null ? 'any document' : _day(oldest)}.'
          : 'This session ran on game version ${session.gameVersion}, which '
                'none of the app’s BoP documents shipped with.',
    );
  }
  final group = bopTrackGroup(session.trackVenue, session.trackCourse);
  if (group == null) {
    return SessionBop(
      document: document,
      missing: 'BoP ${document.version} does not list ${session.trackVenue}.',
    );
  }
  final carClass = BopClass.of(car.carClass);
  if (carClass == null) {
    return SessionBop(
      document: document,
      group: group,
      missing: 'BoP sets no stint energy for ${car.carClass}.',
    );
  }
  final entries = <int, BopEntry>{
    for (final d in session.drivers)
      if (d.carClass == car.carClass)
        if (bopModel(d) case final model?)
          d.index: ?document.entry(group, carClass, model),
  };
  final ends = bopDocumentEnds(document, documents: documents);
  final others = await store.energyShares(
    trackVenue: session.trackVenue,
    from: document.publishedOn,
    to: ends,
  );
  return SessionBop(
    document: document,
    group: group,
    entries: entries,
    allowance: checkBopAllowance(
      path: path,
      session: session,
      document: document,
      documentEnds: ends,
      others: others,
    ),
  );
}

String _day(BopDocument d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// The BoP of the results session [source] links to; null without one.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionBop?> sessionBop(Ref ref, TelemetrySource source) async {
  final linked = await ref.watch(linkedResultsProvider(source).future);
  if (linked == null) return null;
  return sessionBopOf(
    store: ref.watch(resultsIndexStoreProvider),
    path: linked.link.path,
    session: linked.session,
    car: linked.car,
  );
}

/// Race control's calls about the recording's car, and the laps they fell
/// on (results proposal, R3).
class SessionRaceControl {
  const SessionRaceControl({required this.calls, required this.byLap});

  final List<RaceControlCall> calls;

  /// Keyed by `Lap.index`; only laps with a call.
  final Map<int, List<RaceControlCall>> byLap;

  List<RaceControlCall> of(Lap lap) => byLap[lap.index] ?? const [];
}

/// Null when the recording links to no results file.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionRaceControl?> sessionRaceControl(
  Ref ref,
  TelemetrySource source,
) async {
  final linked = await ref.watch(linkedResultsProvider(source).future);
  if (linked == null) return null;
  final laps = await ref.watch(lapsProvider(source).future);
  final calls = raceControlFor(linked.session, linked.car);
  return SessionRaceControl(calls: calls, byLap: raceControlByLap(calls, laps));
}

/// The car's pace against its class, and which of the file's laps each of
/// the recording's laps is (results proposal, R2).
class SessionFieldPace {
  SessionFieldPace({required this.pace, required List<Lap> laps})
    : _numbers = {
        for (final lap in laps)
          lap.index: _numberOf(lap, pace.me.driver.laps) ?? lap.displayNumber,
      };

  final FieldPace pace;
  final Map<int, int> _numbers;

  /// The file's 1-based number for [lap]: found by its start time, which
  /// both clocks share, and by its position when the file has no time for
  /// it.
  int numberOf(Lap lap) => _numbers[lap.index] ?? lap.displayNumber;

  static int? _numberOf(Lap lap, List<ResultsLap> laps) {
    for (final l in laps) {
      if (l.startElapsed case final start?
          when (start - lap.startSeconds).abs() < 1.0) {
        return l.number;
      }
    }
    return null;
  }
}

/// Null when the recording links to no results file.
@Riverpod(keepAlive: true, retry: _neverRetry)
Future<SessionFieldPace?> sessionFieldPace(
  Ref ref,
  TelemetrySource source,
) async {
  final linked = await ref.watch(linkedResultsProvider(source).future);
  if (linked == null) return null;
  final laps = await ref.watch(lapsProvider(source).future);
  return SessionFieldPace(
    pace: FieldPace.of(linked.session, linked.car),
    laps: laps,
  );
}
