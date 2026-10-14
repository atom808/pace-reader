/// What each measure is, in plain words, for the info popovers (SPEC.md
/// §8.13.3, §8.13.4, §8.13.7: "the exact definition and how it was checked").
library;

import '../domain/lap_technique.dart';
import '../domain/pedal_spans.dart';

/// The popover's paragraphs for [measure].
List<String> measureDefinition(TechniqueMeasure measure) => switch (measure) {
  TechniqueMeasure.fullThrottle => [
    'The share of the lap with the accelerator pedal at 98 % or more.',
    'Read from the pedal itself, not from the throttle reaching the engine: '
        'traction control and the upshift cut trim that one while the pedal '
        'stays down. 98 rather than 100, because late in long races the pedal '
        'stops reaching 100.',
  ],
  TechniqueMeasure.braking => [
    'The share of the lap with the brake pedal above 2 %.',
    'Checked against the car: with the throttle off above 100 km/h, the '
        'pedal follows the deceleration at r 0.92–0.99.',
  ],
  TechniqueMeasure.gripUsed => [
    'How hard the car was loaded when it was loaded: the lap\'s average '
        'combined G over its samples above 0.5 G, as a share of this '
        'session\'s limit (its 99th percentile of combined G).',
    'The limit is this session\'s own, so read it lap against lap here, never '
        'against another session, car or track.',
  ],
  TechniqueMeasure.trail => [
    'The share of braking time with the wheel turned by 5 % or more.',
    'On 95–100 % of those moments the wheel points into the corner, so this '
        'is turning in on the brakes, not catching a slide.',
  ],
  TechniqueMeasure.overlap => [
    'The share of the lap with both pedals above 2 % at once.',
    'Each overlap is classed by what the pedals did either side: the '
        'throttle-to-brake handover into a corner, the brake still on as the '
        'throttle picks up, or a dab of brake on the throttle.',
  ],
  TechniqueMeasure.coasting => [
    'The share of the lap with neither pedal touched at all.',
    'A lift before braking — throttle, then nothing, then brake — is the '
        'lift-and-coast shape fuel and energy saving leave. Races coast more '
        'than practice or qualifying in every pair measured.',
  ],
  TechniqueMeasure.tc => [
    'Seconds with traction control cutting power, from the TC flag.',
    'Checked: the throttle reaching the engine sits below the pedal on '
        '97–99.7 % of those moments, by 19–30 points.',
  ],
  TechniqueMeasure.abs => [
    'Seconds with ABS releasing the brakes, from the ABS flag. Shown only '
        'for cars whose setup has ABS.',
    'Checked: with the brake above 20 %, a wheel\'s brake force drops below '
        'its normal share on every ABS moment.',
  ],
  TechniqueMeasure.sustainedPeak => [
    'The most combined G the car held for 0.3 s on the lap.',
    'A single-sample peak would be a kerb or an impact — up to 21 G in this '
        'library — where this is the grip.',
  ],
};

/// What the popover says about pace.
String paceNote(TechniqueMeasure measure) => switch (measure) {
  TechniqueMeasure.fullThrottle =>
    'Goes with pace: laps with more full throttle were faster in 12 of 12 '
        'races measured.',
  TechniqueMeasure.braking =>
    'Goes with pace: laps with more braking were slower in 12 of 12 races '
        'measured.',
  TechniqueMeasure.gripUsed =>
    'Goes with pace: faster laps used more of the limit in 16 of 16 sessions '
        'measured.',
  _ =>
    'This describes how the lap was driven, not how fast it was: across 12 '
        'races it did not consistently go with lap time.',
};

/// "In this session: laps with more of it were faster (ρ −0.62, 16 laps)."
String? sessionCorrelation(double? rho, int laps) {
  if (rho == null) return null;
  final direction = rho.abs() < 0.2
      ? 'little relation to lap time'
      : rho < 0
      ? 'laps with more of it were faster'
      : 'laps with more of it were slower';
  return 'In this session: $direction '
      '(Spearman ${rho >= 0 ? '+' : '−'}${rho.abs().toStringAsFixed(2)}, '
      '$laps laps).';
}

/// "72 % handover in · 20 % out · 8 % dabs" for one lap's overlap.
String? overlapBreakdown(SpanBreakdown spans) {
  final total = spans.overlapSamples;
  if (total == 0) return null;
  String part(OverlapKind kind, String name) {
    final n = spans.overlap[kind] ?? 0;
    return '${(100 * n / total).round()} % $name';
  }

  return [
    part(OverlapKind.entry, 'handover in'),
    part(OverlapKind.exit, 'handover out'),
    part(OverlapKind.dab, 'dabs'),
    if ((spans.overlap[OverlapKind.other] ?? 0) > 0)
      part(OverlapKind.other, 'other'),
  ].join(' · ');
}

/// "40 % lift before braking · 34 % mid-corner" for one lap's coasting.
String? coastBreakdown(SpanBreakdown spans) {
  final total = spans.coastSamples;
  if (total == 0) return null;
  String part(CoastKind kind, String name) {
    final n = spans.coast[kind] ?? 0;
    return '${(100 * n / total).round()} % $name';
  }

  return [
    part(CoastKind.liftAndCoast, 'lift before braking'),
    part(CoastKind.midCorner, 'between brake and throttle'),
    if ((spans.coast[CoastKind.other] ?? 0) > 0) part(CoastKind.other, 'other'),
  ].join(' · ');
}
