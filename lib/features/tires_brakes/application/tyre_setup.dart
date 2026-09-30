/// The setup's tyre and brake facts, read from `metadata.CarSetup`
/// (SPEC.md §5.1, §8.6).
library;

import 'dart:convert';

import '../../../data/models/models.dart';

/// One setup value: the text the game shows and, where it has one, its number.
class SetupValue {
  const SetupValue(this.text, this.number);

  /// Parses a setup `stringValue` such as `"136 kPa"`, `"-2.30 deg"` or
  /// `"3.56 cm"` — the number is the first one in the text, the unit stays in
  /// [text]. `N/A` and empty strings are absent, not zero.
  static SetupValue? parse(Object? raw) {
    if (raw is! String) return null;
    final text = raw.trim();
    if (text.isEmpty || text == 'N/A') return null;
    final match = RegExp(r'-?\d+(\.\d+)?').firstMatch(text);
    return SetupValue(text, match == null ? null : double.parse(match[0]!));
  }

  final String text;
  final double? number;

  @override
  String toString() => text;
}

/// What the car was set up with at the tyres and brakes, per corner where
/// the setup names corners.
///
/// Reads each key's `stringValue`, never `lastSavedStringValue`, because only
/// the first is what the car ran with — checked against the one setting the
/// telemetry also records: the Race sample's `Brake Bias Rear` event holds
/// 0.4875, i.e. **51.2 : 48.8**, which is `VM_BRAKE_BALANCE.stringValue`,
/// while `lastSavedStringValue` says 57.0 : 43.0. The two differ on the
/// camber too (−2.30° against −5.00°), so the wrong one would be plausible
/// and wrong on the numbers a driver tunes.
///
/// Every `WM_*-W_{FL,FR,RL,RR}` group is left/right symmetric in all three
/// samples (§15.5), so these are usually two numbers, front and rear — kept
/// per corner anyway, since nothing guarantees a symmetric setup.
class TyreSetup {
  const TyreSetup({
    this.compound = const {},
    this.coldPressure = const {},
    this.camber = const {},
    this.discThickness = const {},
    this.brakeBalance,
    this.brakeMigration,
    this.brakePressure,
  });

  /// Parses the `CarSetup` JSON blob. A blob that is missing, malformed or
  /// lacks a key yields an empty entry for it, never an error: the setup is
  /// reference material beside the telemetry, and a view that fails because
  /// its reference card cannot fill would be failing on the wrong thing.
  factory TyreSetup.fromJson(String json) {
    Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const TyreSetup();
    }
    if (decoded is! Map<String, Object?>) return const TyreSetup();

    SetupValue? value(String key) {
      final entry = decoded! as Map<String, Object?>;
      final item = entry[key];
      return item is Map<String, Object?>
          ? SetupValue.parse(item['stringValue'])
          : null;
    }

    Map<Corner, SetupValue> perCorner(String group) => {
          for (final corner in Corner.values)
            corner: ?value(corner.setupKey(group)),
        };

    return TyreSetup(
      compound: perCorner('COMPOUND'),
      coldPressure: perCorner('PRESSURE'),
      camber: perCorner('CAMBER'),
      discThickness: perCorner('BRAKEDISC'),
      brakeBalance: value('VM_BRAKE_BALANCE'),
      brakeMigration: value('VM_BRAKE_MIGRATION'),
      brakePressure: value('VM_BRAKE_PRESSURE'),
    );
  }

  /// `WM_COMPOUND-W_xx` — the compound the car *started* on. A tyre change
  /// during the session shows up in the `TyresCompound` event, not here.
  final Map<Corner, SetupValue> compound;

  /// `WM_PRESSURE-W_xx`, kPa. Cold, and a reference rather than the first
  /// sample: the Race sample sets 136 kPa and its first reading is 171.7,
  /// because a race starts on tyres the game has already warmed.
  final Map<Corner, SetupValue> coldPressure;

  /// `WM_CAMBER-W_xx`, degrees — negative on every corner of every sample,
  /// which is why the inner tread edge runs hottest.
  final Map<Corner, SetupValue> camber;

  /// `WM_BRAKEDISC-W_xx`, cm. The `Brake Thickness` channel says "%" but holds
  /// exactly this in cm (3.56 front / 3.20 rear GT3, 4.00 Hypercar) and does
  /// not move at two decimals, so the setup value is shown and the channel is
  /// not drawn.
  final Map<Corner, SetupValue> discThickness;

  /// `VM_BRAKE_BALANCE`, front : rear, e.g. `51.2:48.8`.
  final SetupValue? brakeBalance;

  /// `VM_BRAKE_MIGRATION`, e.g. `2.5% F` on the Spa Hypercar, ` 0.0` on both
  /// GT3s.
  final SetupValue? brakeMigration;

  /// `VM_BRAKE_PRESSURE`, the setup's "Max Pedal Force", e.g. `108 kgf (90%)`.
  final SetupValue? brakePressure;

  bool get isEmpty =>
      compound.isEmpty &&
      coldPressure.isEmpty &&
      camber.isEmpty &&
      discThickness.isEmpty &&
      brakeBalance == null &&
      brakeMigration == null &&
      brakePressure == null;
}

/// A per-corner setup group said once per axle when the axle is symmetric —
/// `136 kPa` rather than `136 kPa, 136 kPa` — and per corner when it is not.
///
/// Returns `(label, text)` rows: `('All four', …)`, `('Front', …)` /
/// `('Rear', …)`, or one row per corner.
List<(String, String)> describeAxles(Map<Corner, SetupValue> values) {
  if (values.isEmpty) return const [];
  String? text(Corner corner) => values[corner]?.text;
  final texts = {for (final corner in Corner.values) text(corner)};
  if (texts.length == 1 && texts.single != null) {
    return [('All four', texts.single!)];
  }
  final front = {text(Corner.frontLeft), text(Corner.frontRight)};
  final rear = {text(Corner.rearLeft), text(Corner.rearRight)};
  if (front.length == 1 && rear.length == 1 && !texts.contains(null)) {
    return [('Front', front.single!), ('Rear', rear.single!)];
  }
  return [
    for (final corner in Corner.values)
      if (text(corner) case final t?) (corner.short, t),
  ];
}
