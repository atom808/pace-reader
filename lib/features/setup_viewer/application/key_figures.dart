/// The few settings a setup is usually asked about first (SPEC.md §8.10).
library;

import 'car_setup.dart';

/// One headline figure: brake bias, the wing, the tyres, the traction map.
class KeyFigure {
  const KeyFigure({required this.label, required this.value, this.caption});

  final String label;
  final String value;
  final String? caption;

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

  // The `VM_*` compound is the axle's, and the `WM_*` one is per wheel; either
  // says it, and every sample has both, agreeing.
  final front = shown('VM_FRONT_TIRE_COMPOUND') ?? shown('WM_COMPOUND-W_FL');
  final rear = shown('VM_REAR_TIRE_COMPOUND') ?? shown('WM_COMPOUND-W_RL');
  if (front != null) {
    figures.add(
      KeyFigure(
        label: 'Tyre compound',
        value: front,
        caption: rear == null || rear == front
            ? 'front and rear'
            : 'rear $rear',
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
