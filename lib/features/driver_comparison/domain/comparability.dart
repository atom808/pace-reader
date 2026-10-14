/// Can these two laps be compared, and is the comparison fair? (comparison
/// proposal §4, "Comparability gates")
///
/// Pure functions over facts the files carry, so every gate is a unit test
/// rather than an integration one. The thresholds are the library's
/// (678 recordings, 17 layouts): each is set from the worst case measured
/// within one course, never from a single pair of laps.
library;

import '../../../core/formatting.dart';
import '../../../data/models/models.dart';
import '../../../data/reference/car_catalog.dart';
import '../../../data/reference/car_class.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../../data/repositories/lap_telemetry.dart';
import '../../../widgets/charting/charting.dart';
import '../../telemetry_trace/application/lap_chart.dart';
import 'lines.dart';

/// Whether two files were recorded on one course (§4's hard gate, D2).
enum CourseVerdict {
  /// One file: one course by construction.
  sameFile,

  /// Same track, same layout string, lengths within [CourseCheck.lengthTolerance].
  sameCourse,

  /// Same track and layout string, but a file recorded no `Lap Dist` wrap, so
  /// its length cannot be checked.
  lengthUnchecked,

  /// Different `TrackName`.
  differentTrack,

  /// Same track, a lap length more than [CourseCheck.lengthTolerance] apart:
  /// another course of the track, whatever its layout string says.
  differentLength,

  /// Same track and length, different layout string — Spa against Spa
  /// Endurance. Compared, and labelled, once the whole-lap centre line
  /// agrees (part 3); geometry decides, never the string (D2).
  layoutVariant,

  /// Same track and length, but the two laps' centre paths part by more
  /// than [CentreComparison.courseLimit] somewhere: another course that
  /// happens to measure the same, such as one with a swapped chicane.
  differentCentreLine,

  /// A layout variant whose centre line cannot be checked, because a lap
  /// lacks GPS or `Path Lateral`: refused rather than assumed.
  centreLineUnchecked,
}

/// The course gate's verdict on a pair of files.
class CourseCheck {
  const CourseCheck({
    required this.verdict,
    this.baseLength,
    this.targetLength,
    this.targetLayout,
    this.centre,
  });

  /// Runs parts 1 and 2 of the gate — `TrackName`, then the wrap length.
  /// Needs no lap: it runs before any lap of the Target is read. A different
  /// `TrackLayout` of the same length is a [CourseVerdict.layoutVariant],
  /// which part 3 ([withCentreLine]) decides once the laps are read.
  factory CourseCheck.of({
    required SessionMetadata base,
    required CourseFacts? baseCourse,
    required SessionMetadata target,
    required CourseFacts? targetCourse,
    required bool sameFile,
  }) {
    final b = baseCourse?.wrapLength;
    final t = targetCourse?.wrapLength;
    CourseCheck verdict(CourseVerdict v) => CourseCheck(
      verdict: v,
      baseLength: b,
      targetLength: t,
      targetLayout: target.trackLayout,
    );
    if (sameFile) return verdict(CourseVerdict.sameFile);
    if (base.trackName != target.trackName) {
      return verdict(CourseVerdict.differentTrack);
    }
    if (b != null && t != null && (b - t).abs() > lengthTolerance) {
      return verdict(CourseVerdict.differentLength);
    }
    if (base.trackLayout != target.trackLayout) {
      return verdict(CourseVerdict.layoutVariant);
    }
    if (b == null || t == null) return verdict(CourseVerdict.lengthUnchecked);
    return verdict(CourseVerdict.sameCourse);
  }

  /// The spread of one course's length across the library is 0.04 m; the
  /// closest two distinct courses are 22.3 m apart.
  static const lengthTolerance = 0.5;

  final CourseVerdict verdict;
  final double? baseLength;
  final double? targetLength;
  final String? targetLayout;

  /// Part 3's measurement: null for one file, and until both laps are read.
  final CentreComparison? centre;

