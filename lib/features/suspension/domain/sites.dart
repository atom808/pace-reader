/// Sites: the places a car keeps touching down, and what goes with how deep
/// it goes there (suspension proposal §1, §5).
library;

import 'dart:math' as math;

import '../../../data/models/models.dart';
import 'strikes.dart';
import 'suspension_thresholds.dart';

/// A place on the lap with strikes from two or more laps.
class Site {
  const Site({
    required this.key,
    required this.place,
    required this.corner,
    required this.strikes,
    required this.lapLows,
  });

  /// Stable within a session: its order along the lap.
  final int key;

  /// The median of its laps' lowest points, m of `Lap Dist`.
  final double place;

  /// The corner that went lowest most often.
  final Corner corner;

  /// Every strike in it, Close ones included, off-track ones never.
  final List<Strike> strikes;

  /// Each lap's deepest strike here.
  final Map<int, Strike> lapLows;

  double get start => place - siteWindowMetres;
  double get end => place + siteWindowMetres;
  bool get isFront => corner.isFront;

  /// Laps with a Strike-tier touchdown here.
  Set<int> get struckLaps => {
    for (final s in strikes)
      if (s.tier == StrikeTier.strike) s.lap,
  };

  /// Laps that came within the Close band but never under the floor.
  Set<int> get closeLaps => lapLows.keys.toSet().difference(struckLaps);

  /// A Close site never went under the floor on two laps: drawn fainter,
  /// kept out of the counts.
  StrikeTier get tier =>
      struckLaps.length >= siteMinLaps ? StrikeTier.strike : StrikeTier.close;

  /// The median of each lap's deepest, m.
  double get medianDepth => _median([for (final s in lapLows.values) s.depth]);

  double get deepest => lapLows.values.map((s) => s.depth).reduce(math.min);

  /// How many of its laps' lowest points fell in each phase.
  Map<StrikePhase, int> get phases {
    final out = <StrikePhase, int>{};
    for (final s in lapLows.values) {
      out[s.phase] = (out[s.phase] ?? 0) + 1;
    }
    return out;
  }

