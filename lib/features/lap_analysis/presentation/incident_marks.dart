/// How a lap's incidents are shown, in one place for the table and the chart.
///
/// A glyph, a short label and a tooltip per incident kind. The table renders
/// them as labelled badges and the trend chart as bare glyphs under its
/// columns; both come from here so the two can never describe one lap
/// differently.
library;

import 'package:material_ui/material_ui.dart';

import '../../../data/models/models.dart';
import '../../session_results/domain/race_control.dart';
import '../application/lap_incidents.dart';

/// What kind of incident a mark stands for. Order is importance, most first —
/// it is the order glyphs are dropped in when a chart column is too narrow.
///
/// The first three come from the recording's event tables; [penalty],
/// [contact], [damage] and [trackLimits] from race control's calls in LMU's
/// results file, when one links (results proposal, R3).
enum IncidentKind {
  impact,
  wheelDetached,
  penalty,
  contact,
  damage,
  yellowFlag,
  trackLimits,
}

/// How each kind looks in a legend: one place, so the table, the chart and
/// its key can't drift apart.
({IconData icon, String text}) incidentKindKey(IncidentKind kind) =>
    switch (kind) {
      IncidentKind.impact => (icon: Icons.car_crash_outlined, text: 'impact'),
      IncidentKind.wheelDetached => (
        icon: Icons.tire_repair_outlined,
        text: 'wheel detached',
      ),
      IncidentKind.yellowFlag => (icon: Icons.flag_outlined, text: 'yellow flag'),
      IncidentKind.penalty => (icon: Icons.gavel, text: 'penalty'),
      IncidentKind.contact => (icon: Icons.crisis_alert, text: 'contact'),
      IncidentKind.damage => (icon: Icons.build_outlined, text: 'damage'),
      IncidentKind.trackLimits => (icon: Icons.fence, text: 'track limits'),
    };

/// The flag's own yellow, held here rather than borrowed.
///
/// Not the scheme's — a Material dark scheme has no yellow — and not a channel
/// colour: `AppColors.channelCharge` is state-of-charge's identity (§9.7.1) and
/// a flag that read as a battery would be worse than one that read as nothing.
/// Local to this feature because nothing else draws a flag.
const flagYellow = Color(0xFFFFD84D);

class IncidentMark {
  const IncidentMark({
    required this.kind,
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
  });

  final IncidentKind kind;
  final IconData icon;
  final Color color;

  /// Short, for a badge: `impact`, `impact ×2`, `yellow flag`, `wheel FL`.
  final String label;

  /// Full sentences.
  final String tooltip;
}

/// Seconds into a lap as the tooltip states them: `18.0 s`.
String _into(double seconds) => '${seconds.toStringAsFixed(1)} s';

String _joinNatural(List<String> parts) => switch (parts.length) {
  0 => '',
  1 => parts.first,
  2 => '${parts[0]} and ${parts[1]}',
  _ => '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}',
};

/// The marks for [lap], in importance order; empty for a quiet lap.
///
/// [raceControl] is race control's calls on this lap from LMU's results
/// file, when the recording links to one.
List<IncidentMark> incidentMarks(
  ColorScheme scheme,
  Lap lap,
  LapIncidents incidents, {
  List<RaceControlCall> raceControl = const [],
}) {
  return [
    if (incidents.hasImpact) _impact(scheme, lap, incidents),
    if (incidents.hasDetachedWheel) _wheels(scheme, incidents),
    if (incidents.underYellow) _yellow(incidents),
    ...raceControlMarks(scheme, lap, raceControl),
  ]..sort((a, b) => a.kind.index.compareTo(b.kind.index));
}