  /// Part 3 (D2): the two laps' centre paths, compared every 5 m of the lap
  /// before any number is drawn. Skipped for one file, which has one centre
  /// path; a null [centre] means it could not run, which refuses a layout
  /// variant and leaves a same-layout pair to parts 1 and 2.
  CourseCheck withCentreLine(CentreComparison? centre) {
    if (verdict == CourseVerdict.sameFile || refuses) return this;
    final CourseVerdict next;
    if (centre == null) {
      next = verdict == CourseVerdict.layoutVariant
          ? CourseVerdict.centreLineUnchecked
          : verdict;
    } else {
      next = centre.sameCourse ? verdict : CourseVerdict.differentCentreLine;
    }
    return CourseCheck(
      verdict: next,
      baseLength: baseLength,
      targetLength: targetLength,
      targetLayout: targetLayout,
      centre: centre,
    );
  }

  /// Whether the pair is refused outright — before any lap read, because
  /// `Lap Dist` starts at zero on every course, and a School-against-full-
  /// course delta would look believable over the first 3083 m.
  bool get refuses => switch (verdict) {
    CourseVerdict.differentTrack ||
    CourseVerdict.differentLength ||
    CourseVerdict.differentCentreLine ||
    CourseVerdict.centreLineUnchecked => true,
    _ => false,
  };

  /// Why, for the user.
  String get reason => switch (verdict) {
    CourseVerdict.sameFile => 'same file: distance and line frame shared',
    CourseVerdict.sameCourse => 'same course: ${_m(baseLength)} in both files',
    CourseVerdict.lengthUnchecked =>
      'same layout, but a file recorded no full lap, so its length is '
          'unchecked',
    CourseVerdict.differentTrack => 'a different track',
    CourseVerdict.differentLength =>
      'a different course of this track: ${_m(targetLength)}, not '
          '${_m(baseLength)}',
    CourseVerdict.layoutVariant =>
      'a layout variant ($targetLayout) of the same length',
    CourseVerdict.differentCentreLine =>
      'a different course: the centre lines part by up to '
          '${centre!.max.toStringAsFixed(1)} m at '
          '${centre!.maxStation.toStringAsFixed(0)} m',
    CourseVerdict.centreLineUnchecked =>
      'a layout variant ($targetLayout) whose centre line cannot be checked: '
          'a lap recorded no GPS or Path Lateral',
  };

  static String _m(double? metres) =>
      metres == null ? 'length unknown' : '${metres.toStringAsFixed(2)} m';
}

/// Whether the two laps' lines can be compared, and on what (§4 "Centre
/// path" and "Track Edge", §6 "Line panel").
class LineCheck {
  const LineCheck({
    this.base,
    this.target,
    this.centre,
    this.trackEdge,
    this.withheld,
  });

  /// Measures [base] against [target]. Two laps of one file share one
  /// centre path, so the centre gate and the Track Edge comparison are
  /// skipped for them, as the alignment gate is.
  factory LineCheck.measure({
    required LapTelemetry base,
    required LapTelemetry target,
    required CourseFacts? baseCourse,
    required CourseFacts? targetCourse,
    required bool sameFile,
    required StationAlignment alignment,
  }) {
    final frame = LocalFrame.around(base);
    final (b, t) = frame == null
        ? (null, null)
        : LapLine.pair(
            base,
            target,
            frame: frame,
            basePitLane: baseCourse?.pitLane ?? [],
            targetPitLane: targetCourse?.pitLane ?? [],
          );
    final centre = sameFile || b == null || t == null
        ? null
        : CentreComparison.between(b, t);
    final edges = sameFile || b == null || t == null
        ? null
        : TrackEdgeAgreement.between(b, t);
    final String? withheld;
    if (alignment.withholdsDistance) {
      withheld =
          "the two files' sector lines sit "
          '${alignment.worstOffset!.abs().toStringAsFixed(1)} m apart, so '
          'nothing is compared at equal distance';
    } else if (b == null || t == null) {
      final who = b == null ? "Base's" : "the Target's";
      withheld = '$who lap recorded no GPS or Path Lateral';
    } else if (!sameFile && centre == null) {
      withheld = 'the two laps share no stretch of track';
    } else if (centre != null && !centre.linesComparable) {
      withheld =
          "the two laps' centre paths run ${centre.rms.toStringAsFixed(2)} m "
          'apart (rms), more than the '
          '${CentreComparison.lineLimit.toStringAsFixed(1)} m lines can be '
          'compared within';
    } else {
      withheld = null;
    }
    return LineCheck(
      base: b,
      target: t,
      centre: centre,
      trackEdge: edges,
      withheld: withheld,
    );
  }

