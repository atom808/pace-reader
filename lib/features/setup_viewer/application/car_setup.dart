/// The embedded car setup, parsed and grouped for reading (SPEC.md §5.1, §8.10).
///
/// `metadata.CarSetup` is one JSON object of 172 top-level keys in every sample
/// on hand — 110 `VM_*` (vehicle-level) settings, 60 `WM_<NAME>-W_<CORNER>`
/// (per-wheel) settings, a `gearGraph` and a `symmetric` flag — with the *same
/// keys in the same order* in the Practice, Qualify and Race files. So there is
/// no setup schema to discover per car: what varies is which entries are
/// applicable, and what they read.
///
/// Everything here is plain Dart over the string the session already holds
/// (`SessionMetadata.carSetupJson`), so a `flutter test` reaches it with no
/// DuckDB connection and the unit tests run against the real JSON of all three
/// samples rather than against a hand-built imitation of it.
///
/// ## What the fields mean, measured
///
/// The setting objects carry ten fields; the spec's history is a record of
/// plausible-looking readings of fields like these being wrong, so each claim
/// below was checked against something independent of the field itself — the
/// telemetry in the same file, or arithmetic across settings — on all three
/// samples (510 setting objects).
///
/// - **`value` is a step index, not a physical quantity.** `minValue` is 0 in
///   all 510 and `maxValue` is the last index (`value` never leaves the range).
///   `stringValue` is the game's own rendering of that step. The evidence is
///   the step size: `(stringValue − lowest-step string) / value` is the same
///   constant for every corner of a group whose corners sit at *different*
///   indices — Interlagos camber is `-1.8 deg` at index 32 on the front and
///   `-1.3 deg` at 25 on the rear, both from a `-5.0`/`-3.8` origin, and both
///   work out to exactly 0.1 deg a step. It is why the range track here is
///   drawn from the index and labelled a *step*: on brake bias a step is
///   0.25 points, on Spa's ride height 0.1 cm, on a damper one click.
/// - **`lastSavedStringValue` is *not* the saved setup.** The name invites
///   "changed since saved", and a marker built on that would be wrong. It is
///   the game's rendering of the *lowest step* — `-5.00 deg` for camber,
///   `0 (Off)` for a TC map, `57.0:43.0` for brake bias, `0.01` for fuel level
///   — which is why it equals `stringValue` wherever `value` is 0 (120, 117
///   and 122 of the 170 settings in the Practice, Qualify and Race files; the
///   one miss, Interlagos's fuel-load string, differs only in its laps
///   estimate). A driver's saved setup is not the minimum of every range.
///   Three families break the pattern — tyre compound, the pit-stop slots and
///   the two "(n laps)" estimates on fuel and virtual energy — so it is
///   carried on [SetupSetting.lastSavedStringValue] for completeness and shown
///   nowhere: presenting it as the low end of a range would be wrong for those.
/// - **`available` means "this car has no such adjustment".** It is false for
///   exactly the gear slots the car does not have (`VM_GEAR_7..9` on a
///   six-speed) and the per-gear upshift-RPM slots (10–11 per sample), and in
///   every one of those `stringValue` is `"N/A"` and `value` is 0. The count
///   of available `VM_GEAR_n` equals `gearGraph.numForwardGears` in all three
///   (6, 7, 6). But `available` alone under-reports: 28–47 more settings per
///   sample are available and *also* read `"N/A"` (Sebring's twelve
///   `VM_CHASSIS_ADJ_*` slots, the three `VM_PITSTOP_*` slots in all three),
///   so [SetupSetting.isNotApplicable] is the two together.
/// - **`isFreeSetting` is "adjustable in this session".** True for all 170 in
///   the Practice and Qualify files; in the Race file it is true for exactly
///   27 — brake bias and migration, TC/ABS maps, tyre compound, fuel and
///   virtual-energy load, steering lock, pit-stop plan, handbrake pressure —
///   which is the set a fixed-setup race leaves the driver. The other 143
///   (springs, dampers, camber, toe, wing, pressures…) are locked.
/// - **`numChangesValue` is a signed step count and is almost always 0.** It
///   is non-zero on 5 of 510 settings, all in the Qualify file: virtual energy
///   at −74 (its `value` is 26, and 26 − 100 = −74, where 100 is what the
///   Practice file starts it at) and the four tyre compounds at −1. That is
///   what a qualifying run looks like — little energy, the soft tyre — but
///   the reference the count is taken from is not in the data, and zero is
///   uninformative (a setting can be off its lowest step and still read 0),
///   so only a non-zero count is surfaced, as what it says: a change of n
///   steps.
/// - **`diffComparisonValue` is 0 in all 510** — the garage's compare-two-
///   setups delta, unused in a recording. It is read and ignored.
/// - **`symmetric` is true in all three**, and with it every left/right pair
///   in every per-wheel group and every `VM_LEFT_*`/`VM_RIGHT_*` pair is
///   identical on all of `value`, `stringValue`, range, availability and lock
///   state. The converse — false meaning independent sides — has no sample.
/// - **`caption`** appears on seven settings in each sample (`"DIVE PLANE"`,
///   `"Max Pedal Force"`, `"Wheel Range (Lock)"`, and on Spa's
///   `VM_CHASSIS_ADJ_00` `"FRONT PUSHROD"`): the game's own name for a slot
///   whose generic key says less. It is shown as a second line, in sentence
///   case (the same slot reads `Max Pedal Force` in two files and `MAX PEDAL
///   FORCE` in the third), unless blank (one is a single space) or a repeat of
///   the label.
///
/// Cross-checks of `stringValue` against the file's own telemetry:
/// `VM_BRAKE_BALANCE` is `front:rear` (`51.2:48.8` against a `Brake Bias Rear`
/// event of 0.4875, and `50.5:49.5`/`51.9:48.1` against 0.495/0.481);
/// `VM_TRACTIONCONTROLMAP` equals the `TCLevel` event and
/// `VM_ANTILOCKBRAKESYSTEMMAP` the `ABSLevel` event (5/7/6 and 9/0/9);
/// `VM_VIRTUAL_ENERGY.value` equals the first `Virtual Energy` sample (100, 26,
/// 47); and the litres in `VM_FUEL_CAPACITY`'s string equal the first `Fuel
/// Level` sample to 0.1 L (86.0, 20.8, 40.9) — so despite its key that entry
/// reads as the fuel *loaded*, which is how it is labelled. `WM_BRAKEDISC` is
/// the disc thickness (3.56 cm front, 3.20 cm rear: the first `Brake
/// Thickness` sample to the digit, in both files that have one of each) and
/// `WM_RIDEHEIGHT` a ride-height set-point in cm — within about 1 cm of the
/// first `RideHeights` sample, front and rear, in all three, not a reading.
library;

