/// Short display names for the shell's session switcher (SPEC.md §8.1, §9.7.6).
///
/// The rail badge has a tooltip and the switcher popover has one line per open
/// session, and both have to name a session in a few words. The full strings
/// in the file are written for a catalogue, not a chip:
///
/// | `TrackName`                    | `TrackLayout`                            |
/// |--------------------------------|------------------------------------------|
/// | Autódromo José Carlos Pace     | Autódromo José Carlos Pace               |
/// | Circuit de Spa-Francorchamps   | Circuit de Spa-Francorchamps Endurance   |
/// | Sebring International Raceway  | Sebring School Circuit                   |
///
/// (Measured from the three `metadata` tables in `samples/`.) Two things in
/// that table drive the rules below. The layout very often *repeats* the track
/// name — Interlagos' layout is its track name to the character, Spa's is the
/// track name plus "Endurance" — so a naive "track — layout" label says the
/// circuit twice. And what tells two sessions apart at Sebring is the layout,
/// not the track: the Race sample is the 3.08 km School Circuit, roughly half
/// the full course (§8.1), so dropping the layout to save space would make two
/// different circuits wear the same name.
///
/// These are *display* helpers and never keys: nothing indexes, groups or
/// compares on them. `SessionMetadata.trackKey` is the key. Every rule falls
/// back to the original string rather than to an empty one, so an unfamiliar
/// name costs some length, never legibility.
library;

import '../data/models/models.dart';

/// Words a circuit's own name carries that add nothing next to a rail badge.
///
/// Only the three measured names are verified against real data; the rest are
/// the same *kinds* of prefix and suffix (a language's word for "circuit" or
/// "autodrome", an "International Raceway") that other tracks in the game are
/// named with. "Circuit of the Americas" is deliberately not matched — what
/// is left after stripping "Circuit of the" is "Americas", which is not a
/// name.
final _leadingWords = RegExp(
  r'^(?:circuit\s+de\s+la\s+|circuit\s+de\s+|circuit\s+des\s+|circuito\s+de\s+'
  r'|aut[oó]dromo\s+internacional\s+d[oae]\s+|aut[oó]dromo\s+nazionale\s+'
  r'|aut[oó]dromo\s+)',
  caseSensitive: false,
);

final _trailingWords = RegExp(
  r'\s+(?:international\s+raceway|international\s+circuit'
  r'|international\s+speedway|motorsport\s+park|raceway|speedway)$',
  caseSensitive: false,
);

/// A circuit's name without its boilerplate: `Sebring International Raceway`
/// → `Sebring`, `Circuit de Spa-Francorchamps` → `Spa-Francorchamps`,
/// `Autódromo José Carlos Pace` → `José Carlos Pace`.
///
/// Returns [trackName] unchanged when stripping would leave fewer than three
/// characters — a rule that turns a name into nothing is a bug in the rule.
String shortTrackName(String trackName) {
  final trimmed = trackName.trim();
  final short = trimmed
      .replaceFirst(_leadingWords, '')
      .replaceFirst(_trailingWords, '')
      .trim();
  return short.length < 3 ? trimmed : short;
}

/// What distinguishes this layout from the circuit it belongs to, or null
/// when it adds nothing (Interlagos: the layout *is* the track name).
///
/// The track name is removed whether it is written out in full ("Circuit de
/// Spa-Francorchamps Endurance" → `Endurance`) or as its short form ("Sebring
/// School Circuit" → `School Circuit`), because the file does both.
String? shortLayoutName(String trackName, String trackLayout) {
  final layout = trackLayout.trim();
  if (layout.isEmpty || layout == trackName.trim()) return null;

  var rest = layout;
  final short = shortTrackName(trackName);
  for (final prefix in [trackName.trim(), short]) {
    if (prefix.isNotEmpty &&
        rest.toLowerCase().startsWith(prefix.toLowerCase())) {
      rest = rest.substring(prefix.length).trim();
      break;
    }
  }
  // A layout that was *only* the track name (in either spelling) has nothing
  // left to say; a layout that shares no prefix is kept whole.
  return rest.isEmpty ? null : rest;
}

/// The one-line name of a session's circuit: `Sebring School Circuit`,
/// `Spa-Francorchamps Endurance`, `José Carlos Pace`.
///
/// Track first and layout after, joined by a space, because that is how the
/// layouts read aloud — nobody says "Sebring, School Circuit".
String shortCircuitTitle(SessionMetadata metadata) {
  final track = shortTrackName(metadata.trackName);
  final layout = shortLayoutName(metadata.trackName, metadata.trackLayout);
  return layout == null ? track : '$track $layout';
}
