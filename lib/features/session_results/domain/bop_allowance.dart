/// Whether a session kept BoP's stint energy (PACE-FACTORS §5.6, §5.7).
///
/// An event can set its own energy allowance, and neither the results file
/// nor the recording says so. What shows it is the energy share a lap takes:
/// under one BoP a model takes nearly the same share at a track in every
/// session (Le Mans Hypercars 0.078–0.086 across 18 files, 1.4.3), and an
/// allowance cut to 70 % would raise it by 43 %. So a session's shares are
/// set against the same models' in the user's other sessions at that track
/// under the same document.
library;

import 'bop.dart';
import 'field_pace.dart';
import 'results_session.dart';

/// One model's median energy share per pace lap in one results file.
class EnergyShareSample {
  const EnergyShareSample({
    required this.path,
    required this.startedAt,
    required this.trackVenue,
    required this.trackCourse,
    required this.gameVersion,
    required this.fuelMultiplier,
    required this.carClass,
    required this.model,
    required this.laps,
    required this.median,
  });

  final String path;
  final DateTime startedAt;
  final String trackVenue;
  final String trackCourse;
  final String gameVersion;
  final double? fuelMultiplier;
  final BopClass carClass;

  /// [bopModel]'s name.
  final String model;
  final int laps;
  final double median;
}

/// A model needs this many pace laps with an energy share in a file to
/// count: fewer is a share or two of 1/256 steps.
const energySampleMinLaps = 5;

/// [session]'s samples: one per BoP model with [energySampleMinLaps] pace
/// laps that carry a share, every car of the model pooled.
List<EnergyShareSample> energySharesOf(String path, ResultsSession session) {
  final shares = <(BopClass, String), List<double>>{};
  for (final d in session.drivers) {
    final carClass = BopClass.of(d.carClass);
    final model = bopModel(d);
    if (carClass == null || model == null) continue;
    for (final lap in d.laps) {
      if (!isPaceLap(lap)) continue;
      if (lap.energyUsedFraction case final e? when e > 0) {
        (shares[(carClass, model)] ??= []).add(e);
      }
    }
  }
  return [
    for (final MapEntry(key: (carClass, model), value: xs) in shares.entries)
      if (xs.length >= energySampleMinLaps)
        EnergyShareSample(
          path: path,
          startedAt: session.startedAt,
          trackVenue: session.trackVenue,
          trackCourse: session.trackCourse,
          gameVersion: session.gameVersion,
          fuelMultiplier: session.fuelMultiplier,
          carClass: carClass,
          model: model,
          laps: xs.length,
          median: quantile(xs..sort(), 0.5),
        ),
  ];
}

/// What the check found.
enum BopAllowanceKind {
  /// The shares match the user's other sessions under the same BoP.
  matches,

  /// They do not: the event set its own allowance.
  differs,

  /// No other session to set them against, or no shares in the file.
  unchecked,

  /// The event multiplied fuel use, which multiplies the shares too.
  multiplied,
}

/// How far a session's allowance may sit from BoP's and still count as
/// BoP's. Shares come in 1/256 steps (about 5 % of a Le Mans lap's 0.082),
/// and offline sessions, against AI, run about 5 % above online ones; an
/// allowance of 85 % of BoP or less shows.
const bopAllowanceTolerance = 0.12;

class BopAllowance {
  const BopAllowance({
    required this.kind,
    this.ratio,
    this.sessions = 0,
    this.models = 0,
  });

  final BopAllowanceKind kind;

  /// The allowance as a share of BoP's: the other sessions' shares over this
  /// one's (0.7 when each lap takes 1/0.7 of the usual share). Null when
  /// unchecked.
  final double? ratio;

  /// How many other files the check read.
  final int sessions;

  /// How many models it compared.
  final int models;
}

/// Whether [session] (at [path]) kept [document]'s stint energy, from
/// [others]: samples of the user's results files at the same venue.
BopAllowance checkBopAllowance({
  required String path,
  required ResultsSession session,
  required BopDocument document,
  required DateTime? documentEnds,
  required List<EnergyShareSample> others,
}) {
  if (session.fuelMultiplier case final m? when m != 1) {
    return const BopAllowance(kind: BopAllowanceKind.multiplied);
  }
  final group = bopTrackGroup(session.trackVenue, session.trackCourse);
  final own = {
    for (final s in energySharesOf(path, session)) (s.carClass, s.model): s,
  };
  final byModel = <(BopClass, String), List<EnergyShareSample>>{};
  for (final s in others) {
    if (s.path == path) continue;
    if (s.fuelMultiplier case final m? when m != 1) continue;
    if (bopTrackGroup(s.trackVenue, s.trackCourse) != group) continue;
    if (s.startedAt.isBefore(document.publishedOn)) continue;
    if (documentEnds != null && !s.startedAt.isBefore(documentEnds)) continue;
    if (!document.gameVersions.contains(s.gameVersion)) continue;
    (byModel[(s.carClass, s.model)] ??= []).add(s);
  }
  final ratios = <double>[];
  final files = <String>{};
  for (final MapEntry(:key, value: mine) in own.entries) {
    final theirs = byModel[key];
    if (theirs == null || theirs.isEmpty) continue;
    final norm = quantile([for (final s in theirs) s.median]..sort(), 0.5);
    ratios.add(norm / mine.median);
    files.addAll(theirs.map((s) => s.path));
  }
  if (ratios.isEmpty) {
    return const BopAllowance(kind: BopAllowanceKind.unchecked);
  }
  final ratio = quantile(ratios..sort(), 0.5);
  return BopAllowance(
    kind: (ratio - 1).abs() <= bopAllowanceTolerance
        ? BopAllowanceKind.matches
        : BopAllowanceKind.differs,
    ratio: ratio,
    sessions: files.length,
    models: ratios.length,
  );
}