import 'dart:convert';

/// A wheel position, as the JSON keys themselves name it.
///
/// Safe to label — unlike telemetry's `value1..value4`, whose left/right order
/// was an open question (§5.3, §15.5) — because the key says `-W_FL`, not "the
/// first one".
enum WheelCorner {
  fl('FL', 'Front left'),
  fr('FR', 'Front right'),
  rl('RL', 'Rear left'),
  rr('RR', 'Rear right');

  const WheelCorner(this.code, this.title);

  final String code;
  final String title;

  bool get isFront => this == fl || this == fr;
  bool get isLeft => this == fl || this == rl;

  static WheelCorner? tryParse(String code) {
    for (final corner in values) {
      if (corner.code == code) return corner;
    }
    return null;
  }
}

/// The groups a setup engineer expects to find things under, in the order a
/// setup sheet reads.
enum SetupSectionId {
  aero('Aero', 'Aero'),
  brakes('Brakes', 'Brakes'),
  suspension('Suspension & chassis', 'Suspension'),
  alignment('Alignment & steering', 'Alignment'),
  tyres('Tyres', 'Tyres'),
  differential('Differential', 'Diff'),
  gearing('Gearing', 'Gearing'),
  electronics('Electronics', 'Electronics'),
  engine('Engine, fuel & hybrid', 'Engine'),
  other('Other', 'Other');

  const SetupSectionId(this.title, this.shortTitle);

  final String title;

  /// For the navigation chips, where ten full titles do not fit a row.
  final String shortTitle;
}

/// One setting: a `VM_*` entry, one corner of a `WM_*` group, or — for a
/// top-level entry this build does not recognise — a [raw] one carrying the
/// entry's JSON as text, so nothing in the file is dropped.
class SetupSetting {
  const SetupSetting({
    required this.key,
    required this.label,
    required this.stringValue,
    this.caption,
    this.value = 0,
    this.minValue = 0,
    this.maxValue = 0,
    this.available = true,
    this.isFree = true,
    this.stepsMoved = 0,
    this.lastSavedStringValue = '',
    this.corner,
    this.isRaw = false,
  });

  /// The JSON key, verbatim — what the search matches when a name fails.
  final String key;

  /// Humanised (`VM_FRONT_3RD_SLOWBUMP` → `Front 3rd · slow bump`), or for a
  /// [corner] the group's label, since the corner is shown beside it.
  final String label;

  /// The game's own name for the slot, when it gives one worth showing.
  final String? caption;

  /// The game's formatted value, verbatim: `51.2:48.8`, `136 kPa`, `P4`,
  /// `40.9L (22.0 laps)`. Untrimmed, because it is data — see [display].
  final String stringValue;

  /// The step index (see the library note); `minValue` is 0 in every sample.
  final int value;
  final int minValue;
  final int maxValue;

  final bool available;

  /// `isFreeSetting` — adjustable in this session.
  final bool isFree;

  /// `numChangesValue` — see the library note. Zero is uninformative.
  final int stepsMoved;

  /// Carried, never shown: it is the lowest step's rendering, not a saved setup.
  final String lastSavedStringValue;

  final WheelCorner? corner;

  /// A top-level entry that is not a setting object, kept as JSON text.
  final bool isRaw;

  /// What the row shows. The game pads some strings (`" 0.0"`, `" 0.0:100.0"`).
  String get display => stringValue.trim();

  /// The car has no such adjustment, or the game says so: [available] is
  /// false, or the string reads `N/A`. Hidden by default and never dropped.
  bool get isNotApplicable => !available || display.toUpperCase() == 'N/A';

  /// The car fixes this and says so (`Non-adjustable`, `Fixed`) — a stated
  /// fact worth showing, in a quieter voice than a value.
  bool get isFixedByCar {
    final text = display.toLowerCase();
    return text == 'non-adjustable' || text == 'fixed';
  }

  bool get isLocked => !isFree;

  bool get isMoved => stepsMoved != 0;

  /// Steps between the first and last option.
  int get steps => maxValue - minValue;

