/// The four corners of the car, and which `valueN` column holds each
/// (SPEC.md §5.3, §15.5).
library;

/// A side of the car, in the car's own frame (driver's left/right).
enum CarSide { left, right }

/// One wheel position, in the order the per-corner columns hold them:
/// `value1..value4` = **FL, FR, RL, RR**.
///
/// ## Why this order is fact, not convention (§15.5, resolved)
///
/// §5.3 could only confirm front-pair-then-rear-pair from the setup, because
/// every `WM_*-W_{FL,FR,RL,RR}` group is left/right symmetric in all three
/// samples (each setup even carries `"symmetric": true`), so the setup cannot
/// be the answer key. Three independent measurements settled left/right
/// instead, all in agreement:
///
/// - **Wheel-speed kinematics.** Over a closed lap the heading turns by ±2π,
///   so ∫(v_left − v_right)dt = −track·Θ. Measured ∫(v1 − v2)dt per lap:
///   −10.56/−10.58 m on anticlockwise Interlagos, +10.26/+10.24 m on
///   clockwise Spa, +10.57…+10.63 m on all 18 laps of clockwise Sebring —
///   a 1.68 m GT3 front track (1.63 m Hypercar) with value1 on the **left**;
///   value1 on the right would need a track of −1.7 m. The rear pair (v3 −
///   v4) is identical.
/// - **Heat, pressure and wear by circuit direction.** The outside tyres of a
///   circuit's dominant turn work hardest: on clockwise Sebring lap index 18
///   the carcass runs FL 93.4 °C against FR 83.3 °C, and anticlockwise
///   Interlagos reverses it, FR 65.0 against FL 58.8. Sebring's wear over the
///   stint is fastest on FL (lap means 99.39 → 92.12 %).
/// - **Roll.** `RideHeights` v1 − v2 against lateral acceleration: the inside
///   wheel rises, correlation +0.95…+0.99.
///
/// Everything that labels a per-corner column goes through this type, so the
/// mapping is written down exactly once.
enum Corner {
  frontLeft('FL', 'Front left', 'value1'),
  frontRight('FR', 'Front right', 'value2'),
  rearLeft('RL', 'Rear left', 'value3'),
  rearRight('RR', 'Rear right', 'value4');

  const Corner(this.short, this.label, this.valueColumn);

  /// `FL`, `FR`, `RL`, `RR` — also the suffix the setup uses
  /// (`WM_PRESSURE-W_FL`).
  final String short;

  /// `Front left` etc., for headings.
  final String label;

  /// The per-corner channel/event column holding this corner.
  final String valueColumn;

  bool get isFront => this == frontLeft || this == frontRight;
  bool get isLeft => this == frontLeft || this == rearLeft;

  CarSide get side => isLeft ? CarSide.left : CarSide.right;

  /// The car-frame tread edge that faces the car's centreline.
  ///
  /// `TyresTempLeft`/`Right` are the tread's **car-frame** edges, not
  /// inner/outer (§15.5 findings): with negative camber the inner edge runs
  /// hottest on all four wheels, and that edge is `TyresTempRight` on the left
  /// wheels (v1, v3) but `TyresTempLeft` on the right ones (v2, v4). Measured
  /// as per-lap means on every corner of every lap after the garage lap: an
  /// inner-minus-outer spread of +6.9…+14.6 °C on the Sebring Race, +5.6…+11.9
  /// on Interlagos, +3.8…+8.6 on Spa — never once negative. Reading "Left" as
  /// "inner" would swap the camber story on half the car.
  CarSide get innerEdge => isLeft ? CarSide.right : CarSide.left;

  /// The car-frame tread edge on the outside of the car.
  CarSide get outerEdge => isLeft ? CarSide.left : CarSide.right;

  /// The setup key for this corner in a `WM_<group>-W_xx` group.
  String setupKey(String group) => 'WM_$group-W_$short';

  /// The corner a per-corner column holds, or null for a column that is not
  /// one of `value1..value4`.
  static Corner? ofColumn(String column) {
    for (final corner in values) {
      if (corner.valueColumn == column) return corner;
    }
    return null;
  }

  /// The per-corner columns, in [Corner] order — what a one-scan read of a
  /// per-corner channel asks for.
  static List<String> get valueColumns =>
      [for (final corner in values) corner.valueColumn];
}
