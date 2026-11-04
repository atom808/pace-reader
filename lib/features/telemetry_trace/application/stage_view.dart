/// What the lap stage shows besides the lap itself (map stage proposal §6,
/// §9): which dock tab, what the map's line is coloured by, and which corner
/// the per-corner tabs follow.
///
/// All of it outlives a screen — coming back to the stage finds the tab and
/// the colouring as they were — so all of it is kept alive.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/channels.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/lap_channels.dart';
import '../../../widgets/charting/charting.dart';
import '../../driving_technique/application/technique_focus.dart';
import '../../fuel_energy_strategy/application/fuel_energy_focus.dart';
import '../../lap_focus/lap_focus.dart';
import '../../suspension/application/suspension_focus.dart';
import '../../tires_brakes/application/tires_brakes_focus.dart';
import 'corner_chart.dart';
import 'lap_chart.dart';

/// Delta, throttle, brake, steering, speed, gear, RPM: what the driver did
/// and what the car did about it.
const inputsTab = TraceTab(id: 'inputs', label: 'Inputs', icon: Icons.tune);

/// Pressure over temperature, per corner (§6.1 tab 2).
const tyresTab = TraceTab(
  id: 'tyres',
  label: 'Tyres',
  icon: Icons.tire_repair_outlined,
  guard: ChannelGuard.anyOf({
    Channels.tyresPressure,
    Channels.tyresTempCentre,
    Channels.tyresCarcassTemp,
    Channels.tyresRimTemp,
  }, reason: 'Tyres: this recording has no tyre pressure or temperature.'),
);

/// Brake temperature per corner, with the pedal and the bias (§6.1 tab 3).
const brakesTab = TraceTab(
  id: 'brakes',
  label: 'Brakes',
  icon: Icons.album_outlined,
  guard: ChannelGuard.anyOf({
    Channels.brakesTemp,
  }, reason: 'Brakes: this recording has no brake temperature.'),
);

/// Ride height, the dampers and the third elements (§6.1 tab 4).
const suspensionTab = TraceTab(
  id: 'suspension',
  label: 'Suspension',
  icon: Icons.compress,
  guard: ChannelGuard.anyOf({
    Channels.frontRideHeight,
    Channels.rearRideHeight,
    Channels.suspPos,
  }, reason: 'Suspension: this recording has no ride height or damper travel.'),
);

/// The three G axes and the line across the track (§6.1 tab 5).
const dynamicsTab = TraceTab(
  id: 'dynamics',
  label: 'Dynamics',
  icon: Icons.open_with,
  guard: ChannelGuard.anyOf({
    Channels.gForceLat,
    Channels.gForceLong,
    Channels.gForceVert,
  }, reason: 'Dynamics: this recording has no G force channels.'),
);

/// The hybrid's charge and flow, the virtual energy and the fuel (§6.1 tab
/// 6). Shown for any car with one of them: a car without a hybrid carries
/// `SoC` and `Regen Rate` as zeros, and the tab says so rather than drawing
/// them flat (§5.4).
const energyTab = TraceTab(
  id: 'energy',
  label: 'Energy',
  icon: Icons.bolt_outlined,
  guard: ChannelGuard.anyOf({
    Channels.soc,
    Channels.virtualEnergy,
    Channels.fuelLevel,
  }, reason: 'Energy: this recording has no charge, energy or fuel channel.'),
);

/// The dock's tabs, in order. Each is data, not a screen.
const traceTabs = [
  inputsTab,
  tyresTab,
  brakesTab,
  suspensionTab,
  dynamicsTab,
  energyTab,
];

/// The channels a tab of [traceTabs] reads beyond the lap's own, as a
/// [LapChannelSet]; null for one that reads none, or reads its own way.
LapChannelSet? channelSetOf(String tabId) => switch (tabId) {
  'suspension' => LapChannelSet.suspension,
  'dynamics' => LapChannelSet.dynamics,
  'energy' => LapChannelSet.energy,
  _ => null,
};

/// The screen each tab's "in detail" link opens, at the playhead (map stage
/// proposal §6.4). A tab without one has no link.
final Map<String, LapFocusTarget> traceTabDetails = {
  inputsTab.id: techniqueFocusTarget,
  tyresTab.id: tiresBrakesFocusTarget,
  brakesTab.id: tiresBrakesFocusTarget,
  suspensionTab.id: suspensionFocusTarget,
  // Car Behavior takes this over once it is built (§6.4).
  dynamicsTab.id: techniqueFocusTarget,
  energyTab.id: fuelEnergyFocusTarget,
};

