/// What the lap stage shows besides the lap itself (map stage proposal §6,
/// §9): which dock tab, and what the map's line is coloured by.
///
/// Both outlive a screen — coming back to the stage finds the tab and the
/// colouring as they were — so both are kept alive.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/channels.dart';
import '../../../widgets/charting/charting.dart';
import 'lap_chart.dart';

/// Delta, throttle, brake, steering, speed, gear, RPM: what the driver did
/// and what the car did about it.
const inputsTab = TraceTab(id: 'inputs', label: 'Inputs', icon: Icons.tune);

/// The dock's tabs, in order. P3 adds Tyres and Brakes here; each is data,
/// not a screen.
const traceTabs = [inputsTab];

final traceTabProvider = NotifierProvider<TraceTabSelection, String>(
  TraceTabSelection.new,
);

class TraceTabSelection extends Notifier<String> {
  @override
  String build() => inputsTab.id;

  void select(TraceTab tab) => state = tab.id;
}

/// The colouring that shows the pedals rather than a channel (D7).
const colourByInputs = 'inputs';

/// What the Colour by menu offers: the pedals, then the channels the map
/// has always offered.
const colourByChoices = [colourByInputs, ...trackMapChannelChoices];

String colourByLabel(String choice) => switch (choice) {
  colourByInputs => 'Inputs',
  Channels.groundSpeed => 'Speed',
  Channels.throttlePos => 'Throttle',
  Channels.brakePos => 'Brake',
  _ => choice,
};

final colourByProvider = NotifierProvider<ColourBy, String>(ColourBy.new);

/// What the stage's line is coloured by: [colourByInputs], or a channel —
/// which [trackMapChannelProvider] then builds the line's values from.
class ColourBy extends Notifier<String> {
  @override
  String build() => colourByInputs;

  void select(String choice) {
    state = choice;
    if (choice != colourByInputs) {
      ref.read(trackMapChannelProvider.notifier).select(choice);
    }
  }
}
