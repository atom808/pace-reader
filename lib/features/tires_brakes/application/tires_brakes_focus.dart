/// Tires & Brakes as a [LapFocusTarget] (map stage proposal §6.4): the lap,
/// the metric that matches what the sender showed, and the corner it was
/// looking at lit.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../data/channels.dart';
import '../../lap_focus/lap_focus.dart';
import 'tire_brake_report.dart';
import 'tire_brake_selection.dart';

class TiresBrakesFocusTarget implements LapFocusTarget {
  const TiresBrakesFocusTarget();

  @override
  String get route => '/tires-brakes';

  @override
  String get label => 'Tires & brakes';

  @override
  IconData get icon => Icons.tire_repair_outlined;

  @override
  void apply(WidgetRef ref, LapFocus focus) {
    ref.read(tyreLapSelectionProvider(focus.source).notifier).select(focus.lap);
    if (metricOfChannel(focus.channel) case final metric?) {
      ref
          .read(tyreMetricSelectionProvider(focus.source).notifier)
          .select(metric);
    }
  }
}

const tiresBrakesFocusTarget = TiresBrakesFocusTarget();

/// The metric that shows [channel]; null for one this screen has no metric
/// for. The tread zones and their average are the tread metric.
TyreMetric? metricOfChannel(String? channel) => switch (channel) {
  Channels.tyresPressure => TyreMetric.pressure,
  Channels.tyresTempLeft ||
  Channels.tyresTempCentre ||
  Channels.tyresTempRight ||
  Channels.tyresRimTemp => TyreMetric.tread,
  Channels.tyresCarcassTemp => TyreMetric.carcass,
  Channels.tyresWear => TyreMetric.wear,
  Channels.brakesTemp => TyreMetric.brake,
  _ => null,
};

/// The channel [metric] reads, the inverse of [metricOfChannel]: what a link
/// back to Trace names.
String channelOfMetric(TyreMetric metric) => switch (metric) {
  TyreMetric.pressure => Channels.tyresPressure,
  TyreMetric.tread => Channels.tyresTempCentre,
  TyreMetric.carcass => Channels.tyresCarcassTemp,
  TyreMetric.wear => Channels.tyresWear,
  TyreMetric.brake => Channels.brakesTemp,
};
