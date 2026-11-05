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
import '../../../data/channels.dart';

/// Fuel is highlighted from this difference (L): about 0.2 s at the
/// library's +0.08 s per 10 L.
const fuelHighlight = 25.0;

/// Track temperature is highlighted from this difference (°C), above the
/// 4.6 °C p90 drift within one race. It is not shown to change pace in this
/// library (r ≈ 0 over 136 sessions).
const trackTemperatureHighlight = 5.0;

/// The battery is highlighted from this difference in what the two laps
/// spent (SoC points): the p90 between two clean laps of one Hypercar
/// session (21.1 over 14,732 pairs in 129 sessions; p50 8.2). A GO
/// qualifying lap against a race lap is 30 or more (PACE-FACTORS §10.1).
const batterySpendHighlight = 21.0;

/// Map steps closer together than this are one switch (s): GO's 499P lap
/// steps 3 → 10 one event at a time within 1.3 s (PACE-FACTORS §5.5).
const mapSwitchGapSeconds = 1.5;

/// One lap's hybrid battery: what it started and ended on, and the energy
/// that went out and in (PACE-FACTORS §5.5, §10).
class LapBattery {
  const LapBattery({this.socStart, this.socEnd, this.deployed, this.harvested});

  /// `SoC` at the lap's first and last samples (%).
  final double? socStart;
  final double? socEnd;

  /// `Regen Rate` integrated over the lap below and above zero (MJ, both
  /// positive).
  final double? deployed;
  final double? harvested;

  /// The points of charge the lap used: negative when it ended fuller.
  double? get spent =>
      socStart == null || socEnd == null ? null : socStart! - socEnd!;
}

/// How the deployment map (`FuelMixtureMap`) moved over one lap.
class MapUse {
  const MapUse({required this.min, required this.max, required this.switches});

  /// The lowest and highest map in force at any moment of the lap.
  final double min;
  final double max;

  /// Moves within the lap, each run of steps closer than
  /// [mapSwitchGapSeconds] counted once.
  final int switches;
}

/// One lap's conditions.
class LapConditions {
  const LapConditions({
    this.fuel,
    this.energy,
    this.battery,
    this.map,
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

  /// Null for a car without a hybrid, where `SoC` and `Regen Rate` are flat
  /// (zero in GT3, 100 % in the Valkyrie).
  final LapBattery? battery;

  /// Null where the file records no `FuelMixtureMap`.
  final MapUse? map;

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
  Events.tcLevel,
  Events.tcCut,
  Events.tcSlipAngle,
  Events.absLevel,
  Events.brakeBiasRear,
  Events.brakeMigration,
  Events.fuelMixtureMap,
];

/// A session's per-lap reads, cut into [LapConditions] lap by lap.
class SessionConditions {
  const SessionConditions({
    this.fuel = const {},
    this.energy = const {},
    this.soc = const {},
    this.regen = const {},
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

  /// Empty for a car without a hybrid: the read skips a flat channel.
  final Map<int, LapChannelStats> soc;
  final Map<int, LapChannelFlow> regen;
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
    final charge = soc[lap.index];
    final flow = regen[lap.index];
    return LapConditions(
      fuel: fuel[lap.index]?.first,
      energy: energy[lap.index]?.first,
      battery: charge == null && flow == null
          ? null
          : LapBattery(
              socStart: charge?.first,
              socEnd: charge?.last,
              deployed: flow == null ? null : -flow.below / 1e6,
              harvested: flow == null ? null : flow.above / 1e6,
            ),
      map: switch (settings[Events.fuelMixtureMap]) {
        final series? => mapUse(series, start, end),
        null => null,
      },
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

/// How [series] moved between [start] and [end]: its range over the lap,
/// the value in force at the start included, and its switches. Null when no
/// value is in force anywhere in the lap.
MapUse? mapUse(StepSeries series, double start, double end) {
  final atStart = series.valueAt(start);
  var lo = atStart ?? double.infinity;
  var hi = atStart ?? double.negativeInfinity;
  var switches = 0;
  double? last;
  for (var i = 0; i < series.length; i++) {
    final t = series.times[i];
    if (t <= start || t >= end) continue;
    final v = series.values[i];
    if (v < lo) lo = v;
    if (v > hi) hi = v;
    if (last == null || t - last >= mapSwitchGapSeconds) switches++;
    last = t;
  }
  if (!lo.isFinite || !hi.isFinite) return null;
  return MapUse(min: lo, max: hi, switches: switches);
}

String _number(double? value, int decimals, String unit) =>
    value == null ? '—' : '${value.toStringAsFixed(decimals)} $unit';

/// "77 → 38 %".
String _charge(LapBattery? b) => b?.socStart == null || b?.socEnd == null
    ? '—'
    : '${b!.socStart!.toStringAsFixed(0)} → ${b.socEnd!.toStringAsFixed(0)} %';

/// "39 points used", "7 points gained".
String _points(double spent) => spent >= 0
    ? '${spent.toStringAsFixed(0)} points used'
    : '${(-spent).toStringAsFixed(0)} points gained';

/// "5.6 MJ".
String _mj(double? value) => _number(value, 1, 'MJ');

/// "1–10, 4 switches", "5, held".
String _map(MapUse? m) {
  if (m == null) return '—';
  final range = m.min == m.max
      ? _trim(m.min)
      : '${_trim(m.min)}–${_trim(m.max)}';
  return m.switches == 0
      ? '$range, held'
      : '$range, ${m.switches} switch${m.switches == 1 ? '' : 'es'}';
}

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
  final bb = base.battery;
  final tb = target.battery;
  final bSpent = bb?.spent;
  final tSpent = tb?.spent;
  if (bSpent != null &&
      tSpent != null &&
      (bSpent - tSpent).abs() >= batterySpendHighlight) {
    chips.add(
      ComparabilityChip(
        label: '≠ battery ${_charge(bb)} / ${_charge(tb)}',
        tone: ChipTone.neutral,
        detail: [
          'State of charge over each lap: Base ${_charge(bb)} '
              '(${_points(bSpent)}), Target ${_charge(tb)} '
              '(${_points(tSpent)}).',
          'Deployed: Base ${_mj(bb?.deployed)}, Target ${_mj(tb?.deployed)}. '
              'Harvested: Base ${_mj(bb?.harvested)}, Target '
              '${_mj(tb?.harvested)}.',
          if (base.map != null || target.map != null)
            'Deployment map: Base ${_map(base.map)}, Target '
                '${_map(target.map)}.',
          'A qualifying lap can spend most of a battery that a race lap '
              'holds level, so straight-line speed is not compared like for '
              'like. Nothing is corrected.',
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
        if (bb != null || tb != null) ...[
          'Battery over the lap: ${_charge(bb)} / ${_charge(tb)} (a "≠" '
              'chip from ${batterySpendHighlight.toStringAsFixed(0)} points '
              'spent)',
          'Deployed: ${_mj(bb?.deployed)} / ${_mj(tb?.deployed)}',
          'Harvested: ${_mj(bb?.harvested)} / ${_mj(tb?.harvested)}',
        ],
        if (base.map != null || target.map != null)
          'Deployment map over the lap: ${_map(base.map)} / '
              '${_map(target.map)}',
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
