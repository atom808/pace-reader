/// Suspension's words (suspension proposal §6.1): every finding the screen
/// relies on, said where the reader is looking, in short sentences that say
/// "goes with", never "causes", and end with where the number came from.
library;

import '../../../data/models/models.dart';
import '../domain/sites.dart';
import '../domain/strikes.dart';
import '../domain/suspension_thresholds.dart';

String mm(double metres, {int digits = 1}) =>
    (metres * 1000).toStringAsFixed(digits);

String metres(double m) {
  final whole = m.round();
  if (whole.abs() < 1000) return '$whole m';
  final s = whole.toString();
  return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)} m';
}

String percent(double share) => '${(share * 100).round()} %';

/// "This session: 36 racing laps."
String sessionSource(int laps) =>
    'Measured on this session\'s $laps racing lap${laps == 1 ? '' : 's'}.';

String axleWord(Corner corner) => corner.isFront ? 'front' : 'rear';

/// The verdict's sentence and its suggestion (§4.4), phrased as what goes
/// with depth across the laps.
({String sentence, String suggestion}) verdictSentence(
  Site site,
  SiteVerdict v, {
  required int racingLaps,
}) {
  final axle = axleWord(site.corner);
  final lineSlope = v.lineSlope;
  final speedSlope = v.speedSlope;
  String lineClause() {
    if (lineSlope == null) return '';
    final side = lineSlope > 0 ? 'right' : 'left';
    return 'Laps 1 m further $side stayed '
        '${lineSlope.abs().toStringAsFixed(1)} mm higher';
  }

  String speedClause() {
    if (speedSlope == null) return '';
    return speedSlope < 0
        ? 'Every 10 km/h more here took '
              '${speedSlope.abs().toStringAsFixed(1)} mm off the $axle'
        : 'Faster laps rode ${speedSlope.toStringAsFixed(1)} mm higher per '
              '10 km/h';
  }

  final struck = '${site.struckLaps.length} of $racingLaps laps';
  return switch (v.kind) {
    VerdictKind.line => (
      sentence: 'Goes with your line, not speed. ${lineClause()}.',
      suggestion:
          'Try the ${lineSlope != null && lineSlope > 0 ? 'right' : 'left'} '
          'side of the bump next time and see whether the site goes away.',
    ),
    VerdictKind.speed => (
      sentence: 'Goes with speed, not line. ${speedClause()}.',
      suggestion:
          'A line change is unlikely to fix it: look at the $axle ride '
          'height, packers or $axle springs.',
    ),
    VerdictKind.both => (
      sentence:
          'Goes with both line and speed. ${lineClause()}; '
          '${speedClause().toLowerCase()}.',
      suggestion:
          'Line and speed move together here (a wider line is often faster), '
          'so try the line first: it costs nothing to test.',
    ),
    VerdictKind.everyLap => (
      sentence:
          'Touches down on $struck whatever the line or speed: neither goes '
          'with how deep.',
      suggestion:
          'It is the car, not the lap: raise the $axle ride height or stiffen '
          'the $axle platform here.',
    ),
    VerdictKind.kerb => (
      sentence:
          'Most laps touched down riding the kerb, so this is the kerb, not '
          'a bump in the road.',
      suggestion: 'Take less of the kerb, or soften the $axle fast bump.',
    ),
    VerdictKind.notClear => (
      sentence:
          'Neither line nor speed goes with how deep it went '
          '(|r| under $verdictMinR for both).',
      suggestion:
          'Compare the struck laps\' inputs in the traces below: brake and '
          'steering can matter where line and speed do not.',
    ),
    VerdictKind.tooFewLaps => (
      sentence:
          'Only ${v.laps} lap${v.laps == 1 ? '' : 's'} reached here at '
          'speed; the verdict needs $verdictMinLaps.',
      suggestion: 'Drive more laps and come back.',
    ),
  };
}

/// What each verdict word means, for its tooltip.
String verdictMeaning(VerdictKind kind) => switch (kind) {
  VerdictKind.line =>
    'Line: how low the car went here goes with where on the road it was '
        '(|r| ≥ $verdictMinR), more than with speed.',
  VerdictKind.speed =>
    'Speed: how low the car went here goes with how fast it was going '
        '(|r| ≥ $verdictMinR), more than with the line. Setup territory.',
  VerdictKind.both =>
    'Both line and speed go with it (|r| ≥ $verdictMinR each). They are '
        'often linked: a wider line is faster.',
  VerdictKind.everyLap =>
    'Struck on at least ${(everyLapShare * 100).round()} % of laps with '
        'neither line nor speed going with depth: the car, not the lap.',
  VerdictKind.kerb =>
    'Most strikes here were on a kerb (surface code 5 or 6). Kerbs are where '
        'the fast damping works.',
  VerdictKind.notClear =>
    'Neither line nor speed reaches |r| $verdictMinR, and it is not struck '
        'nearly every lap.',
  VerdictKind.tooFewLaps =>
    'The fit needs $verdictMinLaps laps with a lowest point here.',
};

/// The surface tag's tooltip (§6.1).
String surfaceMeaning(
  StrikeSurface surface,
  StrikePhase phase,
) => switch (surface) {
  StrikeSurface.kerb =>
    'On a kerb (surface code 5 or 6)${phase == StrikePhase.straight ? ', so it is not the car bottoming on a straight' : ''}. '
        'Kerbs are where the fast damping works: 550–900 mm/s, against '
        'under 50 mm/s on a straight.',
  StrikeSurface.offTrack =>
    'Off track (grass or gravel, codes 2 or 4). Listed, but kept out of '
        'sites and verdicts: ride height means little in a gravel trap.',
  StrikeSurface.track => 'On the racing surface (code 0).',
};

const surfaceSource =
    'Surface codes decoded from your filmed Le Mans test lap, 4 Nov 2026, and '
    'checked on one file per track of 468.';

const tierMeaning =
    'Strike: a corner\'s ride height under ${strikeFloorMetres * 1000} mm. '
    'Close: within ${closeBandMetres * 1000} mm above that, drawn fainter and '
    'left out of the counts. Negative readings on track count: the BMW at '
    'Sebring read −6.6 to −10.5 mm on asphalt at one bump on three laps.';

const floorNote =
    'The floor is provisional: set where the measured strikes cluster, and '
    'to be checked against vertical-G jolts across your library.';
