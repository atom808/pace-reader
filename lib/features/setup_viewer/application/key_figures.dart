/// The few settings a setup is usually asked about first (SPEC.md §8.10).
library;

import '../../../data/reference/tyre_compound.dart';
import 'car_setup.dart';

/// One headline figure: brake bias, the wing, the tyres, the traction map.
class KeyFigure {
  const KeyFigure({
    required this.label,
    required this.value,
    this.caption,
    this.compounds = const [],
  });

  final String label;
  final String value;
  final String? caption;

  /// For the tyre compound: one mark when all four wheels match, else the
  /// four (FL, FR, RL, RR), badged beside the value the way the game marks a
  /// mixed set.
  final List<CompoundMark> compounds;

  @override
  bool operator ==(Object other) =>
      other is KeyFigure &&
      other.label == label &&
      other.value == value &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(label, value, caption);

  @override
  String toString() =>
      'KeyFigure($label: $value${caption == null ? '' : ' — $caption'})';
}

/// The headline figures the setup can supply, in reading order.
///
/// Leads the screen for the reason the Fuel & Energy view leads with tiles: the
/// question a driver brings to a setup is often one number — where is the
/// brake bias, what is the wing at — and a number that is the whole message is
/// a tile, not a row to find among 116. Each figure is dropped when the car has
/// no such setting (a Hypercar has no ABS map, and reads `N/A` for it), never
/// filled with a placeholder.
///
/// Every source is a setting the row list also shows, so a tile is a copy of a
/// row, not a second reading of the data.
List<KeyFigure> keyFigures(CarSetup setup) {
  String? shown(String key) {
    final setting = setup.byKey(key);
    if (setting == null || setting.isNotApplicable) return null;
    return setting.display;
  }

  final figures = <KeyFigure>[];

  // Read as front:rear — the rear share is the `Brake Bias Rear` event
  // (`51.2:48.8` against 0.4875 in the Race sample).
  final bias = shown('VM_BRAKE_BALANCE');
  if (bias != null) {
    figures.add(
      KeyFigure(label: 'Brake bias', value: bias, caption: 'front : rear'),
    );
  }

  final rearWing = shown('VM_REAR_WING');
  if (rearWing != null) {
    final frontWing = shown('VM_FRONT_WING');
    figures.add(
      KeyFigure(
        label: 'Rear wing',
        value: rearWing,
        caption: frontWing == null ? null : 'front wing $frontWing',
      ),
    );
  }

  // The per-wheel `WM_COMPOUND-W_*` is what each corner was fitted with. The
  // axle's `VM_*_TIRE_COMPOUND` is not: across 440 recordings it names the
  // session's first compound (Soft wherever Soft is offered), whatever is
  // fitted, and differs from the wheels in 203 of them (SPEC §15.20).
  // The name is the figure; a used set's tread goes in the caption, since
  // "70% Medium" in the tile's numeral would not fit its width. All four
  // wheels are read: the game offers a set per wheel, and its presets split
  // the car by side as well as by axle.
  final fitted = [
    for (final corner in const ['FL', 'FR', 'RL', 'RR'])
      ?CompoundMark.ofSetup(shown('WM_COMPOUND-W_$corner')),
  ];
  if (fitted.isNotEmpty) {
    // Grouped by compound, not by tread: four used Mediums worn to different
    // depths are one compound.
    final plain = [
      for (final m in fitted) CompoundMark(kind: m.kind, name: m.name),
    ];
    final treads = {
      for (final m in fitted)
        if (m.treadLeft != null) m.treadLeft!.toStringAsFixed(0),
    };
    final uniform = plain.every((m) => m == plain.first);
    final (value, layout) = switch (plain) {
      _ when uniform => (plain.first.label, 'front and rear'),
      [final fl, final fr, final rl, final rr] when fl == fr && rl == rr => (
        '${fl.label} / ${rl.label}',
        'front / rear',
      ),
      [final fl, final fr, final rl, final rr] when fl == rl && fr == rr => (
        '${fl.label} / ${fr.label}',
        'left / right',
      ),
      _ => ('Mixed', describeCompounds(plain)),
    };
    figures.add(
      KeyFigure(
        label: 'Tyre compound',
        value: value,
        caption: [
          layout,
          if (treads.isNotEmpty) 'used, ${treads.join(' / ')} % tread',
        ].join(' · '),
        compounds: uniform ? [plain.first] : plain,
      ),
    );
  }

  // `VM_TRACTIONCONTROLMAP` is the `TCLevel` event (5, 7, 6 across the three
  // samples); the other two maps qualify it.
  final tc = shown('VM_TRACTIONCONTROLMAP');
  if (tc != null) {
    final parts = [
      if (shown('VM_TRACTIONCONTROLPOWERCUTMAP') case final cut?)
        'power cut $cut',
      if (shown('VM_TRACTIONCONTROLSLIPANGLEMAP') case final slip?)
        'slip angle $slip',
    ];
    figures.add(
      KeyFigure(
        label: 'Traction control',
        value: tc,
        caption: parts.isEmpty ? null : parts.join(' · '),
      ),
    );
  }

  return figures;
}
