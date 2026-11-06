/// How the app words a session's balance of performance (PACE-FACTORS §5.6).
library;

import '../application/linked_results.dart';
import '../domain/bop.dart';
import '../domain/bop_allowance.dart';

String _n(double v) {
  if (v < 0) return '−${_n(-v)}';
  return v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

/// `1132 kg (+5)`: a figure, and its change from the previous document.
String bopFigure(BopValue v, String unit) {
  final change = v.change;
  final changed = change == null
      ? ''
      : ' (${change > 0 ? '+' : '−'}${_n(change.abs())})';
  return '${_n(v.value)}$unit$changed';
}

/// One car's BoP in a line, for a tooltip.
String bopSummary(BopEntry e, BopDocument document) {
  final unit = e.isPercentPower ? ' %' : ' kW';
  final power =
      e.powerStage1.value == e.powerStage2.value &&
          e.stage1EndKph == e.stage2StartKph
      ? '${bopFigure(e.powerStage1, unit)} power'
      : '${bopFigure(e.powerStage1, unit)} to ${_n(e.stage1EndKph)} km/h, '
            '${bopFigure(e.powerStage2, unit)} from ${_n(e.stage2StartKph)}';
  return [
    'BoP ${document.version}, ${e.group}: ${e.model}',
    '${bopFigure(e.minWeightKg, ' kg')} with driver',
    power,
    '${bopFigure(e.stintEnergyMJ, ' MJ')} a stint',
    if (e.carClass == BopClass.hypercar)
      e.deployFromKph == null
          ? 'no hybrid'
          : e.deployFromKph == 0
          ? 'deploys at any speed'
          : 'deploys from ${_n(e.deployFromKph!)} km/h',
    if (e.dockingSeconds case final s? when s > 0) '${_n(s)} s docking',
    if (e.rearWingMin case final min?)
      if (e.rearWingMax case final max?)
        'rear wing ${bopFigure(min, '°')} to ${bopFigure(max, '°')}',
    if (e.minRideHeightMm case final h?) 'ride height ${bopFigure(h, ' mm')}',
  ].join(' · ');
}

/// `6 Oct 2026`.
String bopDay(BopDocument d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String _sessions(int n) => n == 1 ? '1 other session' : '$n other sessions';

/// What the card says about the session's BoP and its energy allowance.
String bopStatus(SessionBop bop) {
  final document = bop.document;
  if (document == null || bop.group == null) {
    return '${bop.missing ?? 'No BoP covers this session.'} '
        'Energy stays a share.';
  }
  final head =
      'BoP ${document.version} (${bopDay(document)}) sets each model’s '
      'weight, power and stint energy at ${bop.group}.';
  if (bop.missing case final why?) return '$head $why Energy stays a share.';
  final a = bop.allowance;
  return switch (a.kind) {
    BopAllowanceKind.matches =>
      '$head This event’s energy shares match ${_sessions(a.sessions)} of '
          'yours here under it, so energy reads in megajoules: the share of '
          'the allowance a lap took, times the model’s stint energy.',
    BopAllowanceKind.differs =>
      '$head This event’s energy shares run '
          '${(1 / a.ratio!).toStringAsFixed(2)}× those of '
          '${_sessions(a.sessions)} of yours here under it: its allowance '
          'looks like about ${(a.ratio! * 100).round()} % of BoP’s, so '
          'energy stays a share.',
    BopAllowanceKind.unchecked =>
      '$head No other session of yours here under it has energy figures to '
          'check this event’s allowance against, so energy stays a share.',
    BopAllowanceKind.multiplied =>
      '$head This event multiplied fuel use, which multiplies the energy '
          'shares too, so energy stays a share.',
  };
}