  /// Each lap's line in one frame; null where a lap lacks the channels.
  final LapLine? base;
  final LapLine? target;

  /// The centre gate's measurement; null for one file.
  final CentreComparison? centre;

  /// Null for one file, or where either lap lacks `Track Edge`.
  final TrackEdgeAgreement? trackEdge;

  /// Why the Line panel and line findings are not shown; null when they are.
  final String? withheld;

  bool get shown => withheld == null && base != null && target != null;
}

/// How a chip reads (§8 "Chips are neutral").
enum ChipTone {
  /// A gate that ran and passed: ✓.
  passed,

  /// A fact worth knowing that changes nothing: ≠, or a flag.
  neutral,

  /// Something that may shift a number on screen.
  warning,

  /// A number on screen would be wrong. Only a failed delta check is this.
  error,
}

/// One chip of the comparability strip, and what its popover says.
class ComparabilityChip {
  const ComparabilityChip({
    required this.label,
    required this.tone,
    required this.detail,
    this.compounds,
  });

  final String label;
  final ChipTone tone;

  /// The numbers behind the chip, one line each.
  final List<String> detail;

  /// For "≠ compound": each lap's compounds, FL FR RL RR, which the strip
  /// draws as badges.
  final ({List<CompoundMark> base, List<CompoundMark> target})? compounds;
}

/// Everything the strip shows about a pair that the chart does not.
class PairFacts {
  const PairFacts({
    required this.base,
    required this.target,
    required this.baseLap,
    required this.targetLap,
    required this.baseCourse,
    required this.targetCourse,
    required this.baseClockGaps,
    required this.targetClockGaps,
  });

  final SessionMetadata base;
  final SessionMetadata target;
  final Lap baseLap;
  final Lap targetLap;
  final CourseFacts? baseCourse;
  final CourseFacts? targetCourse;

  /// Each file's recording discontinuities (§5.2).
  final List<ClockGap> baseClockGaps;
  final List<ClockGap> targetClockGaps;
}

