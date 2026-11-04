/// A tab of the stage's dock, as data (map stage proposal §6.1, §14.2).
///
/// A tab is not a screen: it is what to call it, what glyph to show, and
/// which channels it needs. The feature that owns the channels declares its
/// tabs and builds their panels; the dock shows whichever tabs the lap can
/// fill, and says in words why the others are missing.
library;

import 'package:material_ui/material_ui.dart';

/// Which channels a tab needs before it has anything to show.
class ChannelGuard {
  /// Shown whatever the file carries.
  const ChannelGuard.always() : channels = const {}, reason = null;

  /// Shown when the lap carries at least one of [channels]; [reason] says
  /// why it is not, when it is not.
  const ChannelGuard.anyOf(this.channels, {required String this.reason});

  final Set<String> channels;
  final String? reason;

  bool admits(Set<String> available) =>
      channels.isEmpty || channels.any(available.contains);
}

class TraceTab {
  const TraceTab({
    required this.id,
    required this.label,
    required this.icon,
    this.guard = const ChannelGuard.always(),
  });

  /// Stable across runs: the remembered tab is stored by it.
  final String id;
  final String label;
  final IconData icon;
  final ChannelGuard guard;

  @override
  bool operator ==(Object other) => other is TraceTab && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The tabs of [tabs] that [available] channels can fill, in order.
List<TraceTab> admittedTabs(List<TraceTab> tabs, Set<String> available) => [
  for (final tab in tabs)
    if (tab.guard.admits(available)) tab,
];