/// The tabs [chart] can show, and the one on screen: [selectedId], else the
/// first when the lap does not carry what the selected one needs.
({List<TraceTab> tabs, TraceTab shown}) shownTraceTab(
  LapChart chart,
  String selectedId,
) {
  final tabs = admittedTabs(traceTabs, chart.telemetry.channelNames);
  return (
    tabs: tabs,
    shown: tabs.firstWhere((t) => t.id == selectedId, orElse: () => tabs.first),
  );
}

final traceTabProvider = NotifierProvider<TraceTabSelection, String>(
  TraceTabSelection.new,
);

class TraceTabSelection extends Notifier<String> {
  @override
  String build() => inputsTab.id;

  void select(TraceTab tab) => state = tab.id;

  /// Selects by [TraceTab.id], as a link from another screen names it. An id
  /// the lap does not admit falls back to the first tab when shown.
  void selectId(String id) => state = id;
}

/// The corner the Tyres and Brakes tabs follow: the one the pointer last
/// rested on, which the map's line is coloured by (§3.3) and which a detail
/// link carries.
final cornerFocusProvider = NotifierProvider<CornerFocus, Corner>(
  CornerFocus.new,
);

class CornerFocus extends Notifier<Corner> {
  @override
  Corner build() => Corner.frontLeft;

  void select(Corner corner) {
    if (corner != state) state = corner;
  }
}

/// The temperature the Tyres tab shows under each pressure.
final tyreTempProvider = NotifierProvider<TyreTempSelection, TyreTemp>(
  TyreTempSelection.new,
);

class TyreTempSelection extends Notifier<TyreTemp> {
  @override
  TyreTemp build() => TyreTemp.surface;

  void select(TyreTemp temp) => state = temp;
}

/// The colouring that shows the pedals rather than a channel (D7).
const colourByInputs = 'inputs';

/// The colouring by [quantity] at the corner the tabs follow.
String colourByCorner(CornerQuantity quantity) => 'corner:${quantity.name}';

/// The corner quantity [choice] colours by, or null for any other choice.
CornerQuantity? cornerQuantityOf(String choice) {
  for (final q in CornerQuantity.values) {
    if (choice == colourByCorner(q)) return q;
  }
  return null;
}

/// What the Colour by menu offers on [tabId]: the pedals, then the channels
/// of that tab (§3.3).
List<String> colourByChoicesFor(String tabId) => switch (tabId) {
  'tyres' => [
    colourByInputs,
    colourByCorner(CornerQuantity.surface),
    colourByCorner(CornerQuantity.pressure),
  ],
  'brakes' => [colourByInputs, colourByCorner(CornerQuantity.brake)],
  _ => [colourByInputs, ...trackMapChannelChoices],
};

/// [tabId]'s colouring until the user picks one (§3.3's table): the
/// followed corner's surface temperature on Tyres, the pedals elsewhere —
/// on Brakes because where braking happens is the point.
String colourByDefault(String tabId) => tabId == tyresTab.id
    ? colourByCorner(CornerQuantity.surface)
    : colourByInputs;

String colourByLabel(String choice, {Corner? corner}) {
  if (cornerQuantityOf(choice) case final q?) {
    return corner == null ? q.label : '${q.label} · ${corner.short}';
  }
  return switch (choice) {
    colourByInputs => 'Inputs',
    Channels.groundSpeed => 'Speed',
    Channels.throttlePos => 'Throttle',
    Channels.brakePos => 'Brake',
    _ => choice,
  };
}

final colourByProvider = NotifierProvider<ColourBy, Map<String, String>>(
  ColourBy.new,
);

/// What the stage's line is coloured by, per tab: [colourByInputs], a
/// channel — which [trackMapChannelProvider] then builds the line's values
/// from — or a corner quantity. A tab with no choice has its default.
class ColourBy extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void select(String tabId, String choice) {
    state = {...state, tabId: choice};
    if (choice != colourByInputs && cornerQuantityOf(choice) == null) {
      ref.read(trackMapChannelProvider.notifier).select(choice);
    }
  }
}

/// [tabId]'s colouring in [choices].
String colourByOf(Map<String, String> choices, String tabId) =>
    choices[tabId] ?? colourByDefault(tabId);

/// The one-time offer of Performance mode when playback stutters (map stage
/// proposal §7.4): not yet made, on screen, or settled — taken or turned
/// down — for the rest of the run.
enum StutterOffer { unmade, shown, settled }

final stutterOfferProvider =
    NotifierProvider<StutterOfferNotifier, StutterOffer>(
      StutterOfferNotifier.new,
    );

class StutterOfferNotifier extends Notifier<StutterOffer> {
  @override
  StutterOffer build() => StutterOffer.unmade;

  /// Playback stuttered: shown, unless it has been already.
  void stuttered() {
    if (state == StutterOffer.unmade) state = StutterOffer.shown;
  }

  void settle() => state = StutterOffer.settled;
}