/// The strip's chips for a pair, in reading order: the course, the
/// alignment, the delta check, then the flags and the neutral differences.
List<ComparabilityChip> comparabilityChips({
  required CourseCheck course,
  required LapComparison comparison,
  required PairFacts facts,
  LineCheck? line,
}) {
  final centre = course.centre;
  final chips = <ComparabilityChip>[
    ComparabilityChip(
      label: course.verdict == CourseVerdict.sameFile
          ? 'same file'
          : course.verdict == CourseVerdict.lengthUnchecked
          ? 'course length unchecked'
          : 'same course',
      tone: course.verdict == CourseVerdict.lengthUnchecked
          ? ChipTone.warning
          : ChipTone.passed,
      detail: [
        course.reason,
        if (course.baseLength != null && course.targetLength != null)
          'Lap length: Base ${course.baseLength!.toStringAsFixed(2)} m, '
              'Target ${course.targetLength!.toStringAsFixed(2)} m '
              '(the same course measures within 0.04 m in every recording)',
        if (course.verdict != CourseVerdict.sameFile)
          centre == null
              ? 'Centre line: unchecked, since a lap recorded no GPS or Path '
                    'Lateral'
              : 'Centre line: within ${centre.max.toStringAsFixed(2)} m of '
                    "Base's all the way round (another course parts by over "
                    '${CentreComparison.courseLimit.toStringAsFixed(0)} m)',
      ],
    ),
  ];

  final alignment = comparison.alignment;
  if (!alignment.sameFile) {
    final worst = alignment.worstOffset;
    chips.add(
      ComparabilityChip(
        label: worst == null
            ? 'distance unchecked'
            : alignment.aligned
            ? 'distance aligned ${worst.abs().toStringAsFixed(1)} m'
            : alignment.withholdsDistance
            ? 'distance offset ${worst.abs().toStringAsFixed(1)} m: '
                  'delta withheld'
            : 'distance offset ${worst.abs().toStringAsFixed(1)} m',
        tone: worst == null || !alignment.aligned
            ? ChipTone.warning
            : ChipTone.passed,
        detail: [
          "Sector lines in Target's file against Base's:",
          'S1 ${_signedMetres(alignment.sector1Offset)}, '
              'S2 ${_signedMetres(alignment.sector2Offset)}',
          'Base S1 ${_station(facts.baseCourse?.sector1Station)}, '
              'S2 ${_station(facts.baseCourse?.sector2Station)}; '
              'Target S1 ${_station(facts.targetCourse?.sector1Station)}, '
              'S2 ${_station(facts.targetCourse?.sector2Station)}',
          'Within ${StationAlignment.alignedWithin} m is one coordinate (the '
              'library never exceeds 2.1 m); past '
              '${StationAlignment.usableWithin} m nothing is compared at equal '
              'distance.',
        ],
      ),
    );
  }

  final lineCentre = line?.centre;
  if (lineCentre != null && !alignment.withholdsDistance) {
    chips.add(
      ComparabilityChip(
        label: lineCentre.linesComparable
            ? 'centre path ${lineCentre.rms.toStringAsFixed(2)} m'
            : 'line hidden: centre paths '
                  '${lineCentre.rms.toStringAsFixed(2)} m apart',
        tone: lineCentre.linesComparable ? ChipTone.passed : ChipTone.warning,
        detail: [
          "The course's centre path, rebuilt from each lap's GPS and Path "
              'Lateral, every 5 m: ${lineCentre.rms.toStringAsFixed(2)} m '
              'apart (rms), ${lineCentre.max.toStringAsFixed(2)} m at most.',
          'Within ${CentreComparison.lineLimit.toStringAsFixed(1)} m the '
              "two files' lines compare (the library's worst pair is "
              '0.26 m); past it the Line panel is hidden.',
        ],
      ),
    );
  }

  chips.add(_deltaCheckChip(comparison.check));

  for (final (role, lap, course) in [
    ('Base', facts.baseLap, facts.baseCourse),
    ('Target', facts.targetLap, facts.targetCourse),
  ]) {
    final end = lap.endSeconds;
    if (course != null &&
        end != null &&
        course.pitLaneDuring(lap.startSeconds, end)) {
      chips.add(
        ComparabilityChip(
          label: 'pit lane: $role',
          tone: ChipTone.warning,
          detail: [
            "$role's lap spent time in the pit lane. The stop lands in the "
                'first or last stretch of the lap, depending on which side of '
                'the timing line the box sits.',
          ],
        ),
      );
    }
  }
  for (final (role, lap, gaps) in [
    ('Base', facts.baseLap, facts.baseClockGaps),
    ('Target', facts.targetLap, facts.targetClockGaps),
  ]) {
    if (gaps.isEmpty) continue;
    final end = lap.endSeconds ?? double.infinity;
    final inLap = gaps.where((gap) {
      final at = gap.atSeconds;
      return at != null && at > lap.startSeconds && at <= end;
    }).length;
    chips.add(
      ComparabilityChip(
        label: inLap > 0 ? 'clock gap in $role\'s lap' : 'clock gaps: $role',
        tone: inLap > 0 ? ChipTone.warning : ChipTone.neutral,
        detail: [
          inLap > 0
              ? "The recording's clock jumps $inLap time${inLap == 1 ? '' : 's'} "
                    "inside $role's lap: time across the jump is missing."
              : "$role's file has ${gaps.length} clock "
                    'gap${gaps.length == 1 ? '' : 's'}, none inside this lap.',
        ],
      ),
    );
  }

  final edges = line?.trackEdge;
  if (course.verdict == CourseVerdict.layoutVariant) {
    chips.add(
      ComparabilityChip(
        label: 'layout variant: ${facts.target.trackLayout}',
        tone: ChipTone.neutral,
        detail: [
          'Base: ${facts.base.trackLayout}',
          'Target: ${facts.target.trackLayout}',
          if (centre != null)
            'Geometry identical: the same length, and centre lines within '
                '${centre.max.toStringAsFixed(2)} m all the way round.',
          if (edges != null)
            edges.agrees
                ? 'Track edges agree.'
                : 'Track edges differ at ${edges.differingText}.',
          "Segments are Base's layout's: a variant never supplies another's.",
        ],
      ),
    );
  }
  if (edges != null && !edges.agrees) {
    chips.add(
      ComparabilityChip(
        label: 'track edges differ (game update?)',
        tone: ChipTone.neutral,
        detail: [
          '${(edges.share * 100).toStringAsFixed(0)}% of ${edges.matched} '
              'matched samples find the same edge (within one recording, '
              '93–99%).',
          if (edges.differing.isNotEmpty)
            'They differ at ${edges.differingText}.',
          'The centre line and Path Lateral still compare, so the Line panel '
              'stays.',
        ],
      ),
    );
  }

  void differs(String what, String a, String b) {
    if (a == b) return;
    chips.add(
      ComparabilityChip(
        label: '≠ $what',
        tone: ChipTone.neutral,
        detail: ['Base: $a', 'Target: $b'],
      ),
    );
  }

  // By model: two entries of one car (Ferrari AF Corse #50 and AF Corse #83,
  // both 499Ps) are the same car in another livery. The class is its own
  // chip, so an LMP2 and an LMP2 ELMS Oreca differ there, not here.
  final baseCar = placeCar(facts.base.carName, facts.base.carClass);
  final targetCar = placeCar(facts.target.carName, facts.target.carClass);
  final otherCar = baseCar.isPlaced && targetCar.isPlaced
      ? baseCar.model != targetCar.model
      : facts.base.carName != facts.target.carName;
  if (otherCar) {
    String car(CarPlacement p) =>
        p.isPlaced ? '${p.title} (${p.entryLabel})' : p.entry.raw;
    chips.add(
      ComparabilityChip(
        label: '≠ car',
        tone: ChipTone.neutral,
        detail: ['Base: ${car(baseCar)}', 'Target: ${car(targetCar)}'],
      ),
    );
  }
  differs(
    'class',
    CarClass.parse(facts.base.carClass).label,
    CarClass.parse(facts.target.carClass).label,
  );
  differs(
    'session',
    facts.base.sessionType.rawValue,
    facts.target.sessionType.rawValue,
  );
  return chips;
}