  /// The phase most of its laps touched down in.
  StrikePhase get phase =>
      (phases.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  /// Most of its laps touched down on a kerb (§5): the verdict is then about
  /// the kerb, not the setup.
  bool get isKerb {
    final kerb = lapLows.values
        .where((s) => s.surface == StrikeSurface.kerb)
        .length;
    return kerb * 2 > lapLows.length;
  }

  double get medianSpeed => _median([for (final s in lapLows.values) ?s.speed]);
}

double _median(List<double> values) {
  if (values.isEmpty) return double.nan;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// Groups [strikes] into sites (§5): along the lap, a strike within
/// [siteJoinMetres] of the previous one joins its group, and a group with
/// strikes from at least [siteMinLaps] laps is a site. Off-track strikes are
/// listed elsewhere and never form a site.
///
/// Sites are returned in lap order, keyed 0, 1, … in that order.
List<Site> clusterSites(List<Strike> strikes) {
  final placed = [
    for (final s in strikes)
      if (s.station != null && s.surface != StrikeSurface.offTrack) s,
  ]..sort((a, b) => a.station!.compareTo(b.station!));
  final groups = <List<Strike>>[];
  for (final s in placed) {
    final last = groups.lastOrNull;
    if (last != null && s.station! - last.last.station! <= siteJoinMetres) {
      last.add(s);
    } else {
      groups.add([s]);
    }
  }
  final sites = <Site>[];
  for (final group in groups) {
    final lows = <int, Strike>{};
    for (final s in group) {
      final held = lows[s.lap];
      if (held == null || s.depth < held.depth) lows[s.lap] = s;
    }
    if (lows.length < siteMinLaps) continue;
    final corners = <Corner, int>{};
    for (final s in lows.values) {
      corners[s.corner] = (corners[s.corner] ?? 0) + 1;
    }
    final corner =
        (corners.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    sites.add(
      Site(
        key: sites.length,
        place: _median([for (final s in lows.values) s.station!]),
        corner: corner,
        strikes: group,
        lapLows: lows,
      ),
    );
  }
  return sites;
}

/// Sites in the order the list shows them (§4.3): most laps struck, then
/// deepest; Close sites after every Strike site.
List<Site> rankSites(List<Site> sites) => [...sites]
  ..sort((a, b) {
    final tier = a.tier.index.compareTo(b.tier.index);
    if (tier != 0) return tier;
    final laps = b.struckLaps.length.compareTo(a.struckLaps.length);
    if (laps != 0) return laps;
    final close = b.lapLows.length.compareTo(a.lapLows.length);
    if (close != 0) return close;
    return a.medianDepth.compareTo(b.medianDepth);
  });

/// One racing lap's lowest point at a site, struck or not: how clean laps
/// are compared with struck ones.
class SiteLapLow {
  const SiteLapLow({
    required this.lap,
    required this.depth,
    this.station,
    this.line,
    this.speed,
    this.maxBrake,
  });

  final int lap;

  /// The site corner's lowest within ±[siteSearchMetres], m.
  final double depth;
  final double? station;
  final double? line;
  final double? speed;
  final double? maxBrake;
}

/// What the verdict says (§5).
enum VerdictKind {
  line('Line', 'Your line decides it here'),
  speed('Speed', 'Faster laps ride lower here'),
  both('Both', 'Line and speed both go with it'),
  everyLap('Every lap', 'It touches down whatever you do'),
  kerb('Kerb', 'It touches down on the kerb'),
  notClear('Not clear', 'Nothing measured goes with it'),
  tooFewLaps('Too few laps', 'Too few laps to say');

  const VerdictKind(this.word, this.headline);

  /// The word in the sites list.
  final String word;
  final String headline;

  /// Whether the fix is in the car rather than the driving.
  bool get pointsAtSetup => this == speed || this == everyLap;
}

/// A site's fit over its laps.
class SiteVerdict {
  const SiteVerdict({
    required this.kind,
    required this.laps,
    required this.struckShare,
    this.lineR,
    this.speedR,
    this.lineSlope,
    this.speedSlope,
    this.cleanest,
    this.lows = const [],
  });

  final VerdictKind kind;

  /// Laps with a lowest point at the site.
  final int laps;

  /// The share of racing laps struck here.
  final double struckShare;

  /// r of depth on line and on speed.
  final double? lineR;
  final double? speedR;

  /// mm of ride height per metre of line (+ right), and per 10 km/h.
  final double? lineSlope;
  final double? speedSlope;

  /// The lap to copy: the highest at the site among laps at its speed.
  final int? cleanest;

  /// Every lap's lowest point, for the evidence scatter.
  final List<SiteLapLow> lows;
}

/// Pearson's r and the least-squares slope of y on x; null under 3 points
/// or with no spread.
({double r, double slope})? fit(List<double> x, List<double> y) {
  final n = x.length;
  if (n < 3 || y.length != n) return null;
  var mx = 0.0;
  var my = 0.0;
  for (var i = 0; i < n; i++) {
    mx += x[i];
    my += y[i];
  }
  mx /= n;
  my /= n;
  var sxx = 0.0;
  var syy = 0.0;
  var sxy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = x[i] - mx;
    final dy = y[i] - my;
    sxx += dx * dx;
    syy += dy * dy;
    sxy += dx * dy;
  }
  if (sxx <= 0 || syy <= 0) return null;
  return (r: sxy / math.sqrt(sxx * syy), slope: sxy / sxx);
}

/// The verdict for [site] from every racing lap's lowest point there
/// ([lows]) out of [racingLaps] (§5).
///
/// It says what goes with depth across your laps, never what causes it:
/// speed and line are often correlated (a wider line is faster), which is
/// why Both exists and why the evidence shows both scatters.
SiteVerdict verdictFor(
  Site site,
  List<SiteLapLow> lows, {
  required int racingLaps,
}) {
  final struckShare = racingLaps == 0
      ? 0.0
      : site.struckLaps.length / racingLaps;
  final cleanest = cleanestLap(lows);
  if (site.isKerb) {
    return SiteVerdict(
      kind: VerdictKind.kerb,
      laps: lows.length,
      struckShare: struckShare,
      cleanest: cleanest,
      lows: lows,
    );
  }
  final withLine = [
    for (final l in lows)
      if (l.line != null) l,
  ];
  final withSpeed = [
    for (final l in lows)
      if (l.speed != null) l,
  ];
  final lineFit = fit(
    [for (final l in withLine) l.line!],
    [for (final l in withLine) l.depth * 1000],
  );
  final speedFit = fit(
    [for (final l in withSpeed) l.speed! / 10],
    [for (final l in withSpeed) l.depth * 1000],
  );
  final enough = lows.length >= verdictMinLaps;
  final lr = lineFit?.r.abs() ?? 0;
  final sr = speedFit?.r.abs() ?? 0;
  final kind = !enough
      ? VerdictKind.tooFewLaps
      : lr >= verdictMinR && sr >= verdictMinR
      ? VerdictKind.both
      : lr >= verdictMinR
      ? VerdictKind.line
      : sr >= verdictMinR
      ? VerdictKind.speed
      : struckShare >= everyLapShare
      ? VerdictKind.everyLap
      : VerdictKind.notClear;
  return SiteVerdict(
    kind: kind,
    laps: lows.length,
    struckShare: struckShare,
    lineR: lineFit?.r,
    speedR: speedFit?.r,
    lineSlope: lineFit?.slope,
    speedSlope: speedFit?.slope,
    cleanest: cleanest,
    lows: lows,
  );
}

/// The cleanest comparable lap (§5): the highest lowest-point among laps
/// within [comparableSpeedShare] of the median speed there, or within
/// [comparableSpeedShareWide] when fewer than two laps are that close. Null
/// without speeds.
int? cleanestLap(List<SiteLapLow> lows) {
  final speeds = [for (final l in lows) ?l.speed];
  if (speeds.isEmpty) return null;
  final median = _median(speeds);
  List<SiteLapLow> within(double share) => [
    for (final l in lows)
      if (l.speed != null && (l.speed! - median).abs() <= median * share) l,
  ];
  var pool = within(comparableSpeedShare);
  if (pool.length < 2) pool = within(comparableSpeedShareWide);
  if (pool.isEmpty) return null;
  return pool.reduce((a, b) => b.depth > a.depth ? b : a).lap;
}