  /// Whether a position within the range says anything. A two-option setting
  /// (`Available`, `Detached`, an on/off) is a switch: a track with a dot at
  /// one end would be a bar carrying one bit, on 51 of Interlagos's 112
  /// applicable rows — noise, not a range. Three options is the least that
  /// has a middle.
  bool get hasRange => !isRaw && steps >= 2;

  /// Where [value] sits from the first option (0) to the last (1).
  double? get rangeFraction =>
      steps > 0 ? ((value - minValue) / steps).clamp(0.0, 1.0) : null;

  /// Whether every word of [tokens] (already lower-case) appears in the
  /// label, caption, key, value or [extra] text.
  bool matches(List<String> tokens, {String extra = ''}) {
    if (tokens.isEmpty) return true;
    final haystack = '$label ${caption ?? ''} $key $display $extra'
        .toLowerCase();
    return tokens.every(haystack.contains);
  }
}

/// One per-wheel setting across its four corners (`WM_CAMBER-W_FL` … `-W_RR`),
/// drawn as a 2×2 car layout: FL FR over RL RR.
class WheelSettingGroup {
  const WheelSettingGroup({
    required this.id,
    required this.label,
    required this.corners,
  });

  /// The key stem: `CAMBER` for `WM_CAMBER-W_FL`.
  final String id;
  final String label;
  final Map<WheelCorner, SetupSetting> corners;

  Iterable<SetupSetting> get settings => corners.values;

  bool get isNotApplicable => settings.every((s) => s.isNotApplicable);

  /// Whether the left and right of each axle read the same — true of every
  /// group in every sample, which is what `symmetric: true` promises.
  bool get isMirrored =>
      _same(WheelCorner.fl, WheelCorner.fr) &&
      _same(WheelCorner.rl, WheelCorner.rr);

  bool _same(WheelCorner a, WheelCorner b) =>
      corners[a]?.display == corners[b]?.display;

  bool matches(List<String> tokens, {String extra = ''}) {
    if (tokens.isEmpty) return true;
    final corner = [for (final c in corners.keys) '${c.code} ${c.title}']
        .join(' ');
    final values = settings.map((s) => s.display).join(' ');
    final captions = settings.map((s) => s.caption ?? '').join(' ');
    final haystack = '$label $captions WM_$id $corner $values $extra'
        .toLowerCase();
    return tokens.every(haystack.contains);
  }
}

/// One gear of `gearGraph`, with where its line starts and ends on an
/// rpm-against-speed diagram.
class GearStep {
  const GearStep({
    required this.gear,
    required this.topSpeed,
    required this.upshiftRpm,
    required this.rpmAfterUpshift,
    required this.entrySpeed,
    required this.entryRpm,
  });

  /// 1-based.
  final int gear;

  /// Speed at the top of the gear — where the game shifts up — in
  /// [GearGraph.unit].
  final double topSpeed;

  /// The rpm reached there: the rev limit in every sample (8,250, 8,500,
  /// 7,500, each within 16 rpm of the session's peak `Engine RPM`).
  final double upshiftRpm;

  /// The rpm the next gear starts at, straight after the shift. Null in top
  /// gear, which has no next.
  final double? rpmAfterUpshift;

  /// Where the line starts: the standstill for first gear, the previous
  /// gear's top speed and post-shift rpm after that.
  final double entrySpeed;
  final double entryRpm;

  double? get rpmDrop =>
      rpmAfterUpshift == null ? null : upshiftRpm - rpmAfterUpshift!;
}

/// `gearGraph`: per-gear top speed and shift rpm, decoded.
///
/// The raw shape is `{numForwardGears, unit, topSpeed[10], kiloRPM[20]}`, with
/// index 0 of `topSpeed` and the first pair of `kiloRPM` unused (zeros) and
/// gears from index 1. `kiloRPM` is ten *pairs* — `(peak, after-upshift)` per
/// gear, in thousands of rpm — which is not evident from the array and was
/// checked two ways:
///
/// - Against itself: the after-upshift rpm of gear *g* is where gear *g+1*'s
///   line passes at gear *g*'s top speed, `topSpeed[g] / topSpeed[g+1] ×
///   peak[g+1]`. All 16 shifts across the three samples agree to within
///   36 rpm (mean 15).
/// - Against the telemetry: the median speed per rpm the car actually ran in
///   each gear (`Ground Speed / Engine RPM` while in that `Gear`) is 1.4–8.3%
///   *higher* than `topSpeed / peak` — 1.4–4.4% at Interlagos, 6.7–8.3% at
///   Spa, 5.3–7.7% at Sebring — and within a few points across the gears of
///   one file. So these are the game's nominal figures, right in ratio and
///   steps and a few percent low in absolute speed; read as *the gearing*, not
///   as a prediction of what a lap will reach. (Top gear was not used in
///   either six-speed file, so it is checked only through the pairs.)
class GearGraph {
  const GearGraph({required this.unit, required this.steps});

  /// As the file states it (`kph` in all three).
  final String unit;
  final List<GearStep> steps;

  double get maxSpeed => steps.map((s) => s.topSpeed).reduce(_max);
  double get maxRpm => steps.map((s) => s.upshiftRpm).reduce(_max);

  static double _max(double a, double b) => a > b ? a : b;

