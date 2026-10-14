/// What each lap started with and ran in, and the strip's chips for it
/// (comparison proposal §7 "Lap-start chips", "Setup").
///
/// Neutral values, never a verdict: between same-layout, same-class
/// recordings the fuel at best-lap start differs by a median 24.8 L, the
/// compound index differs in 42% and track temperature by 5 °C or more in
/// 56%, so these show on most cross-file pairs. Only a difference past its
/// measured threshold gets a "≠" chip of its own; every value is in the
/// "conditions" chip's popover.
library;

import '../../../data/models/models.dart';
import '../../../data/reference/tyre_compound.dart';
import '../../setup_viewer/application/car_setup.dart';
import 'comparability.dart';

/// Fuel is highlighted from this difference (L): about 0.2 s at the
/// library's +0.08 s per 10 L.
const fuelHighlight = 25.0;

/// Track temperature is highlighted from this difference (°C), above the
/// 4.6 °C p90 drift within one race. It is not shown to change pace in this
/// library (r ≈ 0 over 136 sessions).
const trackTemperatureHighlight = 5.0;

/// One lap's conditions.
class LapConditions {
  const LapConditions({
    this.fuel,
    this.energy,
    this.wear = const {},
    this.wetness,
    this.compound,
    this.compoundKey = CompoundKey.none,
    this.trackTemperature,
    this.ambientTemperature,
    this.settings = const {},
    this.settingsChanged = const {},
  });

  /// Litres at the lap's first sample (`FuelEnergyReport`'s definition).
  final double? fuel;

  /// `Virtual Energy` at the lap's first sample. See [energyValid].
  final double? energy;

  /// Tyre life left per corner at the lap's first sample (%).
  final Map<Corner, double> wear;

  /// `Minimum Path Wetness` in force over the lap, lowest and highest (%).
  /// `WeatherConditions` is never read for it: it is wrong both ways.
  final ({double min, double max})? wetness;

  /// The `TyresCompound` index per corner at the lap's start, FL FR RL RR:
  /// a place in the session's list of compounds, which [compoundKey] names
  /// where the file can.
  final List<int>? compound;

  /// What this file's compound indices name (SPEC §15.20).
  final CompoundKey compoundKey;

  /// [compound] as badges show it, FL FR RL RR.
  List<CompoundMark>? get compoundMarks =>
      compound?.map(compoundKey.mark).toList();

  /// Lap means (°C): essentially constant within a lap (track p99 1.0 °C).
  final double? trackTemperature;
  final double? ambientTemperature;

  /// The driver-adjustable settings the file records as events, by event
  /// name ([settingEventNames]), at the lap's start: Driving Technique's
  /// conditions lens reads these (SPEC.md §8.13.6). The level in force is
  /// read per lap, never from the setup: TC changes mid-session in 5 GT3 and
  /// 24 Hypercar files.
  final Map<String, double> settings;

  /// The settings that changed during the lap.
  final Set<String> settingsChanged;

  /// Virtual energy is a share only in 0 < VE ≤ 100: it is 0 in every LMP2
  /// and LMP3 file, and about 9.05e10 in the Hypercar files of 15 February
  /// to 14 March 2026.
  bool get energyValid => energy != null && energy! > 0 && energy! <= 100;
}

/// The setting events [LapConditions.settings] reads, in the order the
/// conditions lens lists them.
const settingEventNames = [
  'TCLevel',
  'TCCut',
  'TCSlipAngle',
  'ABSLevel',
  'Brake Bias Rear',
  'Brake Migration',
  'FuelMixtureMap',
];

/// A session's per-lap reads, cut into [LapConditions] lap by lap.
class SessionConditions {
  const SessionConditions({
    this.fuel = const {},
    this.energy = const {},
    this.wear = const {},
    this.wetness,
    this.compound,
    this.compoundKey = CompoundKey.none,
    this.trackTemperature = const {},
    this.ambientTemperature = const {},
    this.settings = const {},
  });

  /// Per-lap statistics keyed by `Lap.index`.
  final Map<int, LapChannelStats> fuel;
  final Map<int, LapChannelStats> energy;
  final Map<Corner, Map<int, LapChannelStats>> wear;
  final Map<int, LapChannelStats> trackTemperature;
  final Map<int, LapChannelStats> ambientTemperature;

  /// The event series over the whole session, including the value in force
  /// when it began.
  final StepSeries? wetness;

  /// One series per corner, FL FR RL RR.
  final List<StepSeries>? compound;

  /// What [compound]'s indices name: the setup read against each series'
  /// first row.
  final CompoundKey compoundKey;

  /// Each of [settingEventNames] the file carries, over the whole session.
  final Map<String, StepSeries> settings;

