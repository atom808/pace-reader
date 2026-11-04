/// Suspension as a [LapFocusTarget] (map stage proposal §6.4): the lap, and
/// once the sites are read, the one nearest the point the sender showed.
library;

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../lap_focus/lap_focus.dart';
import '../domain/sites.dart';
import 'suspension_providers.dart';

/// How far from the playhead a site still counts as the one being looked
/// at: about a corner's approach.
const focusSiteMetres = 150.0;

class SuspensionFocusTarget implements LapFocusTarget {
  const SuspensionFocusTarget();

  @override
  String get route => '/suspension';

  @override
  String get label => 'Suspension';

  @override
  IconData get icon => Icons.compress;

  @override
  void apply(WidgetRef ref, LapFocus focus) => ref
      .read(suspensionSelectionStateProvider(focus.source).notifier)
      .selectLap(focus.lap);
}

const suspensionFocusTarget = SuspensionFocusTarget();

/// The site nearest [focus]'s point within [focusSiteMetres]; null when it
/// points nowhere or no site is that near, which leaves the screen on its
/// top site.
Site? focusedSite(List<Site> sites, LapFocus focus) {
  final point = focus.point;
  if (point == null) return null;
  Site? best;
  for (final s in sites) {
    final d = (s.place - point).abs();
    if (d <= focusSiteMetres &&
        (best == null || d < (best.place - point).abs())) {
      best = s;
    }
  }
  return best;
}

/// The site view's id for `LapFocusReveal`: where a focus near a site lands.
const suspensionSiteReveal = 'suspension-site';

/// The platform panels' id for `LapFocusReveal`: where a focus near no site
/// lands, since the platform is what the whole lap did.
const suspensionPlatformReveal = 'suspension-platform';