  /// Decodes the raw entry, or null when it is not the shape described above
  /// (so the caller keeps it as a raw entry instead of drawing nonsense).
  static GearGraph? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final count = raw['numForwardGears'];
    final speeds = raw['topSpeed'];
    final rpm = raw['kiloRPM'];
    if (count is! int || count < 1 || count > 9) return null;
    if (speeds is! List || speeds.length < count + 1) return null;
    if (rpm is! List || rpm.length < 2 * (count + 1)) return null;
    if (speeds.any((v) => v is! num) || rpm.any((v) => v is! num)) return null;

    double speed(int gear) => (speeds[gear] as num).toDouble();
    double peak(int gear) => (rpm[2 * gear] as num).toDouble() * 1000;
    double after(int gear) => (rpm[2 * gear + 1] as num).toDouble() * 1000;

    final steps = <GearStep>[];
    for (var gear = 1; gear <= count; gear++) {
      if (speed(gear) <= 0 || peak(gear) <= 0) return null;
      if (gear > 1 && speed(gear) <= speed(gear - 1)) return null;
      steps.add(
        GearStep(
          gear: gear,
          topSpeed: speed(gear),
          upshiftRpm: peak(gear),
          rpmAfterUpshift: gear < count ? after(gear) : null,
          entrySpeed: gear == 1 ? 0 : speed(gear - 1),
          entryRpm: gear == 1 ? 0 : after(gear - 1),
        ),
      );
    }
    final unit = raw['unit'];
    return GearGraph(
      unit: unit is String && unit.trim().isNotEmpty ? unit.trim() : 'kph',
      steps: steps,
    );
  }
}

/// A section's contents: the vehicle-level settings, then the per-wheel groups.
class SetupSection {
  const SetupSection({
    required this.id,
    this.singles = const [],
    this.wheelGroups = const [],
  });

  final SetupSectionId id;
  final List<SetupSetting> singles;
  final List<WheelSettingGroup> wheelGroups;

  /// Settings, counting each corner of a group.
  int get count =>
      singles.length + wheelGroups.fold(0, (n, g) => n + g.corners.length);

  bool get isEmpty => singles.isEmpty && wheelGroups.isEmpty;
}

/// What the viewer is narrowed to.
class SetupFilter {
  const SetupFilter({
    this.query = '',
    this.showNotApplicable = false,
    this.adjustableOnly = false,
  });

  final String query;

  /// Off by default: 38–58 of a sample's 170 settings read `N/A`, and a wall
  /// of them buries the 112–132 that say something.
  final bool showNotApplicable;

  final bool adjustableOnly;

  List<String> get tokens => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();

  SetupFilter copyWith({
    String? query,
    bool? showNotApplicable,
    bool? adjustableOnly,
  }) => SetupFilter(
    query: query ?? this.query,
    showNotApplicable: showNotApplicable ?? this.showNotApplicable,
    adjustableOnly: adjustableOnly ?? this.adjustableOnly,
  );

  @override
  bool operator ==(Object other) =>
      other is SetupFilter &&
      other.query == query &&
      other.showNotApplicable == showNotApplicable &&
      other.adjustableOnly == adjustableOnly;

  @override
  int get hashCode => Object.hash(query, showNotApplicable, adjustableOnly);
}

/// A [SetupFilter] applied — the sections that survive, and what was left out
/// and why, so the screen can say so rather than silently shrink (no silent
/// caps).
class SetupView {
  const SetupView({
    required this.sections,
    required this.shown,
    required this.total,
    required this.hiddenNotApplicable,
    required this.hiddenLocked,
  });

  final List<SetupSection> sections;
  final int shown;
  final int total;

  /// Matches left out because they read `N/A` (checked before the lock filter,
  /// so a locked N/A setting is counted here and not below).
  final int hiddenNotApplicable;

  /// Matches left out by "adjustable only" that would otherwise be shown.
  final int hiddenLocked;