/// One mark per kind of call on [lap], its colour the most serious call's.
///
/// Neutral for a call that changed nothing (a "No Further Action", a light
/// contact), the secondary colour for a warning or a firm contact, the
/// error colour for what cost the lap or the race: an invalidation, a
/// penalty, a heavy contact, damage.
List<IncidentMark> raceControlMarks(
  ColorScheme scheme,
  Lap lap,
  List<RaceControlCall> calls,
) {
  if (calls.isEmpty) return const [];
  final into = lap.isOutLap ? 'into the recording' : 'into the lap';
  String line(RaceControlCall c) =>
      '${_into(c.elapsed - lap.startSeconds)} $into: ${c.sentence}';
  const source = 'From race control, in LMU\'s results file for this session.';

  IncidentMark mark(
    IncidentKind kind,
    List<RaceControlCall> of,
    String label,
  ) => IncidentMark(
    kind: kind,
    icon: incidentKindKey(kind).icon,
    color: raceControlColor(
      scheme,
      of.map((c) => c.severity).reduce((a, b) => a > b ? a : b),
    ),
    label: label,
    tooltip: [for (final c in of) line(c), source].join('\n'),
  );

  List<RaceControlCall> ofKind(RaceControlKind k) => [
    for (final c in calls)
      if (c.kind == k) c,
  ];
  String counted(String word, int n) => n == 1 ? word : '$word ×$n';

  final limits = ofKind(RaceControlKind.trackLimits);
  final contacts = ofKind(RaceControlKind.contact);
  final penalties = ofKind(RaceControlKind.penalty);
  final damage = ofKind(RaceControlKind.damage);
  return [
    if (penalties.isNotEmpty)
      mark(
        IncidentKind.penalty,
        penalties,
        counted('penalty', penalties.length),
      ),
    if (contacts.isNotEmpty)
      mark(
        IncidentKind.contact,
        contacts,
        counted('contact', contacts.length),
      ),
    if (damage.isNotEmpty) mark(IncidentKind.damage, damage, 'damage'),
    if (limits.isNotEmpty)
      mark(
        IncidentKind.trackLimits,
        limits,
        limits.any((c) => c.text.startsWith('Invalid'))
            ? 'lap invalidated'
            : counted('limits', limits.length),
      ),
  ];
}

/// A race-control call's colour by its [RaceControlCall.severity]: the error
/// colour for what cost the lap or the race, the secondary for a warning or
/// a firm contact, neutral for a note.
Color raceControlColor(ColorScheme scheme, int severity) => switch (severity) {
  >= 2 => scheme.error,
  1 => scheme.secondary,
  _ => scheme.onSurfaceVariant,
};

IncidentMark _impact(ColorScheme scheme, Lap lap, LapIncidents incidents) {
  final count = incidents.impactCount;
  // The out lap's clock starts with the recording, in the garage, so "into the
  // lap" would be a number nobody could find on the trace.
  final into = lap.isOutLap ? 'the recording' : 'the lap';
  final offsets = [
    for (final t in incidents.impactSeconds) _into(t - lap.startSeconds),
  ];
  final when = count <= 3
      ? 'at ${_joinNatural(offsets)} into $into'
      : 'from ${offsets.first} to ${offsets.last} into $into';
  return IncidentMark(
    kind: IncidentKind.impact,
    icon: Icons.car_crash_outlined,
    color: scheme.error,
    label: count == 1 ? 'impact' : 'impact ×$count',
    tooltip:
        '${count == 1 ? 'Impact' : '$count impacts'} registered $when.\n'
        'The game records that contact happened, not how hard, so a tap and '
        'a crash look alike.',
  );
}

IncidentMark _wheels(ColorScheme scheme, LapIncidents incidents) {
  List<WheelCorner> sorted(Iterable<WheelCorner> corners) =>
      corners.toList()..sort((a, b) => a.index.compareTo(b.index));
  String names(Iterable<WheelCorner> corners) =>
      _joinNatural([for (final c in sorted(corners)) c.description]);

  final already = incidents.alreadyDetached;
  final fresh = incidents.detachedWheels.difference(already);
  return IncidentMark(
    kind: IncidentKind.wheelDetached,
    icon: Icons.tire_repair_outlined,
    color: scheme.error,
    label:
        'wheel ${sorted(incidents.detachedWheels).map((c) => c.abbreviation).join(' ')}',
    tooltip: [
      if (fresh.isNotEmpty) '${names(fresh)} wheel detached during this lap.',
      if (already.isNotEmpty)
        '${names(already)} wheel was already detached when the lap began.',
    ].join('\n'),
  );
}

IncidentMark _yellow(LapIncidents incidents) {
  final codes = incidents.yellowFlagCodes.toList()..sort();
  return IncidentMark(
    kind: IncidentKind.yellowFlag,
    icon: Icons.flag_outlined,
    color: flagYellow,
    label: 'yellow flag',
    // The code is quoted, not interpreted: 0 is the only value any recording
    // on hand has held, so what the others mean is the game's to say.
    tooltip:
        'Yellow Flag State was not clear during this lap '
        '(code ${codes.join(', ')}).',
  );
}