  LapConditions of(Lap lap) {
    final start = lap.startSeconds;
    final end = lap.endSeconds ?? double.infinity;
    ({double min, double max})? wet;
    final w = wetness;
    if (w != null) {
      final atStart = w.valueAt(start);
      var lo = atStart ?? double.infinity;
      var hi = atStart ?? double.negativeInfinity;
      for (var i = 0; i < w.length; i++) {
        if (w.times[i] <= start || w.times[i] >= end) continue;
        lo = lo < w.values[i] ? lo : w.values[i];
        hi = hi > w.values[i] ? hi : w.values[i];
      }
      if (lo.isFinite && hi.isFinite) wet = (min: lo, max: hi);
    }
    final compounds = compound?.map((s) => s.valueAt(start)?.round()).toList();
    final atStart = <String, double>{};
    final changed = <String>{};
    for (final MapEntry(key: name, value: series) in settings.entries) {
      final v = series.valueAt(start);
      if (v == null) continue;
      atStart[name] = v;
      for (var i = 0; i < series.length; i++) {
        final t = series.times[i];
        if (t > start && t < end && series.values[i] != v) {
          changed.add(name);
          break;
        }
      }
    }
    return LapConditions(
      fuel: fuel[lap.index]?.first,
      energy: energy[lap.index]?.first,
      wear: {
        for (final MapEntry(key: corner, value: laps) in wear.entries)
          if (laps[lap.index] case final stats?) corner: stats.first,
      },
      wetness: wet,
      compoundKey: compoundKey,
      compound: compounds == null || compounds.any((c) => c == null)
          ? null
          : [for (final c in compounds) c!],
      trackTemperature: trackTemperature[lap.index]?.mean,
      ambientTemperature: ambientTemperature[lap.index]?.mean,
      settings: atStart,
      settingsChanged: changed,
    );
  }
}

String _number(double? value, int decimals, String unit) =>
    value == null ? '—' : '${value.toStringAsFixed(decimals)} $unit';

String _wet(({double min, double max})? w) => w == null
    ? '—'
    : w.max == 0
    ? 'dry'
    : w.min == w.max
    ? '${_trim(w.max)}%'
    : '${_trim(w.min)}–${_trim(w.max)}%';

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

/// "Medium", "F Soft, R Medium"; an index the file cannot name is its bare
/// number, as the strip has always shown it: "≠ compound 0 / 1".
String _compound(List<CompoundMark>? marks) => marks == null
    ? '—'
    : [
        for (final (axle, mark) in axleGroups(marks))
          [?axle, mark.isNamed ? mark.label : '${mark.index}'].join(' '),
      ].join(', ');

/// Whether every corner's compound has a name.
bool _named(List<CompoundMark>? marks) =>
    marks != null && marks.every((m) => m.kind != null);

bool _sameKinds(List<CompoundMark> a, List<CompoundMark> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i].kind == b[i].kind].every((s) => s);

String _wear(Map<Corner, double> wear) => wear.isEmpty
    ? '—'
    : [
        for (final corner in Corner.values)
          if (wear[corner] case final left?)
            '${corner.short} ${left.toStringAsFixed(1)}',
      ].join(', ');