  SetupSection? section(SetupSectionId id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// A `CarSetup` that could not be read at all.
class SetupFormatException implements Exception {
  const SetupFormatException(this.message);

  final String message;

  @override
  String toString() => 'SetupFormatException: $message';
}

/// The parsed setup.
class CarSetup {
  const CarSetup({
    required this.sections,
    required this.gears,
    required this.symmetric,
    required this.settingCount,
    required this.rawCount,
    required this.lockedCount,
    required this.movedCount,
    required this.notApplicableCount,
  });

  /// A recording with no `CarSetup` entry (or an empty one).
  static const empty = CarSetup(
    sections: [],
    gears: null,
    symmetric: null,
    settingCount: 0,
    rawCount: 0,
    lockedCount: 0,
    movedCount: 0,
    notApplicableCount: 0,
  );

  /// Only the sections that hold something, in setup-sheet order.
  final List<SetupSection> sections;
  final GearGraph? gears;

  /// The `symmetric` flag; null when the file does not carry one.
  final bool? symmetric;

  /// Setting objects (`VM_*` and each corner of `WM_*`): 170 in every sample.
  final int settingCount;

  /// Top-level entries that were neither a setting object nor `gearGraph` /
  /// `symmetric`, kept under Other as JSON text.
  final int rawCount;

  final int lockedCount;
  final int movedCount;
  final int notApplicableCount;

  bool get isEmpty => sections.isEmpty && gears == null;

  /// Every setting the viewer can show, raw entries included.
  int get total => settingCount + rawCount;

  int get adjustableCount => settingCount - lockedCount;

  /// The session leaves some settings locked and some free — a fixed-setup
  /// race — which is the only case where telling the two apart carries
  /// information (the Practice and Qualify samples are 170 of 170 free).
  bool get hasLockedSettings => lockedCount > 0 && lockedCount < settingCount;

  Iterable<SetupSetting> get allSettings sync* {
    for (final section in sections) {
      yield* section.singles;
      for (final group in section.wheelGroups) {
        yield* group.settings;
      }
    }
  }

  /// A setting by its JSON key.
  SetupSetting? byKey(String key) {
    for (final s in allSettings) {
      if (s.key == key) return s;
    }
    return null;
  }

  /// The wheel group with key stem [id] (`CAMBER`).
  WheelSettingGroup? wheelGroup(String id) {
    for (final section in sections) {
      for (final group in section.wheelGroups) {
        if (group.id == id) return group;
      }
    }
    return null;
  }

  SetupSection? section(SetupSectionId id) {
    for (final s in sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Applies [filter].
  ///
  /// Text is matched word by word (all words must hit) against label, the
  /// game's caption, JSON key, displayed value and section title — the value
  /// too, unlike the events log's name-only search, because a row here shows
  /// its value beside its name, so a hit for `soft` or `kPa` is a hit the
  /// reader can see the reason for.
  SetupView apply(SetupFilter filter) {
    final tokens = filter.tokens;
    var hiddenNotApplicable = 0;
    var hiddenLocked = 0;

    /// Whether a setting (or group, via its corners) clears the two toggles,
    /// counting what each one hid.
    bool passes(Iterable<SetupSetting> settings) {
      final all = settings.toList();
      if (!filter.showNotApplicable && all.every((s) => s.isNotApplicable)) {
        hiddenNotApplicable += all.length;
        return false;
      }
      if (filter.adjustableOnly && all.every((s) => s.isLocked)) {
        hiddenLocked += all.length;
        return false;
      }
      return true;
    }

    final out = <SetupSection>[];
    for (final section in sections) {
      final title = section.id.title;
      final singles = <SetupSetting>[];
      for (final s in section.singles) {
        if (!s.matches(tokens, extra: title)) continue;
        if (passes([s])) singles.add(s);
      }
      final groups = <WheelSettingGroup>[];
      for (final g in section.wheelGroups) {
        if (!g.matches(tokens, extra: title)) continue;
        if (passes(g.settings)) groups.add(g);
      }
      final kept = SetupSection(
        id: section.id,
        singles: singles,
        wheelGroups: groups,
      );
      // Unless a search is narrowing things, Gearing stays for its graph even
      // when every gearing setting reads N/A.
      final holdsGraph =
          section.id == SetupSectionId.gearing &&
          gears != null &&
          tokens.isEmpty;
      if (!kept.isEmpty || holdsGraph) out.add(kept);
    }
    return SetupView(
      sections: out,
      shown: out.fold(0, (n, s) => n + s.count),
      total: total,
      hiddenNotApplicable: hiddenNotApplicable,
      hiddenLocked: hiddenLocked,
    );
  }

  /// Parses the `CarSetup` JSON.
  ///
  /// A blank string is [empty] (the repository reads a missing key as `''`);
  /// text that is not a JSON object throws [SetupFormatException]. Within an
  /// object nothing throws: an entry that is not a setting is kept as a raw
  /// row under Other, so a future LMU adding a key changes what is listed, not
  /// whether the screen opens.
  static CarSetup parse(String source) {
    final text = source.trim();
    if (text.isEmpty) return empty;

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw SetupFormatException(
        'the CarSetup entry is not valid JSON (${e.message})',
      );
    }
    if (decoded is! Map) {
      throw SetupFormatException(
        'the CarSetup entry is JSON, but a ${_describe(decoded)} rather than an object',
      );
    }

    bool? symmetric;
    GearGraph? gears;
    // (position in the catalogue, position in the file, item): `List.sort` is
    // not guaranteed stable, and unknown keys all tie on the first number —
    // the second keeps them in file order.
    var seq = 0;
    final singles = <SetupSectionId, List<(int, int, SetupSetting)>>{};
    final groups = <String, Map<WheelCorner, SetupSetting>>{};
    final groupOrder = <String>[];
    final raw = <SetupSetting>[];
    var settingCount = 0;
    var locked = 0;
    var moved = 0;
    var notApplicable = 0;

    void count(SetupSetting s) {
      settingCount++;
      if (s.isLocked) locked++;
      if (s.isMoved) moved++;
      if (s.isNotApplicable) notApplicable++;
    }

    for (final entry in decoded.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (key == 'symmetric' && value is bool) {
        symmetric = value;
        continue;
      }
      if (key == 'gearGraph') {
        final parsed = GearGraph.tryParse(value);
        if (parsed != null) {
          gears = parsed;
          continue;
        }
      }
      if (value is Map && _looksLikeSetting(value)) {
        final wheel = _wheelKey.firstMatch(key);
        final corner = wheel == null
            ? null
            : WheelCorner.tryParse(wheel.group(2)!);
        if (wheel != null && corner != null) {
          final stem = wheel.group(1)!;
          final setting = _settingFrom(
            key,
            value,
            label: _labelFor('WM_$stem'),
            corner: corner,
          );
          if (!groups.containsKey(stem)) groupOrder.add(stem);
          groups.putIfAbsent(stem, () => {})[corner] = setting;
          count(setting);
        } else {
          final setting = _settingFrom(key, value, label: _labelFor(key));
          count(setting);
          final section = _defs[key]?.section ?? SetupSectionId.other;
          singles.putIfAbsent(section, () => []).add((
            _orderOf(key),
            seq++,
            setting,
          ));
        }
        continue;
      }
      raw.add(
        SetupSetting(
          key: key,
          label: _generic(key),
          stringValue: _compact(value),
          isRaw: true,
        ),
      );
    }

    final wheelBySection =
        <SetupSectionId, List<(int, int, WheelSettingGroup)>>{};
    for (final stem in groupOrder) {
      final id = 'WM_$stem';
      final section = _defs[id]?.section ?? SetupSectionId.other;
      final ordered = {
        for (final corner in WheelCorner.values)
          if (groups[stem]!.containsKey(corner)) corner: groups[stem]![corner]!,
      };
      wheelBySection.putIfAbsent(section, () => []).add((
        _orderOf(id),
        seq++,
        WheelSettingGroup(id: stem, label: _labelFor(id), corners: ordered),
      ));
    }
    singles.putIfAbsent(SetupSectionId.other, () => []).addAll([
      for (final r in raw) (_unknownOrder, seq++, r),
    ]);

    int byOrder<T>((int, int, T) a, (int, int, T) b) =>
        a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2);
    final sections = <SetupSection>[];
    for (final id in SetupSectionId.values) {
      final s = [...?singles[id]]..sort(byOrder);
      final w = [...?wheelBySection[id]]..sort(byOrder);
      final section = SetupSection(
        id: id,
        singles: [for (final e in s) e.$3],
        wheelGroups: [for (final e in w) e.$3],
      );
      // A gear graph is drawn under Gearing, so the section exists for it even
      // in a file with no gearing settings — the graph is never dropped.
      final holdsGraph = id == SetupSectionId.gearing && gears != null;
      if (!section.isEmpty || holdsGraph) sections.add(section);
    }

    return CarSetup(
      sections: sections,
      gears: gears,
      symmetric: symmetric,
      settingCount: settingCount,
      rawCount: raw.length,
      lockedCount: locked,
      movedCount: moved,
      notApplicableCount: notApplicable,
    );
  }

  static String _describe(Object? value) => switch (value) {
    null => 'null',
    List() => 'list',
    String() => 'string',
    num() => 'number',
    bool() => 'boolean',
    _ => value.runtimeType.toString(),
  };
}

/// `WM_CAMBER-W_FL` → stem `CAMBER`, corner `FL`.
final _wheelKey = RegExp(r'^WM_(.+)-W_([A-Z]{2})$');

/// The stable shape of a setting object: it carries the game's own rendering.
bool _looksLikeSetting(Map<dynamic, dynamic> map) =>
    map['stringValue'] is String && map['value'] is num;

SetupSetting _settingFrom(
  String key,
  Map<dynamic, dynamic> map, {
  required String label,
  WheelCorner? corner,
}) {
  int int_(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
  bool bool_(Object? v, {required bool fallback}) => v is bool ? v : fallback;

  final caption = map['caption'];
  return SetupSetting(
    key: key,
    label: label,
    caption: _captionFor(caption, label),
    stringValue: map['stringValue'] as String,
    value: int_(map['value']),
    minValue: int_(map['minValue']),
    maxValue: int_(map['maxValue']),
    available: bool_(map['available'], fallback: true),
    isFree: bool_(map['isFreeSetting'], fallback: true),
    stepsMoved: int_(map['numChangesValue']),
    lastSavedStringValue: map['lastSavedStringValue'] is String
        ? map['lastSavedStringValue'] as String
        : '',
    corner: corner,
  );
}

/// The game's caption in sentence case, or null when it says nothing new.
///
/// Blank (Interlagos's `VM_HANDFRONTBRAKE_PRESSURE` has a single space) and
/// repeats of the label (`OIL RADIATOR COVER` on a setting already labelled
/// "Oil radiator cover") are dropped. A caption whose every word is capitalised
/// — `MAX PEDAL FORCE` in one file, `Max Pedal Force` in two — is folded to
/// sentence case, so one slot reads the same whichever car it came from; a
/// caption already in sentence case is left alone.
String? _captionFor(Object? caption, String label) {
  if (caption is! String) return null;
  var text = caption.trim();
  if (text.isEmpty) return null;
  final words = text
      .split(RegExp(r'\s+'))
      .where((w) => RegExp(r'[A-Za-z]').hasMatch(w));
  final allCapitalised = words.every((w) {
    final first = RegExp(r'[A-Za-z]').firstMatch(w)!.group(0)!;
    return first == first.toUpperCase();
  });
  if (allCapitalised) text = text[0] + text.substring(1).toLowerCase();
  if (_squash(text) == _squash(label)) return null;
  return text;
}

String _squash(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// A raw entry's value as one short line of JSON.
String _compact(Object? value) {
  final text = jsonEncode(value);
  return text.length <= 160 ? text : '${text.substring(0, 157)}…';
}

// ---------------------------------------------------------------------------
// The catalogue: which section a key belongs to, and what to call it.
//
// One table rather than a `switch` per concern, so the section, the label and
// the order within the section cannot disagree. An entry's position here is its
// position in its section. Keys not listed fall through to `Other` with a
// generic label — which the unit tests pin to *nothing* for the 170 settings of
// all three samples, so a key the table forgot is a failing test, not a quietly
// misfiled setting.
// ---------------------------------------------------------------------------

class _Def {
  const _Def(this.id, this.section, this.label);

  final String id;
  final SetupSectionId section;
  final String label;
}

final List<_Def> _catalogue = _buildCatalogue();

final Map<String, _Def> _defs = {for (final d in _catalogue) d.id: d};
final Map<String, int> _order = {
  for (var i = 0; i < _catalogue.length; i++) _catalogue[i].id: i,
};

/// Unknown keys sort after every catalogued one, in file order.
final int _unknownOrder = _catalogue.length;

int _orderOf(String id) => _order[id] ?? _unknownOrder;

String _labelFor(String id) => _defs[id]?.label ?? _generic(id);

/// `VM_NEW_THING` → `New thing`; `WM_NEW_THING-W_FL` → `New thing`.
String _generic(String key) {
  var text = key
      .replaceFirst(RegExp(r'^(VM|WM)_'), '')
      .replaceFirst(RegExp(r'-W_[A-Z]{2}$'), '')
      .replaceAll('_', ' ')
      .trim()
      .toLowerCase();
  if (text.isEmpty) text = key;
  return text[0].toUpperCase() + text.substring(1);
}

List<_Def> _buildCatalogue() {
  const aero = SetupSectionId.aero;
  const brakes = SetupSectionId.brakes;
  const suspension = SetupSectionId.suspension;
  const alignment = SetupSectionId.alignment;
  const tyres = SetupSectionId.tyres;
  const diff = SetupSectionId.differential;
  const gearing = SetupSectionId.gearing;
  const electronics = SetupSectionId.electronics;
  const engine = SetupSectionId.engine;

  String pad(int n) => n.toString().padLeft(2, '0');

  return [
    // Aero
    const _Def('VM_FRONT_WING', aero, 'Front wing'),
    const _Def('VM_REAR_WING', aero, 'Rear wing'),
    const _Def('VM_LEFT_FENDER_FLARE', aero, 'Fender flare · left'),
    const _Def('VM_RIGHT_FENDER_FLARE', aero, 'Fender flare · right'),

    // Brakes
    const _Def('VM_BRAKE_BALANCE', brakes, 'Brake bias'),
    const _Def('VM_BRAKE_MIGRATION', brakes, 'Brake migration'),
    const _Def('VM_BRAKE_PRESSURE', brakes, 'Brake pressure'),
    const _Def('VM_HANDBRAKE_PRESSURE', brakes, 'Handbrake pressure'),
    const _Def(
      'VM_HANDFRONTBRAKE_PRESSURE',
      brakes,
      'Front handbrake pressure',
    ),
    const _Def('VM_BRAKE_DUCTS', brakes, 'Brake ducts · front'),
    const _Def('VM_BRAKE_DUCTS_REAR', brakes, 'Brake ducts · rear'),
    const _Def('WM_BRAKEDISC', brakes, 'Brake disc thickness'),
    const _Def('WM_BRAKEPAD', brakes, 'Brake pad'),

    // Suspension & chassis
    const _Def('WM_SPRING', suspension, 'Spring'),
    const _Def('WM_SLOWBUMP', suspension, 'Damper · slow bump'),
    const _Def('WM_FASTBUMP', suspension, 'Damper · fast bump'),
    const _Def('WM_SLOWREBOUND', suspension, 'Damper · slow rebound'),
    const _Def('WM_FASTREBOUND', suspension, 'Damper · fast rebound'),
    const _Def('WM_PACKERS', suspension, 'Packers'),
    const _Def('WM_RIDEHEIGHT', suspension, 'Ride height'),
    const _Def('WM_SRUBBER', suspension, 'Spring rubber'),
    const _Def('WM_TENDERSPRING', suspension, 'Tender spring'),
    const _Def('WM_TENDERSPRINGTRAVEL', suspension, 'Tender spring travel'),
    const _Def('VM_FRONT_ANTISWAY', suspension, 'Front anti-roll bar'),
    const _Def('VM_REAR_ANTISWAY', suspension, 'Rear anti-roll bar'),
    for (final axle in ['FRONT', 'REAR']) ...[
      _Def('VM_${axle}_3RD_SPRING', suspension, '${_title(axle)} 3rd · spring'),
      _Def(
        'VM_${axle}_3RD_SLOWBUMP',
        suspension,
        '${_title(axle)} 3rd · slow bump',
      ),
      _Def(
        'VM_${axle}_3RD_FASTBUMP',
        suspension,
        '${_title(axle)} 3rd · fast bump',
      ),
      _Def(
        'VM_${axle}_3RD_SLOWREBOUND',
        suspension,
        '${_title(axle)} 3rd · slow rebound',
      ),
      _Def(
        'VM_${axle}_3RD_FASTREBOUND',
        suspension,
        '${_title(axle)} 3rd · fast rebound',
      ),
      _Def(
        'VM_${axle}_3RD_PACKERS',
        suspension,
        '${_title(axle)} 3rd · packers',
      ),
      _Def(
        'VM_${axle}_3RD_TENDERSPRING',
        suspension,
        '${_title(axle)} 3rd · tender spring',
      ),
      _Def(
        'VM_${axle}_3RD_TENDERSPRINGTRAVEL',
        suspension,
        '${_title(axle)} 3rd · tender spring travel',
      ),
    ],
    const _Def('VM_LEFT_TRACK_BAR', suspension, 'Track bar · left'),
    const _Def('VM_RIGHT_TRACK_BAR', suspension, 'Track bar · right'),
    const _Def('VM_WEIGHT_DISTRIB', suspension, 'Weight distribution'),
    const _Def('VM_WEIGHT_LATERAL', suspension, 'Weight · lateral'),
    const _Def('VM_WEIGHT_VERTICAL', suspension, 'Weight · vertical'),
    const _Def('VM_WEIGHT_WEDGE', suspension, 'Weight · wedge'),
    for (var i = 0; i < 12; i++)
      _Def(
        'VM_CHASSIS_ADJ_${pad(i)}',
        suspension,
        'Chassis adjuster ${pad(i)}',
      ),

    // Alignment & steering
    const _Def('WM_CAMBER', alignment, 'Camber'),
    const _Def('VM_FRONT_TOEIN', alignment, 'Front toe-in'),
    const _Def('VM_REAR_TOEIN', alignment, 'Rear toe-in'),
    const _Def('VM_FRONT_TOEOFFSET', alignment, 'Front toe offset'),
    const _Def('VM_REAR_TOEOFFSET', alignment, 'Rear toe offset'),
    const _Def('VM_LEFT_CASTER', alignment, 'Caster · left'),
    const _Def('VM_RIGHT_CASTER', alignment, 'Caster · right'),
    const _Def('VM_FRONT_WHEEL_TRACK', alignment, 'Front track width'),
    const _Def('VM_REAR_WHEEL_TRACK', alignment, 'Rear track width'),
    const _Def('VM_STEER_LOCK', alignment, 'Steering lock'),

    // Tyres
    const _Def('WM_COMPOUND', tyres, 'Tyre compound'),
    const _Def('WM_PRESSURE', tyres, 'Tyre pressure'),
    const _Def('VM_FRONT_TIRE_COMPOUND', tyres, 'Front tyre compound'),
    const _Def('VM_REAR_TIRE_COMPOUND', tyres, 'Rear tyre compound'),

    // Differential
    const _Def('VM_DIFF_POWER', diff, 'Diff · power'),
    const _Def('VM_DIFF_COAST', diff, 'Diff · coast'),
    const _Def('VM_DIFF_PRELOAD', diff, 'Diff · preload'),
    const _Def('VM_DIFF_PUMP', diff, 'Diff · pump'),
    const _Def('VM_FRONT_DIFF_POWER', diff, 'Front diff · power'),
    const _Def('VM_FRONT_DIFF_COAST', diff, 'Front diff · coast'),
    const _Def('VM_FRONT_DIFF_PRELOAD', diff, 'Front diff · preload'),
    const _Def('VM_FRONT_DIFF_PUMP', diff, 'Front diff · pump'),
    const _Def('VM_TORQUE_SPLIT', diff, 'Torque split'),

    // Gearing
    const _Def('VM_RATIO_SET', gearing, 'Ratio set'),
    const _Def('VM_GEAR_FINAL', gearing, 'Final drive'),
    const _Def('VM_GEAR_REVERSE', gearing, 'Reverse'),
    for (var g = 1; g <= 9; g++) _Def('VM_GEAR_$g', gearing, 'Gear $g ratio'),
    const _Def('VM_GEAR_AUTOUPSHIFT', gearing, 'Auto upshift'),
    const _Def('VM_GEAR_AUTODOWNSHIFT', gearing, 'Auto downshift'),
    for (var g = 1; g <= 8; g++)
      _Def('VM_GEAR_UPSHIFT_RPM_$g', gearing, 'Gear $g upshift rpm'),

    // Electronics
    const _Def('VM_TRACTION_CONTROL', electronics, 'Traction control'),
    const _Def('VM_TRACTIONCONTROLMAP', electronics, 'TC map'),
    const _Def(
      'VM_TRACTIONCONTROLPOWERCUTMAP',
      electronics,
      'TC power-cut map',
    ),
    const _Def(
      'VM_TRACTIONCONTROLSLIPANGLEMAP',
      electronics,
      'TC slip-angle map',
    ),
    const _Def('VM_ANTILOCK_BRAKES', electronics, 'ABS'),
    const _Def('VM_ANTILOCKBRAKESYSTEMMAP', electronics, 'ABS map'),

    // Engine, fuel & hybrid
    const _Def('VM_ENGINE_MIXTURE', engine, 'Engine mixture'),
    const _Def('VM_ENGINE_BOOST', engine, 'Engine boost'),
    const _Def('VM_ENGINE_BRAKEMAP', engine, 'Engine braking map'),
    const _Def('VM_REV_LIMITER', engine, 'Rev limiter'),
    const _Def('VM_ELECTRIC_MOTOR_MAP', engine, 'Electric motor map'),
    const _Def('VM_REGEN_LEVEL', engine, 'Regen level'),
    const _Def('VM_FUEL_LEVEL', engine, 'Fuel level'),
    // Labelled for what it reads, not for its key: see the library note.
    const _Def('VM_FUEL_CAPACITY', engine, 'Fuel at start'),
    const _Def('VM_VIRTUAL_ENERGY', engine, 'Virtual energy at start'),
    const _Def('VM_OIL_RADIATOR', engine, 'Oil radiator cover'),
    const _Def('VM_WATER_RADIATOR', engine, 'Water radiator cover'),
    // The pit plan is the fuel plan, so it sits with fuel rather than alone.
    const _Def('VM_NUM_PITSTOPS', engine, 'Planned pit stops'),
    for (var i = 1; i <= 3; i++) _Def('VM_PITSTOP_$i', engine, 'Pit stop $i'),
  ];
}

String _title(String upper) => upper[0] + upper.substring(1).toLowerCase();