ComparabilityChip _deltaCheckChip(DeltaCheck check) {
  String lap(LapAnchor anchor) => anchor.reanchored
      ? 're-anchored by ${_signedMs(anchor.offset)} on its splits; residuals '
            '${_residuals(anchor.residuals)}'
      : anchor.traceMinusGame.isEmpty
      ? 'kept its Lap event: no splits to check against'
      : 'kept its Lap event (not every split recorded); trace − game '
            '${_residuals(anchor.traceMinusGame)}';
  final detail = [
    'Base ${lap(check.base)}',
    'Target ${lap(check.target)}',
    if (check.pair.isNotEmpty)
      "Delta at the lines against the game's differences: "
          '${_residuals(check.pair)}',
    'Allowed: ${_ms(DeltaCheck.perLapLimit)} per lap, '
        '${_ms(check.pairBound)} per pair.',
  ];
  return switch (check.status) {
    DeltaCheckStatus.passed => ComparabilityChip(
      label: 'delta checked ${formatDelta(check.worstPair!)} s',
      tone: ChipTone.passed,
      detail: detail,
    ),
    DeltaCheckStatus.failed => ComparabilityChip(
      label: 'delta check failed',
      tone: ChipTone.error,
      detail: detail,
    ),
    DeltaCheckStatus.unchecked => ComparabilityChip(
      label: 'delta unchecked',
      tone: ChipTone.neutral,
      detail: detail,
    ),
  };
}

/// In milliseconds: at three decimals of a second a 0.4 ms residual reads
/// "-0.000", which says nothing.
String _residuals(Map<TimingLine, double> values) => [
  for (final MapEntry(:key, :value) in values.entries)
    '${key.label} ${_signedMs(value)}',
].join(', ');

String _signedMs(double seconds) =>
    '${seconds < 0 ? '-' : '+'}${_ms(seconds.abs())}';

String _ms(double seconds) => '${(seconds * 1000).toStringAsFixed(1)} ms';

String _signedMetres(double? metres) => metres == null
    ? '—'
    : '${metres >= 0 ? '+' : ''}${metres.toStringAsFixed(2)} m';

String _station(double? metres) =>
    metres == null ? '—' : '${metres.toStringAsFixed(1)} m';