/// The strip's chips for the two laps' conditions: one neutral
/// "conditions" chip holding every value, and a "≠" chip for each
/// difference past its threshold.
///
/// Compounds compare by name wherever the files name them, across cars too:
/// a Soft is a Soft. An index the file cannot name is compared only for one
/// car, since it is a place in a session's list.
List<ComparabilityChip> conditionChips({
  required LapConditions base,
  required LapConditions target,
  required bool sameCar,
}) {
  final chips = <ComparabilityChip>[];
  if (base.fuel case final b?) {
    if (target.fuel case final t? when (b - t).abs() >= fuelHighlight) {
      chips.add(
        ComparabilityChip(
          label: '≠ fuel ${b.toStringAsFixed(1)} / ${t.toStringAsFixed(1)} L',
          tone: ChipTone.neutral,
          detail: [
            "Fuel at each lap's start: Base ${b.toStringAsFixed(1)} L, "
                'Target ${t.toStringAsFixed(1)} L.',
            'Across this library, laps after a refuel ran a median 0.08 s '
                'slower per 10 L (IQR 0.01–0.17 s): too noisy to correct a lap '
                'with, so nothing is corrected.',
          ],
        ),
      );
    }
  }
  final bw = base.wetness;
  final tw = target.wetness;
  if (bw != null && tw != null && (bw.min != tw.min || bw.max != tw.max)) {
    chips.add(
      ComparabilityChip(
        label: '≠ wetness ${_wet(bw)} / ${_wet(tw)}',
        tone: ChipTone.neutral,
        detail: [
          'Minimum Path Wetness over each lap: Base ${_wet(bw)}, Target '
              '${_wet(tw)}.',
          "The file's weather label is not used: it is wrong both ways.",
        ],
      ),
    );
  }
  final bc = base.compoundMarks;
  final tc = target.compoundMarks;
  final named = _named(bc) && _named(tc);
  if (bc != null &&
      tc != null &&
      (named
          ? !_sameKinds(bc, tc)
          : sameCar && base.compound!.join() != target.compound!.join())) {
    chips.add(
      ComparabilityChip(
        label: '≠ compound ${_compound(bc)} / ${_compound(tc)}',
        tone: ChipTone.neutral,
        compounds: (base: bc, target: tc),
        detail: [
          "The compound at each lap's start: Base ${_compound(bc)}, Target "
              '${_compound(tc)}.',
          if (!named)
            'The file numbers compounds by their place in the session\'s '
                'list and names only some, so these are compared by number, '
                'within one car: Base ${base.compound!.join('/')}, Target '
                '${target.compound!.join('/')} (FL/FR/RL/RR).',
        ],
      ),
    );
  }
  final bt = base.trackTemperature;
  final tt = target.trackTemperature;
  if (bt != null &&
      tt != null &&
      (bt - tt).abs() >= trackTemperatureHighlight) {
    chips.add(
      ComparabilityChip(
        label: '≠ track ${bt.toStringAsFixed(0)} / ${tt.toStringAsFixed(0)} °C',
        tone: ChipTone.neutral,
        detail: [
          'Track temperature over each lap: Base ${bt.toStringAsFixed(1)} °C, '
              'Target ${tt.toStringAsFixed(1)} °C.',
          'Not shown to change pace in this library (r ≈ 0 over 136 '
              'sessions).',
        ],
      ),
    );
  }
  String energy(LapConditions c) => c.energy == null
      ? '—'
      : c.energyValid
      ? '${c.energy!.toStringAsFixed(1)}%'
      : 'n/a';
  chips.add(
    ComparabilityChip(
      label: 'conditions',
      tone: ChipTone.neutral,
      detail: [
        "At each lap's start, Base / Target:",
        'Fuel: ${_number(base.fuel, 1, 'L')} / ${_number(target.fuel, 1, 'L')}'
            ' (a "≠" chip from ${fuelHighlight.toStringAsFixed(0)} L)',
        'Virtual energy: ${energy(base)} / ${energy(target)}'
            '${base.energyValid && target.energyValid ? '' : ' (n/a: not recorded as a share in this file)'}',
        'Tyre life left: ${_wear(base.wear)} / ${_wear(target.wear)} %',
        'Compound: ${_compound(bc)} / ${_compound(tc)}'
            '${sameCar || named ? '' : ' (different cars: an unnamed index is not compared)'}',
        'Over each lap:',
        'Wetness: ${_wet(base.wetness)} / ${_wet(target.wetness)}',
        'Track: ${_number(base.trackTemperature, 1, '°C')} / '
            '${_number(target.trackTemperature, 1, '°C')}; ambient '
            '${_number(base.ambientTemperature, 1, '°C')} / '
            '${_number(target.ambientTemperature, 1, '°C')} (a "≠" chip from '
            '${trackTemperatureHighlight.toStringAsFixed(0)} °C of track)',
      ],
    ),
  );
  return chips;
}

/// "setup: n differences", from the game's own rendering of each setting;
/// null when the cars differ (the "≠ car" chip already says so) or either
/// setup is missing.
ComparabilityChip? setupChip(CarSetup? base, CarSetup? target) {
  if (base == null || target == null || base.isEmpty || target.isEmpty) {
    return null;
  }
  final differences = CarSetup.diff(base, target);
  final n = differences.length;
  String fixed(String whose, CarSetup setup) =>
      '$whose the setup: only ${setup.adjustableCount} of '
      '${setup.settingCount} settings are free.';
  // Two laps of one file, or two sessions of one series, say it once.
  final bothFixed =
      base.hasLockedSettings &&
      target.hasLockedSettings &&
      base.adjustableCount == target.adjustableCount &&
      base.settingCount == target.settingCount;
  return ComparabilityChip(
    label: 'setup: $n difference${n == 1 ? '' : 's'}',
    tone: ChipTone.neutral,
    detail: [
      if (n == 0) 'Every setting reads the same in both setups.',
      for (final d in differences)
        '${d.label}: Base ${d.base ?? '—'}, Target ${d.target ?? '—'}',
      if (bothFixed)
        fixed('Both sessions fix', base)
      else ...[
        if (base.hasLockedSettings) fixed("Base's session fixes", base),
        if (target.hasLockedSettings) fixed("Target's session fixes", target),
      ],
    ],
  );
}
